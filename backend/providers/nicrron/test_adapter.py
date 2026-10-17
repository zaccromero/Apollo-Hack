"""Offline checks only: synthetic sources/transports, actual sockets forbidden."""
import json
import socket
import tempfile
from pathlib import Path
import unittest
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from datetime import datetime, timezone
from unittest.mock import patch
from .adapter import AnalysisRequest, NicrronAdapter, NicrronConfig, SourceNote, TransportReply, TRACKS, MAX_RESPONSE_BYTES

NOW = lambda: datetime(2026, 10, 17, 16, tzinfo=timezone.utc)
TEXT = 'Revenue increased during the quarter; attribution to the new CEO is unknown.'
NOTE = SourceNote('S1', 'WINA', ('promises_results',), 'Synthetic source', 'https://example.com/report',
                  '2026-10-16', 'published_at', TEXT, SourceNote.hash_text(TEXT))
REQUEST = AnalysisRequest('WINA', 'My growth hypothesis', '2026-10-17', (NOTE,), {'S1': NOTE.identity_sha256()}, 'synthetic-retrieval-1')
ENTRY = {'source_id': 'S1', 'quote': TEXT, 'interpretation': 'This example records growth without proving leadership causality.'}

def answer():
    return {'asset_id': 'WINA', 'cutoff': '2026-10-17',
            'tracks': {t: [dict(ENTRY)] if t == 'promises_results' else [] for t in TRACKS},
            'supporting_evidence': [dict(ENTRY)], 'opposing_evidence': []}

def reply(data=None, finish='stop'):
    return TransportReply(200, json.dumps({'model': 'synthetic-model',
        'choices': [{'message': {'content': json.dumps(data if data is not None else answer())}, 'finish_reason': finish}],
        'usage': {'prompt_tokens': 10, 'completion_tokens': 20, 'total_tokens': 30}}).encode())

class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.calls = []
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        self.pause = Path(temporary.name) / 'pause.json'
        guard = patch.object(socket.socket, 'connect', side_effect=AssertionError('Network forbidden'))
        guard.start(); self.addCleanup(guard.stop)

    def adapter(self, response=None, config=None):
        def transport(payload, conf):
            self.calls.append(payload)
            if isinstance(response, Exception): raise response
            return response if response is not None else reply()
        config = config or NicrronConfig('synthetic-key', enabled=True, credit_paused=False, request_allowance=1)
        config = replace(config, pause_path=self.pause)
        return NicrronAdapter(config, transport=transport, now=NOW)

    def test_default_pause_and_health_make_no_call(self):
        a = self.adapter(config=NicrronConfig())
        self.assertEqual(a.health()['status'], 'credit_paused')
        self.assertEqual(a.analyze(REQUEST)['status'], 'credit_paused')
        self.assertEqual(self.calls, [])

    def test_existing_pause_file_wins_over_enable_flags(self):
        self.pause.write_text('malformed still pauses')
        result = self.adapter().analyze(REQUEST)
        self.assertEqual(result['status'], 'credit_paused')
        self.assertEqual(self.calls, [])

    def test_missing_configuration_disabled_and_zero_allowance(self):
        base = NicrronConfig(enabled=True, credit_paused=False, request_allowance=1)
        for config, expected in [(base, 'missing_configuration'),
             (replace(base, api_key='key', enabled=False), 'disabled'),
             (replace(base, api_key='key', request_allowance=0), 'allowance_exhausted')]:
            self.assertEqual(self.adapter(config=config).analyze(REQUEST)['status'], expected)
        self.assertEqual(self.calls, [])

    def test_invalid_configuration_cannot_send(self):
        base = NicrronConfig('key', enabled=True, credit_paused=False, request_allowance=1)
        for values in [dict(request_allowance=2), dict(request_allowance='1'), dict(max_tokens=3001),
                       dict(timeout_seconds=0), dict(model='unknown/model'), dict(api_key='key\nInjected: yes')]:
            self.assertEqual(self.adapter(config=replace(base, **values)).analyze(REQUEST)['status'], 'invalid_configuration')
        self.assertEqual(self.calls, [])

    def test_valid_quoted_analysis_retains_unknown_and_offline_provenance(self):
        result = self.adapter().analyze(REQUEST)
        self.assertEqual(result['status'], 'completed')
        for t in ['leadership', 'public_sentiment']: self.assertEqual(result['answer']['tracks'][t]['status'], 'unknown')
        self.assertEqual(result['answer']['opposing_evidence']['items'], [])
        for key in ['semantic_grounding_verified', 'network_attempted', 'sponsor_proof']: self.assertFalse(result[key])
        self.assertEqual(result['proof_kind'], 'offline_injected_transport')
        self.assertNotIn('synthetic-key', json.dumps(result))
        self.assertNotIn('synthetic-key', repr(self.adapter().config))
        self.assertEqual(self.calls[0]['max_tokens'], 3000)
        self.assertNotIn('models', self.calls[0])

    def test_source_identity_digest_dates_and_manifest_prevent_call(self):
        for note in [replace(NOTE, asset_id='AAPL'), replace(NOTE, title='Substituted title'), replace(NOTE, tracks=('leadership',)), replace(NOTE, date='2026-10-18'),
                     replace(NOTE, date='2026-02-30'), replace(NOTE, date_kind='unknown'),
                     replace(NOTE, content_sha256='0'*64), replace(NOTE, tracks=('unknown',)),
                     replace(NOTE, url='https://key:secret@example.com')]:
            self.assertEqual(self.adapter().analyze(replace(REQUEST, sources=(note,)))['status'], 'invalid_input')
        for fields in [dict(cutoff='2026-10-18'), dict(expected_source_hashes={'S1':'bad'}),
                       dict(sources=(NOTE,NOTE)), dict(thesis=''), dict(expected_source_hashes={})]:
            self.assertEqual(self.adapter().analyze(replace(REQUEST, **fields))['status'], 'invalid_input')
        self.assertEqual(self.calls, [])

    def test_empty_evidence_prevents_paid_call(self):
        result = self.adapter().analyze(replace(REQUEST, sources=(), expected_source_hashes={}))
        self.assertEqual(result['status'], 'insufficient_evidence'); self.assertEqual(self.calls, [])

    def test_no_silent_context_truncation(self):
        sources = tuple(replace(NOTE, source_id=f'S{i}', text='x'*16000, content_sha256=SourceNote.hash_text('x'*16000)) for i in range(4))
        req = replace(REQUEST, sources=sources, expected_source_hashes={n.source_id:n.identity_sha256() for n in sources})
        self.assertEqual(self.adapter().analyze(req)['status'], 'invalid_input'); self.assertEqual(self.calls, [])

    def test_bad_quote_citation_track_or_identity_has_no_answer(self):
        variants = []
        for key,value in [('source_id','INVENTED'),('quote','An invented quotation.'),('interpretation','')]:
            data=answer(); data['supporting_evidence'][0][key]=value; variants.append(data)
        data=answer(); data['tracks']['leadership']=[dict(ENTRY)]; variants.append(data)
        data=answer(); data['asset_id']='AAPL'; variants.append(data)
        data=answer(); data['cutoff']='2026-10-16'; variants.append(data)
        data=answer(); del data['tracks']['public_sentiment']; variants.append(data)
        data=answer(); data['timing_signal']='buy today'; variants.append(data)
        for data in variants:
            result=self.adapter(reply(data)).analyze(REQUEST)
            self.assertEqual(result['status'],'invalid_output'); self.assertIsNone(result['answer'])

    def test_truncated_oversized_or_invalid_json_has_no_answer(self):
        for response in [reply(finish='length'),TransportReply(200,b'x'*(MAX_RESPONSE_BYTES+1)),
                         TransportReply(200,b'{'),TransportReply(200,b'{"choices":[],"choices":[]}')]:
            result=self.adapter(response).analyze(REQUEST)
            self.assertEqual(result['status'],'invalid_output'); self.assertIsNone(result['answer'])

    def test_errors_consume_allowance_without_retry_or_error_body(self):
        for response in [TransportReply(401,b'echo synthetic-key'),TransportReply(429,b'limit'),
                         TransportReply(500,b'internal'),TimeoutError('contains synthetic-key')]:
            self.calls.clear(); a=self.adapter(response)
            first=a.analyze(REQUEST); second=a.analyze(REQUEST)
            self.assertEqual(first['status'],'provider_error')
            self.assertEqual(second['status'],'allowance_exhausted'); self.assertEqual(len(self.calls),1)
            self.assertNotIn('synthetic-key',json.dumps(first))

    def test_concurrent_requests_use_one_allowance(self):
        a=self.adapter()
        with ThreadPoolExecutor(max_workers=8) as pool: results=list(pool.map(lambda _:a.analyze(REQUEST),range(8)))
        self.assertEqual(sum(r['status']=='completed' for r in results),1); self.assertEqual(len(self.calls),1)

    def test_source_order_does_not_change_fingerprint(self):
        two=replace(NOTE,source_id='S2')
        req=replace(REQUEST,sources=(NOTE,two),expected_source_hashes={'S1':NOTE.identity_sha256(),'S2':two.identity_sha256()})
        one=self.adapter().analyze(req); other=self.adapter().analyze(replace(req,sources=(two,NOTE)))
        self.assertEqual(one['context_sha256'],other['context_sha256'])

