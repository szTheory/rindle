# Plan: Phase 56

## Scope
1. Finalize the uncommitted changes for the LiveView Tus helper.
2. Ensure documentation in `guides/resumable_uploads.md` covers the new LiveView `allow_tus_upload/4` DX.
3. Commit the changes.

## Tasks
1. **[Complete]** Implement `Rindle.LiveView.allow_tus_upload/4`.
2. **[Complete]** Implement `Rindle.initiate_tus_upload/2` and `TusPlug.create_upload/2`.
3. **[Complete]** Validate integration with `generated_app_smoke_test.exs`.
4. **[Complete]** Commit the Phase 56 changes.

## Verification
- Run `mix test test/install_smoke/generated_app_smoke_test.exs test/rindle/live_view_test.exs` to ensure stability before committing.