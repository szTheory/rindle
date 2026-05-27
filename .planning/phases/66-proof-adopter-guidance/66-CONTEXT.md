# Phase 66: Proof & adopter guidance - Context

**Gathered:** 2026-05-27 (assumptions mode — research-validated)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close v1.13 with proof that cancel works as specified (PROOF-01) and
adopter-facing documentation that matches runtime behavior (TRUTH-01).

Phase 66 is **tests + guide + docs parity only**. Implementation shipped in
Phases 64–65 (`cancel_direct_upload/1`, Mux adapter, happy-path hermetic test).

Out of scope for this phase:

- New public API or behaviour changes
- LiveView auto-cancel helper
- Local `MediaAsset` purge on cancel
- PubSub broadcast on user cancel
- Oban retry worker for failed Mux cancel
- Second streaming provider cancel
- tus/resumable cancel changes
- install-smoke / package-consumer cancel lane (PROOF-01 is default `mix test`)
- Extending `direct_upload_flow_test.exs` with cancel (webhook flow stays separate)

</domain>

<decisions>
## Implementation Decisions

### PROOF-01 test placement
- **D-01:** PROOF-01 closes in the default `mix test` suite — not install-smoke,
  not a new `:mux` generated-app lane.
- **D-02:** Extend `cancel_direct_upload_test.exs` and `mux_cancel_upload_test.exs`;
  add `test/rindle/streaming/provider/mux/http_cancel_upload_test.exs` for HTTP
  403/404 only. Leave `direct_upload_flow_test.exs` unchanged (create → webhook
  story only).

### Create → cancel integration
- **D-03:** One integration test in `cancel_direct_upload_test.exs`: real
  `create_direct_upload/2` → `cancel_direct_upload/1` → provider row `deleted`,
  `ClientMock.cancel_upload/1` called with persisted `provider_upload_id`.
  Proves CANCEL-01 + CANCEL-03 correlation (not just hand-inserted rows).

### HTTP 403/404 idempotency proof
- **D-04:** Prove Mux cancel idempotency at the **HTTP layer** with two Bypass
  tests on `Mux.HTTP.cancel_upload/1` (403 and 404 → `:ok`). Add `base_url`
  passthrough in `build_client/0` (`Keyword.get(cfg, :base_url)` →
  `Mux.Base.new/3`) — same seam pattern as GCS Bypass tests.
- **D-05:** Adapter and Streaming orchestration tests use `ClientMock` returning
  post-normalization `:ok` only. Do **not** mock `{:error, _, %{status: 403}}`
  at the adapter — D-14 maps 4xx → `:provider_sync_failed`; that would not
  prove `http.ex` and would fight locked adapter design.

### Streaming edge-case matrix (`cancel_direct_upload_test.exs`)
- **D-06:** Idempotent re-cancel: row already `deleted` → `:ok` on **two**
  calls; `cancel_upload` invoked twice (D-07 best-effort provider on re-cancel).
- **D-07:** Table-driven `:not_cancellable` for `processing` and `ready`:
  tagged `{:not_cancellable, %{reason: :state, state: state}}`; row unchanged;
  explicitly reject/forbid `ClientMock.cancel_upload/1`.
- **D-08:** `:missing_upload_id`: `provider_upload_id: nil` →
  `{:not_cancellable, %{reason: :missing_upload_id}}` before conditional
  `update_all`; no provider call.
- **D-09:** Provider failure after local delete: mock `:provider_sync_failed`
  (or `:provider_quota_exceeded`) → row stays `deleted` (D-15 no rollback).
- **D-10:** Optional low-cost additions: `pending` cancel (mirror happy path);
  `:provider_quota_exceeded` without rollback (symmetric to D-09).
- **D-11:** Skip `ingest_mode` `:not_cancellable` integration test — public API
  filters `direct_creator_upload` at fetch; wrong mode yields `:not_found`, not
  tagged ingest_mode (classify branch is TOCTOU-only).

### Adapter tests (`mux_cancel_upload_test.exs`)
- **D-12:** Keep existing happy path, already-cancelled (`:ok` at client layer),
  429, 5xx tests. Do not duplicate Streaming orchestration here.

