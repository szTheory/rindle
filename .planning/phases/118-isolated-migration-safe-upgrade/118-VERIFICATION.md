---
phase: 118-isolated-migration-safe-upgrade
verified: 2026-08-09T17:15:23Z
status: human_needed
score: 2/4 must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 1/4
  gaps_closed:
    - "The published migration now calls directional helpers directly at migration-body scope; it no longer nests them in execute(fn -> ... end)."
    - "V1 translates PostgreSQL lock-not-available errors to bounded quiesce-and-retry guidance, with targeted contention and privilege tests added."
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "An adopter can run a host-owned public-to-rindle upgrade that moves exactly the six Rindle tables and rindle_migration_versions while preserving rows, indexes, and relationships."
    test: "In a clean disposable PostgreSQL test database, run `mix test test/rindle/migration_test.exs:436 --include test --seed 0`."
    expected: "The Ecto.Migrator forward and reverse execution of the documented direct-call module moves exactly seven relations, preserves fixture/index/sequence/FK/marker state, and leaves oban_jobs and schema_migrations in public."
    why_human: "The exact behavioral test is present and reaches Ecto.Migrator, but this verification environment has a pre-existing partial public schema; the test fails in its fixture setup before the move is invoked."
  - truth: "Mixed, incomplete, or insufficient-permission database states stop before an unsafe move and provide bounded corrective guidance."
    test: "Against the same clean isolated test database, run the named contention and privilege cases: lines 303, 381, and 401 of migration_test.exs with `--include test`."
    expected: "A synchronized second backend produces bounded lock guidance with no move and no SET LOCAL leakage; both privilege denial paths refuse before schema creation or relocation."
    why_human: "The test code exercises these branches through the public helper, but the shared database is missing required public Rindle fixture relations and cannot reach either asserted behavior."
human_verification:
  - test: "Run the documented migration integration case in a clean isolated PostgreSQL database."
    expected: "The direct helper calls inside Ecto.Migrator up/down complete, preserving all seven Rindle relations' data and relational objects while host relations remain untouched."
    why_human: "Current shared test state is partial and makes the fixture setup fail before the operation under verification."
  - test: "Run the named lock-contention and privilege-refusal cases in that clean database."
    expected: "Contention returns bounded quiesce/retry guidance atomically and locally; denied database/schema CREATE refuses before any move."
    why_human: "These state-transition behaviors require a clean live PostgreSQL fixture; source inspection and string tests cannot prove them."
---

# Phase 118: Isolated Migration & Safe Upgrade Verification Report

**Phase Goal:** Adopters can create a fresh isolated install or move a populated legacy install to `rindle` without losing Rindle data or taking ownership of host infrastructure.
**Verified:** 2026-08-09T17:15:23Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh host migration provisions the selected schema, all six Rindle tables, and Rindle marker state idempotently. | ✓ VERIFIED | `migration_test.exs:36` passed with `--include test`; it runs `Rindle.Migration.up(version: 1)` and verifies `rindle`, all six tables, and marker version. Options/default and ownership contracts also passed (55 focused tests). |
| 2 | A host-owned public-to-`rindle` upgrade moves exactly six Rindle tables plus marker while preserving data and integrity. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | The fixed seven-relation loop, direct public API, documented direct-call module, and an `Ecto.Migrator.up/down` integration test exist. The named test currently fails during its public-fixture setup because the shared database lacks `public.media_attachments`, before either helper executes. |
| 3 | Mixed, incomplete, or insufficient-permission states stop before unsafe moves with bounded corrective guidance. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `V1` preflights catalog/ownership/privilege state before `provision_schema/1`; SQLSTATE lock handling and deterministic privilege cases are implemented. The named live cases cannot be exercised in the dirty shared database. |
| 4 | Upgrade instructions state maintenance-window and limited host-controlled rollback operation truthfully. | ✓ VERIFIED | `guides/upgrading.md` specifies backup, drained writers/workers, `SET LOCAL lock_timeout`, direct pinned helpers, untouched Oban/ledger, and guarded reverse versus destructive `down/1`. Its structural parity test passed. |

