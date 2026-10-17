"""Transport-neutral API. The shared server owns HTTP, authentication and binding."""
import re
from urllib.parse import urlsplit
from .models import PaperError


class PaperAPI:
    def __init__(self, service):
        self.service = service

    def handle(self, method, path, body=None):
        """Return (HTTP status, JSON-serializable dict). Unknown request fields fail closed."""
        try:
            if body is None:
                body = {}
            if not isinstance(body, dict):
                raise PaperError('invalid_body', 'Body must be a JSON object')
            method, path = method.upper(), urlsplit(path).path.rstrip('/')
            if method == 'POST' and path == '/paper/compare':
                self._fields(body, {'asset_id', 'quantity'}, {'strategy_id', 'strategy_budget'})
                return 200, self.service.compare(**body)
            if method == 'GET' and path == '/paper/profile':
                return 200, self.service.profile()
            if method == 'POST' and path == '/paper/profile':
                self._fields(body, {'tolerance', 'confirmed'})
                return 200, self.service.set_profile(**body)
            if method == 'GET' and path == '/paper/portfolio':
                return 200, self.service.portfolio()
            if method == 'GET' and path == '/paper/state':
                return 200, self.service.state()
            if method == 'GET' and path == '/paper/catalog':
                return 200, self.service.catalog()
            if method == 'POST' and path == '/paper/orders/preview':
                self._fields(body, {'asset_id', 'quantity', 'client_request_id'}, {'side', 'thesis'})
                return 200, self.service.preview_order(**body)
            match = re.fullmatch(r'/paper/orders/([^/]+)/(confirm|cancel)', path)
            if method == 'POST' and match:
                order_id, action = match.groups()
                if action == 'confirm':
                    self._fields(body, {'confirmed'}, {'mixed_exception_acknowledged'})
                    return 200, self.service.confirm_order(order_id, **body)
                self._fields(body, set())
                return 200, self.service.cancel_order(order_id)
            if method == 'POST' and path == '/paper/copy/preview':
                self._fields(body, {'strategy_id', 'budget', 'client_request_id'}, {'thesis'})
                return 200, self.service.preview_copy(**body)
            if method == 'POST' and path == '/paper/decisions':
                # asset_id is accepted as a convenience; target_id also supports strategy cards.
                if 'asset_id' in body and 'target_id' not in body:
                    body = {**body, 'target_id': body['asset_id']}
                    del body['asset_id']
                self._fields(body, {'target_id', 'action'}, {'thesis'})
                return 200, self.service.record_decision(**body)
            if method == 'POST' and path == '/paper/reset/preview':
                self._fields(body, set())
                return 200, self.service.preview_reset()
            if method == 'POST' and path == '/paper/reset/confirm':
                self._fields(body, {'reset_token', 'confirmed', 'confirmation_phrase'})
                return 200, self.service.confirm_reset(**body)
            return 404, {'error': {'code': 'route_not_found', 'message': 'Paper route not found'}, 'mode': 'paper'}
        except PaperError as error:
            return error.status, {'error': {'code': error.code, 'message': str(error)}, 'mode': 'paper'}
        except (TypeError, AttributeError):
            return 400, {'error': {'code': 'invalid_request', 'message': 'Request fields have invalid types'}, 'mode': 'paper'}

    @staticmethod
    def _fields(body, required, optional=None):
        optional = optional or set()
        if required - body.keys() or body.keys() - required - optional:
            raise PaperError('invalid_fields', 'Missing or unsupported request fields')
