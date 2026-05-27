# Phase 64: Cancel contract & persistence - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Freeze the public cancel boundary for Mux direct creator uploads before
implementation lands in Phase 65.

Phase 64 locks:

- Public `@spec` and error vocabulary for `Rindle.Streaming.cancel_direct_upload/1`
- Additive persistence spec for provider `upload_id` on `media_provider_assets`
- FSM allowlist edges for terminal cancel from pre-link states
- Security invariant 14 redaction rules for stored `upload_id`
- Cancel-vs-webhook race orchestration spec

Out of scope for this phase (Phase 65+):

- Mux HTTP wiring and adapter implementation
- `Streaming.cancel_direct_upload/1` implementation body
- Hermetic/integration tests and guide updates
- LiveView auto-cancel helper
- Local `MediaAsset` purge on cancel
- tus/resumable cancel changes
- Second streaming provider cancel
- Webhook handler changes for `video.upload.cancelled`

</domain>

<decisions>
## Implementation Decisions

### Public API shape
- **D-01:** Ship `Rindle.Streaming.cancel_direct_upload/1` keyed solely by Rindle
  `asset_id` (`Ecto.UUID.t()`), the same handle returned from
  `create_direct_upload/2`.
- **D-02:** Success returns bare `:ok` (not `{:ok, map}`). Matches
  `Rindle.cancel_processing/1` and CANCEL-02 idempotent re-cancel semantics.
- **D-03:** No profile argument on cancel — profile is derived from the durable
  provider row. Create needs profile because the asset does not exist yet;
  cancel does not.
- **D-04:** No bang variant in v1.13 — consistent with `create_direct_upload/2`
  and `cancel_processing/1`.
- **D-05:** Public API never accepts or returns provider `upload_id`,
  `provider_asset_id`, or `upload_url`.

### Error vocabulary
- **D-06:** Locked return type:

  ```elixir
  @type cancel_direct_upload_result ::
    :ok
    | {:error, :not_found}
    | {:error, :streaming_not_configured}
    | {:error, :provider_sync_failed}
    | {:error, :provider_quota_exceeded}
    | {:error, {:not_cancellable, not_cancellable_detail()}}

  @type not_cancellable_detail ::
    %{reason: :state, state: String.t()}
    | %{reason: :ingest_mode, ingest_mode: String.t()}
    | %{reason: :missing_upload_id}
  ```

- **D-07:** `:ok` when cancel succeeds, row is already `deleted`, or Mux upload
  is already terminal (`cancelled`, `timed_out`, 404). Do not treat Mux 404 as
  `:not_found`.
- **D-08:** `{:error, :not_found}` when `MediaAsset` or matching
  `media_provider_assets` row is missing.
- **D-09:** `{:error, {:not_cancellable, %{reason: :ingest_mode, ...}}}` when
  `ingest_mode != "direct_creator_upload"`.
- **D-10:** `{:error, {:not_cancellable, %{reason: :state, state: state}}}` when
  state is `processing`, `ready`, or `errored`.
- **D-11:** `{:error, {:not_cancellable, %{reason: :missing_upload_id}}}` for
  pre-v1.13 rows created before persistence shipped (no backfill).
- **D-12:** Reuse `:streaming_not_configured`, `:provider_sync_failed`, and
  `:provider_quota_exceeded` unchanged. Do not reuse `:provider_asset_not_ready`
  (delivery gate) or expose `{:invalid_transition, from, to}` on the public
  boundary.
- **D-13:** Add one new frozen atom `:not_cancellable` plus `Rindle.Error.message/1`
  clauses for tagged forms. Extend error freeze test accordingly.

### upload_id persistence
- **D-14:** Add nullable string column `provider_upload_id` on
  `media_provider_assets` via additive migration.
- **D-15:** Add partial unique index on `(provider_name, provider_upload_id)`
  where `provider_upload_id IS NOT NULL`, mirroring `provider_asset_id` and
  `mux_passthrough` index conventions.
- **D-16:** Persist `provider_upload_id` in the existing
  `create_direct_upload/2` `Multi.run(:direct_upload, ...)` success branch,
  same transaction as the `state: "uploading"` update. Do not persist
  `upload_url` (bearer secret).
