---
phase: 138-lifecycle-failure-and-recovery-matrix
plan: 03
subsystem: testing
tags: [ffmpeg, ffprobe, av, oban, s3, repair]
requires: [138-02]
provides: [Real five-attempt AV failure, Public failed-work diagnosis and new-job repair, Full decoded derivative proof]
affects: [138-04, 138-06]
actuals: {tokens: 9362, tasks: 2, commits: 2}
tech-stack:
  added: []
  patterns: [Exact worker-temp post-download corruption, Committed natural-attempt polling]
key-files:
  created: []
  modified: [scripts/maintainer/built_package_twin.py, scripts/maintainer/twin_receipt.py, test/twin/host/lib/twin/storage.ex, test/twin/host/lib/twin/tracer.ex, test/twin/host/config/config.exs, test/install_smoke/twin_fault_test.exs, test/install_smoke/twin_receipt_test.exs]
key-decisions:
  - Store a fixed 4249-byte H.264/AAC fixture in the existing verifier owner; bind its actual SHA-256 before allocation.
  - Disable MuonTrap cgroups in this disposable Docker host using the existing supported install-smoke setting; preserve library defaults and FFmpeg limits.
patterns-established:
  - Restored downloads and a distinct new committed job are required before repair can pass.
requirements-completed: []
requirements-covered: [RECOV-03]
coverage:
  - id: AV-FAILURE
    description: Five actual malformed-worker-input failures discard the same normal media job and appear in public runtime_status.
    requirement: RECOV-03
    verification:
      - kind: e2e
        ref: /private/tmp/rindle-138-av-verified/receipt.json
        status: pass
    human_judgment: false
  - id: AV-REPAIR
    description: Public requeue creates a different job and a fully decoded ready H.264/AAC derivative.
    requirement: RECOV-03
    verification:
      - kind: e2e
        ref: /private/tmp/rindle-138-av-verified/receipt.json
        status: pass
      - kind: unit
        ref: test/install_smoke/twin_receipt_test.exs
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
independent_pilot_credit: false
---

# Phase 138 Plan 03: Real AV failure and supported repair

A valid video with audio fails through five ordinary attempts, is diagnosed publicly, and repairs through a new job into a fully decoded derivative.

## Accomplishments

- Fixed tiny H.264/AAC input, actual MinIO upload/promotion and one supported web_720p variant.
- The exact-source wrapper delegates real S3 download before corrupting only the worker's UUID temp path. Concurrent fast controls prove exact source/path selection, durable counting and restoration.
- Five ordinary errors, fault downloads and attempts are retained on a discarded job; the failed variant is reported as failed_work by public runtime_status using its supported string profile filter.
- After discard, downloads are restored and public requeue enqueues exactly one new job. Old job 2 and repaired job 3 are distinct; the latter completes at attempt one.
- Original source checksum remains unchanged. The declared derivative is ready, its error cleared, and ffprobe plus FFmpeg full audio/video decode succeed. Actual binary versions: {"ffmpeg": "7.1.5-0+deb13u1", "ffprobe": "7.1.5-0+deb13u1"}.

## Task Commits

1. `708aea38` — actual five-attempt AV failure and public diagnosis.
2. `ed0f8389` — new-job repair, output decode and closed typed verifier.

## Verification

- Final real `run --case av-repair --verify --cleanup`: exit zero, `/private/tmp/rindle-138-av-verified`.
- Subsequent independent CLI `verify --inputs ... --receipt ...`: exit zero.
- Five-attempt portion measured 96128 ms with 503872 ms remaining in its fixed 600000 ms deadline. No backoff, attempt or schedule changes.
- Fault-only probe at `/private/tmp/rindle-138-av-failure-observed` proved five failures plus diagnosis in 94483 ms; its receipt correctly stays incomplete/repair_pending, never full case acceptance.
- Focused fault/receipt tests: 10 tests, zero failures. Full Docker-free twin suite: 23 tests, zero failures.
- Red tests demonstrated absent corruption and absent AV verifier before implementation. Mutations reject fewer attempts, active retry as repair, missing new enqueue, changed identities/checksum, wrong derivative, absent audio/full decode and unsupported ready claims.
- `git diff --check`: clean.

## Deviations and Issues Encountered

The disposable host initially inherited Linux cgroup behavior that cannot execute against Docker's read-only cgroup filesystem. Existing generated install-smoke already sets RINDLE_AV_USE_CGROUPS=false; the host now uses the equivalent supported application setting. The diagnostic call initially supplied a module instead of the API's required profile string and was corrected. Original failed receipts/private output remain retained under `/private/tmp/rindle-138-av-failure`, `-diagnostic` and `-cgroup-setting`; their owned resources were separately disposed, without changing verdicts.

Input discriminator/fixture binding lands with task 1 so allocation/disposal can validate AV resources. Task 2 includes the minimal existing runner glue required to invoke repair and capture bounded ffprobe/FFmpeg output. No production API/schema/dependency or worker change.

## Next Phase Readiness

138-04 can implement the approved bounded provider-convergence correction. All RECOV requirements remain pending until the shared full six-case integration and current-source separate verification in 138-06. No independent-adopter, readiness, CI-speed or release credit. No user setup required.

## Self-Check: PASSED
