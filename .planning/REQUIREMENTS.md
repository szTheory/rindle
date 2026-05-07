# Requirements: Rindle v1.6 — Provider Boundary + Mux

**Defined:** 2026-05-06
**Core Value:** Media, made durable.
**Source:** Locked recommendation in
`.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` (research-driven candidate
evaluation: Provider+Mux 8/10, GCS 7.5/10, tus 6/10).

**Goal:** Productize `Rindle.Streaming.Provider` as a real adapter contract and
ship Mux as the single reference streaming provider. Turns v1.4's reserved
`streaming_url/3` seam into provider-aware playback with durable provider
state, signed-webhook ingest, and Oban-driven sync — without making Rindle a
video platform.

## v1.6 Requirements

### Provider Boundary & State Schema

- [x] **STREAM-01**: Rindle ships a `Rindle.Streaming.Capabilities` module with
  a closed vocabulary (`:signed_playback`, `:public_playback`, `:webhook_ingest`,
  `:server_push_ingest`, `:direct_creator_upload`) consumed by
  `mix rindle.doctor` and `Rindle.Capability.report/0`.
- [x] **STREAM-02**: `Rindle.Streaming.Provider` is promoted from a reserved
  behaviour to a runtime contract with locked `@callback` signatures (capability
  query, asset create/get/delete, signed playback URL, webhook verify, optional
  direct-creator-upload).
- [x] **STREAM-03**: Adopters get an additive `media_provider_assets` Ecto
  table (one row per `(asset, profile, provider)`) without any change to
  `media_assets` or `media_variants`.
- [x] **STREAM-04**: `Rindle.Domain.MediaProviderAsset` schema, changeset, and
  finite state machine cover `pending → uploading → processing → ready |
  errored | deleted` transitions.
- [x] **STREAM-05**: Profile DSL accepts a `:streaming` key with locked named
  options (`:provider`, `:playback_policy`, `:ingest_mode`, `:source_variant`)
  validated through NimbleOptions; raw provider knobs are forbidden; image-only
  and AV-only profiles compile unchanged.
- [x] **STREAM-06**: `Rindle.Delivery.streaming_url/3` dispatches via a single
  deterministic decision tree — provider-ready row returns provider URL,
  in-flight ingest returns `:provider_asset_not_ready`, errored row returns
  `:provider_sync_failed`, no row falls back to existing progressive (or to a
  strict-mode error when `opts[:strict]` is set).
- [x] **STREAM-07**: `Rindle.Error` vocabulary extends with five additive
  locked atoms: `:provider_asset_not_ready`, `:provider_webhook_invalid`,
  `:provider_sync_failed`, `:provider_quota_exceeded`,
  `:streaming_provider_requires_asset_struct`. Existing v1.4
  `:streaming_not_configured` is reused unchanged.
- [x] **STREAM-08**: `Rindle.Capability.report/0` lists detected streaming
  providers and signed-playback configuration status alongside the existing
  storage/processor capability output.
- [x] **STREAM-09**: An ExUnit parity gate asserts the exact reason atom and
  message text for the five new error variants (matches the AV-06-05 freeze
  pattern) so the v1.6 streaming vocabulary can be safely frozen at ship.

### Mux REST Adapter & Server-Push Sync

- [ ] **MUX-01**: `mux ~> 3.2` and `jose ~> 1.11` ship as **optional** deps;
  adopters who don't enable streaming pay zero transitive cost and Mux SDK's
  Tesla + JOSE transitive surface stays adapter-local.
- [ ] **MUX-02**: `Rindle.Streaming.Provider.Mux` implements every locked
  callback in the behaviour (capabilities, create/get/delete asset, signed
  playback URL, webhook verify); credential resolution lives entirely in
  `Application.get_env`.
- [ ] **MUX-03**: A new `Rindle.Workers.MuxIngestVariant` Oban worker pushes a
  Rindle-produced AV variant to Mux from server context using a private signed
  storage URL; the resulting `provider_asset_id` and `playback_id` persist into
  `media_provider_assets`; FSM advances `pending → uploading → processing`.
- [ ] **MUX-04**: Signed HLS playback URLs mint via Mux's own JOSE-based
  `Mux.Token.sign/2` helper inside a Rindle-owned wrapper that respects the
  v1.4 `signed_url_ttl_seconds` profile policy (no hidden 7-day default).
