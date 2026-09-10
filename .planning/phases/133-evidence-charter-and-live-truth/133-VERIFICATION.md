---
phase: 133-evidence-charter-and-live-truth
verified: 2026-09-10T04:14:28Z
status: gaps_found
score: 26/29 must-haves verified
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 17
  total: 17
  not_honored: []
gaps:
  - truth: "Package-proof claims are accepted only with freshly built/unpacked/no-fallback provenance."
    status: failed
    reason: "A caller-controlled receipt field `validated: true` bypasses all generated-consumer provenance normalization and accepts nonexistent paths."
    artifacts:
      - path: "scripts/maintainer/validate_live_truth.exs"
        issue: "validate_package_claim!/2 trusts receipt.validated and skips normalize_package_receipt!/1."
      - path: "test/install_smoke/live_truth_parity_test.exs"
        issue: "Negative package fixtures never exercise the forged validated=true fast path."
    missing:
      - "Remove the caller-controlled validation bypass or replace it with an internal, unforgeable representation."
      - "Add a regression case proving a minimal validated=true map with nonexistent paths is rejected."
  - truth: "The final Nightly receipt independently binds every persisted remote and local evidence field to the exact implementation SHA."
    status: failed
    reason: "verify-receipt accepts forged job identities, timestamps, verdict provenance, incident snapshots, and local-authority payloads while still reporting the receipt valid."
    artifacts:
      - path: "scripts/ci/verify_nightly_run.sh"
        issue: "Revalidation compares only run_id and dialyzer evidence with live GitHub state; most persisted fields receive type/status checks only."
      - path: "scripts/ci/test_verify_nightly_run.sh"
        issue: "The 28-case matrix tests collection failures but has no per-field receipt-tampering matrix."
    missing:
      - "Reconstruct and compare every remotely reproducible receipt field, including created_at, exact sorted jobs, and strict-verdict source."
      - "Re-run or independently bind local authorities and incident snapshots, require exact key sets, and add field-by-field mutation tests."
  - truth: "The live collector accepts only the supported Elixir 1.17 / OTP 27 toolchain."
    status: failed
    reason: "Unanchored substring checks accept Elixir 11.17.0 and OTP 127.0 as the supported 1.17/27 cell."
    artifacts:
      - path: "scripts/ci/verify_nightly_run.sh"
        issue: "Collection uses unanchored Bash regexes and receipt shape validation uses contains(\"1.17\") / contains(\"27\")."
      - path: "scripts/ci/test_verify_nightly_run.sh"
        issue: "unsupported_toolchain covers missing output but not near-match versions."
    missing:
      - "Parse the setup-beam version formats and require anchored 1.17 and 27 boundaries in collection and revalidation."
      - "Add rejection cases for 11.17, 1.170, and 127."
---

# Phase 133: Evidence Charter and Live Truth Verification Report

**Phase Goal:** Maintainers can trust exact-head quality, Nightly, incident, release, support, and adoption evidence before any cleanup changes the baseline.
**Verified:** 2026-09-10T04:14:28Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

The phase is not ready to establish a trusted cleanup baseline. The normal-path evidence is substantial and the recorded live run is internally plausible, but two authority boundaries accept forged evidence and the supported-toolchain parser accepts near-match versions. Because the goal is trust in the evidence itself, these are goal-level failures even though the existing suites are green.

### Roadmap Success Criteria

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | Exact-SHA, twelve-dimension, deduplicated census with one disposition per candidate | ✓ VERIFIED | Ledger records subject `4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2`, 12 dimensions, 12 candidates, and 8 transitions; the focused census tests pass. |
| 2 | Supported fresh/restored Dialyzer succeeds and stale evidence is rejected or rebuilt | ✓ VERIFIED with blocker in final collector | The actual receipt records Elixir `v1.17.3-otp-27`, OTP `OTP-27.3.4.17`, one fresh build/analysis, one restored analysis, and zero rebuilds; the 24-case runner suite passes. However, the final collector also accepts unsupported near-match versions (Gap 3). |
| 3 | Strict Nightly aggregation and exact-run rolling incident lifecycle | ✓ VERIFIED with receipt-integrity blocker | The 49-case aggregate and 22-case incident suites pass, workflow wiring is fail-closed, and the recorded diagnostic run is attempt 1. Independent receipt revalidation does not protect most persisted evidence fields (Gap 2). |
| 4 | Executable release/planning/support/adoption parity rejects every contradiction | ✗ FAILED | Version and workflow topology checks are derived, but a forged `validated: true` package receipt bypasses package provenance (Gap 1). |

**Roadmap score:** 3/4 success criteria verified.  
**Merged PLAN truth score:** 26/29 truths verified (0 present-but-behavior-unverified).

### Failed PLAN Truths

