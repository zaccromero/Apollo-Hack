"""Bounded PRISM adapter: no model generation, evaluator jobs or retry loops.

Live search/telemetry need separate server-only opt-ins and no credit-pause file.
Opt-ins describe configuration; they do not grant owner authorization.
"""
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import re
import time
from urllib.error import HTTPError
from urllib.request import Request, build_opener, HTTPRedirectHandler, ProxyHandler
from uuid import UUID, uuid4
from .compat import check_nicrron

HERE = Path(__file__).resolve().parent
APPROVED_HOSTS = {'https://api.prism.blockconvey.com', 'https://prism.blockconvey.com'}
PAUSE = Path('/Users/zaccromero/code/hackathon/plutus/research/credit-pause.json')
FIELDS = {'leadership', 'promises_results', 'public_sentiment', 'challenge', 'next_watch'}

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

def stamp():
    return datetime.now(timezone.utc).isoformat()

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

class ProviderError(Exception):
    pass

def request_json(host, key, path, payload):
    """Single bounded HTTP request; no redirects, proxies or retries."""
    request = Request(host + path, data=json.dumps(payload, allow_nan=False).encode(),
                      headers={'Content-Type': 'application/json', 'X-PRISMtrace-Key': key}, method='POST')
    try:
        with build_opener(ProxyHandler({}), NoRedirect()).open(request, timeout=12) as response:
            raw = response.read(1_048_577)
            if len(raw) > 1_048_576:
                raise ProviderError('response_too_large')
            return json.loads(raw)
    except HTTPError as error:
        raise ProviderError('http_' + str(error.code)) from None
    except (OSError, ValueError):
        raise ProviderError('transport_error') from None

@dataclass(frozen=True)
class PrismConfig:
    api_key: str = field(default='', repr=False)
    project_id: str = ''
    host: str = 'https://api.prism.blockconvey.com'
    network_enabled: bool = False
    telemetry_enabled: bool = False
    pause_path: Path = PAUSE

    @classmethod
    def from_env(cls, env=None):
        env = os.environ if env is None else env
        return cls(api_key=env.get('PRISMTRACE_API_KEY', ''), project_id=env.get('PRISMTRACE_PROJECT_ID', ''),
                   host=env.get('PRISMTRACE_HOST', 'https://api.prism.blockconvey.com').rstrip('/'),
                   network_enabled=env.get('APOLLO_PRISM_NETWORK_ENABLED') == 'true',
                   telemetry_enabled=env.get('APOLLO_PRISM_TELEMETRY_ENABLED') == 'true')

    def problem(self, telemetry=False):
        # Existing pause-file presence wins even if its content is malformed/false.
        if Path(self.pause_path).exists(): return 'credit_paused'
        if not self.network_enabled: return 'network_disabled'
        if telemetry and not self.telemetry_enabled: return 'telemetry_disabled'
        if not self.api_key or not self.project_id: return 'not_configured'
        if self.host not in APPROVED_HOSTS: return 'invalid_host'
        try: UUID(self.project_id)
        except (ValueError, TypeError, AttributeError): return 'invalid_project'
        return None

