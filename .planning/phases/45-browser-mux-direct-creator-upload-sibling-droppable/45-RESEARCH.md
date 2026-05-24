# Phase 45 Research: Browser -> Mux Direct Creator Upload

**Date:** 2026-05-24
**Scope:** MUX-20, MUX-21, MUX-22, MUX-23
**Sources:** `.planning/research/v1.8/MUX-DIRECT-UPLOAD-RESEARCH.md`, `.planning/research/v1.8-MUX-SDK-BOUNDARY.md`, `.planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-CONTEXT.md`, `.planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-UI-SPEC.md`

## Research Goal

Answer: what must the Phase 45 plan preserve so browser -> Mux direct creator
upload lands as a small additive slice instead of a second upload subsystem.

## Locked Findings

### 1. The public seam is streaming-owned, not broker-owned

- `Rindle.Upload.Broker` and `MediaUploadSession` are the wrong lifecycle for
  this flow because bytes never land in adopter storage and there is no
  `verify_completion/2` handoff.
- The durable row is `media_provider_assets`, created before the browser starts
  uploading so the webhook path always mutates existing local state.
- The public server entrypoint should be
  `Rindle.Streaming.create_direct_upload/2`, returning only
  `%{upload_url, asset_id}`.

### 2. Mux direct upload is already pre-wired in core

- `Rindle.Streaming.Provider` already reserves `create_direct_upload/2`.
- `Rindle.Streaming.Capabilities` already includes `:direct_creator_upload`.
- `Rindle.Streaming.Provider.Mux.Event.normalize/1` already exposes both
  `provider_asset_id` and `upload_id` on `video.upload.asset_created`.
- `Rindle.Workers.IngestProviderWebhook` already dispatches
  `video.upload.asset_created`, but its current behavior is still the deferred
  no-op stub.

### 3. Correlation must use Mux passthrough

- The primary business key is an opaque Rindle-owned passthrough token stamped
  at direct-upload creation time.
- `upload_id` is internal-only and may be persisted only as secondary
  diagnostics, never as the primary lookup key and never as the public handle.
- The schema change is one additive nullable column on `media_provider_assets`
  for the passthrough token, with redaction parity matching other
  provider-internal identifiers.

### 4. The adapter work is intentionally thin

- `Rindle.Streaming.Provider.Mux` should implement
  `create_direct_upload/2` using `Mux.Video.Uploads.create/2`.
- The request must include:
  - `cors_origin` (required)
  - `new_asset_settings.playback_policies`
  - `new_asset_settings.passthrough` (<= 255 chars)
- The callback result shape stays locked:
  `%{upload_url, upload_id, provider_asset_id: nil}`.
- The Mux adapter must start advertising `:direct_creator_upload`.
- The HTTP boundary stays Rindle-owned: add `create_upload/1` to
  `Rindle.Streaming.Provider.Mux.Client` and
  `Rindle.Streaming.Provider.Mux.HTTP`, reusing the same response-shaping and
  error-normalization pattern already used for `create_asset/1`.

### 5. The webhook worker owns the upload -> asset linker

- `video.upload.asset_created` should:
  - look up the row by the passthrough token carried by the normalized raw data
  - stamp `provider_asset_id`
  - move the row from `"pending"` or `"uploading"` into `"processing"`
  - emit the reserved `:provider_asset_created` PubSub event
- `video.asset.ready` should then keep using the existing ready-path broadcast
  and playback-id persistence.
- Idempotency remains Oban-backed and duplicates must be harmless.

### 6. Public secrecy rules are strict

- `upload_url` is a one-time bearer credential and must never be stored,
  logged, or emitted in telemetry.
- Raw Mux `upload_id` and `provider_asset_id` must never cross the adopter
  public API.
- The public handle is the Rindle asset id.

### 7. DX hierarchy is controller-first, LiveView-second

- Baseline docs story: controller/JSON endpoint that calls
  `Rindle.Streaming.create_direct_upload/2`.
- Convenience story: `Rindle.LiveView.allow_direct_upload/4`, layered over
  LiveView `:external` uploads and the same server contract.
- Browser helper posture: UpChunk for the happy path, one file only, visible
  state split after transfer:
  `Uploading to Mux...` -> `Upload received. Linking provider asset...` ->
  `Asset linked. Preparing playback...`.

### 8. Preset ergonomics should mirror MuxWeb, not mutate it

- Keep `Rindle.Profile.Presets.MuxWeb` unchanged.
- Add a sibling preset, `Rindle.Profile.Presets.MuxDirectUploadWeb`, that keeps
  the same streaming provider/playback posture but locks
  `ingest_mode: :direct_creator_upload`.

## Implementation File Set

### Core code

- `lib/rindle/streaming.ex` or equivalent public streaming facade
- `lib/rindle/streaming/provider/mux.ex`
- `lib/rindle/streaming/provider/mux/http.ex`
- `lib/rindle/streaming/provider/mux/client.ex`
- `lib/rindle/streaming/capabilities.ex`
- `lib/rindle/workers/ingest_provider_webhook.ex`
- `lib/rindle/domain/media_provider_asset.ex`
- `lib/rindle/profile/presets/mux_direct_upload_web.ex`
- `lib/rindle/live_view.ex`

### Database

- one additive migration for the passthrough correlation column and index

### Tests and docs

- `test/rindle/streaming/provider/mux/mux_test.exs`
- `test/rindle/workers/ingest_provider_webhook_test.exs`
- new streaming/direct-upload tests around the public entrypoint
- `test/rindle/profile/presets/mux_direct_upload_web_test.exs`
- LiveView helper tests
- `guides/streaming_providers.md`

## Recommended Plan Split

### Plan 01: Adapter + schema contract

- Add passthrough correlation column and redaction parity.
- Implement `create_direct_upload/2` end to end at the Mux boundary.
- Add adapter/client/http tests for request shape, capability advertisement, and
  error normalization.

### Plan 02: Streaming entrypoint + webhook linker

- Add `Rindle.Streaming.create_direct_upload/2`.
- Create the local provider row and stamp passthrough before returning the
  upload URL.
- Upgrade `video.upload.asset_created` into the linker and broadcast
  `:provider_asset_created`.
- Add end-to-end provider event tests proving linker -> ready flow.

### Plan 03: LiveView helper + preset + docs

- Add `Rindle.Profile.Presets.MuxDirectUploadWeb`.
- Add `Rindle.LiveView.allow_direct_upload/4`.
- Extend `guides/streaming_providers.md` with controller-first docs and a
  secondary LiveView/UpChunk path.
- Add tests covering the helper, preset, and the documented provider-event flow.

## Validation Architecture

### Fast loop

- `mix test test/rindle/streaming/provider/mux/mux_test.exs`
- `mix test test/rindle/workers/ingest_provider_webhook_test.exs`
- `mix test test/rindle/profile/presets/mux_direct_upload_web_test.exs`

### Integration loop

- Run the direct-upload public entrypoint tests and LiveView helper tests after
  each plan wave.
- Keep an end-to-end provider-event flow that proves:
  create direct upload -> upload asset created webhook -> provider asset ready
  webhook -> both PubSub events observed.

### Manual checks

- Review guide wording to ensure `upload_url`, raw `upload_id`, and raw
  `provider_asset_id` never appear in user-facing examples.
- Confirm the docs maintain the controller-first / LiveView-second hierarchy
  locked in `45-CONTEXT.md` and `45-UI-SPEC.md`.
