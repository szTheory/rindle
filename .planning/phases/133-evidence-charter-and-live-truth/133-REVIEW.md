---
phase: 133-evidence-charter-and-live-truth
reviewed: 2026-09-11T02:23:52Z
depth: standard
files_reviewed: 31
files_reviewed_list:
  - .github/actions/setup-elixir/action.yml
  - .github/workflows/ci.yml
  - .github/workflows/nightly.yml
  - .github/workflows/release.yml
  - RUNNING.md
  - config/ci_required_checks.json
  - examples/adoption_demo/docs/adoption-proof-matrix.md
  - scripts/ci/eval_nightly_incident.sh
  - scripts/ci/eval_nightly_summary.sh
  - scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh
  - scripts/ci/manage_nightly_incident.sh
  - scripts/ci/run_nightly_dialyzer.sh
  - scripts/ci/test_nightly_dialyzer.sh
  - scripts/ci/test_nightly_incident.sh
  - scripts/ci/test_nightly_summary_gate.sh
  - scripts/ci/test_verify_nightly_run.sh
  - scripts/ci/verify_nightly_run.sh
  - scripts/maintainer/check_adoption_proof_matrix.sh
  - scripts/maintainer/evidence_census.exs
  - scripts/maintainer/validate_evidence_census.exs
  - scripts/maintainer/validate_live_truth.exs
  - scripts/maintainer/validate_phase_133_reconciliation.exs
  - scripts/setup_branch_protection.sh
  - test/install_smoke/ci_cache_hygiene_test.exs
  - test/install_smoke/ci_lane_split_test.exs
  - test/install_smoke/evidence_census_test.exs
  - test/install_smoke/live_truth_parity_test.exs
  - test/install_smoke/nightly_policy_test.exs
  - test/install_smoke/phase_133_completed_validation_test.exs
  - test/install_smoke/phase_133_reconciliation_test.exs
  - test/install_smoke/support/generated_app_helper.ex
findings:
  critical: 5
  warning: 1
  info: 0
  total: 6
status: issues_found
---

# Phase 133: Code Review Report

**Reviewed:** 2026-09-11T02:23:52Z
**Depth:** standard
**Files Reviewed:** 31
**Status:** issues_found

## Summary

The strict Nightly result evaluator rejects missing, failed, cancelled, and malformed job evidence, and its focused shell suites pass. However, the surrounding evidence authorities still contain five ship-blocking integrity gaps: a diagnostic run can be attributed to the wrong dispatch, concurrent scheduled runs can corrupt the single-incident lifecycle, census inputs can escape through symlinks, package evidence is not bound to the repository release version, and a four-result package receipt is produced from only three executions. One additional warning concerns unbounded atom creation from decoded report data.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Same-second workflow history can be mistaken for the newly dispatched Nightly run

**File:** `scripts/ci/verify_nightly_run.sh:443-463`
**Issue:** The collector records a timestamp with only whole-second precision before dispatch, then accepts any matching run whose `createdAt >=` that timestamp. If an earlier diagnostic dispatch for the same ref/SHA was created in that same second, the first poll can select that pre-existing run and stop before GitHub exposes the run just dispatched by this process. A green receipt can therefore be attributed to the wrong dispatch while the actual requested run is still pending or later fails. The test for older history uses a run from an earlier hour and does not cover this boundary collision.
**Fix:** Snapshot the IDs of all matching runs before dispatch and select exactly one matching post-dispatch ID not present in that snapshot. Continue polling until that new ID appears; fail on multiple new IDs. Do not use second-resolution `createdAt` as the ownership token.

### CR-02: The rolling Nightly incident lifecycle has a check-then-act race

**File:** `scripts/ci/manage_nightly_incident.sh:20-26,56-65`
**Issue:** The script lists incidents, decides, and mutates in separate GitHub API calls. `nightly.yml` has no workflow-level concurrency serialization. Two overlapping scheduled runs (including reruns of a scheduled event) can both observe zero incidents and create duplicates, or an older green run can close an incident opened/updated by a newer red run. Once duplicates exist, future evaluations deliberately fail closed, leaving the lifecycle stuck and the public incident state inaccurate.
**Fix:** Serialize scheduled Nightly runs with a non-cancelling workflow concurrency group, and re-read/revalidate the exact-label incident set immediately before mutation. For close/update, verify that the issue still represents the expected prior state; for create, use a serialized owner or another uniqueness mechanism.

### CR-03: Detector input hashing follows symlinks outside the repository

**File:** `scripts/maintainer/evidence_census.exs:239-270`
**Issue:** `safe_relative_path/1` checks only lexical containment, after which `File.read/1` follows symlinks. A repository-relative detector input that is a symlink to `/tmp/...` or another external path is therefore accepted and hashed as authoritative repository evidence. Observation locations have a physical-containment check, but detector inputs do not. The independent validator repeats the same flaw at `scripts/maintainer/validate_evidence_census.exs:448-475`, so generation and validation agree on the escaped input instead of failing closed.
**Fix:** Resolve every path component physically before reading and require the resolved file to remain beneath the physical repository root, reusing the existing `physically_contained?/2` logic. Add a test with a detector input symlink that targets a file outside the fixture repository.

### CR-04: Package proof is not tied to the release version derived from the subject repository

**File:** `scripts/maintainer/validate_live_truth.exs:285-296,408-433`
**Issue:** Package validation ties `receipt.subject_sha` to `repository_root` HEAD, but it only checks `receipt.package_version` against the unrelated unpacked package's own `mix.exs`. The model's authoritative release version is never passed into `verify_package_evidence!/2`. Consequently, a receipt for HEAD can validate an old or otherwise unrelated unpacked Rindle package as long as the receipt, tree hashes, generated app, and caller-supplied results are internally consistent. The existing mutation test changes only the receipt version while leaving the package tree unchanged, so it does not exercise this cross-authority mismatch.
**Fix:** Pass `expected_version: model.version` (and preferably the expected source/package digest produced at that SHA) into the verifier and require `receipt["package_version"] == expected_version` in addition to checking the unpacked `mix.exs`. Add a test using a self-consistent package tree and receipt whose version differs from the repository model.

### CR-05: The receipt claims four command results from only three executions

**File:** `test/install_smoke/support/generated_app_helper.ex:342-347`
**Issue:** `package_evidence_receipt!/2` manufactures the `lifecycle` result by copying the single `smoke` result. The verifier requires four named results and unconditionally returns `lifecycle_proved: true`, so the receipt overstates independent execution: there is no separately attributable lifecycle command/result even though the schema presents one. A single successful test invocation is counted twice.
**Fix:** Either model the test invocation once (for example, one `smoke_and_lifecycle` result) or execute and capture a distinct lifecycle command. The verifier should derive `lifecycle_proved` only from that real result rather than setting it unconditionally.

## Warnings

### WR-01: Report-controlled strings are converted into permanent VM atoms

**File:** `test/install_smoke/support/generated_app_helper.ex:730-731`
**Issue:** `to_existing_atom_safe/1` calls `String.to_atom/1`, which creates a new permanent atom for every distinct decoded migration `resolver` string. Repeated malformed or externally influenced report values can grow the atom table until the BEAM VM terminates; the function name incorrectly suggests the safe existing-atom operation.
**Fix:** Use `String.to_existing_atom/1` with explicit error handling, or map an allowlisted set of resolver strings to known atoms without creating new ones.

---

_Reviewed: 2026-09-11T02:23:52Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
