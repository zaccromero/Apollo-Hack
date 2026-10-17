import json
import socket
import unittest
from unittest.mock import patch
from research import research_payload


class ActualLocalResearchTests(unittest.TestCase):
    def test_natural_apple_question_uses_three_tracks_without_network(self):
        with patch('socket.socket', side_effect=AssertionError('Network forbidden')):
            result = research_payload('What changed AAPL this week?')
        self.assertEqual([x['title'] for x in result['embeds'][1:]],
                         ['Leadership', 'Promises vs results', 'Public sentiment'])
        self.assertIn('AAPL', result['embeds'][0]['title'])
        self.assertIn('latest updates are unverified', result['embeds'][0]['description'])
        self.assertIn('context only', result['content'])
        self.assertEqual(result['allowed_mentions'], {'parse': []})
        self.assertIn('https://www.apple.com/', json.dumps(result))
        self.assertIn('Counterevidence', json.dumps(result))

    def test_winmark_does_not_leak_apple_sources(self):
        result = research_payload('Review Winmark')
        self.assertIn('WINA', result['embeds'][0]['title'])
        self.assertNotIn('apple.com', json.dumps(result))

    def test_pasted_url_is_context_never_fetched_or_admitted(self):
        with patch('socket.socket', side_effect=AssertionError('Network forbidden')):
            result = research_payload('Review Apple', pasted_url='https://example.com/unreviewed')
        self.assertIn('NOT FETCHED or reviewed', result['content'])
        self.assertNotIn('example.com', json.dumps(result['embeds']))

    def test_unknown_ambiguous_and_malformed_requests_fail_closed(self):
        for q in ['What changed?', 'AAPL and WINA', '', 'x'*1001]:
            with self.subTest(q=q[:30]), self.assertRaises(ValueError):
                research_payload(q)
        with self.assertRaises(ValueError):
            research_payload('AAPL', pasted_url='https://u:p@example.com')
        with self.assertRaises(ValueError):
            research_payload('AAPL', asset='UNKNOWN')

    def test_explicit_asset_and_known_source_url_resolution(self):
        self.assertIn('SPY', research_payload('Explain the exposure', asset='SPY')['embeds'][0]['title'])
        result = research_payload('Explain this source', pasted_url='https://www.apple.com/leadership/john-ternus/')
        self.assertIn('AAPL', result['embeds'][0]['title'])

    def test_other_bot_application_is_rejected_offline(self):
        from bot import Config, create_client
        with self.assertRaises(ValueError):
            create_client(Config(1561042929265418393, 1561044080698331337))


if __name__ == '__main__':
    unittest.main()