- [ ] **MUX-05**: `MuxIngestVariant` is idempotent under Oban `unique`
  constraints keyed on `(asset_id, profile, variant_name)`; re-running yields
  the same `media_provider_assets` row, never a duplicate.
- [ ] **MUX-06**: Atomic-promote rule on flip-to-`ready`: re-fetch the source
  asset and abort the transition if `recipe_digest` or `storage_key` changed
  during ingest, mirroring the v1.4 AV-03-10 race protection.
- [ ] **MUX-07**: A defensive `Rindle.Workers.MuxSyncProviderAsset` Oban worker
  polls any `processing`/`uploading` row whose `updated_at` exceeds the
  configured floor and transitions to `errored` with reason
  `:provider_asset_stuck` when older than the stuck-threshold cap.
- [ ] **MUX-08**: Provider ingest and sync emit telemetry under
  `[:rindle, :provider, :ingest, :start | :stop | :exception]` and
  `[:rindle, :provider, :sync, :resolved | :stuck]` with documented
  measurement and metadata schemas.

### Signed-Webhook Plug & Idempotent Ingest

- [x] **MUX-09**: `Rindle.Delivery.WebhookPlug` is a mountable provider-aware
  Plug that adopters mount via a documented `forward` declaration; it reads
  the raw body via a shipped `Rindle.Delivery.WebhookBodyReader` and bypasses
  `Plug.Parsers` JSON decoding for the webhook scope.
- [x] **MUX-10**: Webhook signature verification delegates to
  `Mux.Webhooks.verify_header/4` (HMAC-SHA256, constant-time compare,
  Stripe-parity 300s default tolerance, configurable up to 900s, rejected
  below 60s).
- [x] **MUX-11**: The Plug supports multi-secret rotation via an ordered
  `:webhook_secrets` config list; first-match wins; a metric records which
  secret index matched so operators can confirm rotation completed before
  retiring the previous secret.
- [x] **MUX-12**: On verified webhook, the Plug enqueues the raw payload to a
  `Rindle.Workers.IngestProviderWebhook` Oban job and returns `202 Accepted`;
  signature failures and replay-window failures both return `400` with
  `:provider_webhook_invalid` (operators distinguish via telemetry metadata,
  not error variants).
- [x] **MUX-13**: `IngestProviderWebhook` is idempotent under Oban `unique`
  keyed on the Mux event UUID; it dispatches on `event.type` to flip
  `media_provider_assets` state, persist `playback_ids`, and broadcast
  `:provider_asset_*` PubSub; unknown event types persist `last_event_at`
  without crashing.
- [x] **MUX-14**: Workers exceeding `max_attempts` leave the affected row in
  its last-known good state with `last_sync_error` populated; `mix
  rindle.runtime_status` (v1.5 surface) gains a `--provider-stuck` filter
  listing stuck/uploading rows older than the configured threshold.

### Public DX, Onboarding, & CI Proof

- [ ] **MUX-15**: `Rindle.Profile.Presets.MuxWeb` ships alongside the existing
  `Rindle.Profile.Presets.Web` and demonstrates `:streaming` opt-in with the
  `:signed` named playback policy.
- [ ] **MUX-16**: `mix rindle.doctor` validates streaming configuration —
  presence of token id/secret, signing key id + RSA private key, webhook
  secrets, and a 5s smoke ping to `Mux.Video.Assets.list/1` — and reports
  per-profile streaming status with PASS/FAIL.
- [ ] **MUX-17**: `guides/streaming_providers.md` ships with a Mux-only
  section: env vars, signing-key creation steps, webhook secret rotation
  workflow, raw-body cache wiring, ngrok-style local webhook tunnel
  guidance, and the `mix rindle.doctor` smoke check.
- [ ] **MUX-18**: The generated-app package-consumer proof harness gains a
  `mux-enabled` lane (alongside the v1.5 `image-only` and `av-enabled` lanes).
  PR builds run cassette-based Mux fixtures by default; a gated `mux-soak`
  lane runs against real Mux every PR labelled `streaming`.
- [ ] **MUX-19**: README and getting-started gain a "Streaming with Mux"
  subsection that points at `guides/streaming_providers.md`; image and AV
  onboarding paths remain the canonical first-run story.

