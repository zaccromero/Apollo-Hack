"""Durable public research jobs using bounded public source reads or reviewed local evidence; no paid providers."""
from __future__ import annotations
import asyncio
from contextlib import contextmanager
from datetime import date, datetime, timezone
import json
from pathlib import Path
import sqlite3
from urllib.parse import urlsplit
from zoneinfo import ZoneInfo

MARKETS={'stock':'Stocks','etf':'ETFs','commodity':'Commodities','crypto':'Crypto',
         'real_estate':'Real estate','option':'Options','strategy':'Strategies',
         'stablecoin':'Stablecoins','bond':'Bonds'}
STAGES={'QUEUED':'Queued','CREATING_THREAD':'Opening forum post','LOADED':'Reviewed record loaded',
        'CHECKED':'Provenance checked','ANALYZED':'Reviewed analysis prepared','FORMATTED':'Three tracks formatted',
        'POSTING_RESULT':'Publishing result','PUBLISHED':'Published · read-back verified','BLOCKED':'Blocked'}
STAGES.update({'FETCH_STARTED':'Fetching public source','FETCH_COMPLETED':'Public source received',
               'SOURCE_CHECKED':'Source content and provenance checked','SOURCE_FAILED':'Source read failed','SOURCE_GAP':'No supported source excerpt','FRESH_FORMATTED':'Fresh-read brief prepared'})
FRESH_STAGES={'fetchstarted':'FETCH_STARTED','fetchcompleted':'FETCH_COMPLETED',
              'sourcechecked':'SOURCE_CHECKED','formatted':'FRESH_FORMATTED','blocked':'BLOCKED'}
FRESH_ASSETS={'AAPL','SPY','BTC-USD'}
PROGRESS_TIMEOUT=30
TERMINAL={'PUBLISHED','BLOCKED'}
EXPANDED={'USDC-USD_DEMO','DEMO_USD_BOND_20281115'}


def now():return datetime.now(timezone.utc).isoformat(timespec='milliseconds')


def research_service(asset_id):
    import sys
    root=str(Path(__file__).resolve().parents[2])
    if root not in sys.path:sys.path.insert(0,root)
    from backend.research import ResearchService
    return ResearchService(include_expansion=True) if asset_id in EXPANDED else ResearchService()


def resolve_asset(asset_id):
    if not isinstance(asset_id,str) or len(asset_id)>80:raise ValueError('Invalid asset')
    asset_id=asset_id.upper().strip()
    service=research_service(asset_id)
    assets={a['asset_id']:a for a in service.catalog()['assets']}
    if asset_id not in assets:raise ValueError('Use an exact supported asset ID')
    asset=assets[asset_id]
    if asset['kind'] not in MARKETS:raise ValueError('Unsupported market')
    return service,asset


def check_provenance(detail):
    if not detail.get('asset_id') or detail.get('kind') not in MARKETS:raise ValueError('Invalid asset identity')
    sources=detail.get('sources',[]);ids=[s['id'] for s in sources]
    if len(ids)!=len(set(ids)):raise ValueError('Duplicate source identity')
    for source in sources:
        if source.get('date'):date.fromisoformat(str(source['date']))
        if source.get('date_kind') not in (None,'reviewed_at'):raise ValueError('Unrecognized source date meaning')
        p=urlsplit(source.get('url',''))
        if p.scheme not in ('https','http') or not p.hostname or p.username or p.password:
            raise ValueError('Invalid reviewed source URL')
        if any(c in source['url'] for c in '\r\n<> \\'):raise ValueError('Invalid source link')
    tracks=detail.get('evidence_tracks',[])
    if {t.get('key') for t in tracks}!={'leadership','promises_results','public_sentiment'}:
        raise ValueError('Three separate evidence tracks required')
    for track in tracks:
        if not set(track.get('sources',[]))<=set(ids):raise ValueError('Unbound source reference')
    missing=[t['title'] for t in tracks if not t.get('sources')]
    quote=detail.get('quote',{})
    return {'source_count':len(sources),'evidence_cutoff':detail.get('evidence_cutoff'),
            'quote_status':quote.get('status','unknown'),'quote_stale':quote.get('stale'),
            'missing':missing,'corpus_hash':detail.get('corpus_hash'),'mode':'cached_reviewed_or_demo',
            'paid_calls':0,'fresh_web_fetch':False}


