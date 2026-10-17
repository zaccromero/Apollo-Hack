import http.client
import json
import threading
import unittest
from backend.server import Adapter, ApolloServer

class ServerBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.server = ApolloServer(('127.0.0.1', 0), {'paper': Adapter('paper'), 'research': Adapter('research')})
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.http = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
    def tearDown(self):
        self.http.close(); self.server.shutdown(); self.server.server_close(); self.thread.join()
    def request(self, method, path, body=None, headers={}):
        self.http.request(method, path, body, headers)
        response = self.http.getresponse()
        return response.status, json.loads(response.read())
    def test_health_does_not_promote_missing_adapters(self):
        status, value = self.request('GET', '/health')
        self.assertEqual(status, 200)
        self.assertEqual(value['adapters']['paper']['status'], 'unavailable')
        self.assertEqual(self.request('GET', '/paper/state')[0], 503)
    def test_bad_input_is_rejected_before_business_adapter(self):
        for raw in ('[]', '{', '{"amount":NaN}'):
            with self.subTest(raw=raw):
                self.assertEqual(self.request('POST', '/paper/orders/preview', raw, {'Content-Type':'application/json'})[0], 400)
        self.assertEqual(self.request('POST', '/paper/orders/preview', '{}', {'Content-Type':'text/plain'})[0], 415)
    def test_adapters_keep_status_and_never_leak_exceptions(self):
        class Failure:
            def handle(self, *args):
                raise RuntimeError('private internal detail')
        self.server.services['paper'].api=Failure()
        self.assertEqual(self.request('GET', '/paper/state'), (500, {'error':'adapter_failed','adapter':'paper'}))

    def test_real_research_query_is_preserved(self):
        from backend.research import ResearchAPI
        self.server.services['research'].api=ResearchAPI()
        status,value=self.request('GET','/research/catalog?kind=crypto')
        self.assertEqual(status,200)
        self.assertEqual([item['asset_id'] for item in value['assets']],['BTC-USD'])
        status,value=self.request('GET','/research/assets/AAPL/analysis?thesis=Preserved%20hypothesis')
        self.assertEqual(status,200)
        self.assertEqual(value['thesis'],'Preserved hypothesis')

if __name__ == '__main__': unittest.main()
