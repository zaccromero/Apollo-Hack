"""Fresh primary-source metadata, never paid models or historical-corpus blending."""
import hashlib,ipaddress,json,socket,time
from datetime import datetime,timezone
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from urllib.request import Request,build_opener,HTTPRedirectHandler,ProxyHandler
from urllib.parse import urlsplit
from urllib.error import HTTPError,URLError
from xml.etree import ElementTree as ET
SOURCES={'AAPL':('stock','Apple','https://www.apple.com/newsroom/rss-feed.rss','issuer_news_feed'),'SPY':('etf','SPDR S&P 500 ETF Trust','https://www.ssga.com/us/en/individual/etfs/state-street-spdr-sp-500-etf-trust-spy','issuer_document'),'BTC-USD':('crypto','Bitcoin','https://bitcoin.org/en/faq','project_document')}
MAX_BYTES=262144
TIMEOUT=5
TRACKS=[('leadership','Leadership'),('promises_results','Promises vs results'),('public_sentiment','Public sentiment')]
def now():return datetime.now(timezone.utc).isoformat()
class NoRedirect(HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs):raise ValueError('redirect_not_permitted')
def fetch_source(url):
 if url not in {v[2] for v in SOURCES.values()}:raise ValueError('source_not_allowlisted')
 host=urlsplit(url).hostname;addresses=socket.getaddrinfo(host,443,type=socket.SOCK_STREAM)
 if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses):raise ValueError('nonpublic_source_address')
 req=Request(url,headers={'User-Agent':'ApolloResearch/1.0 public-source-metadata','Accept-Encoding':'identity'})
 started=time.monotonic()
 with build_opener(ProxyHandler({}),NoRedirect()).open(req,timeout=TIMEOUT) as response:
  mime=response.headers.get_content_type()
  if mime not in ('text/html','application/xhtml+xml','application/rss+xml','application/atom+xml','application/xml','text/xml'):raise ValueError('unsupported_content_type')
  if response.headers.get('Content-Encoding','identity').lower()!='identity':raise ValueError('compressed_response_not_permitted')
  raw=bytearray()
  while True:
   chunk=response.read(min(16384,MAX_BYTES+1-len(raw)));raw.extend(chunk)
   if len(raw)>MAX_BYTES:raise ValueError('source_too_large')
   if time.monotonic()-started>TIMEOUT:raise ValueError('source_deadline_exceeded')
   if not chunk:break
  return bytes(raw),mime
class TitleParser(HTMLParser):
 def __init__(self):super().__init__(convert_charrefs=True);self.inside=False;self.title=''
 def handle_starttag(self,tag,attrs):
  if tag=='title':self.inside=True
 def handle_endtag(self,tag):
  if tag=='title':self.inside=False
 def handle_data(self,data):
  if self.inside:self.title+=data

def metadata(raw,source_kind):
 if b'<!ENTITY' in raw.upper() or (source_kind=='issuer_news_feed' and b'<!DOCTYPE' in raw.upper()):raise ValueError('unsafe_xml_declaration')
 if source_kind!='issuer_news_feed':
  p=TitleParser();p.feed(raw.decode('utf-8',errors='replace'));title=' '.join(p.title.split())[:100]
  if not title:raise ValueError('missing_document_title')
  return [{'title':title,'published_at':None}]
 rows=[]
 for item in ET.fromstring(raw).iter():
  if item.tag.split('}')[-1] not in ('item','entry'):continue
  c={x.tag.split('}')[-1]:x for x in item};title=''.join(c['title'].itertext()).strip() if 'title' in c else '';linknode=next((x for x in item if x.tag.split('}')[-1]=='link' and x.get('rel','alternate')=='alternate' and x.get('type','text/html')=='text/html'),None)
  link=(linknode.get('href') or linknode.text or '') if linknode is not None else '';u=urlsplit(link)
  if not title or u.scheme!='https' or u.hostname!='www.apple.com' or not u.path.startswith('/newsroom/') or u.path.startswith('/newsroom/images/') or u.username or u.password:continue
  dn=next((c[k] for k in ('published','pubDate','updated') if k in c),None);published=None
  if dn is not None and dn.text:
   try:
    dt=datetime.fromisoformat(dn.text.replace('Z','+00:00')) if dn.text[:4].isdigit() else parsedate_to_datetime(dn.text)
    if dt.tzinfo and dt<=datetime.now(timezone.utc):published=dt.isoformat()
   except (ValueError,TypeError):pass
  rows.append({'title':' '.join(title.split())[:100],'url':link,'published_at':published,'article_body_reviewed':False})
  if len(rows)==2:break
 if not rows:raise ValueError('no_valid_feed_items')
 return rows

