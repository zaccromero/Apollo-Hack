"""Validate PRISM's returned notes against its separately frozen manifest.

This maps data only: no retrieval, model call, telemetry, credential access or I/O.
"""
import hashlib
import json
from .adapter import AnalysisRequest, SourceNote


def _prism_digest(value):
    # PRISM v1's externally defined canonicalization (not Nicrron's digest).
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def request_from_prism(retrieval, *, thesis, frozen_manifest, tracks_by_source, date_kinds):
    """Only exact same-asset/same-corpus notes can become model context.

    tracks_by_source/date_kinds are explicit reviewed classifications keyed by
    original source ID. Never infer a publication date from a review date.
    """
    if not isinstance(retrieval, dict) or not isinstance(frozen_manifest, dict):
        raise ValueError('PRISM retrieval and separately frozen manifest required')
    asset = frozen_manifest['asset_id']
    if (retrieval.get('status') not in ('cached', 'retrieved')
            or retrieval.get('asset_id') != asset
            or retrieval.get('corpus_hash') != frozen_manifest['corpus_hash']
            or _prism_digest(frozen_manifest['sources']) != frozen_manifest['corpus_hash']
            or retrieval.get('query_hash') != _prism_digest(thesis)):
        raise ValueError('Retrieval status, query, asset or corpus mismatch')
    sources = retrieval.get('sources')
    if not isinstance(sources, list) or not sources or len(sources) > 24:
        raise ValueError('No bounded retrieved source set')
    known = {s['id']: s for s in frozen_manifest['sources']}
    if len(known) != len(frozen_manifest['sources']):
        raise ValueError('Duplicate frozen source IDs')
    notes, seen = [], set()
    for source in sources:
        expected = known.get(source.get('id'))
        if (not expected or source['id'] in seen
                or set(source) - set(expected) - {'provider_doc_id', 'provider_chunk_id'}
                or {key: source.get(key) for key in expected} != expected):
            raise ValueError('Retrieved source identity mismatch')
        sid = source['id']; seen.add(sid)
        classifications = tracks_by_source[sid]
        if not isinstance(classifications, tuple):
            raise ValueError('Explicit immutable track assignment required')
        notes.append(SourceNote(sid, asset, classifications, expected['title'], expected['url'],
            expected['date'], date_kinds[sid], expected['text'], SourceNote.hash_text(expected['text'])))
    return AnalysisRequest(asset, thesis, frozen_manifest['cutoff'], tuple(notes),
        {n.source_id: n.identity_sha256() for n in notes}, retrieval['trace_id'])
