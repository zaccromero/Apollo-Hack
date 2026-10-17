import asyncio
import json
from pathlib import Path
import socket
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock,patch
from forum_jobs import JobStore,ForumRunner,check_provenance,progress_text,resolve_asset,normalize_embed


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.store=JobStore(Path(self.temp.name)/'jobs.sqlite')
    def tearDown(self):self.temp.cleanup()
    def test_duplicate_request_persistence_and_no_restart_of_terminal(self):
        asset={'asset_id':'AAPL','kind':'stock'}
        _,created=self.store.create('1',asset);self.assertTrue(created)
        _,created=self.store.create('1',asset);self.assertFalse(created)
        self.assertEqual(len(self.store.recent()),1)
        self.store.transition('1','CREATING_THREAD');self.store.recover()
        self.assertEqual(JobStore(self.store.path).get('1')['stage'],'BLOCKED')
        self.assertEqual(self.store.queued(),[])
        with self.assertRaises(ValueError):self.store.transition('1','QUEUED')
    def test_queue_capacity_is_bounded(self):
        for i in range(10):self.store.create(str(i),{'asset_id':'AAPL','kind':'stock'})
        with self.assertRaises(ValueError):self.store.create('11',{'asset_id':'AAPL','kind':'stock'})
    def test_progress_uses_real_event_times_and_no_paid_claim(self):
        row,_=self.store.create('1',{'asset_id':'AAPL','kind':'stock'})
        text=progress_text(row,self.store.events('1'))
        self.assertIn('EDT',text);self.assertIn('Queued',text);self.assertIn('No fresh web search',text)
        self.assertNotIn('Published',text)


class FakeTransport:
    def __init__(self,fail=None):self.fail=fail;self.created=0;self.sent=0;self.stages=[];self.payload=None
    async def create(self,job,events):
        self.created+=1
        if self.fail=='uncertain_create':raise TimeoutError('remote outcome unknown')
        return '1561052340360978523','1561052340360978524'
    async def progress(self,job,events):
        self.stages.append(job['stage'])
        if self.fail=='final_progress' and job['stage']=='PUBLISHED':raise TimeoutError()
    async def result(self,job,payload):self.sent+=1;self.payload=payload;return '1561052340360978525'
    async def verify(self,job,payload):
        if self.fail=='readback':raise ValueError('Mismatch')


class WorkerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp=tempfile.TemporaryDirectory();self.store=JobStore(Path(self.temp.name)/'jobs.sqlite')
    async def asyncTearDown(self):self.temp.cleanup()
    async def test_real_multi_market_pipeline_without_network(self):
        for i,aid in enumerate(['AAPL','SPY','BTC-USD','AAPL_20261120_C350_DEMO']):
            t=FakeTransport();runner=ForumRunner(self.store,t)
            with patch('socket.socket',side_effect=AssertionError('No research network')):
                row,created=await runner.submit(str(i),aid,fresh=False)
                await runner.run_job(str(i))
            row=self.store.get(str(i));self.assertEqual(row['stage'],'PUBLISHED')
            self.assertEqual([e['title'] for e in t.payload['embeds'][1:]],['Leadership','Promises vs results','Public sentiment'])
            self.assertEqual(t.sent,1);self.assertEqual(t.stages[-1],'PUBLISHED')
            self.assertEqual(row['meta']['paid_calls'],0);self.assertFalse(row['meta']['fresh_web_fetch'])
            if aid in ['BTC-USD','AAPL_20261120_C350_DEMO']:
                self.assertEqual(row['meta']['source_count'],0);self.assertEqual(len(row['meta']['missing']),3)
            await runner.run_job(str(i));self.assertEqual(t.created,1);self.assertEqual(t.sent,1)
    async def test_failed_readback_never_publishes_or_reposts(self):
        t=FakeTransport('readback');runner=ForumRunner(self.store,t)
        await runner.submit('1','AAPL',fresh=False);await runner.run_job('1')
        self.assertEqual(self.store.get('1')['stage'],'BLOCKED');self.assertNotIn('PUBLISHED',t.stages)
        await runner.run_job('1');self.assertEqual(t.sent,1)
    async def test_uncertain_creation_never_retries_automatically(self):
        t=FakeTransport('uncertain_create');runner=ForumRunner(self.store,t)
        await runner.submit('1','AAPL',fresh=False);await runner.run_job('1');await runner.run_job('1')
        self.assertEqual(t.created,1);self.assertEqual(t.sent,0);self.assertEqual(self.store.get('1')['stage'],'BLOCKED')
    async def test_final_status_failure_does_not_certify_published(self):
        t=FakeTransport('final_progress');runner=ForumRunner(self.store,t)
        await runner.submit('1','AAPL',fresh=False);await runner.run_job('1')
        self.assertEqual(self.store.get('1')['stage'],'BLOCKED');self.assertEqual(t.sent,1)
    async def test_invalid_asset_has_no_public_side_effect(self):
        t=FakeTransport();runner=ForumRunner(self.store,t)
        with self.assertRaises(ValueError):await runner.submit('1','MADEUP')
        self.assertIsNone(self.store.get('1'));self.assertEqual(t.created,0)


