---
phase: 133-evidence-charter-and-live-truth
plan: "40"
subsystem: testing
tags: [evidence-census, exact-subject, nightly, reconciliation, repository-hygiene]

requires:
  - phase: 133-38
    provides: detached no-start authority execution and fail-closed collector sequencing
  - phase: 133-39
    provides: exact 42-plan lifecycle reconciliation and append-only validation ownership
provides:
  - deterministic twelve-dimension census bound to a locally qualified pre-ledger commit
  - read-only qualification of the immutable canonical Nightly receipt
  - exact absent remote-ref candidate for the separate Plan 41 authorization decision
affects: [133-41, 133-42, evidence-authorization, nightly-qualification]

actuals:
  tokens: 6443
  tasks: 2
  commits: 3
plan_head_before: 96fc13dad9eec519ad628c24660edbc43e7c6fbd

tech-stack:
  added: []
  patterns:
    - detached subject-owned authority execution with an external tracked ledger
    - complexity reduction instead of expanding the reviewed Credo baseline

key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-40-SUMMARY.md
  modified:
    - .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json
    - test/install_smoke/phase_133_reconciliation_test.exs
    - test/install_smoke/phase_133_completed_validation_test.exs

key-decisions:
  - "Kept the canonical Plan 37 receipt and all exhausted histories byte-identical while qualifying a distinct local subject."
  - "Reduced two Plan 39 test-helper complexity findings rather than raising the reviewed removal-only baseline, then rebound the census to the repaired commit."
  - "Kept all five Phase 133 requirements pending because only terminal Plan 42 automation may grant completion credit."

patterns-established:
  - "Exact-subject freeze: every tracked change after the subject commit is confined to the census ledger."
  - "Authorization separation: local green evidence may identify an absent ref but cannot publish it or complete requirements."

requirements-completed: []

coverage:
  - id: D1
    description: Deterministic census covers twelve dimensions and assigns one disposition to every candidate at the exact subject.
    requirement: EVID-01
    verification:
      - kind: unit
        ref: mix test test/install_smoke/evidence_census_test.exs --seed 0
        status: pass
      - kind: integration
        ref: two detached evidence_census.exs generations plus validate_evidence_census.exs
        status: pass
    human_judgment: false
  - id: D2
    description: Nightly PLT, strict-summary, incident, package, release, adoption, and reconciliation authorities pass locally.
    requirement: EVID-02
    verification:
      - kind: integration
        ref: four scripts/ci shell harnesses plus the eight-file focused ExUnit suite
        status: pass
      - kind: integration
        ref: mix ci && mix refactor_contract
        status: pass
    human_judgment: false
  - id: D3
    description: The immutable canonical receipt still verifies against its exact live repository, workflow, ref, SHA, and run.
    requirement: EVID-03
    verification:
      - kind: integration
        ref: scripts/ci/verify_nightly_run.sh verify-receipt for run 34638437301
        status: pass
    human_judgment: false
  - id: D4
    description: Reconciliation and automation-first preserve halted incident history without granting completion credit.
    requirement: EVID-04
    verification:
      - kind: integration
        ref: validate_phase_133_reconciliation.exs --root . && automation_first_contract.sh
        status: pass
    human_judgment: false
  - id: D5
    description: The exact subject passes detached repository hygiene and its derived remote ref is absent through a read-only lookup.
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: detached repo_hygiene_check.sh plus git ls-remote --heads origin refs/heads/phase-133-evidence-c83f61379ad5
        status: pass
    human_judgment: false

duration: 32m 15s
completed: 2026-09-13
status: complete
---

# Phase 133 Plan 40: Exact-Subject Local Qualification Summary

**A deterministic twelve-dimension census is bound to quality-green subject `c83f61379ad5033efef9afa7b5bc88913080bae2`, with complete local/read-only qualification and no remote or canonical mutation.**

## Performance