def fresh_research(asset_id,on_progress=None,*,_fetch=None):
 if not isinstance(asset_id,str) or asset_id not in SOURCES:raise ValueError('Unsupported fresh-research asset ID')
 kind,name,url,source_kind=SOURCES[asset_id];events=[];sources=[]
 def emit(stage,**info):
  info={'asset_id':asset_id,'source_url':url,'at':now(),**info};events.append({'stage':stage,**info})
  if on_progress:
   try:on_progress(stage,dict(info))
   except Exception:raise RuntimeError('progress_callback_failed') from None
 receipt={'asset_id':asset_id,'mode':'fresh_public_source_read','paid_calls':0,'fresh_web_fetch':False,'sources_attempted':1,'sources_succeeded':0,'source_receipts':[],'events':events,'fetched_at':None,'historical_corpus_used':False,'market_prices_fetched':False,'scope':'Fresh HTTP metadata, not newly published news, full article review, market-wide search or sentiment measurement.'}
 emit('fetchstarted')
 try:
  raw,mime=(_fetch or fetch_source)(url)
  if len(raw)>MAX_BYTES:raise ValueError('source_too_large')
  emit('fetchcompleted',bytes=len(raw),http_status=200,content_type=mime)
  rows=metadata(raw,source_kind);fetched=now();digest=hashlib.sha256(raw).hexdigest()
  for i,row in enumerate(rows):
   pub=row.get('published_at');sources.append({'id':'FRESH-'+str(i+1),'title':row['title'],'url':row.get('url',url),'fetch_url':url,'article_body_reviewed':False,'date':(pub or fetched)[:10],'date_kind':None if pub else 'reviewed_at','published_at':pub,'fetched_at':fetched,'kind':source_kind,'text':'Observed source title: '+row['title']+'. Investment implications and full article claims have not been verified.'})
  receipt.update(status='fetched_metadata',fresh_web_fetch=True,sources_succeeded=1,fetched_at=fetched,source_receipts=[{'url':url,'sha256':digest,'checked':True,'bytes':len(raw),'http_status':200,'content_type':mime,'fetched_at':fetched}],observations=rows)
  emit('sourcechecked',source_count=len(sources),fetched_at=fetched,check='metadata_only; article bodies not reviewed')
 except (ValueError,OSError,HTTPError,URLError,ET.ParseError) as exc:
  # No raw exception bodies/headers/URLs are reflected into public progress.
  code=type(exc).__name__;receipt.update(status='blocked',error_code=code,observations=[]);emit('blocked',check=code)
 tracks=[]
 for key,title in TRACKS:
  observed=key=='promises_results' and bool(sources)
  tracks.append({'key':key,'title':title,'headline':'Fresh source metadata only; no verified promise/result comparison.' if observed else 'Unknown from this bounded source read.','body':'\n'.join(s['text'] for s in sources) if observed else 'No reviewed evidence collected for this track.','status':'Metadata observed; implications unverified' if observed else 'Unknown','caveat':'No broad market scan, causal link, measured sentiment, valuation or trade recommendation. Fresh read does not mean new publication or complete coverage.','sources':[s['id'] for s in sources] if observed else []})
 corpus=hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest()
 detail={'asset_id':asset_id,'name':name,'kind':kind,'evidence_tracks':tracks,'sources':sources,'evidence_cutoff':receipt['fetched_at'],'corpus_hash':corpus,'paid_api_calls':False,'quote':{'status':'not_fetched','live':False},'demo_asset':False}
 analysis={'asset_id':asset_id,'corpus_hash':corpus,'evidence_tracks':tracks,'sources':sources,'paid_api_calls':False,'opposing_evidence':{'supports_caution':None,'counterevidence':None,'limits':'Only source metadata was freshly checked; no directional thesis or counter-thesis was established.'}}
 if receipt['status']!='blocked':emit('formatted',check='fresh metadata; not full article analysis')
 return {'detail':detail,'analysis':analysis,'receipt':receipt}

def format_fresh_brief(result):
 from .discord_brief import format_brief
 payload=format_brief(result['detail'],result['analysis'])
 r=result['receipt'];payload['content']='Fresh public-source HTTP read · metadata only · not investment advice.' if r['fresh_web_fetch'] else 'Fresh retrieval BLOCKED · no cached evidence substituted.'
 payload['embeds'][0]['title']=result['detail']['asset_id']+' · fresh source metadata'
 payload['embeds'][0]['description']='Fetched at: '+str(r['fetched_at'])+'. Source dates below distinguish publication from observed review. This job performed a fresh HTTP read, not full article verification or a representative sentiment survey.' if r['fresh_web_fetch'] else 'The allowlisted source could not be read and checked. No fresh claims or cached source substitutions are presented.'
 return payload
