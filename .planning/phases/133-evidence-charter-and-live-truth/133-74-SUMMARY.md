---
phase: 133-evidence-charter-and-live-truth
plan: "74"
subsystem: ci-diagnostics
tags: [elixir, mix, jose, exunit, evidence, worktrees]

# Dependency graph
requires:
  - phase: 133-evidence-charter-and-live-truth
    provides:
      - Historical Plans 69, 72, and 73 diagnostic evidence and the current local CI gate
provides:
  - Per-call active JOSE preflight path snapshots with a fail-closed causal classification
  - Two independent full mix ci reports bound to one exact subject and tree
  - A zero-credit summary that classifies the Doctor and terminal-evidence gates
affects: [phase-133-evidence-charter-and-live-truth, local-ci, cause-backed-repair-planning]

# Actuals (#2632); tokens measure changed production/evidence diff content, excluding this summary.
actuals:
  tokens: 49748
  tasks: 2
  commits: 9
  plan_head_before: 0f58ff8be38d5b85f7c25bfdf14b4ab5c832dd0f
  plan_head_after: 1a143b8ed588a82b49661e66bb54169924fc323c

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Snapshot source and staged include paths immediately around each mutating Mix call
    - Bind diagnostic reports to helper and harness blobs in a clean detached exact-subject worktree
    - Treat nested ExUnit summaries and one-sided fingerprints as insufficient evidence

key-files:
  created:
    - scripts/maintainer/phase_133_preflight_differential.sh
    - scripts/maintainer/test_phase_133_preflight_differential.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-74-PREFLIGHT.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-74-CI-A.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-74-CI-B.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-74-SUMMARY.md
  modified: []

key-decisions:
  - "Classify the active JOSE path cause as unresolved because no readable-local-to-absent-or-dangling transition was observed."
  - "Keep the Doctor two-report gate blocked because CI-A lacks a complete fingerprint, although CI-B matches Plan 73."
  - "Classify terminal evidence as complete because both commands have final full-suite summaries, while recording both mix ci exits as failures."
  - "Retain zero requirement credit and keep Plans 71, 67, and 68 blocked."

requirements-completed: []
requirements-pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
qualification: diagnostic_only
subject_sha: f461b46433187a469b9525f6cdfb7933b3a364d9
subject_tree: 9c066d02e411c7ccef6953773742aef77a4406c0
preflight_report: .planning/phases/133-evidence-charter-and-live-truth/133-74-PREFLIGHT.json
preflight_sha256: d1a0fc4dc242ae81bcb4b12f06b48f67a66c283fbf7cded10302a951bd4eadec
ci_a_report: .planning/phases/133-evidence-charter-and-live-truth/133-74-CI-A.json
ci_a_sha256: eb31978f3309dd89812f44646e0bc4ecade127ec91f9c037731bfa97310b628b
ci_b_report: .planning/phases/133-evidence-charter-and-live-truth/133-74-CI-B.json
ci_b_sha256: a680df6f1a071724ce139eb9dd29ad0a7465420d56c3245719a1097ec831efac
canonical_receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
doctor_two_report_gate: blocked
terminal_evidence: complete
jose_cause: unresolved

# Metrics
duration: 2h 26m
completed: 2026-10-03
status: complete
---

# Phase 133 Plan 74: Evidence Charter and Live Truth Summary

**Per-call snapshots leave the active JOSE include readable; two full CI runs show terminal failures and only one complete Doctor fingerprint**

## Performance

- **Duration:** 2h 26m
- **Started:** 2026-10-03T14:14:20Z
- **Completed:** 2026-10-03T16:40:34Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added a committed active-preflight collector, fake-Mix harness, read-only verifiers, and a source-call report bound to subject `f461b46433187a469b9525f6cdfb7933b3a364d9` and tree `9c066d02e411c7ccef6953773742aef77a4406c0`.
- Captured source, staged include, and header state at each active Plan 72 preflight call and each CI-prefix boundary. The staged include remained a readable local JOSE header through the active preflight and prefix checks; the cause stays unresolved because **no readable-local-to-absent-or-dangling transition was observed**. Plan 73 remains correctly described as provenance-only and did not call `build_structure` or `compile.elixir`.
- Collected two independent `mix ci` runs from clean, distinct detached worktrees at the same subject/tree. CI-A worktree: `84ac5de5-6ea6-4ec6-af3c-448b3beb14b1`; CI-B worktree: `2b240743-3dbf-4ecf-97b7-5f4cca575c17`.
- Both reports contain a terminal full-suite summary. CI-A exited 2 with `3 doctests, 1710 tests, 8 failures, 87 excluded, 4 skipped`. CI-B exited 2 with `3 doctests, 1710 tests, 8 failures, 87 excluded, 2 invalid, 4 skipped`. Each also contains a nested `97 tests, 0 failures` line, which was not treated as the terminal result.
- CI-B contains the complete Doctor `setup_all` `FunctionClauseError` for `{:error, :module_not_found}` and `Mix.Tasks.Rindle.AbortIncompleteUploads`, and its fingerprint matches Plan 73. CI-A has no complete Doctor fingerprint, so the two-report gate remains blocked.
- Preserved canonical Nightly receipt SHA-256 `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`. All five requirements remain pending with zero requirement credit.

