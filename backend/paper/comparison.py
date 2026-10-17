"""Read-only all-profile comparisons and explicitly illustrative mark sensitivities."""
from decimal import Decimal
from .models import PaperError, decimal_text, number
from .portfolio import TOLERANCES
from .service import money


def outcomes(summary):
    result = []
    baseline = number(summary['equity'])
    for shock, label in ((Decimal('-.20'), 'DEMO: all held marks down 20%'),
                         (Decimal(0), 'DEMO: unchanged marks'),
                         (Decimal('.20'), 'DEMO: all held marks up 20%')):
        marked = sum((money(number(p['value']) * (1 + shock)) for p in summary['allocations']), Decimal(0))
        equity = number(summary['cash']) + marked
        result.append({'shock': decimal_text(shock), 'holding_mark_value': decimal_text(marked),
                       'equity': decimal_text(equity), 'change_from_snapshot': decimal_text(equity - baseline), 'label': label})
    return result


def compare_portfolios(service, asset_id, quantity, *, strategy_id='DEMO_PATIENT_BUILDER', strategy_budget=None):
    # No INSERT, UPDATE, DELETE, set_profile, preview persistence or confirm call.
    with service._transaction() as db:
        now, account = service._now(), service._account(db)
        asset = service._asset(db, asset_id)
        investment_lines = [service._line(asset, quantity, 'buy', now)]
        investment_cost = number(investment_lines[0]['total'])
        service._check_resources(db, investment_lines, investment_cost, number(account['cash']))
        strategy = service._strategy(db, strategy_id)
        budget = money(number(strategy_budget if strategy_budget is not None else investment_cost, 'strategy_budget', positive=True))
        if budget > number(account['cash']):
            raise PaperError('insufficient_funds', 'Strategy comparison budget exceeds available virtual cash', 409)
        strategy_lines = service._copy_lines(db, strategy, budget)
        strategy_cost = sum((number(line['total']) for line in strategy_lines), Decimal(0))
        service._check_resources(db, strategy_lines, strategy_cost, number(account['cash']))
        baseline = service._portfolio_snapshot(db, account, now)
        profiles = []
        alternatives = {'investment': (investment_lines, investment_cost), 'strategy': (strategy_lines, strategy_cost)}
        first_projections = {}
        for tolerance, ceiling in TOLERANCES.items():
            profile = {'tolerance': tolerance, 'asset_risk_ceiling': ceiling,
                       'model': 'DEMO comparison profile; does not change your saved preference'}
            item = {'tolerance': tolerance, 'asset_risk_ceiling': ceiling,
                    'current': service._portfolio_snapshot(db, account, now, profile_override=profile)}
            for name, (lines, cost) in alternatives.items():
                try:
                    risk = service._risk_check(db, lines, preview=True, profile_override=profile)
                except PaperError as error:
                    risk = {'status': 'blocked', 'code': error.code, 'notice': str(error),
                            'requires_mixed_exception': False, 'profile': profile}
                after = service._portfolio_snapshot(db, account, now, projected_lines=lines,
                                                    cash_change=-cost, profile_override=profile)
                item[name] = {'risk_check': risk, 'portfolio_after': after}
                first_projections.setdefault(name, after)
            profiles.append(item)
        return {'mode': 'paper_comparison', 'mutates_account': False, 'creates_order': False,
                'as_of': now.isoformat(), 'saved_profile': service._profile(db), 'baseline': baseline,
                'recorded_paper_pnl': decimal_text(number(baseline['equity']) - number(account['initial_cash'])),
                'recorded_results_notice': 'Recorded paper snapshot only, using dated catalog marks; no real or verified historical investment performance.',
                'investment': {'asset_id': asset_id, 'lines': investment_lines, 'total': decimal_text(investment_cost)},
                'strategy': {'strategy_id': strategy_id, 'name': strategy['name'], 'provenance': strategy['provenance'],
                             'lines': strategy_lines, 'total': decimal_text(strategy_cost), 'budget': decimal_text(budget),
                             'uninvested_budget': decimal_text(budget - strategy_cost)},
                'profiles': profiles,
                'outcomes': {'current': outcomes(baseline), 'investment': outcomes(first_projections['investment']),
                             'strategy': outcomes(first_projections['strategy'])},
                'outcome_assumptions': 'DEMO sensitivity examples, not forecasts, probabilities or observed returns. Cash unchanged; every held mark moves by the displayed percentage. Options shock premium marks, not underlying prices; no Greeks, exercise, expiry settlement, fees or slippage modeled. Stablecoin marks can depeg; tokens are not cash. Bond coupon cash flows and maturity settlement are not simulated.',
                'comparison_notice': 'Read-only hypothetical comparison across all three profiles. Risk-ineligible cases are shown for learning only. A real paper acceptance still requires an explicit chosen profile, a separate order preview, any mixed exception acknowledgment and confirmation.'}
