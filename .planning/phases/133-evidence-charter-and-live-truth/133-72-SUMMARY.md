---
phase: 133-evidence-charter-and-live-truth
plan: "72"
subsystem: ci-evidence
tags: [mix, ci, diagnostics, exact-subject]
requires: []
provides:
  - "Digest-bound comparison of Plan 69 and Plan 70 terminal CI evidence."
  - "Two independent fresh mix ci reports bound to one exact subject SHA and tree."
affects: [phase-133-diagnosis, later-ci-repair-or-qualification-planning]
actuals:
  tokens: 26615
  tasks: 2
  commits: 2
  plan_head_before: 7d2449d09a36ce4a1dbda2dffe797e2c479606ee
tech-stack:
  added: []
  patterns:
    - "Bind repeated CI evidence to an exact commit/tree and separate detached worktree IDs."
key-files:
  created:
    - scripts/maintainer/phase_133_ci_forensics.sh
    - scripts/maintainer/test_phase_133_ci_forensics.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-72-FORENSIC.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-72-DIAGNOSTIC-A.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-72-DIAGNOSTIC-B.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-72-SUMMARY.md
  modified: []
key-decisions:
  - "Keep the fresh diagnosis unresolved because both CI attempts lack a terminal summary and a Doctor setup fingerprint."
  - "Do not repair the JOSE include-path failure or begin qualification in this diagnostic-only plan."
requirements: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requirements-completed: []
qualification: diagnostic_only
remote_action: none
diagnosis: unresolved
forensic_report: .planning/phases/133-evidence-charter-and-live-truth/133-72-FORENSIC.json
diagnostic_a_report: .planning/phases/133-evidence-charter-and-live-truth/133-72-DIAGNOSTIC-A.json
diagnostic_b_report: .planning/phases/133-evidence-charter-and-live-truth/133-72-DIAGNOSTIC-B.json
forensic_sha256: 93d3521243a22eaa13157b6d3f0e6af75c86bbc8f6f42eee73892369aae6b682
diagnostic_a_sha256: 569fb28ce9b02b018c81e3ceaf1b6e32a0248b2b50df1d585d7879866f3b387c
diagnostic_b_sha256: 9ad5caa277c2c6a7dae638ddd1ded850bbe69b6fe02f392c9d00c7478b9e179e
fresh_subject_sha: 60ccc124c0b42bf8f2ee47456e6cfec839d6c299
fresh_subject_tree: cdb14d310c706ed42ea8c57a87c8311c6110adb9
coverage:
  - id: D1
    description: "Historical Plan 69 and Plan 70 evidence retains the terminal-counter distinction and unresolved cause."
    verification:
      - kind: other
        ref: "bash scripts/maintainer/test_phase_133_ci_forensics.sh"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/phase_133_ci_forensics.sh --verify-report .planning/phases/133-evidence-charter-and-live-truth/133-72-FORENSIC.json"
        status: pass
    human_judgment: false
  - id: D2
    description: "Two fresh exact-subject CI reports are bound to distinct detached worktrees and retain the missing-terminal JOSE compile failure."
    verification:
      - kind: other
        ref: "./scripts/maintainer/phase_133_ci_forensics.sh --verify-report .planning/phases/133-evidence-charter-and-live-truth/133-72-DIAGNOSTIC-A.json"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/phase_133_ci_forensics.sh --verify-report .planning/phases/133-evidence-charter-and-live-truth/133-72-DIAGNOSTIC-B.json"
        status: pass
    human_judgment: false
  - id: D3
    description: "The summary records diagnostic-only status, unchanged pending requirements, and no downstream authority."
    verification:
      - kind: other
        ref: "./scripts/maintainer/phase_133_ci_forensics.sh --verify-summary .planning/phases/133-evidence-charter-and-live-truth/133-72-SUMMARY.md"
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-10-02
status: complete
---

# Phase 133 Plan 72: Evidence Charter and Live Truth Summary

**Two fresh exact-subject `mix ci` runs failed while compiling JOSE before a terminal ExUnit summary, so Plan 69's Doctor cause remains unresolved.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-10-02T19:28:51Z
- **Completed:** 2026-10-02T19:42:54Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Compared immutable Plan 69 and Plan 70 evidence: Plan 69's nested 97/0 line is not terminal; the final `mix ci` summary was 3 doctests, 1710 tests, and 1 failure, with no recorded exception class or stack.
- Ran two fresh `mix ci` diagnostics on subject `60ccc124c0b42bf8f2ee47456e6cfec839d6c299` and tree `cdb14d310c706ed42ea8c57a87c8311c6110adb9` in distinct detached worktrees. Both supported-toolchain, dependency, and JOSE preflight checks passed; both CI commands exited 1 before a terminal summary.
- Preserved the common compiler error and left the causal diagnosis unresolved. All five requirements remain Pending; no remote action or qualification authority was used.

## Task Commits

Each task was committed atomically:

