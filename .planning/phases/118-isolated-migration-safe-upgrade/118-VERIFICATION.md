---
phase: 118-isolated-migration-safe-upgrade
verified: 2026-08-09T16:34:51Z
status: gaps_found
score: 1/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
gaps:
  - truth: "An adopter can run a host-owned public-to-rindle upgrade that moves exactly the six Rindle tables and rindle_migration_versions while preserving rows, indexes, and relationships."
    status: failed
    reason: "The sole published host-migration example wraps the directional helper in Ecto.Migration.execute/1. The helper queues its ALTER TABLE commands while that callback is executing; Ecto.Migration.Runner rejects nested commands, so the documented upgrade raises instead of moving the relations."
    artifacts:
      - path: "guides/upgrading.md"
        issue: "Lines 94-100 defer move_public_to_rindle/1 and move_rindle_to_public/1 inside execute callbacks."
      - path: "lib/rindle/migration/v1.ex"
        issue: "move_owned_relations/3 queues ALTER TABLE commands with Ecto.Migration.execute/1."
    missing:
      - "Publish an executable callback shape (or redesign the helper to issue DDL safely from a deferred callback)."
      - "Add an integration test that runs the exact documented host migration through Ecto.Migrator/Runner and asserts all seven relations moved."
  - truth: "Upgrade instructions state the required maintenance window and the limited, host-controlled rollback path truthfully."
    status: failed
    reason: "The prose accurately describes maintenance and rollback limits, but its copy-pasteable forward and reverse migration callbacks cannot execute the queued move operations. It therefore does not provide a truthful executable operating path."
    artifacts:
      - path: "guides/upgrading.md"
        issue: "The documented execute(fn -> Rindle.Migration.move_*...) callback nests Ecto migration commands."
    missing:
      - "Correct the guide and parity contract to prove the operational snippet executes end to end."
  - truth: "D-118-07: migration examples can set transaction-local lock_timeout, and lock contention fails boundedly without partial relocation."
    status: failed
    reason: "The example sets SET LOCAL lock_timeout, but V1 has no lock-timeout translation or dedicated contention path; an ALTER TABLE timeout propagates as a raw Postgrex error. The requested deterministic lock-contestion test is also absent from migration_test.exs."
    artifacts:
      - path: "lib/rindle/migration/v1.ex"
        issue: "move_owned_relations/3 directly queues ALTER TABLE and does not catch/translate lock timeout failures."
      - path: "test/rindle/migration_test.exs"
        issue: "No lock_timeout, second-connection contention, or timeout-locality test exists."
    missing:
      - "Translate lock-timeout failures to bounded operator guidance and add deterministic contention/atomicity coverage."
behavior_unverified_items:
  - truth: "Mixed, incomplete, or insufficient-permission database states stop before an unsafe move and provide bounded corrective guidance."
    test: "Using a disposable non-owner role, invoke the pinned forward helper once with no database CREATE privilege and once with an existing rindle schema lacking CREATE; then inspect both schemas."
    expected: "The helper raises bounded guidance before schema creation or any of the seven relation moves, leaving every owned relation in public."
    why_human: "The code has privilege branches, and tests cover incomplete/marker states, but no test exercises the PostgreSQL privilege branches with an actual role or an equivalent deterministic seam."
---

# Phase 118: Isolated Migration & Safe Upgrade Verification Report

**Phase Goal:** Adopters can create a fresh isolated install or move a populated legacy install to `rindle` without losing Rindle data or taking ownership of host infrastructure.
**Verified:** 2026-08-09T16:34:51Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Fresh host migration provisions selected schema, six tables, and marker idempotently. | ✓ VERIFIED | `Options` defaults to `rindle`; `V1.up/1` provisions before DDL; `migration_test.exs` exercises fresh/default and explicit-public idempotency (11 tests pass). |
| 2 | Host-owned public-to-`rindle` upgrade moves exactly seven owned relations while preserving data/integrity. | ✗ FAILED | Direct-helper tests pass, but the published host callback nests `execute/1`; installed Ecto Runner rejects nested commands. |
| 3 | Mixed, incomplete, or insufficient-permission states stop before unsafe moves with bounded guidance. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Classifier and bounded error mapping exist; incomplete/marker tests exist, but privilege paths have no behavioral proof. |
| 4 | Upgrade instructions truthfully state maintenance and limited rollback operation. | ✗ FAILED | The maintenance prose is sound, but its copy-pasteable forward/reverse snippet is not executable. |
| 5 | Lock contention fails boundedly and atomically. | ✗ FAILED | No lock-timeout translation or deterministic lock-contention test exists. |

