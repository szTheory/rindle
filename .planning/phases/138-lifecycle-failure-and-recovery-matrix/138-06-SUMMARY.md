---
phase: 138-lifecycle-failure-and-recovery-matrix
plan: 06
subsystem: testing
tags: [package-consumer, cleanup, oban, receipts, recovery]
requires: [138-01, 138-02, 138-03, 138-04, 138-05]
provides: [Real interrupted maintenance recovery, Independently verified six-case matrix, Complete pre-disposal audit]
affects: [139]
actuals: {tasks: 3, commits: 5}
tech-stack:
  added: []
  patterns: [Repo-only maintenance role, Closed pre-disposal inventory, Whole-matrix cleanup preflight]
key-files:
  created: []
  modified:
    - scripts/maintainer/built_package_twin.py
    - scripts/maintainer/twin_receipt.py
    - scripts/maintainer/twin_cleanup.py
    - test/twin/host/lib/twin/storage.ex
    - test/twin/host/lib/twin/tracer.ex
    - test/twin/host/lib/twin/application.ex
    - test/install_smoke/twin_receipt_test.exs
    - test/install_smoke/twin_cleanup_test.exs
    - test/install_smoke/twin_cli_test.exs
    - guides/built_package_twin.md
    - RUNNING.md
    - lib/rindle/workers/mux_ingest_variant.ex
    - lib/rindle/workers/mux_sync_provider_asset.ex
    - test/rindle/workers/mux_sync_provider_asset_test.exs
    - scripts/maintainer/credo_complexity_baseline.json
    - scripts/maintainer/readability_changes.json
key-decisions:
  - Freeze the exact six-case domain verdict and stopped-writer inventories before infrastructure disposal.
  - Require all child cleanup preflights before mutating any child, then recheck each resource owner.
  - Wait for normal Oban peer ownership after SIGKILL before graceful shutdown; never delete or weaken the lease.
requirements-completed: []
requirements-covered: [RECOV-01, RECOV-02, RECOV-03, RECOV-04, RECOV-05, RECOV-06]
coverage:
  - id: FULL-RECOVERY-MATRIX
    description: One fresh archive completes all six cases and exact stopped-writer audits before disposal.
    verification:
      - kind: e2e
        ref: /private/tmp/rindle-138-matrix-verified/receipt.json
        status: pass
      - kind: unit
        ref: test/install_smoke/twin_receipt_test.exs
        status: pass
    human_judgment: false
  - id: INTERRUPTED-JANITOR
    description: Real expired multipart part and post-object-delete maintenance death converge through two supported reruns.
    requirement: RECOV-06
    verification:
      - kind: e2e
        ref: /private/tmp/rindle-138-matrix-verified/receipt.json
        status: pass
      - kind: unit
        ref: test/install_smoke/twin_cleanup_test.exs
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
independent_pilot_credit: false
---

# Phase 138 Plan 06: Complete lifecycle recovery evidence

One fresh package archive now supports all six isolated recovery cases, strict independent verification and complete pre-disposal accounting.

## Task Commits

1. `a0b52e24` — Tasks 1–2: real maintenance interruption, closed six-case matrix, independent audits and safe cleanup.
2. `235f07db` — Task 3 prerequisite: equivalent private provider persistence helpers satisfy the existing nesting gate.
3. `f506a89c` — Task 3: operator CLI/docs, two evidence-backed baseline reductions, readability trace and bounded scope clarification.
4. `8d9a8a68` — Task 3: remove five newly introduced planning references from live docs/help; preserve CLI behavior.
5. `c4cf0742` — Task 3 integration correction: observe normal Oban peer takeover before stopping the replacement host for audit.

Tasks 1–2 share one cohesive commit because the final case supplies the typed observations consumed by the matrix verifier; neither receives partial full-matrix credit.

## Verification