class JobStore:
    def __init__(self,path):
        self.path=Path(path);self.path.parent.mkdir(parents=True,exist_ok=True)
        with self.db() as c:
            c.execute('CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY, asset_id TEXT NOT NULL, kind TEXT NOT NULL, stage TEXT NOT NULL, created TEXT NOT NULL, updated TEXT NOT NULL, thread_id TEXT, starter_id TEXT, result_id TEXT, meta TEXT NOT NULL)')
            c.execute('CREATE TABLE IF NOT EXISTS events(job_id TEXT NOT NULL, seq INTEGER PRIMARY KEY AUTOINCREMENT, stage TEXT NOT NULL, at TEXT NOT NULL, note TEXT NOT NULL)')
    @contextmanager
    def db(self):
        c=sqlite3.connect(self.path,timeout=5);c.row_factory=sqlite3.Row
        try:
            with c:yield c
        finally:c.close()
    def get(self,job_id):
        with self.db() as c:
            row=c.execute('SELECT * FROM jobs WHERE id=?',(str(job_id),)).fetchone()
        if row is None:return None
        row=dict(row);row['meta']=json.loads(row['meta']);return row
    def create(self,job_id,asset,*,fresh=False):
        stamp=now()
        with self.db() as c:
            existing=c.execute('SELECT id FROM jobs WHERE id=?',(str(job_id),)).fetchone()
            if existing:return self.get(job_id),False
            if c.execute("SELECT count(*) FROM jobs WHERE stage NOT IN ('PUBLISHED','BLOCKED')").fetchone()[0]>=10:
                raise ValueError('Research queue is full')
            c.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?,?,?)',(str(job_id),asset['asset_id'],asset['kind'],'QUEUED',stamp,stamp,None,None,None,json.dumps({'mode':'fresh_public_source_read'} if fresh else {})))
            c.execute('INSERT INTO events(job_id,stage,at,note) VALUES(?,?,?,?)',(str(job_id),'QUEUED',stamp,'Owner requested a public fresh-source job.' if fresh else 'Owner requested a public reviewed-evidence job.'))
        return self.get(job_id),True
    def transition(self,job_id,stage,note='',**updates):
        assert stage in STAGES
        stamp=now()
        with self.db() as c:
            current=c.execute('SELECT stage FROM jobs WHERE id=?',(str(job_id),)).fetchone()
            if not current:raise ValueError('Unknown job')
            if current['stage'] in TERMINAL and stage!=current['stage']:raise ValueError('Terminal job cannot restart')
            c.execute('UPDATE jobs SET stage=?,updated=? WHERE id=?',(stage,stamp,str(job_id)))
            for key,value in updates.items():
                if key not in ('thread_id','starter_id','result_id','meta'):raise ValueError('Unknown job field')
                c.execute('UPDATE jobs SET '+key+'=? WHERE id=?',(json.dumps(value) if key=='meta' else value,str(job_id)))
            c.execute('INSERT INTO events(job_id,stage,at,note) VALUES(?,?,?,?)',(str(job_id),stage,stamp,note[:300]))
        return self.get(job_id)
    def events(self,job_id):
        with self.db() as c:return [dict(x) for x in c.execute('SELECT stage,at,note FROM events WHERE job_id=? ORDER BY seq',(str(job_id),))]
    def recent(self,limit=10):
        with self.db() as c:ids=[x[0] for x in c.execute('SELECT id FROM jobs ORDER BY created DESC LIMIT ?',(limit,))]
        return [self.get(i) for i in ids]
    def queued(self):
        with self.db() as c:return [x[0] for x in c.execute("SELECT id FROM jobs WHERE stage='QUEUED' ORDER BY created")]
    def recover(self):
        with self.db() as c:ids=[x[0] for x in c.execute("SELECT id FROM jobs WHERE stage NOT IN ('QUEUED','PUBLISHED','BLOCKED')")]
        for job_id in ids:self.transition(job_id,'BLOCKED','Worker interrupted; remote outcome must be reconciled before a new attempt.')
        return ids


