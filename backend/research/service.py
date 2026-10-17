"""Read-only research adapter. Does not trade, write Plutus, fetch or call models."""
import copy,json,sqlite3,math
from datetime import datetime,date,timedelta,timezone
from decimal import Decimal,InvalidOperation
from pathlib import Path
from urllib.parse import urlsplit
from .reasoning import reasoning_tracks

HERE=Path(__file__).resolve().parent
KINDS=('stock','etf','commodity','crypto','real_estate','option','strategy')
TRACKS=(('leadership','Leadership'),('promises_results','Promises vs results'),('public_sentiment','Public sentiment'))

def utc():return datetime.now(timezone.utc)
def decimal(value):
 try:
  if len(str(value))>100:raise ValueError('Financial value too long')
  n=Decimal(str(value))
 except (InvalidOperation,TypeError,ValueError):raise ValueError('Invalid financial value') from None
 if not n.is_finite() or n<=0 or n>Decimal('1000000000000') or n.as_tuple().exponent < -18:raise ValueError('Financial value must be finite, positive and bounded')
 return format(n,'f')
def public_url(value):
 try:
  p=urlsplit(str(value))
  return str(value) if p.scheme in ('https','http') and p.hostname and not p.username and not p.password else None
 except ValueError:return None
def source(identifier,url,text):return {'id':identifier,'date':'2026-10-17','date_kind':'reviewed_at','title':'Issuer exposure description','kind':'issuer_description','url':url,'text':text}

CATALOG=[
 {'asset_id':'AAPL','symbol':'AAPL','name':'Apple','kind':'stock','instrument_type':'equity','risk_tags':['single_company','valuation','execution'],'demo_price':'250.00'},
 {'asset_id':'WINA','symbol':'WINA','name':'Winmark','kind':'stock','instrument_type':'equity','risk_tags':['single_company','small_company','franchise_execution'],'demo_price':'400.00'},
 {'asset_id':'SPY','symbol':'SPY','name':'State Street SPDR S&P 500 ETF Trust','kind':'etf','instrument_type':'fund_share','risk_tags':['equity_market','index_concentration','tracking_error'],'demo_price':'600.00',
  'description':'Index fund exposure; diversification does not eliminate equity losses.',
  'issuer_source':source('SPY-ISSUER','https://www.ssga.com/us/en/individual/etfs/state-street-spdr-sp-500-etf-trust-spy','The fund seeks, before expenses, to track the S&P 500 Index. This describes its objective, not a return guarantee.')},
 {'asset_id':'GLD','symbol':'GLD','name':'SPDR Gold Shares','kind':'commodity','instrument_type':'gold_trust_share','risk_tags':['gold_price','no_operating_income','trust_expenses'],'demo_price':'300.00',
  'description':'Gold trust shares, not direct possession of gold bars.',
  'issuer_source':source('GLD-ISSUER','https://www.spdrgoldshares.com/usa/gld/','The trust seeks to reflect gold bullion performance less expenses. A share is not direct delivery of a personal gold bar.')},
 {'asset_id':'BTC-USD','symbol':'BTC-USD','name':'Bitcoin exposure','kind':'crypto','instrument_type':'coin','risk_tags':['high_volatility','custody','continuous_market','regulatory_uncertainty'],'demo_price':'100000.00','description':'Educational crypto exposure. No verified current quote or investment thesis supplied.'},
 {'asset_id':'VNQ','symbol':'VNQ','name':'Vanguard Real Estate ETF','kind':'real_estate','instrument_type':'real_estate_fund_share','risk_tags':['real_estate_sector','interest_rates','equity_liquidity'],'demo_price':'90.00',
  'description':'Listed real-estate fund exposure, not ownership of a particular property.',
  'issuer_source':source('VNQ-ISSUER','https://advisors.vanguard.com/investments/products/vnq/vanguard-real-estate-etf','Vanguard identifies VNQ as its Real Estate ETF; the fund has real-estate sector exposure. No current holdings, yield or performance has been verified here.')},
 {'asset_id':'AAPL_20261120_C350_DEMO','symbol':'AAPL DEMO CALL','name':'Apple call — fictional contract','kind':'option','instrument_type':'option_contract','risk_tags':['expiry','leverage','premium_total_loss','underlying_price','wide_spreads'],'demo_price':'5.00','demo_asset':True,
  'description':'Synthetic educational long-call fixture. Not a verified listed contract or market premium.',
  'option':{'underlying_asset_id':'AAPL','option_type':'call','put_call':'C','strike':'350.00','expiry':'2026-11-20','expires_at':'2026-11-20T21:00:00+00:00','contract_multiplier':100,'premium_unit':'per_underlying_share','position_unit':'contract','exercise':'not_simulated','maximum_loss_rule':'For a fully paid long call, premium × multiplier × contracts; no exercise or short options.'}},
 {'asset_id':'DEMO_PATIENT_BUILDER','symbol':'DEMO BUILDER','name':'Alex Rivera — fictional Patient Builder','kind':'strategy','instrument_type':'people_portfolio_demo','risk_tags':['copying_lag','allocation_drift','unknown_track_record','underlying_asset_risk'],'demo_asset':True,
  'description':'Fictional person and allocations for paper-copy learning. No claimed real investor, profitable creator or verified performance.',
  'allocations':[{'asset_id':'SPY','weight':'0.60'},{'asset_id':'GLD','weight':'0.20'},{'asset_id':'BTC-USD','weight':'0.20'}]}
]

