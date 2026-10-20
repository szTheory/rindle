---
phase: 136-measured-quality-and-ci-ratchets
plan: 05
status: complete
subsystem: ci
tags: [integrity, timeout, fork-safety, release]
requires:
  - phase: 135
    provides: Verified prerequisite and current workflow baseline
provides:
  - Dated FFmpeg archive with checksum verification before extraction
  - MinIO client architecture checksums and pinned browser image
  - Reviewed job timeouts and consumer-scoped mutation tests
  - Executable exact-SHA release gate regression
affects: [136-contributor-bootstrap, 136-final-timing]
tech-stack:
  added: []
  patterns: [immutable tool inputs, parsed consumer policy]
key-files:
  created: []
  modified:
    - scripts/ci/install_ffmpeg.sh
    - .github/actions/setup-minio/action.yml
    - .github/workflows/ci.yml
    - .github/workflows/nightly.yml
    - test/install_smoke/ci_cache_hygiene_test.exs
    - test/install_smoke/quality_signal_policy_test.exs
key-decisions:
  - Existing digest-pinned MinIO image remains unchanged; verify copied client bytes before install.
  - Dated FFmpeg download fails closed on expired or changed upstream bytes; update URL and reviewed digest together.
  - Disposable Postgres 16-alpine fixture services explicitly retain patch-tracking tags; executable tool images are digest-pinned.
requirements-completed: [CI-15, CI-16]
coverage:
  - id: input-integrity
    description: Verified archive and binary copy paths with mismatched-byte refusal
    verification:
      - kind: unit
        ref: mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/quality_signal_policy_test.exs --seed 0
        status: pass
    human_judgment: false
  - id: topology
    description: Parsed bounds/cache/actions/fork mutations and exact-SHA release execution
    verification:
      - kind: unit
        ref: mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs --seed 0
        status: pass
      - kind: unit
        ref: bash scripts/ci/test_ci_summary_gate.sh
        status: pass
      - kind: unit
        ref: bash scripts/ci/test_nightly_summary_gate.sh
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-10-20
---

# Phase 136 Plan 05: CI Integrity and Time Bounds

The FFmpeg installer consumes a dated reviewed asset and verifies its SHA-256 before extraction. MinIO retains the existing image digest, checks architecture-specific mc bytes before privileged install, and both browser jobs use the measured Playwright image digest. Every CI and Nightly job has a documented timeout budget.

## Accomplishments

- Good/bad archive fixtures execute the actual FFmpeg entrypoint; mismatches never reach tar or install. Moving release overrides fail closed.
- Good amd64/arm64 client fixtures and a bad-byte fixture execute the actual composite step; bad bytes never reach install.
- Parsed YAML mutation matrix covers each job timeout, MinIO digest/client checksums, actual cache consumers, pinned actions and browser image consumers.
- Sole CI/ci.yml/CI Summary authority, read-only fork permissions, unconditional fork browser smoke and release publish dependency are mutation-tested.
- The actual release-gate JavaScript runs under fake GitHub responses: exact successful SHA passes, wrong-SHA success and failed conclusions fail. A weakened filter exposes wrong-SHA success, and an unbound lookup is rejected.

## Task Commits

1. RED f610ca97; GREEN 28a72b95 — verified FFmpeg archive.
2. RED ba0c73d0; GREEN 00ecf7c1 — input consumers, job bounds and mutations.
3. c2ccbc91 — existing fork/release behavior characterization (test-only).

## Verification

- Combined focused suites: 59 tests, 0 failures on Elixir 1.17.3 / OTP 27.3.4.15, MIX_ENV=test.
- CI Summary harness: passed 6, failed 0. Nightly Summary harness: passed 49, failed 0.
- Both preserved JUnit RED reports return RED_EVIDENCE_OK on their intended assertion failures.
- Actionlint: two pre-existing matrix.elixir undefined-property findings before and after; zero new findings. Not claimed globally clean.
- Bash syntax and whitespace checks passed.

## Input Provenance

- BtbN release autobuild-2026-10-20-13-08, asset 659366397, ffmpeg-n9.0.2-29-g6dfaba896f-linux64-gpl-9.0.tar.xz. Actual 144 MiB download SHA-256 6a40dd0b5a020854573aa8bf11449694fabd4fdff1be09b43f6713ca8a2abab1 independently matches GitHub asset metadata and upstream checksums.sha256.
- MinIO parent sha256:2136d593beacf4461187035eca949fe49abd589d5079735025c711ca58fee0c8 unchanged. Registry manifest child amd64 8d66c6b9ce8996091d841d768a88b4255faf0c25fa8de257d832ea4c27d08395 yields mc f06aa7f9d4a333b9481dcb9859bb2f6da5b4345b67f2cc7ac1c982f0c7cdd06c. Arm64 child 0d5ed225307de9bdbc53fa56186892a34abd00f0181798cceb02e65b1f623805 yields mc 160b34eaae2e32c4cce8784162a20b4449ed7e31210bf940e4698c030194f897. Each measured from a private stopped container; both containers removed without execution.
- Playwright v1.57.0-noble registry manifest digest 3bed4b1a12f2338642f3d8cba28e291deef3c66bd4a964bbeb3e57bbff511dbd.

## Deviations and Limits

MinIO was already digest-pinned on accepted main, so no speculative repin. macOS sha256sum requires a checksum file rather than stdin; portable file-based validation is fixture-proven. Existing release topology needed additional characterization rather than production changes. No new packages or services introduced. Static tests do not qualify live speed; required remote lanes and exact-ten timing remain final-subject work in Plan 07. CI-15/CI-16 remain Pending.

## Next Phase Readiness

Plan 06 may build contributor bootstrap on the frozen input/budget policy. Continue Wave 1 Plan 08 first.

## Self-Check: PASSED
