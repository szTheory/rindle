# Phase 56: LiveView Tus helper polish

## Strategic Intent
Wrap up uncommitted `Rindle.LiveView.allow_tus_upload` local edits and ensure tests (including `generated_app_smoke_test.exs`) pass with the helper updates.

## Current State
The LiveView Tus helper (`allow_tus_upload/4`) has already been implemented locally as a spike. It integrates seamlessly with `TusPlug.create_upload/2` to precreate the Tus session server-side and return a signed `upload_url` to the client. This bypasses the typical Tus POST creation phase for a much tighter DX within LiveView.

Tests in `test/rindle/live_view_test.exs` and `test/install_smoke/generated_app_smoke_test.exs` have been verified to pass successfully.

## Discuss Phase Outcome
The uncommitted edits were reviewed and verified. As a low-blast-radius DX addition that adheres to all success criteria and tests, the recommendation to proceed straight to planning and execution was approved by the user.