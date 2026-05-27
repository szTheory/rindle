# Phase 65: Mux cancel implementation - Context

**Gathered:** 2026-05-27 (assumptions mode — research-validated)
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement cancel end-to-end for Mux direct creator uploads: ship
`Rindle.Streaming.cancel_direct_upload/1` orchestration and the Mux adapter
HTTP path via `Mux.Video.Uploads.cancel/2`.

Phase 65 ships the function body and adapter wiring only. Phase 64 locked the
public types, error vocabulary, FSM edges, and `provider_upload_id` persistence.
Phase 66 ships PROOF-01 (hermetic/integration test matrix) and TRUTH-01 (guide).

Out of scope for this phase:

- Full PROOF-01 test matrix (idempotent re-cancel, `:not_cancellable` edge cases,
  create→cancel integration) — Phase 66
- `guides/streaming_providers.md` cancel section — Phase 66
- LiveView auto-cancel helper
- Local `MediaAsset` purge on cancel
- PubSub broadcast on user cancel
- Oban retry worker for failed Mux cancel
- Second streaming provider cancel
- tus/resumable cancel changes

</domain>

<decisions>
## Implementation Decisions

### Orchestration (FSM-first hybrid)
- **D-01:** Implement `Rindle.Streaming.cancel_direct_upload/1` as a `with`
  pipeline keyed solely by Rindle `asset_id` (Phase 64 D-01..D-05 unchanged).
- **D-02:** Define `@cancellable_states ~w(pending uploading)` as a shared module
  constant consumed by both the conditional `update_all` WHERE clause and tests
  that assert parity with `ProviderAssetFSM` allowlist edges to `"deleted"`.
- **D-03:** Authoritative persistence gate is conditional
  `Repo.update_all(set: [state: "deleted"])` WHERE `id = row.id AND state IN
  @cancellable_states`. Do not use read-then-changeset without the WHERE guard
  (TOCTOU vs `video.upload.asset_created` webhook).
- **D-04:** On `{0, _}` from conditional update, re-read row and classify:
  `deleted` → proceed to best-effort provider cancel then `:ok`; other states →
  `{:error, {:not_cancellable, %{reason: :state, state: state}}}`.
- **D-05:** Optional advisory call to `ProviderAssetFSM.transition/3` on success
  path for telemetry only (using captured pre-update `from_state`). FSM module
  is not the persistence gate.
- **D-06:** Provider HTTP call runs **after** successful local FSM write and
  **outside** any `Repo.transaction` (security invariant 4 / OSS DNA).
- **D-07:** On idempotent re-cancel (row already `deleted`, 0-row update), still
  attempt best-effort provider cancel when `provider_upload_id` is present, then
  return `:ok` (Phase 64 D-07).

### Row lookup and profile resolution
- **D-08:** Single query:
  `Repo.get_by(MediaProviderAsset, asset_id: asset_id, ingest_mode:
  "direct_creator_upload")`. `nil` → `{:error, :not_found}`.
- **D-09:** Resolve profile via `String.to_existing_atom(row.profile)` — never
  `String.to_atom/1`. No separate `MediaAsset` load.
- **D-10:** Missing `provider_upload_id` →
  `{:error, {:not_cancellable, %{reason: :missing_upload_id}}}` (Phase 64 D-11,
  D-19). Do not lookup via `mux_passthrough`.

### Mux adapter + HTTP stack
- **D-11:** Extend internal `Rindle.Streaming.Provider.Mux.Client` behaviour with
  `@callback cancel_upload/1` (unguarded — Pitfall 4 Mox target).
- **D-12:** Implement `Mux.HTTP.cancel_upload/1` via `Mux.Video.Uploads.cancel/2`.
  Map **403 and 404 → `:ok`** at HTTP layer (Mux returns 403 when upload already
  `cancelled`, `timed_out`, or `asset_created`; 404 when unknown id).
