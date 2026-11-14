---
phase: 139-exact-head-readiness-closure
reviewed: 2026-11-14T00:40:16Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - .github/workflows/release.yml
  - scripts/ci/install_ffmpeg.sh
  - scripts/ci/test_readiness_runs.sh
  - scripts/ci/test_verify_nightly_run.sh
  - scripts/ci/verify_nightly_run.sh
  - scripts/maintainer/live_residue_allowlist/automation_generators.json
  - scripts/maintainer/scan_live_residue.exs
  - scripts/maintainer/validate_exact_head_readiness.exs
  - scripts/maintainer/validate_live_truth.exs
  - scripts/maintainer/validate_phase_133_reconciliation.exs
  - test/install_smoke/ci_cache_hygiene_test.exs
  - test/install_smoke/ci_lane_split_test.exs
  - test/install_smoke/evidence_census_test.exs
  - test/install_smoke/live_residue_scan_test.exs
  - test/install_smoke/live_truth_parity_test.exs
  - test/install_smoke/phase_133_reconciliation_test.exs
  - test/install_smoke/quality_signal_policy_test.exs
  - test/install_smoke/release_guard_meta_test.exs
  - test/rindle/admin/queries_test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 139: Code Review Report

**Reviewed:** 2026-11-14T00:40:16Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Summary

Reviewed the Phase 139 source changes and their CI, release, and reconciliation call paths. The new exact-SHA CI evidence capture does not authenticate that the successful check was produced by GitHub Actions, so a same-name check from another app can be accepted as the required CI Summary.

## Critical Issues

### CR-01: BLOCKER — CI receipt accepts a check from the wrong GitHub App

**File:** `scripts/ci/verify_nightly_run.sh:656-667`
**Issue:** The receipt selector binds only `name == "CI Summary"` and `head_sha == expected_sha`, and validates success, but never checks the check run's `app.id`. The repository's exact-head readiness logic binds the required CI check to GitHub Actions app ID `15368` (`scripts/maintainer/validate_exact_head_readiness.exs:1045`, `:1090`), while this new path would accept an identically named successful check from any other app if it were the only matching check for that SHA. The phase reconciliation invokes this path as an authoritative validator (`scripts/maintainer/validate_phase_133_reconciliation.exs:879-890`), allowing non-CI evidence to be recorded as CI proof.
**Fix:** Require the check run's app identity to match the required-check policy before emitting a receipt, and include that identity in the receipt so later comparisons preserve the binding. For the repository's current policy, filter with `.app.id == 15368` and reject missing or different IDs.

## Warnings

---

_Reviewed: 2026-11-14T00:40:16Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
