"""Bounded official-source content observations; no generated tips or sentiment."""
import hashlib,ipaddress,json,re,socket,time
from datetime import datetime,timezone
from html.parser import HTMLParser
from urllib.request import Request,build_opener,ProxyHandler
from .fresh import SOURCES,MAX_BYTES,TIMEOUT,NoRedirect,metadata,now
LEADERSHIP='https://www.apple.com/leadership/john-ternus/'
class VisibleText(HTMLParser):
 def __init__(self):super().__init__(convert_charrefs=True);self.skip=0;self.parts=[]
 def handle_starttag(self,t,a):
  if t in ('script','style','noscript','template'):self.skip+=1
 def handle_endtag(self,t):
  if t in ('script','style','noscript','template') and self.skip:self.skip-=1
 def handle_data(self,d):
  if not self.skip:self.parts.append(d)
 def text(self):return ' '.join(' '.join(self.parts).split())
def _transport(url,allowed):
 if url not in allowed:raise ValueError('URL not in current job allowlist')
 from urllib.parse import urlsplit
 host=urlsplit(url).hostname;addrs=socket.getaddrinfo(host,443,type=socket.SOCK_STREAM)
 if not addrs or any(not ipaddress.ip_address(a[4][0]).is_global for a in addrs):raise ValueError('Nonpublic source address')
 req=Request(url,headers={'User-Agent':'ApolloResearch/2.0 public-source-content','Accept-Encoding':'identity'})
 with build_opener(ProxyHandler({}),NoRedirect()).open(req,timeout=TIMEOUT) as response:
  mime=response.headers.get_content_type()
  if mime not in ('text/html','application/xhtml+xml','application/rss+xml','application/atom+xml','text/xml','application/xml'):raise ValueError('Unsupported source type')
  if response.headers.get('Content-Encoding','identity').lower()!='identity':raise ValueError('Compressed response unsupported')
  started=time.monotonic();body=bytearray()
  while True:
   part=response.read(min(16384,MAX_BYTES+1-len(body)));body.extend(part)
   if len(body)>MAX_BYTES or time.monotonic()-started>TIMEOUT:raise ValueError('Source budget exceeded')
   if not part:break
  return bytes(body),mime

def _excerpt(raw,asset_id,role):
 p=VisibleText();p.feed(raw.decode('utf8',errors='replace'));text=p.text()
 anchors={'SPY':['The State Street','SPDR'],'BTC-USD':['Bitcoin is a consensus network'], 'leadership':['John Ternus is','John Ternus Chief','Chief Executive Officer']}
 if role=='leadership':keys=anchors['leadership']
 elif role=='article':keys=['CUPERTINO','Apple today','Apple introduced','Apple announced','Apple is','Apple']
 else:keys=anchors.get(asset_id,[])
 for key in keys:
  i=text.find(key)
  if i>=0:
   # A short contiguous quote, not a paraphrase or claim that missing text was read.
   fragment=text[i:].split(' Press Contacts')[0];words=fragment.split()[:20]
   if len(words)>=5:return ' '.join(words)
 return None

