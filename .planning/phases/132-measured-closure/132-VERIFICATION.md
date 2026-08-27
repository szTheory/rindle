---
phase: 132-measured-closure
verified: 2026-08-27T17:11:31Z
status: gaps_found
score: 2/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/3
  gaps_closed:
    - "Completed PASS state now calls verify_api_backed_receipt before it can exit successfully."
  gaps_remaining:
    - "Fresh threshold-passing exact-ten CI-14 receipt"
  regressions:
    - "Failed terminal state is reset, allowing the two-sequence ceiling to be bypassed."
    - "--max-sequences accepts values above two."
    - "A missing triggered Actions run has no creation deadline."
    - "Canonical eligible-run discovery reads only the first GitHub Actions API page."
gaps:
  - truth: "Ten consecutive successful, non-cancelled, first-attempt pull-request runs from one immutable implementation head achieve a median of at most 480 seconds and nearest-rank p95 of at most 600 seconds without weaker gates or newly introduced reruns."
    status: failed
    reason: "No current exact-ten receipt exists. The bounded sampler terminalized at sequence 2 after GitHub Actions run 33095420536 failed Quality (1.17, 27, true), hence CI Summary; the live API reports it as a completed pull_request attempt-1 failure on fc2a8c85141d39883749bdfb4278e7215f7f3db7. Four controller defects also make the bounded/no-rerun/complete-population guarantees false."
    artifacts:
      - path: ".planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md"
        issue: "Has zero CI_TIMING_CURRENT_TABLE_BEGIN and CI_TIMING_CURRENT_SOURCE_BEGIN markers; it contains only historical failed receipts."
      - path: "scripts/ci/collect_pr_timing_receipt.sh"
        issue: "Failed state resets (377-379), max-sequences is only positive (284), delayed-run polling has no deadline (513-527), and canonical run discovery fetches only page one (244)."
    missing:
      - "Repair the four fail-closed controller paths with executable regressions."
      - "Collect and explicitly API-reverify one fresh exact-ten qualifying PR receipt that meets median <=480s and p95 <=600s."
---

# Phase 132: Measured Closure Verification Report

**Phase Goal:** Close the measured CI-14 median gap on the existing required pull-request path, prove the behavior-preserving quality ratchets remain intact, and replace the failed timing measurement with a fresh comparable ten-run receipt.

**Verified:** 2026-08-27T17:11:31Z
**Status:** gaps_found  
**Re-verification:** Yes — after Plans 132-12 through 132-18.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Ten qualifying exact-head PR runs meet median <=480s and p95 <=600s, without weaker gates or reruns | ✗ FAILED | Live API: run `33095420536` was `pull_request`, attempt `1`, `completed`/`failure`, at `fc2a8c8…`; the receipt has zero current markers, so no ten-run canonical population or metrics exist. Four code-review-confirmed controller defects also violate the bounded/no-rerun/complete-population conditions. |
| 2 | `CI Summary` remains the sole required check with its required-job set and skip-as-pass behavior | ✓ VERIFIED | `scripts/setup_branch_protection.sh` declares only `CI Summary`; current `ci.yml` retains the aggregate and `if: always()`. Independent `bash scripts/ci/test_ci_summary_gate.sh` passed 6/6. |
| 3 | Coverage >=82.13% and the final correction preserves focused proof, quality signals, SAFE-01, relevant consumer proof, and bounded drift | ✓ VERIFIED | The fresh post-`15336d4` preservation census records `5149/6269 = 82.13431169245494%`, inclusive floor pass, quality/SAFE-01/automation-first/hygiene authorities, and packed image consumer `22 tests, 0 failures`. The preserved source SHA resolves exactly to `15336d4cc8053aa90788c62377096081c5b07f21`. |

