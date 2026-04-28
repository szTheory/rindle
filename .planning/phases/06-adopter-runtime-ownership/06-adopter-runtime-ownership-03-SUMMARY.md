---
phase: 06-adopter-runtime-ownership
plan: 03
subsystem: docs
tags: [docs, ecto, oban, runtime-repo, adopter]
requires:
  - phase: 06-adopter-runtime-ownership
    provides: runtime repo contract proofs for facade, broker, and worker paths
provides:
  - adopter-first repo ownership guidance in getting started and troubleshooting docs
  - explicit Phase 6 default-Oban scope statement for background processing
  - guide snippets synchronized with canonical direct-upload and proxied-upload proofs
affects: [guides, release-readiness, adopter-runtime-ownership]
tech-stack:
  added: []
  patterns: [docs mirror executable adopter proofs, default-Oban scope documented explicitly]
key-files:
  created: []
  modified: [guides/getting_started.md, guides/background_processing.md, guides/troubleshooting.md]
key-decisions:
  - "Teach `config :rindle, :repo, MyApp.Repo` as the adopter contract everywhere public docs discuss runtime persistence."
  - "Document Phase 6 as compatible with the default `Oban` path only and defer named-instance / `:oban_name` ownership from this release."
patterns-established:
  - "Guide Drift Gate: adopter-facing snippets should stay aligned with the canonical lifecycle and proxied-upload proof files."
  - "Ownership Language: docs describe adopter-owned Repo and Oban runtime boundaries, not library-owned infrastructure."
requirements-completed: [ADOPT-04]
duration: 2 min
completed: 2026-04-28
---

# Phase 06 Plan 03: Adopter Runtime Ownership Summary

**Public guides now teach adopter-owned repo configuration, default-Oban scope, and troubleshooting queries that match the Phase 6 runtime proofs.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-28T09:37:16Z
- **Completed:** 2026-04-28T09:39:25Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added an explicit `config :rindle, :repo, MyApp.Repo` setup step and proxied-upload example to [guides/getting_started.md](/Users/jon/projects/rindle/guides/getting_started.md).
- Replaced adopter-facing `Rindle.Repo` troubleshooting queries with `MyApp.Repo` examples in [guides/troubleshooting.md](/Users/jon/projects/rindle/guides/troubleshooting.md).
- Clarified that adopters own Oban supervision, queue config, and the default Oban Repo, while named-instance support remains out of scope in [guides/background_processing.md](/Users/jon/projects/rindle/guides/background_processing.md).

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite setup and troubleshooting guides around adopter-owned Repo resolution**
   - `1a088fc` (`docs`): repo ownership guidance and troubleshooting query alignment
2. **Task 2: Document the exact Oban ownership boundary for Phase 6**
   - `0dc7800` (`docs`): default-Oban scope and enqueue-contract clarification

## Files Created/Modified

- `guides/getting_started.md` - adds explicit adopter-owned repo configuration and a proxied-upload example that matches the Phase 6 proof lane.
- `guides/background_processing.md` - states the default-Oban-only support boundary and updates the detach enqueue example to the current contract.
- `guides/troubleshooting.md` - swaps adopter debugging examples to `MyApp.Repo` reads and updates.

## Decisions Made

- Treated guide wording as part of the runtime contract, so the docs now describe repo ownership exactly as the executable adopter proofs do.
- Documented Oban support narrowly: default `Oban` path is supported in Phase 6, while named-instance / `:oban_name` routing is explicitly deferred.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Task 1 verification caught one remaining `Rindle.Repo` mention in prose, which was removed before commit so the no-leak guide contract passed exactly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The public guides now match the proven adopter-owned runtime contract from Plans 06-01 and 06-02.
- Release-readiness work can reference these guides without carrying forward stale repo or Oban ownership assumptions.

## Self-Check: PASSED
