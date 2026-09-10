---
phase: 133-evidence-charter-and-live-truth
plan: "03"
subsystem: ci
tags: [github-actions, bash, jq, nightly, evidence]
requires:
  - phase-133-plan-02
provides:
  - Strict exact-set Nightly verdict with typed applicability and execution evidence
  - Visible repository/secret inapplicability that never claims live-provider success
  - Machine verdict exported for incident eligibility and enforced as the Nightly conclusion
affects: [phase-133-plan-04, phase-136, nightly, incident-automation]
actuals:
  tokens: 8293
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns:
    - Pure jq policy evaluator with canonical JSON verdict and downstream Markdown rendering
    - Exact declared/observed job-set equality with typed boolean applicability
    - Workflow job outputs separating applicability, execution, result, and exemption reason
key-files:
  created:
    - scripts/ci/eval_nightly_summary.sh
    - scripts/ci/test_nightly_summary_gate.sh
    - test/install_smoke/nightly_policy_test.exs
  modified:
    - .github/workflows/nightly.yml
    - .github/workflows/ci.yml
    - test/install_smoke/ci_lane_split_test.exs
key-decisions:
  - "Keep Nightly's strict policy independent from the PR aggregate's intentional skip-as-pass semantics."
  - "Allow inapplicability only under the named upstream-repository-and-required-secrets rule with one of two bounded reasons."
  - "Publish the canonical evaluator verdict before a separate unmasked enforcement step so incident consumers and the workflow conclusion share one authority."
patterns-established:
  - "Nightly evidence tuple: result, applicable, applicability_rule, execution, and reason are independently validated."
  - "False-green closure: unknown, malformed, missing, extra, failed, cancelled, and impermissibly skipped states all produce canonical red JSON and a nonzero exit."
requirements-completed: [EVID-03]
coverage:
  - id: D1
    description: "Evaluate the exact declared Nightly job set across every supported result, applicability, execution, exemption, malformed-input, and drift boundary."
    requirement: EVID-03
    verification:
      - kind: unit
        ref: "scripts/ci/test_nightly_summary_gate.sh#49-case strict truth table"
        status: pass
    human_judgment: false
  - id: D2
    description: "Make the evaluator's canonical machine verdict control Nightly conclusion and provide incident-eligible output while keeping not-run work visible."
    requirement: EVID-03
    verification:
      - kind: integration
        ref: "test/install_smoke/nightly_policy_test.exs#parsed workflow authority"
        status: pass
    human_judgment: false
duration: 13min
completed: 2026-09-09
status: complete
---

# Phase 133 Plan 03: Strict Nightly Verdict Authority Summary

**Nightly now fails closed through one canonical machine verdict while repository- and secret-gated exemptions remain visible as `not-run`, never passed live-provider evidence.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-09-10T00:38:11Z
- **Completed:** 2026-09-10T00:50:51Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added a pure Bash/jq evaluator that requires non-empty object inputs, exact declared/observed job equality, bounded GitHub result vocabulary, typed booleans, and complete applicability/execution evidence.
- Added a 49-case truth table covering supported and unknown results, every material applicability/execution boundary, missing/extra jobs, malformed/empty inputs, absent environment variables, GitHub output envelopes, and collect-all diagnostics.
- Made all four Nightly gates export applicability, rule, execution, and reason outputs; upstream or secret absence is now explicit `not-run` evidence.
- Replaced the presentation-only Nightly summary with a canonical verdict export and terminal enforcement step, while adding the shell matrix to the existing `ci-script-tests` carrier without changing `CI Summary` membership or PR aggregate semantics.

## Task Commits

Each planned task used explicit RED and GREEN commits:

1. **Task 1 RED: strict verdict matrix** - `663d38d` (test)
2. **Task 1 GREEN: pure Nightly evaluator** - `c3fe5ab` (feat)
3. **Task 2 RED: parsed workflow authority** - `28a5cea` (test)
4. **Task 2 GREEN: evidence outputs and terminal verdict** - `4673c0c` (feat)
5. **Task 2 follow-up: shell-clean output grouping** - `d14612d` (fix)

## Files Created/Modified

