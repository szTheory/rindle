---
phase: 132-measured-closure
verified: 2026-08-26T22:04:35Z
status: gaps_found
score: 2/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/3
  gaps_closed: []
  gaps_remaining:
    - "Fresh threshold-passing CI-14 receipt"
    - "API revalidation of completed timing-controller state"
  regressions: []
gaps:
  - truth: "Ten consecutive successful, non-cancelled, first-attempt pull-request runs from one immutable implementation head achieve a median of at most 480 seconds and nearest-rank p95 of at most 600 seconds without weaker gates or newly introduced reruns."
    status: failed
    reason: "The only authorized recovery controller exhausted both sequence attempts: runs 33016605029 and 33017105225 were first-attempt pull_request failures at 7f025dfdf55d612861610a10773d86761a374277. Its persisted state has zero rows, the receipt has no CI_TIMING_CURRENT markers, and therefore no comparable ten-run timing verdict exists."
    artifacts:
      - path: ".gsd/ci-timing/phase-132-recovery/pr-96-7f025dfdf55d612861610a10773d86761a374277.json"
        issue: "status is failed after 2/2 sequences with runs: []; no qualifying sample was collected."
      - path: ".planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md"
        issue: "Contains historical failed receipts only; no explicitly current table/source manifest was rendered."
    missing:
      - "A new bounded CI-14 remediation followed by one fresh API-backed exact-ten receipt that passes both inclusive thresholds."
  - truth: "One command safely publishes, collects, and verifies a timing receipt without accepting stale or forged local evidence."
    status: failed
    reason: "scripts/ci/collect_pr_timing_receipt.sh accepts state status complete/verdict PASS after verify_current_receipt_shape only. That path does not call verify_api_backed_receipt or reapply live API identity/threshold checks, so a stale or forged state/receipt can produce exit 0."
    artifacts:
      - path: "scripts/ci/collect_pr_timing_receipt.sh"
        issue: "Completed-state branch at lines 284-289 exits 0 for PASS without GitHub Actions API revalidation."
    missing:
      - "Make the completed-state path invoke verify_api_backed_receipt and add a regression test that stale/forged completed PASS state is rejected."
---

# Phase 132: Measured Closure Verification Report

**Phase Goal:** Close the measured CI-14 median gap on the existing required pull-request path, prove the behavior-preserving quality ratchets remain intact, and replace the failed timing measurement with a fresh comparable ten-run receipt.

**Verified:** 2026-08-26T22:04:35Z  
**Status:** gaps_found  
**Re-verification:** Yes — prior gaps remain open after Plans 132-06 through 132-11.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Fresh exact-ten PR receipt passes median <=480s and p95 <=600s, without weaker gates/reruns | ✗ FAILED | GitHub API independently reports recovery runs `33016605029` and `33017105225` as `pull_request`, attempt 1, `failure`, both at `7f025df…`. The persisted controller state is `failed`, at attempt `2`, with `runs: []`; no `CI_TIMING_CURRENT_*` marker exists. |
| 2 | `CI Summary` remains sole required check, required-job set and skip-as-pass behavior remain intact | ✓ VERIFIED | Current topology contracts passed: `mix test ...ci_timing_automation_test ...ci_lane_split_test ...ci_observability_test --seed 0` returned 47/47; `bash scripts/ci/test_ci_summary_gate.sh` returned 6/6. `.github/workflows/ci.yml` retains `CI Summary`, `if: always()`, and the required aggregate membership. |
| 3 | Coverage >=82.13% and quality/SAFE-01/relevant package proof/prohibited-surface census remain intact | ✓ VERIFIED | The preserved-subject receipt records one coverage authority, machine census `5149/6269`, ratio `0.8213431169245494`, and inclusive threshold pass. It records post-edit green quality, SAFE-01, automation-first, hygiene, and packed image-consumer authorities; `11bfee5` changed only three authorized CI topology lines. |

**Score:** 2/3 roadmap must-haves verified (0 present-but-behavior-unverified).

### Plan Must-Haves: Adversarial Trace

