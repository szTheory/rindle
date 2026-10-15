---
phase: 133-evidence-charter-and-live-truth
plan: "128"
subsystem: testing
tags: [mix, hex, offline, dependency-diagnostic]

# Dependency graph
requires:
  - phase: 133-126
    provides: Immutable zero-credit history and read-only offline supply
  - phase: 133-127
    provides: Evidence validators used to preserve the Plan 126 boundary
provides:
  - Guarded Plan 128 offline dependency observation with zero qualification credit
  - Separate Plan 129 qualification identity and supply-staging path
affects: [133-129, evidence-charter, live-truth]

# Actuals measured against the plan ledger at summary authoring time.
actuals:
  tokens: 17450
  tasks: 2
  commits: 2
plan_head_before: a543deb9725f0be3b3f40ef5823e41f56e1d8e8c
plan_head_after: 8ed91b981b59f2f8369c3bdb5d758f0f72952f0c

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guarded, offline, single-child diagnostics publish bounded sanitized output to a no-clobber report."
    - "Historical supply staging rehashes immutable inputs without replaying old runtime or network probes."

key-files:
  created:
    - scripts/maintainer/phase_133_dependency_diagnostic.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-128-DIAGNOSTIC.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-128-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/test_phase_133_local_gates.sh

key-decisions:
  - "Keep Plan 126 artifacts and authority read-only; do not repeat its fetch or qualification attempt."
  - "Preserve the diagnostic report's cause classification as not_determined and record the exact Mix output for review."
  - "Do not repair the missing mux registry entry without authenticated registry metadata; Plan 129 needs a fresh exact authorization for retrieval."
  - "Require Plan 129 to use its own source, supply, report, and no-clobber attempt marker."

requirements-completed: []

coverage:
  - id: D1
    description: "A guarded offline Mix diagnostic records bounded safe output, guard evidence, and zero qualification credit."
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/phase_133_local_gates.sh --verify-diagnostic --output .planning/phases/133-evidence-charter-and-live-truth/133-128-DIAGNOSTIC.json"
        status: pass
    human_judgment: false
  - id: D2
    description: "Plan 129 admission rejects Plan 126 authority and uses distinct qualification identities."
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_local_gates.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "The exact missing offline Hex registry entry for mux is retained as a zero-credit stop, with no fabricated repair."
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_local_gates.sh (offline registry metadata classifier fixture)"
        status: pass
    human_judgment: false

duration: 32min
completed: 2026-10-08
status: complete
---

# Phase 133 Plan 128: Evidence Charter and Live Truth Summary

**A guarded offline Mix diagnostic retained the missing Hex registry entry for `mux` and stopped with zero qualification credit.**

## Performance

- **Duration:** 32 min
- **Started:** 2026-10-08T16:15:40Z
- **Completed:** 2026-10-08T16:47:56Z
- **Tasks:** 2
- **Files modified or created:** 6

## Accomplishments

- Added a guarded, one-child offline diagnostic and read-only verifier. The actual diagnostic report is `133-128-DIAGNOSTIC.json`, SHA256 `a1aeca83fd4a961d4636773c2fa7428693f2da488ca6a9a91d716a39c7395cdb`.
- The diagnostic ran `mix deps.get --check-locked` once with `HEX_OFFLINE=1`; the sandbox guard and loopback `EPERM` witness passed both initially and immediately before the child. Mix exited 1 and emitted: `** (Mix) Hex is running in offline mode and the registry entry for package mux is not cached locally`.
- Added a regression for the exact offline registry-metadata message and distinct Plan 129 authority checks. Plan 126's seven artifact hashes match before and after the diagnostic; its supply digest remains `9441e4cb9882287c563d861f118cfe4747c08592c45018cf2c7320440d3a8924`.
- Left EVID-01/02/03/04 and TRUTH-08 Pending, with no requirement completion or qualification credit. Plan 126 was not retried and no network operation was performed.

## Task Commits

1. **Task 1: Preserve and classify one fresh offline dependency observation** - `d5ec48b6` (test)
2. **Task 2: Repair only the diagnosed dependency failure and prove retention** - `8ed91b98` (feat; bounded zero-credit stop recorded because required registry metadata is absent)

The metadata commit records this Summary separately.

## Files Created/Modified

- `scripts/maintainer/phase_133_dependency_diagnostic.mjs` - bounded offline child, guard checks, redaction, no-clobber report, and read-only verification.
- `scripts/maintainer/phase_133_local_gates.sh` - diagnostic dispatch and separate Plan 129 qualification admission.
- `scripts/maintainer/phase_133_local_supply.mjs` - distinct Plan 129 supply identity and byte-only revalidation/staging for historical Plan 126 inputs.
- `scripts/maintainer/test_phase_133_local_gates.sh` - diagnostic sanitizer, guard, collision, exact-cause, and authority-boundary regressions.
- `.planning/phases/133-evidence-charter-and-live-truth/133-128-DIAGNOSTIC.json` - immutable observation with `diagnostic_only: true`, `qualification_credit: 0`, and `requirements_completed: []`.

## Decisions Made

- The report's machine classification remains `not_determined` (`child_failure_requires_exact_output_review`). The bounded excerpt preserves the exact Mix message, which identifies the missing offline registry entry for `mux`; a regression covers that exact message. No report field was rewritten after publication.
- The Plan 126 supply does not provide the registry metadata named by Mix. Because acquiring it requires fresh authorization, this plan records the zero-credit stop and leaves retrieval to Plan 129's exact checkpoint.
- Plan 129 must not reuse Plan 126 source or qualification authority; it receives a distinct supply path, report basename, and attempt marker.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added byte-only validation for historical diagnostic supply staging**
- **Found during:** Task 1
- **Issue:** Replaying the historical supply verifier's runtime and guard checks failed with `report_recomputed_mismatch`, so the existing path could not stage the already authenticated Plan 126 bytes for an offline diagnostic.
- **Fix:** Added a diagnostic-only staging path that rehashes the original lock, 67 cached archives, Vix, Lexbor, and supply digest without replaying the old dynamic probes or changing Plan 126 artifacts.
- **Files modified:** `scripts/maintainer/phase_133_local_supply.mjs`
- **Verification:** Full phase-133 local-gates regression and diagnostic verifier passed; the report records identical Plan 126 artifact hashes before and after.
- **Committed in:** `8ed91b98`

**Total deviations:** 1 auto-fixed (Rule 3). **Impact:** Enabled the authorized offline observation while preserving Plan 126's read-only and no-replay boundary.

## Issues Encountered

The diagnostic child failed because Hex's offline registry entry for package `mux` is not cached locally. The report retained that exact output, but its machine cause field remains `not_determined` pending exact-output review. No authenticated registry metadata was present in the Plan 126 supply, so no dependency repair or `mix.lock` change was made. This is a zero-credit stop, not qualification evidence.

## User Setup Required

None for Plan 128. Plan 129 requires a fresh exact authorization before retrieving the missing registry metadata.

## Next Phase Readiness

Plan 129 can proceed only with its own exact authorization and distinct source, supply, report, and attempt marker. Do not reuse Plan 126 authorization or treat this diagnostic as qualification. The five requirements remain Pending, and the eleven flagged edge rows remain flagged.

## Self-Check: PASSED

- Diagnostic report exists and its read-only verifier passes.
- Task commits `d5ec48b6` and `8ed91b98` exist on this worktree branch.
- No Plan 126 artifact changed; no requirement or qualification credit was claimed.
