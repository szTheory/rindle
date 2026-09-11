---
phase: 133-evidence-charter-and-live-truth
verified: 2026-09-11T02:34:41Z
status: gaps_found
score: 60/66 must-haves verified
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 17
  total: 17
  not_honored: []
re_verification:
  previous_status: gaps_found
  previous_score: 30/38
  gaps_closed:
    - "PLT deletion is confined to repository-owned physical priv/plts and escape cases are tested."
    - "Polling waits through unrelated runs and fails on multiple qualifying matches."
    - "Package/adopter maps use exact schemas, immutable digests, reconstruction, and an empty adopter allowlist."
    - "Local authority records and reconstructs census path, digest, blob, commit, detailed receipt, and live-truth digest."
    - "Applicable census dimensions retain independent detector authority and observation locations are contained."
    - "Release coupling and required-check truth derive from structured executable policy."
    - "The stale receipt was replaced and the exact-subject receipt revalidates."
  gaps_remaining: []
  regressions:
    - "Five additional evidence-integrity defects from the post-Plan-17 review are confirmed."
gaps:
  - truth: "The accepted diagnostic Nightly run is uniquely attributable to the collector's dispatch."
    status: failed
    reason: "Whole-second createdAt selection has no pre-dispatch run-ID exclusion, so a same-second pre-existing exact run can be selected."
    artifacts:
      - path: "scripts/ci/verify_nightly_run.sh"
        issue: "Filters ref/SHA/time but has no dispatch-ownership token."
      - path: "scripts/ci/test_verify_nightly_run.sh"
        issue: "No same-second pre-existing exact-run case."
    missing:
      - "Snapshot matching IDs before dispatch and accept exactly one new ID."
      - "Test same-second old and multiple-new runs."
  - truth: "Scheduled Nightly failure and recovery preserve one correctly ordered rolling incident under overlap."
    status: failed
    reason: "No workflow concurrency serializes list-decide-mutate; duplicates or stale closes are possible."
    artifacts:
      - path: ".github/workflows/nightly.yml"
        issue: "No non-cancelling incident-owner concurrency group."
      - path: "scripts/ci/manage_nightly_incident.sh"
        issue: "Inventory is not revalidated immediately before mutation."
    missing:
      - "Serialize scheduled mutation and enforce run ordering/current incident state."
      - "Add an automated overlap/interleaving regression."
  - truth: "Census detector inputs are repository bytes bound to the inspected immutable subject."
    status: failed
    reason: "Lexically relative detector inputs are read through symlinks outside the repository by producer and validator."
    artifacts:
      - path: "scripts/maintainer/evidence_census.exs"
        issue: "input_digests/2 reads without physical containment."
      - path: "scripts/maintainer/validate_evidence_census.exs"
        issue: "Independent validation repeats the same flaw."
    missing:
      - "Physically contain detector inputs before reading in both boundaries."
      - "Add an external-target input-symlink test."
  - truth: "Package proof is bound to the release version derived from the exact repository subject."
    status: failed
    reason: "The receipt version is checked only against the supplied unpacked package, not the authoritative repository model version."
    artifacts:
      - path: "scripts/maintainer/validate_live_truth.exs"
        issue: "Package verification receives no expected live-truth version."
      - path: "test/install_smoke/live_truth_parity_test.exs"
        issue: "No self-consistent stale-package fixture."
    missing:
      - "Cross-bind package version/source identity to the exact-subject model."
      - "Reject a self-consistent old package and receipt."
  - truth: "Compile, boot, smoke, and lifecycle package results are separately attributable evidence."
    status: failed
    reason: "The producer copies one smoke result into smoke and lifecycle slots; the verifier asserts lifecycle_proved unconditionally."
    artifacts:
      - path: "test/install_smoke/support/generated_app_helper.ex"
        issue: "command_results.smoke is written twice."
      - path: "scripts/maintainer/validate_live_truth.exs"
        issue: "Identical argv/results are counted as separate lifecycle proof."
    missing:
      - "Record one combined command or execute a distinct lifecycle command."
      - "Derive lifecycle proof and reject duplicated evidence."