### TRUTH-01 guide (`guides/streaming_providers.md`)
- **D-13:** New subsection **"Cancel an abandoned direct upload"** under §4.1
  Browser Direct Upload, immediately after the fresh-URL / do-not-reuse note
  (~lines 166–167). Not a new top-level section (preserves 11-section arc).
- **D-14:** Guide content must include:
  - Two-layer cancel: client `upload.abort()` (UpChunk) + server
    `Rindle.Streaming.cancel_direct_upload/1`
  - Cancel vs fresh `create_direct_upload/2` decision table
  - Cancellable states (`pending`, `uploading`); idempotent `:ok`
  - Return shape summary (`:not_found`, `:provider_*`, `{:not_cancellable, ...}`)
  - `:provider_sync_failed` means locally cancelled — hide uploader, retry safe
  - Explicit **Mux-only in v1.13** scope note
  - Out-of-scope pointers: no `MediaAsset` purge, no LiveView auto-hook, not
    tus/resumable/`cancel_processing/1`
- **D-15:** §10 Operator Runbook: add short **"Provider upload cancel vs Oban
  job cancel"** block linking to §4.1 — disambiguate existing `Oban.cancel_jobs`
  wording from `cancel_direct_upload/1`.
- **D-16:** Intro bullet list (lines 14–27): add cancel line for TOC/discovery.

### Docs parity (CI contract)
- **D-17:** Add `test/install_smoke/streaming_cancel_docs_parity_test.exs` (mirror
  `phoenix_tus_truth_parity_test.exs`) asserting `guides/streaming_providers.md`
  contains: `cancel_direct_upload/1`, `create_direct_upload/2`, fresh-URL contrast,
  Mux-only/v1.13 scope, `upload.abort()` or UpChunk, `pending`/`uploading`, and
  §10 mentions both streaming cancel API and `Oban.cancel_jobs`.

### Claude's Discretion
- Exact test names and `describe` block grouping
- Whether quota failure test ships alongside sync failure (D-10)
- Exact guide prose and code snippets (must satisfy D-14 checklist)
- Bypass test file name (`http_cancel_upload_test.exs` vs nested under `mux/`)

### Folded Todos
None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone scope
- `.planning/ROADMAP.md` — Phase 66 goal, success criteria, PROOF-01/TRUTH-01
- `.planning/REQUIREMENTS.md` — PROOF-01, TRUTH-01 acceptance criteria
- `.planning/PROJECT.md` — security invariant 14, layered CI proof posture
- `.planning/STATE.md` — v1.13 milestone context
- `.planning/phases/64-cancel-contract-persistence/64-CONTEXT.md` — locked public
  API, error vocabulary, FSM spec (D-01..D-30)
- `.planning/phases/65-mux-cancel-implementation/65-CONTEXT.md` — implementation
  decisions; D-20 deferred PROOF-01 matrix to Phase 66

### Research and prompts
- `.planning/research/v1.8/MUX-DIRECT-UPLOAD-RESEARCH.md` — Mux upload lifecycle,
  UpChunk pairing, passthrough vs upload_id, docs shape
- `.planning/phases/65-mux-cancel-implementation/65-RESEARCH.md` — deferred test
  matrix, validation architecture, 403 idempotency
- `prompts/gsd-rindle-elixir-oss-dna.md` — layered CI proof, footguns in tests,
  behaviour seams, no HTTP in transactions
- `prompts/phoenix-media-uploads-lib-deep-research.md` — lifecycle verbs (cancel),
  client abort vs server cancel lessons

### Existing code and test seams
- `lib/rindle/streaming.ex` — `cancel_direct_upload/1`, `@cancellable_states`,
  `classify_zero_row_update/2`, `invoke_provider_cancel/4`
