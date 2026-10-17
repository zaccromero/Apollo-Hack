"""New owner scope: track/visualize, risk eligibility and explicit mixed-sentiment exception."""
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
import tempfile
import unittest
from backend.paper import PaperAPI, PaperError, PaperService


class PortfolioMVPTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'portfolio.sqlite'
        self.service = PaperService(self.path)
        self.api = PaperAPI(self.service)

    def assert_code(self, code, call):
        with self.assertRaises(PaperError) as error:
            call()
        self.assertEqual(code, error.exception.code)

    def preview(self, asset='AAPL', quantity='1', key='mvp'):
        return self.service.preview_order(asset, quantity, client_request_id=key)

    def score(self, asset, risk, bullish):
        self.service.register_assessments([{
            'asset_id': asset, 'risk_level': risk, 'risk_label': 'DEMO educational test rubric',
            'is_demo': True, 'sentiment': {'bullish_share': str(bullish), 'bearish_share': str(Decimal(1)-Decimal(str(bullish)))},
            'source_label': 'DEMO fictional sentiment scenario; not observed market opinion',
            'as_of': datetime.now(timezone.utc).isoformat()}])

    def test_profile_required_confirmed_and_persistent(self):
        self.assert_code('risk_profile_required', self.preview)
        self.assertEqual([], self.service.state()['positions'])
        self.assertEqual(400, self.api.handle('POST', '/paper/profile', {'tolerance': 'balanced', 'confirmed': False})[0])
        self.assertEqual(200, self.api.handle('POST', '/paper/profile', {'tolerance': 'balanced', 'confirmed': True})[0])
        self.assertEqual('balanced', PaperService(self.path).profile()['profile']['tolerance'])
        self.assertEqual(200, self.api.handle('GET', '/paper/portfolio')[0])
        self.assertEqual('unknown', self.service.portfolio()['sentiment']['status'])

    def test_acceptance_within_tolerance_updates_holding_and_visualization(self):
        self.service.set_profile('balanced', confirmed=True)
        self.score('AAPL', 3, '.8')
        order = self.preview()
        self.assertEqual('within_tolerance', order['risk_check']['status'])
        receipt = self.service.confirm_order(order['order_id'], confirmed=True)
        self.assertEqual([], receipt['portfolio_before']['allocations'])
        self.assertEqual('AAPL', receipt['portfolio_after']['allocations'][0]['asset_id'])
        after = self.service.portfolio()
        self.assertEqual('bullish', after['sentiment']['status'])
        self.assertEqual('0.8', after['sentiment']['bullish_share_of_covered_holdings'])
        self.assertEqual('3', after['risk']['weighted_invested_score'])
        self.assertEqual(Decimal(1), Decimal(after['cash_weight']) + sum(Decimal(x['weight']) for x in after['allocations']))
        self.assertEqual(receipt['portfolio_after'], after)
        self.assertEqual(after, PaperService(self.path).portfolio())

    def test_outside_risk_with_unknown_sentiment_is_not_mixed(self):
        self.service.set_profile('balanced', confirmed=True)
        self.assert_code('risk_tolerance_exceeded', lambda: self.preview('BTC-USD', '.01'))
        self.assertEqual([], self.service.state()['positions'])
        decision = self.service.record_decision('BTC-USD', 'watchlist')
        self.assertEqual('watchlist', decision['action'])
        self.assertEqual('unknown', self.service.catalog()['assets'][0]['assessment']['sentiment_status'])

    def test_mixed_sentiment_requires_separate_explicit_paper_acknowledgment(self):
        self.service.set_profile('balanced', confirmed=True)
        self.score('WINA', 4, '.5')
        order = self.preview('WINA')
        self.assertTrue(order['risk_check']['requires_mixed_exception'])
        self.assert_code('mixed_exception_required', lambda: self.service.confirm_order(order['order_id'], confirmed=True))
        self.assert_code('mixed_exception_required', lambda: self.service.confirm_order(order['order_id'], confirmed=True, mixed_exception_acknowledged='true'))
        self.assertEqual([], self.service.state()['positions'])
        receipt = self.service.confirm_order(order['order_id'], confirmed=True, mixed_exception_acknowledged=True)
        self.assertTrue(receipt['mixed_exception_acknowledged'])
        self.assertEqual('mixed', receipt['portfolio_after']['sentiment']['status'])
        self.assertEqual(['WINA'], receipt['portfolio_after']['risk']['outside_tolerance_asset_ids'])
        self.assertEqual(receipt, self.service.confirm_order(order['order_id'], confirmed=True))
        self.assertEqual('9600.00', self.service.state()['cash'])

    def test_confirm_rechecks_profile_and_sentiment_in_same_transaction(self):
        self.service.set_profile('adventurous', confirmed=True)
        order = self.preview('WINA')
        self.service.set_profile('balanced', confirmed=True)
        self.assert_code('risk_tolerance_exceeded', lambda: self.service.confirm_order(order['order_id'], confirmed=True))
        self.score('WINA', 4, '.5')
        mixed = self.preview('WINA', key='mixed')
        self.score('WINA', 4, '.9')
        self.assert_code('risk_tolerance_exceeded', lambda: self.service.confirm_order(mixed['order_id'], confirmed=True, mixed_exception_acknowledged=True))
        self.assertEqual('10000.00', self.service.state()['cash'])

    def test_value_weighted_sentiment_exposes_unknown_coverage_and_cash(self):
        self.service.set_profile('adventurous', confirmed=True)
        self.score('AAPL', 3, '.8')
        self.score('WINA', 4, '.2')
        for asset, quantity in [('AAPL', '4'), ('WINA', '2.5'), ('GLD', '2')]:
            order = self.preview(asset, quantity, asset)
            self.service.confirm_order(order['order_id'], confirmed=True)
        summary = self.service.portfolio()
        sentiment = summary['sentiment']
        self.assertEqual('mixed', sentiment['status'])
        self.assertEqual('0.5', sentiment['bullish_share_of_covered_holdings'])
        self.assertEqual(Decimal(2000)/Decimal(2600), Decimal(sentiment['coverage_of_holdings']))
        self.assertEqual('0.06', sentiment['unknown_equity_weight'])
        self.assertEqual('0.74', sentiment['cash_equity_weight'])
        self.assertEqual(Decimal(1), sum(Decimal(sentiment[k]) for k in ('bullish_equity_weight','bearish_equity_weight','unknown_equity_weight','cash_equity_weight')))
        self.assertTrue(sentiment['has_demo_inputs'])

    def test_copied_strategy_checks_each_constituent_and_remains_atomic(self):
        self.service.set_profile('balanced', confirmed=True)
        self.assert_code('risk_tolerance_exceeded', lambda: self.service.preview_copy('DEMO_PATIENT_BUILDER', '1000', client_request_id='copy-blocked'))
        self.score('BTC-USD', 5, '.5')
        order = self.service.preview_copy('DEMO_PATIENT_BUILDER', '1000', client_request_id='copy-mixed')
        self.assertEqual(['BTC-USD'], order['risk_check']['exception_asset_ids'])
        receipt = self.service.confirm_order(order['order_id'], confirmed=True, mixed_exception_acknowledged=True)
        self.assertEqual(3, len(receipt['portfolio_after']['allocations']))
        self.assertEqual(1, len(self.service.state()['transactions']))

    def test_preview_impact_is_hypothetical_and_matches_unchanged_confirmation(self):
        self.service.set_profile('balanced', confirmed=True)
        self.score('AAPL', 3, '.8')
        before = self.service.state()
        order = self.preview()
        after_preview = self.service.state()
        for field in ('cash', 'positions', 'transactions', 'decisions', 'portfolio_summary'):
            self.assertEqual(before[field], after_preview[field])
        self.assertTrue(order['portfolio_projection_is_estimate'])
        self.assertEqual(before['portfolio_summary'], order['portfolio_before'])
        self.assertEqual('9750.00', order['portfolio_after']['cash'])
        self.assertEqual('bullish', order['portfolio_after']['sentiment']['status'])
        receipt = self.service.confirm_order(order['order_id'], confirmed=True)
        self.assertFalse(receipt['portfolio_projection_is_estimate'])
        self.assertEqual(order['portfolio_before'], receipt['portfolio_before'])
        self.assertEqual(order['portfolio_after'], receipt['portfolio_after'])

    def test_copy_and_option_projections_preserve_unknown_coverage_and_contract_math(self):
        self.service.set_profile('adventurous', confirmed=True)
        copy = self.service.preview_copy('DEMO_PATIENT_BUILDER', '1000', client_request_id='project-copy')
        self.assertEqual(3, len(copy['portfolio_after']['allocations']))
        self.assertEqual('unknown', copy['portfolio_after']['sentiment']['status'])
        self.assertEqual('0', copy['portfolio_after']['sentiment']['coverage_of_holdings'])
        self.assertEqual('10000.00', self.service.state()['cash'])
        option = self.preview('AAPL_20261120_C350_DEMO', '2', 'project-option')
        self.assertEqual('1000.00', option['portfolio_after']['holdings_value'])
        self.assertEqual('9000.00', option['portfolio_after']['cash'])
        self.assertEqual('10000.00', option['portfolio_after']['equity'])
        receipt = self.service.confirm_order(option['order_id'], confirmed=True)
        self.assertEqual(option['portfolio_after'], receipt['portfolio_after'])

    def test_confirm_recomputes_impact_after_intervening_trade_without_repricing_preview(self):
        self.service.set_profile('adventurous', confirmed=True)
        preview = self.preview('AAPL', '1', 'first-preview')
        intervening = self.preview('GLD', '1', 'intervening')
        self.service.confirm_order(intervening['order_id'], confirmed=True)
        receipt = self.service.confirm_order(preview['order_id'], confirmed=True)
        self.assertEqual(1, len(receipt['portfolio_before']['allocations']))
        self.assertEqual(2, len(receipt['portfolio_after']['allocations']))
        self.assertNotEqual(preview['portfolio_after'], receipt['portfolio_after'])
        self.assertEqual('9450.00', receipt['portfolio_after']['cash'])
        self.assertEqual(preview['lines'], receipt['lines'])

    def test_sell_projection_removes_position_without_mutating_before_confirm(self):
        self.service.set_profile('balanced', confirmed=True)
        buy = self.preview()
        self.service.confirm_order(buy['order_id'], confirmed=True)
        sell = self.service.preview_order('AAPL', '1', side='sell', client_request_id='project-sell')
        self.assertEqual([], sell['portfolio_after']['allocations'])
        self.assertEqual('10000.00', sell['portfolio_after']['cash'])
        self.assertEqual(1, len(self.service.state()['positions']))
        receipt = self.service.confirm_order(sell['order_id'], confirmed=True)
        self.assertEqual(sell['portfolio_after'], receipt['portfolio_after'])

    def test_client_cannot_submit_ratings_or_bypass_risk_through_confirm_payload(self):
        self.service.set_profile('balanced', confirmed=True)
        self.assertEqual(404, self.api.handle('POST', '/paper/assessments', {'risk_level': 1})[0])
        order = self.preview()
        self.assertEqual(400, self.api.handle('POST','/paper/orders/'+order['order_id']+'/confirm', {'confirmed':True,'risk_level':1})[0])
        self.assertEqual([], self.service.state()['positions'])


if __name__ == '__main__':
    unittest.main()
