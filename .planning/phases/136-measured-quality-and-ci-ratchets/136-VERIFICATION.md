---
phase: 136-measured-quality-and-ci-ratchets
verified: 2026-10-21T19:37:49Z
status: passed
score: 41/41 active must-haves verified
covered_files:
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-01-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-01-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-02-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-02-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-03-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-03-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-04-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-04-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-05-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-05-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-06-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-06-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-07-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-07-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-08-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-08-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-09-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-09-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-10-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-10-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-11-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-11-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-12-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-12-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-13-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-13-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-14-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-14-SUMMARY.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-15-PLAN.md
  - .planning/phases/136-measured-quality-and-ci-ratchets/136-15-SUMMARY.md
  - .dialyzer_ignore.exs
  - .github/actions/setup-minio/action.yml
  - .github/workflows/ci.yml
  - .github/workflows/nightly.yml
  - CONTRIBUTING.md
  - RUNNING.md
  - coveralls.json
  - scripts/ci/collect_pr_timing_receipt.sh
  - scripts/ci/install_ffmpeg.sh
  - scripts/ci/test_nightly_dialyzer.sh
  - scripts/maintainer/artifact_ledger.json
  - scripts/maintainer/async_isolation_evidence.sh
  - scripts/maintainer/credo_complexity_baseline.json
  - scripts/maintainer/credo_quality.sh
  - scripts/maintainer/credo_quality_normalize.exs
  - scripts/maintainer/credo_removal_evidence.json
  - scripts/maintainer/live_residue_allowlist/install_smoke.json
  - scripts/maintainer/phase136_evidence.py
  - scripts/maintainer/phase136_evidence_contract.json
  - scripts/maintainer/phase136_measure.sh
  - scripts/maintainer/verify_async_isolation_receipt.sh
  - scripts/maintainer/verify_contributor_bootstrap.sh
  - scripts/maintainer/verify_coverage_floor.exs
  - scripts/maintainer/verify_phase136_qualification.sh
  - test/install_smoke/async_isolation_evidence_runner_test.exs
  - test/install_smoke/ci_cache_hygiene_test.exs
  - test/install_smoke/ci_timing_automation_test.exs
  - test/install_smoke/contributor_bootstrap_test.exs
  - test/install_smoke/coverage_floor_policy_test.exs
  - test/install_smoke/credo_policy_test.exs
  - test/install_smoke/dialyzer_ignore_policy_test.exs
  - test/install_smoke/phase136_measure_test.exs
  - test/install_smoke/phase136_qualification_test.exs
  - test/install_smoke/quality_signal_policy_test.exs
  - test/rindle/processor/av/output_probe_test.exs
covered_digest: "v3:sha256:78bafcb8a5306bd689e1da3fc427f100288179e4f313767e372bcfafef2ec33b"
behavior_unverified: 0
overrides_applied: 0
deferred:
  - truth: "Exact-ten current-PR timing population has median <=480 seconds and p95 <=600 seconds."
    addressed_in: "SEED-261021-918"
    evidence: "User decision in 136-SPEED-DEFERRAL.json explicitly defers this unfinished numeric target and grants zero acceptance credit; no sampler ran."
---

# Phase 136: Measured Quality and CI Ratchets Verification Report

