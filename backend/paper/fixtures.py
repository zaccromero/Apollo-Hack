"""Illustrative prices only. These are not fetched quotes or historical price claims."""
from decimal import Decimal
from dataclasses import asdict
import json
from .models import Allocation, AssetKind, BondContract, CopyStrategy, Instrument, OptionContract, Provenance, StablecoinTerms


def demo_catalog():
    def provenance(url):
        return Provenance('DEMO illustrative price; linked page identifies exposure only',
                          '2026-10-17T15:00:00+00:00', url, True)
    assets = (
        Instrument('AAPL', 'AAPL', 'Apple', AssetKind.STOCK, Decimal('250'), provenance('https://www.apple.com/investor/'), venue='NASDAQ'),
        Instrument('WINA', 'WINA', 'Winmark', AssetKind.STOCK, Decimal('400'), provenance('https://www.winmarkcorporation.com/'), venue='NASDAQ'),
        Instrument('SPY', 'SPY', 'SPDR S&P 500 ETF Trust', AssetKind.ETF, Decimal('600'), provenance('https://www.ssga.com/us/en/individual/etfs/spdr-sp-500-etf-trust-spy'), venue='NYSE_ARCA'),
        Instrument('GLD', 'GLD', 'SPDR Gold Shares — gold trust exposure', AssetKind.COMMODITY_EXPOSURE, Decimal('300'), provenance('https://www.spdrgoldshares.com/'), venue='NYSE_ARCA'),
        Instrument('BTC-USD', 'BTC-USD', 'Bitcoin — simulated USD spot exposure', AssetKind.CRYPTO, Decimal('100000'), provenance('https://bitcoin.org/'), venue='DEMO_SPOT'),
        Instrument('VNQ', 'VNQ', 'Vanguard Real Estate ETF — fund exposure', AssetKind.REAL_ESTATE_EXPOSURE, Decimal('90'), provenance('https://investor.vanguard.com/investment-products/etfs/profile/vnq'), venue='NYSE_ARCA'),
        Instrument('AAPL_20261120_C350_DEMO', 'AAPL 20 Nov 2026 350 Call', 'DEMO long Apple call option', AssetKind.OPTION,
                   Decimal('5'), provenance('https://www.optionseducation.org/optionsoverview/options-basics'), venue='DEMO_OPTIONS',
                   option=OptionContract('AAPL', 'call', Decimal('350'), '2026-11-20T21:00:00+00:00', 100)),
        Instrument('USDC-USD_DEMO', 'USDC-USD', 'USD Coin — DEMO stablecoin exposure', AssetKind.STABLECOIN,
                   Decimal('1.00'), provenance('https://www.circle.com/usdc'), venue='DEMO_STABLECOIN',
                   stablecoin=StablecoinTerms('USD', Decimal('1.00'), False)),
        Instrument('DEMO_USD_BOND_20281115', 'DEMO USD 4% 2028', 'Fictional USD direct bond — DEMO', AssetKind.BOND,
                   Decimal('980.00'), provenance('https://www.investor.gov/introduction-investing/investing-basics/investment-products/bonds-or-fixed-income-products/bonds'),
                   venue='DEMO_BONDS', bond=BondContract(Decimal('1000'), Decimal('.04'), '2028-11-15T21:00:00+00:00', 2),
                   bond_clean_price_per_100=Decimal('98.00'), bond_accrued_interest_per_bond=Decimal('0')),
    )
    strategy = CopyStrategy('DEMO_PATIENT_BUILDER', 'Patient Builder — fictional allocation', 'Fictional educational investor',
                            (Allocation('SPY', Decimal('.60')), Allocation('GLD', Decimal('.20')), Allocation('BTC-USD', Decimal('.20'))),
                            provenance('https://www.investor.gov/introduction-investing/investing-basics/asset-allocation'))
    return assets, (strategy,)


def get_instrument_specs():
    """Canonical pure registry export; no DB, files, network, service or provider calls.

    Research adds evidence/educational copy to these exact identities and terms.
    All price fields here are explicitly illustrative DEMO execution snapshots.
    Every call returns a fresh JSON-compatible structure.
    """
    assets, strategies = demo_catalog()
    payload = {'schema_version': 2, 'mode': 'demo_instrument_specs',
               'price_notice': 'Illustrative DEMO execution prices; source URLs identify exposure/concepts only, never validate the fixture price.',
               'assets': [{**asdict(asset), 'multiplier': asset.multiplier,
                           'quantity_unit': asset.unit, 'tradable': True} for asset in assets],
               'strategies': [{**asdict(strategy), 'kind': 'strategy', 'tradable': False} for strategy in strategies]}
    return json.loads(json.dumps(payload, default=lambda value: format(value, 'f') if isinstance(value, Decimal) else value.value))
