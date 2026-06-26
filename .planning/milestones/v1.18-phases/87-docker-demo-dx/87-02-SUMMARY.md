---
phase: 87-docker-demo-dx
plan: "02"
subsystem: docker-demo-dx
tags: [dockerfile, cache, mix, cohort-demo]
requires: []
provides:
  - Cache-friendly Cohort Dockerfile ordering for Mix dependency fetches.
  - Static source-order proof that dependency fetches precede the full source copy.
affects: [cohort-demo, docker-preview, phase-87-docs]
tech-stack:
  added: []
  patterns:
    - Copy Mix dependency manifests before broad source copies.
    - Run asset vendoring and compile only after source is copied.
key-files:
  created: []
  modified:
    - docker/Dockerfile.cohort-demo
key-decisions:
  - "Kept the Docker preview as a simple build and did not introduce release builds, split images, reverse proxies, or production deployment topology."
patterns-established:
  - "Routine source, style, and template edits should not invalidate the Hex dependency fetch layer."
requirements-completed: [DX-02]
duration: 2 min
completed: 2026-06-11
---

# Phase 87 Plan 02: Dockerfile Cache Ordering Summary

**Cohort Docker preview dependency fetches now sit before the full source copy so routine UI/source edits reuse the Hex deps layer.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-11T18:21:34Z
- **Completed:** 2026-06-11T18:22:59Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Copied root and Cohort Mix manifests before the full repository source copy.
- Moved `mix deps.get` ahead of `COPY . /app`.
- Preserved the preview-only Dockerfile boundary with `EXPOSE 4102`, the existing entrypoint, and no release/split-image topology.

## Task Commits

Each source-changing task was committed atomically:

1. **Task 1: Reorder Dockerfile dependency layer** - `bd2bb2d` (fix)
2. **Task 2: Preserve preview-only Dockerfile boundary** - verified against `bd2bb2d`; no additional source delta was required.

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `docker/Dockerfile.cohort-demo` - Separates dependency manifest copy and `mix deps.get` from the full source copy, then runs asset vendoring and compile after source is present.

## Decisions Made

- Left the image as the existing local preview image rather than converting it into a release build or multi-stage production shape.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

None.

## Verification

- Dockerfile line-order assertion proved root/demo manifests and `mix deps.get` occur before `COPY . /app`.
- Dockerfile line-order assertion proved `mix assets.vendor` and `mix compile` occur after `COPY . /app`.
- `grep -F "EXPOSE 4102" docker/Dockerfile.cohort-demo` passed.
- `grep -F "ENTRYPOINT [\"/entrypoint.sh\"]" docker/Dockerfile.cohort-demo` passed.
- Forbidden preview-topology terms were absent from the Dockerfile.
- `bash -n docker/cohort-demo-entrypoint.sh` passed.
- `shellcheck docker/cohort-demo-entrypoint.sh` passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 87-03 can document the env-driven Compose/script contract and the Dockerfile cache expectation.

---
*Phase: 87-docker-demo-dx*
*Completed: 2026-06-11*