| Plan | Truth | Status | Evidence |
|---|---|---|---|
| 133-05 | Package proof requires fresh built/unpacked/no-fallback evidence | ✗ FAILED | Direct invocation returned `:ok` for a minimal forged map with nonexistent paths. |
| 133-07 | The collector accepts only exact requested, supported, complete Nightly evidence | ✗ FAILED | A fake run reporting Elixir `11.17.0` and OTP `127.0` produced an accepted canonical receipt. |
| 133-07 | Final receipt binds local census/live-truth and remote Nightly facts to the same subject | ✗ FAILED | A receipt with forged jobs, timestamp, summary-job provenance, incidents, and authority fields passed `verify-receipt`. |

All other PLAN truths received existence, substantive implementation, wiring, and targeted behavioral evidence. No verification override exists.

## Required Artifacts

| Plan | Artifacts | Status | Details |
|---|---|---|---|
| 133-01 | Census collector, validator, and ExUnit contract | ✓ VERIFIED | Substantive modules are wired through subprocess tests; exact-SHA, taxonomy, candidate, disposition, and transition paths are exercised. |
| 133-02 | Dialyzer runner/tests, setup composite, Nightly workflow, failure fingerprint | ✓ VERIFIED | Fresh/restored runner and exact cache-key wiring exist; 24 behavior cases pass. |
| 133-03 | Strict summary evaluator/tests, parsed workflow test, Nightly workflow | ✓ VERIFIED | Evaluator is invoked from `nightly-summary`; its verdict is exported then enforced. |
| 133-04 | Incident evaluator/adapter/tests and workflow lifecycle | ✓ VERIFIED | `nightly.yml` invokes the adapter, which invokes `eval_nightly_incident.sh`; the plan's direct-link grep misses this intentional transitive wiring. The test script is substantive despite naming its helper differently from `expect_exit`. |
| 133-05 | Live-truth validator and parity tests | ✗ PARTIAL | Files are substantive and wired, but the package-receipt trust boundary is bypassable. |
| 133-06 | Adoption gate, active truth docs, and frozen census ledger | ✓ VERIFIED | Gate invokes derived/package tests before copy checks; active claims and ledger exist. |
| 133-07 | Exact-run collector/tests and Nightly receipt | ✗ PARTIAL | Normal collection and the real receipt exist, but independent receipt integrity and version boundaries fail. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Census collector | Census validator | Canonical observations/candidates/transition digest | ✓ WIRED | Collector output fields are consumed and mutation-tested. |
| Setup composite | Nightly Dialyzer | Resolved Elixir/OTP outputs in `plt-v3` key | ✓ WIRED | Exact outputs feed save and restore keys; no restore prefix is present. |
| Nightly jobs | Strict summary evaluator | `NEEDS_JSON` and policy JSON under `always()` | ✓ WIRED | Evaluator controls exported verdict and terminal enforcement. |
| Nightly lifecycle | Incident evaluator and adapter | Workflow -> `manage_nightly_incident.sh` -> `eval_nightly_incident.sh` | ✓ WIRED | Job-local `issues: write`; dispatch is policy-gated to no-op. |
| Adoption gate | Live-truth/package tests | Tagged authority tests | ⚠ PARTIAL | Normal path is wired, but public map input can impersonate normalized package proof. |
| Exact-run verifier | GitHub run/logs and receipt | Preflight, job-scoped logs, canonical JSON | ⚠ PARTIAL | Dialyzer is re-derived; jobs/timestamps/verdict source/incidents/local authorities are not independently rebound. |

## Data-Flow Trace (Level 4)

This is an infrastructure/evidence phase with no rendered dynamic UI. Evidence flow was traced instead:

| Artifact | Data | Source | Status |
|---|---|---|---|
| `133-EVIDENCE-CENSUS.json` | SHA, taxonomy, candidates, transitions | Git/repository detectors -> collector -> validator | ✓ FLOWING |
| Nightly verdict | Needs results and applicability outputs | GitHub Actions `needs` -> strict jq evaluator -> workflow conclusion/incident input | ✓ FLOWING |
| Package authority | Generated-consumer provenance | Helper report -> normalization -> claim validator | ✗ BYPASSABLE |
| `133-NIGHTLY-EVIDENCE.json` | Run/jobs/logs/incidents/local authorities | GitHub/local collectors -> JSON -> revalidation | ✗ PARTIALLY REBOUND |

## Behavioral Spot-Checks and Probe Execution

| Check | Result | Status |
|---|---|---|
| `bash scripts/ci/test_nightly_summary_gate.sh` | 49 passed, 0 failed | ✓ PASS |
| `bash scripts/ci/test_nightly_dialyzer.sh` | 24 passed, 0 failed | ✓ PASS |
| `bash scripts/ci/test_nightly_incident.sh` | 22 passed, 0 failed | ✓ PASS |
| `bash scripts/ci/test_verify_nightly_run.sh` | 28 passed, 0 failed | ✓ PASS |
| Focused ExUnit census/Nightly/live-truth set, excluding MinIO | 26 tests, 0 failures, 1 excluded | ✓ PASS |
| Exact remote ref preflight and current receipt verification | Remote ref matched; run `34432289094`, attempt 1 reported valid | ⚠ PASS THROUGH INCOMPLETE VERIFIER |
| Forged package receipt | `validate_claims!/2` returned `:ok` for nonexistent paths | ✗ FAIL |
| Forged persisted Nightly receipt | `verify-receipt` printed `Nightly receipt valid` | ✗ FAIL |
| Near-match toolchain | Elixir `11.17.0` / OTP `127.0` receipt was accepted | ✗ FAIL |