## Task Commits

Each task was committed atomically:

1. **Task 1: Specify the preflight diagnostic CLI (RED)** — `bb8d5dd1`
2. **Task 1: Add active preflight differential diagnostics** — `ebc4720c`
3. **Task 1: Improve detached-worktree diagnostics and fixture support** — `122694cd`
4. **Task 1: Assert active preflight path transitions** — `e0b3e8bd`
5. **Task 1: Encode provenance without Jason** — `4b898548`
6. **Task 1: Run the snapshot helper inside Mix** — `3eef1ed2`
7. **Task 1: Record isolated Mix environment** — `f461b464`
8. **Task 1: Record active JOSE preflight paths** — `56278e25`
9. **Task 2: Record independent full CI observations** — `1a143b8e`

**Plan metadata:** this summary is committed separately as the plan close-out.

## Files Created/Modified

- `scripts/maintainer/phase_133_preflight_differential.sh` — exact-subject collectors, path snapshots, redaction, no-clobber publication, and structural verifiers.
- `scripts/maintainer/test_phase_133_preflight_differential.sh` — fake-Mix, mutation, provenance, redaction, terminal-summary, and fail-closed fixtures.
- `133-74-PREFLIGHT.json` — active source-call and prefix-boundary report.
- `133-74-CI-A.json` — first independent full CI result.
- `133-74-CI-B.json` — second independent full CI result.
- `133-74-SUMMARY.md` — this zero-credit evidence decision.

## Decisions Made

- A causal JOSE diagnosis requires a source-backed transition at an observed call boundary; command success alone is not enough.
- A Doctor recurrence requires the same complete fingerprint in both new reports and a match to Plan 73. A fingerprint in CI-B alone does not satisfy the pair gate.
- A present terminal summary records what the full command concluded; it does not turn a failing `mix ci` into a pass.
- No requirement status, historical authority, Nightly receipt, or downstream plan was advanced.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replace the unavailable Jason encoder in the no-compile snapshot path**
- **Found during:** Task 1, active preflight instrumentation.
- **Issue:** The snapshot expression runs with `--no-compile` and cannot rely on Jason being loaded.
- **Fix:** Encode the structured provenance with the existing `Base` functions.
- **Files modified:** `scripts/maintainer/phase_133_preflight_differential.sh`, `scripts/maintainer/test_phase_133_preflight_differential.sh`.
- **Verification:** Fake-Mix harness and both report verification paths passed.
- **Committed in:** `4b898548`.

**2. [Rule 3 - Blocking] Execute the Bash snapshot helper directly**
- **Found during:** Task 1, active preflight instrumentation.
- **Issue:** Passing the Bash collector to `node` made Node parse shell source and exit 1.
- **Fix:** Invoke the committed executable helper directly from `System.cmd`.
- **Files modified:** `scripts/maintainer/phase_133_preflight_differential.sh`, `scripts/maintainer/test_phase_133_preflight_differential.sh`.
- **Verification:** Fake-Mix harness and active preflight report verification passed.
- **Committed in:** `3eef1ed2`.

**Total deviations:** 2 auto-fixed (2 Rule 3 blocking instrumentation fixes).  
**Impact on plan:** Both fixes were necessary to collect the planned source-backed evidence; they added no external dependency or qualification authority.

## Issues Encountered

- Both full `mix ci` runs exited 2 with eight failures. The reports include the planning-path hygiene failure and seven Plan 64 reconciliation fixture failures caused by the Plan 64 review section/prefix validation. CI-B also contains the complete Doctor setup failure and two invalidated tests. These remain diagnostic findings; no source repair was made.
- The active JOSE path report did not observe a transition, and CI-A did not contain a complete Doctor block. These are explicit unresolved evidence gates, not inferred causes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 74's diagnostic work is complete without qualifying a candidate or closing requirements. The JOSE cause remains unresolved, and CI-A lacks the complete Doctor fingerprint needed to pair with CI-B and Plan 73. **Plans 71, 67, and 68 remain blocked.** A separately planned causal evidence pass must establish the JOSE path transition and a complete same-subject Doctor fingerprint pair before any cause-backed repair or qualification. All five requirements remain pending with zero requirement credit.

## Self-Check: PASSED

All six task output files exist, and all nine task commits are present in the worktree history.
