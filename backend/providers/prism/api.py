"""JSON dispatch only; integration owns HTTP binding and frontend presentation."""
from urllib.parse import urlsplit
from .service import PrismService

class PrismAPI:
    def __init__(self, service=None):
        self.service = service or PrismService()

    def handle(self, method, path, body=None):
        route = urlsplit(path).path.rstrip('/')
        method = method.upper()
        if method == 'GET' and route == '/providers/prism/status':
            return 200, self.service.status()
        if method == 'GET' and route == '/providers/prism/evidence':
            return 200, self.service.evidence_index()
        if method == 'POST' and route in {'/providers/prism/retrieve', '/providers/prism/cached-search'}:
            allowed = {'asset_id', 'query', 'session_id', 'corpus_hash'}
            if not isinstance(body, dict) or set(body) != allowed:
                return 400, {'error': 'Exactly asset_id, query, session_id and corpus_hash required'}
            if body['asset_id'] != self.service.corpus['asset_id']:
                return 422, {'error': 'No assigned PRISM corpus for this asset', 'reason': 'unsupported_asset'}
            if body['corpus_hash'] != self.service.corpus['corpus_hash']:
                return 409, {'error': 'Requested corpus differs from frozen assigned PRISM corpus',
                             'reason': 'corpus_mismatch', 'assigned_corpus_hash': self.service.corpus['corpus_hash']}
            retrieve = self.service.retrieve_cached if route.endswith('/cached-search') else self.service.retrieve
            result = retrieve(body['asset_id'], body['query'], session_id=body['session_id'])
            code = {'invalid_request': 400, 'disabled': 503, 'failed': 502}.get(result['status'], 200)
            return code, result
        return 404, {'error': 'PRISM route not found'}
