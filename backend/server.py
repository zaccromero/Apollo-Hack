"""Apollo local demo API. Producer modules retain ownership of all business rules."""
from __future__ import annotations
import argparse
from dataclasses import dataclass
import importlib
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlsplit

MAX_BODY = 64 * 1024
ROOT = Path(__file__).resolve().parents[1]

@dataclass
class Adapter:
    name: str
    api: object | None = None
    error: str | None = None

    def handle(self, method, path, body):
        if self.api is None:
            return 503, {'error': 'adapter_unavailable', 'adapter': self.name}
        result = self.api.handle(method, path, body)
        if isinstance(result, tuple) and len(result) == 2 and isinstance(result[0], int) and isinstance(result[1], (dict, list)):
            return result
        if isinstance(result, (dict, list)):
            return 200, result
        raise TypeError('Producer API must return a JSON value or (status, JSON value)')


def adapters(db_path: Path):
    result = {}
    for name in ('paper', 'research'):
        adapter = Adapter(name)
        try:
            module = importlib.import_module('backend.' + name)
            if name == 'paper':
                db_path.parent.mkdir(parents=True, exist_ok=True)
                service = module.PaperService(str(db_path), initial_cash='10000.00')
                adapter.api = module.PaperAPI(service)
            else:
                adapter.api = module.ResearchAPI(module.ResearchService(include_expansion=True))
        except Exception as error:
            adapter.error = type(error).__name__
        result[name] = adapter
    social = Adapter('social')
    try:
        from backend.research.social import SocialIntakeAPI
        social.api = SocialIntakeAPI()
    except Exception as error:
        social.error = type(error).__name__
    result['social'] = social
    provider = Adapter('providers')
    try:
        from backend.provider_gateway import ProviderGateway
        provider.api = ProviderGateway()
    except Exception as error:
        provider.error = type(error).__name__
    result['providers'] = provider
    return result


class ApolloServer(HTTPServer):
    def __init__(self, address, services):
        self.services = services
        super().__init__(address, Handler)


class Handler(BaseHTTPRequestHandler):
    server_version = 'ApolloLocal/1'

    def log_message(self, format, *args):
        # Routine access logs can contain owner-entered theses or asset queries.
        pass

    def reply(self, status, value):
        raw = json.dumps(value, ensure_ascii=False, allow_nan=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(raw)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        self.dispatch()

    def do_POST(self):
        self.dispatch()

    def dispatch(self):
        path = urlsplit(self.path).path
        body = {}
        if self.command == 'POST':
            try:
                length = int(self.headers.get('Content-Length', '-1'))
                if length < 0:
                    return self.reply(411, {'error': 'content_length_required'})
                if length > MAX_BODY:
                    return self.reply(413, {'error': 'body_too_large'})
                if self.headers.get_content_type() != 'application/json':
                    return self.reply(415, {'error': 'json_required'})
                body = json.loads(self.rfile.read(length), parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
                if not isinstance(body, dict):
                    raise ValueError()
            except (ValueError, UnicodeDecodeError):
                return self.reply(400, {'error': 'invalid_json_object'})
        if path == '/health' and self.command == 'GET':
            return self.reply(200, {'product': 'Apollo', 'mode': 'paper_only', 'adapters': {name: {'status': 'ready' if adapter.api else 'unavailable', 'error_type': adapter.error} for name, adapter in self.server.services.items()}})
        name = 'social' if path.startswith('/research/social/') else path.strip('/').split('/')[0]
        adapter = self.server.services.get(name)
        if adapter is None:
            return self.reply(404, {'error': 'route_not_found'})
        try:
            status, value = adapter.handle(self.command, self.path, body)
            self.reply(status, value)
        except Exception:
            self.reply(500, {'error': 'adapter_failed', 'adapter': name})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8767)
    parser.add_argument('--database', type=Path, default=ROOT / 'data/apollo-paper.sqlite')
    args = parser.parse_args()
    server = ApolloServer(('127.0.0.1', args.port), adapters(args.database))
    print('Apollo paper-only API listening on http://127.0.0.1:' + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == '__main__':
    main()
