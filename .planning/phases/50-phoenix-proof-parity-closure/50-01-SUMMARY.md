---
phase: 50-phoenix-proof-parity-closure
plan: 01
subsystem: testing
tags: [phoenix, liveview, tus, install-smoke, proof]
requires:
  - phase: 49-liveview-tus-productization
    provides: "the canonical guide, helper seam, and honest state vocabulary now being proven end to end"
provides:
  - "Generated-app tus proof now starts from the documented Phoenix / LiveView helper path"
  - "Machine-readable Phoenix helper metadata and completion-surface breadcrumbs"
  - "Honest `uploading` / `verifying` / `ready` proof artifacts preserved alongside the real Node resume proof"
affects: [phase-50-verification, PROOF-01]
tech-stack:
  added: []
  patterns:
    - "LiveView preflight drives the same Node tus transport proof instead of replacing it"
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
key-decisions:
  - "Kept one generated-app tus lane and moved the proof entrypoint up to `allow_tus_upload/4`"
  - "Recorded Phoenix-facing report fields instead of relying on prose-only smoke output"
patterns-established:
  - "Generated-app install smoke can prove a LiveView external-upload contract while reusing the lower-level tus transport sub-proof"
requirements-completed: [PROOF-01]
duration: 95min
completed: 2026-05-25
---

# Phase 50 Plan 01 Summary

**The canonical generated-app tus smoke lane now proves the documented Phoenix / LiveView path end to end instead of only a raw tus client against the mounted plug.**

## Performance

- **Duration:** 95 min
- **Completed:** 2026-05-25
- **Files modified:** 2

## Accomplishments

- Patched the generated `:tus` app to mount a smoke LiveView that calls `Rindle.LiveView.allow_tus_upload/4`, emits canonical `RindleTus` metadata, and completes through `consume_uploaded_entries/3` and `verify_completion/2`.
- Rewired the proof harness so `Phoenix.LiveViewTest.file_input/4` and `preflight_upload/1` mint the real helper metadata before the existing Node `tus-js-client` interrupt-and-resume proof runs.
- Persisted Phoenix-facing report fields including `phoenix_helper_uploader`, `phoenix_helper_endpoint`, `phoenix_helper_upload_url`, `phoenix_helper_session_id`, `phoenix_helper_asset_id`, `completion_surface`, `phoenix_state_sequence`, and `phoenix_error_state`.
- Extended the merge-blocking smoke assertions to freeze those Phoenix-path facts alongside the existing transport/runtime facts.

## Verification

- `RINDLE_INSTALL_SMOKE_PROFILE=tus mix test test/install_smoke/generated_app_smoke_test.exs --include minio --trace`
- `rg -n 'allow_tus_upload\\(|consume_uploaded_entries\\(|preflight_upload\\(|render_submit\\(|phoenix_helper_uploader|completion_surface' test/install_smoke/support/generated_app_helper.ex`
- `rg -n 'phoenix_helper_uploader|completion_surface|phoenix_state_sequence|phoenix_error_state' test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex`

## Issues Encountered

- MinIO was not durable when launched from the helper shell alone in this tool environment, so the final proof loop used a persistent PTY-backed MinIO process.
- A stale suspicion about `mix.exs` patching was cleared by rerunning the fresh full script path after the proof-harness fixes; no additional `mix.exs` patch was needed for the successful final lane.

## Next Phase Readiness

Plan 01 left the generated-app proof surface authoritative and audit-friendly. Plan 02 could now freeze the same Phoenix contract in fast parity and local helper tests without widening scope.

---
*Phase: 50-phoenix-proof-parity-closure*
*Completed: 2026-05-25*
