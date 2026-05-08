---
phase: 41-onboarding-docs-doctor-package-consumer-proof
plan: 41-03
subsystem: install-smoke
tags: [install-smoke, gcs, package-consumer, ci, resumable-uploads]
requires:
  - phase: 39
    provides: shipped resumable broker/storage contracts
  - phase: 41-01
    provides: optional GCS docs posture and parity expectations
  - phase: 41-02
    provides: `mix rindle.doctor` warning-capable GCS onboarding surface
provides:
  - First-class `:gcs` generated-app install-smoke profile
  - Always-on structural package-consumer GCS proof
  - Secret-gated live package-consumer GCS CI lane with per-run cleanup
affects: [install-smoke, ci, docs-parity, package-consumer]
key-files:
  created:
    - .planning/phases/41-onboarding-docs-doctor-package-consumer-proof/41-03-SUMMARY.md
  modified:
    - scripts/install_smoke.sh
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
    - .github/workflows/ci.yml
    - test/install_smoke/docs_parity_test.exs
    - test/install_smoke/release_docs_parity_test.exs
requirements-completed: [RESUMABLE-14]
completed: 2026-05-07
---

# Phase 41 Plan 03 Summary

Implemented the generated-app GCS package-consumer proof slice and verified the
new structural `:gcs` lane locally.

## Accomplishments

- Added `gcs` profile dispatch to `scripts/install_smoke.sh`.
- Extended `GeneratedAppHelper` with a first-class `:gcs` profile, package
  wiring for `goth`, `finch`, and `gcs_signed_url`, GCS-specific runtime/test
  helpers, optional live-bucket env plumbing, and cleanup-file support for
  CI-driven object deletion.
- Added a dedicated GCS generated-app smoke module that proves the package
  install surface, `mix rindle.doctor` presence, and resumable status proof
  surface, while only asserting the live resumable lifecycle when bucket
  secrets are present.
- Updated `.github/workflows/ci.yml` so the built-artifact package-consumer
  lane always runs `bash scripts/install_smoke.sh gcs`, and added a sibling
  `package-consumer-gcs-live` job gated on
  `GOOGLE_APPLICATION_CREDENTIALS_JSON` with a unique per-run prefix and
  `if: always()` cleanup.
- Added docs parity assertions that keep the public docs aligned to the new
  optional GCS posture exposed by Plans 41-01 and 41-03.

## Verification

- Ran `RINDLE_INSTALL_SMOKE_PROFILE=gcs mix test test/install_smoke/generated_app_smoke_test.exs`
- Result: PASS (`3 tests, 0 failures`)
- Ran `rg -n "install_smoke\.sh gcs|GOOGLE_APPLICATION_CREDENTIALS_JSON|if: \$\{\{ secrets\.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' \}\}|if: always\(\)|prefix|session_uri" .github/workflows/ci.yml`
- Result: PASS (expected structural strings present)

## Acceptance Criteria

- Met. `scripts/install_smoke.sh` accepts `gcs`.
- Met. `GeneratedAppHelper` and generated-app smoke tests expose a first-class
  `:gcs` path without disturbing `:image`, `:video`, or `:mux`.
- Met. The GCS smoke assertions reference `mix rindle.doctor` and
  `Rindle.resumable_session_status/2`.
- Met. CI contains both the always-on structural GCS proof and the separate
  secret-gated live lane, with unique per-run prefixing, raw-`session_uri`
  hygiene, and unconditional cleanup.

## Deviations / Blockers

- No shipped blockers remain.
- The structural smoke proof passed locally without live GCS secrets; the
  secret-gated live lane remains CI-only by design.
