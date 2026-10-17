"""Offline PRISM contracts; never live sponsor evidence."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from .service import PrismConfig, PrismService, FIELDS

PROJECT = '00000000-0000-0000-0000-000000000001'

class PrismTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.pause = Path(self.temp.name) / 'pause.json'
        self.calls = []
        self.service = PrismService(PrismConfig(api_key='synthetic-secret', project_id=PROJECT,
            network_enabled=True, telemetry_enabled=True, pause_path=self.pause), transport=self.transport)
        corpus = self.service.corpus
        self.reply = {'results': [{'id': 'chunk-' + source['id'], 'doc_id': doc['id'],
            'content': json.dumps({**source, 'corpus_hash': corpus['corpus_hash']})}
            for source, doc in zip(corpus['sources'], corpus['documents'])]}

    def transport(self, host, key, path, payload):
        self.calls.append((path, payload))
        if path.endswith('/search'): return copy.deepcopy(self.reply)
        if path == '/api/traces': return {'id': PROJECT}
        return {'trajectory_id': PROJECT}

    def retrieve(self):
        return self.service.retrieve('WINA', 'marketing leadership revenue', session_id='apollo-test')

    def answer(self):
        return {key: 'Unknown except the dated source S1.' for key in FIELDS}

    def test_default_off_and_no_calls_on_import_or_status(self):
        service = PrismService(PrismConfig(pause_path=self.pause), transport=self.transport)
        self.assertEqual(service.status()['retrieval_state'], 'network_disabled')
        self.assertEqual(service.retrieve('WINA','revenue',session_id='s')['status'], 'disabled')
        self.assertFalse(self.calls)

    def test_pause_wins_even_with_both_opt_ins(self):
        self.pause.write_text('{"paused": false}')
        result = self.retrieve()
        self.assertEqual(result['reason'], 'credit_paused')
        self.assertEqual(self.service.publish_trace({})['reason'], 'credit_paused')
        self.assertFalse(self.calls)

    def test_missing_configuration_and_invalid_destination(self):
        for config, expected in [
            (PrismConfig(network_enabled=True,pause_path=self.pause),'not_configured'),
            (PrismConfig('synthetic-secret',PROJECT,'https://attacker.invalid',True,pause_path=self.pause),'invalid_host'),
            (PrismConfig('synthetic-secret','invalid',network_enabled=True,pause_path=self.pause),'invalid_project')]:
            service = PrismService(config,transport=self.transport)
            self.assertEqual(service.retrieve('WINA','revenue',session_id='s')['reason'],expected)
        self.assertFalse(self.calls)

    def test_offline_search_has_exact_sources_and_never_live_label(self):
        result = self.service.retrieve_cached('WINA','dividend',session_id='s')
        self.assertEqual(result['status'],'cached')
        self.assertIn('S5',result['source_ids'])
        self.assertFalse(result['network_attempted'])
        self.assertFalse(result['live_verified'])
        self.assertFalse(self.calls)
        self.assertEqual(self.service.retrieve_cached('WINA','zzzzzzzz',session_id='s')['status'],'no_results')

    def test_cross_asset_and_invalid_query_refused_before_provider(self):
        for asset, query, session in [('AAPL','revenue','s'),('WINA','','s'),('WINA','x'*2401,'s'),('WINA','revenue','\nprivate'),(None,{},None)]:
            self.assertEqual(self.service.retrieve(asset,query,session_id=session)['status'],'invalid_request')
        self.assertFalse(self.calls)

    def test_valid_assigned_retrieval_and_mock_is_not_live(self):
        result = self.retrieve()
        self.assertEqual(result['status'],'retrieved')
        self.assertEqual(len(result['sources']),6)
        self.assertEqual(self.calls[0][1]['agent_id'],'money-talks-2-winmark')
        self.assertFalse(result['live_verified'])
        self.assertNotIn('synthetic-secret',json.dumps(result))
        self.assertNotIn('synthetic-secret',repr(self.service.config))

    def test_corrupt_identity_rejected_without_partial_sources(self):
        original = copy.deepcopy(self.reply)
        for field, value in [('corpus_hash','v3-is-not-original'),('id','S99'),('url','https://attacker.invalid'),('text','rewritten')]:
            self.reply = copy.deepcopy(original)
            note = json.loads(self.reply['results'][0]['content']);note[field]=value
            self.reply['results'][0]['content']=json.dumps(note)
            result=self.retrieve()
            self.assertEqual(result['status'],'failed',field)
            self.assertEqual(result['sources'],[])
        self.reply=copy.deepcopy(original);self.reply['results'][0]['doc_id']='foreign-doc'
        self.assertEqual(self.retrieve()['status'],'failed')
        self.reply={'results':[original['results'][0],original['results'][0]]}
        self.assertEqual(self.retrieve()['status'],'failed')

    def test_provider_failure_and_empty_response_not_fabricated(self):
        def failure(*args): raise RuntimeError('synthetic-secret')
        self.service.transport=failure
        result=self.retrieve()
        self.assertEqual(result['status'],'failed')
        self.assertNotIn('synthetic-secret',json.dumps(result))
        self.service.transport=self.transport
        for response, status in [({'results':[]},'no_results'),({},'failed'),({'results':'wrong'},'failed')]:
            self.reply=response
            self.assertEqual(self.retrieve()['status'],status)

    def test_offline_contract_evaluation_not_accuracy_or_judge(self):
        record=self.retrieve();result=self.service.evaluate_response(self.answer(),record)
        self.assertEqual(result['status'],'PASS')
        self.assertFalse(result['provider_evaluator_run'])
        self.assertFalse(result['financial_accuracy_verified'])
        self.assertEqual(self.service.evaluate_response({'leadership':'S1'},record)['status'],'FAIL')
        answer=self.answer();answer['leadership']='S99 invented'
        self.assertIn('unknown_source_citations',self.service.evaluate_response(answer,record)['failures'])
        self.assertEqual(self.service.evaluate_response(self.answer(),{'status':'disabled'})['status'],'FAIL')

    def test_trace_preparation_and_partial_ingest_are_honest(self):
        record=self.retrieve();answer=self.answer();evaluation=self.service.evaluate_response(answer,record)
        payload=self.service.trace_payload(record,question='marketing leadership revenue',answer=answer,model='synthetic-offline-model',latency_ms=10,evaluation=evaluation)
        self.assertEqual(payload['status'],'prepared_not_sent')
        self.assertEqual(payload['trace']['trace_id'],payload['spans']['trace_id'])
        self.assertEqual(len(payload['spans']['spans']),4)
        self.assertNotIn('synthetic-secret',json.dumps(payload))
        self.assertEqual(self.service.publish_trace(payload)['reason'],'unverified_or_offline_model')
        # Synthetic boundary exercise only; never a real model/provider receipt.
        payload['trace']['metadata']['model_proof_kind']='live_provider_response'
        result=self.service.publish_trace(payload)
        self.assertEqual(result['status'],'recorded')
        self.assertFalse(result['live_verified'])
        def partial(host,key,path,body):
            if path=='/api/traces':return {'id':PROJECT}
            raise RuntimeError('secret')
        self.service.transport=partial
        result=self.service.publish_trace(payload)
        self.assertEqual(result['status'],'partial')
        self.assertEqual(result['trace_id'],PROJECT)
        self.assertIsNone(result['trajectory_id'])

    def test_no_telemetry_opt_in_and_offline_records_never_publish(self):
        record=self.service.retrieve_cached('WINA','marketing',session_id='s')
        answer=self.answer();evaluation=self.service.evaluate_response(answer,record)
        payload=self.service.trace_payload(record,question='marketing',answer=answer,model='local',latency_ms=1,evaluation=evaluation)
        self.assertEqual(self.service.publish_trace(payload)['reason'],'offline_trace')
        self.assertFalse(self.calls)
        service=PrismService(PrismConfig('synthetic-secret',PROJECT,network_enabled=True,pause_path=self.pause),transport=self.transport)
        self.assertEqual(service.publish_trace({})['reason'],'telemetry_disabled')

    def test_api_rejects_cross_asset_and_current_corpus_mismatch(self):
        from .api import PrismAPI
        api=PrismAPI(self.service)
        body={'asset_id':'WINA','query':'marketing','session_id':'s','corpus_hash':self.service.corpus['corpus_hash']}
        self.assertEqual(api.handle('POST','/providers/prism/cached-search',body)[0],200)
        body['corpus_hash']='f4ac7c6b2702cf94b1176750ed262cc213a22418936d1060e01667885a1fc020'
        self.assertEqual(api.handle('POST','/providers/prism/retrieve',body)[0],409)
        body['asset_id']='AAPL'
        self.assertEqual(api.handle('POST','/providers/prism/retrieve',body)[0],422)
        body['network_enabled']=True
        self.assertEqual(api.handle('POST','/providers/prism/retrieve',body)[0],400)
        self.assertFalse(self.calls)

    def test_trace_question_binding_and_invalid_latency(self):
        record=self.retrieve();answer=self.answer();evaluation=self.service.evaluate_response(answer,record)
        for question, latency in [('different question',10),('marketing leadership revenue',float('nan')),('marketing leadership revenue',True)]:
            with self.assertRaises(ValueError):
                self.service.trace_payload(record,question=question,answer=answer,model='offline',latency_ms=latency,evaluation=evaluation)

    def test_evidence_distinguishes_historical_from_current(self):
        evidence=self.service.evidence_index()
        self.assertTrue(all(r['status']=='MATCH' for r in evidence['receipt_integrity']))
        self.assertEqual(evidence['current_game']['retrieval'],'NOT_RUN')
        self.assertFalse(evidence['current_game']['owner_acceptance'])
        self.assertEqual(evidence['historical']['matched_runs'],100)

if __name__=='__main__':unittest.main()
