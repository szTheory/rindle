---
phase: 133-evidence-charter-and-live-truth
plan: 22
subsystem: ci-evidence
tags: [github-actions, exact-subject, nightly, evidence-census, reconciliation]
status: complete
requires:
  - phase: 133-18
    provides: attributable pre/post run-ID set-difference dispatch ownership
  - phase: 133-19
    provides: immutable ordered Nightly incident replay and idempotent mutation evidence
  - phase: 133-20
    provides: physically contained census detector inputs and independent reconstruction
  - phase: 133-21
    provides: exact-version package truth, distinct lifecycle evidence, and phase reconciliation
provides:
  - Rebound reviewed census ledger for the final repaired implementation subject
  - Fresh first-attempt exact-subject Nightly receipt from one uniquely attributable diagnostic dispatch
  - Automated proof that all five post-review evidence gaps are closed at one immutable subject
affects: [134, 135, 136, nightly-evidence, release-readiness]
actuals:
  tokens: 7706
  tasks: 3
  commits: 4
plan_head_before: c80d830f398b8e4ddfd8b1d58647375ab949dc6e
tech-stack:
  added: []
  patterns:
    - Publish one immutable diagnostic ref only after exact local identity and remote absence checks
    - Attribute diagnostic evidence through pre/post run-ID set difference and canonical receipt reconstruction
    - Keep pre-summary and post-summary reconciliation as separate automated truth states
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-22-SUMMARY.md
  modified:
    - .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json
    - scripts/ci/test_verify_nightly_run.sh
    - scripts/ci/verify_nightly_run.sh
    - test/install_smoke/evidence_census_test.exs
    - test/install_smoke/live_truth_parity_test.exs
    - test/install_smoke/nightly_policy_test.exs
    - test/install_smoke/phase_133_completed_validation_test.exs
key-decisions:
  - "Published only commit 1470cf8cb0f111d0b233efbf77ee69e92f25fd68 to the absent non-force ref phase-133-evidence-1470cf8cb0f1; preserved the rejected ref and run as audit evidence."
  - "Accepted only the collector-attributed first attempt run 34638437301 after exact SHA/ref/job, Dialyzer, incident-snapshot, census, and live-truth reconstruction passed."
  - "Kept Phase 133 at 21/22 throughout Task 3 and deferred the 22/22 assertion to the post-summary execution-complete gate."
patterns-established:
  - "Final evidence binding: immutable census subject -> unique non-force ref -> one new dispatch ID -> canonical receipt."
  - "Diagnostic topology: all eleven workflow_dispatch jobs are required; only the two schedule-only incident jobs may be skipped."
requirements-completed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: "The reviewed census reconstructs from physically contained detector inputs at the final repaired implementation subject."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "test/install_smoke/evidence_census_test.exs and detached repository hygiene gate"
        status: pass
    human_judgment: false
  - id: D2
    description: "The final evidence collector preserves explicit unclassified states and attributes one new diagnostic run by run-ID set difference."
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "scripts/ci/test_verify_nightly_run.sh (130 passed) and run 34638437301 receipt verification"
        status: pass
    human_judgment: false
  - id: D3
    description: "The Nightly receipt proves authenticated immutable incident evidence and the complete eleven-job diagnostic topology."
    requirement: EVID-03
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_incident.sh (15 passed) and scripts/ci/test_nightly_summary_gate.sh (49 passed)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Three-overlap replay, repeated replay, and green-with-no-incident behavior converge idempotently without mutating the preserved incident snapshot."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_incident.sh#three-overlap/replay/no-op matrix and receipt incident_before == incident_after"
        status: pass
    human_judgment: false
  - id: D5
    description: "Exact-subject live truth uses independent version authority and distinct smoke/lifecycle evidence while preserving release boundaries."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs and canonical receipt local-authority reconstruction"
        status: pass
    human_judgment: false
metrics:
  duration: 26m
  completed: 2026-09-11
---

# Phase 133 Plan 22: Final Exact-Subject Evidence Summary

**A uniquely attributable green Nightly run now binds the repaired census, supported Dialyzer lifecycle, incident replay, and package truth to one immutable subject.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-09-11T19:15:08Z
- **Completed:** 2026-09-11T19:40:36Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Rebound the reviewed census to the clean final repair subject with contained-input and transition reconciliation intact.
- Published exactly one authorized non-force diagnostic ref and attributed fresh run `34638437301` through the collector's pre/post run-ID set difference.
- Replaced the obsolete Nightly receipt with canonical first-attempt evidence for all eleven jobs, supported Elixir 1.17 / OTP 27 fresh-and-restored Dialyzer paths, unchanged incident state, and corrected live truth.
- Passed focused shell and ExUnit suites, `mix ci`, the refactor contract, exact receipt verification, detached repository hygiene, automation-first validation, and the 21/22 pre-summary reconciliation gate.

## Task Commits

1. **Task 1: Rebind the reviewed census to the final repair subject**
   - `8bcd1b2` — fixture mutation safety classification
   - `e8d8b54` — census test quality-baseline refactor
   - `c80d830` — initial final census rebind
   - `847e98d` — failing eleven-job diagnostic topology regression
   - `1470cf8` — collector support for the exact diagnostic topology
   - `78a2b94` — repaired-subject census rebind
