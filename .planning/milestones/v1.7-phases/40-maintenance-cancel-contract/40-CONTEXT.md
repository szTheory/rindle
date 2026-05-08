# Phase 40: Maintenance + Cancel Contract - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Make resumable-session cleanup idempotent and operator-safe through Rindle's
existing two-step maintenance lane:

- `Rindle.Ops.UploadMaintenance.abort_incomplete_uploads/1`
- `Rindle.Ops.UploadMaintenance.cleanup_orphans/1`
- `mix rindle.runtime_status`

This phase adds resumable-aware cancel semantics, deletion guards, operator
visibility, and proof coverage. It does not broaden the public upload API, add
new upload capabilities, or expand Phase 41's docs/doctor/package-consumer
scope.

</domain>

<decisions>
## Implementation Decisions

### Failure posture after remote cancel fails
- **D-01:** Keep the public contract narrow. Do not add a new public
  cancel-failure state, new public return tuple family, or a new durable FSM
  state such as `"cancel_failed"`.
- **D-02:** When resumable remote cancel fails for a non-idempotent reason, the
  row stays in terminal `"aborted"` with a bounded, operator-facing
  `failure_reason` taxonomy rather than raw `inspect(reason)` output.
- **D-03:** The `failure_reason` vocabulary should stay low-cardinality and
  action-oriented, e.g.
  `resumable_cancel_failed:goth_unconfigured`,
  `resumable_cancel_failed:gcs_http_4xx`,
  `resumable_cancel_failed:gcs_http_5xx`,
  `resumable_cancel_failed:transport`.
- **D-04:** `{:error, :session_uri_unknown}` and
  `{:error, :session_uri_expired}` remain idempotent success for maintenance
  cleanup and must not be recorded as failures.

### Ownership split between abort and cleanup
- **D-05:** `abort_incomplete_uploads/1` is the only maintenance step allowed to
  perform resumable remote cancel. `cleanup_orphans/1` must not issue provider
  cancel requests on its own.
- **D-06:** Resumable rows become cleanup-eligible only after local proof that
  remote cancel already succeeded or was idempotently resolved. The preferred
  proof marker is clearing `session_uri` after successful/idempotent cancel.
- **D-07:** `cleanup_orphans/1` may delete resumable rows only when they are in
  `"expired"` and satisfy the local proof marker above. If a resumable row is
  `"expired"` but still retains its cancel-required marker, cleanup skips it and
  reports the drift instead of deleting silently.
- **D-08:** Remote cancel stays outside DB transactions and inside the abort
  lane's retryable maintenance flow, preserving the existing Rindle pattern that
  network side effects are not hidden inside persistence work.

### runtime_status shape
- **D-09:** Keep `upload_sessions` as the primary runtime-status section. Do not
  add a new top-level `resumable_sessions` report.
- **D-10:** Add a bounded nested resumable summary under `upload_sessions`
  carrying exactly the Phase 40 counters:
  `resumable_sessions_pending`,
  `resumable_sessions_expired`,
  `resumable_session_uris_stale`.
- **D-11:** Reuse the existing top-level `recommendations` surface for repair
  guidance. Do not invent resumable-only repair verbs when the correct operator
  action is still the maintenance lane (`abort_incomplete_uploads` then
  `cleanup_orphans`).
- **D-12:** `runtime_status` must never expose `session_uri`, partial URIs,
  offset details, provider headers, or other protocol-debugging internals.

### Live proof depth
- **D-13:** The secret-gated real-GCS lane should prove exactly two end-to-end
  maintenance scenarios with intermediate assertions:
  initiate -> cancel/idempotent cancel -> runtime_status visible -> cleanup,
  and initiate -> expire -> runtime_status visible -> cleanup.
- **D-14:** The live lane should assert stable public/operator surfaces:
  maintenance reports, persisted row transitions, and `runtime_status` output.
  Do not make worker telemetry the main live proof target.
- **D-15:** Richer branch/error permutations stay in local ExUnit coverage using
  existing Bypass-style seams. The live lane should stay thin enough to preserve
  trust without becoming a flaky conformance matrix.

