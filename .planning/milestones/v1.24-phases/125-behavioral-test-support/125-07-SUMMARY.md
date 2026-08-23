---
phase: 125-behavioral-test-support
plan: "07"
subsystem: testing
tags: [elixir, exunit, documentation-parity, migrations]
requires:
  - phase: 125-06
    provides: Generated-app source ownership seams
provides:
  - Shared read-once docs-parity support mechanics
  - Independently runnable install and migration documentation contract suite
affects: [125-08, docs-parity]
tech-stack:
  added: []
  patterns: [named document maps, domain-owned parity suites, compiled-doc support]
key-files:
  created: [test/install_smoke/docs_parity/support.ex, test/install_smoke/docs_parity/install_and_migrations_test.exs]
  modified: [test/install_smoke/docs_parity_test.exs]
key-decisions:
  - "Keep shared support limited to read-once loading and parser/compiled-doc mechanics; public-contract assertions remain domain-owned."
  - "Move install, migration, upgrade, and ownership assertions together so fixture and documentation links remain independently runnable."
requirements-completed: [TEST-03, SAFE-01]
duration: 27min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 07: Documentation Parity Migration Domain Summary

**Documentation parity now has a narrow shared mechanics seam and a dedicated install/migrations suite that preserves the shipped host-migration contract.**

## Accomplishments

- Extracted read-once document loading, section/order/fence/migration parsing, compiled-doc lookup, and normalization into hidden `DocsParity.Support`.
- Moved pinned `Rindle.Migration`, host-owned Oban, public/default schema, populated-upgrade, troubleshooting, historical migration, and upgrade-navigation assertions into `InstallAndMigrationsTest`.
- Retained the aggregate as the remaining docs-parity owner without duplicate test registrations.

## Task Commits

1. **Task 1: Extract shared read-once documentation mechanics** — `7996470` (refactor)
2. **Task 2: Move install, migration, upgrade, and ownership parity as one domain** — `c13cfbc` (test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored exact helper failure diagnostics during support extraction**
- **Found during:** Task 1
- **Issue:** The inherited partial support extraction changed argument order and removed diagnostic failure paths.
- **Fix:** Restored the aggregate helpers' prior semantics and messages, then added the named read-once loader.
- **Files modified:** `test/install_smoke/docs_parity/support.ex`
- **Commit:** `7996470`

## Verification

- `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs test/install_smoke/docs_parity/install_and_migrations_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0` — pass (59 tests, 0 failures).
- `bash scripts/maintainer/refactor_contract.sh` — pass (92 tests, 0 failures).
- `mix format` for all Plan 125-07 test files — pass.

## Self-Check: PASSED

Declared artifacts exist and task commits `7996470` and `c13cfbc` are present.