All eleven plans have a corresponding SUMMARY.md, but their claims were not used as proof. The actual artifacts and source establish the following.

| Plans | Result | Code/evidence checked |
| --- | --- | --- |
| 132-01 | ✓ VERIFIED | `Workspace.generate_phoenix_app!/2` uses `--no-install`; generated-app helper executes generate → patch → `fetch_deps!` → compile. Tagged source contract exists, and the preservation receipt records the real image consumer. |
| 132-02, 04, 07, 10 | ✓ VERIFIED | Preservation receipt is substantive, carries immutable subject `5add065…`, bounded diff census, coverage source manifest, ordered authorities, and no-publish preflight. Its COV-05 arithmetic is independently consistent: 5149 × 10000 >= 6269 × 8213. |
| 132-03 | ✗ FAILED | The controller is wired and fixture-tested, but the completed PASS state shortcut calls only `verify_current_receipt_shape`; it does not call `verify_api_backed_receipt`. This falsifies the claimed safe unattended verification path. |
| 132-05 | ✗ FAILED as closure evidence | The retained exact-ten historical receipt is correctly preserved but measures a 516.5s median, above 480s. It cannot close CI-14. |
| 132-06 | ✓ VERIFIED | `install_apt_packages.sh` has bounded install-first → refresh-on-failure → one retry flow; focused cache-hygiene contracts cover ordering and exit handling. Required workflow references are present. |
| 132-08 | ✗ FAILED / superseded | Its required current manifest is absent. The later locked Plan 132-11 controller honestly did not fabricate it after its samples failed, but that does not make the Plan 132-08 exact-ten/current-manifest truths true. |
| 132-09 | ✓ VERIFIED | Commit `11bfee5` changes only `.github/workflows/ci.yml` (three deleted `needs` declarations); current topology fixture and contracts prove the exact six-edge removal and preserved aggregate. |
| 132-11 | ✗ FAILED | External API confirms both allowed owned samples failed and no qualifying row was admitted. The code correctly stopped at two sequences and cleaned its state/label/lock, but the required exact-ten current receipt and CI-14 verdict do not exist. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/install_smoke/support/generated_app/workspace.ex` | Post-patch-only dependency path | ✓ VERIFIED | Substantive source uses `--no-install`; helper wiring fetches dependencies after patching. |
| `.github/workflows/ci.yml` + topology test/fixture | Exact D-08 graph with unchanged aggregate | ✓ VERIFIED | Source contracts passed; exact corrective commit contains three intended workflow deletions only. |
| `scripts/ci/install_apt_packages.sh` + hygiene test | Bounded install-first apt acquisition | ✓ VERIFIED | Script has empty-list failure, bounded initial install, refresh only after failure, and bounded retry; source contract exists. |
| `132-PRESERVATION-RECEIPT.md` | Authoritative preservation/coverage receipt | ✓ VERIFIED | 399 lines, current recovery census, immutable subject, machine-readable coverage record, and ordered command evidence. |
| `scripts/ci/collect_pr_timing_receipt.sh` | Fail-closed, API-backed timing controller | ✗ FAILED | The completed-PASS branch bypasses API verification; see gap 2. |
| `132-CI-TIMING-RECEIPT.md` | Fresh current exact-ten source/table/metrics receipt | ✗ MISSING | No `CI_TIMING_CURRENT_TABLE_BEGIN` or `CI_TIMING_CURRENT_SOURCE_BEGIN` marker exists. Historical failed receipts cannot substitute. |

### Key Link Verification

| From | To | Status | Details |
| --- | --- | --- | --- |
| Generated app helper | `Workspace.generate_phoenix_app!` / `fetch_deps!` | ✓ WIRED | Actual call order is generate → patch → fetch → compile. |
| CI topology contracts | `.github/workflows/ci.yml` | ✓ WIRED | The 47-test focused run includes `ci_lane_split_test.exs`; it reads the workflow source and asserts the required graph. |
| CI workflow | shared apt helper | ✓ WIRED | Cache-hygiene contract asserts 18 workflow invocations; helper is substantive. |
| Preservation receipt | timing controller preflight | ✓ WIRED | Receipt records correction and preserved SHAs used by controller preflight. |
| Timing controller | current receipt / GitHub API | ✗ PARTIAL | Normal verification has API-backed code, but completed PASS state exits after local-shape validation only. |

### Data-Flow Trace

| Artifact | Data | Source | Status |
| --- | --- | --- | --- |
| Preservation receipt | Covered/relevant counts | `cover/excoveralls.json` parsed to `RECOVERY_COVERAGE_CENSUS_V1` | ✓ FLOWING — positive denominator and integer threshold proof recorded. |
| Timing receipt | Current ten-run table and source manifest | GitHub Actions API via controller | ✗ DISCONNECTED — recovery state has zero admitted runs, so no current section is rendered. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Current topology/controller contract suite | `mix test test/install_smoke/ci_timing_automation_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0` | `47 tests, 0 failures` | ✓ PASS |
| CI Summary skip/failure semantics | `bash scripts/ci/test_ci_summary_gate.sh` | `passed: 6 failed: 0` | ✓ PASS |
| Two owned recovery samples | GitHub Actions API `GET actions/runs/{id}` | Both are attempt 1, `pull_request`, same SHA, completed `failure` | ✗ FAIL for qualifying membership |

### Requirements Coverage

| Requirement | Source plans | Status | Evidence |
| --- | --- | --- | --- |
| CI-14 | 01–11 | ✗ BLOCKED | No fresh threshold-passing ten-run receipt; zero qualifying recovery samples. Controller’s local completed-PASS shortcut is also unsafe. |
| COV-05 | 02, 04, 07, 09–11 | ✓ SATISFIED | Machine-recorded `5149/6269 = 82.1343%`, inclusive threshold pass; no percentage-only test identified in bounded correction range. |
| SAFE-02 | 01–04, 06–07, 09–11 | ✓ SATISFIED | Focused contracts pass; preservation census records quality, SAFE-01, packed consumer, topology, diff, hygiene, and automation-first evidence. |

No orphaned Phase 132 requirement IDs were found: every ID declared in PLAN frontmatter is listed in REQUIREMENTS.md, and all three roadmap IDs are accounted for above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `scripts/ci/collect_pr_timing_receipt.sh` | 284–289 | Completed PASS state skips live API verification | 🛑 BLOCKER | Can accept stale/forged local timing evidence as a CI-14 pass. |
| `test/install_smoke/support/generated_app_helper.ex` | 155 / 604 | Doctor status derives from smoke; unbounded `String.to_atom/1` under a misleading name | ⚠️ WARNING | Review-identified report correctness and atom-exhaustion risks; not used to green CI-14. |

The source scan found no unreferenced `TBD`, `FIXME`, or `XXX` debt marker in phase-modified executable files. `dryrun-placeholder` is an existing literal environment value, not an implementation placeholder.

### Prohibitions

The plan frontmatter contains 19 prohibition entries, each marked unresolved with no executable verification tier. They therefore do not receive a silent green verdict. Bounded diffs and source contracts support the no-gate-weakening/no-prohibited-surface claims, while the controller bypass above is a concrete safety failure requiring remediation. Automation-first policy means no human/UAT decision can close CI-14 or substitute for its receipt.

## Gaps Summary

Phase 132 has not achieved its goal. The measured PR path has no new qualifying ten-run receipt: both permitted recovery samples failed before membership could begin. In addition, the controller can treat a locally complete PASS state as authoritative without rechecking GitHub, so even a future receipt is not safe to accept through that path until the bypass is removed and regression-tested.

No later milestone phase explicitly schedules either gap, so nothing is deferred. This is an **Escalation Gate**: plan a bounded CI-14 remediation that (1) fixes the completed-state API revalidation defect with an executable regression, then (2) collects one new exact-ten Actions-API-backed receipt on a fresh immutable head. Do not launch another controller or close the phase before that work is authorized.

---

_Verified: 2026-08-26T22:04:35Z_  
_Verifier: the agent (gsd-verifier)_
