---
phase: 87-docker-demo-dx
plan: "01"
subsystem: docker-demo-dx
tags: [docker-compose, shell, minio, cohort-demo]
requires: []
provides:
  - Env-driven loopback bindings for the Cohort app, MinIO API, and MinIO console.
  - Browser-facing MinIO URL interpolation aligned with the selected host API port.
  - Deterministic launch URL output for app, admin console, and MinIO console.
affects: [cohort-demo, docker-preview, phase-87-docs]
tech-stack:
  added: []
  patterns:
    - Docker Compose interpolation with loopback host bindings.
    - Shell wrapper URL output derived from the same env defaults as Compose.
key-files:
  created: []
  modified:
    - docker/compose.cohort-demo.yml
    - scripts/demo/up.sh
key-decisions:
  - "Kept container-internal MinIO service wiring on http://minio:9000 while browser-facing URLs use host.docker.internal and the selected host API port."
  - "Preserved scripts/demo/up.sh as the primary launch wrapper and added --print-urls as a static verification path."
patterns-established:
  - "Preview ports are controlled by COHORT_DEMO_PORT, COHORT_MINIO_PORT, and COHORT_MINIO_CONSOLE_PORT with loopback-only publication."
  - "Launch output labels stay exact: app, admin console, and MinIO console."
requirements-completed: [DX-01, DX-03]
duration: 8 min
completed: 2026-06-11
---

# Phase 87 Plan 01: Compose And Launch URL Contract Summary

**Loopback-bound Cohort Docker preview ports with env-driven host overrides and deterministic launch URLs.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-11T18:13:00Z
- **Completed:** 2026-06-11T18:21:33Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced fixed Compose host bindings with loopback-bound env interpolation for the app, MinIO API, and MinIO console.
- Preserved stable container ports and internal MinIO service setup while making browser-facing presigned URLs use the selected host MinIO API port.
- Added `scripts/demo/up.sh --print-urls` and normal launch URL output for `app`, `admin console`, and `MinIO console`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Render env-driven loopback Compose contract** - `88beb6c` (fix)
2. **Task 2: Preserve launch wrapper and add URL map print path** - `f7564c2` (feat)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `docker/compose.cohort-demo.yml` - Publishes app and MinIO ports on `127.0.0.1` with Phase 87 env defaults and aligns `RINDLE_MINIO_URL` with `COHORT_MINIO_PORT`.
- `scripts/demo/up.sh` - Resolves/export port defaults, prints the exact URL map, supports `--print-urls`, and preserves `docker compose up --build "$@"`.

## Decisions Made

- Kept `minio-init` on `http://minio:9000`; only browser-facing MinIO URLs use `host.docker.internal`.
- Used plain text label and URL lines in the wrapper so static checks and users see the same copy-pasteable map.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

None.

## Verification

- `COHORT_DEMO_PORT=4212 COHORT_MINIO_PORT=9200 COHORT_MINIO_CONSOLE_PORT=9201 COMPOSE_PROJECT_NAME=rindle-cohort-check docker compose -f docker/compose.cohort-demo.yml config` rendered the expected project name, three loopback host bindings, published ports, target ports, project-scoped volumes, and `RINDLE_MINIO_URL: http://host.docker.internal:9200`.
- `bash -n scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh` passed.
- `shellcheck scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh` passed.
- `COHORT_DEMO_PORT=4212 COHORT_MINIO_CONSOLE_PORT=9201 scripts/demo/up.sh --print-urls` printed exactly the three locked labels and URLs.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 87-02 can rely on the Compose and launch wrapper contract while fixing Dockerfile cache ordering.

---
*Phase: 87-docker-demo-dx*
*Completed: 2026-06-11*
