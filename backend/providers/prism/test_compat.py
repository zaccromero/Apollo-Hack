"""Nested Nicrron compatibility, purely offline; no scores/model calls."""
import copy
import hashlib
import json
import unittest
from .service import PrismService
from .compat import nicrron_digest, TRACKS

class QuotedCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.service=PrismService()
        self.question='marketing leadership revenue dividend'
        self.retrieval=self.service.retrieve_cached('WINA',self.question,session_id='compat-test')
        notes=[]
        for source in self.retrieval['sources']:
            sid=source['id']
            notes.append({'source_id':sid,'asset_id':'WINA','tracks':self.service.classifications['tracks_by_source'][sid],
                'title':source['title'],'url':source['url'],'date':source['date'],'date_kind':'published_at',
                'text':source['text'],'content_sha256':hashlib.sha256(source['text'].encode()).hexdigest()})
        notes.sort(key=lambda s:s['source_id']);self.notes=notes
        source=next(s for s in notes if s['source_id']=='S1')
        entry={'source_id':'S1','quote':source['text'][:80],'interpretation':'Generated analysis remains unverified.'}
        group=lambda entries:{'status':'quoted_evidence' if entries else 'unknown','items':entries}
        self.result={'provider':'nicrron','status':'completed','asset_id':'WINA','cutoff':'2026-10-17',
            'retrieval_id':self.retrieval['trace_id'],'actual_model':'synthetic-offline-model',
            'proof_kind':'offline_injected_transport','sources':notes,'source_sha256':nicrron_digest(notes),
            'answer':{'tracks':{t:group([dict(entry)] if t=='leadership' else []) for t in TRACKS},
                'supporting_evidence':group([dict(entry)]),'opposing_evidence':group([])}}
        context={'asset_id':'WINA','thesis':self.question,'cutoff':'2026-10-17',
                 'retrieval_id':self.retrieval['trace_id'],'sources':notes}
        self.result['context_sha256']=nicrron_digest(context)

    def evaluate(self,result=None,retrieval=None,question=None):
        return self.service.evaluate_response(self.result if result is None else result,
            self.retrieval if retrieval is None else retrieval,question=self.question if question is None else question)

    def test_normalized_nested_result_passes_without_flattening(self):
        result=self.evaluate()
        self.assertEqual(result['status'],'PASS')
        self.assertEqual(result['response_schema'],'nicrron_source_quoted_v1')
        self.assertFalse(result['provider_evaluator_run'])
        self.assertFalse(result['semantic_grounding_verified'])
        before=copy.deepcopy(self.result)
        payload=self.service.trace_payload(self.retrieval,question=self.question,answer=self.result,
            model='synthetic-offline-model',latency_ms=1,evaluation=result)
        self.assertEqual(json.loads(payload['trace']['output_message']),before)
        self.assertEqual(self.result,before)
        self.assertEqual(payload['trace']['metadata']['model_proof_kind'],'offline_injected_transport')
        self.assertFalse(payload['trace']['metadata']['sponsor_acceptance'])

    def test_paused_or_failed_result_is_never_a_generated_answer(self):
        for status in ['credit_paused','provider_error','invalid_output']:
            result=copy.deepcopy(self.result);result.update(status=status,answer=None)
            self.assertIn('model_result_unavailable',self.evaluate(result)['failures'])

    def test_wrong_asset_date_retrieval_and_query_fail(self):
        for key,value in [('asset_id','AAPL'),('cutoff','2026-10-16'),('retrieval_id','foreign-run')]:
            result=copy.deepcopy(self.result);result[key]=value
            self.assertEqual(self.evaluate(result)['status'],'FAIL')
        self.assertIn('query_identity_mismatch',self.evaluate(question='different')['failures'])
        retrieval=copy.deepcopy(self.retrieval);retrieval['corpus_hash']='f4ac-current-v3'
        self.assertIn('corpus_identity_mismatch',self.evaluate(retrieval=retrieval)['failures'])

    def test_mutated_normalized_source_or_context_fails(self):
        for key in ['text','title','url','date','date_kind','asset_id','tracks','content_sha256']:
            result=copy.deepcopy(self.result);result['sources'][0][key]='tampered'
            self.assertIn('model_source_identity_mismatch',self.evaluate(result)['failures'])
        result=copy.deepcopy(self.result);result['context_sha256']='wrong'
        self.assertIn('model_context_digest_mismatch',self.evaluate(result)['failures'])

    def test_quotes_citations_and_track_membership_remain_exact(self):
        for key,value in [('source_id','S99'),('quote','A fabricated quotation.'),('interpretation','')]:
            result=copy.deepcopy(self.result);result['answer']['supporting_evidence']['items'][0][key]=value
            self.assertEqual(self.evaluate(result)['status'],'FAIL')
        result=copy.deepcopy(self.result)
        result['answer']['tracks']['public_sentiment']=copy.deepcopy(result['answer']['tracks']['leadership'])
        self.assertIn('cross_track_citation',self.evaluate(result)['failures'])

    def test_empty_evidence_stays_unknown_and_is_not_filled(self):
        result=copy.deepcopy(self.result);result['answer']['tracks']['leadership']={'status':'unknown','items':[]}
        self.assertEqual(self.evaluate(result)['status'],'PASS')
        result['answer']['opposing_evidence']['status']='quoted_evidence'
        self.assertIn('unknown_status_mismatch',self.evaluate(result)['failures'])

    def test_model_identity_cannot_change_when_building_trace(self):
        evaluation=self.evaluate()
        with self.assertRaises(ValueError):
            self.service.trace_payload(self.retrieval,question=self.question,answer=self.result,
                model='different-model',latency_ms=1,evaluation=evaluation)

    def test_malformed_group_is_failed_offline_check(self):
        for group in [None,[],{'status':'unknown','items':'wrong'}]:
            result=copy.deepcopy(self.result);result['answer']['supporting_evidence']=group
            self.assertEqual(self.evaluate(result)['status'],'FAIL')

if __name__=='__main__':unittest.main()
