import asyncio,json,os,sqlite3,tempfile,time,unittest
from pathlib import Path
from unittest.mock import patch
from admissions import AdmissionStore,WaitlistAPI,AdmissionAgent,verified_install,normalized_email,claim_email,welcome_email

class StoreTests(unittest.TestCase):
 def setUp(self):self.tmp=tempfile.TemporaryDirectory();self.store=AdmissionStore(Path(self.tmp.name)/'private.sqlite')
 def tearDown(self):self.tmp.cleanup()
 def row(self):
  with self.store.db() as c:return dict(c.execute('SELECT * FROM admissions').fetchone())
 def test_email_dedup_consent_and_generic_response_do_not_disclose_tokens(self):
  api=WaitlistAPI(self.store)
  first=api.handle('POST','/waitlist',{'email':'Person@Example.COM','consent':True})
  self.assertEqual(first,api.handle('POST','/waitlist',{'email':' person@example.com ','consent':True}))
  self.assertEqual(first[0],202);self.assertEqual(self.row()['email'],'person@example.com')
  self.assertNotIn('claim',json.dumps(first));self.assertEqual(os.stat(self.store.path).st_mode & 0o777,0o600)
  with self.store.db() as c:self.assertEqual(c.execute('SELECT count(*) FROM admission_mail').fetchone()[0],1)
  self.assertEqual(api.handle('GET','/waitlist',{})[0],404)
  self.assertEqual(api.handle('POST','/waitlist',{'email':'other@example.com','consent':False})[0],400)
 def test_email_header_injection_and_malformed_input_rejected(self):
  for value in ['a@b.com\r\nBcc: bad@evil.com','x@localhost','.a@b.com','a..b@b.com','a@b.com,other@b.com']:
   with self.assertRaises(ValueError):normalized_email(value)
 def test_claim_hash_only_expiry_replay_and_discord_uniqueness(self):
  self.store.apply('person@example.com',True);aid=self.row()['id'];code=self.store.prepare_claim(aid)
  self.assertNotIn(code,self.store.path.read_bytes().decode('latin1'))
  uid='1561042929265418392';row=self.store.claim(code,uid);self.assertEqual(row['discord_id'],uid)
  self.assertEqual(self.store.claim(code,uid)['id'],aid)
  with self.assertRaises(ValueError):self.store.claim(code,'1561044080698331337')
  self.store.apply('other@example.com',True)
  with self.store.db() as c:other=c.execute('SELECT id FROM admissions WHERE email=?',('other@example.com',)).fetchone()[0]
  second=self.store.prepare_claim(other)
  with self.assertRaises(ValueError):self.store.claim(second,uid)
  with self.store.db() as c:c.execute('UPDATE admissions SET claim_expires=? WHERE id=?',(time.time()-1,other))
  with self.assertRaises(ValueError):self.store.claim(second,'1561044080698331337')
 def test_restart_unknown_send_is_blocked_and_never_queued_again(self):
  self.store.apply('person@example.com',True);aid=self.row()['id'];self.store.prepare_claim(aid);self.store.recover()
  self.assertIsNone(self.store.next_mail('CLAIM'))
  with self.store.db() as c:self.assertEqual(c.execute('SELECT state FROM admission_mail').fetchone()[0],'BLOCKED')

