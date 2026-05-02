---
phase: 15-ci-integrity-and-publish-preflight
plan: 01
subsystem: release
tags: [release, ci, packaging, preflight]
requirements_completed:
  - PUBLISH-02
completed: 2026-04-29
---

# Phase 15 Plan 01 Summary

Phase 15 plan 01 hardened the repo-owned release preflight so package unpacking no longer depends on a long checkout-relative path, and it locked the shipped changelog contract into the install-smoke metadata proof.

## Accomplishments

- Updated `scripts/release_preflight.sh` to unpack the built Hex artifact into a short temporary directory outside the checkout by default.
- Added `RINDLE_RELEASE_PREFLIGHT_KEEP_ARTIFACT` so maintainers can preserve the unpacked artifact for manual review without editing the script.
- Preserved `RINDLE_INSTALL_SMOKE_PACKAGE_ROOT` as the shared artifact root exported to downstream install-smoke checks.
- Extended `test/install_smoke/package_metadata_test.exs` so the packaged artifact must ship `CHANGELOG.md` and include a `0.1.0` entry.
- Reconfirmed that the package metadata contract still proves package identity, MIT license, GitHub link, and required shipped paths from the unpacked tarball.

## Verification

- `bash -n scripts/release_preflight.sh`
- `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs`
- `MIX_ENV=dev bash scripts/release_preflight.sh`

All three commands passed on 2026-04-29. The full preflight completed through package metadata, release docs parity, generated-app install smoke, docs generation, and release docs HTML assertions.

## Task Commits

1. `2ac71dc` — `fix(release): harden preflight artifact unpack path`
2. `ec60240` — `test(release): enforce shipped changelog contract`

## Notes

- `CHANGELOG.md` and the `mix.exs` package allowlist entry for it were already present in the working tree baseline for this execution. This plan added the missing executable guard so future drift drops the package test immediately.
