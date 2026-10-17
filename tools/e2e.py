"""Bounded live four-provider journey. Run with the existing foundation Python runtime."""
import asyncio
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shlex
import sys
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parents[1]
SHARED = Path(os.environ.get('APOLLO_PROVIDER_HOME', '/Users/zaccromero/code/hackathon/daytona-hackathon'))
sys.path.insert(0, str(SHARED / 'tools/foundation'))
from foundation.tracing import Tracer, verify_ingestion


def unpack(result):
    if result.is_error:
        raise RuntimeError('Provider rejected operation')
    value = result.structured_content
    if value is None:
        value = '\n'.join(getattr(c, 'text', '') for c in result.content)
    # Daytona file downloads wrap text in a serialized content array.
    for _ in range(5):
        if isinstance(value, str):
            try:
                value = json.loads(value)
            except ValueError:
                break
        elif isinstance(value, list) and len(value) == 1 and 'text' in value[0]:
            value = value[0]['text']
        else:
            break
    return value


@asynccontextmanager
async def connect(name):
    entries = json.loads((ROOT / '.mcp.json').read_text())['mcpServers']
    entry = entries[name]
    with open(os.devnull, 'w') as log:
        async with stdio_client(StdioServerParameters(command=entry['command'], args=entry['args']), errlog=log) as streams:
            async with ClientSession(*streams, read_timeout_seconds=60) as session:
                await session.initialize()
                yield session


def report_files(report):
    target = ROOT / 'results'
    target.mkdir(exist_ok=True)
    text = json.dumps(report, indent=2) + '\n'
    (target / 'latest.json').write_text(text)
    (ROOT / 'ios/ApolloHack/run.json').write_text(text)
    cards = ''.join('<article><small>' + html.escape(s['provider']) + '</small><h2>' + html.escape(s['status']) + '</h2><p>' + html.escape(s['summary']) + '</p></article>' for s in report['steps'])
    (target / 'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Apollo-Hack · Run results</title><style>body{font:17px system-ui;background:#10151d;color:#edf2f6;max-width:960px;margin:60px auto;padding:24px}small{color:#b9c5d2}h1{font-size:44px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}article{background:#1d2733;padding:24px;border-radius:16px}h2{color:#8de3b2}pre{overflow:auto;background:#1d2733;padding:24px;border-radius:16px;font-size:13px}p{line-height:1.6}a{color:#8de3b2}</style><small>APOLLO-HACK / LIVE PROVIDER JOURNEY</small><h1>''' + html.escape(report['status']) + '''</h1><p>Anchor → Daytona → SurrealDB · Arize traces the run.</p><p>Captured evidence from ''' + html.escape(report['started_at']) + '''. Rerun the command to refresh.</p><main>''' + cards + '</main><details><summary>Run evidence</summary><pre>' + html.escape(text) + '</pre></details></html>')