def progress_text(job,events):
    m=job['meta'];fresh=m.get('mode')=='fresh_public_source_read'
    lines=[f"**{job['asset_id']} · {MARKETS[job['kind']]}**",f"**{STAGES[job['stage']]}**",
           f"Job `{job['id']}` · Apollo {MARKETS[job['kind']]} {'source' if fresh else 'evidence'} worker",
           ('Fresh HTTP reads of fixed public sources. Not live quotes, a broad search or representative sentiment. No model calls or paid credits.' if fresh else
            'Reviewed snapshots / educational fixtures. No fresh web search, model call or paid credits.'),
           '**Progress**']
    # Show actual source events, not a timer or simulated agent activity.
    recent=[]
    for e in events:
        if recent and (e['stage'],e.get('note'))==(recent[-1]['stage'],recent[-1].get('note')):continue
        recent.append(e)
    for e in recent[-12:]:
        local=datetime.fromisoformat(e['at']).astimezone(ZoneInfo('America/New_York'))
        label=STAGES[e['stage']]
        if e['stage'] in set(FRESH_STAGES.values())|{'SOURCE_FAILED','SOURCE_GAP'} and e.get('note'):label+=' · '+e['note'][:85]
        lines.append(f"• {local.strftime('%H:%M:%S')} {local.tzname()} — {label}")
    if 'source_count' in m:
        if fresh:
            lines.append(f"Source records: {m.get('source_count',0)} · successful HTTP reads: {m.get('receipt',{}).get('sources_succeeded',0)} · fetched: {m.get('fetched_at') or 'unknown'}")
            lines.append('Fresh read does not establish a new publication or complete/current market coverage.')
        else:
            lines.extend([f"Reviewed source records: {m.get('source_count',0)} · cutoff: {m.get('evidence_cutoff') or 'unknown'}",
                          f"Quote: {m.get('quote_status','unknown')} · stale: {m.get('quote_stale')}"])
        lines.append('Missing evidence tracks: '+(', '.join(m.get('missing',[])) or 'none; completeness still unverified'))
    if m.get('failed_sources'):lines.append('Failed source reads: '+', '.join(m['failed_sources']))
    if job['stage']=='BLOCKED':lines.append('Blocked: '+events[-1]['note'])
    if job.get('result_id') and job.get('thread_id'):
        lines.append(f"Result: https://discord.com/channels/1561044080698331337/{job['thread_id']}/{job['result_id']}")
    return '\n'.join(lines)[:1950]


def fresh_result(asset_id,on_progress):
    # Producer owns all outbound fetching; consumer accepts exact asset IDs only.
    research_service(asset_id)
    from backend.research.fresh_content import fresh_research
    return fresh_research(asset_id,on_progress=on_progress)


def check_fresh_result(result,job):
    detail=result['detail'];analysis=result['analysis'];receipt=result['receipt']
    if detail.get('asset_id')!=job['asset_id'] or detail.get('kind')!=job['kind']:
        raise ValueError('Fresh asset identity mismatch')
    if analysis.get('asset_id')!=job['asset_id'] or not detail.get('corpus_hash') or detail['corpus_hash']!=analysis.get('corpus_hash'):
        raise ValueError('Fresh corpus identity mismatch')
    if receipt.get('asset_id')!=job['asset_id'] or receipt.get('mode')!='fresh_public_source_read':
        raise ValueError('Fresh receipt identity mismatch')
    if receipt.get('paid_calls')!=0 or receipt.get('fresh_web_fetch') is not True or receipt.get('historical_corpus_used') is not False:
        raise ValueError('Fresh receipt must prove a free successful public read')
    if receipt.get('version')!=2 or receipt.get('status')!='fetched_content':raise ValueError('Checked fresh source content required')
    if {o.get('source_id') for o in receipt.get('observations',[])}!={s.get('id') for s in detail.get('sources',[])}:
        raise ValueError('Fresh observations must bind every displayed source')
    # Date and source binding validation is shared, but mode metadata is explicit.
    meta=check_provenance(detail)
    if not detail.get('sources'):raise ValueError('No successful fresh sources')
    meta.update(mode='fresh_public_source_read',fresh_web_fetch=True,fetched_at=receipt.get('fetched_at'),receipt=receipt)
    if not meta['fetched_at']:raise ValueError('Fresh retrieval timestamp missing')
    fetched=datetime.fromisoformat(meta['fetched_at'])
    if fetched.tzinfo is None or fetched.timestamp()<datetime.fromisoformat(job['created']).timestamp()-2 or fetched.timestamp()>datetime.now(timezone.utc).timestamp()+5:
        raise ValueError('Fresh receipt must belong to this job time')
    checked={};failed=[]
    for record in receipt.get('source_receipts',[]):
        if record.get('checked') is False:
            failed.append(urlsplit(record.get('url','')).hostname or 'unknown')
            continue
        digest=record.get('sha256','')
        if record.get('checked') is not True or record.get('http_status')!=200 or len(digest)!=64 or any(c not in '0123456789abcdef' for c in digest):
            raise ValueError('Fresh source receipt not checked')
        p=urlsplit(record.get('url',''))
        if p.scheme!='https' or not p.hostname or p.username or p.password:raise ValueError('Invalid fresh receipt URL')
        checked[record['url']]=record
    meta['failed_sources']=failed
    if not checked or receipt.get('sources_succeeded')!=len(checked):raise ValueError('Fresh source count mismatch')
    if any(s.get('fetch_url') not in checked for s in detail['sources']):raise ValueError('Fresh source not bound to HTTP receipt')
    return meta


