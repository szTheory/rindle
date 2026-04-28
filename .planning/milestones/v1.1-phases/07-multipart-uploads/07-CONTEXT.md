# Phase 7: Multipart Uploads - Context

**Gathered:** 2026-04-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a first-class multipart direct-upload path for larger uploads on supported S3-compatible adapters, while preserving the existing verification, cleanup, capability-honesty, and adopter-owned runtime guarantees established in earlier phases.

</domain>

<decisions>
## Implementation Decisions

### Runtime and flow ownership
- **D-01:** Multipart support extends the existing direct-upload broker/runtime boundary instead of introducing a separate upload subsystem. The broker remains the orchestration point for session creation, storage handoff, completion, and verification.
- **D-02:** Multipart persistence and follow-up job behavior must stay on the Phase 6 adopter-owned runtime Repo seam via `Rindle.Config.repo/0`; Phase 7 must not reintroduce `Rindle.Repo` assumptions anywhere in broker, maintenance, or worker paths.

### Capability and adapter contract
- **D-03:** Multipart is capability-gated. Adapters must explicitly advertise multipart support before any multipart flow is offered, and unsupported adapters return a tagged capability error instead of falling through to storage-specific runtime failures.
- **D-04:** The capability model stays additive to the current `capabilities/0` contract so existing presigned PUT support remains intact and future provider-specific upload modes can compose onto the same honesty boundary.

### Verification and promotion path
- **D-05:** Multipart completion must converge back into the same trusted verification and promotion lane as the current presigned PUT flow. Completing remote parts is not itself a trust boundary; promotion still happens only after server-side completion verification.
- **D-06:** Multipart support is additive, not a replacement. Existing `presigned_put`-based direct uploads remain supported and planner work should avoid refactoring them into a different contract unless required by shared abstractions.

### Session lifecycle and maintenance
- **D-07:** Multipart state should build on the existing upload-session lifecycle rather than bypass it. Any new multipart metadata or part-tracking records must still leave `media_upload_sessions` as the authoritative session-level state machine visible to maintenance flows.
- **D-08:** Abandoned multipart uploads extend the existing two-step maintenance lane: timed-out sessions are first marked terminal by maintenance logic, then storage cleanup/abort work removes remote multipart residue without hiding storage I/O inside database transactions.

### Testing and provider proof
- **D-09:** Multipart support needs both unit/contract coverage and a real S3-compatible integration proof, following the existing MinIO-backed adopter/integration testing patterns already used for direct upload and storage behavior.

### the agent's Discretion
- Exact internal schema split for multipart-specific metadata or part manifests, as long as public lifecycle ownership stays with the existing broker/session boundary.
- Exact public function names and payload field names for multipart initiation/part-signing/completion, as long as the contract stays tagged-tuple based and capability-honest.
- Exact TTL defaults, part-size defaults, and maintenance batching strategy, as long as they remain production-safe and do not weaken verification or cleanup guarantees.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and locked requirements
- `.planning/ROADMAP.md` — Phase 7 goal, dependency on Phase 6, and multipart-specific success criteria.
- `.planning/REQUIREMENTS.md` — MULT-01 through MULT-04 lock the multipart initiation, completion, abort, and unsupported-capability requirements.
- `.planning/PROJECT.md` — milestone priorities, capability-honesty constraint, security invariants, and the explicit v1.1 decision that multipart is additive to presigned PUT.
- `.planning/STATE.md` — current project preference to let the agent decide by default unless a high-impact ambiguity appears.

### Prior decisions that constrain Phase 7
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-03 and D-04 lock explicit storage capability exposure and the rule that storage side effects stay outside DB transactions.
- `.planning/phases/03-delivery-observability/03-CONTEXT.md` — D-03 shows the established pattern that adapters provide capabilities while policy/contract enforcement lives above them.
- `.planning/phases/05-ci-1-0-readiness/05-CONTEXT.md` — D-07 through D-09 and the code-context sections establish the MinIO-backed adopter/integration proof style Phase 7 should reuse.
- `.planning/phases/06-adopter-runtime-ownership/06-adopter-runtime-ownership-02-SUMMARY.md` — runtime repo resolution already covers broker and worker paths and explicitly affects `multipart-uploads`.