**Score:** 2/4 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/rindle/migration/options.ex` | Narrow `rindle` default / explicit `public` contract | ✓ VERIFIED | Artifact check passes; fast contract confirms only the two supported prefixes. |
| `lib/rindle/migration/v1.ex` | Sole fixed ownership, preflight, provisioning, moves, lock guidance | ✓ VERIFIED | `owned_relations/0` is exactly six tables plus marker; move code runs only that list and catalog values are bound/quoted. The artifact tool's missing literal `lock_timeout` is a false negative: timeout policy belongs in host migration SQL, while V1 recognizes `:lock_not_available` / `55P03`. |
| `lib/rindle/migration.ex` | Version-pinned forward/reverse public APIs | ✓ VERIFIED | Only `move_public_to_rindle/1` and `move_rindle_to_public/1` dispatch to V1; fast/API tests reject generic movers and directional prefix/source/target options. |
| `test/rindle/migration_test.exs` | Live fresh/move/refusal/reverse/lock/privilege proof | ⚠️ ENVIRONMENT-BLOCKED | Substantive named integration tests exist, including direct `Ecto.Migrator` proof. Current shared `rindle_test` schema is partial, so populated setup cannot complete. |
| `guides/upgrading.md` | Executable maintenance-window host migration | ✓ VERIFIED | `up/0` and `down/0` queue timeout SQL then call directional helpers directly, avoiding the prior nested Runner command. |
| `test/install_smoke/docs_parity_test.exs` | Direct-call documentation regression guard | ✓ VERIFIED | Passing focused suite requires direct-call ordering and rejects `execute(fn -> helper ...)`. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Rindle.Migration.move_public_to_rindle/1` | `V1.move_public_to_rindle/1` | version-only validation/dispatch | ✓ WIRED | Public wrapper validates exactly `[version: 1]` then invokes V1. |
| V1 preflight | fixed `ALTER TABLE ... SET SCHEMA` loop | classification, target creation, queued immediate callback | ✓ WIRED | `move_public_to_rindle/1` preflights before provisioning, then `move_owned_relations/3` iterates the single seven-relation authority. |
| Upgrade guide | directional helper APIs | direct migration-body calls after `SET LOCAL lock_timeout` | ✓ WIRED | Guide, parity test, and `DocumentedMoveMigration` share the non-nested callback shape. |
| PostgreSQL `55P03` | bounded migration guidance | narrow rescue around immediate relation move | ✓ WIRED | `move_relation!/3` translates only lock-not-available; non-lock Postgrex errors are re-raised. |
| privilege probes | V1 classifier | process-scoped test seam or real SQL privilege queries | ✓ WIRED | Production queries `has_database_privilege`/`has_schema_privilege`; the private seam accepts only approved boolean fields. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `V1` preflight | relation/marker/ownership/privilege snapshot | PostgreSQL catalog and marker queries | Yes | ✓ FLOWING |
| documented migration | queued DDL | Ecto.Migration.Runner through public helper | Yes by code path; runtime confirmation blocked by dirty test DB | ⚠️ BEHAVIOR-UNVERIFIED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Fast API/documentation contracts | `mix test test/rindle/migration_fast_test.exs test/install_smoke/docs_parity_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` | 55 tests, 0 failures | ✓ PASS |
| Fresh selected-schema provisioning | `mix test test/rindle/migration_test.exs:36 --include test --seed 0` | 1 test, 0 failures | ✓ PASS |
| Exact documented Ecto.Migrator forward/reverse path | `mix test test/rindle/migration_test.exs:436 --include test --seed 0` | Fails before the migration under test: `public.media_attachments` is absent during pre-existing fixture setup | ? ENVIRONMENT-BLOCKED |
| Lock contention / privilege refusal | Named tests at lines 303, 381, 401 | Not rerun after the same reproducible fixture precondition failure | ? ENVIRONMENT-BLOCKED |

### Probe Execution

Step 7c: SKIPPED — no Phase 118 probe scripts or declared probes were found.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| MIGRATE-01 | 118-01, 118-04 | Provision selected schema before Rindle tables and marker, idempotently | ✓ SATISFIED | Fresh live test passed; narrow prefix/default and docs contracts pass. |
| MIGRATE-02 | 118-02, 118-03, 118-05 | Documented host-owned, data-preserving exact seven-relation move | ? NEEDS HUMAN | Code/docs/wiring and integration coverage are present, but the exact live case cannot run against current shared DB state. |
| MIGRATE-03 | 118-02 through 118-06 | Fail closed with bounded guidance; honest maintenance/rollback operations | ? NEEDS HUMAN | Documentation is verified and implementation is substantive; live lock/privilege transitions remain blocked by the same shared fixture state. |

No orphaned Phase 118 requirements were found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/rindle/migration_test.exs` | fixture setup for populated cases | Shared `public` schema is assumed complete; current test DB is partial | ⚠️ Warning | Prevents current behavioral verification, but does not demonstrate a production migration defect. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt markers were found in Phase 118 source/docs/tests. Inspection also confirms the Phase prohibitions: no generic mover/search-path routing, no Rindle ownership of `oban_jobs` or `schema_migrations`, no destructive `down/1` rollback claim, and no zero-downtime/quiescence promise.

### Human Verification Required

### 1. Clean-database documented upgrade tracer

**Test:** Provision an isolated, disposable PostgreSQL database with a clean complete `public` Rindle fixture, then run the named `Ecto.Migrator` test at `migration_test.exs:436` with `--include test`.

**Expected:** The documented direct callback moves and reverses exactly the seven Rindle relations, preserving rows/indexes/sequences/FKs/marker while `oban_jobs` and `schema_migrations` stay in `public`.

**Why human:** The current shared test DB is partially modified and fails before the migration path runs.

### 2. Clean-database safety transitions

**Test:** In that same isolated database, run the named lock and privilege cases (lines 303, 381, 401) with `--include test`.

**Expected:** Lock contention yields bounded quiesce/retry guidance with no partial relocation or timeout leak; both privilege refusals leave all owned relations in `public` before mutation.

**Why human:** They need live PostgreSQL state transitions; the local shared fixture is not valid for them.

### Gaps Summary

The three prior implementation gaps are closed in code: the guide no longer nests Ecto commands, the direct host migration has an Ecto.Migrator test, and V1 has narrow lock-timeout guidance plus privilege/atomicity coverage. There is no observable source-level implementation gap or deferred item for later phases. Completion is held at the Escalation Gate because current clean-database behavioral evidence is unavailable; restoring or selecting an isolated disposable test database is required to turn the two present-but-unverified truths into verified truths.

---

_Verified: 2026-08-09T17:15:23Z_
_Verifier: the agent (gsd-verifier)_