- **D-13:** Implement `@impl cancel_direct_upload/1` on `Mux` adapter:
  429 → `:provider_quota_exceeded`; other 4xx/5xx → `:provider_sync_failed`;
  mirror `create_direct_upload/2` / `delete_asset/1` normalization discipline.
- **D-14:** Do not map 403/404 at adapter layer — HTTP layer owns idempotency
  (same split as `delete_asset/1`).

### Provider failure after local FSM transition
- **D-15:** If conditional update succeeds but provider cancel fails (non-idempotent
  error), return `{:error, :provider_sync_failed}` or
  `{:error, :provider_quota_exceeded}` **without rolling back** row to
  `uploading`. Row stays `deleted`.
- **D-16:** Adopter contract: `:provider_sync_failed` means locally cancelled —
  UI should hide/disable uploader; retry with same `asset_id` is safe and
  idempotent. Mux auto-`timed_out` is the correctness backstop.
- **D-17:** Do not add Oban retry worker in v1.13 — defer to follow-up reaper
  lane if ops demand warrants.

### Test scope (Phase 65)
- **D-18:** Phase 65 ships implementation plus contract test flip:
  `assert function_exported?(Rindle.Streaming, :cancel_direct_upload, 1)`.
- **D-19:** Add **one** happy-path hermetic test: `pending`/`uploading` row with
  `provider_upload_id` → `:ok` → row `deleted` → `ClientMock.cancel_upload`
  called (parity with `create_direct_upload_test.exs` shipping pattern).
- **D-20:** Full PROOF-01 matrix (idempotent re-cancel, `:not_cancellable`
  states, Mux 403/404 normalization, create→cancel integration) deferred to
  Phase 66.

### Claude's Discretion
- Exact private function names and module attribute placement for
  `@cancellable_states`, as long as FSM/SQL parity is test-locked.
- Whether to emit optional telemetry on partial provider failure after local
  `deleted` (no new public event contract required in v1.13).
- Exact handling of `Mux.Exception` vs `{:error, msg, env}` tuples in HTTP
  wrapper, as long as 403/404 idempotency holds.

### Folded Todos
None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone scope
- `.planning/ROADMAP.md` — Phase 65 goal, success criteria, CANCEL-04 mapping
- `.planning/REQUIREMENTS.md` — CANCEL-04 acceptance; PROOF-01 deferred Phase 66
- `.planning/PROJECT.md` — security invariant 14, decide-by-default posture,
  async-purge / no-HTTP-in-transaction discipline
- `.planning/STATE.md` — current milestone context
- `.planning/phases/64-cancel-contract-persistence/64-CONTEXT.md` — locked public
  API, error vocabulary, FSM spec, persistence (D-01..D-30)

### Research and prompts
- `.planning/research/v1.8/MUX-DIRECT-UPLOAD-RESEARCH.md` — Mux upload lifecycle,
  SDK `Uploads.cancel/2`, 403 idempotency, passthrough vs upload_id
- `.planning/phases/64-cancel-contract-persistence/64-RESEARCH.md` — Phase 65
  orchestration reference, Mux cancel idempotency notes
- `prompts/phoenix-media-uploads-lib-deep-research.md` — upload session vs asset,
  abort/cancel lifecycle verbs, Day-2 cleanup lessons
- `prompts/gsd-rindle-elixir-oss-dna.md` — behaviour seams, capability honesty,
  tagged errors, telemetry redaction, layered CI proof

### Existing code seams
- `lib/rindle/streaming.ex` — `create_direct_upload/2` Multi pattern; add
  `cancel_direct_upload/1` def
- `lib/rindle/streaming/provider.ex` — optional `cancel_direct_upload/1` callback
  (declared Phase 64)
- `lib/rindle/streaming/provider/mux.ex` — `create_direct_upload/2`,
  `delete_asset/1` normalization patterns
