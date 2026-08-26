---
phase: 132-measured-closure
reviewed: 2026-08-26T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - scripts/ci/collect_pr_timing_receipt.sh
  - scripts/ci/install_apt_packages.sh
  - scripts/maintainer/automation_first_contract.sh
  - scripts/maintainer/repo_hygiene_check.sh
  - test/install_smoke/automation_first_contract_test.exs
  - test/install_smoke/ci_cache_hygiene_test.exs
  - test/install_smoke/ci_timing_automation_test.exs
  - test/install_smoke/generated_app_smoke_test.exs
  - test/install_smoke/support/generated_app/workspace.ex
  - test/install_smoke/support/generated_app_helper.ex
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 132: Code Review Report

**Reviewed:** 2026-08-26T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

The CI timing controller, maintenance checks, and generated-app smoke refactor were reviewed in context. The timing controller can report a cached receipt as passing without checking it against GitHub, and the generated-app proof has two false-positive/unsafe report-conversion paths.

## Critical Issues

### CR-01: Completed-state shortcut accepts a forged or stale timing receipt

**File:** `scripts/ci/collect_pr_timing_receipt.sh:285`
**Issue:** When the SHA-scoped state file says `status: complete` and `verdict: PASS`, `run` calls only `verify_current_receipt_shape` and exits successfully. That verifier checks internal JSON/table consistency, but does not call GitHub or apply the timing thresholds. Thus a stale or modified `.gsd/ci-timing/pr-…json` plus a syntactically valid receipt can cause the controller to claim a passing API-backed CI-14 receipt, even if the selected runs no longer qualify or the receipt was fabricated. `verify_api_backed_receipt` already implements the required live validation but is not used here.
**Fix:** On the completed-state path, call `verify_api_backed_receipt "$receipt"` (and derive/pass the verdict from validated metrics), or remove the shortcut and always validate the receipt against the Actions API before returning success.

## Warnings

### WR-01: Doctor readiness is derived from the smoke test, not the doctor command

**File:** `test/install_smoke/support/generated_app_helper.ex:155`
**Issue:** `doctor_result` is collected at lines 102-107, but `doctor_ready?` is set from `smoke_result.exit_code`. An isolation-upgrade smoke test can pass while `mix rindle.doctor` fails, yet the report and its assertion at `generated_app_smoke_test.exs:762` claim doctor readiness. This invalidates the intended doctor-evidence assertion.
**Fix:** Set the field from the command actually being proved: `doctor_ready?: doctor_result.exit_code == 0`; retain `doctor_output` for diagnostics and add a unit test where doctor fails while smoke succeeds.

### WR-02: JSON-controlled resolver value creates atoms indefinitely

**File:** `test/install_smoke/support/generated_app_helper.ex:604`
**Issue:** `to_existing_atom_safe/1` calls `String.to_atom/1`, which creates a new VM atom for every distinct resolver value read from the generated report. The function name asserts the opposite behavior. A corrupted or unexpected report can exhaust the atom table and terminate the test VM.
**Fix:** Keep the value as a string, or explicitly whitelist known resolver values, e.g. `"host_migrations" -> :host_migrations`; reject all others. If conversion is necessary, use `String.to_existing_atom/1` with controlled error handling only after validating the allowed set.

---

_Reviewed: 2026-08-26T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
