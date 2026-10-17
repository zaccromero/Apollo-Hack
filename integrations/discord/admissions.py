"""Consented waitlist acceptance, verified Discord binding and private delivery.

No model calls, public PII endpoints, implicit sender setup or unverified install URLs.
"""
from contextlib import contextmanager
from datetime import datetime,timezone
import hashlib,json,os,re,secrets,sqlite3,time
from pathlib import Path
from urllib.parse import urlsplit

GENERIC={'status':'received','message':'If this is a new valid request, check your email for the next step. Duplicate requests do not create another place or email.'}

def normalized_email(value):
    if not isinstance(value,str) or len(value)>254 or not value.isascii():raise ValueError('Invalid email')
    value=value.strip().casefold()
    if not re.fullmatch(r"[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+",value):raise ValueError('Invalid email')
    local=value.split('@')[0]
    if local.startswith('.') or local.endswith('.') or '..' in local:raise ValueError('Invalid email')
    return value

def discord_id(value):
    s=str(value)
    if not s.isascii() or not s.isdecimal() or not 16<=len(s)<=20 or not 0<int(s)<2**64:raise ValueError('Invalid Discord ID')
    return s

def verified_install(path):
    """Read only the integration-controlled, verified current Apollo game receipt."""
    try:
        d=json.loads(Path(path).read_text())
        if not isinstance(d,dict) or not isinstance(d.get('url'),str) or not isinstance(d.get('verifiedAt'),str):return None
        p=urlsplit(d['url'])
        stamp=datetime.fromisoformat(d['verifiedAt'].replace('Z','+00:00'))
        if d.get('status')!='verified' or d.get('product')!='Apollo' or d.get('gameBuildVerified') is not True or not isinstance(d.get('build'),str) or not d['build'].strip():return None
        if stamp.tzinfo is None or stamp>datetime.now(timezone.utc):return None
        if p.scheme!='https' or p.hostname!='testflight.apple.com' or p.username or p.password or p.port or p.query or p.fragment or not re.fullmatch(r'/join/[A-Za-z0-9]{8}',p.path):return None
        return {'url':d['url'],'build':d['build'],'verifiedAt':d['verifiedAt']}
    except (OSError,ValueError,TypeError,KeyError):return None

