---
status: complete
mode: shift-left
phase: 24-domain-model-dsl-extension
source:
  - .planning/phases/24-domain-model-dsl-extension/24-01-SUMMARY.md
  - .planning/phases/24-domain-model-dsl-extension/24-02-SUMMARY.md
  - .planning/phases/24-domain-model-dsl-extension/24-03-SUMMARY.md
  - .planning/phases/24-domain-model-dsl-extension/24-04-SUMMARY.md
  - .planning/phases/24-domain-model-dsl-extension/24-05-SUMMARY.md
started: 2026-05-05T15:57:09Z
updated: 2026-05-05T16:00:32Z
human_steps_required: 0
automation_deferred: []
---

## Current Test

[testing complete]

## Automation Map

- `MIX_ENV=test mix ecto.reset`
- `MIX_ENV=test mix test test/rindle/backward_compat/v13_digest_snapshot_test.exs test/rindle/probe_test.exs test/rindle/av/metadata_sanitizer_test.exs test/rindle/domain/migration_test.exs test/rindle/domain/media_schema_test.exs test/rindle/domain/lifecycle_fsm_test.exs test/rindle/profile/validator_test.exs test/rindle/profile/profile_test.exs test/rindle/probe/image_test.exs test/rindle/probe/av_probe_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors`
- `MIX_ENV=test mix compile --warnings-as-errors`
- `MIX_ENV=test mix test test/rindle/upload/lifecycle_integration_test.exs --include integration --warnings-as-errors`
- `MIX_ENV=test mix test test/adopter/canonical_app/lifecycle_test.exs --only adopter --warnings-as-errors`

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running server/service. Clear ephemeral state. Start the application from scratch. Migrations and setup complete without errors, and a primary compile/test verification path succeeds against the fresh state.
result: pass

### 2. Image Digest and Metadata Compatibility
expected: Image-only profiles still validate without persisting a `:kind` key, and the canonical `:thumb` recipe digest remains exactly `3a9ab2f60b2d26217471f22cc329252acba546c6341111a3ef89a8d9978d30a7`.
result: pass

### 3. AV Schema and Lifecycle Readiness
expected: Media assets accept `image`, `video`, and `audio` kinds; media variants accept `image`, `video`, `audio`, and `waveform` output kinds; and the additive lifecycle transitions for `transcoding`, `quarantined`, and `cancelled` work without regressing existing image flows.
result: pass

### 4. Kind-Aware Profile Validation
expected: Profile validation dispatches by variant kind, rejects invalid kind-specific keys and any `:from_variant` chaining, while keeping image variants normalized to the pre-v1.4 shape.
result: pass

### 5. Probe Persistence and Quarantine Flow
expected: Promoting image, video, and audio assets probes by MIME, persists typed dimensions and duration fields plus sanitized metadata, cleans up tempfiles, and quarantines probe failures with an `error_reason` instead of leaving the asset in a bad intermediate state.
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
