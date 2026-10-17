"""Focused behavioral evidence; no network, broker, shared port or real account."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
import sqlite3
import tempfile
import unittest

from backend.paper import (Allocation, AssetKind, CopyStrategy, Instrument, OptionContract,
                           PaperAPI, PaperError, PaperService, Provenance)


class PaperEngineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'paper.sqlite3'
        self.now = datetime(2026, 10, 17, 15, 30, tzinfo=timezone.utc)
        self.service = PaperService(self.path, clock=lambda: self.now)
        self.service.set_profile('adventurous', confirmed=True)
        self.api = PaperAPI(self.service)

    def buy(self, asset='AAPL', quantity='2', key='buy'):
        preview = self.service.preview_order(asset, quantity, client_request_id=key,
                                             thesis={'reason': 'Business', 'risk': 'Valuation', 'invalidation': 'Margins fall'})
        return self.service.confirm_order(preview['order_id'], confirmed=True)

    def assert_code(self, code, call):
        with self.assertRaises(PaperError) as error:
            call()
        self.assertEqual(code, error.exception.code)

    def test_preview_interest_and_watchlist_do_not_trade(self):
        self.service.record_decision('AAPL', 'interest', thesis='I want to learn')
        self.service.record_decision('AAPL', 'watchlist')
        self.service.record_decision('WINA', 'pass')
        self.service.record_decision('DEMO_PATIENT_BUILDER', 'watchlist')
        preview = self.service.preview_order('AAPL', '2', client_request_id='preview')
        state = self.service.state()
        self.assertEqual('10000.00', state['cash'])
        self.assertEqual([], state['positions'])
        self.assertEqual(2, len(state['watchlist']))
        self.assertEqual(4, len(state['decisions']))
        feedback = self.service.record_decision('AAPL', 'save_thesis', thesis='test')['learning']
        self.assertEqual(['risk', 'invalidation'], feedback['missing_fields'])
        self.assertTrue(preview['requires_confirmation'])
        reopened = PaperService(self.path, clock=lambda: self.now).state()
        self.assertEqual(state['watchlist'], reopened['watchlist'])
        self.assertEqual('test', reopened['decisions'][0]['thesis']['reason'])

    def test_explicit_confirmation_and_idempotency_survive_restart(self):
        preview = self.service.preview_order('AAPL', '2', client_request_id='persistent')
        self.assert_code('confirmation_required', lambda: self.service.confirm_order(preview['order_id']))
        self.assert_code('confirmation_required', lambda: self.service.confirm_order(preview['order_id'], confirmed=1))
        receipt = self.service.confirm_order(preview['order_id'], confirmed=True)
        reopened = PaperService(self.path, clock=lambda: self.now)
        self.assertEqual(receipt, reopened.confirm_order(preview['order_id'], confirmed=True))
        self.assertEqual('9500.00', reopened.state()['cash'])
        self.assertEqual('2', reopened.state()['positions'][0]['quantity'])
        self.assertEqual(1, len(reopened.state()['transactions']))

    def test_concurrent_duplicate_confirmation_executes_once(self):
        preview = self.service.preview_order('AAPL', '2', client_request_id='concurrent')
        with ThreadPoolExecutor(max_workers=6) as pool:
            receipts = list(pool.map(lambda _: self.service.confirm_order(preview['order_id'], confirmed=True), range(12)))
        self.assertTrue(all(receipt == receipts[0] for receipt in receipts))
        self.assertEqual('9500.00', self.service.state()['cash'])
        self.assertEqual(1, len(self.service.state()['transactions']))

    def test_two_previews_cannot_overspend_at_confirmation(self):
        a = self.service.preview_order('AAPL', '30', client_request_id='a')
        b = self.service.preview_order('AAPL', '30', client_request_id='b')
        self.service.confirm_order(a['order_id'], confirmed=True)
        self.assert_code('insufficient_funds', lambda: self.service.confirm_order(b['order_id'], confirmed=True))
        self.assertEqual('2500.00', self.service.state()['cash'])
        self.assertEqual(1, len(self.service.state()['transactions']))
        self.assert_code('insufficient_funds', lambda: self.service.preview_order('AAPL', '100', client_request_id='c'))

    def test_exact_identity_and_people_are_not_securities(self):
        self.assert_code('unknown_asset', lambda: self.service.preview_order('aapl', '1', client_request_id='wrong-case'))
        self.assert_code('unknown_asset', lambda: self.service.preview_order('DEMO_PATIENT_BUILDER', '1', client_request_id='person'))
        p = Provenance('DEMO', self.now.isoformat(), 'https://example.com', True)
        self.assert_code('invalid_asset_kind', lambda: Instrument('p', 'p', 'person', 'person', Decimal('1'), p))
        self.assert_code('asset_identity_conflict', lambda: self.service.register_catalog([
            Instrument('AAPL', 'FAKE', 'Another asset', AssetKind.STOCK, Decimal('10'), p, venue='NASDAQ')]))
        self.assertEqual('AAPL', next(a for a in self.service.catalog()['assets'] if a['asset_id'] == 'AAPL')['symbol'])

    def test_all_required_exposures_have_distinct_kinds(self):
        assets = {a['asset_id']: a for a in self.service.catalog()['assets']}
        self.assertEqual({'stock', 'etf', 'crypto', 'commodity_exposure', 'real_estate_exposure', 'option', 'stablecoin', 'bond'}, {a['kind'] for a in assets.values()})
        self.assertFalse(self.service.catalog()['strategies'][0]['tradable'])
        for asset in assets.values():
            self.assertTrue(asset['provenance']['is_demo'])
            self.assertIn('DEMO', asset['provenance']['label'])

    def test_options_are_integer_contracts_with_expiry_and_multiplier(self):
        option = 'AAPL_20261120_C350_DEMO'
        self.assert_code('invalid_quantity', lambda: self.service.preview_order(option, '.5', client_request_id='fraction'))
        receipt = self.buy(option, '2')
        line = receipt['lines'][0]
        self.assertEqual(('contracts', 100, '1000.00'), (line['quantity_unit'], line['multiplier'], line['total']))
        self.assertEqual('9000.00', self.service.state()['cash'])
        self.now = datetime(2026, 11, 21, tzinfo=timezone.utc)
        self.assert_code('expired_option', lambda: self.service.preview_order(option, '1', client_request_id='expired'))
        self.assertEqual('expired_unsettled_snapshot', self.service.state()['positions'][0]['valuation']['status'])

    def test_copy_is_atomic_with_cash_consistency_and_provenance(self):
        preview = self.service.preview_copy('DEMO_PATIENT_BUILDER', '1000.00', client_request_id='copy')
        self.assertEqual(3, len(preview['lines']))
        invested = sum(Decimal(line['total']) for line in preview['lines'])
        self.assertEqual(Decimal('1000'), invested + Decimal(preview['uninvested_budget']))
        self.assertTrue(preview['strategy']['provenance']['is_demo'])
        receipt = self.service.confirm_order(preview['order_id'], confirmed=True)
        state = self.service.state()
        self.assertEqual(Decimal('10000'), Decimal(state['cash']) + invested)
        self.assertEqual(3, len(state['positions']))
        self.assertEqual(1, len(state['transactions']))
        self.assertEqual(receipt, self.service.confirm_order(preview['order_id'], confirmed=True))

    def test_copy_options_rounds_contracts_down_and_leaves_cash(self):
        p = Provenance('DEMO allocation', self.now.isoformat(), 'https://example.com', True)
        strategy = CopyStrategy('OPTION_STRATEGY', 'DEMO', 'Fictional',
                                (Allocation('AAPL_20261120_C350_DEMO', Decimal('0.5')), Allocation('SPY', Decimal('0.4'))), p)
        self.service.register_catalog([], [strategy])
        preview = self.service.preview_copy(strategy.strategy_id, '1500', client_request_id='opt-copy')
        self.assertEqual('1', preview['lines'][0]['quantity'])
        self.assertEqual('400.00', preview['uninvested_budget'])
        self.service.confirm_order(preview['order_id'], confirmed=True)
        self.assertEqual('8900.00', self.service.state()['cash'])

    def test_copy_confirmation_failure_is_all_or_nothing(self):
        basket = self.service.preview_copy('DEMO_PATIENT_BUILDER', '9000', client_request_id='big-copy')
        self.buy(quantity='20', key='spend')
        self.assert_code('insufficient_funds', lambda: self.service.confirm_order(basket['order_id'], confirmed=True))
        state = self.service.state()
        self.assertEqual(['AAPL'], [p['asset_id'] for p in state['positions']])
        self.assertEqual('5000.00', state['cash'])

    def test_reset_requires_fresh_preview_explicit_phrase_and_keeps_audit(self):
        confirmed = self.buy()
        pending = self.service.preview_order('AAPL', '1', client_request_id='pending')
        reset = self.service.preview_reset()
        self.assert_code('confirmation_required', lambda: self.service.confirm_reset(reset['reset_token'], confirmed=True))
        self.assertEqual('9500.00', self.service.state()['cash'])
        receipt = self.service.confirm_reset(reset['reset_token'], confirmed=True, confirmation_phrase='RESET PAPER PORTFOLIO')
        self.assertEqual(receipt, self.service.confirm_reset(reset['reset_token'], confirmed=True, confirmation_phrase='RESET PAPER PORTFOLIO'))
        state = PaperService(self.path).state()
        self.assertEqual(('10000.00', [], [], 2), (state['cash'], state['positions'], state['transactions'], state['epoch']))
        self.assert_code('order_not_pending', lambda: self.service.confirm_order(pending['order_id'], confirmed=True))
        self.assertEqual(confirmed, self.service.confirm_order(confirmed['order_id'], confirmed=True))
        self.assertEqual('10000.00', self.service.state()['cash'])
        with sqlite3.connect(self.path) as db:
            self.assertEqual(1, db.execute('SELECT count(*) FROM paper_transactions').fetchone()[0])

    def test_sell_cannot_short_and_updates_cost_basis(self):
        self.buy(quantity='4')
        sell = self.service.preview_order('AAPL', '1', side='sell', client_request_id='sell')
        self.service.confirm_order(sell['order_id'], confirmed=True)
        state = self.service.state()
        self.assertEqual(('9250.00', '3', '750.00'), (state['cash'], state['positions'][0]['quantity'], state['positions'][0]['cost_basis']))
        self.assert_code('insufficient_position', lambda: self.service.preview_order('AAPL', '4', side='sell', client_request_id='short'))

    def test_expired_preview_cancel_and_request_conflict(self):
        order = self.service.preview_order('AAPL', '1', client_request_id='key')
        self.assert_code('idempotency_conflict', lambda: self.service.preview_order('AAPL', '2', client_request_id='key'))
        self.assertEqual(order, self.service.preview_order('AAPL', '1', client_request_id='key'))
        self.now += timedelta(minutes=6)
        self.assert_code('expired_preview', lambda: self.service.confirm_order(order['order_id'], confirmed=True))
        fresh = self.service.preview_order('SPY', '1', client_request_id='fresh')
        self.service.cancel_order(fresh['order_id'])
        self.assert_code('order_not_pending', lambda: self.service.confirm_order(fresh['order_id'], confirmed=True))

    def test_price_update_preserves_pending_price_and_labels_new_valuation(self):
        preview = self.service.preview_order('AAPL', '1', client_request_id='price')
        p = Provenance('DEMO updated snapshot', self.now.isoformat(), 'https://example.com/quote', True)
        self.service.register_catalog([Instrument('AAPL', 'AAPL', 'Apple', AssetKind.STOCK, Decimal('300'), p, venue='NASDAQ')])
        receipt = self.service.confirm_order(preview['order_id'], confirmed=True)
        self.assertEqual('250', receipt['lines'][0]['price'])
        position = self.service.state()['positions'][0]
        self.assertEqual(('300.00', '50.00'), (position['market_value'], position['unrealized_pnl']))
        self.assertEqual('DEMO updated snapshot', position['valuation']['provenance']['label'])
        self.assertEqual('300', PaperService(self.path).state()['positions'][0]['valuation']['price'])


    def test_preview_retries_after_spending_do_not_create_new_orders(self):
        preview = self.service.preview_copy('DEMO_PATIENT_BUILDER', '10000', client_request_id='all-cash')
        self.service.confirm_order(preview['order_id'], confirmed=True)
        retry = self.service.preview_copy('DEMO_PATIENT_BUILDER', '10000', client_request_id='all-cash')
        self.assertEqual(preview['order_id'], retry['order_id'])
        self.assertEqual('confirmed', retry['status'])
        self.assertEqual(1, len(self.service.state()['transactions']))

    def test_invalid_identity_types_are_client_errors(self):
        for bad_id in ([], {}, 1, None):
            status, _ = self.api.handle('POST', '/paper/orders/preview',
                                      {'asset_id': bad_id, 'quantity': '1', 'client_request_id': 'bad-id'})
            self.assertEqual(400, status)
        self.assertEqual(400, self.api.handle('POST', '/paper/decisions', {'target_id': [], 'action': 'pass'})[0])


    def test_research_bridge_never_promotes_historical_quotes_to_fills(self):
        import copy
        from backend.paper import sync_research_catalog
        from backend.research import ResearchService
        research = ResearchService(now=lambda: self.now)
        catalog = research.catalog()
        before = {a['asset_id']: a for a in self.service.catalog()['assets']}
        for record in catalog['assets']:
            record.pop('paper_quote', None)
        result = sync_research_catalog(self.service, catalog)
        self.assertEqual([], result['updated_assets'])
        self.assertFalse(result['historical_quotes_used'])
        self.assertEqual(before, {a['asset_id']: a for a in self.service.catalog()['assets']})
        explicit = copy.deepcopy(catalog)
        explicit['assets'][0]['paper_quote'] = {'price': '123', 'status': 'demo_fixture', 'is_demo': True,
                                              'as_of': self.now.isoformat()}
        result = sync_research_catalog(self.service, explicit)
        self.assertEqual(['AAPL'], result['updated_assets'])
        self.assertEqual('123', next(a for a in self.service.catalog()['assets'] if a['asset_id'] == 'AAPL')['price'])
        changed = copy.deepcopy(explicit)
        changed['assets'][0]['paper_quote']['price'] = '1'
        next(r for r in changed['assets'] if r['kind'] == 'option')['option']['contract_multiplier'] = 1
        snapshot = self.service.catalog()
        self.assert_code('asset_identity_conflict', lambda: sync_research_catalog(self.service, changed))
        self.assertEqual(snapshot, self.service.catalog())
        explicit['assets'][0]['paper_quote']['is_demo'] = False
        self.assert_code('unsupported_quote', lambda: sync_research_catalog(self.service, explicit))

    def test_api_journey_and_errors(self):
        self.assertEqual(200, self.api.handle('GET', '/paper/catalog')[0])
        status, preview = self.api.handle('POST', '/paper/orders/preview', {'asset_id': 'VNQ', 'quantity': '2', 'client_request_id': 'api'})
        self.assertEqual(200, status)
        self.assertEqual(400, self.api.handle('POST', '/paper/orders/' + preview['order_id'] + '/confirm', {'confirmed': 'true'})[0])
        self.assertEqual(200, self.api.handle('POST', '/paper/orders/' + preview['order_id'] + '/confirm', {'confirmed': True})[0])
        self.assertEqual('9820.00', self.api.handle('GET', '/paper/state')[1]['cash'])
        for quantity in ('NaN', 'Infinity', '0', '-1', True, {}, '1e100', '1e-999999'):
            self.assertEqual(400, self.api.handle('POST', '/paper/orders/preview', {'asset_id': 'AAPL', 'quantity': quantity, 'client_request_id': 'invalid'})[0])
        self.assertEqual(400, self.api.handle('POST', '/paper/orders/preview', {'asset_id': 'AAPL'})[0])
        self.assertEqual(404, self.api.handle('POST', '/paper/unknown')[0])


if __name__ == '__main__':
    unittest.main()
