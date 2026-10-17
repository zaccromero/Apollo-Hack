import json,sqlite3,tempfile,unittest,hashlib
from datetime import datetime,timezone
from decimal import Decimal
from pathlib import Path
from .service import ResearchService,KINDS
from .api import ResearchAPI

class ResearchTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.now=datetime(2026,10,17,15,30,tzinfo=timezone.utc);self.s=ResearchService(self.root,now=lambda:self.now)
 def tearDown(self):self.tmp.cleanup()
 def test_all_asset_classes_and_identity(self):
  catalog=self.s.catalog();self.assertEqual(set(a['kind'] for a in catalog['assets']),set(KINDS));self.assertEqual(len(catalog['assets']),8)
  self.assertFalse(catalog['real_trading']);self.assertFalse(catalog['paid_api_calls']);self.assertTrue(all(a['paper_only'] for a in catalog['assets']))
  self.assertEqual([a['asset_id'] for a in self.s.catalog(query='Winmark')['assets']],['WINA'])
  self.assertEqual(self.s.catalog('crypto')['assets'][0]['asset_id'],'BTC-USD');self.assertEqual(self.s.details('WINA')['corpus_hash'],'f4ac7c6b2702cf94b1176750ed262cc213a22418936d1060e01667885a1fc020')
 def test_option_and_people_cannot_be_treated_as_equity(self):
  option=self.s.details('AAPL_20261120_C350_DEMO');self.assertEqual(option['option']['contract_multiplier'],100);self.assertEqual(option['risk']['position_unit'],'contract');self.assertTrue(option['demo_asset']);self.assertEqual(option['quote']['status'],'demo_fixture')
  strategy=self.s.details('DEMO_PATIENT_BUILDER');self.assertFalse(strategy['tradable']);self.assertIsNone(strategy['quote']['price']);self.assertTrue(strategy['demo_asset']);self.assertEqual(sum(Decimal(a['weight']) for a in strategy['allocations']),Decimal(1))
 def test_unknown_evidence_is_not_invented_sentiment_or_live_quote(self):
  for asset in ['BTC-USD','AAPL_20261120_C350_DEMO','DEMO_PATIENT_BUILDER']:
   d=self.s.details(asset);self.assertFalse(d['sources']);self.assertTrue(all(not t['sources'] for t in d['evidence_tracks']));self.assertFalse(d['risk']['performance_verified'])
  self.assertEqual(self.s.details('BTC-USD')['data_status'],'demo_fixture');self.assertTrue(all(b['demo'] for b in self.s.details('BTC-USD')['chart']))
 def test_reviewed_apple_tracks_counterevidence_dates_and_personal_thesis(self):
  a=self.s.analysis('AAPL','DEMO hypothesis');self.assertEqual(a['leadership_timeline']['relation'],'before');self.assertIn('AAPL-R1',a['opposing_evidence']['supports_caution']['sources']);self.assertIn('AAPL-R2',a['opposing_evidence']['counterevidence']['sources'])
  self.assertEqual([t['key'] for t in a['evidence_tracks']],['leadership','promises_results','public_sentiment']);self.assertEqual(a['evidence_tracks'][2]['sources'],['AAPL-S1']);self.assertIn('not verified',a['thesis_status']);self.assertIsNone(a['timing_signal'])
  self.assertEqual(a['corpus_hash'],self.s.reviewed['records']['AAPL']['record']['corpus_hash']);self.assertNotIn('Winmark',json.dumps(a));self.assertNotIn('AAPL-',json.dumps(self.s.analysis('WINA')))
 def test_real_cached_quotes_are_historical_not_live_and_returns_are_copies(self):
  d=self.s.details('AAPL');self.assertEqual(d['quote']['status'],'cached_daily_close');self.assertFalse(d['quote']['live']);self.assertEqual(d['chart'][-1]['date'],'2026-10-16');Decimal(d['quote']['price'])
  d['evidence_tracks'][0]['body']='corrupted';self.assertNotEqual(self.s.details('AAPL')['evidence_tracks'][0]['body'],'corrupted')
 def test_live_cache_readonly_identity_and_staleness(self):
  (self.root/'data').mkdir();db=self.root/'data/free-market.sqlite';c=sqlite3.connect(db);c.execute('CREATE TABLE feeds(symbol TEXT,kind TEXT,payload TEXT,succeeded TEXT,error TEXT,due REAL)')
  payload={'symbol':'AAPL','currency':'USD','sourceUrl':'https://finance.yahoo.com/quote/AAPL/history/','bars':[{'time':'2026-10-16','open':100,'high':102,'low':99,'close':101,'volume':10}]}
  c.execute('INSERT INTO feeds VALUES(?,?,?,?,?,?)',('AAPL','prices',json.dumps(payload),self.now.isoformat(),None,self.now.timestamp()+300));c.commit();c.close();before=hashlib.sha256(db.read_bytes()).hexdigest()
  d=self.s.details('AAPL');self.assertEqual(d['quote']['price'],'101');self.assertFalse(d['quote']['stale']);self.assertEqual(hashlib.sha256(db.read_bytes()).hexdigest(),before)
  c=sqlite3.connect(db);c.execute("UPDATE feeds SET error='offline'");c.commit();c.close();self.assertTrue(self.s.details('AAPL')['quote']['stale'])
 def test_paper_fixture_prices_are_separate_from_historical_research(self):
  expected={'AAPL':'250.00','WINA':'400.00','SPY':'600.00','GLD':'300.00','BTC-USD':'100000.00','VNQ':'90.00','AAPL_20261120_C350_DEMO':'5.00'}
  for identifier,price in expected.items():
   d=self.s.details(identifier);self.assertEqual(d['paper_quote']['price'],price);self.assertEqual(d['paper_quote']['status'],'demo_fixture');self.assertFalse(d['paper_quote']['live']);self.assertTrue(d['learning']['explanation'])
  self.assertEqual(self.s.details('AAPL')['quote']['status'],'cached_daily_close')
 def test_expired_option_and_malformed_discovery_are_safe(self):
  old=ResearchService(self.root,now=lambda:datetime(2026,11,21,tzinfo=timezone.utc));self.assertFalse(old.details('AAPL_20261120_C350_DEMO')['tradable']);self.assertTrue(old.details('AAPL_20261120_C350_DEMO')['option']['expired'])
  from unittest.mock import patch
  with patch.object(self.s,'_feed',return_value={'data':{'items':None}}):self.assertEqual(self.s._discovery('AAPL')['news'],[])
 def test_malformed_prices_cannot_expand_unbounded_decimal_output(self):
  from .service import decimal
  for value in ['NaN','Infinity','1e999999999','0','-5','0.0000000000000000000001',True]:
   with self.subTest(value=value):
    with self.assertRaises(ValueError):decimal(value)
  self.assertEqual(decimal('0.00000001'),'0.00000001')
 def test_api_contract_errors_and_serializable_shapes(self):
  api=ResearchAPI(self.s)
  for method,path,body in [('GET','/research/catalog',None),('GET','/research/assets/AAPL',None),('GET','/research/assets/AAPL/analysis',None),('POST','/research/analysis',{'asset_id':'AAPL','thesis':'test'})]:
   status,result=api.handle(method,path,body);self.assertEqual(status,200);json.dumps(result,allow_nan=False)
  self.assertEqual(api.handle('GET','/research/assets/BOGUS')[0],404);self.assertEqual(api.handle('GET','/research/catalog?kind=garbage')[0],400);self.assertEqual(api.handle('POST','/research/analysis',{'asset_id':'AAPL','execute_trade':True})[0],400)

if __name__=='__main__':unittest.main()
