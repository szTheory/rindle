---
phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
plan: 04
subsystem: testing
tags: [tus, generated-app, minio, smoke, s3]
requires:
  - phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
    provides: "tus guide and generated-app proof contract"
provides:
  - "Generated-app tus smoke diagnostics with persisted debug artifacts"
  - "Phoenix Plug.Head-compatible tus resume handling"
  - "S3 multipart tus uploads that preserve Upload-Metadata filetype into object metadata"
affects: [phase-44-verification, install-smoke, tus]
tech-stack:
  added: []
  patterns:
    - "Persist generated-app smoke breadcrumbs in repo tmp/ so failing package-consumer runs stay inspectable"
    - "Treat Phoenix-forwarded GET+Tus-Resumable as tus HEAD for resume discovery"
key-files:
  created:
    - .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-04-SUMMARY.md
  modified:
    - lib/rindle/upload/tus_plug.ex
    - test/rindle/upload/tus_plug_test.exs
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
    - scripts/install_smoke.sh
patterns-established:
  - "Generated-app Node tus proofs emit structured phase diagnostics before surfacing assertion failures"
requirements-completed: [TUS-14]
completed: 2026-05-24
---

# Phase 44 Plan 04 Summary

**The generated-app tus package-consumer proof now survives a real interrupted upload plus resume against MinIO, with deterministic debug artifacts and the correct `video/mp4` asset contract.**

## Accomplishments

- Added structured tus smoke diagnostics so generated-app failures record the failing phase, endpoint, saved report paths, and raw Node proof details instead of collapsing to opaque socket errors.
- Fixed Phoenix endpoint compatibility by letting `TusPlug` honor the `Plug.Head` forwarded `GET` shape for tus resume discovery.
- Threaded `Upload-Metadata` filetype through the tus token payload into S3 multipart calls so verified assets retain the expected `video/mp4` content type after resumed uploads.
- Preserved the merge-blocking tus smoke lane and taught the shell wrapper to print the saved generated-app breadcrumbs on failure.

## Verification

- `mix test test/rindle/upload/tus_plug_test.exs`
- `RINDLE_INSTALL_SMOKE_PROFILE=tus mix test test/install_smoke/generated_app_smoke_test.exs --include minio`
- `bash scripts/install_smoke.sh tus`

## Deviations from Plan

- No git commits were created in this run. The worktree already contained unrelated local modifications across the repo, so I left the phase uncommitted rather than bundling unrelated user changes into task commits.
