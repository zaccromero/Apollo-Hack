"""Process-local intake jobs and read-only saved public inspections.

No embedded browser session, generic scraper, login or model capability exists.
Saved examples are explicitly replayed; unknown URLs return a blocked job.
"""
import copy
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit


def canonical_url(value):
    if not isinstance(value, str) or len(value) > 2048:
        raise ValueError('An Instagram post URL is required')
    p = urlsplit(value)
    if p.scheme != 'https' or p.hostname not in ('instagram.com', 'www.instagram.com') or p.username or p.password or p.port not in (None, 443):
        raise ValueError('Only HTTPS public Instagram post or reel URLs are supported')
    match = re.fullmatch(r'/(?:p|reel)/([A-Za-z0-9_-]{5,40})/?', p.path)
    if not match or p.fragment:
        raise ValueError('Unsupported Instagram post URL')
    return 'https://www.instagram.com/p/' + match[1] + '/'


class SocialIntakeService:
    def __init__(self, *, inspections_path=None):
        self.jobs = {}  # Process-local research state; no portfolio/database writes.
        path = Path(inspections_path) if inspections_path else Path(__file__).with_name('inspections.json')
        payload = json.loads(path.read_text())
        self.inspected_at = payload['observed_at']
        self.examples = {canonical_url(x['url']): x for x in payload['items']}

    def submit(self, url):
        url = canonical_url(url)
        job_id = 'social-' + hashlib.sha256(url.encode()).hexdigest()[:24]
        if job_id in self.jobs:
            return copy.deepcopy(self.jobs[job_id])
        saved = self.examples.get(url)
        job = {'schema_version': 1, 'job_id': job_id, 'url': url,
               'submitted_at': datetime.now(timezone.utc).isoformat(),
               'storage': 'process_local; lost on server restart',
               'state': 'reviewed_snapshot' if saved else 'blocked',
               'mode': 'saved_public_inspection' if saved else 'runtime_access_unavailable',
               'fresh_fetch': False, 'paid_calls': 0, 'portfolio_changed': False,
               'candidates': [], 'admitted_candidates': [],
               'tracks': ['leadership', 'promises_results', 'public_sentiment']}
        if saved:
            job.update(inspected_at=self.inspected_at, evidence=copy.deepcopy(saved),
                       limitation='Saved browser inspection, not a fresh request. No video/audio transcript was obtained. No exact catalog asset qualified.',
                       reason_code='NO_VERIFIED_ASSET_CANDIDATE')
        else:
            job.update(inspected_at=None, evidence=None,
                       reason_code='BROWSER_RETRIEVAL_REQUIRED',
                       limitation='This backend has no embedded authorized browser retrieval. A supported public-page inspection is required; no caption, transcript or asset is fabricated.')
        self.jobs[job_id] = job
        return copy.deepcopy(job)

    def get(self, job_id):
        if job_id not in self.jobs:
            raise KeyError('Unknown job')
        return copy.deepcopy(self.jobs[job_id])

    def evidence(self, job_id):
        job = self.get(job_id)
        return {k: job[k] for k in ('job_id', 'mode', 'fresh_fetch', 'inspected_at', 'evidence', 'limitation', 'tracks')}

    def admit(self, job_id, candidate_id, reviewed=False):
        self.get(job_id)
        # Current reviewed examples have no verified catalog candidate. Caller assertions
        # cannot turn arbitrary social content into an eligible security or an order.
        return {'job_id': job_id, 'state': 'blocked', 'reason_code': 'NO_ELIGIBLE_REVIEWED_CANDIDATE',
                'admitted': False, 'portfolio_changed': False, 'paid_calls': 0}


class SocialIntakeAPI:
    def __init__(self, service=None):
        self.service = service or SocialIntakeService()

    def handle(self, method, path, body=None):
        parts = urlsplit(path).path.strip('/').split('/')
        try:
            if method == 'POST' and parts == ['research', 'social', 'jobs']:
                if not isinstance(body, dict) or set(body) != {'url'}:
                    raise ValueError('Only url is accepted')
                return 202, self.service.submit(body['url'])
            if len(parts) in (4, 5) and parts[:3] == ['research', 'social', 'jobs']:
                job_id = parts[3]
                if method == 'GET' and len(parts) == 4:
                    return 200, self.service.get(job_id)
                if method == 'GET' and parts[4:] == ['evidence']:
                    return 200, self.service.evidence(job_id)
                if method == 'POST' and parts[4:] == ['admit']:
                    if not isinstance(body, dict) or set(body) != {'candidate_id', 'reviewed'} or body['reviewed'] is not True or not isinstance(body['candidate_id'], str):
                        raise ValueError('Explicit review and candidate_id required')
                    return 409, self.service.admit(job_id, body['candidate_id'], True)
            return 404, {'error': 'Unknown social intake route'}
        except KeyError:
            return 404, {'error': 'Unknown social intake job'}
        except (ValueError, TypeError):
            return 400, {'error': 'Invalid public Instagram intake request'}
