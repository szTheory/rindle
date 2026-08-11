---
phase: 120-adoption-proof-release-truth
plan: 04
subsystem: documentation
tags: [elixir, ecto, oban, postgres, migration, docs-parity]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: generated default and explicit-public host migration fixtures
provides:
  - README and Getting Started fresh-install contract aligned to generated proof fixtures
  - Rindle.Migration moduledoc parity with default/public host migration calls
  - Executable ownership and forbidden-flow documentation parity checks
affects: [adopter-docs, package-consumer, migration-api, release-proof]
tech-stack:
  added: []
  patterns: [generated-fixture source parity, host-owned migration topology]
key-files:
  created: []
  modified:
    - README.md
    - guides/getting_started.md
    - lib/rindle/migration.ex
    - test/install_smoke/docs_parity_test.exs
key-decisions:
  - "Public documentation copies the generated default and explicit-public host migration calls exactly."
  - "The compatibility call remains limited to a public-compiled release and never introduces arbitrary prefix routing."
requirements-completed: [DOCS-01]
coverage:
  - id: D1
    description: Fresh-install entrypoints mirror generated default/public migration fixtures and host ownership.
    requirement: DOCS-01
    verification:
      - kind: unit
        ref: mix test test/install_smoke/docs_parity_test.exs --seed 0
        status: pass
    human_judgment: false
  - id: D2
    description: Rindle.Migration moduledocs remain aligned with public entrypoints without changing migration behavior.
    requirement: DOCS-01
    verification:
      - kind: unit
        ref: mix format --check-formatted lib/rindle/migration.ex test/install_smoke/docs_parity_test.exs && mix test test/install_smoke/docs_parity_test.exs test/rindle/migration_fast_test.exs --seed 0
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-08-10
status: complete
---

# Phase 120 Plan 04: Fresh-Install Documentation Parity Summary

**Fresh-install docs and `Rindle.Migration` API docs now mechanically mirror the generated default-`rindle` and explicit-public host migration fixtures.**

## Performance

- **Duration:** 14 min
- **Completed:** 2026-08-10T20:43:43Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Documented separate host-owned Oban and Rindle migration files, normal `mix ecto.migrate`, and `mix rindle.doctor` verification in both adopter entrypoints.
- Made `public.oban_jobs` and `public.schema_migrations` ownership explicit while preserving `rindle` as the default and public-compiled compatibility as the only escape hatch.
- Added fast source-parity checks that compare README, Getting Started, moduledocs, and generated fixture calls while rejecting raw replay, arbitrary-prefix, and host-ownership drift.

## Task Commits

1. **Task 1: Lock one copy-pasteable fresh-install story across public entrypoints** — `af4302c` (RED), `ced4b83` (GREEN)
2. **Task 2: Make public migration API docs the same authority** — `83ec50b` (RED), `cf1430b` (GREEN)

## Files Created/Modified

- `README.md` — exact default/public host migration snippets and public host-relation ownership.
- `guides/getting_started.md` — detailed equivalent of the README fresh-install path.
- `lib/rindle/migration.ex` — canonical host topology, compatibility, ownership, and populated-upgrade cross-link.
- `test/install_smoke/docs_parity_test.exs` — generated-helper source parity for docs and moduledocs.

## Decisions Made

- Public documentation consumes the generated helper's behavior-bearing migration calls instead of duplicating a hand-maintained approximation.
- `prefix: "public"` remains tied to a distinct public-compiled host migration; no routing, option, or directional-move semantics changed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Formatted the new docs-parity assertions**
- **Found during:** Task 2
- **Issue:** `mix format --check-formatted` reported the new assertion layout as nonconforming.
- **Fix:** Ran the repository formatter on the two task files before verification.
- **Files modified:** `test/install_smoke/docs_parity_test.exs`
- **Verification:** formatting check and 38 focused tests passed.
- **Committed in:** `cf1430b`

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact:** Formatting-only correction; no scope or behavior change.

## Known Stubs

None.

## Issues Encountered

None.

## Next Phase Readiness

The three public fresh-install surfaces are mechanically coupled to the generated-app migration fixture source. The separate authoritative package verification recorded by Plan 120-02 remains outside this documentation plan.

## Self-Check: PASSED

- All four scoped files exist.
- Task commits `af4302c`, `ced4b83`, `83ec50b`, and `cf1430b` exist in git history.
- Final focused verification passed: 38 tests, 0 failures.

---
*Phase: 120-adoption-proof-release-truth*
*Completed: 2026-08-10*
