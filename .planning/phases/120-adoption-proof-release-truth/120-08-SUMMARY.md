---
phase: 120-adoption-proof-release-truth
plan: 08
subsystem: install-smoke
tags: [elixir, migration, postgres, documentation, package-consumer]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: exact generated-app catalog proof from Plan 120-07
provides:
  - Executable explicit-public migration fixture with matching up and down callbacks
  - Documentation parity for both public migration callbacks across README, Getting Started, and API docs
affects: [package-consumer, release-proof, documentation]
tech-stack:
  added: []
  patterns: [generated migration callback extraction, two-direction public compatibility parity]
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/docs_parity_test.exs
    - README.md
    - guides/getting_started.md
    - lib/rindle/migration.ex
key-decisions:
  - "The explicit-public fixture exposes separate up and down callbacks so parity detects drift in either direction."
  - "Only explicit-public compatibility callbacks carry prefix: public; default teardown remains unprefixed."
patterns-established:
  - "Public compatibility snippets are compared against both behavior-bearing generated fixture callbacks."
requirements-completed: [DOCS-01, PROOF-01]
coverage:
  - id: D1
    description: "Generated explicit-public compatibility migrations install and roll back the public schema."
    requirement: PROOF-01
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_compat_contract --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "README, Getting Started, and Rindle.Migration moduledocs match both public fixture callbacks."
    requirement: DOCS-01
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/docs_parity_test.exs test/rindle/migration_fast_test.exs --seed 0"
        status: pass
    human_judgment: false
metrics:
  duration: 11m
  completed: 2026-08-10
  tasks: 2
  files: 5
status: complete
---

# Phase 120 Plan 08: Public Migration Rollback Parity Summary

The generated explicit-public migration and all public snippets now use `prefix: "public"` for both installation and destructive teardown.

## Accomplishments

- Reused the generated fixture's selected-prefix option for both `Rindle.Migration.up/1` and `down/1`, leaving the default fixture unprefixed.
- Exposed separate generated public `up` and `down` calls, then compared both calls against README, Getting Started, and `Rindle.Migration` moduledocs.
- Retained the default teardown and populated-upgrade directional-move guidance as distinct contracts.

## Task Commits

1. **Task 1 / RED: Make the generated explicit-public migration reversible in public** — `d49242d` (`test`)
2. **Tasks 1–2 / GREEN: Align generated fixture and public snippets** — `204f50d` (`feat`)

## Verification

- `mix format --check-formatted lib/rindle/migration.ex test/install_smoke/docs_parity_test.exs test/install_smoke/support/generated_app_helper.ex` — passed.
- `mix test test/install_smoke/docs_parity_test.exs --seed 0` — passed (34 tests, 0 failures).
- `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_compat_contract --seed 0` — passed (1 test, 0 failures).
- `mix test test/install_smoke/docs_parity_test.exs test/rindle/migration_fast_test.exs --seed 0` — passed (39 tests, 0 failures).

## Files Modified

- `test/install_smoke/support/generated_app_helper.ex` — generates and exposes matching public `up`/`down` migration callbacks.
- `test/install_smoke/docs_parity_test.exs` — requires both explicit-public callbacks on every supported docs surface.
- `README.md`, `guides/getting_started.md`, `lib/rindle/migration.ex` — show the safe explicit-public rollback snippet.

## Decisions Made

- Public compatibility is locked as an exact up/down pair. Default and populated-upgrade rollback semantics remain separate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected an initially over-broad documentation replacement**
- **Found during:** Task 2
- **Issue:** The first replacement targeted the default migration's `down/1` call instead of the explicit-public snippet.
- **Fix:** Restored default teardown to its unprefixed call and applied `prefix: "public"` only to each `InstallPublicRindle` snippet.
- **Files modified:** `README.md`, `guides/getting_started.md`, `lib/rindle/migration.ex`
- **Verification:** Full docs parity and migration fast tests pass.
- **Committed in:** `204f50d`

## Known Stubs

None.

## Self-Check: PASSED

- All five scoped implementation files exist.
- Commits `d49242d` and `204f50d` exist in git history.

---
*Phase: 120-adoption-proof-release-truth*
*Completed: 2026-08-10*
