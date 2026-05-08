# Phase 40: Maintenance + Cancel Contract - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-07
**Phase:** 40-maintenance-cancel-contract
**Areas discussed:** Failure posture after remote cancel fails, Ownership split between abort and cleanup, runtime_status shape for resumable sessions, Live-proof depth for the maintenance lane

---

## Failure posture after remote cancel fails

| Option | Description | Selected |
|--------|-------------|----------|
| Generic multipart mirror | Single generic `failure_reason` such as `remote_cancel_failed`; keeps symmetry but is operationally opaque | |
| Bounded resumable taxonomy | Low-cardinality operator-only `failure_reason` taxonomy while keeping public tuples unchanged | ✓ |
| Raw adapter/provider detail | Persist raw tuple or HTTP detail in `failure_reason` | |
| New public state/contract | Add a public cancel-failure state or structured public surface | |

**User's choice:** Lock the bounded resumable-specific taxonomy and keep it internal/operator-facing only.
**Notes:** Preserve narrow public API; idempotent `:session_uri_unknown` and `:session_uri_expired` stay success paths; no new durable FSM state.

---

## Ownership split between abort and cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Abort owns cancel; cleanup purely state-driven | Clean SRP, but unsafe if `"expired"` alone is trusted for resumable deletion | |
| Cleanup also cancels | Self-healing but duplicates remote-cancel semantics and surprises operators | |
| Hybrid with local proof marker | Abort owns remote cancel; cleanup deletes only after durable local proof of prior cancel success | ✓ |

**User's choice:** Lock the hybrid.
**Notes:** Preferred proof marker is clearing `session_uri` or equivalent only after successful/idempotent remote cancel; cleanup must never become a second remote-cancel worker.

---

## runtime_status shape for resumable sessions

| Option | Description | Selected |
|--------|-------------|----------|
| Fully folded into generic upload-session counts only | Smallest surface but weak discoverability | |
| Nested resumable summary under `upload_sessions` | Keep `upload_sessions` primary and add only the three locked resumable counters | ✓ |
| Dedicated top-level `resumable_sessions` section | More discoverable but duplicates operator domains and recommendation logic | |
| Both nested and top-level | Maximum discoverability with maximum duplication/drift risk | |

**User's choice:** Lock the nested resumable summary under `upload_sessions`.
**Notes:** No URI exposure, no protocol-debugging internals, and no separate resumable repair verb.

---

## Live-proof depth for the maintenance lane

| Option | Description | Selected |
|--------|-------------|----------|
| Minimum end-to-end only | Thinest live proof, but misses visibility guarantees between steps | |
| Live scenarios with intermediate assertions | Two real-GCS scenarios with stepwise checks on runtime-status visibility and cleanup outcomes | ✓ |
| Live scenarios plus worker telemetry assertions | Stronger observability checks but brittle and lower-value | |
| Broad live matrix | Highest confidence with highest flake/cost | |

**User's choice:** Lock the live scenarios with intermediate assertions approach.
**Notes:** Keep richer branch/error matrices local; live lane should validate stable public/operator surfaces rather than internal telemetry choreography.

---

## the agent's Discretion

- Exact `failure_reason` strings within the bounded taxonomy.
- Exact durable proof mechanism used to block unsafe resumable deletion.
- Exact text/JSON placement of resumable counters so long as `upload_sessions`
  remains primary.

## Deferred Ideas

None.
