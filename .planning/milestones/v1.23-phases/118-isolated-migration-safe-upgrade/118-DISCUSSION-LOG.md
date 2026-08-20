# Phase 118: Isolated Migration & Safe Upgrade - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-09
**Phase:** 118-Isolated Migration & Safe Upgrade
**Areas discussed:** Upgrade migration API, move preflight policy, rollback contract, operational guidance boundary

---

## Upgrade migration API

| Option | Description | Selected |
|--------|-------------|----------|
| Narrow versioned Rindle helper invoked by a host migration | Rindle centralizes its fixed seven-relation move while the adopter owns timing and Ecto ledger. | ✓ |
| Handwritten host SQL | Every adopter copies the allowlist, preflight, and quoting logic. | |
| Generic relocation API | Supports arbitrary source/destination schemas. | |

**User's choice:** Approved the researched recommendation package.
**Notes:** Preserve a narrow, version-pinned host-migration wrapper; reject generic schema management and copy/paste migration SQL as the canonical path.

---

## Move preflight policy

| Option | Description | Selected |
|--------|-------------|----------|
| Exact complete-state preflight | Allow only a complete public source and absent target; reject all mixed, partial, collision, marker, and privilege states before DDL. | ✓ |
| Best-effort/idempotent partial reconciliation | Attempt to repair or merge partial source/target states. | |
| Loose `IF EXISTS` behavior | Continue where possible and tolerate missing relations. | |

**User's choice:** Approved the researched recommendation package.
**Notes:** Fail closed with bounded corrective guidance; no guessing, merging, or hidden recovery.

---

## Rollback contract

| Option | Description | Selected |
|--------|-------------|----------|
| Guarded host-controlled reverse move | A separate reverse helper is available only under the same exact-state and quiescence rules. | ✓ |
| Forward-only with no reverse helper | Require restore from backup or manual SQL. | |
| Use `Rindle.Migration.down/1` | Destructively remove Rindle state. | |

**User's choice:** Approved the researched recommendation package.
**Notes:** Backups and a maintenance window remain required; destructive `down/1` is never upgrade rollback.

---

## Operational guidance boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 118 migration truth plus targeted docs | Ship required API/snippet parity and clear maintenance/error guidance; defer packaged-adopter and final release truth. | ✓ |
| Defer all documentation | Leave current public/arbitrary-prefix instructions until Phase 120. | |
| Complete every release surface now | Pull Phase 120's full adoption/release proof into this phase. | |

**User's choice:** Approved the researched recommendation package.
**Notes:** Phase 118 must not leave false migration guidance; Phase 119 retains diagnostics and Phase 120 retains packed/Cohort proof plus final release truth.

---

## the agent's Discretion

- Exact helper names, internal query structure, lock-timeout technique, and bounded error wording within the approved contract.

## Deferred Ideas

- Generic arbitrary-schema migration management — rejected as out of scope; reconsider only with an explicit multitenancy charter.
