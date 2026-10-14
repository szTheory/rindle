---
phase: 133-evidence-charter-and-live-truth
plan: "76"
subsystem: ci-diagnostics
tags: [phase-133, causal-evidence, mix-environment, hex-cleanup]
requires:
  - phase: 133-74
    provides: [per-call JOSE snapshots and immutable local CI observations]
provides:
  - Root Mix environment provenance distinct from dependency-local JOSE provenance
  - Symlink-safe collector-owned Hex cache cleanup and post-cleanup Git status evidence
  - Plan 75 report and summary digests bound as history; Plan 75 subject rejected for recollection
affects: [phase-133-plan-77, phase-133-causal-evidence]
actuals:
  tokens: 10973
  tasks: 2
  commits: 4
  plan_head_before: a175ac4cc809086755400a0e8edeb6f2e36ed7a8
  plan_head_after: 54e47bfa597eb30fe6a20ad57895324e9733ecc5
tech-stack:
  added: []
  patterns: [root-process and dependency-local Mix provenance are independently recorded, clean status follows contained owned-cache cleanup]
key-files:
  created: []
  modified:
    - scripts/maintainer/phase_133_causal_evidence.sh
    - scripts/maintainer/test_phase_133_causal_evidence.sh
key-decisions:
  - "Record root Mix.env() separately from JOSE dependency-local Mix.env()."
  - "Remove only the exact collector-owned .hex directory after physical containment and symlink checks, then record Git status."
  - "Preserve Plan 75 report and summary digests and reject its subject for new collection."
patterns-established:
  - "Process provenance: bind the root Mix probe and dependency-local observation to separate report fields."
  - "Owned cleanup: verify .hex ownership and containment before recursive removal, then measure final worktree status."
requirements-completed: []
requirements-pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: Root Mix provenance is distinct from JOSE dependency context, and the owned Hex cache is safely removed before final cleanliness is measured.
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_causal_evidence.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: Adversarial reports reject forged or missing root provenance, unsafe cleanup, dirty final state, and exhausted Plan 75 subject reuse while retaining historical evidence.
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_causal_evidence.sh"
        status: pass
    human_judgment: false
duration: 19min
completed: 2026-10-03
status: complete
---

# Phase 133 Plan 76: Causal Evidence Collector Correction Summary

**The causal collector now records root Mix provenance independently, safely removes its owned Hex cache, and rejects dirty or previously exhausted evidence subjects.**

## Performance

- **Duration:** 19 min
- **Started:** 2026-10-03T20:07:06-04:00
- **Completed:** 2026-10-04T00:25:33Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added a read-only root Mix environment probe for `Mix.env()`, `MIX_ENV`, `MIX_BUILD_ROOT`, `MIX_DEPS_PATH`, `HEX_HOME`, and unset `MIX_BUILD_PATH`. JOSE dependency-local `Mix.env()` is retained separately, so its observed `prod` value cannot stand in for root `test`.
- Cleanup now refuses a symlink or non-owned `.hex` target, checks physical containment, removes only the collector-owned cache, and records sanitized final Git paths after cleanup. The read-only verifier rejects unsafe cleanup and any dirty or inconsistent final-clean claim.
- Added fake-command coverage for missing/failed/forged provenance, external symlink preservation, tracked dirt, incomplete cleanup, hidden or unsanitized dirty paths, no-clobber behavior, and concurrent independent collections.
- Bound the immutable Plan 75 reports and summary into historical digests, added subject `7b7b5269f46e273760e653d3010b6b489ab91d62` to the exhausted set, and confirmed the canonical Nightly receipt remains unchanged.
- No real subject was selected and no requirement acceptance was granted; EVID-01 through EVID-04 and TRUTH-08 remain pending.

## Task Commits

1. **Task 1: Trace one valid root-environment and clean Hex collection through verification** — `c8ae2778` (TDD RED), `b152630b` (TDD GREEN).
2. **Task 2: Fail closed on unsafe cleanup and provenance substitutions** — `03daff8d` (TDD RED), `54e47bfa` (TDD GREEN).

**Plan metadata:** this summary is recorded by the plan-completion docs commit.

## Files Created/Modified

- `scripts/maintainer/phase_133_causal_evidence.sh` — records root and dependency Mix contexts separately, safely cleans owned Hex data, verifies post-cleanup cleanliness, and preserves Plan 75 history.
  - Committed helper blob: `f94e66f5967048dd32503f7c1486fcdb9cbf3e75`
- `scripts/maintainer/test_phase_133_causal_evidence.sh` — proves valid collection, unsafe and dirty cases, concurrency, no-clobber behavior, and historical immutability using fake commands.
  - Committed harness blob: `b09653ef237e59200e4fd4d611f163ae78a15368`

## Immutable Evidence

- Plan 75 report A SHA-256: `856d11337ec18675d0067763e95468039cfef97c30f91d29d4293c8b27e54daf`
- Plan 75 report B SHA-256: `2c6a1e81f9db54cf3204c7f4988882500b8c3f3af9ccfe9600f2d1a755fe7ce2`
- Plan 75 summary SHA-256: `6bf48243cc2d34728353ccb275071e18af53286379d17240fee25651ce166c9d`
- Canonical Nightly receipt SHA-256: `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`

## Decisions Made

- Root-process and dependency-local Mix environment values are separate authorities; the root process is the source for test environment claims.
- Hex cleanup is restricted to the exact owned `.hex` path after containment checks, and final Git status is captured afterward.
- Plan 75 reports and summary remain immutable inputs, and Plan 75's subject cannot be reused for a new diagnostic collection.

## Deviations from Plan

None — implemented the plan scope as written.

## Issues Encountered

- The default sandbox denied temporary Git worktree registration for the fake-only harness. The harness was run with scoped filesystem access; it invoked no real Mix or remote command.
- The first fake root probe encoded `MIX_BUILD_PATH` as the literal word `unset`; the fixture was corrected to emit an empty value for the actually unset variable, and the complete focused harness then passed.

## User Setup Required

None — no external service configuration is required.

## Next Phase Readiness

Plan 77 can perform the planned fresh independent local collection against a new exact subject. This plan selected no subject and granted no requirement credit. Plans 71, 67, and 68 remain blocked.

## Self-Check: PASSED

- Both modified collector files and all four task commits were present.
- The focused fake-command harness passed after the task commits.
- Plan 75 report and summary digests and the canonical receipt digest match their preserved values.
- EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-03*