- **D-17:** Do not reuse `mux_passthrough` for cancel — passthrough is the
  webhook correlation token; `provider_upload_id` is the Mux
  `Uploads.cancel/2` handle. These are orthogonal.
- **D-18:** Do not store `upload_id` in `raw_provider_metadata` — webhook
  handlers replace the map and clobber ad-hoc keys.
- **D-19:** No backfill for historical direct-upload rows. Cancel applies to
  uploads created after v1.13 persistence ships.

### FSM terminal edge
- **D-20:** Add FSM allowlist edges: `pending → deleted` and
  `uploading → deleted`. Reuse existing `"deleted"` terminal state — do not add
  a seventh `"cancelled"` state.
- **D-21:** Cancellable states are `pending` and `uploading` only. States
  `processing`, `ready`, and `errored` reject cancel at the public API
  (CANCEL-02).
- **D-22:** Cancel orchestration is FSM-first: conditional
  `UPDATE … SET state='deleted' WHERE state IN ('pending','uploading')` before
  best-effort provider cancel. Re-read row on 0-row update to distinguish
  idempotent `:ok` from `:not_cancellable`.
- **D-23:** No PubSub broadcast on cancel in v1.13 (explicit out of scope).
  Existing webhook linker rejection from `deleted` is the race guard — no Phase
  64 webhook handler change required.

### Provider behaviour callback
- **D-24:** Add optional callback on `Rindle.Streaming.Provider`:

  ```elixir
  @callback cancel_direct_upload(upload_id :: String.t()) :: :ok | {:error, term()}
  @optional_callbacks [create_direct_upload: 2, cancel_direct_upload: 1]
  ```

- **D-25:** Public `Streaming.cancel_direct_upload/1` resolves profile, loads
  row, validates state/ingest_mode, runs FSM transition, then calls adapter.
  Adapter receives provider `upload_id` only — mirrors `delete_asset/1` arity
  discipline.
- **D-26:** Capability gate reuses existing `:direct_creator_upload` via
  `Capabilities.supports?/2`. No new capability atom for v1.13.
- **D-27:** Mux adapter normalizes 429/4xx/5xx like `create_direct_upload/2`.
  Map provider-already-gone to `:ok` (same idempotency posture as
  `delete_asset/1` on 404).

### Security / redaction
- **D-28:** Add `provider_upload_id` to `MediaProviderAsset` `@writable` fields.
- **D-29:** Extend custom `Inspect` to redact `provider_upload_id` via
  `MediaProviderAsset.redact_id/1`.
- **D-30:** Telemetry emit sites that touch provider rows continue routing IDs
  through `redact_id/1`. Never log raw `provider_upload_id`.

### Claude's Discretion
- Exact `Rindle.Error.message/1` copy for `:not_cancellable` tagged forms, as
  long as messages are fix-oriented and never leak provider secrets.
- Whether Phase 66 downgrades webhook telemetry for `deleted + asset_created`
  from `:exception` to `:ignored` (polish only).
- Exact migration timestamp/name, as long as migration is additive and follows
  project conventions.

### Folded Todos
None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone scope
- `.planning/ROADMAP.md` — Phase 64 goal, success criteria, requirement mapping
- `.planning/REQUIREMENTS.md` — CANCEL-01, CANCEL-02, CANCEL-03 acceptance criteria
- `.planning/PROJECT.md` — security invariant 14, decide-by-default posture, v1.13 scope
- `.planning/STATE.md` — current milestone context and accumulated streaming notes
- `.planning/threads/2026-05-27-post-v112-milestone-assessment.md` — demand wedge rationale

### Research and prompts
- `.planning/research/v1.8/MUX-DIRECT-UPLOAD-RESEARCH.md` — Mux upload lifecycle,
  SDK `Uploads.cancel/2`, passthrough vs upload_id distinction, deferred cancel note
- `prompts/phoenix-media-uploads-lib-deep-research.md` — lifecycle verbs, provider
  upload handle pattern, schema guidance
- `prompts/gsd-rindle-elixir-oss-dna.md` — behaviour seams, tagged errors, redaction,
  Ecto.Multi discipline

### Locked prior streaming context
- `.planning/milestones/v1.6-phases/33-provider-boundary-state-schema/33-CONTEXT.md`
  — provider behaviour, FSM vocabulary, security invariant 14