The green normal suites do not cover the three adversarial acceptance paths above.

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
|---|---|---|---|
| EVID-01 | 133-01, 133-06, 133-07 | ✓ SATISFIED | Exact-SHA census schema, 12-dimension frozen ledger, stable candidates/transitions, and passing focused tests. |
| EVID-02 | 133-02, 133-06, 133-07 | ⚠ PARTIAL / BLOCKING | Actual supported run and stale-rebuild policy pass, but the final authority collector accepts near-match unsupported versions. |
| EVID-03 | 133-03, 133-06, 133-07 | ✓ SATISFIED | 49-case exact-set evaluator and parsed workflow enforcement reject failed/cancelled/unexpected/impermissible-skip states. |
| EVID-04 | 133-04, 133-06, 133-07 | ✓ SATISFIED | 22-case pure/fake-CLI lifecycle proves one incident, exact-run update/close, no-op dispatch, and duplicate failure. |
| TRUTH-08 | 133-05, 133-06, 133-07 | ✗ BLOCKED | Package/adoption proof can be authorized by a caller-forged validated receipt. |

All five requirement IDs declared across PLAN frontmatter are present in `REQUIREMENTS.md`; no Phase 133 requirement is orphaned.

## Test Quality Audit

| Test file | Linked requirement | Active | Skipped | Circular | Assertion level | Verdict |
|---|---|---:|---:|---|---|---|
| `evidence_census_test.exs` | EVID-01 | 11 focused cases represented | 0 | No | Behavioral/value | Strong |
| `test_nightly_dialyzer.sh` | EVID-02 | 24 | 0 | No | Behavioral command/order/count | Strong, missing near-match collector case |
| `test_nightly_summary_gate.sh` | EVID-03 | 49 | 0 | No | Behavioral truth table | Strong |
| `test_nightly_incident.sh` | EVID-04 | 22 | 0 | No | Behavioral mutation/order | Strong |
| `live_truth_parity_test.exs` | TRUTH-08 | Active focused cases | 0 | No | Behavioral/value | Insufficient at caller-controlled `validated` discriminator |
| `test_verify_nightly_run.sh` | EVID-02/03/04 | 28 | 0 | No | Behavioral fake-CLI | Insufficient for persisted-field tampering and near-match versions |

**Disabled requirement tests:** 0.  
**Circular oracle patterns:** 0.  
**Insufficient assertion surfaces:** 3, corresponding to the reproduced gaps.

## Prohibition Review

The PLAN files declare 14 descriptor-less, unresolved prohibitions. No human judgment was credited. Executable policy tests substantively cover the census mutation boundary, narrow stale retry, strict skip semantics, scheduled-only incident mutation, immutable history, and active-claim wording. Two prohibitions are observably violated:

- Package/adoption evidence can be overstated through `validated: true` without generated-consumer provenance.
- The live collector can accept an unsupported near-match toolchain, and its persisted receipt can carry forged partial provenance.

These failures are included in the structured gaps rather than silently treated as passed.

## Anti-Patterns Found

| File | Pattern | Severity | Impact |
|---|---|---|---|
| Phase implementation files | Unreferenced `TBD` / `FIXME` / `XXX` | None | No blocker debt markers found. |
| `.github/workflows/ci.yml` | `dryrun-placeholder` | Info | Existing bounded dry-run credential placeholder, not a Phase 133 implementation stub. |
| Test files | Temporary-file cleanup and fixture writes | Info | Test infrastructure; no circular expected-value generation was found. |

## Decision Coverage

All 17 trackable `133-CONTEXT.md` decisions are referenced by shipped artifacts. This non-blocking coverage result does not override the behavioral gaps.

## Deferred Item Filter

No gap is deferred. Phases 134–139 cover dependency/inbox disposition, cleanup, ratchets, twin/recovery work, and final readiness; none explicitly owns repairing Phase 133's package or exact-run evidence validators.

## Human Verification

N/A — infrastructure/evidence phase with no user-facing surface. Under the repository's automation-first contract, human observation cannot close these gaps; executable negative tests and implementation fixes are required.

## Gaps Summary

Three must-have truths fail. The first lets callers forge package/adoption authority. The second makes the stored Nightly receipt independently unverifiable for most of its contents. The third allows unsupported near-match toolchains to be labeled as the supported cell. Until these fail closed, maintainers cannot rely on Phase 133 as the immutable evidence baseline promised by the phase goal.

**Next action:** create and execute Phase 133 gap-closure plans with `$gsd-plan-phase 133 --gaps`, then re-run phase verification.

---

_Verified: 2026-09-10T04:14:28Z_  
_Verifier: the agent (gsd-verifier)_