### Existing code surface
- `lib/rindle/upload/broker.ex` — current direct-upload orchestration, repo resolution, and verification/promotion boundary.
- `lib/rindle/storage.ex` — storage behaviour contract and capability surface Phase 7 will extend.
- `lib/rindle/storage/s3.ex` — current S3-compatible adapter with `presigned_put`, `head`, and capability advertising.
- `lib/rindle/storage/local.ex` — current local adapter behavior, useful as the baseline unsupported multipart case unless planner decides otherwise.
- `lib/rindle/ops/upload_maintenance.ex` — existing abort/cleanup maintenance lane that Phase 7 must extend for abandoned multipart work.
- `lib/rindle/workers/abort_incomplete_uploads.ex` — scheduled maintenance worker contract for timing out incomplete sessions.
- `lib/rindle/domain/media_upload_session.ex` and `lib/rindle/domain/upload_session_fsm.ex` — existing session schema/state machine that multipart must preserve or extend coherently.
- `test/rindle/upload/broker_test.exs` — broker contract and repo-seam proof pattern.
- `test/rindle/upload/lifecycle_integration_test.exs` — direct-upload lifecycle integration pattern.
- `test/adopter/canonical_app/lifecycle_test.exs` — canonical adopter proof for real direct-upload behavior through MinIO.
- `test/rindle/storage/storage_adapter_test.exs` and `test/rindle/storage/s3_test.exs` — current adapter capability and MinIO-backed storage proof baseline.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Upload.Broker` already owns direct-upload session creation, signing, verification, telemetry emission, and promotion enqueueing.
- `Rindle.Storage` plus `Rindle.Storage.S3` already expose the adapter seam and the capability-list pattern Phase 7 can extend.
- `Rindle.Ops.UploadMaintenance` and `Rindle.Workers.AbortIncompleteUploads` already form the operator-facing maintenance lane for incomplete uploads.
- `Rindle.Domain.MediaUploadSession` and `Rindle.Domain.UploadSessionFSM` already provide a queryable upload-session lifecycle with timeout and terminal states.
- The MinIO-backed adopter/integration tests already exercise real direct-upload behavior and can be expanded to multipart instead of inventing a new proof harness.

### Established Patterns
- Public/storage-facing contracts use tagged tuples and explicit capability checks instead of hidden raises or provider-specific leakage.
- Storage adapters are primitives that advertise capabilities; higher-level modules enforce product/runtime policy above them.
- Storage side effects stay outside DB transactions, while persistence and job enqueueing stay on the resolved runtime repo seam.
- New operational behavior is surfaced through maintenance services plus Oban workers, not ad hoc scripts or hidden background loops.

### Integration Points
- Multipart broker entrypoints should connect to `lib/rindle/upload/broker.ex` and the public facade in `lib/rindle.ex`, not bypass them.
- Adapter-specific multipart behavior should land in `lib/rindle/storage/s3.ex` first, with capability reporting wired through `lib/rindle/storage.ex`.
- Abandoned multipart cleanup should hook into `lib/rindle/ops/upload_maintenance.ex` and `lib/rindle/workers/abort_incomplete_uploads.ex` so operators keep one maintenance story.
- Real proof should extend the existing MinIO-backed tests in `test/adopter/canonical_app/lifecycle_test.exs`, `test/rindle/upload/lifecycle_integration_test.exs`, and storage adapter tests.

</code_context>

<specifics>
## Specific Ideas

No specific user-supplied requirements surfaced during assumptions mode — standard multipart patterns are acceptable as long as they preserve Rindle's existing verification, cleanup, capability, and runtime-ownership guarantees.

</specifics>

<deferred>
## Deferred Ideas

- Broad non-S3 multipart parity remains out of scope for v1.1 per `.planning/REQUIREMENTS.md`; Phase 7 should focus on the S3-compatible path and explicit unsupported behavior elsewhere.
- Future GCS resumable/tus-style flows remain deferred; Phase 7 should keep capability contracts extensible without taking on those protocols now.

</deferred>

---

*Phase: 07-multipart-uploads*
*Context gathered: 2026-04-28*