- **Duration:** 32m 15s
- **Started:** 2026-09-13T14:27:37Z
- **Completed:** 2026-09-13T14:59:52Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Bound all 12 candidates across all 12 taxonomy dimensions to exact subject `c83f61379ad5033efef9afa7b5bc88913080bae2`: 9 `fix`, 3 `retain`, and no untriggered `defer` dispositions.
- Generated two byte-identical 11,004-byte detached census receipts with SHA-256 `744579300dd0d0f9d0b8ccf5328b29e3c79777dd23a39f36c31980305dbce1c8`; both subject-owned validators passed.
- Qualified the local shell, focused ExUnit, full CI, refactor, reconciliation, automation-first, live receipt, and detached hygiene authorities.
- Proved `refs/heads/phase-133-evidence-c83f61379ad5` absent through a successful read-only lookup and performed no publication, dispatch, incident, or requirement mutation.

## Task Commits

1. **Task 1: Generate and validate the new exact-subject census twice** — `83bdf63b` (initial census binding) and `1bebea9a` (final binding after the Task 2 blocking repair)
2. **Task 2: Run the complete local and read-only qualification matrix** — `c83f6137` (blocking quality repair; qualification itself changed no additional tracked files)

## Files Created/Modified

- `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json` — Binds the final quality-green exact subject, current detector observations, dispositions, and transition records.
- `test/install_smoke/phase_133_reconciliation_test.exs` — Splits fixture-summary dispatch into low-complexity helpers without changing lifecycle coverage.
- `test/install_smoke/phase_133_completed_validation_test.exs` — Flattens closure-record construction while retaining all 26 exact mapping assertions.
- `.planning/phases/133-evidence-charter-and-live-truth/133-40-SUMMARY.md` — Records exact identities, digests, qualification results, and authorization boundary.

## Decisions Made

- The first census binding to `96fc13da…` was superseded after `mix ci` exposed two unreviewed Plan 39 test-helper complexity findings. The findings were removed without widening the baseline, and the census was rebound to the repair commit so only the final census separates the qualified subject from completion.
- The prior canonical receipt remains the sole live authority until Plan 42. Its SHA-256 stayed `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`, and live verification reconfirmed subject `1470cf8cb0f111d0b233efbf77ee69e92f25fd68`, ref `phase-133-evidence-1470cf8cb0f1`, run `34638437301`, attempt 1.
- EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending. Plan 40 supplies qualification evidence but cannot grant terminal completion credit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Restored the reviewed Credo complexity inventory before freezing the final subject**

- **Found during:** Task 2 full `mix ci` qualification
- **Issue:** Two test helpers introduced by Plan 39 exceeded the reviewed thresholds, so `mix credo_quality` reported a stale identity multiset and blocked the required quality lane.
- **Fix:** Extracted small fixture-dispatch and closure-record helpers, eliminating both findings without changing the baseline or test behavior; then rebound the census to that repair commit.
- **Files modified:** `test/install_smoke/phase_133_reconciliation_test.exs`, `test/install_smoke/phase_133_completed_validation_test.exs`, `133-EVIDENCE-CENSUS.json`
- **Verification:** 45 reconciliation tests, `mix credo_quality`, the final 179-test focused matrix, `mix ci`, and detached census generation all passed.
- **Committed in:** `c83f6137`, `1bebea9a`

**2. [Rule 1 - Bug] Corrected argument order in the extracted Regex helper**

- **Found during:** Task 2 repair verification
- **Issue:** The first extraction piped the verification body into `Regex.scan/3` in the wrong argument position.
- **Fix:** Passed the regular expression first and the verification body second.
- **Files modified:** `test/install_smoke/phase_133_completed_validation_test.exs`
- **Verification:** The combined 45-test reconciliation suite passed with zero failures.
- **Committed in:** `c83f6137`

**3. [Rule 3 - Blocking] Refreshed the existing supported-toolchain build cache**