def fresh_research(asset_id,on_progress=None,*,_fetch=None):
 if not isinstance(asset_id,str) or asset_id not in SOURCES:raise ValueError('Unsupported fresh-research asset ID')
 kind,name,base,source_kind=SOURCES[asset_id];allowed={base};events=[];receipts=[];sources=[];observations=[];started=time.monotonic();attempts=0
 def emit(stage,**info):
  e={'asset_id':asset_id,'at':now(),**info};events.append({'stage':stage,**e})
  if on_progress:
   try:on_progress(stage,dict(e))
   except Exception:raise RuntimeError('progress_callback_failed') from None
 def read(url,role):
  nonlocal attempts
  if attempts>=4 or time.monotonic()-started>45:raise RuntimeError('job_budget_exceeded')
  attempts+=1;emit('fetchstarted',source_url=url)
  try:
   raw,mime=(_fetch(url) if _fetch else _transport(url,allowed))
   if len(raw)>MAX_BYTES:raise ValueError('Source too large')
   emit('fetchcompleted',source_url=url,bytes=len(raw),http_status=200,content_type=mime)
   fetched=now();digest=hashlib.sha256(raw).hexdigest()
   receipts.append({'url':url,'sha256':digest,'checked':True,'fetched_at':fetched,'bytes':len(raw),'http_status':200,'role':role})
   return raw,fetched
  except (OSError,ValueError) as exc:
   receipts.append({'url':url,'checked':False,'error_code':type(exc).__name__,'fetched_at':None,'role':role})
   emit('sourcechecked',source_url=url,check='failed',error_code=type(exc).__name__)
   return None,None
 def observe(url,raw,fetched,role,published=None,title=None):
  quote=_excerpt(raw,asset_id,role)
  if not quote:
   emit('sourcechecked',source_url=url,check='no_supported_content_excerpt');return
  sid='CONTENT-'+str(len(sources)+1);track='leadership' if role=='leadership' else 'promises_results'
  source={'id':sid,'title':title or ('Official leadership profile' if role=='leadership' else name+' official source content'),'url':url,'fetch_url':url,'date':(published or fetched)[:10],'date_kind':None if published else 'reviewed_at','published_at':published,'fetched_at':fetched,'kind':'official_source_excerpt','text':quote,'verbatim_quote':True,'excerpt_words':len(quote.split()),'article_body_reviewed':role=='article'}
  sources.append(source);observations.append({'source_id':sid,'track':track,'quote':quote,'attribution':'Issuer/project statement; not independent verification','interpretation':'This describes what the source says, not a verified investment outcome.','unknowns':'Financial materiality, valuation, causality and future performance are not established.'})
  emit('sourcechecked',source_url=url,check='attributed_content_excerpt',source_id=sid,fetched_at=fetched)
 raw,fetched=read(base,'feed' if asset_id=='AAPL' else 'document')
 if raw is not None:
  if asset_id=='AAPL':
   try:items=metadata(raw,source_kind)
   except (ValueError,SyntaxError):items=[]
   emit('sourcechecked',source_url=base,check='feed_metadata_only; not business facts')
   if items:
    article=items[0]['url']
    if re.fullmatch(r'https://www\.apple\.com/newsroom/\d{4}/\d{2}/[a-z0-9-]+/',article):
     allowed.add(article);ar,at=read(article,'article')
     if ar is not None:observe(article,ar,at,'article',items[0]['published_at'],items[0]['title'])
   allowed.add(LEADERSHIP);lr,lt=read(LEADERSHIP,'leadership')
   if lr is not None:observe(LEADERSHIP,lr,lt,'leadership')
  else:observe(base,raw,fetched,'document')
 tracks=[]
 for key,title in [('leadership','Leadership'),('promises_results','Promises vs results'),('public_sentiment','Public sentiment')]:
  selected=[o for o in observations if o['track']==key];ids=[o['source_id'] for o in selected]
  body='\n\n'.join('Official-source excerpt ['+o['source_id']+']: “'+o['quote']+'…”\n'+o['attribution'] for o in selected)
  tracks.append({'key':key,'title':title,'headline':'Fresh attributed source content; implications unverified.' if selected else 'No fresh evidence collected for this track.','body':body or 'Unknown; no source sample collected.','status':'Official statement observed' if selected else 'Unknown','caveat':'A source statement is not independent corroboration, a causal explanation, a full promise/result comparison, or a recommendation. No public-sentiment sample was collected.','sources':ids})
 corpus=hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest();success=bool(observations);finished=now()
 detail={'asset_id':asset_id,'name':name,'kind':kind,'evidence_tracks':tracks,'sources':sources,'evidence_cutoff':finished,'corpus_hash':corpus,'paid_api_calls':False,'quote':{'status':'not_fetched','live':False},'demo_asset':False}
 analysis={'asset_id':asset_id,'corpus_hash':corpus,'evidence_tracks':tracks,'sources':sources,'paid_api_calls':False,'opposing_evidence':{'supports_caution':None,'counterevidence':None,'limits':'Attributed official observations only; no directional thesis, independent corroboration or comprehensive research verdict.'}}
 receipt={'asset_id':asset_id,'mode':'fresh_public_source_read','version':2,'fresh_web_fetch':any(r['checked'] for r in receipts),'status':'fetched_content' if success else 'blocked','paid_calls':0,'historical_corpus_used':False,'sources_attempted':attempts,'sources_succeeded':sum(r['checked'] for r in receipts),'source_receipts':receipts,'fetched_at':finished if success else None,'observations':observations,'events':events,'limits':'At most4HTTPreads;45s checked between reads including callback time; socket5s/source and256KiB. DNS resolution uses system resolver, not a preemptive hard process deadline.'}
 emit('formatted',check='attributed_content; unknown implications and sentiment') if success else emit('blocked',check='no_supported_source_content')
 return {'detail':detail,'analysis':analysis,'receipt':receipt}

def format_fresh_brief(result):
 from .fresh import format_fresh_brief as metadata_format
 from .discord_brief import _text
 payload=metadata_format(result);payload['embeds'][0]['title']=result['detail']['asset_id']+' · fresh official-source observations'
 payload['embeds'][0]['description']='Actual official pages fetched and short attributed excerpts extracted. Publication and observation dates remain distinct. These are source statements, not verified investment conclusions.' if result['receipt']['status']!='blocked' else 'No supported fresh-source content is available. Failed or inaccessible sources remain explicit; no cached claims are substituted.'
 for embed,track in zip(payload['embeds'][1:],result['detail']['evidence_tracks']):
  if track['key']=='public_sentiment':embed['description']='Unknown. No public-sentiment sample was collected; no consensus or sentiment percentage is inferred.'
  else:
   linkpart=embed['description'].split('\n\n')[-1]
   embed['description']=(track['status']+'\n\n'+_text(track['body'],1600)+'\n\nInterpretation: Official-source statements only; no verified valuation, causality or recommendation.\n\nCounterevidence: Not independently researched in this bounded job.\n\nUnknowns: Completeness, future performance and wider market context.\n\n'+linkpart)
 payload['content']='Fresh official-source CONTENT read · attributed excerpts · not comprehensive analysis or investment advice.' if result['receipt']['status']!='blocked' else 'Fresh content retrieval BLOCKED · no cached claims substituted.'
 return payload