class AdmissionStore:
    def __init__(self,path):
        self.path=Path(path);self.path.parent.mkdir(parents=True,exist_ok=True)
        if not self.path.exists():
            fd=os.open(self.path,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600);os.close(fd)
        os.chmod(self.path,0o600)
        with self.db() as c:
            c.executescript('''CREATE TABLE IF NOT EXISTS admissions(
              id TEXT PRIMARY KEY,email TEXT NOT NULL UNIQUE,consent_at REAL NOT NULL,status TEXT NOT NULL,
              created REAL NOT NULL,claim_hash TEXT UNIQUE,claim_expires REAL,discord_id TEXT UNIQUE,
              dm_channel TEXT,dm_message TEXT,install_url TEXT);
              CREATE TABLE IF NOT EXISTS admission_mail(
              admission_id TEXT NOT NULL,kind TEXT NOT NULL,state TEXT NOT NULL,created REAL NOT NULL,
              provider_id TEXT,error_code TEXT,PRIMARY KEY(admission_id,kind));''')
            columns={r[1] for r in c.execute('PRAGMA table_info(admissions)')}
            for name in ('guild_channel','guild_message'):
                if name not in columns:c.execute('ALTER TABLE admissions ADD COLUMN '+name+' TEXT')
    @contextmanager
    def db(self):
        c=sqlite3.connect(self.path,timeout=5);c.row_factory=sqlite3.Row
        try:
            with c:yield c
        finally:c.close()
    def apply(self,email,consent):
        email=normalized_email(email)
        if consent is not True:raise ValueError('Explicit consent required')
        with self.db() as c:
            c.execute('BEGIN IMMEDIATE')
            # Check global intake before identity, avoiding an at-capacity membership oracle.
            if c.execute('SELECT count(*) FROM admissions WHERE created>?',(time.time()-86400,)).fetchone()[0]>=20:raise ValueError('Intake limit reached')
            if c.execute('SELECT id FROM admissions WHERE email=?',(email,)).fetchone():return False
            aid=secrets.token_hex(16);stamp=time.time()
            c.execute('INSERT INTO admissions(id,email,consent_at,status,created) VALUES(?,?,?,?,?)',(aid,email,stamp,'ACCEPTED_PENDING_EMAIL_CLAIM',stamp))
            c.execute('INSERT INTO admission_mail VALUES(?,?,?,?,NULL,NULL)',(aid,'CLAIM','QUEUED',stamp))
        return True
    def claim(self,code,user_id):
        user_id=discord_id(user_id)
        if not isinstance(code,str) or not re.fullmatch(r'[A-Za-z0-9_-]{24,100}',code):raise ValueError('Invalid or expired claim')
        digest=hashlib.sha256(code.encode()).hexdigest()
        with self.db() as c:
            c.execute('BEGIN IMMEDIATE')
            row=c.execute('SELECT * FROM admissions WHERE claim_hash=?',(digest,)).fetchone()
            if not row or row['claim_expires']<time.time():raise ValueError('Invalid or expired claim')
            if row['discord_id'] and row['discord_id']!=user_id:raise ValueError('Claim already bound')
            other=c.execute('SELECT id FROM admissions WHERE discord_id=?',(user_id,)).fetchone()
            if other and other['id']!=row['id']:raise ValueError('Discord account already linked')
            if row['discord_id']:return dict(row)
            c.execute("UPDATE admissions SET discord_id=?,status='VERIFIED_PENDING_INSTALL' WHERE id=?",(user_id,row['id']))
            c.execute('INSERT OR IGNORE INTO admission_mail VALUES(?,?,?,?,NULL,NULL)',(row['id'],'WELCOME','QUEUED',time.time()))
            row=dict(c.execute('SELECT * FROM admissions WHERE id=?',(row['id'],)).fetchone())
        return row
    def get(self,aid):
        with self.db() as c:
            r=c.execute('SELECT * FROM admissions WHERE id=?',(aid,)).fetchone()
            return dict(r) if r else None
    def for_discord(self,user_id):
        with self.db() as c:
            r=c.execute('SELECT * FROM admissions WHERE discord_id=?',(discord_id(user_id),)).fetchone()
            return dict(r) if r else None
    def next_mail(self,kind):
        with self.db() as c:
            r=c.execute("SELECT a.* FROM admissions a JOIN admission_mail m ON a.id=m.admission_id WHERE m.kind=? AND m.state='QUEUED' ORDER BY m.created LIMIT 1",(kind,)).fetchone()
            return dict(r) if r else None
    def prepare_claim(self,aid):
        code=secrets.token_urlsafe(24);digest=hashlib.sha256(code.encode()).hexdigest()
        with self.db() as c:
            c.execute('BEGIN IMMEDIATE')
            updated=c.execute("UPDATE admission_mail SET state='SENDING' WHERE admission_id=? AND kind='CLAIM' AND state='QUEUED'",(aid,)).rowcount
            if not updated:raise ValueError('Mail already reserved')
            c.execute('UPDATE admissions SET claim_hash=?,claim_expires=? WHERE id=?',(digest,time.time()+86400,aid))
        return code
    def reserve_welcome(self,aid):
        with self.db() as c:
            updated=c.execute("UPDATE admission_mail SET state='SENDING' WHERE admission_id=? AND kind='WELCOME' AND state='QUEUED'",(aid,)).rowcount
            if not updated:raise ValueError('Mail already reserved')
    def finish_mail(self,aid,kind,provider_id=None,error=None):
        if not provider_id and not error:raise ValueError('Actual provider result required')
        with self.db() as c:
            changed=c.execute("UPDATE admission_mail SET state=?,provider_id=?,error_code=? WHERE admission_id=? AND kind=? AND state='SENDING'",('BLOCKED' if error else 'SENT',provider_id,error,aid,kind)).rowcount
            if changed!=1:raise ValueError('Only an exact reserved mail can be acknowledged')
            if kind=='WELCOME' and not error:c.execute("UPDATE admissions SET status='EMAIL_SENT' WHERE id=?",(aid,))
    def recover(self):
        with self.db() as c:
            c.execute("UPDATE admission_mail SET state='BLOCKED',error_code='interrupted_uncertain_send' WHERE state='SENDING'")