1. **Task 1: Trace preserved failure evidence into a fail-closed forensic verdict** - `60ccc124` (`feat`).
2. **Task 2: Collect two fresh CI-path diagnoses and state the next evidence gate** - `2a9a1822` (`feat`).

**Plan metadata:** This summary is committed as the separate plan close-out commit.

## Files Created/Modified

- `scripts/maintainer/phase_133_ci_forensics.sh` - compares historical reports, captures bounded exact-subject CI evidence, and verifies reports and summaries.
- `scripts/maintainer/test_phase_133_ci_forensics.sh` - exercises terminal parsing, missing/contradictory outcomes, redaction, no-clobber behavior, subject guards, and read-only verifiers.
- `.planning/phases/133-evidence-charter-and-live-truth/133-72-FORENSIC.json` - records the historical terminal-counter discrepancy and unresolved cause.
- `.planning/phases/133-evidence-charter-and-live-truth/133-72-DIAGNOSTIC-A.json` and `133-72-DIAGNOSTIC-B.json` - bind the two fresh CI attempts to the same subject and distinct worktrees.
- `.planning/phases/133-evidence-charter-and-live-truth/133-72-SUMMARY.md` - records the zero-credit diagnosis and next evidence gate.

## Decisions Made

- Keep the diagnosis unresolved: neither fresh report contains a Doctor `setup_all` fingerprint.
- Treat the repeated `jose_jwt.hrl` `:enoent` compile failure as a new observed blocker requiring a separately planned diagnostic. Do not run suggested dependency repair commands or qualification gates from this plan.
- Preserve EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 as Pending.

## Post-review hardening

- Bound every historical source and receipt path in summary verification to its expected repository-relative artifact before reading it.
- Permit reports stopped at the unsupported-toolchain gate only when no dependency, JOSE preflight, or CI command started; those reports remain verifiable as `preflight_blocked`.
- Preserve a registered diagnostic worktree if Git cannot remove it, and remove raw logs separately.
- Give the harness a unique `mktemp` output directory and add regression cases for traversal, preflight-blocked evidence, and failed worktree removal.
- Require a failed terminal CI result before classifying a complete Doctor fingerprint as a reproduced failure; bind top-level report status and setup-stage fields to the validated CI path.
- Route summary verification through the full report verifier for the forensic report and both diagnostics; keep one summary-verification implementation.
- Keep only parsed terminal-counter text in fresh diagnostic reports, redact credentials and full private path suffixes in historical counter lines, and bind any top-level Doctor fingerprint to its matching complete failure block.
- Verification: the focused fake-command harness passed with live and historical credential/path canaries and a fabricated-fingerprint rejection; the forensic report, both diagnostic reports, and summary passed their read-only verifiers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Keep the fake harness on the installed Node executable**
- **Found during:** Task 1 (forensic harness).
- **Issue:** The fake `asdf` command intercepted the Node shim used by the helper, preventing the output-path guard from running.
- **Fix:** Added the installed Node executable to the harness command path.
- **Files modified:** `scripts/maintainer/test_phase_133_ci_forensics.sh`.
- **Verification:** The full fake-command harness passed.
- **Committed in:** `60ccc124`.

**2. [Rule 1 - Bug] Expose acceptance-query terminal and nested fields**
- **Found during:** Task 1 (forensic report verification).
- **Issue:** The report kept Plan 69's exit, nested summary, and terminal summary only under `plan69.ci`, while the plan's acceptance query reads `plan69.ci_exit_code`, `plan69.nested`, and `plan69.terminal`.
- **Fix:** Added deterministic aliases and kept them bound to the detailed `plan69.ci` evidence during report regeneration.
- **Files modified:** `scripts/maintainer/phase_133_ci_forensics.sh`, `scripts/maintainer/test_phase_133_ci_forensics.sh`, and `133-72-FORENSIC.json`.
- **Verification:** The acceptance `jq`, report verifier, and full fake-command harness passed.
- **Committed in:** `60ccc124`.

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 3 blocking harness issue).
**Impact:** Both fixes were necessary to satisfy the specified executable checks; no repair or qualification scope was added.

## Issues Encountered

Both independent `mix ci` attempts exited 1 with no terminal test summary. Their bounded output agrees:

`== Compilation error in file lib/jose/jwt.ex ==`

`** (RuntimeError) error parsing file <diagnostic-worktree>/_build/test/lib/jose/include/jose_jwt.hrl, got: {:error, :enoent}`

Neither report has a Doctor failure fingerprint. The missing include file explains the observed compile stop but does not establish the cause of Plan 69's Doctor setup failure. No suggested dependency clean/update/compile command was run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 72 closes with `diagnosis: unresolved` and zero requirement credit. A separately planned local diagnostic must establish why the locked JOSE JWT header is absent from the detached test build path and produce complete terminal CI evidence before any cause-backed Doctor repair plan or qualification can be considered. Plans 71, 67, and 68 remain blocked.

Qualification is diagnostic-only.

Plans 71, 67, and 68 remain blocked.

No downstream handoff, repair, or qualification authority is issued.

## Self-Check: PASSED

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-02*
