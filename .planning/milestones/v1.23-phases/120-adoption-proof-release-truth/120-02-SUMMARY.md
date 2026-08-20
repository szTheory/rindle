---
phase: 120-adoption-proof-release-truth
plan: 02
subsystem: testing
tags: [elixir, phoenix, postgres, package-consumer, schema-isolation]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: packed default-install ownership and persistence evidence
provides:
  - Isolated explicit-public package-consumer fixture topology
  - Populated public-to-rindle host-migration proof harness
affects: [package-consumer, release-proof, phase-120]
tech-stack:
  added: []
  patterns: [separate compile-time consumer roots, schema-qualified upgrade reports]
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
key-decisions:
  - "Public compatibility and post-move default routing compile in separate generated app roots against the same upgraded database."
  - "The upgrade fixture invokes only the pinned host migration helper and reports relational integrity from schema-qualified catalogs."
requirements-completed: []
coverage:
  - id: D1
    description: Explicit public compatibility has an isolated compiled fixture and fast topology contract.
    requirement: PROOF-01
    verification:
      - kind: unit
        ref: mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_compat_contract --seed 0
        status: pass
      - kind: integration
        ref: RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_public_compat --seed 0
        status: unknown
    human_judgment: false
  - id: D2
    description: Populated public data moves via the host migration and is read by a default-compiled consumer.
    requirement: PROOF-01
    verification:
      - kind: unit
        ref: mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0
        status: pass
      - kind: integration
        ref: RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_isolation_upgrade --seed 0
        status: unknown
    human_judgment: false
duration: 35min
completed: 2026-08-10
status: blocked
---

# Phase 120 Plan 02: Compatibility and Populated Upgrade Proof Summary

**Generated packed consumers now model explicit public compatibility and a seeded public-to-`rindle` host migration with separate compile-time builds.**

## Performance

- **Duration:** 35 min
- **Completed:** 2026-08-10T20:33:03Z
- **Tasks:** 2/2 implementation tasks
- **Files modified:** 2

## Accomplishments

- Added a distinct public-compiled generated app, fixed `prefix: "public"` host migration, schema-qualified ownership report, and real persistence lifecycle.
- Added a separate public/default generated-app upgrade flow that seeds relational state, runs `move_public_to_rindle(version: 1)` under `SET LOCAL lock_timeout = '5s'`, and reports relation, FK, index, marker, host-boundary, doctor-layout, and post-move persistence facts.
- Made generated smoke database names process-independent, preventing stale temporary databases from contaminating later catalog checks.

## Task Commits

1. **Task 1: Prove explicit public compatibility in its own packed consumer** — `0872bb6` (RED), `8d1cc63` (GREEN)
2. **Task 2: Prove a populated public install moves and runs under the default** — `3c43e0f` (GREEN)
3. **Verification fix** — `55a46bc` (Rule 1)

## Verification

- `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_compat_contract --seed 0` — passed (1 test).
- `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` — passed (1 test).
- The authoritative image-profile commands began successfully and completed the initial generated-app test, but were interrupted after `phx.new --install` remained stalled while creating the public compatibility consumer. They must be rerun to close this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Isolated generated smoke database names across Mix invocations**
- **Found during:** authoritative package verification
- **Issue:** VM-local unique integers could reuse a prior temporary database name and expose stale public relations to a later fixture.
- **Fix:** Use timestamp-based generated database identities.
- **Files modified:** `test/install_smoke/support/generated_app_helper.ex`
- **Commit:** `55a46bc`

## Known Stubs

None.

## Deferred Issues

- Authoritative packed compatibility and isolation-upgrade gates remain unverified because generated-app dependency installation stalled. This is tracked in `.planning/WINDOWS.md` as `unrun-verify` entry 5.

## Self-Check: PASSED

- Both modified generated-app files exist.
- Task commits `0872bb6`, `8d1cc63`, `3c43e0f`, and `55a46bc` exist in git history.