class ProvenanceTests(unittest.TestCase):
    def test_wrong_source_binding_and_private_credential_url_rejected(self):
        service,_=resolve_asset('AAPL');d=service.details('AAPL');d['evidence_tracks'][0]['sources']=['FORGED']
        with self.assertRaises(ValueError):check_provenance(d)
        d=service.details('AAPL');d['sources'][0]['url']='https://u:p@example.com'
        with self.assertRaises(ValueError):check_provenance(d)
    def test_embed_metadata_normalization_does_not_drop_text(self):
        a={'title':'x','fields':[{'name':'n','value':'v'}]};b={'title':'x','type':'rich','fields':[{'name':'n','value':'v','inline':False}]}
        self.assertEqual(normalize_embed(a),normalize_embed(b));b['fields'][0]['value']='wrong'
        self.assertNotEqual(normalize_embed(a),normalize_embed(b))


class JobCommandTests(unittest.IsolatedAsyncioTestCase):
    async def test_non_owner_cannot_publish_and_no_queue_call(self):
        import discord
        from bot import Config,create_client
        client=create_client(Config(1561042929265418392,1561044080698331337))
        client.forum_owner_id=123;client.forum_runner=SimpleNamespace(submit=AsyncMock())
        group=client.tree.get_commands(guild=discord.Object(1561044080698331337))[0]
        command=next(c for c in group.commands if c.name=='job')
        interaction=SimpleNamespace(guild_id=1561044080698331337,user=SimpleNamespace(id=456),response=SimpleNamespace(send_message=AsyncMock()))
        await command.callback(interaction,'AAPL');client.forum_runner.submit.assert_not_awaited()
        self.assertTrue(interaction.response.send_message.call_args.kwargs['ephemeral']);await client.close()
    async def test_owner_job_uses_interaction_id_for_dedup_and_private_ack(self):
        import discord
        from bot import Config,create_client
        client=create_client(Config(1561042929265418392,1561044080698331337,forum_id=1561052340360978523))
        client.forum_owner_id=123;client.forum_runner=SimpleNamespace(submit=AsyncMock(return_value=({'id':'999','asset_id':'AAPL'},True)))
        command=next(c for c in client.tree.get_commands(guild=discord.Object(1561044080698331337))[0].commands if c.name=='job')
        interaction=SimpleNamespace(id=999,guild_id=1561044080698331337,user=SimpleNamespace(id=123),response=SimpleNamespace(defer=AsyncMock()),followup=SimpleNamespace(send=AsyncMock()))
        await command.callback(interaction,'AAPL');client.forum_runner.submit.assert_awaited_once_with('999','AAPL',fresh=True)
        self.assertTrue(interaction.followup.send.call_args.kwargs['ephemeral']);await client.close()

class FreshWorkerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp=tempfile.TemporaryDirectory();self.store=JobStore(Path(self.temp.name)/'jobs.sqlite')
    async def asyncTearDown(self):self.temp.cleanup()
    def fixture(self):
        service,_=resolve_asset('AAPL');detail=service.details('AAPL');analysis=service.analysis('AAPL')
        from forum_jobs import now
        fetched=now();url='https://www.apple.com/newsroom/rss-feed.rss'
        for source in detail['sources']:source['fetch_url']=url
        return {'detail':detail,'analysis':analysis,'receipt':{'asset_id':'AAPL','mode':'fresh_public_source_read','historical_corpus_used':False,'version':2,'status':'fetched_content','observations':[{'source_id':x['id']} for x in detail['sources']],'paid_calls':0,'fresh_web_fetch':True,'fetched_at':fetched,'sources_succeeded':1,'source_receipts':[{'url':url,'checked':True,'sha256':'a'*64,'http_status':200}]}}
    async def test_actual_callback_events_persist_before_publication_and_mode_survives(self):
        result=self.fixture()
        def producer(asset,callback):
            for stage in ['fetchstarted','fetchcompleted','sourcechecked','formatted']:
                callback(stage,{'source_id':'official-source','unsafe_text':'@everyone SECRET'})
            return result
        def formatter(result):
            from backend.research.discord_brief import format_brief
            return format_brief(result['detail'],result['analysis'])
        t=FakeTransport();runner=ForumRunner(self.store,t)
        with patch('forum_jobs.fresh_result',side_effect=producer),patch.dict('sys.modules',{'backend.research.fresh_content':SimpleNamespace(format_fresh_brief=formatter)}):
            await runner.submit('fresh','AAPL')
            self.assertEqual(JobStore(self.store.path).get('fresh')['meta']['mode'],'fresh_public_source_read')
            await runner.run_job('fresh')
        row=self.store.get('fresh');self.assertEqual(row['stage'],'PUBLISHED')
        stages=[e['stage'] for e in self.store.events('fresh')]
        self.assertLess(stages.index('FETCH_COMPLETED'),stages.index('SOURCE_CHECKED'))
        self.assertLess(stages.index('SOURCE_CHECKED'),stages.index('POSTING_RESULT'))
        self.assertTrue(row['meta']['fresh_web_fetch']);self.assertEqual(t.sent,1)
        text=progress_text(row,self.store.events('fresh'));self.assertIn('Fresh HTTP reads',text)
        self.assertIn('official-source',text);self.assertNotIn('SECRET',text)
    async def test_paid_zero_success_mismatch_and_unknown_event_never_publish(self):
        for case in ['paid','zero','mismatch','event','binding','receipt','metadata']:
            result=self.fixture()
            if case=='paid':result['receipt']['paid_calls']=1
            if case=='metadata':result['receipt']['status']='fetched_metadata'
            if case=='zero':result['detail']['sources']=[]
            if case=='mismatch':result['analysis']['asset_id']='SPY'
            if case=='binding':result['detail']['sources'][0]['fetch_url']='https://unfetched.example'
            if case=='receipt':result['receipt']['source_receipts'][0]['sha256']='bad'
            def producer(asset,callback):
                if case=='event':callback('simulated_agent_activity',{})
                return result
            t=FakeTransport();runner=ForumRunner(self.store,t)
            with patch('forum_jobs.fresh_result',side_effect=producer):
                await runner.submit(case,'AAPL');await runner.run_job(case)
            self.assertEqual(self.store.get(case)['stage'],'BLOCKED');self.assertEqual(t.sent,0)
    async def test_partial_source_failure_is_visible_without_discarding_bound_success(self):
        result=self.fixture();result['receipt']['source_receipts'].append({'url':'https://www.apple.com/leadership/john-ternus/','checked':False,'error_code':'TimeoutError'})
        def producer(asset,callback):
            callback('sourcechecked',{'source_url':'https://www.apple.com/leadership/john-ternus/','check':'failed'})
            return result
        def formatter(result):
            from backend.research.discord_brief import format_brief
            return format_brief(result['detail'],result['analysis'])
        t=FakeTransport();runner=ForumRunner(self.store,t)
        with patch('forum_jobs.fresh_result',side_effect=producer),patch.dict('sys.modules',{'backend.research.fresh_content':SimpleNamespace(format_fresh_brief=formatter)}):
            await runner.submit('partial','AAPL');await runner.run_job('partial')
        row=self.store.get('partial');self.assertEqual(row['stage'],'PUBLISHED')
        self.assertIn('SOURCE_FAILED',t.stages);self.assertEqual(row['meta']['failed_sources'],['www.apple.com'])
        self.assertIn('Failed source reads: www.apple.com',progress_text(row,self.store.events('partial')))

    async def test_stalled_source_progress_is_cancelled_and_blocks_without_result(self):
        class Stalled(FakeTransport):
            async def progress(self,job,events):
                self.stages.append(job['stage'])
                if job['stage']=='FETCH_STARTED':await asyncio.sleep(60)
        def producer(asset,callback):
            callback('fetchstarted',{'source_url':'https://www.apple.com/newsroom/rss-feed.rss'})
            raise AssertionError('Callback should have timed out')
        t=Stalled();runner=ForumRunner(self.store,t)
        with patch('forum_jobs.fresh_result',side_effect=producer),patch('forum_jobs.PROGRESS_TIMEOUT',0.01):
            await runner.submit('stalled','AAPL');await runner.run_job('stalled')
        self.assertEqual(self.store.get('stalled')['stage'],'BLOCKED')
        self.assertEqual(t.stages[-1],'BLOCKED');self.assertEqual(t.sent,0)

    async def test_unsupported_fresh_market_rejected_before_job_creation(self):
        runner=ForumRunner(self.store,FakeTransport())
        with self.assertRaises(ValueError):await runner.submit('unknown','VNQ')
        self.assertIsNone(self.store.get('unknown'))
        row,_=await runner.submit('reviewed','VNQ',fresh=False)
        self.assertNotEqual(row['meta'].get('mode'),'fresh_public_source_read')


if __name__=='__main__':unittest.main()