---

# Phase 133: Evidence Charter and Live Truth Verification Report

**Phase Goal:** Maintainers can trust exact-head quality, Nightly, incident, release, support, and adoption evidence before any cleanup changes the baseline.
**Verified:** 2026-09-11T02:34:41Z
**Status:** gaps_found
**Re-verification:** Yes — after Plans 11–17 and fresh receipt collection

## Goal Achievement

Plans 11–17 close every blocker in the previous report, and the replacement receipt is real, current, exact-subject, and canonically revalidates. The phase goal is still not achieved: five confirmed integrity gaps allow correctly signed evidence to overclaim dispatch ownership, incident uniqueness/order, repository provenance, release-version identity, or independent lifecycle execution.

### Roadmap Success Criteria

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Exact-SHA census covers every dimension and assigns each candidate once | ✗ FAILED | Twelve dimensions/candidates and immutable ledger binding validate, but detector-input symlinks can source bytes outside the subject. |
| 2 | Supported Dialyzer passes fresh/restored and handles stale PLTs | ✓ VERIFIED | Run `34550391882` attempt 1 plus 34 runner cases prove exact patches/cache, fresh/restored, stale-only rebuild, and safe deletion. |
| 3 | Strict aggregation and one exact-run incident lifecycle fail closed | ✗ FAILED | The 49-case verdict is strong; overlapping schedules are not serialized and can violate incident uniqueness/order. |
| 4 | Executable parity rejects active claim contradictions | ✗ FAILED | Structured release/check/adopter truth works, but package version is not cross-bound and one execution is counted twice. |

**Roadmap score:** 1/4. **Merged PLAN score:** 60/66 truths verified (0 behavior-unverified).

## Original Gap Re-verification

| Previous gap | Status | Evidence |
|---|---|---|
| Arbitrary PLT deletion | ✓ CLOSED | Overrides reject; physical containment dominates reset; 34 cases pass. |
| Older runs abort polling | ✓ CLOSED | Zero/one/many polling and delayed history pass in the 109-case suite. |
| Forgeable package/adopter maps | ✓ CLOSED IN PART | Exact schemas/digests and empty allowlist work; new cross-authority gaps remain. |
| Mutable ledger | ✓ CLOSED | Ledger path/SHA-256/blob/commit/detailed receipt reconstruct from Git objects. |
| Mixed-applicability bypass | ✓ CLOSED | Applicable rows validate independently. |
| Inert release text | ✓ CLOSED | YAML structure and required-check policy are parsed and mutation-tested. |
| Stale receipt | ✓ CLOSED | Remote ref equals subject; canonical verifier accepts the requested receipt identity. |

## Required Artifacts, Links, and Data Flow

All declared files exist. The artifact/link checker passes every Plan 11–17 declaration. Older misses for literal helper names and Plan 04's transitive workflow → adapter → evaluator path are checker false negatives confirmed by code and passing suites.

| Flow | Status | Finding |
|---|---|---|
| Detectors → census → ledger Git object → receipt | ✗ HOLLOW | Immutable object binding exists; detector reads may follow external symlinks. |
| setup-beam/cache/logs → Dialyzer receipt | ✓ FLOWING | Exact supported identity plus fresh/restored evidence revalidates. |
| `needs`/policy → verdict → incident | ⚠ PARTIAL | Verdict is strict; mutation ordering is not serialized. |
| Dispatch → selector → receipt | ⚠ PARTIAL | Identity is exact, dispatch ownership is ambiguous at same-second boundary. |
| Built package/app → receipt → live truth | ✗ PARTIAL | Digests flow; release-version binding and distinct lifecycle execution do not. |
| Parsed release workflow/policy → active claims | ✓ FLOWING | Comment/dead/duplicate/mismatch fixtures reject. |