### Browser → Mux Direct Creator Upload (optional Phase 37)

- [ ] **MUX-20**: `Rindle.Streaming.Provider.Mux.create_direct_upload/2`
  returns `%{upload_url, upload_id, provider_asset_id}` after creating a
  `media_provider_assets` row in `pending` state with
  `direct_creator_upload: true`.
- [ ] **MUX-21**: A `video.upload.asset_created` webhook handler in
  `IngestProviderWebhook` links upload-id to asset-id when the direct-creator
  flow completes.
- [ ] **MUX-22**: `Rindle.Streaming.Capabilities.require_streaming/2` gate
  exists and surfaces `:direct_creator_upload` capability to adopters.
- [ ] **MUX-23**: LiveView helper extends the v1.4 PubSub vocabulary with
  `:provider_asset_created`, `:provider_asset_ready`, `:provider_asset_errored`
  events delivered through `Rindle.LiveView.subscribe/2`.

## Requirement Outcomes

Filled by `gsd-roadmapper` once the v1.6 ROADMAP.md is approved.

| Requirement | Phase | Status |
|-------------|-------|--------|
| STREAM-01..09 | Phase 33 | Validated 2026-05-06 |
| MUX-01..08 | Phase 34 | Planned (v1.6 roadmap) |
| MUX-09..14 | Phase 35 | Planned (v1.6 roadmap) |
| MUX-15..19 | Phase 36 | Planned (v1.6 roadmap) |
| MUX-20..23 | Phase 37 (optional) | Planned (v1.6 roadmap) |

## Deferred Candidate Requirements (v1.7+)

### v1.7 candidate — GCS Resumable Adapter

Locked plan: `.planning/research/v1.6-CANDIDATE-GCS.md` (5 phases, ~13 days,
18 plans, 7.5/10 score).

- **GCS-01..04**: `Rindle.Storage.GCS` adapter implements the existing
  `Rindle.Storage` behaviour using `goth ~> 1.4` for auth, `finch` for HTTP,
  and `gcs_signed_url ~> 0.4` for V4 signing — no resumable behaviour yet.
- **RESUMABLE-01..14**: Promote `:resumable_upload` and
  `:resumable_upload_session` capabilities from reserved to shipped; additive
  Ecto migration for session URI / expiry / offset / region; behaviour
  callbacks on `Rindle.Storage`; broker entrypoints; Oban-driven cancel
  with idempotency on `:not_found`/`:expired`; `mix rindle.doctor` GCS check;
  package-consumer GCS proof lane.

### v1.8 candidate — tus Resumable Upload Protocol

Locked plan: `.planning/research/v1.6-CANDIDATE-TUS.md` (5 phases, ~13-15
days, 6/10 score; in-process Plug on `tussle ~> 0.3.1`).

- **TUS-01..19**: Mountable `Rindle.Upload.TusPlug` macro on
  `tussle ~> 0.3.1`; broker entrypoints `initiate_resumable_upload/2` +
  `cancel_resumable_upload/1`; HMAC-signed tus URLs (closes the tusd
  same-user-resume gap); S3 multipart `UploadPart` per PATCH ≥ 5MiB on the
  S3 path; local-tmp accumulation on the local-storage path; Ecto-backed
  Tussle cache; Oban expiry sweep extending `AbortIncompleteUploads`;
  generated-app proof lane against `tus-js-client` + MinIO.

## Out of Scope (v1.6)

- **Second streaming provider** (Cloudflare Stream / Bunny Stream / Cloudinary
  Video). The single-provider rule is what keeps the abstraction honest;
  v1.7 adds a second adapter as the contract test.
- **Live streaming, RTMP / WebRTC ingest, DRM** (Widevine / FairPlay /
  PlayReady). Different runtime shape; Membrane Framework territory; out of
  scope per `PROJECT.md`.
- **Multi-region failover / multi-CDN routing.** Library-level CDN
  orchestration is overreach; adopters configure routing at the application
  edge.
- **Replacing `Rindle.Processor.AV`.** Mux is additive; FFmpeg-driven
  progressive delivery stays intact and is the safety-net fallback when a
  profile has not opted into a provider.
- **Direct-to-Mux upload from the browser** ships only if Phase 37 pulls
  forward; default v1.6 ships only the server-push ingest path.