- `.planning/milestones/v1.7-phases/40-maintenance-cancel-contract/40-CONTEXT.md`
  — resumable cancel precedent (separate domain; do not conflate with streaming cancel)

### Existing code seams
- `lib/rindle/streaming.ex` — `create_direct_upload/2` public contract and Multi shape
- `lib/rindle/streaming/provider.ex` — behaviour callbacks and provider types
- `lib/rindle/streaming/provider/mux.ex` — adapter error normalization patterns
- `lib/rindle/domain/media_provider_asset.ex` — schema, changeset, Inspect redaction
- `lib/rindle/domain/provider_asset_fsm.ex` — locked transition allowlist
- `lib/rindle/workers/ingest_provider_webhook.ex` — `video.upload.asset_created`
  linker and terminal-state rejection
- `lib/rindle/error.ex` — streaming error messages and freeze patterns
- `lib/rindle/upload/broker.ex` — resumable cancel precedent (`cancel_resumable_session/2`)
- `lib/rindle.ex` — `cancel_processing/1` bare `:ok` precedent
- `test/rindle/streaming/create_direct_upload_test.exs` — public return shape assertions
- `priv/repo/migrations/20260506120000_create_media_provider_assets.exs` — table baseline
- `priv/repo/migrations/20260524120000_add_mux_passthrough_to_media_provider_assets.exs`
  — prior additive column precedent

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Streaming.create_direct_upload/2`: Multi insert + adapter call pattern;
  extend success branch to persist `provider_upload_id`.
- `Rindle.Domain.MediaProviderAsset`: schema/changeset/Inspect redaction machinery
  ready for one more provider-secret column.
- `Rindle.Domain.ProviderAssetFSM`: pure validator — add two edges without changing
  call-site contract.
- `Rindle.Streaming.Provider.Mux`: error normalization and HTTP client wrapper
  patterns for Phase 65 adapter work.
- `MediaProviderAsset.redact_id/1`: shared redaction helper for telemetry and Inspect.

### Established Patterns
- Public facade uses Rindle-owned ids; provider handles stay internal (same as
  `multipart_upload_id` on upload sessions).
- Provider callbacks use minimal arity (`delete_asset/1`); profile-scoped config
  comes from application env, not callback args.
- Idempotent provider operations map already-gone to `:ok` (`delete_asset/1` 404).
- Network side effects stay outside DB transactions where possible; cancel uses
  conditional FSM update then best-effort provider call.
- One new error atom + tagged map discriminant beats atom sprawl (pairs with
  `:not_processing` family).

### Integration Points
- `create_direct_upload/2` must persist `provider_upload_id` at mint time (CANCEL-03).
- `ProviderAssetFSM` allowlist grows before Phase 65 implementation.
- `Rindle.Streaming.Provider` behaviour gains optional `cancel_direct_upload/1`.
- `Rindle.Error` and freeze tests gain `:not_cancellable` coverage.
- Webhook linker unchanged — `deleted` rows already reject
  `video.upload.asset_created` promotion.

</code_context>

<specifics>
## Specific Ideas

- Treat cancel like `cancel_processing/1` (user-initiated stop, bare `:ok`), not
  like `cancel_resumable_session/2` (maintenance bookkeeping with returned row).
- FSM-first conditional update is the race guard — do not rely on Mux cancel
  alone to win against a late `video.upload.asset_created`.
- Pre-v1.13 direct uploads without stored `upload_id` should fail closed with
  tagged `:missing_upload_id`, not attempt a Mux lookup by passthrough.
- Mux auto-`timed_out` remains a provider safety net; explicit cancel is adopter
  UX/control, not correctness (Active Storage / Shrine lesson).

</specifics>

<deferred>
## Deferred Ideas

- LiveView auto-cancel hook — adopters call `cancel_direct_upload/1` explicitly
  (REQUIREMENTS out-of-scope table)
- Local `MediaAsset` purge on cancel — provider upload abort only
- Stale direct-upload row reaper via `MuxSyncCoordinator` — separate follow-up
- Webhook telemetry polish for `deleted + asset_created` — Phase 66 optional
- Second streaming provider cancel — MUX-25+ when explicit demand
- Generic `cancel_provider_ingest/1` — deferred since Phase 33

</deferred>

---

*Phase: 64-cancel-contract-persistence*
*Context gathered: 2026-05-27*