def normalize_embed(e):
    return (e.get('title'),e.get('description'),e.get('color'),[(f['name'],f['value']) for f in e.get('fields',[])])


class ForumTransport:
    def __init__(self,client,forum):self.client=client;self.forum=forum
    async def create(self,job,events):
        import discord
        market=MARKETS[job['kind']]
        tags=[t for t in self.forum.available_tags if t.name==market]
        result=await self.forum.create_thread(name=f"{job['asset_id']} · {market} · {'fresh source read' if job['meta'].get('mode')=='fresh_public_source_read' else 'reviewed evidence'}",content=progress_text(job,events),
          applied_tags=tags,allowed_mentions=discord.AllowedMentions.none(),reason='Owner-authorized public Apollo research job')
        return str(result.thread.id),str(result.message.id)
    async def progress(self,job,events):
        import discord
        thread=await self.client.fetch_channel(int(job['thread_id']))
        message=await thread.fetch_message(int(job['starter_id']))
        expected=progress_text(job,events)
        edited=await message.edit(content=expected,allowed_mentions=discord.AllowedMentions.none())
        if edited.content!=expected:raise ValueError('Progress update read-back mismatch')
    async def result(self,job,payload):
        import discord
        thread=await self.client.fetch_channel(int(job['thread_id']))
        message=await thread.send(payload['content'],embeds=[discord.Embed.from_dict(e) for e in payload['embeds']],
                                  allowed_mentions=discord.AllowedMentions.none(),silent=True)
        return str(message.id)
    async def verify(self,job,payload):
        thread=await self.client.fetch_channel(int(job['thread_id']))
        message=await thread.fetch_message(int(job['result_id']))
        if message.author.id!=self.client.user.id or message.content!=payload['content']:
            raise ValueError('Published message identity/content mismatch')
        if [normalize_embed(e.to_dict()) for e in message.embeds]!=[normalize_embed(e) for e in payload['embeds']]:
            raise ValueError('Published embed mismatch')
        if message.mention_everyone or message.mentions or message.role_mentions:raise ValueError('Unexpected mention')