LESSONS={
 'stock':('Can one growing segment alone prove the entire business is improving?',False,'Compare the whole company’s reported results and qualifications, not just one segment.'),
 'etf':('Does diversification guarantee that an equity fund cannot lose value?',False,'A diversified fund still carries market risk and can decline.'),
 'commodity':('Does this trust share give you personal possession of a gold bar?',False,'GLD is trust-share exposure; its structure and expenses differ from direct possession.'),
 'crypto':('Does a price chart remove custody and volatility risk?',False,'A chart describes prices; it does not remove custody, volatility or market risks.'),
 'real_estate':('Does this fund share give you direct ownership of a specific building?',False,'VNQ is listed fund exposure, not a deed to a particular property.'),
 'option':('Can a fully paid long call expire worthless?',True,'The premium can be lost. This fixture uses whole contracts and a100-share multiplier.'),
 'stablecoin':('Does a target USD peg guarantee redemption or prevent losses?',False,'A peg is a target, not cash or a redemption guarantee. Issuer, reserve, custody and depeg risks remain.'),
 'bond':('Does this fictional bond guarantee payment or a live market price?',False,'The demo terms are illustrative. Credit, rate and liquidity risks remain; no coupon settlement is promised.'),
 'strategy':('Does a fictional copy portfolio demonstrate a real person’s profitability?',False,'Fictional allocations have no verified track record. Copying also inherits underlying risks.')
}

