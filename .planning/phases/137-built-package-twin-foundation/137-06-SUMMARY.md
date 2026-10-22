---
phase: 137-built-package-twin-foundation
plan: 06
subsystem: testing
tags: [synthetic, cli, docs, regression]
requires: [137-02, 137-03, 137-04, 137-05]
provides: [documented operator CLI, phase-wide executable acceptance]
affects: [138, 139]
actuals: {tokens: 10000, tasks: 2, commits: 4}
key-files:
  created: [guides/built_package_twin.md, test/install_smoke/twin_cli_test.exs]
  modified: [scripts/maintainer/built_package_twin.py, RUNNING.md, mix.exs, test/twin/host/lib/twin/storage.ex]
requirements-completed: [TWIN-01, TWIN-02, TWIN-03, TWIN-04, TWIN-05, TWIN-06]
completed: 2026-10-21
status: complete
---

# Phase 137 Plan 06 Summary

Maintainer-operated synthetic evidence; independent_pilot_credit: false.
Four discoverable operations, explicit retained verification inputs, safe text or
single JSON results, nonzero failed/incomplete/blocked statuses, bounded execution
and concrete reproduction/cleanup guidance are implemented. The guide renders under
the Maintainer section and its RUNNING link resolves in generated HTML.

## Task Commits

1. `4c3ab08d`: CLI/result contract and direct staged-source shortcut guard.
2. `fc2c9901`: operator guide and RUNNING entry.
3. `4a894ae2`: review fix — digest before parsing; bounded archive expansion/member count.
4. `34e2ce4f`: regression fixes — flattened adapter branching, serial CLI fixture tests,
   and ExDoc inclusion/link under Maintainer.

## Verification

- Frozen implementation subject: `34e2ce4f3588f7691f9fb311ca6f9fae93fcfba1`.
- Canonical full default suite: **1717 tests, 3 doctests, 0 failures, 87 excluded,
  4 skipped**, 253.1 seconds. Output: `/private/tmp/rindle-137-stable-full-tests.txt`.
- Focused twin + named CI/public-surface regression command: 60 tests, 0 failures.
- Real final run: `/private/tmp/rindle-twin-137-stable-umor3huw`; run, separate explicit-inputs verifier and
  repeated stopped-host cleanup each exit 0. Observed local run duration:
  **53.979 seconds**. This single local observation grants no CI speed credit.
- Format, reviewed Credo quality/complexity, artifact ledger, automation-first and
  diff checks passed. Docs build exit 0; new guide link verified. Existing unrelated
  ExDoc reference warnings remain, with no new warning-clean claim.
- No CI workflow/required-context/release coupling or public-surface fixture change.

## Deviations and Issues Encountered

The first full suite found new adapter nesting and an async fixture file-write
classification; both were fixed within existing gates, without baseline growth.
Its package-authority mismatch arose while packaged docs were changing during the
run; the exact case passed on a stable tree, then the full stable suite passed.
The original failed log remains intact. No frozen historical receipt was edited.
Added runtime source guards in the parent to enforce private/manual/source-read
refusals during `run`, supplementing drift tests. The archive review fix adds finite
64 MiB compressed/expanded material and 10000-member bounds. Root mix.exs changes
only docs registration/grouping; dependency declarations and lock are unchanged.
Public Doctor migration-ledger false failure remains an explicit deferred defect.

## Self-Check: PASSED

All six plans' runtime and fast controls executed. Real acceptance and separate
verification passed on stable committed source. This closes the foundation only;
full recovery matrix, aggregate readiness, independent adoption and numeric CI speed
remain outside its acceptance. No publication, merge or release action occurred.