**Phase Goal:** Contributors receive bounded, reproducible quality and CI feedback whose measured guarantees cannot silently regress.
**Verified:** 2026-10-21T19:37:49Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Complexity and Dialyzer ledgers reject baseline growth or broader suppressions; reductions require behavior-preservation evidence and retained findings have machine-checkable removal triggers. | ✓ VERIFIED | Frozen-source quality authorities in `136-QUALIFICATION-CLOSEOUT.json` are complete. Credo and Dialyzer policy tests are in the canonical suite; final fresh/restored Dialyzer receipts pass on Elixir 1.17.3 / OTP 27.3.4.15. |
| 2 | One fresh canonical coverage run preserves the exact accepted floor, with changed risk branches tested behaviorally. | ✓ VERIFIED | `136-SUBJECT-SPEED.json` pins source `e2d3b5c759e38c79744a1ef9bade8b6f2d92a2f9` and projection `9e66e48b2fc64a29f5b973ce28c922eed053cfc3`; final canonical receipt records 1,700 tests, 3 doctests, zero failures, and 5,206/6,329 coverage (82.2563%) above the 82.1343% floor. `verify-subject` and qualification verification authenticate the pin and receipt hashes. |
| 3 | Issue #42's finite isolation experiment completes or retains a reproducible open failure, with uncertainty and a next trigger; reruns cannot erase its result. | ✓ VERIFIED | `136-ASYNC-RESULT-SPEED.json` binds 25 passing iterations to the frozen subject and records that finite sampling cannot prove every schedule safe; next trigger is a reproducible failure or source change. The no-clobber/receipt consumer owners are included in the final canonical suite. |
| 4 | A clean supported environment follows a tested command map from bootstrap through focused and full verification. | ✓ VERIFIED | `136-BOOTSTRAP-EVIDENCE-SPEED.json` records all documented commands, including full `mix ci`, passing on the supported runtime; `RUNNING.md` and `CONTRIBUTING.md` provide the command map. Final receipt verification confirms the frozen subject. |
| 5 | Structural CI checks preserve workflow semantics, cache/input integrity, bounded timeouts, `ci.yml` / workflow `CI`, sole required `CI Summary`, fork safety, exact-SHA release coupling, exact-head proof, and required CI green. | ✓ VERIFIED | Parsed-workflow policy and cache tests are in the canonical suite. `136-MERGE-RESULT.json` binds successful PR CI run 39620867248 to the exact source SHA, records the authorized squash merge, and records successful main CI run 39624064249 on merge SHA `a046e5be585618d4dfc8f559870e4585b1abb06a`, including `CI Summary`. Plan 15 tests exercise overlap and failure propagation while retaining the existing 15-minute ceiling and required context. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

The original qualification contract still reports `outcome: blocked`: its timing authority is absent, and CI-16 remains `blocked` inside that immutable manifest. That result is accurate for the original exact-ten timing contract. The active roadmap and requirement were explicitly amended by the recorded user decision: the numeric target is deferred unfinished, gives no acceptance credit, and is no longer a merge gate. The active CI-16 criterion is the structural, exact-SHA, fork-safety, required-context and green-CI contract; exact-source PR and main receipts satisfy it. This report does not rewrite the qualification receipt or claim any numeric speed acceptance.

### Plan-Specific Must-Haves

The 15 plan frontmatters add implementation-level truths to the five roadmap truths. All 36 still-active plan truths were checked against source, executable owners, final-subject receipts, or exact-SHA CI evidence. Three plan truths that required the now-deferred exact-ten timing population are listed as deferred below and are excluded from the active score, without receiving acceptance credit.

