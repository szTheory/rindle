---
phase: 118-isolated-migration-safe-upgrade
plan: "04"
subsystem: documentation
tags: [elixir, ecto, postgresql, migrations, schema-isolation, docs]
requires:
  - phase: 118-03
    provides: "Pinned forward/reverse migration helpers with transactional safety"
provides:
  - "Fresh-install guidance for the rindle default and public compatibility pairing"
  - "A copy-pasteable host-owned populated-upgrade migration with local lock timeout"
  - "Executable documentation parity for ownership, maintenance, and rollback boundaries"
affects: [migration-safety, phase-119-diagnostics, phase-120-release-proof]
tech-stack:
  added: []
  patterns:
    - "Section-scoped documentation parity tests normalize Markdown whitespace while asserting behavior-bearing symbols"
    - "Operational migration docs distinguish guarded reverse moves from destructive teardown"
key-files:
  created: []
  modified:
    - README.md
    - guides/getting_started.md
    - guides/upgrading.md
    - test/rindle/migration_fast_test.exs
    - test/install_smoke/docs_parity_test.exs
key-decisions:
  - "Fresh installs use the rindle default; public remains the sole explicit compatibility pairing with a public-compiled release."
  - "Populated upgrades remain host-controlled maintenance-window operations, with Rindle moving only its seven fixed relations."
requirements-completed: [MIGRATE-01, MIGRATE-02, MIGRATE-03]
coverage:
  - id: D1
    description: "Fresh-install documentation states the rindle default, explicit public compatibility, and host-owned infrastructure boundary."
    requirement: MIGRATE-01
    verification:
      - kind: unit
        ref: "test/rindle/migration_fast_test.exs#current migration documentation names the bounded schema upgrade contract"
        status: pass
      - kind: unit
        ref: "test/install_smoke/docs_parity_test.exs#migration docs teach pinned Rindle.Migration and host-owned Oban setup"
        status: pass
    human_judgment: false
  - id: D2
    description: "Upgrade documentation provides the bounded forward and exactly-reversible guarded reverse paths."
    requirement: MIGRATE-02
    verification:
      - kind: unit
        ref: "test/install_smoke/docs_parity_test.exs#upgrade guide documents the bounded host-owned populated move"
        status: pass
      - kind: integration
        ref: "mix test test/rindle/migration_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "Documentation explains maintenance, transaction-local locking, privilege refusal, host ownership, and destructive-down limits."
    requirement: MIGRATE-03
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/docs_parity_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0"
        status: pass
    human_judgment: false
metrics:
  duration: "~13 min"
  tasks_completed: 2
  files_modified: 5
completed: 2026-08-09
status: complete
---

# Phase 118 Plan 04: Migration Documentation Contract Summary

**Rindle’s migration documentation now gives adopters a truthful rindle-default install path and a tested, host-controlled maintenance-window upgrade and guarded reverse runbook.**

## Accomplishments

- Updated README, Getting Started, and Upgrading guidance to use `rindle` by default and allow only explicit `prefix: "public"` with a public-compiled release.
- Added the copy-pasteable host Ecto migration that applies `SET LOCAL lock_timeout = '5s'` before each pinned directional helper.
- Documented the preflight-before-provisioning behavior, transaction rollback, host ownership (`oban_jobs` and `schema_migrations`), quiescence, deploy order, verification, and limits of guarded reverse moves.
- Added fast documentation smoke coverage and section-scoped parity tests that reject arbitrary prefixes, generic mover guidance, and live-migration claims without extending into Phase 119 or 120 scope.

## Task Commits

1. **Task 1: Write the fresh-install and maintenance-window upgrade path** — `2414d38` (docs)
2. **Task 2 RED: Lock migration documentation parity and phase boundaries** — `6cf7c2f` (test)
3. **Task 2 GREEN: Enforce safe migration docs contract** — `80c4b6c` (feat)

## Files Created/Modified

- `README.md` — default migration and host-infrastructure guidance.
- `guides/getting_started.md` — canonical fresh-install pairing.
- `guides/upgrading.md` — maintenance-window forward/reverse runbook.
- `test/rindle/migration_fast_test.exs` — DB-free migration-documentation smoke contract.
- `test/install_smoke/docs_parity_test.exs` — current-section documentation parity enforcement.

## Decisions Made

- Kept the public compatibility path explicit and narrow rather than reintroducing arbitrary schema prefixes.
- Kept populated upgrades inside adopter-owned Ecto migrations; Rindle does not own traffic quiescence, the migration ledger, or Oban infrastructure.
- Required exact reversibility (no post-move writes or later migrations and a previous public-compiled release) for the guarded reverse; `down/1` remains destructive teardown.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test robustness] Normalize Markdown whitespace in the parity assertion**
- **Found during:** Task 2 GREEN
- **Issue:** Markdown formatting wrapped behavior-bearing text, causing a literal phrase assertion to fail despite the documentation satisfying the intended operator contract.
- **Fix:** Normalize whitespace in the scoped upgrade section before checking focused symbols and phrases.
- **Files modified:** `test/install_smoke/docs_parity_test.exs`
- **Verification:** `mix test test/install_smoke/docs_parity_test.exs --seed 0`
- **Committed in:** `80c4b6c`

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** The parity test remains sensitive to contract drift rather than formatter line wrapping.

## Verification

- `mix format --check-formatted README.md guides/getting_started.md guides/upgrading.md test/rindle/migration_fast_test.exs` — PASS
- `mix test test/rindle/migration_fast_test.exs --seed 0` — PASS (5 tests)
- `mix test test/install_smoke/docs_parity_test.exs --seed 0` — PASS (31 tests)
- `mix test test/rindle/migration_test.exs --seed 0` — PASS (11 tests)
- `mix test test/install_smoke/docs_parity_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0` — PASS (53 tests)
- `mix coveralls.multiple --type local --type json --slowest 20` — PASS (1,273 tests, 0 failures, 4 skipped, 77 excluded)

## Known Stubs

None.

## Next Phase Readiness

Phase 118’s migration API and current documentation contract are aligned. Phase 119 remains responsible for separate-prefix diagnostics and raw-SQL/Oban boundary hardening; Phase 120 remains responsible for packaged-consumer, Cohort, and release-facing proof.

## Self-Check: PASSED

- Verified all five task-modified files exist.
- Verified task commits `2414d38`, `6cf7c2f`, and `80c4b6c` exist in git history.
- No known stubs, skipped planned tests, or unrun planned verification remain.
