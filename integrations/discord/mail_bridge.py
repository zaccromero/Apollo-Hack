"""Local trusted Gmail-agent outbox bridge. Never expose this as an HTTP route.

prepare reserves at most one message before returning private MIME data. The agent
must send exactly that payload through connected Gmail, read the actual sent message,
then ack its provider ID. Uncertain attempts block; they are never auto-resent.
"""
import argparse,asyncio,json,os,re,sys
from pathlib import Path
from admissions import AdmissionStore,AdmissionAgent,verified_install,claim_email,welcome_email

def config(path):
    d=json.loads(Path(path).read_text())
    if d.get('delivery_mode')!='guild_channel' or not d.get('category_id'):raise ValueError('Private server channel destination required')
    if d.get('guild_id')!='1561044080698331337' or d.get('invite_verified_guild_id')!=d['guild_id']:raise ValueError('Wrong admission guild')
    return d

def private_message(row,kind,text):
    subject=('Apollo access — link Discord — ' if kind=='CLAIM' else 'Apollo welcome — private channel and TestFlight — ')+row['id']
    return {'status':'RESERVED','admission_id':row['id'],'kind':kind,'expected_sender':None,
      'gmail':{'to':row['email'],'subject':subject,'payload':{'mime_type':'text/plain','body':{'content':text}},'response_fields':['id','thread_id','label_ids']}}

async def prepare(d,store):
    row=store.next_mail('CLAIM')
    if row:
        claim_email('A'*32,d.get('invite_url',''))
        code=store.prepare_claim(row['id'])
        result=private_message(row,'CLAIM',claim_email(code,d['invite_url']))
    else:
        row=store.next_mail('WELCOME')
        if not row:return {'status':'NO_QUEUED_EMAIL'}
        install=verified_install(d['install_receipt'])
        if not install:return {'status':'WAITING_VERIFIED_TESTFLIGHT'}
        import discord
        client=discord.Client(intents=discord.Intents.none(),allowed_mentions=discord.AllowedMentions.none())
        try:
            await client.login(os.environ['APOLLO_DISCORD_BOT_TOKEN'])
            if (await client.application_info()).id!=1561042929265418392:raise ValueError('Wrong Apollo application')
            agent=AdmissionAgent(store,client,d['install_receipt'],guild_id=d['guild_id'],category_id=d['category_id'])
            await agent.ensure_channel(row,install);row=store.get(row['id'])
            current=verified_install(d['install_receipt'])
            if not current or current['url']!=install['url']:return {'status':'WAITING_VERIFIED_TESTFLIGHT'}
            text=welcome_email(row,install);store.reserve_welcome(row['id'])
            result=private_message(row,'WELCOME',text)
        except Exception as exc:
            with store.db() as c:c.execute("UPDATE admission_mail SET state='BLOCKED',error_code=? WHERE admission_id=? AND kind='WELCOME' AND state='QUEUED'",(type(exc).__name__,row['id']))
            raise
        finally:await client.close()
    result['expected_sender']=d['expected_gmail_sender']
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',required=True)
    p.add_argument('action',choices=['prepare','ack','block','status','self-test-signup'])
    p.add_argument('--admission');p.add_argument('--kind',choices=['CLAIM','WELCOME']);p.add_argument('--provider-id')
    a=p.parse_args();d=config(a.config);store=AdmissionStore(d['database'])
    if a.action=='prepare':return asyncio.run(prepare(d,store))
    if a.action=='self-test-signup':
        store.apply(d['expected_gmail_sender'],True)
        return {'status':'SELF_TEST_RECEIVED','recipient':'APPROVED_CONNECTED_GMAIL_OWNER'}
    if a.action=='status':
        with store.db() as c:
            return {'admissions':dict(c.execute('SELECT status,count(*) FROM admissions GROUP BY status').fetchall()),'outbox':dict(c.execute('SELECT state,count(*) FROM admission_mail GROUP BY state').fetchall()),'install_ready':bool(verified_install(d['install_receipt']))}
    if not a.admission or not a.kind:raise ValueError('Exact reserved admission and kind required')
    if a.action=='ack':
        if not a.provider_id or not re.fullmatch(r'[A-Za-z0-9_-]{5,100}',a.provider_id):raise ValueError('Actual Gmail message ID required')
        store.finish_mail(a.admission,a.kind,provider_id=a.provider_id)
        return {'status':'GMAIL_SENT_RECORDED','provider_id':a.provider_id,'kind':a.kind}
    store.finish_mail(a.admission,a.kind,error='gmail_send_outcome_uncertain')
    return {'status':'BLOCKED_UNCERTAIN_NO_RETRY'}

if __name__=='__main__':
    try:print(json.dumps(main()))
    except Exception as e:
        print(json.dumps({'status':'BLOCKED','error_type':type(e).__name__}));raise SystemExit(1)