- `lib/rindle/streaming/provider/mux/http.ex` — `cancel_upload/1` 403/404→`:ok`
- `lib/rindle/streaming/provider/mux.ex` — adapter normalization (D-14: no 403/404)
- `test/rindle/streaming/cancel_direct_upload_test.exs` — Phase 65 happy path
- `test/rindle/streaming/provider/mux_cancel_upload_test.exs` — adapter matrix
- `test/rindle/streaming/direct_upload_flow_test.exs` — create → webhook (unchanged)
- `test/rindle/streaming/create_direct_upload_test.exs` — create persistence pattern
- `test/rindle/error_streaming_freeze_test.exs` — frozen `:not_cancellable` messages
- `test/rindle/streaming/cancel_direct_upload_contract_test.exs` — export contract
- `test/install_smoke/phoenix_tus_truth_parity_test.exs` — docs parity pattern
- `test/rindle/storage/gcs_concatenate_test.exs` — Bypass + `base_url` precedent
- `guides/streaming_providers.md` — TRUTH-01 target; §4.1 and §10 edit sites

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 65 `DirectUploadProfile` + Mox setup blocks in `cancel_direct_upload_test.exs`,
  `mux_cancel_upload_test.exs`, `create_direct_upload_test.exs` — copy pattern,
  do not fork a fourth harness.
- `ClientMock` on `Rindle.Streaming.Provider.Mux.Client` — extend with
  `cancel_upload/1` expectations; use `stub` for double idempotent calls.
- `error_streaming_freeze_test.exs` — canonical message copy; integration tests
  assert return tuples only, not message strings.
- `phoenix_tus_truth_parity_test.exs` — template for `streaming_cancel_docs_parity_test.exs`.

### Established Patterns
- Create wedge: body phase ships happy path; proof phase completes matrix (Phase 45→65→66).
- Hermetic/unit in `mix test`; install-smoke for package-consumer paths (OSS DNA).
- HTTP idempotency at HTTP module; adapter maps 429/5xx only (delete_asset precedent).
- Tests-as-docs: `cancel_direct_upload_test.exs` is the adopter grep target for cancel.
- `direct_upload_flow_test.exs` = async webhook pipeline only — do not mix cancel.

### Integration Points
- `build_client/0` gains optional `:base_url` for Bypass HTTP tests only.
- Guide §4.1 gains cancel subsection; §10 gains disambiguation cross-link.
- Verification command for Phase 66 plans:

```bash
mix test test/rindle/streaming/cancel_direct_upload_contract_test.exs \
         test/rindle/streaming/cancel_direct_upload_test.exs \
         test/rindle/streaming/provider/mux_cancel_upload_test.exs \
         test/rindle/streaming/provider/mux/http_cancel_upload_test.exs \
         test/install_smoke/streaming_cancel_docs_parity_test.exs
```

</code_context>

<specifics>
## Specific Ideas

- **Two-layer cancel** is the adopter story: UpChunk `upload.abort()` stops bytes;
  `cancel_direct_upload/1` invalidates Mux upload + marks Rindle row `deleted`.
  Active Storage only documents client `xhr.abort()` — Rindle's server cancel is
  the differentiator.
- **Re-cancel must call provider** even when row is `deleted` — HTTP 403→`:ok`
  is load-bearing for CANCEL-02, not optional polish.
- **`delete_asset` 404 test gap** is known debt (mock returns `:ok` without
  exercising HTTP) — Phase 66 fixes cancel properly; do not copy that mistake.
- **§10 "cancel" verb** today means Oban — TRUTH-01 must disambiguate or adopters
  will cancel the wrong thing.
- Ecosystem: Mux cancel only while upload `waiting`; 403 when terminal — maps to
  Rindle FSM-first + HTTP idempotency.

</specifics>

<deferred>
## Deferred Ideas

- install-smoke generated-app exercise of cancel once — future milestone if
  package-consumer proof needed beyond hermetic suite
- Fix `delete_asset` HTTP 404 test the same way as cancel (low urgency debt)
- Webhook telemetry downgrade for `deleted + asset_created` — optional polish
- PubSub on user cancel — out of v1.13 scope
- Oban retry worker after `:provider_sync_failed` — follow-up if ops demand
- Second streaming provider cancel — MUX-25+ explicit demand

</deferred>

---

*Phase: 66-proof-adopter-guidance*
*Context gathered: 2026-05-27*