class BridgeTests(unittest.TestCase):
    def setUp(self):
        from .bridge import _prism_digest
        self.hash = _prism_digest
        self.source = dict(id='S1', date=NOTE.date, kind='test', title=NOTE.title, url=NOTE.url, text=NOTE.text)
        self.manifest = dict(asset_id='WINA', cutoff='2026-10-17', sources=[self.source])
        self.manifest['corpus_hash'] = self.hash(self.manifest['sources'])
        self.retrieval = dict(status='cached', asset_id='WINA', corpus_hash=self.manifest['corpus_hash'],
                              query_hash=self.hash(REQUEST.thesis), sources=[dict(self.source)], trace_id='offline-trace')

    def make(self, retrieval=None, manifest=None):
        from .bridge import request_from_prism
        return request_from_prism(retrieval or self.retrieval, thesis=REQUEST.thesis,
            frozen_manifest=manifest or self.manifest, tracks_by_source={'S1':('promises_results',)},
            date_kinds={'S1':'published_at'})

    def test_matching_prism_contract_maps_without_network(self):
        request = self.make()
        self.assertEqual(request.sources[0], NOTE)
        self.assertEqual(request.expected_source_hashes['S1'], NOTE.identity_sha256())
        self.assertEqual(request.retrieval_id, 'offline-trace')

    def test_other_asset_or_corpus_and_query_are_rejected(self):
        for change in [dict(asset_id='AAPL'), dict(corpus_hash='different-current-corpus'),
                       dict(query_hash='other-query'), dict(status='disabled')]:
            with self.assertRaises(ValueError): self.make({**self.retrieval, **change})

    def test_metadata_substitution_and_untrusted_manifest_are_rejected(self):
        source = {**self.source, 'date':'2026-10-15'}
        with self.assertRaises(ValueError): self.make({**self.retrieval,'sources':[source]})
        with self.assertRaises(ValueError): self.make(manifest={**self.manifest,'corpus_hash':'bad'})


if __name__=='__main__': unittest.main()
