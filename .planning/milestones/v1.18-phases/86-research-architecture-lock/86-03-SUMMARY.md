---
phase: 86-research-architecture-lock
plan: "03"
subsystem: docs
tags: [docker, cohort, ui-principles, agents, e2e]
requires:
  - phase: 84
    provides: brand tokens and contrast gate
  - phase: 85
    provides: repo surface and brand integration precedent
provides:
  - Docker demo DX lock
  - durable UI-principles guide
  - AGENTS.md link to UI principles
affects: [phase-87, phase-88, phase-91, phase-92, agents]
tech-stack:
  added: []
  patterns:
    - env-driven Docker demo ports
    - cache-friendly Dockerfile dependency-copy ordering
    - durable agent-facing UI governance
key-files:
  created:
    - guides/docker_demo_dx.md
    - guides/ui_principles.md
  modified:
    - AGENTS.md
key-decisions:
  - "COMPOSE_PROJECT_NAME is the Docker namespacing mechanism."
  - "Cohort demo ports are env-driven with defaults 4102, 9000, and 9001."
  - "Traefik is rejected for Phase 87 unless a later recorded requirement needs multi-host routing."
  - "Future UI/admin-console work must read guides/ui_principles.md via AGENTS.md."
patterns-established:
  - "Docker DX lock: namespacing, env ports, launch URL map, dependency-file-first build cache."
  - "UI principles lock: design/a11y audit, deterministic E2E, screenshots, motion, security, escalation."
requirements-completed: [PRIN-01]
duration: 2 min
completed: 2026-06-11
---

# Phase 86 Plan 03: Docker DX And UI Principles Summary

**Docker demo DX and durable UI-principles governance are locked, and future agents are routed to the guide from `AGENTS.md`.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-11T16:29:16Z
- **Completed:** 2026-06-11T16:31:10Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Created `guides/docker_demo_dx.md` with Compose project namespacing, env-driven ports,
  launch URL map, Dockerfile cache-ordering, local MinIO exposure, and Traefik decision.
- Created `guides/ui_principles.md` with PRIN-01 design-system values, visual/a11y audit,
  deterministic E2E, screenshot polish, motion, security/destructive-action, and escalation
  rules.
- Linked `guides/ui_principles.md` from the `AGENTS.md` Repository workflow section.

## Task Commits

1. **Task 1: Write Docker and Cohort demo DX lock** - `57fafcd` (docs)
2. **Task 2: Write durable UI-principles guide** - `cb2bf39` (docs)
3. **Task 3: Link UI principles from AGENTS** - `1451823` (docs)

## Files Created/Modified

- `guides/docker_demo_dx.md` - Docker/Cohort demo DX architecture lock.
- `guides/ui_principles.md` - Durable PRIN-01 UI guidance.
- `AGENTS.md` - Scoped Repository workflow link to UI principles.

## Decisions Made

- Phase 87 should use `COMPOSE_PROJECT_NAME` and env-driven host ports rather than fixed
  host bindings.
- The launch URL map labels are `app`, `admin console`, and `MinIO console`.
- The Dockerfile should copy `mix.exs`, `mix.lock`, `examples/adoption_demo/mix.exs`, and
  `examples/adoption_demo/mix.lock` before full source copy and run `mix deps.get` before
  app source copy.
- UI/admin-console changes now have durable agent-facing guidance in `AGENTS.md`.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

One source assertion initially failed because the exact lowercase phrase `seeded lifecycle
state` was capitalized. The wording was adjusted before the task commit and the full
assertion set passed.

## User Setup Required

None - no external service configuration required.

## Verification

- `test -f guides/docker_demo_dx.md`
- Required `rg` assertions for Docker project name, env ports, defaults, URL map, cache
  ordering, fixed-port baseline, MinIO console, Traefik, and multi-host routing.
- `test -f guides/ui_principles.md`
- Required `rg` assertions for all seven headings, token/contrast sources, CSS/theme terms,
  E2E/screenshot terms, and escalation triggers.
- `rg -n "For UI/admin-console work, follow \\[guides/ui_principles\\.md\\]\\(guides/ui_principles\\.md\\)" AGENTS.md`

## Self-Check: PASSED

- Key files exist on disk.
- Task commits are present in git history.
- Plan-level success criteria are satisfied.

## Next Phase Readiness

Phase 87 can implement Docker DX from the locked contract. Future UI/admin-console phases
will discover `guides/ui_principles.md` through `AGENTS.md`.

---
*Phase: 86-research-architecture-lock*
*Completed: 2026-06-11*
