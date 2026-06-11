---
phase: 87-docker-demo-dx
plan: "03"
subsystem: docker-demo-dx
tags: [documentation, adoption-demo, proof-matrix, docker-preview]
requires:
  - phase: 87-01
    provides: Env-driven Compose ports and launch URL output.
  - phase: 87-02
    provides: Cache-friendly Cohort Dockerfile ordering.
provides:
  - Docker quick-try documentation aligned with Phase 87 script and Compose behavior.
  - Adoption proof matrix row aligned with local Docker preview truth and static drift checks.
affects: [cohort-demo, docs, proof]
tech-stack:
  added: []
  patterns:
    - Command-first Docker preview documentation.
    - Static proof matrix drift checks for optional local preview behavior.
key-files:
  created: []
  modified:
    - examples/adoption_demo/README.md
    - examples/adoption_demo/docs/adoption-proof-matrix.md
key-decisions:
  - "Documented port conflict recovery through env vars and COMPOSE_PROJECT_NAME instead of process-level or compose-file workarounds."
  - "Kept Docker preview claims optional, preview-only, and static-checkable."
patterns-established:
  - "Docs name the same URL labels that scripts/demo/up.sh prints: app, admin console, and MinIO console."
  - "Proof matrix local preview rows stay optional and point to deterministic static checks."
requirements-completed: [DX-01, DX-02, DX-03]
duration: 3 min
completed: 2026-06-11
---

# Phase 87 Plan 03: Docker Quick-Try And Proof Matrix Summary

**Cohort Docker preview docs now match the env-driven Compose/script contract and the cache-friendly Dockerfile behavior.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-11T18:22:59Z
- **Completed:** 2026-06-11T18:25:29Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Updated the Cohort README Docker quick-try section to describe launch URL labels, defaults, override env vars, sibling-stack namespacing, and cache expectations.
- Updated the adoption proof matrix local preview row and try-local section to describe env-driven loopback ports, `COMPOSE_PROJECT_NAME`, printed URL labels, and static verification.
- Kept the local Docker preview optional, preview-only, and not CI-blocking while preserving the proof matrix drift gate.

## Task Commits

Each task was committed atomically:

1. **Task 1: Update Docker quick-try docs** - `4fcb1ac` (docs)
2. **Task 2: Update adoption proof matrix and drift checks** - `9692982` (docs)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `examples/adoption_demo/README.md` - Documents `./scripts/demo/up.sh`, URL labels, env overrides, `COMPOSE_PROJECT_NAME`, loopback/local preview behavior, and cache expectations.
- `examples/adoption_demo/docs/adoption-proof-matrix.md` - Updates local click-around preview truth and names static verification checks, including `check_adoption_proof_matrix.sh`.

## Decisions Made

- Used command-first conflict recovery examples with `COHORT_DEMO_PORT`, `COHORT_MINIO_PORT`, `COHORT_MINIO_CONSOLE_PORT`, and `COMPOSE_PROJECT_NAME`.
- Left full Docker startup as an optional manual smoke; static checks remain the required autonomous proof path.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

None.

## Verification

- README assertions found `Preview only`, `./scripts/demo/up.sh`, all three URL labels, and all four override env vars.
- README forbidden wording check passed for process-killing, compose-file editing, public MinIO, and production-deployment guidance.
- Proof matrix assertions found the local preview row, Compose/script references, `COMPOSE_PROJECT_NAME`, `COHORT_DEMO_PORT`, `MinIO console`, and `check_adoption_proof_matrix.sh`.
- Proof matrix forbidden wording check passed for public MinIO, production deployment, Traefik, and release-build claims.
- `scripts/maintainer/check_adoption_proof_matrix.sh` passed.
- Full Phase 87 static gate passed: shell syntax, shellcheck, rendered Compose config, Dockerfile source-order assertion, and proof matrix drift check.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 87 implementation is ready for phase-level review and verification.

---
*Phase: 87-docker-demo-dx*
*Completed: 2026-06-11*