- Acceptance implementation subject: `c4cf0742a043dd1f8fb8cd44ca29acad7ea083cc`.
- Fresh `run --evidence-dir /private/tmp/rindle-138-matrix-verified --verify --cleanup`: exit zero, `PASSED run: complete`.
- Separate process `verify --inputs /private/tmp/rindle-138-matrix-verified/inputs.json --receipt /private/tmp/rindle-138-matrix-verified/receipt.json`: exit zero, `PASSED verify: complete`.
- Repeated `cleanup --descriptor /private/tmp/rindle-138-matrix-verified/resources.json`: exit zero. Frozen receipt remains independently valid after disposal.
- Six ordered cases all complete: tus-resume, purge-absence, av-repair, provider-events, promotion-restart and interrupted-cleanup. All use the same archive checksum, with distinct child run IDs. Root verdict is frozen and every host exited.
- Measured full local runtime: 342727 ms (5 minutes 42.727 seconds), including build and all six case/audit work through verdict freezing, excluding final infrastructure disposal. No numeric CI-speed credit.
- Each stopped-writer audit has empty lifecycle domain rows, objects, uploads, parts, temp files, peers and processes; exact infrastructure catalog and migration ledgers are retained. Exact allowed Oban histories contain respectively 3, 3, 4, 8, 3 and 2 jobs, with IDs/queue/asset/event/attempt/error predicates rather than broad count allowances. Fixture counters have exact source/run ownership.
- Cleanup exercises genuine expiry of a real multipart part, supported abort then remote janitor cleanup, and an exact-key storage-delete barrier. Only the maintenance BEAM is killed at exit 137 after object deletion but before session-row deletion; the main host remains healthy. Two fresh supported janitor runs converge on the same resources.
- Fast controls reject omitted/skipped/duplicate/swapped cases, unknown fields/relations/jobs/fixtures, incomplete or denied inventory, secrets, foreign resources, bind/foreign mounts and active runtimes. An actual active full-matrix cleanup attempt refused before mutation at `/private/tmp/rindle-138-matrix-active-cleanup.json`.
- Final `mix ci`: exit zero; quality/public-contract/complexity and generated-style sentinels present; **3 doctests, 1748 tests, 0 failures, 87 excluded, 4 skipped**. Quality helper also ran 97 tests with zero failures. Private log: `/private/tmp/rindle-138-mix-ci-final.txt`.
- Focused twin/public-surface/quality-policy/CI-lane suite: 79 tests, zero failures. Final residue/CLI regressions: 36 tests, zero failures. Post-peer-fix cleanup/tracer controls: 14 tests, zero failures. Provider concurrency suite: 49 tests, zero failures, repeatedly, without new committed fixture residue.
- Existing hygiene check: 10 PASS, 1 WARN, 0 BLOCK; warning is unavailable latest Hex index, not a weakened gate. Python syntax, format, diff and automation-first checks pass.

## Deviations and Issues Encountered

- The original full run at `/private/tmp/rindle-138-matrix-accepted` correctly remained incomplete when SIGKILL left the ordinary Oban peer lease until normal takeover. Its receipt is preserved. The fix waits for normal current-node peer ownership before graceful stop, with no direct lease deletion, forced expiry or altered retry policy.
- Maintenance uses a Repo-only fixture startup role so supported Mix tasks do not start duplicate endpoint/Oban supervisors. The standard abort task marks expiry; the cleanup task performs remote multipart abort. This distinction is recorded in the plan and evidence.
- A valid indented full receipt exceeded the old 65536-byte limit. The finite limit is now 262144 bytes while exact shape/count/value checks remain enforced.
- Mandatory quality checks required equivalent private helpers and a provider-test cleanup helper. Current-head executable evidence justified removing exactly two resolved existing baseline entries and recording their readability anchors; no new baseline debt or disabled checks.
- Existing default test database contained 18 pre-existing committed rows from earlier faulty fixture setup. They were preserved; final CI uses the supported isolated `MIX_TEST_PARTITION=_phase138_8d9a8a68`. Corrected provider fixtures use the actual struct UUID and exact cleanup assertions, independently checked for zero new rows.
- A previous CI run crossed a verified 954-second macOS thermal sleep and then failed five time-sensitive LocalPlug checks. The exact VM/OS signing-clock delta was not directly captured. A fresh VM with the idle-sleep assertion passed unchanged token lifetimes and tests after Docker finished. No security contract was relaxed.

## Threat Flags

No unresolved implementation threat flags. Retained raw process captures and credentials stay private (0700 directories, 0600 files); exported receipts and CLI status remain allowlisted. Descriptor/label/mount/liveness/foreign-user guards and complete matrix preflight precede disposal. No force/prune command is introduced.

## Next Phase Readiness

All six RECOV requirements now have automated evidence ready for the normal GSD validation/security/review/goal-verification gates. Requirements are deliberately not marked complete by this plan summary. Public API/schema, root lock, dependency tree and CI required contexts are preserved. No independent pilot, Doctor pass, readiness, merge, release or deferred speed-target credit is claimed. Doctor migration-ledger correction and readiness closure remain Phase 139.

## Self-Check: PASSED
