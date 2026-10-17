"""Transparent game-risk rubric and portfolio projections; never a market predictor.

Unknown sentiment is distinct from 50/50. Inputs are either explicitly DEMO
fixtures or trusted, attributed interpretations supplied by the research owner.
"""
from decimal import Decimal
from .models import PaperError, decimal_text, number, timestamp

TOLERANCES = {'conservative': 2, 'balanced': 3, 'adventurous': 5}
DEMO_RISK_LEVELS = {'AAPL': 3, 'WINA': 4, 'SPY': 2, 'GLD': 3, 'BTC-USD': 5, 'VNQ': 3,
                    'AAPL_20261120_C350_DEMO': 5, 'USDC-USD_DEMO': 3, 'DEMO_USD_BOND_20281115': 2}


def default_assessment(asset_id):
    return {'asset_id': asset_id, 'risk_level': DEMO_RISK_LEVELS.get(asset_id),
            'risk_label': 'DEMO educational 1–5 rubric, not a measured loss probability',
            'is_demo': True, 'sentiment': None,
            'sentiment_status': 'unknown', 'as_of': None,
            'source_label': 'No scored sentiment evidence supplied'}


def validate_assessment(value):
    if not isinstance(value, dict) or not isinstance(value.get('asset_id'), str):
        raise PaperError('invalid_assessment', 'Assessment needs exact asset identity')
    level = value.get('risk_level')
    if level is not None and (type(level) is not int or not 1 <= level <= 5):
        raise PaperError('invalid_assessment', 'Risk level must be an integer 1–5 or unknown')
    if type(value.get('is_demo')) is not bool or not isinstance(value.get('risk_label'), str) or not value['risk_label']:
        raise PaperError('invalid_assessment', 'Assessment requires a labeled rubric and explicit demo status')
    result = {**default_assessment(value['asset_id']), **value}
    sentiment = result.get('sentiment')
    if sentiment is None:
        result.update(sentiment_status='unknown', sentiment=None)
        return result
    if not isinstance(sentiment, dict):
        raise PaperError('invalid_assessment', 'Sentiment needs bullish and bearish shares')
    bullish = number(sentiment.get('bullish_share'), 'bullish_share')
    bearish = number(sentiment.get('bearish_share'), 'bearish_share')
    if bullish < 0 or bearish < 0 or bullish + bearish != 1:
        raise PaperError('invalid_assessment', 'Sentiment shares must be nonnegative and sum to 1')
    if not isinstance(result.get('source_label'), str) or not result['source_label'].strip():
        raise PaperError('invalid_assessment', 'Scored sentiment requires attribution')
    timestamp(result.get('as_of'))
    if not result['is_demo'] and not str(result.get('source_url', '')).startswith('https://'):
        raise PaperError('invalid_assessment', 'Nondemo sentiment requires a source URL')
    mixed = Decimal('.45') <= bullish <= Decimal('.55')
    result.update(sentiment={'bullish_share': decimal_text(bullish), 'bearish_share': decimal_text(bearish)},
                  sentiment_status='mixed' if mixed else ('bullish' if bullish > bearish else 'bearish'))
    return result


def projection(positions, cash, profile, assessments):
    """Market-value weights. Cash/unknown are explicit, never disguised as neutral evidence."""
    cash = number(cash)
    holdings = sum((number(p['market_value']) for p in positions), Decimal(0))
    equity = cash + holdings
    denominator = equity if equity else Decimal(1)
    weighted_risk = known_risk_value = covered = bullish = bearish = Decimal(0)
    by_kind, allocations, outside = {}, [], []
    ceiling = TOLERANCES.get((profile or {}).get('tolerance'))
    for position in positions:
        asset_id, value = position['asset_id'], number(position['market_value'])
        assessment = assessments.get(asset_id, default_assessment(asset_id))
        kind = position['asset']['kind']
        by_kind[kind] = by_kind.get(kind, Decimal(0)) + value
        level = assessment['risk_level']
        if level is not None:
            weighted_risk += value * level
            known_risk_value += value
            if ceiling is not None and level > ceiling:
                outside.append(asset_id)
        sentiment = assessment['sentiment']
        if sentiment is not None:
            covered += value
            bullish += value * number(sentiment['bullish_share'])
            bearish += value * number(sentiment['bearish_share'])
        allocations.append({'asset_id': asset_id, 'value': decimal_text(value),
                            'weight': decimal_text(value / denominator), 'kind': kind,
                            'assessment': assessment})
    known_bullish = bullish / covered if covered else None
    status = ('unknown' if known_bullish is None else 'mixed' if Decimal('.45') <= known_bullish <= Decimal('.55')
              else 'bullish' if known_bullish > Decimal('.5') else 'bearish')
    return {'equity': decimal_text(equity), 'cash': decimal_text(cash), 'holdings_value': decimal_text(holdings),
            'allocations': allocations,
            'asset_class_allocation': [{'kind': kind, 'value': decimal_text(value), 'weight': decimal_text(value / denominator)}
                                       for kind, value in sorted(by_kind.items())],
            'cash_weight': decimal_text(cash / denominator),
            'risk': {'profile': profile, 'ceiling': ceiling, 'outside_tolerance_asset_ids': outside,
                     'weighted_invested_score': decimal_text(weighted_risk / known_risk_value) if known_risk_value else None,
                     'coverage': decimal_text(known_risk_value / holdings) if holdings else '0',
                     'label': 'Educational rubric weighted by holding value; not loss probability or a diversification model'},
            'sentiment': {'status': status,
                          'bullish_share_of_covered_holdings': decimal_text(known_bullish) if covered else None,
                          'bearish_share_of_covered_holdings': decimal_text(bearish / covered) if covered else None,
                          'coverage_of_holdings': decimal_text(covered / holdings) if holdings else '0',
                          'bullish_equity_weight': decimal_text(bullish / denominator),
                          'bearish_equity_weight': decimal_text(bearish / denominator),
                          'unknown_equity_weight': decimal_text((holdings - covered) / denominator),
                          'cash_equity_weight': decimal_text(cash / denominator),
                          'has_demo_inputs': any(p['assessment']['is_demo'] and p['assessment']['sentiment'] is not None for p in allocations),
                          'label': 'Value-weighted evidence sentiment; not a probability of profit. Unknown is not 50/50.'}}