| Plan | Active must-haves | Status | Evidence |
|---|---|---|---|
| 136-01 | Stable finding identity and non-growth; reductions require passing behavioral evidence; retained findings have owner and executable trigger. | ✓ 3/3 VERIFIED | Credo gate and mutation tests in final canonical run; removal ledger is wired to the gate. |
| 136-02 | Exact suppressions are removal-only on supported toolchain; fresh/restored contracts are fixture-tested and measured. | ✓ 2/2 VERIFIED | Narrow matcher tests plus final fresh/restored Dialyzer receipts. |
| 136-03 | Exact threshold receipt can be emitted; just-below-floor fails; changed risk branches have behavioral regressions. | ✓ 3/3 VERIFIED | Final exact counts exceed floor; floor-policy tests and risk-branch behavior tests are in canonical run. |
| 136-04 | Fixed 25-seed runner and validator are fixture-proven; open/red outcomes preserve uncertainty and next trigger. | ✓ 2/2 VERIFIED | Final async receipt, no-clobber and validator tests. |
| 136-05 | Parsed workflow/cache/input/timeout policies are enforced; required workflow/context, fork safety and SHA coupling remain. | ✓ 2/2 VERIFIED | Parsed YAML policy tests, cache/input checks, and exact-subject PR/main CI evidence. |
| 136-06 | Clean environment runs documented bootstrap/focused/full commands; command map routes to existing owners. | ✓ 2/2 VERIFIED | Clean supported bootstrap receipt and `RUNNING.md` command map. |
| 136-07 | Each requirement derives from fresh supported evidence, with TEST-08 allowed to remain explicitly open on a first red. | ✓ 1/1 VERIFIED | Qualification validates the complete non-timing authorities; TEST-08 has a complete finite result with uncertainty and next trigger. |
| 136-08 | Current-subject timing mode does not borrow historical transition state; current mode enforces ten-run and CI Summary authentication. | ✓ 2/2 VERIFIED | Parsed timing-controller behavior tests verify current and historical modes and reject partial/foreign populations. |
| 136-09 | Fresh/restored Dialyzer, finite async and clean bootstrap evidence bind to one measured subject and supported authority. | ✓ 2/2 VERIFIED | Final SPEED receipts bind to e2d3b5c7 and the accepted toolchain; receipt hashes authenticate. |
| 136-10 | Collectors produce source-bound receipts; qualification verdict is derived by executable validation of the authorities. | ✓ 2/2 VERIFIED | Producer/consumer tests and verify command; the returned aggregate preserves the blocked timing status. |
| 136-11 | Commit/tree identity is pinned before measurement; one canonical run produces exact counts or a durable first red. | ✓ 2/2 VERIFIED | Historical first-red is retained; replacement final subject has one canonical exact-count receipt. |
| 136-12 | Original first-red remains unchanged; async/residue gates pass; replacement subject owns one canonical run. | ✓ 3/3 VERIFIED | Immutable historical artifacts plus repaired-candidate canonical evidence and retained tests. |
| 136-13 | Timeouts remain terminal failures; full `mix ci` has a 600-second command cap with 300-second focused/setup and 1200-second total bounds; old receipts remain unchanged. | ✓ 3/3 VERIFIED | Controlled timeout/consumer tests, preserved first-red record, bounded bootstrap command map, and final distinct subject receipts. |
| 136-14 | Artifact ledger/archive simulation passes; relocation preserves bytes/digests; missing/tampered/symlink evidence rejects; each new subject has distinct measurements. | ✓ 3/3 VERIFIED | 58-case harness, 31 exact relocation hashes, 38 unchanged JSON hashes, and source-bound replacement receipts. |
| 136-15 | Four harnesses start independently and are all awaited; any failure keeps Proof/CI Summary red; timeout/dependencies/assertions remain; new measurements do not relabel old receipts. | ✓ 4/4 VERIFIED | Plan15 focused and owner/meta suites, real sequential/parallel runs, preserved topology and exact-source PR/main CI results. |

The three deferred plan-specific truths are the two Plan 07 exact-ten run/median/p95 acceptance truths and Plan 14's request for a current-head exact-ten timing receipt. Their status is explicitly deferred unfinished under the user decision and they carry zero numeric acceptance credit.

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|---|---|---|
| 1 | Exact-ten timing median <=480 seconds and p95 <=600 seconds | SEED-261021-918 | `136-SPEED-DEFERRAL.json` records `deferred_unfinished`, `acceptance_credit: false`, and no sampler; historical blocked receipts remain unchanged. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `scripts/maintainer/credo_quality.sh`, normalizer, baseline, removal evidence | Removal-only complexity ratchet and behavior-backed reductions | ✓ VERIFIED | Non-stub policy implementation is consumed by the Credo task and policy tests; final quality authority complete. |
| `.dialyzer_ignore.exs`, `scripts/ci/run_nightly_dialyzer.sh` | Narrow stable suppressions and fresh/restored supported analysis | ✓ VERIFIED | Policy tests and frozen-subject fresh/restored transcripts pass; current subject verifier authenticates evidence. |
| `scripts/maintainer/verify_coverage_floor.exs`, coverage policy tests | Exact source-bound floor and canonical measurement verification | ✓ VERIFIED | Final receipt identifies source projection, exact covered/relevant counts and runtime; verify-only passes. |
| Async evidence producer and receipt validator | Immutable, bounded, complete/open/blocked outcomes | ✓ VERIFIED | Producer is consumed by the 25-seed source-bound receipt; receipt verifier and no-clobber test are in canonical suite. |
| CI workflow, cache/input validators, policy tests | Structural topology, input integrity and bounded execution | ✓ VERIFIED | Workflow parsed by executable policy tests; frozen final CI passed and main required CI is green. |
| Contributor bootstrap script and `RUNNING.md` | Reproducible supported bootstrap and command map | ✓ VERIFIED | Clean bootstrap receipt completed all six commands on the supported subject/runtime. |
| `phase136_evidence.py`, measurement/qualification validators | Source-bound, fail-closed measurement and aggregate receipts | ✓ VERIFIED | Subject verifier returned complete for the final SHA/projection; qualification verifier authenticated receipts and preserved blocked timing. |