async def run():
    started = datetime.now(timezone.utc).isoformat()
    run_id = 'apollo-' + uuid.uuid4().hex[:12]
    report = {'run_id': run_id, 'started_at': started, 'status': 'RUNNING', 'steps': [], 'cleanup': {}, 'trace_id': '', 'limitations': ['Synthetic public-page test; no hosted evaluator.', 'The iOS app displays a bundled captured run; it does not hold provider credentials.']}
    tracer = Tracer()
    sandbox = browser = None
    def step(provider, summary):
        report['steps'].append({'provider': provider, 'status': 'PASS', 'summary': summary})
        print(provider + ': PASS — ' + summary, flush=True)
    try:
        with tracer.span('apollo.e2e', 'CHAIN', {'apollo.run_id': run_id}) as root_span:
            async with connect('anchor') as anchor, connect('daytona') as daytona, connect('surrealdb-memory') as memory:
                try:
                    with tracer.span('anchor.read_page', 'TOOL') as span:
                        created = unpack(await anchor.call_tool('create_session', {'session': {'initial_url': 'https://example.com', 'recording': {'active': False}, 'timeout': {'max_duration': 3, 'idle_timeout': 1}}}))
                        browser = created['id']
                        state = unpack(await anchor.call_tool('get_session', {'session_id': browser, 'include': 'pages'}))
                        pages = state.get('pages', [])
                        page = next(p for p in pages if p.get('url') == 'https://example.com/')
                        payload = {'run_id': run_id, 'title': page['title'], 'url': page['url']}
                        assert payload['title'] == 'Example Domain', 'Unexpected page title'
                        tracer.finish(span, True, payload)
                        step('Anchor', 'Read Example Domain from the cloud browser.')
                    with tracer.span('daytona.verify_page', 'TOOL') as span:
                        created = unpack(await daytona.call_tool('create_sandbox', {'name': run_id, 'public': False, 'networkBlockAll': True, 'autoStopInterval': 2, 'autoDeleteInterval': 0, 'ttlMinutes': 5}))
                        found = re.search(r'Created new sandbox ([a-f0-9-]{36})', str(created))
                        if not found:
                            raise RuntimeError('Sandbox response lacked expected identifier; five-minute TTL applies')
                        sandbox = found.group(1)
                        code = 'import json,hashlib,pathlib; p=json.loads(' + repr(json.dumps(payload)) + '); assert p["title"]=="Example Domain"; r={**p,"digest":hashlib.sha256((p["title"]+p["url"]).encode()).hexdigest(),"verified":True}; pathlib.Path("/tmp/apollo.json").write_text(json.dumps(r)); print("verified")'
                        execution = unpack(await daytona.call_tool('execute_command', {'id': sandbox, 'command': 'python3 -c ' + shlex.quote(code)}))
                        assert execution['exitCode'] == 0, 'Sandbox command failed'
                        verified = unpack(await daytona.call_tool('file_download', {'id': sandbox, 'filePath': '/tmp/apollo.json'}))
                        expected = hashlib.sha256((payload['title'] + payload['url']).encode()).hexdigest()
                        assert verified == {**payload, 'digest': expected, 'verified': True}, 'Downloaded result mismatch'
                        report['page'] = verified
                        tracer.finish(span, True, verified)
                        step('Daytona', 'Verified Anchor’s page and independently downloaded its SHA-256 result.')
                    with tracer.span('surreal.persist_and_recall', 'TOOL') as span:
                        literal = 'APOLLO_E2E ' + json.dumps(verified, sort_keys=True)
                        written = unpack(await memory.call_tool('remember', {'scope': ['hacksprint'], 'infer': 'none', 'labels': ['project=Apollo-Hack', 'kind=e2e'], 'text': literal}))
                        # New connection ensures this is server persistence, not client state.
                        async with connect('surrealdb-memory') as reader:
                            recalled = unpack(await reader.call_tool('recall', {'query': run_id, 'lens': ['hacksprint'], 'labels': ['project=Apollo-Hack', 'kind=e2e'], 'mode': 'bm25', 'k': 3}))
                        hits = recalled.get('hits', recalled.get('context_hits', []))
                        assert any(hit.get('text') == literal for hit in hits), 'Fresh recall did not match exact result'
                        report['memory_chunk_id'] = written['chunk_id']
                        tracer.finish(span, True, {'chunk_id': written['chunk_id'], 'exact_recall': True})
                        step('SurrealDB', 'Stored Daytona’s result and recalled the exact record through a fresh connection.')
                    tracer.finish(root_span, True, {'run_id': run_id, 'digest': verified['digest']})
                finally:
                    # Attempt both cleanups even if the first fails. Never delete unrelated resources.
                    for provider, client, tool, resource, key in [('Daytona', daytona, 'destroy_sandbox', sandbox, 'id'), ('Anchor', anchor, 'end_session', browser, 'session_id')]:
                        if resource:
                            try:
                                unpack(await client.call_tool(tool, {key: resource}))
                                report['cleanup'][provider] = 'PASS'
                            except Exception as error:
                                report['cleanup'][provider] = 'FAIL: ' + type(error).__name__
    except Exception as error:
        # Provider exceptions can contain private transport URLs: retain only the class.
        report['error_type'] = type(error).__name__
    finally:
        tracer.flush()
        report['trace_id'] = tracer.state['trace_id'] or ''
    if report['trace_id']:
        try:
            ingestion = await verify_ingestion(report['trace_id'], tracer.state['project'], started, tries=3, delay_s=5)
            report['arize'] = ingestion
            required = {'apollo.e2e', 'anchor.read_page', 'daytona.verify_page', 'surreal.persist_and_recall'}
            if ingestion['state'] == 'PASS' and required <= set(ingestion['span_names']):
                step('Arize AX', 'Independently read back all four spans for this exact run.')
        except Exception as error:
            report['arize'] = {'state': 'FAIL', 'error_type': type(error).__name__}
    passed = len(report['steps']) == 4 and all(report['cleanup'].get(p) == 'PASS' for p in ['Daytona', 'Anchor']) and 'error_type' not in report
    report['status'] = 'PASS' if passed else 'FAIL'
    for provider in ['Anchor', 'Daytona', 'SurrealDB', 'Arize AX']:
        if not any(s['provider'] == provider for s in report['steps']):
            report['steps'].append({'provider': provider, 'status': 'FAIL' if provider == 'SurrealDB' and 'page' in report else 'NOT_RUN', 'summary': 'No successful verification receipt; inspect this run’s evidence.'})
    report['finished_at'] = datetime.now(timezone.utc).isoformat()
    report_files(report)
    print('RESULT: ' + report['status'] + ' · ' + run_id, flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(asyncio.run(run()))
