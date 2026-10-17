"""Pure Discord presentation of reviewed research; no fetching, models or secrets."""
from urllib.parse import urlsplit

CHANNELS = [('leadership', 'Leadership', 0x5865F2),
            ('promises_results', 'Promises vs results', 0xE6A23C),
            ('public_sentiment', 'Public sentiment', 0x9B59B6)]


def _text(value, limit):
    # Source/user text must not inject mentions or Discord link syntax.
    value = str(value or '').replace('@', '@\u200b')
    for c in ('*', '_', '`', '[', ']', '<', '>'):
        value = value.replace(c, '\\' + c)
    return value[:limit - 1] + '…' if len(value) > limit else value


def _url(value):
    if not isinstance(value, str) or len(value) > 700:
        return None
    try:
        p = urlsplit(value)
        if p.scheme not in ('https', 'http') or not p.hostname or p.username or p.password:
            return None
        if any(c in value for c in '\r\n<> \\'):
            return None
        return value.replace('(', '%28').replace(')', '%29')
    except ValueError:
        return None


def format_brief(detail, analysis, *, question='', pasted_url=None):
    """Return Discord create-message fields. Caller owns asset resolution/auth/delivery.

    Exact matching detail/analysis required. Does not answer arbitrary questions,
    fetch a pasted URL, infer source counts, or certify freshness/completeness.
    """
    aid = detail.get('asset_id')
    if not aid or analysis.get('asset_id') != aid:
        raise ValueError('Matching asset identity required')
    if detail.get('corpus_hash') != analysis.get('corpus_hash'):
        raise ValueError('Matching corpus identity required')
    sources = {s['id']: s for s in detail.get('sources', []) if isinstance(s, dict) and s.get('id')}

    def links(ids):
        lines = []
        for sid in list(dict.fromkeys(ids))[:3]:
            s = sources.get(sid, {})
            u = _url(s.get('url'))
            if u:
                date = _text(s.get('date', 'unknown'), 35)
                kind = s.get('date_kind')
                label = ('reviewed/observed as of ' + date + '; publication date unknown') if kind == 'reviewed_at' else ('published ' + date if s.get('date') else 'publication date unknown')
                line = '[' + _text(s.get('title', sid), 70) + '](' + u + ') · ' + label
                if sum(map(len, lines)) + len(line) + len(lines) <= 600:
                    lines.append(line)
        return '\n'.join(lines) or 'No displayable reviewed source link in this section.'

    sides = analysis.get('opposing_evidence') or {}
    fields = []
    for key, title in [('supports_caution', 'Evidence for caution'), ('counterevidence', 'Counterevidence')]:
        side = sides.get(key) or {}
        fields.append({'name': title, 'value': _text(side.get('text', 'Unknown: no reviewed directional evidence.'), 300) + '\n' + links(side.get('sources', []))})
    fields.append({'name': 'Limits', 'value': _text(sides.get('limits', 'No verified valuation, entry signal or future-return conclusion.'), 330)})
    cutoff = _text(detail.get('evidence_cutoff', 'unknown'), 40)
    overview = {'title': _text(str(aid) + ' · reviewed stock / asset brief', 120), 'color': 0x2ECC71,
                'description': 'Reviewed snapshot cutoff: **' + cutoff + '**. Source dates are labeled published or reviewed/observed; observation dates do not establish publication dates. This is not a live web search; completeness and latest updates are unverified.', 'fields': fields}
    tracks = {t.get('key'): t for t in detail.get('evidence_tracks', []) if isinstance(t, dict)}
    embeds = [overview]
    for key, title, color in CHANNELS:
        t = tracks.get(key, {})
        parts = [_text(t.get('status', 'Unknown'), 100)]
        parts += [_text(t[k], 120) for k in ('headline', 'body', 'caveat') if t.get(k)]
        if len(parts) == 1:
            parts.append('No reviewed evidence available in this track.')
        if key == 'public_sentiment':
            parts.append('Coverage: the named sample above is a reviewed selection, not a representative public poll. Representativeness, collection-window completeness and platform coverage are unverified; no population sentiment percentage is inferred.')
        parts.append(links(t.get('sources', [])))
        embeds.append({'title': title, 'color': color, 'description': '\n\n'.join(parts)})
    content = 'Source-linked educational research · cached evidence · no trading instruction.'
    if question:
        content += '\nYour question (context only; not a verified claim): ' + _text(question, 350)
    if pasted_url:
        u = _url(pasted_url)
        content += '\nPasted article: ' + ('<' + u + '>' if u else 'invalid or unsupported URL') + ' — NOT FETCHED or reviewed; not used as evidence.'
    # Discord permits 6000 total embed characters. Cap each text field while keeping URLs intact.
    total = sum(len(e.get('title', '')) + len(e.get('description', '')) + sum(len(f['name']) + len(f['value']) for f in e.get('fields', [])) for e in embeds)
    if total > 5900:
        # Very long source URLs: preserve source links in their own track and shorten overview.
        for f in overview['fields']:
            f['value'] = f['value'].split('\n')[0][:350]
    return {'content': content[:1900], 'embeds': embeds, 'allowed_mentions': {'parse': []}}