## Behavioral Spot-Checks

| Behavior | Result | Status |
|---|---|---|
| Dialyzer runner | 34 passed, 0 failed | ✓ PASS |
| Nightly verdict | 49 passed, 0 failed | ✓ PASS |
| Incident lifecycle | 22 passed, 0 failed | ✓ PASS, no overlap case |
| Run/receipt mutation suite | 109 passed, 0 failed | ✓ PASS, no same-second ownership case |
| Focused ExUnit authority files | 55 tests, 0 failures, 1 MinIO-tagged exclusion on diagnostic Elixir 1.19.5/OTP 28.4.1 | ✓ PASS for active cases |
| Remote receipt | ref `phase-133-evidence-08d2f4f55fb2` = `08d2f4f55fb2f59319a371de56606b2e925e6d54`; preflight and verify-receipt exit 0 | ✓ PASS under current schema |

## Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| EVID-01 | ✗ BLOCKED | Ledger/dedup/object binding work; detector input provenance can escape. |
| EVID-02 | ✓ SATISFIED | Exact supported fresh/restored/stale/cache/safe-reset and remote receipt evidence pass. |
| EVID-03 | ✓ SATISFIED | Exact job-set, applicability, unexpected-state, and required-context contracts pass. |
| EVID-04 | ✗ BLOCKED | Static cases pass; concurrent scheduled executions can violate the single incident. |
| TRUTH-08 | ✗ BLOCKED | Release/check/adopter claims derive; package version and lifecycle attribution can overclaim. |

Every requirement ID in Plans 01–17 exists in `REQUIREMENTS.md`, maps to Phase 133, and is accounted for. No Phase 133 requirement is orphaned.

## Prohibitions and Test Quality

Twenty of twenty-one descriptor-less prohibitions are satisfied by executable/static evidence. Plan 04's prohibition against competing rolling incidents is violated. Human publication authorization received no acceptance credit.

No requirement-linked test is disabled. The shell matrices are strong but omit same-second dispatch ownership and overlapping incident order. Census tests omit detector-input symlink escape. The package positive oracle is blocker-level circular evidence because it duplicates smoke as lifecycle and validates that same duplicate shape.

## Anti-Patterns and Review Findings

| Finding | Severity | Evidence |
|---|---|---|
| Same-second dispatch ownership | 🛑 BLOCKER | `createdAt >=` without pre-dispatch ID snapshot. |
| Incident check-then-act race | 🛑 BLOCKER | No concurrency; separate list/decision/mutation. |
| Detector-input symlink escape | 🛑 BLOCKER | Lexical check then symlink-following `File.read`. |
| Package/release version disconnect | 🛑 BLOCKER | Version checked only against supplied package. |
| Duplicated smoke/lifecycle result | 🛑 BLOCKER | One execution copied to two results. |
| Report-controlled atom creation | ⚠ WARNING | `to_existing_atom_safe/1` calls `String.to_atom/1`. |
| Unreferenced debt markers | None | No actionable marker in phase implementation files. |

## Decision Coverage

All 17 trackable context decisions are honored by shipped artifacts. This warning-only heuristic does not supersede confirmed defects.

## Deferred Item Filter

No blocker is deferred. Phases 134–139 consume or extend this baseline; none owns these producer fixes. Phase 139's readiness manifest cannot repair defective Phase 133 authority.

## Human Verification

N/A — infrastructure/evidence phase. Repository policy requires executable acceptance; human authorization or observation cannot satisfy these requirements.

## Gaps Summary

The receipt has exact subject `08d2f4f55fb2f59319a371de56606b2e925e6d54`, run `34550391882` attempt 1, ten green jobs, supported fresh/restored Dialyzer proof, immutable local authority, and unchanged diagnostic incident snapshots. It still certifies an insufficient authority model. Five implementation gaps block the trusted baseline.

---

_Verified: 2026-09-11T02:34:41Z_
_Verifier: the agent (gsd-verifier)_
