# Phase 45 Pattern Map

## Existing Analogs

### Adapter boundary pattern

- `lib/rindle/streaming/provider/mux.ex`
  - existing pattern: public provider callback delegates to private param
    builder, then normalizes HTTP-layer success/error shapes.
- `lib/rindle/streaming/provider/mux/http.ex`
  - existing pattern: thin wrapper over Mux SDK module; keep success body,
    preserve error env.
- `lib/rindle/streaming/provider/mux/client.ex`
  - existing pattern: internal behavior used by both the real client and Mox.

**Reuse for Phase 45:**
- add `create_upload/1` beside `create_asset/1`
- add `create_direct_upload/2` beside `create_asset/3`
- follow the same 429 / 4xx / 5xx normalization posture

### Durable provider-row pattern

- `lib/rindle/workers/mux_ingest_variant.ex`
  - existing pattern: create/update `media_provider_assets` rows inside
    `Ecto.Multi`, persist provider identifiers, then advance the FSM.
- `lib/rindle/domain/media_provider_asset.ex`
  - existing pattern: schema-owned redaction helper and `Inspect` redaction.
- `lib/rindle/domain/provider_asset_fsm.ex`
  - existing pattern: explicit allowlisted transitions with telemetry.

**Reuse for Phase 45:**
- create the provider row before browser upload starts
- extend row schema with passthrough correlation
- use the same FSM gate before writing `"processing"`

### Webhook dispatch + PubSub pattern

- `lib/rindle/workers/ingest_provider_webhook.ex`
  - existing pattern: event-type-specific dispatch functions, repo update,
    telemetry emit, and two-topic PubSub broadcast.
- `test/rindle/workers/ingest_provider_webhook_test.exs`
  - existing pattern: assert row mutation, telemetry redaction, and PubSub
    payload shape together in one test.

**Reuse for Phase 45:**
- convert `video.upload.asset_created` from no-op to linker
- preserve payload contract:
  `asset_id`, `playback_ids`, `profile`, `provider`, `state`
- add a new event assertion for `:provider_asset_created`

### Public facade pattern

- `lib/rindle.ex`
  - existing pattern: small top-level facade delegating to focused subsystems.
- `lib/rindle/delivery.ex`
  - existing pattern: capability-gated public call with narrow return shapes and
    typed error atoms.

**Reuse for Phase 45:**
- add `Rindle.Streaming.create_direct_upload/2` as a narrow public facade
- keep its return shape browser-safe: `%{upload_url, asset_id}`

### LiveView helper pattern

- `lib/rindle/live_view.ex`
  - existing pattern: wrapper around LiveView upload primitives, returning
    metadata maps with only the fields the browser flow needs.
- existing helper sets `external:` and keeps the core lifecycle outside the
  LiveView layer.

**Reuse for Phase 45:**
- add `allow_direct_upload/4` rather than mutating `allow_upload/4`
- keep the helper thin over the streaming-owned server contract

### Preset pattern

- `lib/rindle/profile/presets/mux_web.ex`
- `test/rindle/profile/presets/mux_web_test.exs`

**Reuse for Phase 45:**
- create `mux_direct_upload_web.ex` as a sibling preset
- copy the locked-streaming-block merge pattern
- change only `ingest_mode: :direct_creator_upload`

### Guide + docs pattern

- `guides/streaming_providers.md`
  - existing pattern: controller-/runtime-oriented guide with copy-pasteable
    snippets and explicit operator guidance.

**Reuse for Phase 45:**
- extend the existing guide rather than create a separate Mux-direct guide
- add controller baseline first, then LiveView convenience path

## Expected Files to Modify

### Create

- `priv/repo/migrations/*_add_mux_passthrough_to_media_provider_assets.exs`
- `lib/rindle/profile/presets/mux_direct_upload_web.ex`
- `test/rindle/profile/presets/mux_direct_upload_web_test.exs`
- one new streaming direct-upload public entrypoint test file
- one new LiveView direct-upload helper test file

### Update

- `lib/rindle/domain/media_provider_asset.ex`
- `lib/rindle/streaming/provider/mux.ex`
- `lib/rindle/streaming/provider/mux/http.ex`
- `lib/rindle/streaming/provider/mux/client.ex`
- `lib/rindle/workers/ingest_provider_webhook.ex`
- `lib/rindle/live_view.ex`
- `guides/streaming_providers.md`
- `test/rindle/streaming/provider/mux/mux_test.exs`
- `test/rindle/workers/ingest_provider_webhook_test.exs`

## Landmines

- Do not route this flow through `MediaUploadSession` or `verify_completion/2`.
- Do not expose raw Mux `upload_id` or `provider_asset_id` from public APIs.
- Do not persist `upload_url`.
- Do not mutate `MuxWeb`; add a sibling preset.
- Do not look up the linker row by `provider_asset_id` on
  `video.upload.asset_created`; that id does not exist locally yet.