All 15 plan/summary pairs and their declared implementation files were fingerprinted. The modified implementation set is substantive and connected through scripts, workflows, focused test owners, final measurement collectors and exact-SHA CI evidence. Level 4 dynamic-data flow is not applicable to this CI/tooling phase.

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Credo quality command | normalized findings, reviewed baseline and removal evidence | executable task pipeline | WIRED | Invocation and policy tests are present in the final quality authority. |
| Dialyzer ignore policy | fresh/restored analysis | supported CI script and pinned measurement | WIRED | Both modes completed on the subject; validator checks toolchain and transcript identity. |
| Coverage floor verifier | canonical local+JSON coverage receipt | exact subject/tree and receipt digests | WIRED | Final source-bound receipt passes verify-only; exact count and floor are recorded. |
| Async isolation runner | immutable JSONL receipt and verdict consumer | bounded runner plus validator | WIRED | 25-seed result, uncertainty and next trigger are retained and authenticated. |
| Parsed CI policy tests | `.github/workflows/ci.yml` topology and Proof harness | YAML parsing and behavioral fixtures | WIRED | Tests cover required context, fork safety, exact-SHA relationship, overlap and fail-any/wait-all behavior. |
| Contributor command map | tested bootstrap commands | `RUNNING.md` and bootstrap verifier | WIRED | Six clean bootstrap steps completed on the frozen subject. |
| PR/main CI result | frozen PR SHA and merged main SHA | `136-MERGE-RESULT.json` | WIRED | Exact PR subject is recorded with successful CI; merged main SHA has successful required CI and CI Summary. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| Measurement receipts | results, counts, hashes, runtime | actual test/analysis/bootstrap/async child processes on pinned checkout | Yes; raw outputs and digests retained | ✓ FLOWING |
| CI merge result | job conclusions and head SHAs | exact-source GitHub CI runs recorded in receipt | Yes; PR and main run IDs, conclusions and SHAs present | ✓ FLOWING |

### Behavioral Spot-Checks

No suites were rerun during verification because the final subject already has recorded executable evidence and the source/receipt verifiers were sufficient. The verification commands were read-only and did not recollect timing or mutate measurement state.

| Behavior | Command / retained evidence | Result | Status |
|---|---|---|---|
| Final source and tree are the measured subject | `phase136_measure.sh verify-subject --subject-file .../136-SUBJECT-SPEED.json` | `outcome: complete`, SHA `e2d3b5c7…`, tree `9e66e48b…` | ✓ PASS |
| Final measurement authorities authenticate | `verify_phase136_qualification.sh verify --subject-file ... --manifest .../136-QUALIFICATION-CLOSEOUT.json` | Command exited 0; coverage, Dialyzer, bootstrap, async and quality complete; timing blocked by original contract | ✓ PASS (receipt authentication; aggregate remains blocked) |
| Canonical coverage floor and behavioral tests | `136-COVERAGE-EVIDENCE-SPEED.json` | 1,700 tests + 3 doctests, zero failures; 5,206/6,329 exact coverage | ✓ PASS |
| Async isolation finite experiment | `136-ASYNC-RESULT-SPEED.json` | 25 iterations complete; explicit limitation and evidence-triggered next action retained | ✓ PASS |
| Required PR and main CI | `136-MERGE-RESULT.json` | PR CI and merged-main CI success; required `CI Summary` success | ✓ PASS |

