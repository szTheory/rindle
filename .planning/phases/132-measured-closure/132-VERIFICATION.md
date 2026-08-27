---
phase: 132-measured-closure
verified: 2026-08-27T20:59:00Z
status: gaps_found
score: 2/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/3
  gaps_closed:
    - "Fresh exact-ten API-backed CI-14 receipt exists and independently verifies against GitHub Actions."
    - "Terminal failed state, maximum-sequence validation, persisted creation epoch, and paginated canonical-population paths were repaired."
  gaps_remaining:
    - "Rate-limit retries are not bounded by persisted creation, quiescence, or run deadlines."
    - "automation_first_contract.sh misses valid checkpoint:human-action task markup when type is not the first attribute."
  regressions: []
gaps:
  - truth: "A pending trigger and every controller wait path terminalize within their configured persisted deadline without relabeling or retaining unbounded mutation authority."
    status: failed
    reason: "gh_api_json retries a rate-limited gh request indefinitely. Its callers invoke it before checking the persisted creation deadline or local quiescence/run deadlines, so persistent primary or secondary GitHub API rate limiting prevents terminalization and may retain the controller label/lock indefinitely."
    artifacts:
      - path: "scripts/ci/collect_pr_timing_receipt.sh"
        issue: "Lines 255-291 have an unbounded rate-limit retry/sleep loop; lines 508-527, 577-593, and 605-616 can reach their deadline checks only after gh_api_json returns."
      - path: "test/install_smoke/ci_timing_automation_test.exs"
        issue: "The rate-limit test at lines 384-392 checks source strings only; it does not prove timeout/terminalization under persistent rate limiting."
    missing:
      - "Pass an absolute deadline or bounded retry budget through gh_api_json, check it before request and sleep, return a distinguishable timeout, and have every caller terminalize/clean up its durable state."
      - "Add deterministic fixture regressions for permanent rate-limit responses in creation, publication-quiescence, run polling, and canonical-population paths."
  - truth: "The automation-first acceptance gate rejects every non-authorization checkpoint:human-action task and any human action that carries acceptance or verification, regardless of XML-like attribute order or quote style."
    status: failed
    reason: "The AWK opener is the literal ordered substring <task type=\"checkpoint:human-action\". A task whose gate attribute precedes type is never collected or checked."
    artifacts:
      - path: "scripts/maintainer/automation_first_contract.sh"
        issue: "Lines 57-61 require type to be the first attribute; the policy therefore reports a false pass for valid reordered task markup."
      - path: "test/install_smoke/automation_first_contract_test.exs"
        issue: "All three tests put type first, so the parser's attribute-order bypass is uncovered."
    missing:
      - "Detect checkpoint:human-action type attributes independent of order and quote style, then apply the existing authorization-only and no-acceptance checks to the full task block."
      - "Add regressions for gate-before-type and single-quoted type attributes, including a requirement-bearing rejected example."
next_action:
  gate: escalation
  command: "$gsd-plan-phase 132 --gaps"
  required_scope: "Repair and regression-test both fail-closed gaps, then rerun the receipt verifier and preservation authorities. The current ten-run receipt remains evidence but must not be used to mark SAFE-02 or the phase complete until those gates pass."
---

# Phase 132: Measured Closure Verification Report

**Phase Goal:** Close the measured CI-14 median gap on the existing required pull-request path, prove the behavior-preserving quality ratchets remain intact, and replace the failed timing measurement with a fresh comparable ten-run receipt.

**Verified:** 2026-08-27T20:59:00Z
**Status:** gaps_found
**Re-verification:** Yes — after Plans 132-19 through 132-21.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Ten consecutive successful, non-cancelled, first-attempt PR runs from one immutable head meet median <=480s and p95 <=600s without weaker gates or reruns. | ✓ VERIFIED | Independent live `verify` exited 0. The paginated GitHub API census returned exactly the ten receipt IDs for PR 96/head `869ca9c…`; all are completed `pull_request` attempt-1 successes. Source/table cardinality is 1/1, chronology is non-overlapping, median is 453s, and p95 is 481s. |
| 2 | `CI Summary` remains the sole required check with the required job set and skip-as-pass behavior. | ✓ VERIFIED | `scripts/setup_branch_protection.sh` still declares only `CI Summary`; `.github/workflows/ci.yml` keeps its required member list and `if: always()`. `bash scripts/ci/test_ci_summary_gate.sh` passed 6/6 cases. |
| 3 | Coverage >=82.13% and the final correction preserves focused proof, quality signals, SAFE-01, relevant consumer proof, bounded prohibited-surface review, and automation-first acceptance. | ✗ FAILED | COV-05 numeric evidence is sound (`5149/6269 = 82.134311…%`), but the automation-first gate that this preservation claim relies on has an executable bypass. The controller's unbounded rate-limit path also violates the repaired fail-closed safety contract. |