- `scripts/ci/eval_nightly_summary.sh` - Produces canonical green/red JSON, renders downstream Markdown, and exits from the strict policy.
- `scripts/ci/test_nightly_summary_gate.sh` - Exercises the complete strict state table and exit/verdict agreement.
- `test/install_smoke/nightly_policy_test.exs` - Parses workflow YAML and locks exact topology, outputs, applicability checks, enforcement, and CI carrier wiring.
- `.github/workflows/nightly.yml` - Publishes typed gate evidence and makes one strict verdict authoritative.
- `.github/workflows/ci.yml` - Runs the Nightly truth table in the existing merge-blocking script-test carrier.
- `test/install_smoke/ci_lane_split_test.exs` - Tracks the owned fresh/restored Dialyzer runners instead of an obsolete inline command literal.

## Decisions Made

- Nightly does not reuse `eval_ci_summary.sh`: PR skip-as-pass remains intentional for fork safety, while Nightly applies an exact, separate evidence policy.
- The only exemption rule is `upstream-repository-and-required-secrets`, with bounded `not-upstream-repository` and `required-secrets-unavailable` reasons.
- The evaluator writes verdict output before the workflow's terminal enforcement step; the final step checks both evaluator status and canonical `green`, with no `continue-on-error` path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated the stale Dialyzer topology assertion**

- **Found during:** Task 2 focused regression verification
- **Issue:** The existing lane test still required the obsolete inline `mix dialyzer` literal even though Plan 02 intentionally moved both analyses behind the owned runner.
- **Fix:** Asserted the fresh and restored runner invocations explicitly.
- **Files modified:** `test/install_smoke/ci_lane_split_test.exs`
- **Verification:** The focused 34-test ExUnit suite passed.
- **Committed in:** `4673c0c`

**2. [Rule 1 - Bug] Removed actionlint warnings introduced by workflow output writes**

- **Found during:** Task 2 final workflow lint
- **Issue:** Repeated individual redirects triggered SC2129 in each newly added evidence-output block.
- **Fix:** Grouped constant output writes behind one redirect and kept the structural contract behavior-based.
- **Files modified:** `.github/workflows/nightly.yml`, `test/install_smoke/nightly_policy_test.exs`
- **Verification:** `actionlint .github/workflows/nightly.yml` passed.
- **Committed in:** `d14612d`

---

**Total deviations:** 2 auto-fixed bugs
**Impact on plan:** Both fixes strengthened existing regression and lint authority without changing public, schema, release, or PR-gate contracts.

## Issues Encountered

- The repository's pinned Elixir 1.17.3/OTP 27.2 toolchain is not installed locally. Focused ExUnit and quality verification ran diagnostically on Elixir 1.19.5/OTP 28.4.1; scheduled Nightly remains the supported-cell authority.
- Whole-workflow `actionlint` still reports pre-existing warnings in `ci.yml`; the changed `nightly.yml` passes actionlint independently.

## Known Stubs

None.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `bash scripts/ci/test_nightly_summary_gate.sh` - 49 cases, 0 failures.
- `bash scripts/ci/test_ci_summary_gate.sh` - 6 cases, 0 failures; PR aggregate semantics preserved.
- `bash scripts/ci/test_nightly_dialyzer.sh` - 24 cases, 0 failures; Plan 02 evidence wiring preserved.
- `mix test test/install_smoke/nightly_policy_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs` - 34 tests, 0 failures on the installed diagnostic toolchain.
- `shellcheck scripts/ci/eval_nightly_summary.sh scripts/ci/test_nightly_summary_gate.sh scripts/ci/run_nightly_dialyzer.sh scripts/ci/test_nightly_dialyzer.sh` - passed.
- `actionlint .github/workflows/nightly.yml` - passed.
- `mix format --check-formatted` - passed.
- `mix quality_signals` - passed the reviewed Credo policy, documentation/spec coverage, Doctor validation, and cycle check.
- `./scripts/maintainer/automation_first_contract.sh` - passed.

## Next Phase Readiness

- Plan 04 can consume `nightly-summary.outputs.verdict` and `verdict-json` for scheduled-only rolling incident open/update/close decisions.
- Phase 136 can rely on Nightly's strict supported-cell conclusion instead of presentation-only job text.
- `ci.yml`, workflow `CI`, sole `CI Summary`, all current merge-blocking members, fork safety, and release coupling remain unchanged except for the additive shell-test step.

## TDD Gate Compliance

- RED commits precede GREEN commits for both planned tasks.

## Self-Check: PASSED

- All three declared new artifacts and all modified workflow/test files exist.
- All five task commits are present in Git history.
- Every plan-level verification passed with non-zero case/test counts.
- No known stub, deleted tracked file, unrun verification, or new threat surface outside the plan's threat register blocks the goal.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-09*
