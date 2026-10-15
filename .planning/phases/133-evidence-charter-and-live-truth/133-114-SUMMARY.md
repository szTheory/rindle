---
phase: 133-evidence-charter-and-live-truth
plan: 114
subsystem: testing
tags: [recovery, provenance, sandbox-exec, mix, lexbor]

# Dependency graph
requires:
  - phase: 133-108
    provides: [halted native qualification findings, missing pinned Lexbor input, unproved macOS network denial]
provides:
  - Plan 115 durable offline supply verification and source-bound one-shot Lexbor authorization gate
  - Actual macOS allow/deny proof required before Mix or native child execution
  - Exact Plan 116-118 authority, candidate, and transaction validators with copied-tree regressions
affects: [133-115, 133-116, 133-117, 133-118, phase-133-local-gates]

# Actuals measured from the realized plan diff, chars/4.
actuals:
  tokens: 28096
  tasks: 3
  commits: 5
  plan_head_before: 0b509f1feb62234f4cbffac89870d3b8a7151a19
  plan_head_after: 33d2db3914053dfa68cf3dba9ea2fe1bda290132

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Rehash durable supply bytes and bind every use to the exact source SHA/tree.
    - Require a positive macOS policy-denial witness before guarded Mix/native children.
    - Keep recovery artifacts read-only and zero-credit until later independent qualification.

key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-114-GUARD-PROOF.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-114-TASK1-TDD-RED-EVIDENCE.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-114-TASK2-TDD-RED-EVIDENCE.json
  modified:
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/phase_133_local_supply.test.mjs
    - scripts/maintainer/phase_133_recovery.mjs
    - scripts/maintainer/phase_133_recovery.test.mjs
    - scripts/maintainer/test_phase_133_local_gates.sh
    - scripts/maintainer/test_phase_133_local_supply.sh
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - test/install_smoke/phase_133_reconciliation_test.exs

key-decisions:
  - Plan 115 has a distinct identity and does not reinterpret historical Plan 104, 105, or 108 reports.
  - The durable manifest binds and rechecks the source tree, 67 lock-authenticated archives, Vix asset, and pinned Lexbor files; staging reads only those bytes.
  - A macOS guard is available only after an allowed control and loopback denial with an EPERM or EACCES witness; startup exit 71 remains a zero-credit stop.
  - Lexbor fetch requires the literal one-shot Plan 115 answer and matching preflight digest, source, URL, commit, and destination. No real fetch or qualification was run.
  - The declared requirement IDs are copied here per the plan-summary contract; REQUIREMENTS.md remains Pending for all five IDs, and this plan grants no qualification credit.

requirements-completed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: Durable lock-authenticated archive, Vix, and Lexbor bytes survive disposable-worktree cleanup and are revalidated before offline staging.
    verification:
      - kind: unit
        ref: node --test scripts/maintainer/phase_133_recovery.test.mjs
        status: pass
      - kind: integration
        ref: bash scripts/maintainer/test_phase_133_local_supply.sh
        status: pass
    human_judgment: false
  - id: D2
    description: The actual macOS launcher proves an allowed control and a policy-denied loopback child before guarded build work.
    verification:
      - kind: other
        ref: node scripts/maintainer/phase_133_recovery.mjs guard --actual-host
        status: pass
    human_judgment: false
  - id: D3
    description: Plan 116-118 production validators bind exact upstream artifacts and preserve pending or journaled state in copied trees.
    verification:
      - kind: unit
        ref: ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0
        status: pass
    human_judgment: false
  - id: D4
    description: Local-gates refuses to start Mix without the Plan 115 durable manifest and requires the proven guard for child execution.
    verification:
      - kind: integration
        ref: bash scripts/maintainer/test_phase_133_local_gates.sh
        status: pass
    human_judgment: false

# Metrics
duration: 68min
completed: 2026-10-07
status: complete
---

# Phase 133 Plan 114: Evidence Charter and Live Truth Summary

**Plan 115 now has durable, revalidated offline inputs and source-bound recovery gates, while Plan 116-118 validators preserve zero-credit pending state.**

## Performance

- **Duration:** 68 min
- **Started:** 2026-10-07T21:12:35Z
- **Completed:** 2026-10-07T22:20:40Z
- **Tasks:** 3
- **Files modified or created:** 12

## Accomplishments

