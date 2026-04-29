---
phase: 12
plan: 01
title: Public Hex.pm consumer verification
requirements-completed: [RELEASE-08]
status: complete
completed_at: 2026-04-28
files_changed:
  - test/install_smoke/support/generated_app_helper.ex
  - test/install_smoke/generated_app_smoke_test.exs
  - scripts/public_smoke.sh
  - .github/workflows/release.yml
---

# Phase 12 Plan 12-01 Summary

Implemented public-registry verification plumbing for the generated-app install smoke path and moved the live proof into a separate post-publish job.

## Outcomes

- `test/install_smoke/support/generated_app_helper.ex` now supports a network mode via `RINDLE_INSTALL_SMOKE_NETWORK_VERSION`, skips local artifact unpacking in that mode, switches the generated dependency injection from `path:` to `~> version`, and polls `mix deps.get` for up to 30 attempts with 10-second sleeps.
- `test/install_smoke/generated_app_smoke_test.exs` now skips the unpacked-package-root assertion when the smoke run is proving public Hex.pm resolution.
- `scripts/public_smoke.sh` now requires an explicit published version from `$1` or `RINDLE_INSTALL_SMOKE_NETWORK_VERSION`, exports `RINDLE_INSTALL_SMOKE_NETWORK_VERSION`, and runs the generated-app smoke test as a public-registry verification entrypoint.
- `.github/workflows/release.yml` now runs `Verify public Hex.pm artifact` in a separate `public_verify` job that depends on the publish job, provisions a fresh runner, clears `HEX_API_KEY`, derives the version from `github.ref_name`, and passes only that version into `bash scripts/public_smoke.sh "$VERSION"`.

## Verification Evidence

- `grep -n "network_mode?:" test/install_smoke/support/generated_app_helper.ex` matched line `64`.
- `grep -n "Enum.reduce_while(1..30" test/install_smoke/support/generated_app_helper.ex` matched line `36`.
- `grep -n "if not report.network_mode? do" test/install_smoke/generated_app_smoke_test.exs` matched line `21`.
- `grep -nE '\\$1|RINDLE_INSTALL_SMOKE_NETWORK_VERSION' scripts/public_smoke.sh` matched the explicit version input and exported env var.
- `grep -n "needs: release" .github/workflows/release.yml` matched the fresh verification job dependency.
- `grep -n "Verify public Hex.pm artifact" .github/workflows/release.yml` matched the post-publish verification step in the separate job.
- `grep -n 'HEX_API_KEY: ""' .github/workflows/release.yml` matched the credential-free verification step.
- `grep -n 'bash scripts/public_smoke.sh "\\$VERSION"' .github/workflows/release.yml` matched the explicit version handoff from the Git tag.
- `test -x scripts/public_smoke.sh` passed after setting the executable bit.
- `bash -n scripts/public_smoke.sh` exited `0`.
- `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` exited `0` with `2 tests, 0 failures` in `56.4 seconds`.

## Deviations

None. The plan was executed as written within the scoped files.

## Notes

- The local verification run intentionally exercised the non-network path, matching the plan's required acceptance command. The new public-registry path is wired for post-publish CI execution through `scripts/public_smoke.sh`, and the remaining live Hex.pm proof stays as a blocking human checkpoint.