**Score:** 1/4 roadmap truths verified (1 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/rindle/migration/options.ex` | `rindle` default and two-prefix contract | ✓ VERIFIED | Allowlist is exactly `rindle`/`public`; invalid values raise before DDL. |
| `lib/rindle/migration/v1.ex` | Sole owned-relation authority, provisioning, fixed moves | ⚠️ PARTIAL | Owns exact seven-relation list and qualified DDL; its queued move DDL cannot run from the published nested callback. |
| `lib/rindle/migration.ex` | Pinned directional public API | ✓ VERIFIED | Only `move_public_to_rindle/1` and `move_rindle_to_public/1`; generic move exports excluded. |
| `test/rindle/migration_test.exs` | Live fresh/move/refusal/rollback/privilege/lock proof | ⚠️ PARTIAL | Covers fresh, direct move, and injected rollback; lacks documented-callback, privilege, and lock contention coverage. |
| `guides/upgrading.md` | Executable maintenance-window move runbook | ✗ STUBBED WIRING | Required calls are present but wired through an invalid nested Ecto callback. |
| `test/install_smoke/docs_parity_test.exs` | Executable documentation contract | ⚠️ PARTIAL | Checks phrases only; does not execute the documented migration shape. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Rindle.Migration.move_public_to_rindle/1` | `V1.move_public_to_rindle/1` | Version-only dispatch | ✓ WIRED | Public wrapper validates `[version: 1]` then calls V1. |
| V1 preflight | Fixed seven-relation `ALTER TABLE` loop | Classify, provision absent target, move | ✓ WIRED for direct runner usage | Direct integration tests demonstrate populated move and rollback. |
| `guides/upgrading.md` | Directional APIs | Host Ecto callback plus `lock_timeout` | ✗ NOT WIRED | `execute(fn -> Rindle.Migration.move_*...)` attempts nested Runner commands. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `V1` move classifier | Catalog snapshot | Bound PostgreSQL catalog queries | Actual relation/marker/privilege state | ✓ FLOWING |
| Upgrade guide callback | Queued ALTER commands | Ecto Migration Runner | Not reached from documented callback | ✗ DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused migration implementation | `mix test test/rindle/migration_test.exs --seed 0` | 11 tests, 0 failures | ✓ PASS (does not cover guide callback) |
| Fast/API/docs contracts | `mix test test/rindle/migration_fast_test.exs test/rindle/api_surface_boundary_test.exs test/install_smoke/docs_parity_test.exs --seed 0` | 55 tests, 0 failures | ✓ PASS (string/reflection coverage only) |
| Nested callback viability | Installed `Ecto.Migration.Runner.execute/1` source | Raises `Ecto.MigrationError, "cannot execute nested commands"` when a callback queues V1's `execute/1` DDL | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| MIGRATE-01 | 118-01, 118-04 | Provision selected schema and idempotent fresh install | ✓ SATISFIED | Default, schema provisioning order, and public compatibility have focused passing tests. |
| MIGRATE-02 | 118-02, 118-03, 118-04 | Host-owned data-preserving public-to-rindle upgrade | ✗ BLOCKED | The only documented host migration uses a callback shape that cannot queue the helper's `ALTER TABLE` operations. |
| MIGRATE-03 | 118-02, 118-03, 118-04 | Safe refusal with bounded guidance and truthful operations | ✗ BLOCKED | Published operations callback fails; lock-timeout behavior lacks bounded guidance and coverage. Privilege behavior still needs human/runtime proof. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `guides/upgrading.md` | 95, 100 | Nested Ecto `execute/1` migration commands | 🛑 Blocker | Operator’s documented forward/reverse migration cannot perform table relocation. |
| `test/rindle/migration_test.exs` | — | Missing documented-callback, role privilege, and lock-contention coverage | ⚠️ Warning | Focused tests pass while the real operator flow remains unproven. |

### Human Verification Required

### 1. Privilege preflight with a non-owner role

**Test:** In a disposable database, use a non-owner role with a complete public install; separately deny database CREATE for an absent `rindle` target and schema CREATE for an existing empty target.

**Expected:** Each call reports bounded guidance and leaves every Rindle relation in `public`, without creating/moving `rindle` state.

**Why human:** Existing automated tests do not exercise the actual PostgreSQL role/privilege branches.

### Gaps Summary

Phase 118 delivers substantial direct-helper implementation: fresh provisioning, exact seven-relation ownership, transactional direct moves, and host-boundary checks are present. It does not achieve the adopter-facing upgrade goal because the published, copy-pasteable host migration nests Ecto commands and cannot execute the move. This is not deferred to Phases 119 or 120: those phases cover diagnostics and packaged/release proof, not repair of Phase 118’s core upgrade primitive.

---

_Verified: 2026-08-09T16:34:51Z_
_Verifier: the agent (gsd-verifier)_
