# Nicrron provider lane

Receiving chat `01a14a82-3e08-7dc3-a673-0e119f891329`; source scope only `backend/providers/nicrron/**` and this file. Coordinator routes integration requests; Integration owns all shared-server/native edits and the canonical ledger. Formal managed claim is NOT ESTABLISHED. Staged release is an explicit import handoff, not source integration or owner acceptance.

Work-ready cutoff October 17, 2026 **16:00 America/New_York**; recording/rehearsal 16:00–16:30; judging 16:30. Submission cutoff remains unverified. First contract checkpoint delivered before 11:57 EDT.

## Observable outcome and authority

An importable, typed, source-quoted thesis-challenge adapter. No startup network, credential lookup, environment mutation, retrieval, telemetry, evaluator job, paid retry or fallback. Plutus is read-only. Current pause remains binding. Ordinary offline implementation/checks are authorized; actual provider calls are NOT authorized by this release.

Default configuration: disabled, credit-paused, allowance zero. Existing Plutus `research/credit-pause.json` file presence wins even over enable flags. Default transport targets only `https://api.nicrron.ai/v1/chat/completions`, rejects redirects, ignores environment proxies, bounds the response to 128 KiB, timeout to 45 seconds and output ceiling to 3000 tokens. Pinned model `openai/gpt-4.1-mini` reuses the existing Plutus route; `nicrron/auto` is a supported explicit alternative. No fallback array is sent. Secret is backend-injected, omitted from config repr and returned receipts. No balance/current credential validity claim.

## Import contract

```python
from backend.providers.nicrron import (
    AnalysisRequest, SourceNote, NicrronConfig, NicrronAdapter,
    request_from_prism,
)

adapter = NicrronAdapter()  # construct once in the shared server; remains paused
status = adapter.health()  # metadata only, no credential content or network
result = adapter.analyze(request)  # AnalysisRequest -> JSON-serializable dict
```

`AnalysisRequest(asset_id, thesis, cutoff, sources, expected_source_hashes, retrieval_id)` is immutable. `sources` is a tuple of `SourceNote(source_id, asset_id, tracks, title, url, date, date_kind, text, content_sha256)`. `tracks` is a tuple containing one or more of `leadership`, `promises_results`, `public_sentiment`; multiple classifications preserve one original source ID. `date_kind` is explicitly `published_at` or `reviewed_at`; they are never interchangeable. Dates are ISO calendar dates, valid and no later than cutoff; cutoff cannot be in the future. Text is exact, with SHA-256 checked against `SourceNote.hash_text(text)`.

**`expected_source_hashes` contains full normalized note identity digests (`note.identity_sha256()`), not text-only hashes.** It must come from a separately trusted manifest/classification, not blindly from the returned search content. Metadata changes (asset, title, URL, date or track) invalidate it. Exact source-set equality and duplicate IDs are checked. At most 24 sources, 48 KB combined context; no silent truncation. Thesis is a bounded user hypothesis, never source evidence.

For PRISM v1 use this pure data mapper after the PRISM owner provides retrieval:

```python
request = request_from_prism(
    retrieval,
    thesis=question,  # exactly the query bound to the retrieval
    frozen_manifest=separately_loaded_prism_corpus,
    tracks_by_source=reviewed_track_assignment,  # source_id -> tuple of track keys
    date_kinds=reviewed_date_classification,     # source_id -> published_at/reviewed_at
)
result = adapter.analyze(request)
```

Mapper validates the frozen PRISM corpus digest, asset ID, query digest, retrieval success state, exact original note metadata/text and corpus equality. It accepts cached or retrieved context but never turns cached context into live PRISM proof. Keep the original retrieval receipt beside the Nicrron result. There is no search client here. Unsupported assets/corpus differences remain blocked in PRISM; do not route AAPL or current WINA into the historical WINA corpus.

## Output and failure contract

Every result has status, answer (null on failure), source/context/prompt/request hashes where available, requested/actual model where available, bounded usage fields, provider timing, attempt flags and proof kind. `completed` means output structure, quoted passages, citation identity and track membership passed; **semantic interpretation has not been independently verified**. Each output evidence entry contains exact `source_id`, `quote`, `interpretation`. Interpretations stay visibly labeled generated analysis. Empty leadership/results/sentiment or supporting/opposing lists become `unknown`, never neutral/50–50 or invented balance. No order, timing signal or guaranteed-return field becomes actionable.

Statuses: `credit_paused`, `disabled`, `missing_configuration`, `invalid_configuration`, `allowance_exhausted`, `insufficient_evidence`, `invalid_input`, `provider_error`, `invalid_output`, `completed`. A failed/invalid response receives no canned answer. HTTP failures return only status code and generic error; bodies and exception text are withheld. Truncation, duplicate JSON keys, wrong asset/cutoff, invented quote/citation and cross-track evidence fail validation. An attempted request consumes the single in-memory allowance even on timeout. Concurrent requests share the allowance; keep one adapter instance and **never reconstruct it to replenish an exhausted grant**. Restart persistence remains an integrator grant-accounting responsibility before any live enablement.

Injected transport checks always emit `proof_kind=offline_injected_transport`, `network_attempted=false`, `sponsor_proof=false`. A real response may emit `live_provider_response` but still does not establish sponsor acceptance. This lane does not launch telemetry or an evaluator.

## Integration request and remaining required proof

Integration should expose metadata in its provider health and wire an explicit thesis-challenge action only when the full retrieval/corpus mapping is valid. Recommended HTTP mapping: invalid input 400, unsupported asset/corpus 409/422 from PRISM, paused/configuration/allowance states 503, provider/invalid-output failure 502, completed 200. Keep existing deterministic research labeled separately. Native UI must show generated interpretations, exact passages/source links, cutoff/date kind, and unknown tracks; no silent substitution or inference that this satisfies the paper-engine risk assessment.