**Score:** 2/3 truths verified (0 present-but-behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md` | One current exact-ten table/source manifest and inclusive CI-14 verdict | ✓ VERIFIED | Exactly one begin/end pair for both table and source; parsed source identifies head `869ca9c…`, ten runs, 453s median, 481s p95. Live verifier exited 0. |
| `scripts/ci/collect_pr_timing_receipt.sh` | Bounded, fail-closed timing controller | ✗ STUBBED SAFETY | Substantive and wired, including terminal state, max-two, state validation, and pagination repairs; however, unbounded rate-limit retry makes the deadline guarantee false. |
| `test/install_smoke/ci_timing_automation_test.exs` | Executable controller regressions | ⚠️ PARTIAL | Focused suite passes, but its rate-limit assertion is source-text presence only and does not exercise persistent limiting against a deadline. |
| `.planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md` | Immutable preservation manifest and COV-05/SAFE-02 authorities | ⚠️ PARTIAL | One schema-v2 manifest binds `a4bbbd1…`; coverage and topology evidence are substantive, but SAFE-02 cannot rely on a bypassable automation-first gate. |
| `scripts/maintainer/automation_first_contract.sh` | Fail-closed human-acceptance policy | ✗ STUBBED SAFETY | Actual Phase 132 plans pass, but a temporary plan using `<task gate="blocking" type="checkpoint:human-action">` with human acceptance passed the script (exit 0). |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Receipt source manifest | GitHub Actions canonical population | `verify_api_backed_receipt` → paginated `canonical_eligible_run_ids` | ✓ WIRED | Live `verify` passed; independent API census returned exactly the receipt's ten selected IDs after its documented boundary exclusions. |
| Persisted deadline | Trigger/run/quiescence wait loops | `gh_api_json` before the callers' deadline checks | ✗ NOT_WIRED | Persistent rate limits never return from lines 255-291, so lines 525, 590, and 614 cannot enforce their deadline. |
| Human-action markup | automation-first policy | AWK task-block extraction | ✗ NOT_WIRED | Extraction only recognizes the literal type-first opening tag, leaving reordered valid attributes invisible. |
| CI workflow | branch protection | `REQUIRED_CHECKS=("CI Summary")`, summary `needs`, skip-as-pass evaluator | ✓ WIRED | The sole-required-check topology and evaluator behavior remain intact; six deterministic gate scenarios pass. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Timing receipt | `runs`, statistics, canonical IDs | Live paginated GitHub Actions API | Ten exact IDs, 453s median, 481s p95 | ✓ FLOWING |
| Preservation receipt | coverage counts | Structural `cover/excoveralls.json` census | 5149 covered / 6269 relevant | ✓ FLOWING |
| Controller deadline | deadline loop progress | `gh_api_json` response | Persistent rate limit blocks response/control return | ✗ HOLLOW SAFETY FLOW |
| Automation acceptance | checkpoint task blocks | AWK extractor | Reordered human-action block discarded | ✗ DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Current exact-ten receipt re-fetches API identities, jobs, population, chronology, and statistics | `bash scripts/ci/collect_pr_timing_receipt.sh verify --repo szTheory/rindle --pr 96 --workflow ci.yml --summary-job 'CI Summary' --samples 10 --median-max 480 --p95-max 600 --receipt .planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md` | `receipt verification passed` | ✓ PASS |
| Canonical live population is complete | Paginated `gh api` projection for PR 96/head `869ca9c…` excluding documented boundaries | Count 10; IDs exactly equal receipt | ✓ PASS |
| Controller regression suite | `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` | Exit 0 | ✓ PASS, but insufficient for persistent rate-limit deadline behavior |
| Automation-first existing fixtures | `mix test test/install_smoke/automation_first_contract_test.exs --seed 0` | 3 tests, 0 failures | ✓ PASS, but incomplete fixture coverage |
| CI Summary skip/failure semantics | `bash scripts/ci/test_ci_summary_gate.sh` | 6 passed, 0 failed | ✓ PASS |
| Current automation-first policy | `bash scripts/maintainer/automation_first_contract.sh --phase-dir .planning/phases/132-measured-closure` | Exit 0 | ✗ FALSE POSITIVE — adversarial reordered task also exits 0 |
| Attribute-order policy bypass | Temporary plan: `gate` before `type`, human acceptance criterion | Contract reported passed | ✗ FAIL |

The documented completed-state `run --no-publish` result cannot be independently replayed now without reconstructing the cleaned state file; cleanup absence is the intended end state. Its control path exists at lines 470-484 and the receipt's original evidence is retained, but it is not used to waive either blocker above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| CI-14 | 01–21 | Ten comparable non-cancelled PR runs meet timing limits with intact gates/no reruns. | ✓ SATISFIED | Fresh immutable head `869ca9c…`, exact ten-run API population, successful attempt-1 identities, 453s median and 481s p95 independently reverified. |
| COV-05 | 02, 04, 07, 09–13, 15, 17, 20–21 | Authoritative coverage >=82.13%, not raised by percentage-only tests. | ✓ SATISFIED | Active preservation receipt records the structural positive-denominator census and integer pass: `5149 * 10000 >= 6269 * 8213`. |
| SAFE-02 | 01–04, 06–07, 09–21 | Focused proof, quality, SAFE-01, relevant consumer/integration lane, and prohibited-surface preservation. | ✗ BLOCKED | The inspected source and an executable adversarial input prove the automation-first policy is bypassable; the sampling controller is not bounded under persistent API rate limiting. These invalidate two safety must-haves despite otherwise passing preservation receipts. |

All requirement IDs declared across the 21 plans map to CI-14, COV-05, or SAFE-02 in `REQUIREMENTS.md`; there are no orphaned Phase 132 requirement IDs. No later milestone phase explicitly covers either unresolved gap, so neither is deferred.

### Plan Must-Have Audit

All 21 PLAN frontmatters were read. Their declared artifacts exist and are substantive; the current end-state artifacts are wired through the receipt verifier, preservation manifest, CI topology tests, and controller entry points. Historic receipt/correction plans are superseded by the current Plan 132-21 receipt rather than treated as a substitute for it.

The two current false truths are both explicit must-haves, not a tooling limitation:

1. Plan 132-19's persisted creation/deadline truth fails under persistent API rate limiting.
2. Plans 132-20 and 132-21's automation-first preservation truth fails for reordered `checkpoint:human-action` markup.

All other current Plan 132-19–21 must-haves have direct code or machine evidence: immutable terminal failure, one-or-two sequence validation, schema-v2 resume validation, paginated deterministic population, exact-ten receipt shape/statistics, manifest binding, coverage arithmetic, planning-only tail, and intact CI Summary topology.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `scripts/ci/collect_pr_timing_receipt.sh` | 255–291 | Infinite rate-limit retry before deadline evaluation | 🛑 BLOCKER | A controller can remain active beyond all durable timing bounds. |
| `test/install_smoke/ci_timing_automation_test.exs` | 384–392 | Presence-only rate-limit test | 🛑 BLOCKER | Passing test does not test the stated fail-closed timeout behavior. |
| `scripts/maintainer/automation_first_contract.sh` | 57–61 | Attribute-order-sensitive task parser | 🛑 BLOCKER | Manual acceptance can evade the merge-blocking policy. |
| `test/install_smoke/automation_first_contract_test.exs` | 25, 56 | Type-first-only fixtures | 🛑 BLOCKER | The attribute-order bypass is not covered. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt marker was found in the phase's executable paths. The `mktemp` matches are normal temporary-state handling, not stubs.

### Gaps Summary

The exact-ten receipt is a genuine CI-14 closure receipt: it is fresh, API-backed, complete under pagination, and within both inclusive timing thresholds. COV-05 is also met.

Phase 132 nevertheless fails its goal because SAFE-02's behavior-preserving safety ratchets are not intact. The current controller's rate-limit retry can outlive every persisted deadline, and the repository's automation-first acceptance check has a reproducible syntax-order bypass. These are observable implementation failures, so no human verification or UAT can close them.

This is an **Escalation Gate**. Create a focused gap-closure plan to repair both fail-closed paths and add behavioral regressions. Re-run the current receipt verifier and preservation authorities after the repair; a new ten-run receipt is not required unless those checks show receipt or required-path drift.

---

_Verified: 2026-08-27T20:59:00Z_
_Verifier: the agent (gsd-verifier)_
