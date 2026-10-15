---
phase: 133-evidence-charter-and-live-truth
plan: 20
subsystem: evidence-integrity
tags: [elixir, filesystem, symlink-containment, provenance, tdd]

requires:
  - phase: 133-17
    provides: independently validated census authority and immutable exact-subject receipt reconstruction
provides:
  - Detector inputs are physically contained beneath the inspected repository before producer reads and hashes
  - The independent validator separately rejects external-target and post-receipt symlink substitutions
  - Bounded regression coverage for escaped, dangling, looping, root, directory, and valid contained inputs
affects: [133-evidence-charter-and-live-truth, evidence-census, exact-head-readiness]

actuals:
  tokens: 3242
  tasks: 2
  commits: 4
plan_head_before: d26208e4b5d83d410239adc757a9c38123d6f20f

tech-stack:
  added: []
  patterns:
    - component-wise physical path resolution before filesystem reads
    - independent producer and validator provenance boundaries

key-files:
  created: []
  modified:
    - scripts/maintainer/evidence_census.exs
    - scripts/maintainer/validate_evidence_census.exs
    - test/install_smoke/evidence_census_test.exs

key-decisions:
  - "Resolve the explicit repository root physically as well as each detector input so platform aliases such as /var -> /private/var preserve valid containment."
  - "Keep validator path resolution independent from producer logic so matching outputs cannot substitute for provenance reconstruction."

patterns-established:
  - "Contained input read: validate lexical spelling, resolve every physical component, require a regular file beneath the physical root, then read bytes."
  - "Receipt identity remains the original repository-relative path while the digest covers bytes read only from the validated resolved object."

requirements-completed: [EVID-01]

coverage:
  - id: D1
    description: "The census producer rejects escaped or invalid detector inputs before reading or emitting a receipt while preserving contained input identity and order."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "mix test test/install_smoke/evidence_census_test.exs#collector detector input containment cases"
        status: pass
    human_judgment: false
  - id: D2
    description: "The independent validator rejects self-consistent external evidence and same-byte post-generation symlink substitution before digest comparison."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "mix test test/install_smoke/evidence_census_test.exs#validator provenance substitution cases"
        status: pass
      - kind: other
        ref: "mix format --check-formatted scripts/maintainer/evidence_census.exs scripts/maintainer/validate_evidence_census.exs test/install_smoke/evidence_census_test.exs"
        status: pass
    human_judgment: false

duration: 2h 13m
completed: 2026-09-11
status: complete
---

# Phase 133 Plan 20: Detector Input Physical Provenance Summary

**Census producer and validator now independently resolve detector inputs to regular files beneath the physical repository root before reading or hashing any bytes.**

## Performance

- **Duration:** 2h 13m (including protected-branch handoff pause)
- **Started:** 2026-09-11T15:07:00Z
- **Completed:** 2026-09-11T17:20:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a producer-side component resolver that fails closed on direct and nested external symlinks, dangling links, loops, directories, the repository root, traversal, and absolute inputs before `File.read/1`.
- Added a separate validator-side resolver that rejects forged receipt/ledger agreement over external bytes and same-byte post-receipt symlink replacement.
- Preserved the existing repository-relative input identity, SHA-256 byte contract, canonical detector/path ordering, taxonomy, candidate, disposition, and transition semantics.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 1 RED: producer containment regressions** - `a880bdb` (test)
2. **Task 1 GREEN: contained producer input reads** - `b21cfe5` (feat)
3. **Task 2 RED: validator provenance substitutions** - `d45e8d0` (test)
4. **Task 2 GREEN: independent validator containment** - `07e7f9d` (feat)

## Files Created/Modified

- `scripts/maintainer/evidence_census.exs` - resolves and validates physical detector-input ownership before producer reads.
- `scripts/maintainer/validate_evidence_census.exs` - independently reconstructs the same physical provenance boundary before digest comparison.
- `test/install_smoke/evidence_census_test.exs` - covers producer invalid shapes, contained symlinks, forged external receipts, and post-generation substitution.
- `.planning/WINDOWS.md` - records the resolved physical-root alias deviation.

## Decisions Made

- The physical root is canonicalized through the same component resolver before containment comparison. This handles operating-system path aliases without widening the allowed boundary.
- Producer and validator retain separate implementations. Shared output or shared validation status cannot authenticate provenance at the validator boundary.
- Error text names only the repository-relative input and a bounded failure class; resolved external targets are not disclosed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Canonicalized the repository root before physical containment comparison**

- **Found during:** Task 1 GREEN verification
- **Issue:** macOS temporary roots use the lexical `/var` alias while component resolution yields `/private/var`, causing valid fixture inputs to appear outside the root.
- **Fix:** Resolve the explicit root through the physical component resolver before comparing the final input path.
- **Files modified:** `scripts/maintainer/evidence_census.exs`
- **Verification:** Focused suite passed all 20 cases, including regular and contained-symlink inputs.
- **Committed in:** `b21cfe5`

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug).
**Impact on plan:** The fix is required for portable correctness and does not widen scope or alter receipt semantics.

## Issues Encountered

- The repository-pinned Elixir 1.17.3/OTP 27 toolchain is not installed locally. Verification used the established installed diagnostic toolchain Elixir 1.19.5/OTP 28.4.1; the phase's supported-cell authority remains the exact-run evidence owned by Plan 07.
- Initial execution paused at the mandatory protected-branch guard. The orchestrator created `gsd/phase-133-evidence-charter-and-live-truth` from the same HEAD, preserving the RED edit before commits resumed.

## TDD Gate Compliance

- **Task 1 RED:** `RED_EVIDENCE_OK`; the external detector-input symlink was followed and rejected only later as an observation path.
- **Task 1 GREEN:** all 18 then-current focused cases passed after producer containment.
- **Task 2 RED:** `RED_EVIDENCE_OK`; the independent validator accepted a forged self-consistent external input receipt.
- **Task 2 GREEN:** all 20 focused cases passed after validator containment.
- **REFACTOR:** No separate refactor commit; the minimal GREEN implementations remained direct and independently owned.

## Verification Results

- `mix test test/install_smoke/evidence_census_test.exs` — 20 tests, 0 failures.
- `mix format --check-formatted scripts/maintainer/evidence_census.exs scripts/maintainer/validate_evidence_census.exs test/install_smoke/evidence_census_test.exs` — exit 0.
- Stub/skip scan over the three implementation files found no new stubs, TODOs, FIXMEs, or skipped tests.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The census detector-input provenance gap from `133-VERIFICATION.md` is closed under D-01 through D-04.
- Ready for Plan 133-21; the remaining Phase 133 verification gaps are outside this plan's ownership.

## Self-Check: PASSED

- All three modified implementation/test files exist.
- All four task commits are present in Git history in RED -> GREEN order for both tasks.
- Final committed-state verification passed: 20 tests, 0 failures, with canonical formatting.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-11*