class ForumRunner:
    def __init__(self,store,transport):
        self.store=store;self.transport=transport;self.wake=asyncio.Event();self.stopping=False
    async def submit(self,job_id,asset_id,*,fresh=True):
        _,asset=await asyncio.to_thread(resolve_asset,asset_id)
        if fresh and asset['asset_id'] not in FRESH_ASSETS:raise ValueError('Fresh reads support AAPL, SPY and BTC-USD')
        job,created=self.store.create(job_id,asset,fresh=fresh)
        self.wake.set();return job,created
    async def run_job(self,job_id):
        job=self.store.get(job_id)
        if job is None or job['stage']!='QUEUED':return
        try:
            job=self.store.transition(job_id,'CREATING_THREAD')
            thread_id,starter_id=await self.transport.create(job,self.store.events(job_id))
            # Persist binding before any subsequent network operation.
            job=self.store.transition(job_id,'CREATING_THREAD',thread_id=thread_id,starter_id=starter_id)
            service,asset=await asyncio.to_thread(resolve_asset,job['asset_id'])
            if job['meta'].get('mode')=='fresh_public_source_read':
                loop=asyncio.get_running_loop()
                def callback(stage,info):
                    if stage not in FRESH_STAGES:raise ValueError('Unknown producer progress event')
                    # No raw source text, untrusted URLs, headers or error bodies in public progress.
                    note=str(info.get('source_id') or urlsplit(info.get('source_url') or info.get('url','')).hostname or '')
                    note=''.join(c for c in note if c.isascii() and (c.isalnum() or c in '-_.'))[:60]
                    if stage=='blocked':raise ValueError('Fresh source retrieval blocked')
                    public_stage=FRESH_STAGES[stage]
                    if stage=='sourcechecked' and info.get('check')=='failed':public_stage='SOURCE_FAILED'
                    if stage=='sourcechecked' and info.get('check')=='no_supported_content_excerpt':public_stage='SOURCE_GAP'
                    future=asyncio.run_coroutine_threadsafe(self.advance(job_id,public_stage,note=note),loop)
                    try:return future.result(timeout=PROGRESS_TIMEOUT)
                    except BaseException:
                        future.cancel()
                        raise
                result=await asyncio.to_thread(fresh_result,job['asset_id'],callback)
                meta=check_fresh_result(result,job)
                await self.advance(job_id,'CHECKED',meta=meta)
                from backend.research.fresh_content import format_fresh_brief
                payload=format_fresh_brief(result)
            else:
                detail=await asyncio.to_thread(service.details,job['asset_id'])
                if detail['asset_id']!=job['asset_id'] or detail['kind']!=job['kind']:raise ValueError('Asset mismatch')
                await self.advance(job_id,'LOADED')
                meta=check_provenance(detail)
                await self.advance(job_id,'CHECKED',meta=meta)
                analysis=await asyncio.to_thread(service.analysis,job['asset_id'])
                await self.advance(job_id,'ANALYZED')
                from backend.research.discord_brief import format_brief
                payload=format_brief(detail,analysis,question=f"Review {job['asset_id']}: evidence for caution, counterevidence and the three separate tracks.")
            await self.advance(job_id,'FORMATTED')
            job=await self.advance(job_id,'POSTING_RESULT')
            result_id=await self.transport.result(job,payload)
            job=self.store.transition(job_id,'POSTING_RESULT',result_id=result_id)
            await self.transport.verify(job,payload)
            # The result must be read back before the public status can say Published.
            published=dict(job,stage='PUBLISHED')
            events=self.store.events(job_id)+[{'stage':'PUBLISHED','at':now(),'note':'Exact result read-back verified.'}]
            await self.transport.progress(published,events)
            job=self.store.transition(job_id,'PUBLISHED','Exact Discord result and progress read-back verified.')
            print(json.dumps({'event':'apollo_job_published','job_id':str(job_id),'asset_id':job['asset_id'],'thread_id':job['thread_id'],'result_id':job['result_id'],'paid_calls':0}),flush=True)
        except Exception as exc:
            job=self.store.get(job_id)
            if job and job['stage'] not in TERMINAL:
                job=self.store.transition(job_id,'BLOCKED',type(exc).__name__+'; no worker-level retry.')
                if job.get('thread_id') and job.get('starter_id'):
                    try:await self.transport.progress(job,self.store.events(job_id))
                    except Exception:pass
            print(json.dumps({'event':'apollo_job_blocked','job_id':str(job_id),'error_type':type(exc).__name__}),flush=True)
    async def advance(self,job_id,stage,note='',**updates):
        job=self.store.transition(job_id,stage,note,**updates)
        await self.transport.progress(job,self.store.events(job_id));return job
    async def work(self,ready):
        await ready()
        for job_id in self.store.recover():
            job=self.store.get(job_id)
            if job.get('thread_id') and job.get('starter_id'):
                try:await self.transport.progress(job,self.store.events(job_id))
                except Exception:pass
        while not self.stopping:
            self.wake.clear()
            for job_id in self.store.queued():await self.run_job(job_id)
            await self.wake.wait()
