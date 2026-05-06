---
phase: 29-adopter-proof-matrix
plan: 03
subsystem: ci
tags: [github-actions, shell, release-preflight, minio, package-consumer]
requires:
  - phase: 29-01
    provides: image-only generated-app package-consumer proof
  - phase: 29-02
    provides: AV-enabled generated-app package-consumer proof
provides:
  - explicit CI package-consumer proof matrix naming
  - thin release-facing entrypoints for built-artifact image and AV/public proof
affects: [ci, release-preflight, public-smoke, install-smoke]
tech-stack:
  added: []
  patterns: [mode-driven smoke wrappers, explicit CI proof steps]
key-files:
  created: [.planning/phases/29-adopter-proof-matrix/29-03-SUMMARY.md]
  modified: [.github/workflows/ci.yml, scripts/install_smoke.sh, scripts/public_smoke.sh, scripts/release_preflight.sh]
key-decisions:
  - "Keep shell wrappers mode-driven and let ExUnit remain the source of truth for package-consumer proof."
  - "Expose the built-artifact image lane and built-artifact AV lane as explicit CI/release surfaces instead of one opaque smoke command."
patterns-established:
  - "Package-consumer CI should name image and AV proof steps explicitly while reusing one MinIO-backed S3-compatible setup."
  - "Published-version smoke commands accept version and profile inputs without re-implementing lifecycle logic."
requirements-completed: [PROOF-03]
duration: 17min
completed: 2026-05-06
---

# Phase 29 Plan 03 Summary

**CI and release-facing commands now expose the package-consumer proof matrix explicitly across the built-artifact image lane, the built-artifact AV lane, and the published-version public-smoke companion path**

## Performance

- **Duration:** 17 min
- **Started:** 2026-05-06T01:32:00Z
- **Completed:** 2026-05-06T01:49:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Renamed the CI job and MinIO steps so the package-consumer proof matrix is explicit and readable in `.github/workflows/ci.yml`.
- Added a dedicated built-artifact AV package-consumer proof step to CI while keeping the existing MinIO-backed S3-compatible setup shared.
- Extended `scripts/install_smoke.sh` with an explicit profile selector and `scripts/public_smoke.sh` with version-plus-profile arguments so both built and published proof paths stay thin wrappers over the generated-app ExUnit harness.
- Updated `scripts/release_preflight.sh` so the built-artifact image proof remains in the main preflight path and the published-version AV proof is surfaced as a documented companion command.

## Files Created/Modified

- `.github/workflows/ci.yml` - names the package-consumer proof matrix explicitly and adds a built-artifact AV proof step against MinIO.
- `scripts/install_smoke.sh` - accepts `image`, `video`, or `all` profile modes while preserving local package build/unpack behavior.
- `scripts/public_smoke.sh` - accepts `<published-version> [profile]` and continues to run the same generated-app ExUnit proof without repo-local path fallback.
- `scripts/release_preflight.sh` - keeps the built-artifact image proof in preflight and documents the published-version AV companion command.

## Verification

Passed task-level and plan-level commands:

```bash
rg -n "package-consumer|public smoke|install_smoke|generated_app_smoke|MinIO" .github/workflows/ci.yml
bash scripts/release_preflight.sh
```

Observed results:

- `rg -n "package-consumer|public smoke|install_smoke|generated_app_smoke|MinIO" .github/workflows/ci.yml` matched the explicit package-consumer proof matrix steps and MinIO-backed S3-compatible path.
- `bash scripts/release_preflight.sh` passed after Wave 4 cleared the inherited docs-warning blocker in the strict docs build.

## Deviations from Plan

The first plan-level preflight run failed in `mix docs --warnings-as-errors` due to pre-existing docs/build issues outside the Wave 3 file set. Those were fixed in Wave 4, after which the Wave 3 release-preflight verification passed unchanged.

## Next Phase Readiness

The CI and release-facing proof surfaces now point to the same generated-app image and AV truths, leaving no independent shell harness to drift from ExUnit.

## Self-Check

PASSED
