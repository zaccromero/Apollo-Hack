"""Read-only adapter to Apollo's existing local reviewed corpus, with no fetches."""
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit


def research_payload(question: str, asset: str = '', pasted_url: str = '') -> dict:
    if not isinstance(question, str) or not 1 <= len(question.strip()) <= 1000:
        raise ValueError('Question must be 1-1000 characters.')
    if len(asset) > 80 or len(pasted_url) > 1500:
        raise ValueError('Input too long.')
    if pasted_url:
        parsed = urlsplit(pasted_url)
        if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError('Pasted source context must be an HTTPS URL without credentials.')
    root = Path(__file__).resolve().parents[2]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    from backend.research import ResearchService
    from backend.research.discord_brief import format_brief
    service = ResearchService()
    assets = service.catalog()['assets']
    ids = {item['asset_id'] for item in assets}
    if asset:
        selected = asset.upper()
        if selected not in ids:
            raise ValueError('Choose a supported Apollo asset ID.')
    else:
        matched = set()
        for item in assets:
            terms = {item['asset_id'], item['symbol'], item['name']}
            # Names such as Apple are supported without making a model call.
            if item['asset_id'] == 'AAPL':
                terms.add('Apple')
            if item['asset_id'] == 'WINA':
                terms.add('Winmark')
            if any(term and re.search(r'(?<![\w-])'+re.escape(term)+r'(?![\w-])', question, re.I) for term in terms):
                matched.add(item['asset_id'])
        if not matched and pasted_url:
            for item in assets:
                if any(s.get('url') == pasted_url for s in service.details(item['asset_id'])['sources']):
                    matched.add(item['asset_id'])
        if len(matched) != 1:
            raise ValueError('Specify one asset, such as AAPL/Apple or WINA/Winmark; use the asset option if ambiguous.')
        selected = matched.pop()
    return format_brief(service.details(selected), service.analysis(selected),
                        question=question, pasted_url=pasted_url or None)
