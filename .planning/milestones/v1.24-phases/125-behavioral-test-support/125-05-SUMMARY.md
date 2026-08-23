---
phase: 125-behavioral-test-support
plan: "05"
subsystem: testing
tags: [elixir, exunit, postgres, phoenix, migrations, generated-app]
requires:
  - phase: 125-04
    provides: Stable facade and hidden generated Phoenix patcher
provides:
  - Hidden generated migration owner for host/Rindle writers, runners, seeds, and catalog snapshots
  - Report-level isolation-upgrade proof for complete Oban catalog and migration ownership facts
affects: [125-06, generated-app-support]
tech-stack:
  added: []
  patterns: [explicit migration scenario inputs, generated database outcome proof]
key-files:
  created: [test/install_smoke/support/generated_app/migrations.ex]
  modified: [test/install_smoke/support/generated_app_helper.ex, test/install_smoke/generated_app_smoke_test.exs]
key-decisions:
  - "Keep scenario selection and facade report normalization in GeneratedAppHelper; Migrations only writes generated migration mechanics."
  - "Pass root, app module, prefix, scenario, report name, and version facts explicitly into the hidden owner."
requirements-completed: [TEST-01, TEST-02, SAFE-01]
coverage:
  - id: D1
    description: "Isolation-upgrade report proves full Oban catalog snapshots, migration paths, marker/index/foreign-key facts, and doctor readiness"
    requirement: TEST-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --include phase_120_isolation_upgrade --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Generated migration mechanics retain host-owned Oban, pinned Rindle, catalog, public compatibility, and legacy upgrade behavior"
    requirement: TEST-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --seed 0"
        status: pass
      - kind: integration
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "SAFE-01 protected product and release boundaries remain unchanged"
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 05: Generated Migration Owner Summary

**Generated host and Rindle migration mechanics now have one hidden owner while the stable facade retains scenario orchestration and report-level catalog proof.**

## Performance

- **Duration:** 14 min
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Extended the isolation-upgrade tracer with concrete complete-Oban-snapshot and host migration path outcome assertions.
- Extracted host marker, host Oban, pinned Rindle, directional/legacy source writers, generated migration runner, upgrade seed, and catalog query mechanics into `GeneratedApp.Migrations`.
- Preserved facade report shaping, Contracts validation, profile/package decisions, and all protected product migration surfaces.

## Task Commits

1. **Task 1: Complete outcome coverage for one isolation-upgrade migration path** — `c8d8871` (test)
2. **Task 2: Extract generated migration and catalog mechanics** — `3047c3c` (refactor)

## Files Created/Modified

- `test/install_smoke/support/generated_app/migrations.ex` — hidden generated migration, runner, seed, and catalog-snapshot owner.
- `test/install_smoke/support/generated_app_helper.ex` — stable facade with explicit migration inputs and unchanged report assembly.
- `test/install_smoke/generated_app_smoke_test.exs` — outcome-level isolation migration report assertions.

## Decisions Made

- Migrations receives explicit root, module, prefix, scenario, report name, and version facts; it does not choose package/profile configuration or normalize facade reports.
- The generated consumer and mutation contract remain the authority for migration behavior; no migration-source-text snapshots were added.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed stale helper migration calls after relocation**
- **Found during:** Task 2 compilation.
- **Issue:** The mechanical extraction left obsolete private calls alongside the new Migrations delegation.
- **Fix:** Removed the duplicate calls so the facade has one migration owner.
- **Files modified:** `test/install_smoke/support/generated_app_helper.ex`
- **Verification:** Generated-app suite and SAFE-01 pass.
- **Committed in:** `3047c3c`

## Next Phase Readiness

Plan 125-06 can isolate generated profile/smoke source generation without re-owning migration or catalog effects.

## Self-Check: PASSED

`migrations.ex`, the facade, and generated-consumer test exist; commits `c8d8871` and `3047c3c` are present, and no protected `lib/`, `priv/repo/migrations`, `mix.exs`, or `mix.lock` file changed.