class PrismService:
    def __init__(self, config=None, *, transport=None):
        self.config = config or PrismConfig.from_env()
        self.transport = transport or request_json
        self.corpus = json.loads((HERE / 'corpus.json').read_text())
        self.sources = {source['id']: source for source in self.corpus['sources']}
        if len(self.sources) != len(self.corpus['sources']) or digest(self.corpus['sources']) != self.corpus['corpus_hash']:
            raise ValueError('Frozen corpus identity mismatch')
        self.documents = {doc['id']: doc for doc in self.corpus['documents']}
        self.classifications = json.loads((HERE / 'classifications.json').read_text())

    def status(self):
        config = self.config
        return {'provider': 'prism', 'retrieval_state': config.problem() or 'enabled_unverified',
                'telemetry_state': config.problem(True) or 'enabled_unverified',
                'configuration_present': bool(config.api_key and config.project_id),
                'network_enabled': config.network_enabled, 'telemetry_enabled': config.telemetry_enabled,
                'live_verified': False, 'supported_assets': [self.corpus['asset_id']],
                'corpus_hash': self.corpus['corpus_hash'], 'model_generation': False}

    def evidence_index(self):
        return json.loads((HERE / 'evidence.json').read_text())

    def _validate_request(self, asset_id, query, session_id):
        if asset_id != self.corpus['asset_id']: return 'unsupported_asset'
        if not isinstance(query, str) or not query.strip() or len(query) > 2400: return 'invalid_query'
        if not isinstance(session_id, str) or not re.fullmatch(r'[A-Za-z0-9_.:-]{1,120}', session_id): return 'invalid_session'
        return None

    def _record(self, asset_id, query, session_id, mode):
        return {'provider': 'prism', 'asset_id': asset_id if isinstance(asset_id, str) else None,
                'trace_id': str(uuid4()), 'session_id': session_id if isinstance(session_id, str) else None,
                'agent_id': self.corpus['agent_id'], 'corpus_hash': self.corpus['corpus_hash'], 'cutoff': self.corpus['cutoff'],
                'query_hash': digest(query) if isinstance(query, str) else None,
                'started_at': stamp(), 'mode': mode, 'status': 'started', 'sources': [],
                'network_attempted': False, 'live_verified': False, 'telemetry_status': 'not_sent',
                'evidence_scope': 'current_local_request_not_sponsor_acceptance'}

    def _finish(self, record, status, reason=None):
        record.update(status=status, ended_at=stamp())
        if reason: record['reason'] = reason
        return record

    def retrieve_cached(self, asset_id, query, *, session_id):
        """Local lexical search over frozen notes, never a live PRISM receipt."""
        record = self._record(asset_id, query, session_id, 'offline_curated_corpus')
        problem = self._validate_request(asset_id, query, session_id)
        if problem: return self._finish(record, 'invalid_request', problem)
        terms = set(re.findall(r'[a-z0-9]{3,}', query.lower()))
        ranked = []
        for source in self.sources.values():
            words = set(re.findall(r'[a-z0-9]{3,}', (source['title'] + ' ' + source['text']).lower()))
            score = len(terms & words)
            if score: ranked.append((score, source['id'], source))
        record['sources'] = [copy.deepcopy(row[2]) for row in sorted(ranked, key=lambda x: (-x[0], x[1]))]
        record['source_ids'] = [source['id'] for source in record['sources']]
        record['context_hash'] = digest(record['sources'])
        return self._finish(record, 'cached' if ranked else 'no_results')

    def _checked_sources(self, response):
        if not isinstance(response, dict) or not isinstance(response.get('results'), list): raise ProviderError('invalid_response')
        if len(response['results']) > 6: raise ProviderError('invalid_response')
        sources, seen = [], set()
        for match in response['results']:
            if not isinstance(match, dict) or match.get('doc_id') not in self.documents: raise ProviderError('source_identity_mismatch')
            doc = self.documents[match['doc_id']]
            try:
                note = json.loads(match['content']); sid = note['id']; expected = self.sources[sid]
                if (sid in seen or doc['name'] != sid + '-' + self.corpus['corpus_hash'][:8] + '.md'
                        or doc['agent_id'] != self.corpus['agent_id'] or note.get('corpus_hash') != self.corpus['corpus_hash']
                        or {key: note[key] for key in expected} != expected
                        or date.fromisoformat(note['date']) > date.fromisoformat(self.corpus['cutoff'])):
                    raise ValueError()
            except (ValueError, KeyError, TypeError): raise ProviderError('source_identity_mismatch') from None
            seen.add(sid)
            sources.append({**copy.deepcopy(expected), 'provider_doc_id': match['doc_id'], 'provider_chunk_id': match.get('id')})
        return sources

    def retrieve(self, asset_id, query, *, session_id):
        record = self._record(asset_id, query, session_id, 'prism_assigned_kb')
        problem = self._validate_request(asset_id, query, session_id)
        if problem: return self._finish(record, 'invalid_request', problem)
        problem = self.config.problem()
        if problem: return self._finish(record, 'disabled', problem)
        record['network_attempted'] = True; started = time.monotonic()
        try:
            response = self.transport(self.config.host, self.config.api_key, '/api/knowledge-base/search',
                {'project_id': self.config.project_id, 'agent_id': self.corpus['agent_id'], 'query': query.strip(), 'limit': 6})
            record['sources'] = self._checked_sources(response)
            record['source_ids'] = [s['id'] for s in record['sources']]
            record['context_hash'] = digest(record['sources'])
            record['duration_ms'] = round((time.monotonic() - started) * 1000)
            record['live_verified'] = self.transport is request_json and bool(record['sources'])
            return self._finish(record, 'retrieved' if record['sources'] else 'no_results')
        except Exception:
            return self._finish(record, 'failed', 'provider_or_source_validation_failed')

    def evaluate_response(self, answer, retrieval, *, question=None):
        """Offline shape/citation checks, not PRISM LLM-judge/factual scoring."""
        failures = []
        if retrieval.get('status') not in {'cached', 'retrieved'} or not retrieval.get('sources'): failures.append('retrieval_unavailable')
        quoted = isinstance(answer, dict) and answer.get('provider') == 'nicrron'
        if quoted:
            try:
                failures.extend(check_nicrron(answer, retrieval, self.corpus, self.classifications, question))
            except (ValueError, TypeError, KeyError, AttributeError, IndexError):
                failures.append('invalid_quoted_response_contract')
        elif not isinstance(answer, dict) or set(answer) != FIELDS or any(not isinstance(v, str) or not v.strip() or len(v) > 8000 for v in answer.values()):
            failures.append('invalid_response_contract')
        else:
            cited = set(re.findall(r'\bS\d+\b', ' '.join(answer.values())))
            available = {s['id'] for s in retrieval.get('sources', [])}
            if not cited: failures.append('no_source_citations')
            if cited - available: failures.append('unknown_source_citations')
        return {'status': 'PASS' if not failures else 'FAIL', 'failures': failures,
                'kind': 'offline_contract_check', 'provider_evaluator_run': False,
                'financial_accuracy_verified': False, 'semantic_grounding_verified': False,
                'response_schema': 'nicrron_source_quoted_v1' if quoted else 'legacy_five_strings',
                'model_proof_kind': answer.get('proof_kind', 'unverified') if quoted else 'legacy_unverified',
                'trace_id': retrieval.get('trace_id')}

    def trace_payload(self, retrieval, *, question, answer, model, latency_ms, evaluation):
        """Build only. Caller supplies actual model output; no model/job execution."""
        if (retrieval.get('status') not in {'cached', 'retrieved'} or not isinstance(question, str)
                or digest(question) != retrieval.get('query_hash') or not isinstance(model, str) or not model.strip()
                or isinstance(latency_ms, bool) or not isinstance(latency_ms, (int, float))
                or not math.isfinite(latency_ms) or latency_ms < 0
                or evaluation != self.evaluate_response(answer, retrieval, question=question)
                or (isinstance(answer, dict) and answer.get('provider') == 'nicrron' and answer.get('actual_model') != model)):
            raise ValueError('Invalid trace inputs')
        metadata = {key: retrieval[key] for key in ('asset_id', 'agent_id', 'corpus_hash', 'context_hash', 'mode')}
        metadata.update(evaluation_kind='offline_contract_check', sponsor_acceptance=False,
                        response_schema=evaluation['response_schema'], model_proof_kind=evaluation['model_proof_kind'])
        root = str(uuid4())
        spans = [{'span_id': root, 'name': 'Apollo asset research', 'span_type': 'chain',
                  'start_time': retrieval['started_at'], 'end_time': stamp(),
                  'status': 'ok' if evaluation['status'] == 'PASS' else 'error', 'metadata': metadata},
                 {'span_id': str(uuid4()), 'parent_span_id': root, 'name': 'Assigned source retrieval',
                  'span_type': 'retrieval', 'start_time': retrieval['started_at'], 'end_time': retrieval['ended_at'],
                  'input_text': question,
                  'output_text': json.dumps(retrieval['sources'], ensure_ascii=False), 'status': 'ok'},
                 {'span_id': str(uuid4()), 'parent_span_id': root, 'name': 'Model output supplied by caller',
                  'span_type': 'llm', 'model': model, 'start_time': retrieval['ended_at'], 'end_time': stamp(),
                  'input_text': question, 'output_text': json.dumps(answer, ensure_ascii=False),
                  'metadata': {'timing_kind': 'assembly_bounds_not_measured_model_latency'}, 'status': 'ok'},
                 {'span_id': str(uuid4()), 'parent_span_id': root, 'name': 'Response contract validation',
                  'span_type': 'tool', 'start_time': stamp(), 'status': 'ok' if evaluation['status'] == 'PASS' else 'error',
                  'output_text': json.dumps(evaluation), 'metadata': {'tool_name': 'apollo_response_contract'}}]
        return {'trace': {'project_id': self.config.project_id, 'trace_id': retrieval['trace_id'],
                          'model': model, 'input_messages': [{'role': 'user', 'content': question}],
                          'output_message': json.dumps(answer, ensure_ascii=False), 'latency_ms': latency_ms,
                          'session_id': retrieval['session_id'], 'agent_id': retrieval['agent_id'], 'metadata': metadata},
                'spans': {'project_id': self.config.project_id, 'trace_id': retrieval['trace_id'],
                          'session_id': retrieval['session_id'], 'metadata': metadata, 'spans': spans}, 'status': 'prepared_not_sent'}

    def publish_trace(self, payload):
        problem = self.config.problem(True)
        if problem: return {'status': 'disabled', 'reason': problem, 'network_attempted': False}
        if payload.get('trace', {}).get('metadata', {}).get('mode') != 'prism_assigned_kb':
            return {'status': 'rejected', 'reason': 'offline_trace', 'network_attempted': False}
        if payload['trace']['metadata'].get('model_proof_kind') != 'live_provider_response':
            return {'status': 'rejected', 'reason': 'unverified_or_offline_model', 'network_attempted': False}
        receipt = {'status': 'failed', 'network_attempted': True, 'trace_id': None, 'trajectory_id': None}
        try:
            trace = copy.deepcopy(payload['trace']); spans = copy.deepcopy(payload['spans'])
            if trace['project_id'] != self.config.project_id or spans['project_id'] != self.config.project_id or spans['trace_id'] != trace['trace_id']:
                raise ValueError()
            result = self.transport(self.config.host, self.config.api_key, '/api/traces', trace)
            UUID(result['id']); receipt.update(status='partial', trace_id=result['id'])
            ingested = self.transport(self.config.host, self.config.api_key, '/api/spans/ingest', spans)
            UUID(ingested['trajectory_id'])
            receipt.update(status='recorded', trajectory_id=ingested['trajectory_id'], live_verified=self.transport is request_json)
        except Exception: receipt['reason'] = 'telemetry_incomplete_no_retry'
        return receipt