- `lib/rindle/streaming/provider/mux/client.ex` — add `cancel_upload/1` callback
- `lib/rindle/streaming/provider/mux/http.ex` — add `Uploads.cancel/2` wrapper
- `lib/rindle/domain/provider_asset_fsm.ex` — `pending`/`uploading` → `deleted`
  edges (Phase 64)
- `lib/rindle/domain/media_provider_asset.ex` — `provider_upload_id`, Inspect
  redaction
- `lib/rindle/workers/ingest_provider_webhook.ex` — `video.upload.asset_created`
  linker rejects `deleted` rows (race guard)
- `lib/rindle/upload/broker.ex` — `cancel_resumable_session/2` (contrast:
  storage-first; do not mirror for streaming cancel)
- `test/rindle/streaming/cancel_direct_upload_contract_test.exs` — flip export
  assertion in Phase 65
- `test/rindle/streaming/create_direct_upload_test.exs` — hermetic test pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Streaming.create_direct_upload/2`: `fetch_streaming_config/1`,
  `require_direct_upload_capability/1`, `Rindle.Config.repo/0` patterns.
- `Rindle.Streaming.Provider.Mux`: `http_client/0`, error normalization atoms,
  `delete_asset/1` 404→`:ok` idempotency template.
- `Rindle.Streaming.Provider.Mux.HTTP`: `build_client/0`, SDK wrapper shape for
  `create_upload/1` and `delete_asset/1`.
- `Rindle.Streaming.Provider.Mux.ClientMock`: Mox target; gains `cancel_upload/1`
  via behaviour extension automatically.
- `MediaProviderAsset.redact_id/1`: telemetry/logging for any new emit sites.

### Established Patterns
- Public facade uses Rindle-owned ids; provider handles stay internal.
- Provider callbacks minimal arity; profile from row, not callback arg.
- FSM-first for user-initiated cancel vs webhook race; resumable cancel inverts
  order (storage abort first) because threat model differs.
- Conditional `update_all` with state guard for atomic FSM writes under concurrency.
- Phase wedge: 64 contract → 65 body → 66 proof+docs (same as create_direct_upload
  shipping pattern with hermetic test in body phase).

### Integration Points
- `Streaming.cancel_direct_upload/1` → load row → validate → conditional FSM →
  `provider.cancel_direct_upload(upload_id)`.
- Mux Client/HTTP/adapter chain mirrors existing create/delete upload paths.
- Webhook linker unchanged — `deleted` rows already reject promotion.
- Contract test must flip from `refute function_exported?` to `assert`.

</code_context>

<specifics>
## Specific Ideas

- Treat cancel like `cancel_processing/1` (user-initiated stop, bare `:ok`), not
  like `cancel_resumable_session/2` (returns updated session row).
- Mux 403 on already-terminal uploads is idempotent success, not
  `:provider_sync_failed` — critical correction from SDK research.
- Adopter LiveView: on `:provider_sync_failed`, still hide uploader (locally
  cancelled); optional silent retry or ops log.
- Ecosystem lesson: Active Storage/Shrine/Spatie lack server-side direct-upload
  cancel — Rindle's value is durable row + Mux API + FSM race guard.
- Shared `@cancellable_states` constant prevents FSM/SQL drift footgun.

</specifics>

<deferred>
## Deferred Ideas

- Oban retry worker for failed Mux cancel after local `deleted` — follow-up if
  partial-failure volume warrants (`MuxSyncCoordinator` / maintenance lane)
- Cancel-specific `Rindle.Error.message/1` copy for `:provider_sync_failed` —
  Phase 66 TRUTH-01 polish
- Webhook telemetry downgrade for `deleted + asset_created` — Phase 66 optional
- Stale direct-upload row reaper — separate follow-up
- Full PROOF-01 hermetic matrix and create→cancel integration — Phase 66
- Guide cancel section — Phase 66 TRUTH-01

</deferred>

---

*Phase: 65-mux-cancel-implementation*
*Context gathered: 2026-05-27*