- **Found during:** Task 1 detached census generation
- **Issue:** A stale shared development `Jason` BEAM was incompatible with the selected OTP 27 runtime, preventing the subject-owned scripts from loading.
- **Fix:** Recompiled the already-locked dependency and project cache under Elixir 1.17.3 / OTP 27.3.4.15; no dependency or tracked source changed.
- **Files modified:** None (generated build cache only)
- **Verification:** Both detached generations and validators passed twice, including the tracer feedback rerun.

**4. [Rule 1 - Bug] Corrected halted-plan bookkeeping after the generic roadmap updater**

- **Found during:** Final tracking update
- **Issue:** The generic roadmap updater counted the three immutable halted summaries as completed checkboxes and emitted inconsistent completed/pending prose.
- **Fix:** Restored Plans 27, 32, and 37 to unchecked halted history while retaining the correct 40/42 summarized progress and Plan 40 completion.
- **Files modified:** `.planning/ROADMAP.md`
- **Verification:** Live Phase 133 reconciliation passed at the exact post-Plan-40 lifecycle state.

**Total deviations:** 4 auto-fixed (2 Rule 1, 2 Rule 3).
**Impact on plan:** The final subject remains an immutable pre-census commit, only the census differs after it, and all scope prohibitions remain satisfied.

## Issues Encountered

- The repository `.tool-versions` requests Erlang 27.2, which is unavailable locally. All Mix gates used the installed supported selector Elixir 1.17.3 / OTP 27.3.4.15. An expired local Hex authentication session emitted a warning during dependency audit, but the public locked-dependency resolution and all gates completed successfully.
- `mix ci` reported existing dependency advisories already assigned to Phase 134; no dependency mutation was authorized in this plan.

## Verification Results

- Shell authority harnesses — PASS: collector 163/0, incident 17/0, strict summary 49/0, Nightly Dialyzer 34/0.
- Focused Phase 133 matrix — PASS: 179 tests, 0 failures, 17 excluded.
- `mix ci` — PASS: 97 contract tests plus 3 doctests and 1,626 default-suite tests, 0 failures; four existing conditional skips did not replace any Plan 40 authority.
- `mix refactor_contract` — PASS: 97 tests, 0 failures.
- Live reconciliation and automation-first — PASS: 36 completed, 3 halted, 3 pending, 39/42 summarized, 27 selected validation records before Plan 40 summary bookkeeping.
- Canonical receipt verification — PASS for run `34638437301`, attempt 1; digest unchanged at `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`.
- Detached subject hygiene — PASS: 11 PASS, 1 WARN (local `main` ahead of `origin/main`), 0 BLOCK.
- Derived ref lookup — PASS: `phase-133-evidence-c83f61379ad5` is absent.

## TDD Gate Compliance

The plan tasks were marked `tdd="true"`, but the centralized behavior-adding predicate returned false because the planned tracked output was the census ledger rather than non-test source. The blocking repair was a behavior-preserving test-only refactor driven by the failing `mix ci` quality gate; its focused tests and Credo gate passed before commit. No product behavior was added without RED evidence.

## Known Stubs

None.

## Threat Flags

None. No endpoint, authentication path, schema, package, file-access trust boundary, or mutation capability was added. Exact-subject, receipt-spoofing, exhausted-history, and bounded-read mitigations all passed.

## User Setup Required

None.

## Requirements Status

EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending. Their checkbox and traceability rows were not changed.

## Next Phase Readiness

- Plan 41 can present the single exact authorization decision for subject `c83f61379ad5033efef9afa7b5bc88913080bae2` and absent ref `phase-133-evidence-c83f61379ad5`.
- Plan 42 remains the sole terminal path that may publish once, qualify a fresh exact run, promote a receipt, and complete the five requirements.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-13*

## Self-Check: PASSED

- Verified the census, both refactored test files, and this summary exist.
- Verified commits `83bdf63b`, `c83f6137`, and `1bebea9a` exist.
- Verified the final census names subject `c83f61379ad5033efef9afa7b5bc88913080bae2` with 12 taxonomy dimensions and 12 candidates.
