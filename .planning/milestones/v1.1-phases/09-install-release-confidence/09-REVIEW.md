---
phase: 09-install-release-confidence
reviewed: 2026-04-28T17:10:33Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - mix.exs
  - test/install_smoke/generated_app_smoke_test.exs
  - test/install_smoke/support/generated_app_helper.ex
  - scripts/install_smoke.sh
  - .github/workflows/ci.yml
  - .github/workflows/release.yml
  - README.md
  - guides/getting_started.md
  - test/install_smoke/docs_parity_test.exs
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-04-28T17:10:33Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Re-reviewed the Phase 09 install-smoke, workflow, and docs changes against current `HEAD` after the follow-up fix commit. The earlier package-boundary issues are resolved: `mix.exs` now ships the `guides/` directory in the Hex artifact, and the release workflow reuses the already-unpacked package by setting `RINDLE_INSTALL_SMOKE_PACKAGE_ROOT` before invoking `scripts/install_smoke.sh`.

I verified the current docs drift gate with `mix test test/install_smoke/docs_parity_test.exs` and rebuilt the package with `mix hex.build --unpack --output /tmp/rindle-review-artifact/rindle` to confirm the shipped artifact now includes `README.md`, `guides/getting_started.md`, and the rest of the guide set. I did not run the full MinIO/Postgres smoke harness in this pass.

## Info

### IN-01: Generated Install Smoke Leaves Temporary Databases Behind

**File:** `test/install_smoke/support/generated_app_helper.ex:23-35`
**Issue:** `prove_package_install!/0` creates a uniquely named PostgreSQL database for each generated consumer app run, but `cleanup/1` only removes the temp workspace directory and never drops `report.database_name`. Repeated local or CI-adjacent runs will accumulate `rindle_smoke_app_*_test` databases over time, which is noisy and can eventually interfere with developer environments.
**Fix:** Extend `cleanup/1` to drop the generated database with the same connection env used during setup, for example by invoking `mix ecto.drop` in the generated app or issuing a direct `DROP DATABASE` against `report.database_name` after the smoke run completes.

---

_Reviewed: 2026-04-28T17:10:33Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