### Probe Execution

No phase-declared or conventional `scripts/*/tests/probe-*.sh` probe was found. The phase's executable owners are ExUnit policy tests, measurement collectors and receipt validators; final source-bound receipts were authenticated above.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| MAINT-04 | 01, 07, 14 | Complexity ceiling is removal-only; reductions require behavior proof and retained entries have triggers. | ✓ SATISFIED | Complete frozen-subject quality authority and final policy tests. |
| TYPE-03 | 02, 09, 10, 13 | Dialyzer suppressions remain narrow and supported fresh/restored analysis passes. | ✓ SATISFIED | Fresh/restored final transcripts and source-bound validator. |
| COV-06 | 03, 11, 12, 13 | Exact canonical floor is preserved with behavioral risk tests. | ✓ SATISFIED | Exact 5,206/6,329 final coverage above 82.1343%; canonical suite passed. |
| TEST-08 | 04, 09, 10 | Finite isolation experiment or immutable reproducible open result is retained. | ✓ SATISFIED | 25-seed source-bound complete receipt, uncertainty, and next trigger. |
| CI-15 | 05, 12, 14, 15 | CI semantics, inputs, caches and process-heavy jobs are structurally checked and bounded. | ✓ SATISFIED | Parsed policy tests, integrity checks, preserved timeout and green required CI. |
| CI-16 | 05, 07, 08, 10, 15 | Preserve CI topology, exact-SHA/fork/required-context behavior and green CI; numeric timing is deferred by explicit amendment. | ✓ SATISFIED (amended scope) | Exact PR/main CI receipts pass. Original aggregate manifest remains truthfully blocked on the deferred timing authority; no timing credit. |
| DX-05 | 06, 09, 10, 13 | Clean supported bootstrap and correct focused/full command map. | ✓ SATISFIED | Final bootstrap receipt completed all six commands and is bound to the measured subject. |

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
|---|---|---:|---:|---:|---|---|
| `credo_policy_test.exs`, `dialyzer_ignore_policy_test.exs` | MAINT-04, TYPE-03 | Yes | 0 | 0 detected | Value / behavior | PASS |
| `coverage_floor_policy_test.exs`, `phase136_measure_test.exs` | COV-06 | Yes | 0 | 0 detected | Value / behavior | PASS |
| `async_isolation_evidence_runner_test.exs`, `phase136_measure_test.exs` | TEST-08 | Yes | 0 | 0 detected | Multi-step / value | PASS |
| `ci_cache_hygiene_test.exs`, `quality_signal_policy_test.exs` | CI-15, CI-16 | Yes | 0 | 0 detected | Parsed contract / behavior | PASS |
| `contributor_bootstrap_test.exs`, `phase136_measure_test.exs` | DX-05 | Yes | 0 | 0 detected | Multi-step / value | PASS |

No disabled requirement-linked tests were found. No source-literal-only or percentage-only assertion was identified as the sole proof for a requirement.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `.github/workflows/ci.yml` | 854 | `dryrun-placeholder` passed as a dummy `HEX_API_KEY` for `mix hex.publish --dry-run` | Info | Intentional dry-run credential fixture; does not publish or indicate an unfinished implementation. |

No unresolved `TBD`, `FIXME`, or `XXX` debt markers were found in the phase implementation files. Empty callback stubs were confined to test fixtures. No implementation stub, missing wiring, disabled acceptance test, or hollow measurement path was found.

### Human Verification Required

None. This is an infrastructure/CI phase and active requirements close through executable tests, measurement receipts and exact-SHA CI evidence. Human UAT would not satisfy any requirement.

### Gaps Summary

The amended phase goal is achieved. The only uncompleted measurement is the original exact-ten CI timing target, which the explicit 2026-10-21 decision deferred unfinished to `SEED-261021-918` and assigned zero acceptance credit. The existing qualification manifest continues to say `blocked` for that original authority; this report independently verifies the currently active structural/exact-source CI criterion and retains the original blocked receipt unchanged.

---

_Verified: 2026-10-21T19:37:49Z_  
_Verifier: the agent (gsd-verifier)_