class InstallTests(unittest.TestCase):
 def test_only_verified_current_apollo_testflight_receipt_enables_delivery(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'install.json';p.write_text(json.dumps({'status':'unavailable','url':None,'verifiedAt':None,'build':None,'qr':None}));self.assertIsNone(verified_install(p))
   config={'status':'verified','product':'Apollo','gameBuildVerified':True,'build':'TESTONLY-FIXTURE','verifiedAt':'2026-10-17T00:00:00+00:00','url':'https://testflight.apple.com/join/TESTONLY'}
   p.write_text(json.dumps(config));self.assertEqual(verified_install(p)['url'],config['url'])
   for change in [{'product':'Other'},{'gameBuildVerified':False},{'url':'https://testflight.apple.com.evil.com/join/TESTONLY'},{'url':'https://testflight.apple.com/join/TESTONLY?token=bad'}]:
    p.write_text(json.dumps(config|change));self.assertIsNone(verified_install(p))
 def test_email_bodies_require_private_channel_and_matching_install(self):
  with self.assertRaises(ValueError):claim_email('a'*32,'https://evil.com/invite')
  with self.assertRaises(ValueError):welcome_email({'guild_channel':'1561042929265418392','install_url':'bad'},{'url':'https://testflight.apple.com/join/TESTONLY','build':'TESTONLY'})

class ClaimCommandTests(unittest.IsolatedAsyncioTestCase):
 async def test_claim_binds_only_actual_invoker_and_replies_ephemerally(self):
  import discord
  from bot import Config,create_client
  from types import SimpleNamespace
  from unittest.mock import AsyncMock
  app=1561042929265418392;guild=1561044080698331337;uid=1561063120619831437
  client=create_client(Config(app,guild,admission_config='unused-offline.json'))
  self.assertFalse(client.intents.dm_messages);self.assertFalse(client.intents.guild_messages)
  self.assertFalse(client.intents.message_content);self.assertFalse(client.intents.members)
  client.admission_agent=SimpleNamespace(claim=AsyncMock(return_value={'status':'PRIVATE_CHANNEL_READY','private_channel_url':'https://discord.com/channels/1561044080698331337/1561063188454187152'}))
  command=next(c for c in client.tree.get_commands(guild=discord.Object(guild))[0].commands if c.name=='claim')
  interaction=SimpleNamespace(guild_id=guild,user=SimpleNamespace(id=uid),response=SimpleNamespace(defer=AsyncMock()),followup=SimpleNamespace(send=AsyncMock()))
  await command.callback(interaction,'private-code-fixture')
  client.admission_agent.claim.assert_awaited_once_with('private-code-fixture',str(uid))
  self.assertTrue(interaction.followup.send.call_args.kwargs['ephemeral'])
  self.assertNotIn('private-code-fixture',interaction.followup.send.call_args.args[0])
  await client.close()

class GuildChannelTests(unittest.IsolatedAsyncioTestCase):
 async def test_atomic_private_acl_and_readback_then_replay_reuses_channel(self):
  from types import SimpleNamespace
  from unittest.mock import AsyncMock
  from admissions import channel_overwrites
  guild='1561044080698331337';cat='1561070673047068754';bot='1561042929265418392';uid='1385362917582700716';cid='1561063120619831437'
  data={'id':cid,'type':0,'guild_id':guild,'parent_id':cat,'permission_overwrites':channel_overwrites(guild,bot,uid)}
  category={'type':4,'guild_id':guild,'permission_overwrites':[{'id':guild,'type':0,'deny':'1024','allow':'0'},{'id':bot,'type':1,'allow':'85008','deny':'0'}]}
  class HTTP:
   async def get_channel(self,i):return category if str(i)==cat else data
   create_channel=AsyncMock(return_value=data)
  class Channel:
   id=int(cid)
   def __init__(self):self.msgs=[]
   async def send(self,content,**kw):
    msg=SimpleNamespace(id=1561063188454187152,content=content,author=SimpleNamespace(id=int(bot)),mentions=[],mention_everyone=False);self.msgs.append(msg);return msg
   async def fetch_message(self,mid):return self.msgs[-1]
  channel=Channel();g=SimpleNamespace(owner_id=int(uid),fetch_member=AsyncMock(return_value=SimpleNamespace(bot=False,roles=[])))
  client=SimpleNamespace(user=SimpleNamespace(id=int(bot)),http=HTTP(),fetch_guild=AsyncMock(return_value=g),fetch_channel=AsyncMock(return_value=channel))
  with tempfile.TemporaryDirectory() as d:
   store=AdmissionStore(Path(d)/'db');store.apply('person@example.com',True);r=store.next_mail('CLAIM');code=store.prepare_claim(r['id']);agent=AdmissionAgent(store,client,Path(d)/'none.json',guild_id=guild,category_id=cat)
   first=await agent.claim(code,uid);second=await agent.claim(code,uid)
   self.assertEqual(first,second);self.assertIn('/'+guild+'/',first['private_channel_url']);self.assertNotIn('/@me/',first['private_channel_url'])
   client.http.create_channel.assert_awaited_once();self.assertEqual(len(channel.msgs),1)
   # An uncertain message result is reserved durably, never blindly resent.
   with store.db() as c:c.execute("UPDATE admissions SET status='CREATING_CHANNEL',guild_message=NULL WHERE id=?",(r['id'],))
   with self.assertRaises(ValueError):await agent.claim(code,uid)
   self.assertEqual(len(channel.msgs),1)
   # A simultaneous caller holding a stale row cannot win the same reservation.
   stale=store.get(r['id']);stale['status']='PRIVATE_CHANNEL_READY'
   with self.assertRaises(ValueError):await agent.ensure_channel(stale,None)
   self.assertEqual(len(channel.msgs),1)
   self.assertIsNone(store.get(r['id'])['dm_channel']);self.assertIn('not available yet',channel.msgs[0].content)
 def test_public_or_wrong_member_overwrites_fail_before_message(self):
  from admissions import channel_overwrites,check_private_channel
  args=['1561044080698331337','1561070673047068754','1561042929265418392','1385362917582700716']
  data={'type':0,'guild_id':args[0],'parent_id':args[1],'permission_overwrites':channel_overwrites(args[0],args[2],args[3])}
  check_private_channel(data,*args)
  data['permission_overwrites'].append({'id':'1561063120619831437','type':1,'allow':'1024','deny':'0'})
  with self.assertRaises(ValueError):check_private_channel(data,*args)
  data['permission_overwrites']=channel_overwrites(args[0],args[2],args[3]);data['permission_overwrites'][0]['deny']='0'
  with self.assertRaises(ValueError):check_private_channel(data,*args)
 def test_legacy_private_history_preserved_by_additive_schema(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'db';s=AdmissionStore(p);s.apply('person@example.com',True)
   with s.db() as c:c.execute("UPDATE admissions SET dm_channel='1561068782951071744',status='PRIVATE_DM_READY'")
   s=AdmissionStore(p)
   with s.db() as c:r=dict(c.execute('SELECT * FROM admissions').fetchone())
   self.assertEqual(r['dm_channel'],'1561068782951071744');self.assertIsNone(r['guild_channel'])

if __name__=='__main__':unittest.main()
