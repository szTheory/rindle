---
phase: 86-research-architecture-lock
plan: "01"
subsystem: docs
tags: [admin-console, architecture, ia, liveview, operations]
requires:
  - phase: 84
    provides: brand tokens and logo posture consumed by console docs
provides:
  - mountable admin console router and safe-mount architecture lock
  - task-first Rindle Admin information architecture
affects: [phase-89, phase-90, admin-console, operations]
tech-stack:
  added: []
  patterns:
    - LiveDashboard/Oban-style router macro mounted inside host auth scope
    - Rindle.Admin.Queries read boundary
    - diagnostics-before-actions IA
key-files:
  created:
    - guides/admin_console_architecture.md
    - guides/admin_console_ia.md
  modified: []
key-decisions:
  - "Rindle.Admin.Router.rindle_admin/2 is the recommended mount surface."
  - "Host apps own browser/auth pipelines and LiveView :on_mount; unsafe unauthenticated production mounts are refused by default."
  - "Console reads stay in Rindle.Admin.Queries and do not become public Rindle facade convenience reads."
  - "Rindle Admin uses exactly six top-level task surfaces."
patterns-established:
  - "Admin architecture lock: host-authenticated macro, self-contained assets, CSP/socket options, optional dependency gates."
  - "IA lock: Home/Status, Assets, Upload Sessions, Variants/Jobs, Runtime/Doctor, Actions."
requirements-completed: [PRIN-01]
duration: 10 min
completed: 2026-06-11
---

# Phase 86 Plan 01: Admin Console Architecture And IA Summary

**Mountable console architecture and task-first Rindle Admin IA locked for downstream implementation phases.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-11T16:18:00Z
- **Completed:** 2026-06-11T16:27:56Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `guides/admin_console_architecture.md` with the router macro, safe mount,
  asset serving, CSP/socket, optional dependency, logo/home, and query-boundary decisions.
- Created `guides/admin_console_ia.md` with the six task-first console surfaces and
  diagnostics-before-actions split.
- Verified the public facade boundary with `mix test test/rindle/api_surface_boundary_test.exs`.

## Task Commits

1. **Task 1: Write mountable console architecture lock** - `750e737` (docs)
2. **Task 2: Write task-first console IA map** - `c1cde69` (docs)

## Files Created/Modified

- `guides/admin_console_architecture.md` - Router macro, auth ownership, static asset,
  CSP/socket, optional dependency, and `Rindle.Admin.Queries` architecture lock.
- `guides/admin_console_ia.md` - Persona/JTBD-to-surface map for `Rindle Admin`.

## Decisions Made

- The mount surface is documented as `Rindle.Admin.Router.rindle_admin/2`.
- Phase 86 locks the safe-mount policy but intentionally defers the exact dev/test
  escape-hatch public option name to Phase 89.
- The default Rindle logo links to `:home_path`; replacement/hiding is allowed as an
  implementation option category with exact names deferred.
- Reads belong to `Rindle.Admin.Queries`; actions reuse existing facade/ops surfaces.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

One source assertion initially failed because the exact phrase `host Tailwind` was split
across a Markdown line break. The wording was tightened before the task commit and the
full assertion set passed.

## User Setup Required

None - no external service configuration required.

## Verification

- `test -f guides/admin_console_architecture.md`
- Required `rg` assertions for router macro, auth, static assets, CSP/socket, optional
  dependency, logo/home, and `Rindle.Admin.Queries` terms.
- `mix test test/rindle/api_surface_boundary_test.exs` - 17 tests, 0 failures.
- `test -f guides/admin_console_ia.md`
- Required `rg` assertions for all six surfaces, service identity, query boundary,
  runtime-status read model, and destructive-action terms.

## Self-Check: PASSED

- Key files exist on disk.
- Task commits are present in git history.
- Plan-level success criteria are satisfied.

## Next Phase Readiness

Phase 89 can implement the router macro and read surfaces without reopening Phase 86
architecture decisions. Phase 90 can map destructive/action flows to the locked IA.

---
*Phase: 86-research-architecture-lock*
*Completed: 2026-06-11*