### Recommendation posture for downstream agents
- **D-16:** For this phase, downstream researcher/planner/executor work should
  synthesize one coherent recommendation set, decide by default, and escalate
  only for high-blast-radius choices such as semver-significant public reshapes,
  security boundary changes, destructive irreversibility, or major CI/runtime
  cost surprises.

### the agent's Discretion
- Exact low-cardinality `failure_reason` strings, as long as they stay bounded,
  operator-meaningful, and non-public.
- Exact local proof mechanism for cleanup eligibility, as long as it is durable,
  privacy-safe, and prevents silent deletion of remotely-uncancelled resumable
  rows.
- Exact placement of resumable counters in text/JSON formatter output, as long
  as `upload_sessions` remains the primary section and no duplicate top-level
  resumable report is introduced.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone scope
- `.planning/ROADMAP.md` — Phase 40 goal, success criteria, and plan-count
  guidance.
- `.planning/REQUIREMENTS.md` — `RESUMABLE-09..11` acceptance criteria.
- `.planning/PROJECT.md` — milestone posture, secret-handling boundary, and
  current v1.7 goals.
- `.planning/STATE.md` — current execution state and project-level
  decision-making preference.

### Locked prior context
- `.planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md` — secret
  handling, `"resuming"` semantics, and telemetry/redaction posture.
- `.planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md`
  — resumable callback/broker contract, idempotent error vocabulary, and
  cross-adapter honesty rules.

### Locked research
- `.planning/research/v1.6-CANDIDATE-GCS.md` — original resumable maintenance
  recommendation, operator-visibility rationale, and peer-library lessons.

### Existing code seams
- `lib/rindle/ops/upload_maintenance.ex` — current two-step maintenance flow,
  cleanup invariants, and retry boundaries.
- `lib/rindle/ops/runtime_status.ex` — report shape, bounded findings model, and
  recommendation surface.
- `lib/rindle/upload/broker.ex` — resumable cancel lifecycle and compensation
  precedent.
- `lib/rindle/workers/abort_incomplete_uploads.ex` — worker-level telemetry
  boundary for abort runs.
- `lib/rindle/workers/cleanup_orphans.ex` — worker-level telemetry boundary for
  cleanup runs.
- `test/rindle/ops/upload_maintenance_test.exs` — current maintenance behavior
  and service-layer telemetry boundary.
- `test/rindle/ops/runtime_status_test.exs` — bounded runtime-status contract
  style.
- `test/rindle/storage/gcs/client_test.exs` — `:session_uri_unknown` /
  `:session_uri_expired` mappings and cancel semantics.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Ops.UploadMaintenance`: already owns the two-step maintenance lane and
  should remain the only orchestration point for resumable cleanup semantics.
- `Rindle.Ops.RuntimeStatus`: already uses bounded counts, grouped findings, and
  top-level recommendations instead of protocol-dump output.
- `Rindle.Upload.Broker`: already contains resumable cancel and compensation
  patterns that Phase 40 should mirror rather than reinvent.

### Established Patterns
- Service layers do not emit `[:rindle, :cleanup, :run]` telemetry directly;
  workers emit cleanup-run telemetry after service completion.
- Network side effects are kept outside DB transactions.
- Public/operator surfaces prefer additive, bounded maps and low-cardinality
  tagged reasons over raw backend transcripts.

### Integration Points
- `abort_incomplete_uploads/1` must grow resumable-aware cancel + proof
  bookkeeping.
- `cleanup_orphans/1` must enforce resumable deletion eligibility without
  becoming a second remote-cancel worker.
- `runtime_status/1` must surface resumable counters without creating a second
  operator domain.

</code_context>

<specifics>
## Specific Ideas

- Treat resumable cleanup like a sibling of multipart cleanup, not a separate
  subsystem with its own operator console.
- Prefer explicit local proof of remote cancel completion over trusting
  `"expired"` alone for resumable deletion.
- Keep the live proof thin but stepwise: assert visibility before cleanup, not
  just eventual success after cleanup.
- Push the “research hard, recommend once, escalate rarely” preference left into
  planning for this phase rather than reopening each low-blast-radius tradeoff.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 40-maintenance-cancel-contract*
*Context gathered: 2026-05-07*
