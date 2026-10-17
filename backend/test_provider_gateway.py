import json
import socket
import unittest
from unittest.mock import patch
from uuid import uuid4
from backend.provider_gateway import ProviderGateway
from backend.server import Adapter, ApolloServer
import http.client
import threading

class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.gateway=ProviderGateway()
        self.body={'request_id':str(uuid4()),'asset_id':'WINA','thesis':{'reason':'Leadership may help','risk':'No causal proof','invalidation':'Results disappoint'},'context':{'mode':'assigned_historical','corpus_hash':self.gateway.prism.corpus['corpus_hash']}}
    def test_pause_mismatch_unsupported_and_invalid_make_no_network_calls(self):
        with patch.object(socket,'create_connection',side_effect=AssertionError('Network forbidden')):
            code,value=self.gateway.handle('POST','/providers/challenge',self.body)
            self.assertEqual((code,value['status']),(503,'paused'));self.assertIsNone(value['answer'])
            self.assertIsNone(value['providers']['nicrron']['actual_model']);self.assertFalse(value['providers']['nicrron']['network_attempted'])
            self.assertEqual([step['status'] for step in value['process_steps']],['recorded','not_run','not_run','not_run','not_sent'])
            self.assertTrue(all(step.get('timestamp') is None for step in value['process_steps'][1:]))
            self.assertIn('historical',value['saved_evidence_notice'])
            self.body['context']['corpus_hash']='f4ac7c6b2702cf94b1176750ed262cc213a22418936d1060e01667885a1fc020'
            self.assertEqual(self.gateway.handle('POST','/providers/challenge',self.body)[0],409)
            self.body['asset_id']='AAPL';self.assertEqual(self.gateway.handle('POST','/providers/challenge',self.body)[0],422)
            self.body['thesis']['reason']='';self.assertEqual(self.gateway.handle('POST','/providers/challenge',self.body)[0],400)
    def test_actual_http_paused_envelope_and_provider_routes(self):
        server=ApolloServer(('127.0.0.1',0),{'providers':Adapter('providers',self.gateway)})
        worker=threading.Thread(target=server.serve_forever,daemon=True);worker.start()
        c=http.client.HTTPConnection('127.0.0.1',server.server_port)
        def call(method,path,body=None):
            c.request(method,path,json.dumps(body) if body is not None else None,{'Content-Type':'application/json'})
            r=c.getresponse();return r.status,json.loads(r.read())
        try:
            self.assertEqual(call('GET','/providers/prism/status')[0],200)
            self.assertEqual(call('GET','/providers/nicrron/status')[1]['requests_remaining'],0)
            self.assertEqual(call('POST','/providers/challenge',self.body)[1]['status'],'paused')
            request={'asset_id':'WINA','query':'marketing leadership','session_id':str(uuid4()),'corpus_hash':self.gateway.prism.corpus['corpus_hash']}
            self.assertEqual(call('POST','/providers/prism/retrieve',request)[0],503)
            status,cached=call('POST','/providers/prism/cached-search',request)
            self.assertEqual(status,200);self.assertEqual(cached['status'],'cached');self.assertFalse(cached['network_attempted'])
            request['corpus_hash']='current';self.assertEqual(call('POST','/providers/prism/retrieve',request)[0],409)
            request['asset_id']='AAPL';self.assertEqual(call('POST','/providers/prism/retrieve',request)[0],422)
        finally:
            c.close();server.shutdown();server.server_close();worker.join()


class OfflinePipelineTests(unittest.TestCase):
    def test_injected_actual_adapter_pipeline_preserves_quotes_unknown_and_trace(self):
        from pathlib import Path
        import tempfile
        from backend.providers.prism.service import PrismService,PrismConfig
        from backend.providers.nicrron import NicrronAdapter,NicrronConfig
        from backend.providers.nicrron.adapter import TransportReply
        class LocalPrism(PrismService):
            def status(self): return {**super().status(),'retrieval_state':'enabled_unverified'}
            def retrieve(self,asset_id,query,*,session_id):
                result=self.retrieve_cached(asset_id,query,session_id=session_id)
                result['status']='retrieved'
                return result
        calls=[]
        def injected(payload,config):
            calls.append(payload)
            context=json.loads(payload['messages'][1]['content'])
            note=next(n for n in context['sources'] if 'leadership' in n['tracks'])
            entry={'source_id':note['source_id'],'quote':note['text'][:80],'interpretation':'OFFLINE injected analysis; causal effect remains unverified.'}
            answer={'asset_id':'WINA','cutoff':context['cutoff'],'tracks':{'leadership':[entry],'promises_results':[],'public_sentiment':[]},'supporting_evidence':[entry],'opposing_evidence':[]}
            return TransportReply(200,json.dumps({'model':'OFFLINE-INJECTED-MODEL','choices':[{'message':{'content':json.dumps(answer)},'finish_reason':'stop'}]}).encode())
        with tempfile.TemporaryDirectory() as tmp,patch.object(socket.socket,'connect',side_effect=AssertionError('Network forbidden')):
            gateway=ProviderGateway(LocalPrism(PrismConfig()),NicrronAdapter(NicrronConfig(api_key='synthetic',enabled=True,credit_paused=False,request_allowance=1,pause_path=Path(tmp)/'absent-test-pause'),transport=injected))
            body={'request_id':str(uuid4()),'asset_id':'WINA','thesis':{'reason':'Leadership marketing','risk':'No causal proof','invalidation':'Results disappoint'},'context':{'mode':'assigned_historical','corpus_hash':gateway.prism.corpus['corpus_hash']}}
            code,result=gateway.handle('POST','/providers/challenge',body)
            self.assertEqual(code,200,result);self.assertEqual(result['status'],'success');self.assertEqual(len(calls),1)
            self.assertEqual(result['providers']['nicrron']['proof_kind'],'offline_injected_transport')
            self.assertFalse(result['providers']['nicrron']['network_attempted']);self.assertFalse(result['sponsor_acceptance'])
            self.assertEqual(result['answer']['tracks']['public_sentiment'],{'status':'unknown','items':[]})
            self.assertTrue(result['answer']['supporting_evidence']['items'][0]['source_id'])
            self.assertEqual(gateway.last_receipt['evaluation']['status'],'PASS')
            self.assertFalse(gateway.last_receipt['telemetry_sent'])
            self.assertEqual(gateway.last_receipt['trace_payload']['status'],'prepared_not_sent')
            self.assertEqual(gateway.handle('POST','/providers/challenge',body)[0],503)
            self.assertIsNone(gateway.last_receipt)


class CredentialBindingTests(unittest.TestCase):
    def test_existing_model_alias_requires_exact_nicrron_destination_and_never_enables_calls(self):
        import os
        from backend.provider_gateway import nicrron_key_from_env
        self.assertEqual(nicrron_key_from_env({'MODEL_API_KEY':'synthetic','MODEL_BASE_URL':'https://other.example/v1'}),'')
        self.assertEqual(nicrron_key_from_env({'MODEL_API_KEY':'synthetic','MODEL_BASE_URL':'https://api.nicrron.ai/v1'}),'synthetic')
        with patch.dict(os.environ,{'NICRRON_API_KEY':'synthetic'},clear=True):
            gateway=ProviderGateway();health=gateway.nicrron.health()
            self.assertTrue(health['configured']);self.assertFalse(health['enabled']);self.assertTrue(health['credit_paused']);self.assertEqual(health['requests_remaining'],0)
            self.assertFalse(gateway.prism.status()['network_enabled']);self.assertFalse(gateway.prism.status()['telemetry_enabled'])