- **tus protocol** — locked v1.8 plan, not v1.6 scope.
- **GCS adapter** — locked v1.7 plan, not v1.6 scope.
- **Captions / subtitle `<track>`** rendering — the `:tracks` keyword is
  already reserved in v1.4 `video_tag/3`; provider-delegated captions extend
  cleanly in v1.7+.
- **Provider-side ABR / multi-rendition awareness** beyond Mux's own
  transparent ladder — `Rindle.RenditionSet` is a v2.0 design.
- **Webhook event replay tooling** (`mix rindle.webhook.replay`) — durable
  `media_provider_assets` row covers the durable-state need; replay tooling
  is v1.7+.
- **Configurable telemetry redaction** — v1.6 hardcodes provider-internal
  ID redaction (last-4-char tag) in metadata; configurable redaction is
  over-engineering for v1.6.
- **Cancellation surface for in-flight provider ingest**
  (`Rindle.cancel_provider_ingest/1`). Oban `cancel` covers most of it;
  v1.7+ formalizes the user-facing verb.

## Traceability

Every v1.6 requirement is mapped to exactly one phase. No orphans. No
duplicates. Coverage: 32 / 32 ✓.

| Requirement | Phase | Status |
|-------------|-------|--------|
| STREAM-01 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| STREAM-02 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| STREAM-03 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| STREAM-04 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| STREAM-05 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| STREAM-06 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| STREAM-07 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| STREAM-08 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| STREAM-09 | Phase 33 — Provider Boundary + State Schema | Validated 2026-05-06 |
| MUX-01 | Phase 34 — Mux REST Adapter + Server-Push Sync | Planned |
| MUX-02 | Phase 34 — Mux REST Adapter + Server-Push Sync | Planned |
| MUX-03 | Phase 34 — Mux REST Adapter + Server-Push Sync | Planned |
| MUX-04 | Phase 34 — Mux REST Adapter + Server-Push Sync | Planned |
| MUX-05 | Phase 34 — Mux REST Adapter + Server-Push Sync | Planned |
| MUX-06 | Phase 34 — Mux REST Adapter + Server-Push Sync | Planned |
| MUX-07 | Phase 34 — Mux REST Adapter + Server-Push Sync | Planned |
| MUX-08 | Phase 34 — Mux REST Adapter + Server-Push Sync | Planned |
| MUX-09 | Phase 35 — Signed-Webhook Plug + Idempotent Ingest | Planned |
| MUX-10 | Phase 35 — Signed-Webhook Plug + Idempotent Ingest | Planned |
| MUX-11 | Phase 35 — Signed-Webhook Plug + Idempotent Ingest | Planned |
| MUX-12 | Phase 35 — Signed-Webhook Plug + Idempotent Ingest | Planned |
| MUX-13 | Phase 35 — Signed-Webhook Plug + Idempotent Ingest | Planned |
| MUX-14 | Phase 35 — Signed-Webhook Plug + Idempotent Ingest | Planned |
| MUX-15 | Phase 36 — Public DX, Onboarding, CI Proof | Planned |
| MUX-16 | Phase 36 — Public DX, Onboarding, CI Proof | Planned |
| MUX-17 | Phase 36 — Public DX, Onboarding, CI Proof | Planned |
| MUX-18 | Phase 36 — Public DX, Onboarding, CI Proof | Planned |
| MUX-19 | Phase 36 — Public DX, Onboarding, CI Proof | Planned |
| MUX-20 | Phase 37 (optional) — Browser → Mux Direct Creator Upload | Planned |
| MUX-21 | Phase 37 (optional) — Browser → Mux Direct Creator Upload | Planned |
| MUX-22 | Phase 37 (optional) — Browser → Mux Direct Creator Upload | Planned |
| MUX-23 | Phase 37 (optional) — Browser → Mux Direct Creator Upload | Planned |

**Phase summary** (Phase → REQ-ID range, count):

| Phase | REQ-IDs | Count |
|-------|---------|-------|
| Phase 33 | STREAM-01..09 | 9 |
| Phase 34 | MUX-01..08 | 8 |
| Phase 35 | MUX-09..14 | 6 |
| Phase 36 | MUX-15..19 | 5 |
| Phase 37 (optional) | MUX-20..23 | 4 |
| **Total** | — | **32** |
