---
phase: 133-evidence-charter-and-live-truth
plan: "73"
subsystem: testing
tags: [elixir, mix, jose, diagnostics, ci]
requires:
  - phase: 133-evidence-charter-and-live-truth
    provides: Plan 72 A/B diagnostics, forensic report, and unchanged canonical Nightly receipt
provides:
  - Exact-subject JOSE include-path prefix report and independent CI diagnostic report
  - Bounded diagnostic helper and fake-command regression harness
affects: [plans-71-67-68, phase-133-qualification]
actuals:
  tokens: 32519
  tasks: 2
  commits: 7
tech-stack:
  added: []
  patterns:
    - Clean detached exact-SHA diagnostic worktrees with isolated Mix paths
    - No-clobber reports bound to subject SHA, tree, and separate worktree IDs
key-files:
  created:
    - scripts/maintainer/phase_133_jose_include_diagnostic.sh
    - scripts/maintainer/test_phase_133_jose_include_diagnostic.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-73-DIAGNOSTIC-A.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-73-DIAGNOSTIC-B.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-73-SUMMARY.md
  modified: []
key-decisions:
  - "Keep the JOSE path cause unresolved: no readable-local-to-missing transition occurred on this subject."
  - "Treat the missing final full-suite summary as blocked terminal evidence with zero requirement credit."
patterns-established:
  - "Diagnostic-only evidence stays bound to one immutable SHA/tree and distinct clean detached worktrees."
requirements-completed: []
status: complete
qualification: diagnostic_only
subject_sha: ebe994d09affa06b34d472b93ec37a797b2460de
subject_tree: b90401707fde08bbccd185493e5625e11f23de46
diagnostic_a: .planning/phases/133-evidence-charter-and-live-truth/133-73-DIAGNOSTIC-A.json
diagnostic_a_sha256: 23d6f37d864299bee5bbe73b844de36edd7244cb05e85f3411bb551c900c8fc5
diagnostic_b: .planning/phases/133-evidence-charter-and-live-truth/133-73-DIAGNOSTIC-B.json
diagnostic_b_sha256: f19e2d0f2900949afffe8d4f786aec074ced0a5b470cff12d6a3ee4df2169894
worktree_a: f72bb838-6d1b-4e96-b4a8-65cb762e059c
worktree_b: 9572aa01-2c91-4663-ad76-95da15831490
first_changed_boundary: none
cause: unresolved
ci_command: mix ci
ci_exit_code: 1
ci_terminal_summary_status: missing
terminal_evidence: blocked
receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
duration: 53min
completed: 2026-10-02
---

# Phase 133 Plan 73: JOSE include-path diagnostics

**The exact-subject prefix stayed source-backed, while the independent full CI run still ended before a terminal suite summary.**

## Performance

- **Duration:** about 53 minutes
- **Started:** 2026-10-02T22:09:00-04:00
- **Completed:** 2026-10-02T23:01:00-04:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a bounded JOSE staged-include probe, read-only report and summary verifiers, and a fake-command regression harness.
- Report A bound the observations to SHA `ebe994d09affa06b34d472b93ec37a797b2460de` and tree `b90401707fde08bbccd185493e5625e11f23de46`. The source and staged header digests match. The staged include first appeared after compile as a readable internal symlink to Mix’s JOSE source include; the earlier prefix boundaries had no staged include. Since no readable-local alias later disappeared, the report records `cause: unresolved` and `no_alias_transition_observed;mix_dependency_resolved`.
- Report B used the same SHA/tree in a different clean detached worktree. Its single `mix ci` command exited 1. An earlier nested run reported `97 tests, 0 failures`; `Rindle.DoctorThresholdsTest` then failed in `setup_all` with a `FunctionClauseError` in `Doctor.ModuleInformation.build/2` for `{:error, :module_not_found}` on `Mix.Tasks.Rindle.AbortIncompleteUploads`. No final full-suite summary was present, so `terminal_evidence` remains blocked.
- Kept the Nightly receipt SHA-256 unchanged at `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`. EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending; this plan grants zero requirement credit.

## Task Commits

1. **Task 1: Trace the JOSE staged-include transition** — `c9f80b18`, `c9a50135`, `01015e66`, `ebe994d0`, `43537e32`.
2. **Task 2: Collect independent CI evidence** — `654b70ff`.

The plan summary is committed as the closeout commit after verification.

## Files Created/Modified

- `scripts/maintainer/phase_133_jose_include_diagnostic.sh` — exact-subject prefix and CI collectors with read-only verifiers.
- `scripts/maintainer/test_phase_133_jose_include_diagnostic.sh` — fake-command and path-provenance contract.
- `133-73-DIAGNOSTIC-A.json` — prefix snapshots and unresolved path-transition classification.
- `133-73-DIAGNOSTIC-B.json` — separate `mix ci` exit, nested summary, Doctor setup failure, and missing terminal summary.
- `133-73-SUMMARY.md` — zero-credit result and next evidence gate.

## Decisions Made

- Preserved `cause: unresolved` because the new subject did not reproduce the earlier readable-to-missing alias transition. Mix provenance identifies the source include target after compile but does not prove why the prior subject behaved differently.
- Preserved a blocked terminal-evidence outcome because report B contains no final full-suite summary. The Doctor stack is recorded as an observed test failure, not treated as proof of the JOSE path cause or qualification evidence.
- Kept Plans 71, 67, and 68 blocked and all five requirements pending.

## Deviations from Plan

The helper and harness needed three small implementation adjustments before subject selection: make the harness's Node executable available in its fake-command PATH, retain sanitized Git worktree setup errors, and use a stable transient directory base for subject worktrees. Each adjustment was committed before the final subject SHA was selected, and the harness passed against the final helper.

## Issues Encountered

The independent `mix ci` command ended after the nested `97 tests, 0 failures` output and the `DoctorThresholdsTest` setup failure, without a final full-suite summary. The exact JOSE alias loss seen in the earlier follow-up was not reproduced on this subject. Both are recorded as evidence gaps; no source repair or qualification run was performed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plans 71, 67, and 68 remain blocked. A separately planned local investigation must explain why the earlier preflight boundary loses the JOSE staged include while this subject only creates the include at compile time, or capture the exact absent/dangling transition with source-backed provenance. Qualification must wait for that cause-backed gate and a complete attributed full-suite terminal result.

This plan grants zero requirement credit. `requirements-completed: []`; no requirement row, roadmap, state file, Nightly receipt, qualification artifact, census, or remote service was changed.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-02*