class WaitlistAPI:
    """Server owner must enforce same-origin, rate/body limits and public HTTPS."""
    def __init__(self,store):self.store=store
    def handle(self,method,path,body):
        if method!='POST' or path.split('?')[0]!='/waitlist':return 404,{'error':'route_not_found'}
        try:
            if not isinstance(body,dict) or set(body)!={'email','consent'}:raise ValueError()
            self.store.apply(body['email'],body['consent'])
            return 202,dict(GENERIC)
        except (ValueError,KeyError):return 400,{'error':'Use a valid email and explicitly consent to Apollo access emails.'}

def claim_email(code,invite):
    p=urlsplit(invite)
    if p.scheme!='https' or p.hostname!='discord.gg' or not re.fullmatch(r'/[A-Za-z0-9-]+',p.path) or p.query or p.fragment or p.username or p.password:raise ValueError('Verified Apollo invite required')
    return ('Your Apollo request is accepted. Verify this email and link your own Discord account:\n\n'
      +invite+'\n\nIn the Apollo server, run /apollo claim code:'+code+'\n\n'
      'This single-account code expires in 24 hours. Do not share it. We will email your private channel inside the Apollo server and the verified current-game TestFlight link when both are ready.\n\n'
      'Educational paper simulation only. If you did not request Apollo access, ignore this message.')

def welcome_email(row,install):
    if not row.get('guild_channel') or row.get('install_url')!=install['url']:raise ValueError('Verified private channel and matching install required')
    return ('Welcome to Apollo. Your private channel inside the Apollo server:\nhttps://discord.com/channels/1561044080698331337/'+discord_id(row['guild_channel'])+'\n\n'
      'Install the Apollo game in TestFlight:\n'+install['url']+'\nBuild: '+install['build']+'\n\n'
      'Your linked Discord account, Apollo and server administrators can access this channel. Research separates Leadership, Promises vs results and Public sentiment, with source links and unknowns labeled. Educational paper simulation only.')

# Atomic private guild channel overwrites: no email/name in the channel title.
VIEW=1024;PRIVATE_MEMBER=1024|2048|65536|16384

def channel_overwrites(guild_id,bot_id,user_id):
    return [{'id':str(guild_id),'type':0,'allow':'0','deny':str(VIEW)},
            {'id':str(bot_id),'type':1,'allow':str(PRIVATE_MEMBER),'deny':'0'},
            {'id':str(user_id),'type':1,'allow':str(PRIVATE_MEMBER),'deny':'0'}]

def check_private_channel(data,guild_id,category_id,bot_id,user_id):
    if data.get('type')!=0 or str(data.get('guild_id'))!=str(guild_id) or str(data.get('parent_id'))!=str(category_id):raise ValueError('Wrong private guild channel')
    def shape(x):return (str(x['id']),int(x['type']),int(x.get('allow',0)),int(x.get('deny',0)))
    expected={shape(x) for x in channel_overwrites(guild_id,bot_id,user_id)}
    if {shape(x) for x in data.get('permission_overwrites',[])}!=expected:raise ValueError('Private channel ACL mismatch')