2. **Task 2: Authorize one final exact-subject evidence ref publication** — no repository commit; the blocking-human `publish` decision authorized exactly one non-force remote ref creation.
3. **Task 3: Collect and revalidate final exact-subject evidence** — `fd00a19`

## Files Created/Modified

- `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json` — immutable reviewed ledger for the repaired subject and contained detector inputs.
- `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json` — canonical exact-subject receipt for run `34638437301`, attempt 1.
- `scripts/ci/verify_nightly_run.sh` — validates the full diagnostic topology and schedule-only skipped jobs.
- `scripts/ci/test_verify_nightly_run.sh` — covers the eleven-job workflow-dispatch topology.
- `test/install_smoke/evidence_census_test.exs` — preserves census quality while exercising contained-input movement.
- `test/install_smoke/live_truth_parity_test.exs` — declares isolated fixture mutation safety.
- `test/install_smoke/phase_133_completed_validation_test.exs` — declares isolated reconciliation-tree mutation safety.
- `test/install_smoke/nightly_policy_test.exs` — restores formatter compliance in the Nightly policy contract.

## Decisions Made

- The user-authorized publication was restricted to `1470cf8cb0f111d0b233efbf77ee69e92f25fd68:refs/heads/phase-133-evidence-1470cf8cb0f1`, after immediate local identity and remote-absence verification.
- Rejected ref `phase-133-evidence-e8d8b54b289b` and run `34633633664` remain untouched as audit evidence.
- The replacement receipt was accepted only after canonical local reconstruction and independent remote preflight matched the exact subject; the authorization itself satisfied no acceptance criterion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Classified isolated fixture mutations for the async-safety gate**
- **Found during:** Task 1
- **Issue:** Two tests used unique temporary roots safely but lacked the explicit mutation classification required by the repository-wide async-safety contract.
- **Fix:** Added narrowly scoped `:file_mutation` declarations to the affected fixture modules.
- **Files modified:** `test/install_smoke/live_truth_parity_test.exs`, `test/install_smoke/phase_133_completed_validation_test.exs`
- **Verification:** Full `mix ci` passed.
- **Committed in:** `8bcd1b2`

**2. [Rule 3 - Blocking] Restored the census regression test quality baseline**
- **Found during:** Task 1
- **Issue:** The required fixture update introduced a new Credo nesting finding and blocked the repository quality gate.
- **Fix:** Extracted detector observation mapping into a behavior-preserving helper.
- **Files modified:** `test/install_smoke/evidence_census_test.exs`
- **Verification:** Credo quality and full `mix ci` passed.
- **Committed in:** `e8d8b54`

**3. [Rule 1 - Bug] Accepted the actual eleven-job diagnostic workflow topology**
- **Found during:** Task 1 tracer feedback
- **Issue:** The collector still expected ten uniformly successful jobs, but workflow dispatch emits eleven jobs and skips two schedule-only incident jobs by design.
- **Fix:** Added a failing topology regression, required all eleven job identities, and restricted skipped conclusions to the two schedule-only jobs.
- **Files modified:** `scripts/ci/test_verify_nightly_run.sh`, `scripts/ci/verify_nightly_run.sh`
- **Verification:** Collector suite passed 130/130 and canonical verification accepted run `34638437301`.
- **Committed in:** `847e98d`, `1470cf8`

**4. [Rule 3 - Blocking] Restored formatter compliance in the Nightly policy contract**
- **Found during:** Task 3
- **Issue:** `mix ci` stopped at `mix format --check-formatted` because the existing Nightly policy test lacked one formatter-required blank line.
- **Fix:** Applied the repository formatter to that file without changing behavior.
- **Files modified:** `test/install_smoke/nightly_policy_test.exs`
- **Verification:** The focused test passed 6/6 and full `mix ci` passed with 1,507 tests, 3 doctests, and zero failures.
- **Committed in:** `fd00a19`

---

**Total deviations:** 4 auto-fixed (1 Rule 1, 1 Rule 2, 2 Rule 3)
**Impact on plan:** Each change was required for exact evidence correctness or a mandated automated gate; no product scope was added.

## Issues Encountered

- The first publication command used an unsafe zsh parameter form and failed locally before contacting the remote. Remote absence was re-proved immediately, then the exact authorized refspec was pushed once successfully.
- GitHub's run-watch endpoint returned a transient rate-limit response after dispatch. No second dispatch occurred: the already-attributed run was allowed to finish, and the collector's unchanged validation/reconstruction functions resumed against run `34638437301`. The incident snapshot was independently proven unchanged across the run.
- The repository's `asdf` Elixir shim had no configured project version. Verification used the installed Homebrew Elixir 1.19.5 toolchain and the exact installed Node 20.18.1 binary path; no dependency or project configuration changed.

## Known Stubs

None.

## User Setup Required

None - no further external service configuration is required.

## Next Phase Readiness

- Plans 134-136 can consume the frozen census identities and exact-subject Nightly receipt.
- The post-summary execution-complete reconciliation gate passed at 22/22 with zero pending plans.
- Existing dependency advisories remain outside this plan and are owned by Phase 134 dependency triage.

## Self-Check: PASSED

All listed artifacts, task commits, the exact published ref, and the preserved rejected ref were verified before tracking updates.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-11*
