---
phase: 119-ownership-boundaries-diagnostics
plan: "02"
subsystem: diagnostics
tags: [elixir, ecto, postgres, oban, ownership-boundaries]
requires:
  - phase: 119-ownership-boundaries-diagnostics
    provides: "Tracer ownership snapshot and stable readiness checks"
provides:
  - "Canonical default-Oban binding validation before catalog reads"
  - "Bounded Oban binding, catalog, and Rindle ambiguity classifications"
  - "Live no-mutation proof for diagnostic ownership reads"
affects: [runtime-status, doctor, admin-diagnostics]
tech-stack:
  added: []
  patterns:
    - "Resolve host-owned Oban configuration before invoking catalog seams."
    - "Use the active shared Ecto sandbox connection for read-only diagnostic queries."
key-files:
  created: []
  modified:
    - lib/rindle/ops/ownership_snapshot.ex
    - lib/rindle/ops/runtime_checks.ex
    - test/rindle/ops/ownership_snapshot_test.exs
    - test/rindle/ops/runtime_checks_test.exs
    - test/rindle/migration_test.exs
decisions:
  - "Only the default Oban module bound to the configured Rindle repo is accepted; compatibility-prefix drift is a bounded refusal."
  - "Exact prefix mismatch requires an empty expected catalog and a complete marker-backed alternate catalog."
metrics:
  duration: "~10 min"
  completed: 2026-08-09
  tasks_completed: 2
  files_modified: 5
status: complete
---

# Phase 119 Plan 02: Ownership Binding and Read-Only Proof Summary

**Default host-Oban binding validation now gates fixed catalog diagnostics, with bounded ambiguity states and live before/after ownership preservation proof.**

## Accomplishments

- Resolves only the default `Oban` binding for the configured Rindle repo; absent, named, alternate-repo, false, empty, unsafe, and drifted prefixes refuse before either catalog seam runs.
- Keeps catalog errors bounded as `:inspection_failed`, does not retain adapter data, and restricts Rindle mismatch diagnosis to an empty expected catalog plus a complete marker-backed alternate prefix.
- Preserves stable doctor readiness check IDs and bounded check/telemetry metadata for all new ownership states.
- Adds a live PostgreSQL test proving healthy and refused diagnostic reads preserve `public.oban_jobs`, `schema_migrations`, default Oban configuration, and compatibility-prefix configuration.

## Task Commits

1. **Task 1 RED: Add binding refusal coverage** — `87ca06e` (test)
2. **Task 1 GREEN: Resolve canonical Oban ownership bindings** — `c2c8297` (feat)
3. **Task 2: Prove diagnostic host ownership preservation** — `78238e2` (test)
4. **Task 2 follow-up: Reuse active sandbox for diagnostic reads** — `7c32147` (fix)

## Verification

- `mix format --check-formatted lib/rindle/ops/ownership_snapshot.ex test/rindle/ops/ownership_snapshot_test.exs test/rindle/ops/runtime_checks_test.exs` — PASS.
- `mix test test/rindle/ops/ownership_snapshot_test.exs test/rindle/ops/runtime_checks_test.exs --seed 0` — PASS (50 tests, 0 failures).
- `mix format --check-formatted test/rindle/migration_test.exs` — PASS.
- `mix test test/rindle/migration_test.exs:137 --seed 0` — PASS (1 test, 0 failures; live healthy and refused ownership-preservation proof).
- `mix test` — BLOCKED by pre-existing shared-database state: `public.media_assets` is absent, producing 171 broad unrelated failures. The failure matches the pre-existing Phase 118 shared-database caveat; no test schema or protected baseline change was altered to mask it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reused the active SQL sandbox connection for diagnostic catalog reads**
- **Found during:** Task 2
- **Issue:** A second sandbox checkout classified valid live diagnostic reads as inspection failures.
- **Fix:** Query an already-running repo directly; the sandbox continues to enforce ownership and the diagnostic path remains read-only.
- **Files modified:** `lib/rindle/ops/ownership_snapshot.ex`
- **Verification:** Live before/after diagnostic test passes.
- **Commit:** `7c32147`

**2. [Rule 2 - Critical correctness] Deferred Oban catalog access until binding validation**
- **Found during:** Task 1
- **Issue:** The doctor path could obtain an Oban catalog before confirming its canonical host binding.
- **Fix:** Routed the catalog seam through `OwnershipSnapshot` only after repo, default-instance, prefix, and compatibility checks pass.
- **Files modified:** `lib/rindle/ops/runtime_checks.ex`, `lib/rindle/ops/ownership_snapshot.ex`
- **Verification:** Binding-refusal tests prove neither catalog seam is invoked.
- **Commit:** `c2c8297`

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 2). **Impact:** No public API or host-owned state changes; diagnostics are more strictly read-only.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all five modified implementation and test files exist.
- Confirmed commits `87ca06e`, `c2c8297`, `78238e2`, and `7c32147` exist in git history.