class AdmissionAgent:
    def __init__(self,store,client,install_path,*,guild_id,category_id):
        self.store=store;self.client=client;self.install_path=install_path
        self.guild_id=discord_id(guild_id);self.category_id=discord_id(category_id)
    async def claim(self,code,user_id):
        import asyncio
        row=await asyncio.to_thread(self.store.claim,code,user_id)
        await self.ensure_channel(row,verified_install(self.install_path))
        row=self.store.get(row['id'])
        return {'status':row['status'],'private_channel_url':'https://discord.com/channels/'+self.guild_id+'/'+row['guild_channel']}
    async def ensure_channel(self,row,install):
        import discord
        uid=discord_id(row['discord_id']);bot=str(self.client.user.id)
        if uid==bot:raise ValueError('A human Discord account is required')
        guild=await self.client.fetch_guild(int(self.guild_id))
        member=await guild.fetch_member(int(uid))
        if member.bot:raise ValueError('A human Discord account is required')
        category=await self.client.http.get_channel(int(self.category_id))
        if category.get('type')!=4 or str(category.get('guild_id'))!=self.guild_id:raise ValueError('Wrong private category')
        # Category may grant the dedicated bot a role/member overwrite, but nobody else.
        bot_member=await guild.fetch_member(self.client.user.id)
        allowed_viewers={bot,str(guild.owner_id),*[str(r.id) for r in bot_member.roles if r.id!=int(self.guild_id)]}
        everyone=next((x for x in category.get('permission_overwrites',[]) if str(x['id'])==self.guild_id and int(x['type'])==0),None)
        if not everyone or not int(everyone.get('deny',0))&VIEW or int(everyone.get('allow',0))&VIEW:raise ValueError('Category must deny public viewing')
        if any(int(x.get('allow',0))&VIEW and str(x['id']) not in allowed_viewers for x in category.get('permission_overwrites',[])):raise ValueError('Unexpected category viewer')
        if row.get('guild_channel'):
            data=await self.client.http.get_channel(int(row['guild_channel']))
            check_private_channel(data,self.guild_id,self.category_id,bot,uid)
            if row.get('guild_message') and row.get('install_url')==(install['url'] if install else None):return
            if row['status'] not in ('PRIVATE_CHANNEL_READY','VERIFIED_PENDING_INSTALL','PRIVATE_DM_READY'):raise ValueError('Private message outcome requires reconciliation')
            with self.store.db() as c:
                changed=c.execute("UPDATE admissions SET status='CREATING_CHANNEL' WHERE id=? AND status IN ('PRIVATE_CHANNEL_READY','VERIFIED_PENDING_INSTALL','PRIVATE_DM_READY')",(row['id'],)).rowcount
                if changed!=1:raise ValueError('Private welcome already reserved')
        else:
            if row['status'] not in ('VERIFIED_PENDING_INSTALL','PRIVATE_DM_READY'):raise ValueError('Private channel outcome requires reconciliation')
            with self.store.db() as c:
                changed=c.execute("UPDATE admissions SET status='CREATING_CHANNEL' WHERE id=? AND status IN ('VERIFIED_PENDING_INSTALL','PRIVATE_DM_READY')",(row['id'],)).rowcount
                if changed!=1:raise ValueError('Private channel already reserved')
            data=await self.client.http.create_channel(int(self.guild_id),0,name='apollo-'+row['id'][:10],parent_id=int(self.category_id),permission_overwrites=channel_overwrites(self.guild_id,bot,uid),reason='Consented Apollo admission; private channel inside Apollo server')
            # Persist remote binding before any message send or additional read.
            with self.store.db() as c:c.execute('UPDATE admissions SET guild_channel=? WHERE id=?',(discord_id(data['id']),row['id']))
            data=await self.client.http.get_channel(int(data['id']))
            check_private_channel(data,self.guild_id,self.category_id,bot,uid)
        channel=await self.client.fetch_channel(int(data['id']))
        access=('Apollo TestFlight: '+install['url']+'\nBuild: '+install['build'] if install else 'Apollo TestFlight is not available yet. Your final access email waits for a verified game build.')
        content=('Welcome to your personal Apollo channel inside the Apollo server. You, Apollo and server administrators can access it.\n'
          'Your channel: https://discord.com/channels/'+self.guild_id+'/'+data['id']+'\n'+access+'\n'
          'Use /apollo research question:What should I research about AAPL? for three separate source-linked tracks. Missing evidence stays unknown. Educational paper simulation only.')
        message=await channel.send(content,allowed_mentions=discord.AllowedMentions.none())
        actual=await channel.fetch_message(message.id)
        if actual.author.id!=self.client.user.id or actual.content!=content or actual.mentions or actual.mention_everyone:raise ValueError('Private welcome read-back mismatch')
        with self.store.db() as c:c.execute("UPDATE admissions SET guild_channel=?,guild_message=?,install_url=?,status='PRIVATE_CHANNEL_READY' WHERE id=?",(str(channel.id),str(message.id),install['url'] if install else None,row['id']))
