"""Owner's read-only demo: all profiles, current vs stock vs strategy, honest outcomes."""
from pathlib import Path
from contextlib import closing
from datetime import datetime, timezone
from decimal import Decimal
import sqlite3
import tempfile
import unittest
from backend.paper import PaperAPI, PaperError, PaperService


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'comparison.sqlite'
        self.paper = PaperService(self.path)
        self.api = PaperAPI(self.paper)

    def table_counts(self):
        with closing(sqlite3.connect(self.path)) as db:
            return {name: db.execute('SELECT count(*) FROM '+name).fetchone()[0] for name in
                    ('paper_account','paper_profile','paper_orders','paper_positions','paper_decisions','paper_watchlist','paper_transactions','paper_resets')}

    def test_all_profiles_without_saving_a_profile_or_creating_any_order(self):
        before, counts = self.paper.state(), self.table_counts()
        status, result = self.api.handle('POST','/paper/compare',{'asset_id':'AAPL','quantity':'1'})
        self.assertEqual(200, status)
        self.assertFalse(result['mutates_account'])
        self.assertFalse(result['creates_order'])
        self.assertIsNone(result['saved_profile'])
        self.assertEqual(['conservative','balanced','adventurous'], [p['tolerance'] for p in result['profiles']])
        self.assertEqual(['blocked','within_tolerance','within_tolerance'], [p['investment']['risk_check']['status'] for p in result['profiles']])
        self.assertEqual(before, self.paper.state())
        self.assertEqual(counts, self.table_counts())
        self.assertEqual('250.00', result['strategy']['budget'])
        self.assertEqual(3, len(result['strategy']['lines']))
        self.assertEqual('0.00', result['recorded_paper_pnl'])

    def test_sentiment_unknown_is_not_fabricated_or_treated_as_mixed(self):
        result = self.paper.compare('AAPL','1')
        for profile in result['profiles']:
            self.assertEqual('unknown', profile['investment']['portfolio_after']['sentiment']['status'])
            self.assertEqual('0', profile['strategy']['portfolio_after']['sentiment']['coverage_of_holdings'])
            if profile['tolerance'] != 'adventurous':
                self.assertEqual('blocked', profile['strategy']['risk_check']['status'])
                self.assertEqual('risk_tolerance_exceeded', profile['strategy']['risk_check']['code'])

    def test_sensitivity_math_is_labeled_demo_and_not_recorded_return(self):
        result = self.paper.compare('AAPL','1')
        outcomes = result['outcomes']['investment']
        self.assertEqual(['9950.00','10000.00','10050.00'], [o['equity'] for o in outcomes])
        self.assertEqual(['-50.00','0.00','50.00'], [o['change_from_snapshot'] for o in outcomes])
        self.assertTrue(all(o['label'].startswith('DEMO:') for o in outcomes))
        self.assertIn('not forecasts', result['outcome_assumptions'])
        self.assertEqual('10000.00', self.paper.state()['cash'])
        self.assertEqual('0.00', result['recorded_paper_pnl'])

    def test_saved_preference_and_existing_portfolio_survive_comparison(self):
        self.paper.set_profile('adventurous',confirmed=True)
        order=self.paper.preview_order('AAPL','1',client_request_id='prior')
        self.paper.confirm_order(order['order_id'],confirmed=True)
        before=self.paper.state()
        result=self.paper.compare('SPY','1',strategy_budget='600')
        self.assertEqual('adventurous',result['saved_profile']['tolerance'])
        self.assertEqual(before,self.paper.state())
        for profile in result['profiles']:
            self.assertEqual(1,len(profile['current']['allocations']))
            self.assertEqual(2,len(profile['investment']['portfolio_after']['allocations']))
            self.assertEqual('3',profile['current']['risk']['weighted_invested_score'])

    def test_option_outcome_uses_contract_premium_multiplier_without_underlying_claim(self):
        result=self.paper.compare('AAPL_20261120_C350_DEMO','2')
        self.assertEqual('1000.00',result['investment']['total'])
        after=result['profiles'][2]['investment']['portfolio_after']
        self.assertEqual('1000.00',after['holdings_value'])
        self.assertEqual('9800.00',result['outcomes']['investment'][0]['equity'])
        self.assertIn('premium marks, not underlying prices',result['outcome_assumptions'])
        self.assertEqual(400,self.api.handle('POST','/paper/compare',{'asset_id':'AAPL_20261120_C350_DEMO','quantity':'.5'})[0])

    def test_failed_comparison_cannot_mutate_account_or_override_risk_fields(self):
        before=self.paper.state()
        self.assertEqual(400,self.api.handle('POST','/paper/compare',{'asset_id':'AAPL','quantity':'1','risk_level':1})[0])
        self.assertEqual(409,self.api.handle('POST','/paper/compare',{'asset_id':'AAPL','quantity':'1000'})[0])
        self.assertEqual(404,self.api.handle('POST','/paper/compare',{'asset_id':'DEMO_PATIENT_BUILDER','quantity':'1'})[0])
        self.assertEqual(before,self.paper.state())

    def test_visible_sentiment_shift_does_not_turn_portfolio_balance_into_an_asset_exception(self):
        # An aggregate 50/50 portfolio is not evidence that the proposed asset is mixed.
        for asset_id, risk, bullish in [('AAPL', 3, '.8'), ('WINA', 4, '.2')]:
            self.paper.register_assessments([{
                'asset_id': asset_id, 'risk_level': risk,
                'risk_label': 'DEMO educational comparison rubric', 'is_demo': True,
                'sentiment': {'bullish_share': bullish, 'bearish_share': str(1-Decimal(bullish))},
                'source_label': 'DEMO fictional sentiment; not observed market opinion',
                'as_of': datetime.now(timezone.utc).isoformat()}])
        self.paper.set_profile('adventurous', confirmed=True)
        prior = self.paper.preview_order('AAPL', '4', client_request_id='comparison-baseline')
        self.paper.confirm_order(prior['order_id'], confirmed=True)
        before, counts = self.paper.state(), self.table_counts()
        result = self.paper.compare('WINA', '2.5')
        for profile in result['profiles']:
            current, after = profile['current'], profile['investment']['portfolio_after']
            self.assertEqual('3', current['risk']['weighted_invested_score'])
            self.assertEqual('3.5', after['risk']['weighted_invested_score'])
            self.assertEqual('0.8', current['sentiment']['bullish_share_of_covered_holdings'])
            self.assertEqual('0.5', after['sentiment']['bullish_share_of_covered_holdings'])
            self.assertEqual('1', after['sentiment']['coverage_of_holdings'])
            self.assertEqual('mixed', after['sentiment']['status'])
            check = profile['investment']['risk_check']
            self.assertEqual('within_tolerance' if profile['tolerance'] == 'adventurous' else 'blocked', check['status'])
            self.assertFalse(check.get('requires_mixed_exception', False))
        self.assertEqual(before, self.paper.state())
        self.assertEqual(counts, self.table_counts())


if __name__=='__main__':
    unittest.main()
