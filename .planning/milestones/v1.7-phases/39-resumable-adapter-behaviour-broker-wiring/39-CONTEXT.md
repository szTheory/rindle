# Phase 39: Resumable Adapter Behaviour + Broker Wiring - Context

**Gathered:** 2026-05-07 (assumptions mode + targeted advisor research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Land the public resumable adapter and broker surface on top of the Phase 37
GCS foundation and Phase 38 persistence/FSM groundwork:

- add the four resumable-oriented optional callbacks to `Rindle.Storage`
- implement the GCS resumable initiation/status/cancel surface
- ship broker entrypoints for initiate/status/cancel
- promote `:resumable_upload` and `:resumable_upload_session` from reserved
  to shipped capability atoms for GCS only
- preserve `verify_completion/2` as the single broker trust gate
- freeze the public resumable error vocabulary
- prove the end-to-end path against a real GCS bucket

This phase does **not** cover maintenance-worker idempotency policy,
cleanup/report counters, or runtime-status/doctor expansion beyond what
already shipped in Phases 37-38. Those stay in Phases 40-41.

</domain>

<decisions>
## Implementation Decisions

### Behaviour Contract And Capability Semantics

- **D-01:** `Rindle.Storage` adds the four optional resumable callbacks named
  in the roadmap and locked candidate:
  `initiate_resumable_upload/3`, `resumable_upload_status/3`,
  `cancel_resumable_upload/3`, and `verify_resumable_completion/3`.
- **D-02:** The callbacks stay genuinely optional at the behaviour layer.
  `Rindle.Storage.GCS` implements all four in Phase 39. `Rindle.Storage.S3`
  and `Rindle.Storage.Local` do **not** implement or advertise resumable
  support.
- **D-03:** `:resumable_upload` and `:resumable_upload_session` are shipped
  capability atoms, but their meaning must be documented in broker-first
  terms:
  - `:resumable_upload` means the adapter can mint a resumable upload and the
    broker can still converge through `verify_completion/2`
  - `:resumable_upload_session` means the adapter also supports broker-visible
    status/cancel operations
- **D-04:** `verify_resumable_completion/3` exists for adapter parity and
  lower-level escape-hatch use, but it is **not** the broker trust gate.
  Brokered completion remains `head/2`-based.

### Completion Convergence

- **D-05:** `Rindle.Upload.Broker.verify_completion/2` remains unchanged as
  the single completion path for presigned PUT, multipart, and resumable
  uploads.
- **D-06:** The durable storage-side truth for broker completion is object
  existence plus metadata via `head/2`, not session-URI state. This avoids
  dual completion semantics and keeps resumable uploads aligned with existing
  Rindle upload families.
- **D-07:** Planning/docs must explicitly call out the subtle but important
  distinction:
  `verify_resumable_completion/3` may exist on the adapter, but broker
  promotion still trusts `head/2` only.

### Broker Lifecycle Posture

- **D-08:** `initiate_resumable_session/2` mirrors the existing multipart
  posture:
  storage I/O happens before DB persistence, and persist failure triggers a
  compensating `cancel_resumable_upload/3`.
- **D-09:** The compensation flow should mirror the current
  `compensate_failed_multipart_persist/4` shape closely so maintainers see one
  obvious broker pattern rather than a second bespoke rescue design.
- **D-10:** `resumable_session_status/2` is observational by default. It may
  update durable resumable bookkeeping such as `last_known_offset`,
  `session_uri_expires_at`, and `region_hint`, but status polling alone must
  not move the lifecycle into `"resuming"` or any other more-progressed state.
- **D-11:** The `"resuming"` state remains narrow exactly as locked in Phase
  38: use it only for explicit recovery after interruption or uncertain
  completion, never for ordinary status checks.

### Public Error Vocabulary

- **D-12:** Locked public resumable failures for this phase are:
  `{:upload_unsupported, _}`, `:session_uri_expired`,
  `:session_uri_unknown`, `{:offset_mismatch, %{server: _, client: _}}`,
  `{:gcs_http_error, %{status: _, body: _}}`, `:goth_unconfigured`,
  `:missing_bucket`, and `:storage_object_missing`.
- **D-13:** `:region_pinned_initiation` is **not** a returned public error
  tuple. It is an advisory operator signal only.
- **D-14:** The current candidate doc’s treatment of
  `:region_pinned_initiation` as an error-like atom is superseded for Phase 39
  planning. If the atom survives at all, it belongs in telemetry metadata or
  internal warning classification, not in the broker success/error return
  contract.

### Region Pinning And Operator Visibility

- **D-15:** Region pinning is treated as successful initiation/status with
  visibility, not as an operation failure. The broker returns `{:ok, ...}`,
  persists `region_hint` when available, and emits telemetry that operators
  can alert on if cross-region initiation becomes a cost/performance issue.
- **D-16:** This follows the least-surprise rule for public APIs:
  returned errors mean the requested operation failed; non-fatal provider
  quirks belong in telemetry, docs, and persisted metadata.

### Cross-Adapter Honesty

- **D-17:** `Rindle.Storage.GCS.capabilities/0` becomes
  `[:signed_url, :head, :resumable_upload, :resumable_upload_session]` in
  Phase 39.
- **D-18:** `Rindle.Storage.S3.capabilities/0` and
  `Rindle.Storage.Local.capabilities/0` remain unchanged and explicitly do
  **not** advertise resumable atoms.
- **D-19:** Calling resumable broker entrypoints against a non-resumable
  adapter or non-resumable session row must return tagged
  `{:upload_unsupported, :resumable_upload}` or
  `{:upload_unsupported, :resumable_upload_session}` errors with no silent
  fallback to presigned PUT or multipart behaviour.

### Test And Proof Strategy

- **D-20:** Phase 39 should prove the full resumable path against a real GCS
  bucket, because the load-bearing risks are protocol mechanics, offset/status
  semantics, and callback/broker contract coherence rather than pure unit
  logic.
- **D-21:** Unit tests should still cover the broker/control-plane seams:
  capability gating, compensation on persist failure, non-resumable adapter
  rejection, error vocabulary mapping, and the explicit rule that broker
  completion remains `head/2`-based.
- **D-22:** Tests must defend against the main public-contract footgun:
  no second completion truth. If the adapter-level
  `verify_resumable_completion/3` is implemented, broker tests should still
  make clear that `verify_completion/2` does not depend on it.

### Decision-Making Preference (Carried Forward, Tightened)

- **D-23:** Downstream researchers, planners, and executors should front-load
  research, use subagents when helpful, compare the strongest relevant
  ecosystem examples, and synthesize one cohesive recommendation set rather
  than escalating routine tradeoffs back to the user.
- **D-24:** Prefer idiomatic Elixir/Phoenix/Ecto/Plug patterns for an
  adopter-owned library: behaviour honesty, additive contracts, tagged-tuple
  error semantics, storage side effects outside DB transactions, and small
  predictable public surfaces.
- **D-25:** Escalate only for genuinely high-blast-radius choices such as
  semver-significant public reshapes, destructive operations, security or
  compliance boundary changes, real-cost surprises, or milestone/scope
  changes.

### Claude's Discretion (Planner / Executor)

- Exact typespec wording for the new callbacks and broker result structs,
  so long as the locked arities and decision boundaries above remain intact.
- Exact helper placement between `Rindle.Storage.GCS`, its client module, and
  `Rindle.Upload.Broker`, so long as broker completion stays `head/2`-centric
  and session-URI handling remains secret-safe.
- Exact telemetry event shape for the region-pinning advisory path, so long as
  it is observable and does not pollute the public returned error surface.

</decisions>

<specifics>
## Specific Ideas

- The winning mental model is: resumable adds richer initiation and operational
  control, not a second broker completion model.
- GCS session URIs are operational secrets and should stay out of the hot path
  as soon as possible; that is another reason to converge broker completion on
  `head/2` instead of continued session-URI inspection.
- Region pinning is like a warning light, not a blown fuse: surface it loudly
  for operators, but do not make adopters branch on a pseudo-error for a
  successful initiation.
- The cleanest maintainer UX is to make multipart and resumable broker flows
  look like siblings: different initiation/control callbacks, same final trust
  gate.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone source of truth
- `.planning/ROADMAP.md` — Phase 39 goal, success criteria, and explicit
  “verify_completion/2 is unchanged” posture
- `.planning/REQUIREMENTS.md` — `RESUMABLE-04..08`
- `.planning/PROJECT.md` — milestone posture, constraints, and security
  invariant 14
- `.planning/STATE.md` — tightened decision-making preference

### Locked prior context
- `.planning/phases/37-gcs-adapter-foundation/37-CONTEXT.md` — GCS adapter
  file layout, optional-dep/runtime ownership, capability honesty, and doctor
  posture
- `.planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md` — resumable
  secret handling, `"resuming"` semantics, telemetry vocabulary, and schema
  groundwork

### Locked research
- `.planning/research/v1.6-CANDIDATE-GCS.md` — candidate API shape, protocol
  notes, and peer-library lessons; Phase 39 planning supersedes its
  `:region_pinned_initiation` error treatment where this context says so

### Existing code seams
- `lib/rindle/storage.ex` — behaviour contract and current `head/2` trust gate
- `lib/rindle/storage/capabilities.ex` — capability helpers and upload
  requirement gating
- `lib/rindle/upload/broker.ex` — multipart compensation pattern and existing
  `verify_completion/2` convergence path
- `lib/rindle/storage/gcs.ex` — current GCS adapter surface and unsupported
  callback posture from Phase 37
- `lib/rindle/storage/gcs/client.ex` — hand-rolled GCS JSON API plumbing that
  resumable callbacks should extend rather than bypass
- `lib/rindle/storage/s3.ex` — existing multipart family for broker-shape and
  capability-honesty comparison
- `lib/rindle/storage/local.ex` — explicit unsupported-operation error pattern
- `lib/rindle/domain/media_upload_session.ex` — resumable fields and
  `session_uri` redaction
- `lib/rindle/domain/upload_session_fsm.ex` — locked `"resuming"` state and
  transition rules
- `lib/rindle/error.ex` — public error vocabulary posture

### Existing tests to mirror or extend
- `test/rindle/upload/broker_test.exs` — broker lifecycle and multipart
  compensation patterns
- `test/rindle/storage/storage_adapter_test.exs` — behaviour callback and
  capability-contract assertions
- `test/rindle/storage/gcs_test.exs` — current GCS capability and unsupported
  callback assertions that Phase 39 must intentionally rewrite

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Upload.Broker.persist_multipart_session/4` and
  `compensate_failed_multipart_persist/4`: direct template for resumable
  persist-compensation flow
- `Rindle.Storage.Capabilities.require_upload/2`: existing capability gate
  that broker resumable entrypoints should reuse
- `Rindle.Storage.GCS.Client`: existing auth/base-url/request helpers that make
  resumable callback implementation an extension of current GCS plumbing, not a
  second transport stack
- `Rindle.Domain.MediaUploadSession.redact_session_uri/1`: centralized secret
  redaction helper already available

### Established Patterns
- Broker completion already converges through `head/2` regardless of upload
  family
- Unsupported adapter flows fail as tagged capability errors, not degraded
  fallbacks
- Storage-side effects happen outside DB transactions, with explicit
  compensation when persistence fails
- Public telemetry and error atoms are treated as stable contracts and should
  not be expanded casually

### Integration Points
- `lib/rindle/storage.ex` for behaviour/typespec additions
- `lib/rindle/storage/gcs.ex` and `lib/rindle/storage/gcs/client.ex` for GCS
  resumable support
- `lib/rindle/upload/broker.ex` for public resumable entrypoints and
  compensation
- `lib/rindle/error.ex` for any necessary public error-union update
- `test/rindle/upload/broker_test.exs`, `test/rindle/storage/gcs_test.exs`,
  and the real GCS proof lane for contract verification

</code_context>

<deferred>
## Deferred Ideas

- Maintenance-worker idempotent cancel semantics and cleanup counters belong in
  Phase 40
- Expanded runtime-status and doctor checks for resumable operations belong in
  Phase 41
- Any attempt to unify S3 multipart and GCS resumable into one generic
  “resumable” implementation model stays out of scope

</deferred>

---

*Phase: 39-resumable-adapter-behaviour-broker-wiring*
*Context gathered: 2026-05-07*