**Score:** 2/3 truths verified (0 present-but-behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md` | Fresh preservation census and source manifest | ✓ VERIFIED | Substantive active schema-v2 manifest binds preserved subject `15336d4`; the receipt records positive-denominator coverage arithmetic and packed-consumer authority. |
| `.github/workflows/ci.yml` + required-check setup | Sole Summary topology and skip semantics | ✓ VERIFIED | Wired by CI topology contracts and the summary-gate script; current source retains the exact required aggregate. |
| `scripts/ci/collect_pr_timing_receipt.sh` | Bounded, fail-closed, complete-population timing controller | ✗ FAILED | Completed-state API revalidation is fixed, but failed-state reset, arbitrary sequence ceiling, unbounded missing-run polling, and first-page-only API discovery remain. |
| `.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md` | Current API-backed ten-run table/source/metrics | ✗ MISSING | `CI_TIMING_CURRENT_TABLE_BEGIN` and `CI_TIMING_CURRENT_SOURCE_BEGIN` occur zero times. Historical receipts include a 516.5s median failure and cannot substitute. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Preservation receipt | controller preflight | schema-v2 transition manifest with `15336d4` | ✓ WIRED | Active manifest is present and the receipt records successful no-publish preflight for the same subject. |
| `CI Summary` job | branch protection | `REQUIRED_CHECKS=("CI Summary")` | ✓ WIRED | Current workflow and gate test preserve the sole-required-check contract. |
| Timing controller | GitHub Actions canonical population | `canonical_eligible_run_ids` | ✗ PARTIAL | The function is called by API receipt verification but uses one `per_page=100` request, not pagination; it cannot prove population completeness. |
| Controller terminal state | sequence ceiling | persisted state / `run` entry point | ✗ NOT_WIRED | A `failed` state is overwritten by `write_initial_state`, permitting another two sequences. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Preservation receipt | covered/relevant counts | authoritative `cover/excoveralls.json` parsing | `5149` / `6269` | ✓ FLOWING |
| Timing receipt | current run table/source manifest | GitHub Actions API through controller | Terminal failure produced no admitted exact-ten population | ✗ DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| CI Summary skip/failure semantics | `bash scripts/ci/test_ci_summary_gate.sh` | `passed: 6 failed: 0` | ✓ PASS |
| Planning acceptance cannot be human-only | `./scripts/maintainer/automation_first_contract.sh` | Passed for Phase 132 | ✓ PASS |
| Terminal live sample identity | `gh api repos/szTheory/rindle/actions/runs/33095420536` | `pull_request`, exact `fc2a8c8…`, attempt `1`, `completed`/`failure` | ✗ FAIL for qualifying membership |
| Controller contract test file | `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` | The bounded verifier invocation was stopped after it remained active; regardless, source inspection shows no regressions for terminal-state re-entry, >2 sequences, permanently absent trigger, or page-two population records | ⚠️ INSUFFICIENT |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| CI-14 | 01–18 | Ten comparable PR runs meet timing limits with intact gates/no reruns | ✗ BLOCKED | No current exact-ten receipt; final allowed terminal run failed. Controller defects can bypass bounded sampling and omit eligible API records. |
| COV-05 | 02, 04, 07, 09–13, 15, 17–18 | Coverage >=82.13%, not raised by percentage-only tests | ✓ SATISFIED | Fresh preserved-subject receipt: `5149/6269 = 82.1343%`; integer inclusive comparison passes. |
| SAFE-02 | 01–04, 06–07, 09–18 | Focused proof, quality, SAFE-01, relevant package/integration lane and prohibited-surface preservation | ✓ SATISFIED | Fresh receipt binds `15336d4` to focused authorities, `mix quality_signals`, SAFE-01, packed consumer, and bounded prohibited-surface census. The CI-14-specific controller failures remain blockers for CI-14, not evidence of coverage or surface drift. |

All requirement IDs declared by the 18 PLAN frontmatters are present in `REQUIREMENTS.md`; there are no orphaned Phase 132 IDs. No later roadmap phase explicitly covers the CI-14 controller repair or fresh receipt, so no gap is deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `scripts/ci/collect_pr_timing_receipt.sh` | 377–379 | Failed state is reset | 🛑 BLOCKER | Allows new sequences after terminal ceiling exhaustion. |
| `scripts/ci/collect_pr_timing_receipt.sh` | 284–285, 575 | Any positive `--max-sequences` accepted | 🛑 BLOCKER | Caller can authorize more than the required two sequences. |
| `scripts/ci/collect_pr_timing_receipt.sh` | 513–527 | No missing-run creation deadline | 🛑 BLOCKER | Controller can poll forever rather than terminalizing boundedly. |
| `scripts/ci/collect_pr_timing_receipt.sh` | 240–252 | First API page only | 🛑 BLOCKER | A receipt can be accepted from a truncated canonical population. |
| `scripts/ci/collect_pr_timing_receipt.sh` | 377–396 | Running-state schema/identity not validated before resume | ⚠️ WARNING | Stale/malformed state can influence controller behavior. |
| `scripts/maintainer/automation_first_contract.sh` | 53–68 | Exact attribute-order/quote matching | ⚠️ WARNING | Valid manual checkpoint syntax can evade the automation-first parser. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt marker was found in the phase-modified executable paths.

### Gaps Summary

Phase 132 did not close CI-14. The live terminal sample failed before an exact-ten population could be admitted, and the receipt has no current source/table markers. This is observable absence, not uncertainty.

The previously reported completed-PASS local-state bypass is fixed: the complete-state branch now invokes `verify_api_backed_receipt`. However, four new/reconfirmed controller defects mean a future receipt cannot truthfully satisfy the phase’s bounded, no-rerun, and complete-population promises. These are implementation gaps, not human-verification items.

This is an **Escalation Gate**. Authorize a bounded remediation that fixes and regression-tests all four controller defects, then collect exactly one new API-backed exact-ten receipt on a new immutable published head. Human/UAT acknowledgement cannot close CI-14.

---

_Verified: 2026-08-27T17:11:31Z_
_Verifier: the agent (gsd-verifier)_
