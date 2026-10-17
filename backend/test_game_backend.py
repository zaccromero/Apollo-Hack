"""Focused real HTTP-to-SQLite journey, using disposable paper-only state."""
from decimal import Decimal
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest
from backend.server import Adapter, ApolloServer
from backend.paper import PaperAPI, PaperService

class PaperHTTPJourneyTests(unittest.TestCase):
    def test_all_instrument_types_confirmation_persistence_and_copy(self):
        with tempfile.TemporaryDirectory(prefix='apollo-http-test-') as directory:
            db=Path(directory)/'isolated.sqlite'
            service=PaperService(db, initial_cash='10000.00')
            server=ApolloServer(('127.0.0.1',0),{'paper':Adapter('paper',PaperAPI(service))})
            worker=threading.Thread(target=server.serve_forever,daemon=True);worker.start()
            connection=http.client.HTTPConnection('127.0.0.1',server.server_port,timeout=5)
            def call(method,path,body=None):
                connection.request(method,path,json.dumps(body) if body is not None else None,{'Content-Type':'application/json'})
                response=connection.getresponse();return response.status,json.loads(response.read())
            try:
                status,catalog=call('GET','/paper/catalog');self.assertEqual(status,200)
                self.assertEqual(len(catalog['assets']),9)
                self.assertEqual(call('POST','/paper/orders/preview',{'asset_id':'AAPL','quantity':'1','client_request_id':'profile-required'})[0],409)
                self.assertEqual(call('POST','/paper/profile',{'tolerance':'adventurous','confirmed':False})[0],400)
                self.assertEqual(call('POST','/paper/profile',{'tolerance':'adventurous','confirmed':True})[0],200)
                for asset,quantity in [('AAPL','1'),('WINA','1'),('SPY','0.1'),('GLD','0.1'),('BTC-USD','0.001'),('VNQ','1'),('AAPL_20261120_C350_DEMO','1'),('USDC-USD_DEMO','2.5'),('DEMO_USD_BOND_20281115','1')]:
                    with self.subTest(asset=asset):
                        request={'asset_id':asset,'quantity':quantity,'client_request_id':'http-'+asset,'thesis':{'reason':'Practice exact asset identity','risk':'Can lose value','invalidation':'Evidence changes'}}
                        before=Decimal(call('GET','/paper/state')[1]['cash'])
                        status,preview=call('POST','/paper/orders/preview',request);self.assertEqual(status,200,preview)
                        self.assertEqual(Decimal(call('GET','/paper/state')[1]['cash']),before)
                        self.assertTrue(preview['lines'][0]['provenance']['is_demo'])
                        if asset.startswith('AAPL_'):
                            self.assertEqual(preview['lines'][0]['multiplier'],100)
                            self.assertEqual(Decimal(preview['total']),Decimal('500'))
                        endpoint='/paper/orders/'+preview['order_id']+'/confirm'
                        self.assertEqual(call('POST',endpoint,{'confirmed':False})[0],400)
                        status,confirmed=call('POST',endpoint,{'confirmed':True});self.assertEqual(status,200)
                        self.assertEqual(call('POST',endpoint,{'confirmed':True})[1],confirmed)
                        self.assertEqual(Decimal(call('GET','/paper/state')[1]['cash']),before-Decimal(preview['total']))
                for action in ['pass','watchlist','interest']:
                    self.assertEqual(call('POST','/paper/decisions',{'asset_id':'AAPL','action':action,'thesis':{'reason':'Practice','risk':'Loss','invalidation':'New facts'}})[0],200)
                before=call('GET','/paper/state')[1]
                status,preview=call('POST','/paper/copy/preview',{'strategy_id':'DEMO_PATIENT_BUILDER','budget':'250','client_request_id':'http-copy'});self.assertEqual(status,200,preview)
                self.assertEqual({line['asset_id'] for line in preview['lines']},{'SPY','GLD','BTC-USD'})
                self.assertEqual(call('POST','/paper/orders/'+preview['order_id']+'/confirm',{'confirmed':True})[0],200)
                final=call('GET','/paper/state')[1]
                self.assertEqual(Decimal(final['cash']),Decimal(before['cash'])-Decimal(preview['total']))
                self.assertEqual(len(final['transactions']),10)
                reopened=PaperService(db, initial_cash='10000.00').state()
                self.assertEqual(reopened['cash'],final['cash'])
                self.assertEqual(reopened['positions'],final['positions'])
                self.assertTrue(reopened['watchlist'])
                self.assertEqual(call('POST','/paper/orders/preview',{'asset_id':'DEMO_PATIENT_BUILDER','quantity':'1','client_request_id':'not-a-security'})[0],404)
                self.assertEqual(call('POST','/paper/orders/preview',{'asset_id':'AAPL_20261120_C350_DEMO','quantity':'0.5','client_request_id':'fractional-option'})[0],400)
                self.assertEqual(call('POST','/paper/orders/preview',{'asset_id':'AAPL','quantity':'100000','client_request_id':'insufficient'})[0],409)
            finally:
                connection.close();server.shutdown();server.server_close();worker.join()

if __name__=='__main__': unittest.main()
