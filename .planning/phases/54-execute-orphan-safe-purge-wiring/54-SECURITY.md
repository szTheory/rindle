---
phase: 54
slug: execute-orphan-safe-purge-wiring
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-26
---

# Phase 54 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Phase 54 adds a public owner-erasure execute lane and hardens the async purge
> worker so stale or duplicate purge work cannot delete shared assets.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| caller -> `Rindle.erase_owner/2` | Untrusted caller input selects which owner's attachments are targeted for detach and purge planning. | Owner struct identity, semantic owner-erasure report |
| `Rindle.erase_owner/2` -> DB transaction | Preview/execute planning becomes attachment-row deletion plus purge enqueue state. | Attachment ids, asset ids, slots, profile names, Oban enqueue intent |
| DB commit -> Oban purge jobs | Async destructive work may run after attachment truth changes. | `asset_id`, `profile` job args |
| Oban job args -> `PurgeStorage.perform/1` | The worker must treat job payload as stale until live attachment truth is re-checked. | Asset identity and profile only |
| worker -> storage adapter deletes | Byte deletion and asset-row deletion happen outside the original DB transaction and require a final safety guard. | Storage keys for source/variants, asset row deletion |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation / Evidence | Status |
|-----------|----------|-----------|-------------|-----------------------|--------|
| T-54-01 | Tampering | `lib/rindle/internal/owner_erasure.ex` | mitigate | `execute/2` rebuilds the plan inside `Multi.run(:plan, ...)` and deletes rows from that live plan via `Ecto.Multi.delete_all`, instead of trusting preview output. Contract coverage in `test/rindle/owner_erasure_test.exs` proves execute detaches and reports from recomputed DB truth. | CLOSED |
| T-54-02 | Denial of service | purge enqueue loop in `lib/rindle/internal/owner_erasure.ex` | mitigate | `purge_job/2` uses Oban uniqueness on active states only, and `summarize_purge_results/1` treats `%Oban.Job{conflict?: true}` as semantic success. The already-queued path is verified by `returns semantic success when purge work is already queued`. | CLOSED |
| T-54-03 | Information disclosure | public owner-erasure report maps | mitigate | `build_report/2` emits only semantic keys: `mode`, bucket counts/entries, `purge_enqueued`, and `purge_already_queued`. Tests assert only `attachment_id`, `asset_id`, `slot`, `profile`, and `surviving_attachment_count` appear in the bucket entries. | CLOSED |
| T-54-04 | Repudiation | public execute/report contract | mitigate | `lib/rindle.ex` defines a stable `owner_erasure_report()` and exports `preview_owner_erasure/2` plus `erase_owner/2` as the auditable public facade. Phase-local verification `mix test test/rindle/owner_erasure_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` passed on 2026-05-26 with 20 tests and 0 failures. | CLOSED |
| T-54-05 | Tampering | `lib/rindle/workers/purge_storage.ex` | mitigate | `perform/1` now calls `attachments_exist?/2` and returns `:ok` immediately when any attachment still exists, preventing stale purge jobs from deleting shared assets. Worker regression tests cover both delete and skip paths. | CLOSED |
| T-54-06 | Denial of service | repeated purge jobs for the same asset | accept | Duplicate purge jobs remain acceptable because the worker is idempotent and cheap on the survivor path, while Plan 01's active-state uniqueness reduces duplicate work before execution. The accepted behavior is documented in the phase threat model and confirmed by the no-op survivor path in `test/rindle/workers/purge_storage_test.exs`. | CLOSED |
| T-54-07 | Information disclosure | worker/log-visible asset operations | mitigate | The worker args contract remains the narrow `%{"asset_id" => asset_id, "profile" => profile}` shape; no owner ids or attachment details were added to job payloads or returned worker values. | CLOSED |
| T-54-08 | Elevation of privilege | legacy slot-scoped APIs triggering shared-asset deletion | mitigate | `attach/4` and `detach/3` keep their enqueue behavior, but destructive safety moved to the worker boundary where surviving attachments short-circuit deletion. `test/rindle/attach_detach_test.exs` proves a shared asset survives when another attachment remains live. | CLOSED |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-54-01 | T-54-06 | Duplicate purge jobs are acceptable because active-state uniqueness reduces them and the hardened worker turns survivor-path repeats into safe `:ok` no-ops. | Codex | 2026-05-26 |

*Accepted risks do not resurface in future audit runs.*

---

## Unregistered Flags

None. Phase 54 summary artifacts do not contain a `## Threat Flags` section,
and the implementation evidence matches the declared threat model without
introducing new endpoints, widened worker payloads, or undocumented privilege
boundaries.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-26 | 8 | 8 | 0 | Codex |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-26