- Added a separate Plan 115 durable supply path under the physical main checkout. Its manifest binds the source SHA/tree, lock-authenticated archives, Vix asset, pinned Lexbor tree, profile, and all file hashes; the verifier rechecks actual bytes after the disposable worktree is deleted.
- Added offline archive/native staging and made local-gates require Plan 115’s manifest. Native and Mix children run only after the exact macOS launcher/profile proves an allowed child and loopback denial with an EPERM witness.
- Added preflight, prerequisite, authorization, qualification, and fetch-lexbor modes. The one-shot fetch gate binds the literal Plan 115 answer to the exact source, preflight digest, Lexbor URL, commit, and destination. No fetch or qualification was performed.
- Added Plan 116-118 production validation modes and copied-tree coverage for upstream digests, remote decision/candidate binding, and preterminal, provisional, restored, and terminal journal states.
- Restored immutable Plan 64 authority bytes in Plan 64/79 fixtures, preserved their strict historical digest checks, and repaired the fixture append boundary so later Plan 81 evidence does not change the Plan 64 section hash.
- Preserved all five REQUIREMENTS.md statuses as Pending and issued no qualification credit.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Prove durable supply regression** — fae19bca (test)
2. **Task 1 GREEN: Preserve authenticated supply across worktree cleanup** — 8eaa48b3 (feat)
3. **Task 2 RED: Require positive macOS guard denial witness** — 2668a298 (test)
4. **Task 2 GREEN: Gate native work on proven macOS denial** — f6f33a6b (feat)
5. **Task 3: Seal Plan 115-118 recovery gates** — 33d2db39 (feat)

**Plan metadata:** committed after this summary is written.

## TDD Gate Compliance

- Task 1 has a machine-checked RED record, a test-only commit, then a GREEN implementation commit.
- Task 2 has a machine-checked RED record, a test-only commit, then a GREEN implementation commit.
- The Task 1 tracer verification passed before expansion; Task 2 verification passed before Task 3.

## Files Created/Modified

- .planning/phases/133-evidence-charter-and-live-truth/133-114-GUARD-PROOF.json — exact macOS launcher, profile, argv, exits, and EPERM witness.
- .planning/phases/133-evidence-charter-and-live-truth/133-114-TASK1-TDD-RED-EVIDENCE.json — machine-checked durable-supply RED evidence.
- .planning/phases/133-evidence-charter-and-live-truth/133-114-TASK2-TDD-RED-EVIDENCE.json — machine-checked guard RED evidence.
- scripts/maintainer/phase_133_local_gates.sh — Plan 115 offline staging and pre-Mix guard boundary.
- scripts/maintainer/phase_133_local_supply.mjs — durable bundle collection, verification, and staging support.
- scripts/maintainer/phase_133_local_supply.test.mjs — local supply containment and legacy-mode regressions.
- scripts/maintainer/phase_133_recovery.mjs — Plan 115 recovery CLI, source-bound fetch gate, and macOS guard proof.
- scripts/maintainer/phase_133_recovery.test.mjs — cleanup, substitution, authorization, startup-failure, and denial regressions.
- scripts/maintainer/test_phase_133_local_gates.sh — local-gates runner and missing-manifest regressions.
- scripts/maintainer/test_phase_133_local_supply.sh — includes the Plan 115 recovery regression suite.
- scripts/maintainer/validate_phase_133_reconciliation.exs — Plan 116-118 exact-path and zero-credit validators.
- test/install_smoke/phase_133_reconciliation_test.exs — copied-tree validator coverage and historical Plan 64/79 fixture repairs.

## Decisions Made

- Keep Plan 115 independent from historical Plan 104/105/108 report identities and authorizations.
- Treat sandbox startup failure, generic socket failure, or missing policy witness as unavailable; only positive macOS denial evidence opens the guarded child boundary.
- Keep source qualification, real Lexbor fetch, and requirement completion for later plans with their own decision and evidence.
- Leave STATE.md and ROADMAP.md to the orchestrator after merge.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Align live-state regression with the first active Plan 64 gate**
- **Found during:** Task 3 full reconciliation verification.
- **Issue:** The current live review artifact lacks the historical Plan 64 qualified heading, so validation correctly stops before reaching the later Nyquist digest assertion.
- **Fix:** Updated the regression to require the earlier missing/duplicated-authority failure, preserving its fail-closed check against the current live state.
- **Files modified:** test/install_smoke/phase_133_reconciliation_test.exs
- **Verification:** Plan 79 focused suite and the full reconciliation suite passed.
- **Committed in:** 33d2db39.

**Total deviations:** 1 auto-fixed (Rule 1 - stale regression expectation). **Impact:** No product scope change; the validator remains fail-closed.

## Issues Encountered

- The default sandbox blocked temporary Git object writes in the local-gates test fixture. Running that prescribed regression in the approved host context passed; no test or hook was bypassed.
- The initial full reconciliation baseline exposed the planned historical Plan 64/79 fixture mismatches. The fixtures now restore exact immutable authority bytes and retain strict digest and mutation checks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 115’s explicit preflight. Its Lexbor fetch remains one-shot and requires the matching literal authorization; this execution did not fetch Lexbor or run qualification. EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain Pending in REQUIREMENTS.md.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-07*

## Self-Check: PASSED

- All 12 files listed in key-files exist.
- All five task commits are present on this worktree branch.
- Evaluation scope resolved with five plan commits.
- STATE.md, ROADMAP.md, and REQUIREMENTS.md are unchanged; the five requirement statuses remain Pending.