PRISM v1's current `evaluate_response` expects the old five-string Plutus schema; **it is not compatible with this source-quoted response**. Coordinator must route a focused evaluator contract update to PRISM before tracing/evaluation wiring. Do not flatten these responses into a fabricated legacy answer. No evaluator rerun is authorized.

Current Apollo WINA reviewed corpus and historical assigned PRISM WINA corpus differ. This adapter deliberately does not merge them. Sponsor retrieval, Root Cause and evaluator receipts are historical; pre-event eligibility and the independent human explanation remain unverified. Required actual Apollo research → valid PRISM source retrieval → Nicrron generation → UI/trace proof remains OPEN.

After the integrated path is concrete, the exact owner decision needed is a bounded grant specifying **one actual Apollo Nicrron request**, public asset/thesis/context and corpus, pinned model, at most 3000 output tokens/45 seconds, approved server-side credential route, and how the existing pause is to be overridden for that one request without modifying Plutus. PRISM retrieval/trace/evaluator operations need their own explicit allowance if required. No retries, top-ups or new provider runs are included. This is a documented future dependency, not a spend request or permission granted by code.

## Verification and review ledger

Focused offline tests cover pause file precedence, missing/invalid config, zero/exhausted/concurrent allowance, source/date/full-identity mismatch, exact quotes and tracks, truncation/size limits, provider HTTP/timeout errors, unknown evidence, offline provenance and PRISM data mapping. All sockets are forbidden in the adapter tests. Test command: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest backend.providers.nicrron.test_adapter -v`.

Only this producer scope was inspected; no repository-wide audit/review was opened. Integration retains the one final integrated gate and adversarial review. Offline PASS is not live/model/phone/sponsor/owner acceptance. Rollback: omit this package/wiring; no existing runtime or stored portfolio is modified.

Primary API reference checked October 17: [Nicrron quickstart](https://nicrron.ai/docs/quickstart), [authentication](https://www.nicrron.ai/docs/authentication), [cache behavior](https://nicrron.ai/docs/models). Existing client pattern inspected read-only: Plutus `api/receipts.py` and historical `research/receipts/provider-contract.json`. No credential files were read.


## Current checkpoint — 2026-10-17 16:40:32 UTC / 12:40:32 EDT

Owner: Nicrron chat `01a14a82-3e08-7dc3-a673-0e119f891329`; owned paths unchanged. Shared/native source and canonical ledger remain Integration-owned; cooperative ownership is documented, formal managed claim NOT ESTABLISHED.

This checkpoint supersedes the earlier pending PRISM-v1 compatibility paragraph: PRISM-v2 now accepts the full source-quoted Nicrron result. Frozen Nicrron-v1 manifest SHA-256 `1208ba398028c2b37928d246db2f6f329e36a42b874461c1325cbaa75a15a6ce`; PRISM-v2 manifest `a28ca53fc8486d2bde0b24569310e5a27991e1acb957adb77d3654df0d86166e`. Actual source imports were independently matched 5/5 Nicrron and 10/10 PRISM files before this checkpoint. Nicrron 16 offline tests PASS; PRISM 22 offline tests reported PASS; released cross-adapter no-network flow PASS. Full gate/final review remain Integration-owned and unconsumed by this lane.

PASS, bounded: actual gateway paused HTTP and injected offline response/evaluation/trace preparation; typed native five-envelope mapping; actual Swift delayed 13-second paused HTTP response with one request and no provider traffic (Integration receipt). Challenge-only transport timeout is now 90 seconds. Gateway credential aliases and one-request procedure are prepared with synthetic values only; no real credentials, balance or authentication tested. Existing pause-file SHA-256 last independently checked `97212387a8b64d7fbb64b379fcadb4933528c195a299ff5b767dc64b6764b3d8`; no pause mutation or real provider call by this lane.

BLOCKED native interaction proof: approved simulator loan returned explicitly to Integration/coordinator at 12:37 EDT, before its 12:42 cutoff. Initial blue Compare paper portfolios pixels were readable; Device Hub selected simulator UDID `9EEB618A-AE9D-400E-8124-2BE420C6F7D8`, observed iOS 26.5. Coordinate interaction failed with `noWindowsAvailable`; two Done attempts and one window Raise produced no navigation or submit. No source/config/build/server/physical-device/order/profile changes. No final visual capture exported. Do not treat this as challenge UI acceptance or reuse the returned loan.

Remaining REQUIRED for bounded one-call readiness: Integration must exercise the actual native WINA Challenge action against the refreshed paused gateway, confirm visible pause/process/context/evidence/back behavior and retained draft, and verify structured success/error rendering offline. Do not infer these from transport/unit checks. Authentication and credit availability remain intentionally NOT_RUN until a separate explicit one-call grant; source-boundary/semantic/sponsor acceptance remain separate. Full game, device matrix, current blue demo, combined gate/final review and owner acceptance remain outside this lane's completed proof.

Next observable action: Integration resumes its owned supported simulator input path and supplies the focused native receipt, coordinated with its onboarding operation. Request a compact checkpoint within 15 minutes of this receipt; no duplicate device run or broad review. Quiet existing heartbeat `apollo-nicrron-call-readiness` remains active and notifies on meaningful readiness/blocker changes. Work-ready cutoff stays October 17 16:00 EDT, recording/rehearsal 16:00–16:30; unresolved native proof is a delivery risk, no deadline moved. Human's local-model/OAuth question was answered from current primary documentation only and grants no new implementation, credential access, model download or paid execution.