class ResearchService:
 def __init__(self,plutus_root=None,*,now=None,include_expansion=False):
  self.plutus_root=Path(plutus_root) if plutus_root else Path('/Users/zaccromero/code/hackathon/plutus')
  self.now=now or utc
  self.reviewed=json.loads((HERE/'reviewed.json').read_text())
  self.market=json.loads((HERE/'market_snapshot.json').read_text())
  self.assets={a['asset_id']:copy.deepcopy(a) for a in CATALOG}
  if include_expansion:
   from .registry_extension import expansion_assets
   self.assets.update(expansion_assets())
 def _asset(self,asset_id):
  if not isinstance(asset_id,str) or asset_id not in self.assets:raise KeyError('Unknown asset_id')
  return copy.deepcopy(self.assets[asset_id])
 def _feed(self,symbol,kind='prices'):
  dbfile=self.plutus_root/'data/free-market.sqlite'
  if dbfile.is_file():
   try:
    c=sqlite3.connect(dbfile.as_uri()+'?mode=ro',uri=True,timeout=1);c.row_factory=sqlite3.Row
    try:row=c.execute("SELECT * FROM feeds WHERE symbol=? AND kind=?",(symbol,kind)).fetchone()
    finally:c.close()
    if row:
     row=dict(row);row['data']=json.loads(row.pop('payload') or '{}');row['cache_origin']='readonly_plutus_cache';return row
   except (sqlite3.Error,ValueError):pass
  row=copy.deepcopy(self.market['records'].get(symbol)) if kind=='prices' else None
  if row:row['cache_origin']='bundled_public_cache_snapshot'
  return row
 def _market(self,asset):
  if asset['kind']=='strategy':return {'quote':{'price':None,'currency':'USD','status':'not_applicable','provenance':'nontradable_strategy','stale':True},'chart':[]}
  feed=self._feed(asset['asset_id']);valid=[]
  if feed:
   d=feed['data']
   if isinstance(d,dict) and isinstance(d.get('bars'),list) and d.get('symbol')==asset['asset_id'] and d.get('currency')=='USD' and public_url(d.get('sourceUrl')):
    for bar in d.get('bars',[])[-60:]:
     try:
      day=date.fromisoformat(bar['time']);values={k:decimal(bar[k]) for k in ['open','high','low','close']}
      if day>self.now().date() or Decimal(values['low'])>min(Decimal(values[k]) for k in ['open','close']) or Decimal(values['high'])<max(Decimal(values[k]) for k in ['open','close']):continue
      valid.append({'date':day.isoformat(),**values,'volume':str(max(0,int(bar.get('volume',0))))})
     except (ValueError,TypeError,KeyError,InvalidOperation):continue
   if valid:
    valid=sorted({b['date']:b for b in valid}.values(),key=lambda b:b['date']);due=feed.get('due',0);stale=bool(feed.get('error')) or not isinstance(due,(int,float)) or not math.isfinite(due) or self.now().timestamp()>due
    return {'quote':{'price':valid[-1]['close'],'currency':'USD','as_of':valid[-1]['date'],'fetched_at':feed.get('succeeded'),'status':'cached_daily_close','provenance':feed['cache_origin'],'source_url':public_url(d.get('sourceUrl')),'stale':stale,'live':False,'note':'Cached daily close, not a live or executable quote.'},'chart':valid}
  # Explicit fixture values support paper mechanics, never masquerade as market facts.
  price=decimal(asset['demo_price']);base=Decimal(price);points=[]
  for j in range(20):
   value=base*(Decimal('0.96')+Decimal(j)*Decimal('0.04')/Decimal(19));points.append({'date':(self.now().date()-timedelta(days=19-j)).isoformat(),'close':format(value.quantize(Decimal('0.01')),'f'),'demo':True})
  return {'quote':{'price':price,'currency':'USD','as_of':None,'status':'demo_fixture','provenance':'synthetic_educational_fixture','stale':True,'live':False,'source_url':None,'note':'DEMO execution price and chart; no live quote verified.'},'chart':points}
 def _evidence(self,asset):
  saved=self.reviewed['records'].get(asset['asset_id'])
  if saved:return copy.deepcopy(saved['record'])
  issuer=asset.get('issuer_source');tracks=[]
  for key,title in TRACKS:
   known=bool(issuer and key=='promises_results')
   tracks.append({'key':key,'title':title,'headline':'Issuer objective verified; results unknown' if known else 'No reviewed evidence available','body':issuer['text'] if known else 'Unknown from the current reviewed record.','caveat':'An issuer objective is not delivered performance. No leadership attribution or investor consensus inferred.','status':'Issuer description only' if known else 'Unknown','sources':[issuer['id']] if known else []})
  return {'ticker':asset['asset_id'],'name':asset['name'],'cutoff':'2026-10-17' if issuer else None,'tracks':tracks,'sources':[issuer] if issuer else [],'curation':'Source-reviewed issuer description only' if issuer else 'No reviewed company evidence; fixture mechanics are separately labelled.'}
 def catalog(self,kind=None,query=''):
  if kind is not None and kind not in {a['kind'] for a in self.assets.values()}:raise ValueError('Unknown asset kind')
  if not isinstance(query,str) or len(query)>120:raise ValueError('Query must be a string up to120characters')
  items=[]
  for a in self.assets.values():
   if kind and a['kind']!=kind:continue
   if query.casefold() not in (a['name']+' '+a['symbol']).casefold():continue
   detail=self.details(a['asset_id']);items.append({k:detail[k] for k in ['asset_id','symbol','name','kind','instrument_type','tradable','paper_only','data_status','corpus_hash','quote','paper_quote','risk_tags','evidence_quality','demo_asset','allocations','option']})
  return {'schema_version':1,'as_of':self.now().isoformat(),'assets':items,'asset_kinds':list(dict.fromkeys(a['kind'] for a in self.assets.values())),'paid_api_calls':False,'real_trading':False}
 def details(self,asset_id):
  a=self._asset(asset_id);market=self._market(a);record=self._evidence(a);reviewed=bool(record['sources']);demo=bool(a.get('demo_asset'))
  if a.get('option'):a['option']['expired']=datetime.fromisoformat(a['option']['expires_at'])<=self.now()
  return {**{k:v for k,v in a.items() if k not in ['demo_price','issuer_source']},'tradable':a['kind']!='strategy' and not (a.get('option') or {}).get('expired',False),'paper_only':True,'demo_asset':demo,'allocations':a.get('allocations',[]),'option':a.get('option'),
   'data_status':'demo_fixture' if demo else ('mixed_reviewed_and_demo' if reviewed else 'demo_fixture') if market['quote']['status']=='demo_fixture' else 'reviewed_snapshot' if reviewed else 'unknown',
   **market,'paper_quote':{'price':a.get('demo_price'),'currency':'USD','status':'demo_fixture' if a['kind']!='strategy' else 'not_applicable','live':False,'provenance':'Illustrative paper engine seed; order preview is execution authority','note':'Separate from historical research quote. Request a paper preview before confirmation.'},'evidence_tracks':reasoning_tracks(record),'sources':record['sources'],'evidence_cutoff':record['cutoff'],'evidence_freshness':self._freshness(record),'evidence_quality':{'scope':'Evidence coverage, not probability of an investment outcome','reviewed_sources':len(record['sources']),'status':'source_reviewed_snapshot' if reviewed else 'unknown','missing':['live_executable_quote','valuation_or_entry_signal']+([] if reviewed else ['reviewed_business_evidence'])},
   'risk':{'tags':a['risk_tags'],'maximum_loss':'premium_times_multiplier_times_contracts' if a['kind']=='option' else 'Losses possible; no guaranteed outcome','leverage':a['kind']=='option','position_unit':'contract' if a['kind']=='option' else 'coin' if a['kind']=='crypto' else 'allocation' if a['kind']=='strategy' else a.get('quantity_unit','share'),'performance_verified':False},
   'unreviewed_discovery':self._discovery(asset_id),'learning':{'question':LESSONS[a['kind']][0],'correct_answer':LESSONS[a['kind']][1],'explanation':LESSONS[a['kind']][2]},'corpus_hash':record.get('corpus_hash'),'source_identity':self.reviewed['records'].get(asset_id,{}).get('source_sha256'),'analysis_available':True,'paid_api_calls':False}
 def _freshness(self,record):
  cutoff=record.get('cutoff');age=(self.now().date()-date.fromisoformat(cutoff)).days if cutoff else None
  return {'status':'dated_snapshot' if cutoff else 'unknown','review_cutoff':cutoff,'age_days':age,'stale':age>7 if age is not None else None,'policy':'Stale means more than seven days since the reviewed snapshot cutoff; it does not verify completeness or current company conditions. Source publication dates remain separate.','latest_updates_verified':False}
 def _discovery(self,asset_id):
  result={'news':[],'filings':[],'note':'Unreviewed cached headlines/filing metadata; no sentiment, earnings implication or causation inferred.'}
  for kind in ['news','filings']:
   feed=self._feed(asset_id,kind);data=(feed or {}).get('data')
   if not isinstance(data,dict):continue
   items=data.get('items',[])
   if not isinstance(items,list):continue
   for item in items[:8]:
    if not isinstance(item,dict):continue
    entry={k:item.get(k) for k in ['id','title','date','url','form']};entry['url']=public_url(entry.get('url'));result[kind].append(entry)
  return result
 def analysis(self,asset_id,thesis=''):
  if not isinstance(thesis,str) or len(thesis)>2400:raise ValueError('Thesis must be a string up to2400characters')
  a=self._asset(asset_id);r=self._evidence(a);review=r.get('evidence_review');sides={'supports_caution':None,'counterevidence':None,'limits':'Unknown: insufficient reviewed evidence for a directional thesis challenge.'};timeline=None
  if review:
   sides={k:copy.deepcopy(review[k]) for k in ['supports_caution','counterevidence','limits']};t=review['timeline'];end=date.fromisoformat(t['period_end']);start=date.fromisoformat(t['role_start']);timeline={'period_end':t['period_end'],'role_start':t['role_start'],'relation':'before' if end<start else 'after' if end>start else 'same_date','sources':t['sources'],'note':'Dates do not establish leadership causality.'}
  elif asset_id=='WINA':
   sides={'supports_caution':{'text':'Advertising fund revenue has matching expense; headline revenue growth is not all incremental profit. A delivered pilot is not a systemwide rollout.','sources':['S3','S4']},'counterevidence':{'text':'Reported quarterly net income, diluted EPS and royalties increased; delivered marketing actions are real, although causal attribution remains unknown.','sources':['S3','S4']},'limits':'Company results do not prove the stock is cheap or identify a successful entry time; future campaigns remain pending.'}
  return {'schema_version':1,'asset_id':asset_id,'thesis':thesis,'thesis_status':'User-supplied hypothesis, not verified evidence' if thesis else 'No personal thesis supplied','mode':'deterministic_source_review','evidence_tracks':reasoning_tracks(r),'sources':r['sources'],'opposing_evidence':sides,'leadership_timeline':timeline,'as_of':self.now().isoformat(),'evidence_cutoff':r['cutoff'],'corpus_hash':r.get('corpus_hash'),'decision':'educational_review_only','timing_signal':None,'guaranteed_return':False,'paid_api_calls':False,'learning_prompt':'Which source would change your view, and what risk could you be overlooking?','risk_tags':a['risk_tags'],'demo_asset':bool(a.get('demo_asset'))}
