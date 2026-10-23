---
phase: 137-built-package-twin-foundation
plan: 01
subsystem: testing
tags: [phoenix, oban, docker, synthetic]
requires: []
provides: [external-package lifecycle tracer, committed retry and host replacement]
affects: [137-02, 137-03, 137-04, 137-05, 137-06]
actuals: {tokens: 11000, tasks: 2, commits: 2}
key-files:
  created: [scripts/maintainer/built_package_twin.py, docker/Dockerfile.twin, docker/compose.twin.yml, test/twin/host/lib/twin/tracer.ex, test/install_smoke/twin_tracer_contract_test.exs]
  modified: []
requirements-completed: []
duration: 80min
completed: 2026-10-21
status: complete
coverage:
  - id: tracer
    description: One real external packaged image lifecycle and between-attempt runtime replacement
    verification:
      - {kind: e2e, ref: /private/tmp/rindle-twin-tracer-137-feedback/receipt.json, status: pass}
    human_judgment: false
---

# Phase 137 Plan 01 Summary

Maintainer-operated synthetic evidence; independent_pilot_credit: false.
One fresh archive produced a ready image variant, one attach/final detach, a committed
retryable purge attempt one, paused/no-running/fresh-row barrier, observed old runtime
exit, new container/boot, and ordinary same-job completion at attempt two. Source
purge consumed exactly one persisted fault. All domain rows, objects, multipart
uploads, temp files and host processes were absent before infrastructure disposal;
only one migration marker and three completed Oban history rows remained.

## Task Commits

1. Task 1 — `89a3472f`: minimal pinned host, fresh tar, real lifecycle/retry/restart and cleanup.
2. Task 2 — `a1ff6982`: raced barrier and duplicate stimulus controls.

## Verification

- First successful real run: `/private/tmp/rindle-twin-tracer-137-ninth`.
- Separate verify with explicit inputs and receipt: exit 0.
- GSD tracer feedback run: `/private/tmp/rindle-twin-tracer-137-feedback`, exit 0 including disposal.
- Canonical fast tests: 4 tests, 0 failures; Python syntax and diff checks passed.
- No default fast test boots Docker. Later hardening plans and all TWIN requirements remain open.

## Deviations and Issues Encountered

Docker disk exhaustion required user-approved unused build-cache cleanup (4.524 GB).
Automatic review first refused timestamp-selected cache cleanup; no rejected action ran.
Containers/volumes/tagged images were preserved by the approved cache prune.
The host explicitly starts Phoenix PubSub before Rindle and uses a UUID owner.
Only two existing demo-pinned transport lock entries were added to the host lock;
root dependencies/tool versions/support claims are unchanged. Smaller libvips runtime
package suffices for the actual image trace. The versioning parser uses observed
MinIO JSON, not text heuristics. Failed receipts remain unchanged at their original
exclusive evidence paths. No recovery plan or new dependency framework was created.

## Self-Check: PASSED

All 14 declared paths exist. Both task commits are reachable. Real trace, separate
verification, feedback gate and negative controls passed. This proves only controlled
between-attempt restart; no AV, independent pilot, timing or readiness claim.
