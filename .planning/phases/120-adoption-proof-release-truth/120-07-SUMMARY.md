---
phase: 120-adoption-proof-release-truth
plan: 07
subsystem: install-smoke
tags: [elixir, postgresql, package-consumer, migration, proof]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: populated public-to-rindle generated upgrade harness
provides:
  - Exact Rindle marker, foreign-key, and named-index catalog evidence
  - Exact before/after public.oban_jobs catalog preservation evidence
affects: [package-consumer, release-proof, proof]
tech-stack:
  added: []
  patterns: [parameterized PostgreSQL catalog queries, JSON-safe catalog snapshots, damaged-report policy tests]
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
decisions:
  - "Upgrade preservation is proven with marker contents and named PostgreSQL catalog objects, not existence booleans."
  - "public.oban_jobs preservation is exact before/after catalog snapshot equality independent of host-migration provenance."
metrics:
  duration: 25m
  completed: 2026-08-10
  tasks: 2
  files: 2
status: complete
---

# Phase 120 Plan 07: Exact Upgrade Catalog Proof Summary

The packed populated-upgrade harness now reports exact Rindle catalog facts and an unchanged full public Oban catalog snapshot.

## Accomplishments

- Replaced marker-table existence, join-based FK, and any-index booleans with ordered marker versions, the named `media_variants_asset_id_fkey` catalog record, and ordered named media-variant index definitions.
- Added normalized `public.oban_jobs` before/after snapshots containing relation identity, ordered columns, constraints, and indexes, then made exact equality the preservation gate.
- Added focused damaged-report fixtures covering marker loss, FK loss, loss and definition mutation of each required index, plus Oban identity, column, constraint, and index changes.

## Task Commits

1. **Task 1 / RED: Add catalog policy regressions** — `60efa40`
2. **Tasks 1–2 / GREEN: Report exact Rindle and Oban catalog facts** — `d54b24e`

## Verification

- `mix format --check-formatted test/install_smoke/support/generated_app_helper.ex test/install_smoke/generated_app_smoke_test.exs` — passed before the shared database connection pool became exhausted.
- `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` — passed (3 tests, 0 failures) after implementation.
- `RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_isolation_upgrade --seed 0` — unrun: PostgreSQL rejected connections with `FATAL 53300 (too_many_connections)` before the generated-app scenario could execute.

### Follow-up correction

- A packed public-compatibility rerun exposed Postgrex's typed `regclass` parameter encoding: a relation name passed to `$1::regclass` was encoded as an OID and failed before catalog observation.
- The generated snapshot now reuses the selected `public.oban_jobs` OID for all column, constraint, and index catalog queries. The focused source regression rejects a return to the incompatible `::regclass` parameter pattern.
- `mix format --check-formatted test/install_smoke/support/generated_app_helper.ex test/install_smoke/generated_app_smoke_test.exs` and `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` — passed (4 tests, 0 failures). Per follow-up scope, no external packed or Cohort gate was attempted.

### Follow-up correction: reserved catalog alias

- A fresh packed run exposed PostgreSQL 42601 because generated catalog SQL used the reserved word `constraint` as an unquoted alias.
- Replaced that alias with `catalog_constraint` in both the Oban snapshot and media-variant foreign-key queries; the focused source policy rejects `pg_constraint constraint`.
- `mix format --check-formatted test/install_smoke/support/generated_app_helper.ex test/install_smoke/generated_app_smoke_test.exs` and `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` — passed (4 tests, 0 failures). No external smoke was run.

### Follow-up correction: authoritative generated doctor evidence

- The outer `mix rindle.doctor` invocation cannot observe the generated host migration context and is retained only as diagnostic output.
- Isolation-upgrade readiness now requires the generated smoke test's `doctor_success=true` output, where `Doctor.run_checks` receives its filtered host migration statuses.
- A focused source policy rejects the brittle outer-doctor phrase. Formatting and the `phase_120_upgrade_contract` suite passed (5 tests, 0 failures); no external smoke was run.

### Follow-up correction: bounded generated command diagnostics

- Generated child commands now run through a 20-minute bounded task, with their command stage prepended to captured output and explicit timeout diagnostics (including cwd).
- This preserves existing callers while ensuring an expensive package/Phoenix/dependency/compile command cannot silently hold the parent test process indefinitely.
- Focused contracts passed (6 tests, 0 failures). A direct packed public gate invocation was started, but its profile-gated module had already been compiled by the preceding fast run and selected no tests; it was not treated as integration evidence.

### Follow-up correction: globally unique generated workspaces

- Replaced VM-local `System.unique_integer/1` workspace names with `mktemp -d` allocation beneath the system temporary directory, preventing concurrent BEAM processes from sharing and deleting one another's generated-app root.
- The focused source policy rejects the process-local workspace pattern and requires the OS-global temporary-directory allocation. Formatting and the focused suite passed (7 tests, 0 failures). The packed retry was deferred because the currently compiled profile gate would select no tests without a clean rebuild.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed forced Oban ownership predicate from the asserted contract**
- **Found during:** Task 2
- **Issue:** A boolean derived from whether the host migration had run was always false and could not detect a Rindle-caused Oban mutation.
- **Fix:** Compare complete normalized before/after catalog snapshots instead.
- **Files modified:** `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/generated_app_smoke_test.exs`
- **Commit:** `d54b24e`

## Deferred Issues

- The authoritative image-profile upgrade verification must be rerun after PostgreSQL connection capacity is restored; it was not a code failure and no safe repository-side fix applies.

## Known Stubs

None.

## Self-Check: PASSED

- Both modified install-smoke files exist.
- Commits `60efa40` and `d54b24e` exist in git history.
