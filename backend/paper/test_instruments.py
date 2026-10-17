"""New direct bond / stablecoin math and canonical pure registry, no live feeds."""
from dataclasses import replace
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from backend.paper import AssetKind, PaperError, PaperService, get_instrument_specs
from backend.paper.fixtures import demo_catalog


class ExpandedInstrumentTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path=Path(self.tmp.name)/'paper.sqlite'
        self.now=datetime(2026,10,17,16,15,tzinfo=timezone.utc)
        self.paper=PaperService(self.path,clock=lambda:self.now)
        self.paper.set_profile('adventurous',confirmed=True)
        self.assets={asset.asset_id:asset for asset in demo_catalog()[0]}

    def error_code(self,code,fn):
        with self.assertRaises(PaperError) as result:
            fn()
        self.assertEqual(code,result.exception.code)

    def buy(self,asset,quantity,key='new'):
        preview=self.paper.preview_order(asset,quantity,client_request_id=key)
        return self.paper.confirm_order(preview['order_id'],confirmed=True)

    def test_pure_registry_exports_exact_terms_without_io_and_fresh_objects(self):
        with patch('sqlite3.connect',side_effect=AssertionError('No registry DB')), patch('socket.socket',side_effect=AssertionError('No registry network')), patch('builtins.open',side_effect=AssertionError('No registry file')):
            specs=get_instrument_specs()
        self.assertEqual(9,len(specs['assets']))
        self.assertEqual(1,len(specs['strategies']))
        self.assertFalse(specs['strategies'][0]['tradable'])
        bond=next(a for a in specs['assets'] if a['kind']=='bond')
        self.assertEqual(('980.00','98.00','1000','0.04','bonds',1),
                         (bond['price'],bond['bond_clean_price_per_100'],bond['bond']['face_value'],bond['bond']['annual_coupon_rate'],bond['quantity_unit'],bond['multiplier']))
        bond['price']='1'
        self.assertEqual('980.00',next(a for a in get_instrument_specs()['assets'] if a['kind']=='bond')['price'])

    def test_stablecoin_holdings_are_tokens_not_cash_and_mark_depegs(self):
        receipt=self.buy('USDC-USD_DEMO','100')
        self.assertEqual(('100.00','tokens'),(receipt['lines'][0]['total'],receipt['lines'][0]['quantity_unit']))
        self.assertFalse(receipt['lines'][0]['stablecoin']['redemption_guaranteed'])
        self.paper.register_catalog([replace(self.assets['USDC-USD_DEMO'],price=Decimal('.85'))])
        state=self.paper.state()
        self.assertEqual('9900.00',state['cash'])
        self.assertEqual(('85.00','-15.00'),(state['positions'][0]['market_value'],state['positions'][0]['unrealized_pnl']))
        self.assertEqual('stablecoin',state['portfolio_summary']['asset_class_allocation'][0]['kind'])
        self.assertEqual('9985.00',state['equity'])
        self.assertEqual('0.85',PaperService(self.path).state()['positions'][0]['valuation']['price'])

    def test_bond_quotes_per_100_face_convert_to_usd_per_bond_not_fund_shares(self):
        bond=self.assets['DEMO_USD_BOND_20281115']
        self.assertEqual(Decimal('40.00'),bond.bond.face_value*bond.bond.annual_coupon_rate)
        self.error_code('invalid_bond_price',lambda:replace(bond,price=Decimal('98')))
        self.error_code('invalid_quantity',lambda:self.paper.preview_order(bond.asset_id,'.5',client_request_id='fractional'))
        receipt=self.buy(bond.asset_id,'2')
        line=receipt['lines'][0]
        self.assertEqual(('1960.00','980.00','bonds',1),(line['total'],line['price'],line['quantity_unit'],line['multiplier']))
        self.assertEqual('98.00',line['bond_clean_price_per_100'])
        self.assertEqual('8040.00',self.paper.state()['cash'])
        self.assertEqual('bond',self.paper.state()['positions'][0]['asset']['kind'])

    def test_accrued_interest_is_in_price_once_not_silently_omitted_or_doubled(self):
        bond=replace(self.assets['DEMO_USD_BOND_20281115'],price=Decimal('992.50'),bond_accrued_interest_per_bond=Decimal('12.50'))
        self.paper.register_catalog([bond])
        receipt=self.buy(bond.asset_id,'2')
        self.assertEqual('1985.00',receipt['lines'][0]['total'])
        self.assertEqual('12.50',receipt['lines'][0]['bond_accrued_interest_per_bond'])
        self.assertEqual('8015.00',self.paper.state()['cash'])
        self.assertEqual('1985.00',PaperService(self.path).state()['positions'][0]['market_value'])

    def test_coupon_and_maturity_do_not_invent_cashflows_or_principal_settlement(self):
        self.buy('DEMO_USD_BOND_20281115','1')
        self.now=datetime(2027,10,17,tzinfo=timezone.utc)
        self.assertEqual('9020.00',self.paper.state()['cash'])
        self.now=datetime(2028,11,16,tzinfo=timezone.utc)
        self.assertEqual('matured_unsettled_snapshot',self.paper.state()['positions'][0]['valuation']['status'])
        self.assertEqual('9020.00',self.paper.state()['cash'])
        self.error_code('matured_bond',lambda:self.paper.preview_order('DEMO_USD_BOND_20281115','1',client_request_id='matured'))

    def test_bond_identity_terms_cannot_be_repurposed_under_existing_id(self):
        bond=self.assets['DEMO_USD_BOND_20281115']
        altered=replace(bond,bond=replace(bond.bond,annual_coupon_rate=Decimal('.08')))
        self.error_code('asset_identity_conflict',lambda:self.paper.register_catalog([altered]))
        self.error_code('invalid_bond',lambda:replace(self.assets['AAPL'],bond=bond.bond))
        self.error_code('invalid_stablecoin',lambda:replace(self.assets['AAPL'],stablecoin=self.assets['USDC-USD_DEMO'].stablecoin))

    def test_comparison_shocks_stablecoin_marks_and_direct_bond_value_as_labeled(self):
        stable=self.paper.compare('USDC-USD_DEMO','100')
        self.assertEqual('9980.00',stable['outcomes']['investment'][0]['equity'])
        bond=self.paper.compare('DEMO_USD_BOND_20281115','1')
        self.assertEqual('980.00',bond['investment']['total'])
        self.assertEqual('9804.00',bond['outcomes']['investment'][0]['equity'])
        self.assertIn('tokens are not cash',bond['outcome_assumptions'])
        self.assertIn('coupon cash flows',bond['outcome_assumptions'])
        self.assertEqual('10000.00',self.paper.state()['cash'])


if __name__=='__main__':
    unittest.main()
