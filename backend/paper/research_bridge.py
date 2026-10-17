"""Explicit trusted bridge from the research catalog without promoting historical prices to paper fills.

The integrator calls sync_research_catalog(paper_service, research_service.catalog()).
Only an explicit DEMO paper_quote can change a paper execution snapshot.
Research quote is historical/nonexecutable and is never read by this bridge.
No implicit network calls, cross-lane imports or source writes occur here.
"""
from dataclasses import replace
from .models import Allocation, CopyStrategy, PaperError, Provenance, number, timestamp


KINDS = {'stock': 'stock', 'etf': 'etf', 'crypto': 'crypto',
         'commodity': 'commodity_exposure', 'real_estate': 'real_estate_exposure', 'option': 'option',
         'stablecoin': 'stablecoin', 'bond': 'bond'}


def sync_research_catalog(service, catalog):
    if not isinstance(catalog, dict) or not isinstance(catalog.get('assets'), list):
        raise PaperError('invalid_research_catalog', 'Expected the research catalog envelope')
    current = service.catalog()
    assets = {a['asset_id']: a for a in current['assets']}
    strategies = {s['strategy_id']: s for s in current['strategies']}
    updated, strategy_updates = [], []
    from .service import read_instrument, encode
    for record in catalog['assets']:
        asset_id, kind = record['asset_id'], record['kind']
        if kind == 'strategy':
            previous = strategies.get(asset_id)
            if previous is None or not record.get('demo_asset'):
                raise PaperError('unverified_strategy', 'Only explicitly attributed seeded demo strategies are accepted by this bridge')
            allocations = tuple(Allocation(a['asset_id'], a['weight']) for a in record['allocations'])
            strategy_updates.append(CopyStrategy(asset_id, record['name'], previous['person_name'], allocations,
                                                Provenance(**previous['provenance'])))
            continue
        previous = assets.get(asset_id)
        if previous is None or KINDS.get(kind) != previous['kind']:
            raise PaperError('asset_identity_conflict', 'Research-to-paper mapping requires an exact seeded asset identity and matching kind')
        asset = read_instrument(encode(previous))
        if asset.option:
            option = record.get('option') or {}
            if (option.get('underlying_asset_id') != asset.option.underlying_asset_id or
                option.get('option_type') != asset.option.right or number(option.get('strike')) != asset.option.strike or
                option.get('expiry') != asset.option.expires_at[:10] or option.get('contract_multiplier') != asset.option.multiplier):
                raise PaperError('asset_identity_conflict', 'Research option contract does not match exact paper terms')
        if asset.stablecoin:
            terms = record.get('stablecoin') or {}
            if (terms.get('peg_currency') != asset.stablecoin.peg_currency or
                number(terms.get('target_peg')) != asset.stablecoin.target_peg or terms.get('redemption_guaranteed') is not False):
                raise PaperError('asset_identity_conflict', 'Stablecoin peg terms do not match the canonical instrument')
        if asset.bond:
            terms = record.get('bond') or {}
            if (number(terms.get('face_value')) != asset.bond.face_value or
                number(terms.get('annual_coupon_rate')) != asset.bond.annual_coupon_rate or
                terms.get('matures_at') != asset.bond.matures_at or terms.get('coupon_frequency') != asset.bond.coupon_frequency or
                terms.get('price_convention') != asset.bond.price_convention):
                raise PaperError('asset_identity_conflict', 'Bond face/coupon/maturity/quote convention does not match the canonical instrument')
        quote = record.get('paper_quote')
        if quote is None:
            continue  # Historical research.quote is deliberately never an execution input.
        if not isinstance(quote, dict) or quote.get('is_demo') is not True or quote.get('status') != 'demo_fixture':
            raise PaperError('unsupported_quote', 'Only an explicitly DEMO paper_quote may change execution prices')
        as_of = quote.get('as_of') or catalog.get('as_of')
        timestamp(as_of)
        source = quote.get('source_url') or asset.provenance.source_url
        label = 'DEMO paper execution fixture; research historical quote is nonexecutable'
        provenance = Provenance(label, as_of, source, True)
        updated.append(replace(asset, price=number(quote.get('price'), 'price', positive=True), provenance=provenance))
    service.register_catalog(updated, strategy_updates)
    return {'mode': 'paper', 'historical_quotes_used': False, 'updated_assets': [a.asset_id for a in updated],
            'updated_strategies': [s.strategy_id for s in strategy_updates], 'network_calls': 0}
