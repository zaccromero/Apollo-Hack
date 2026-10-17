"""Offline checks for Nicrron v1's normalized source-quoted result.

This preserves nested answer groups and unverified interpretations. It does not
invoke Nicrron, a PRISM evaluator, or any network transport.
"""
import hashlib
import json

TRACKS = {'leadership', 'promises_results', 'public_sentiment'}

def nicrron_digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()

def check_nicrron(result, retrieval, corpus, classification, question):
    errors = []
    def fail(reason):
        if reason not in errors: errors.append(reason)
    if result.get('status') != 'completed' or not isinstance(result.get('answer'), dict):
        return ['model_result_unavailable']
    if (result.get('asset_id') != retrieval.get('asset_id') or result.get('asset_id') != corpus['asset_id']
            or result.get('cutoff') != corpus['cutoff'] or result.get('retrieval_id') != retrieval.get('trace_id')):
        fail('model_retrieval_identity_mismatch')
    if (classification.get('corpus_hash') != corpus['corpus_hash']
            or retrieval.get('corpus_hash') != corpus['corpus_hash']):
        fail('corpus_identity_mismatch')
    if not isinstance(question, str) or hashlib.sha256(json.dumps(question, sort_keys=True).encode()).hexdigest() != retrieval.get('query_hash'):
        fail('query_identity_mismatch')
    known = {s['id']: s for s in corpus['sources']}
    sources = retrieval.get('sources')
    if not isinstance(sources, list) or not sources:
        return errors + ['retrieval_unavailable']
    expected_notes, seen = [], set()
    for source in sources:
        if not isinstance(source, dict):
            fail('retrieved_source_identity_mismatch'); continue
        sid = source.get('id'); expected = known.get(sid)
        if (not expected or sid in seen or {k: source.get(k) for k in expected} != expected
                or set(source) - set(expected) - {'provider_doc_id','provider_chunk_id'}):
            fail('retrieved_source_identity_mismatch'); continue
        seen.add(sid)
        expected_notes.append({'source_id':sid, 'asset_id':corpus['asset_id'],
            'tracks':classification['tracks_by_source'][sid], 'title':expected['title'], 'url':expected['url'],
            'date':expected['date'], 'date_kind':classification['date_kinds'][sid], 'text':expected['text'],
            'content_sha256':hashlib.sha256(expected['text'].encode()).hexdigest()})
    expected_notes.sort(key=lambda s:s['source_id'])
    if result.get('sources') is None or nicrron_digest(result['sources']) != nicrron_digest(expected_notes):
        fail('model_source_identity_mismatch')
    if result.get('source_sha256') != nicrron_digest(expected_notes):
        fail('model_source_digest_mismatch')
    if isinstance(question, str):
        context={'asset_id':corpus['asset_id'],'thesis':question,'cutoff':corpus['cutoff'],
                 'retrieval_id':retrieval.get('trace_id'),'sources':expected_notes}
        if result.get('context_sha256') != nicrron_digest(context): fail('model_context_digest_mismatch')
    answer = result['answer']
    if set(answer) != {'tracks','supporting_evidence','opposing_evidence'}:
        return errors + ['invalid_quoted_response_contract']
    groups = answer['tracks']
    if not isinstance(groups, dict) or set(groups) != TRACKS:
        return errors + ['invalid_evidence_tracks']
    by_id={s['source_id']:s for s in expected_notes}
    for track, group in list(groups.items()) + [(None,answer['supporting_evidence']),(None,answer['opposing_evidence'])]:
        if not isinstance(group,dict) or set(group) != {'status','items'} or not isinstance(group.get('items'),list) or len(group['items'])>4:
            fail('invalid_evidence_group');continue
        entries=group['items']
        if group['status'] != ('quoted_evidence' if entries else 'unknown'): fail('unknown_status_mismatch')
        for entry in entries:
            if not isinstance(entry,dict) or set(entry) != {'source_id','quote','interpretation'}:
                fail('invalid_evidence_entry');continue
            sid=entry['source_id'];quote=entry['quote'];interpretation=entry['interpretation']
            note=by_id.get(sid) if isinstance(sid,str) else None
            if not note or not isinstance(quote,str) or not 12<=len(quote.strip()) or len(quote)>1200 or quote not in note['text']:
                fail('unsupported_quote_or_source')
            if not isinstance(interpretation,str) or not interpretation.strip() or len(interpretation)>800:
                fail('invalid_generated_interpretation')
            if note and track and track not in note['tracks']: fail('cross_track_citation')
    return errors
