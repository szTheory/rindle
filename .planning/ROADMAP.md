# Roadmap: Rindle

## Milestones

- 🚧 **v1.6 Provider Boundary + Mux** — Phases 33–37 (Phase 33 complete 2026-05-06; see Active Milestone)
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06, see archive)
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, see archive)
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, see archive)
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, see archive)
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, see archive)
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, see archive)

## Active Milestone

### v1.6 Provider Boundary + Mux (Phases 33–37)

**Goal:** Productize `Rindle.Streaming.Provider` as a real adapter contract and
ship `Rindle.Streaming.Provider.Mux` as the single reference streaming adapter.
Turns v1.4's reserved `streaming_url/3` seam into provider-aware playback with
durable provider state, signed-webhook ingest, and Oban-driven sync — without
making Rindle a video platform.

**Source of truth for scope and shape:**
[`.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md`](research/v1.6-CANDIDATE-PROVIDER-MUX.md)

**Effort estimate:** ~7.5 days locked (Phases 33–36) + ~1 day optional
(Phase 37). If the milestone runs long, drop Phase 37 and ship clean at
Phase 36.

**Note on Phase 37:** Phase 37 (Browser→Mux Direct Creator Upload) is **optional**
and pulls forward only if Phases 33–36 ship under budget. It is a clean
additive surface that defers cleanly to v1.7 if not pulled forward.

#### Phase Summary

| Phase | Name | Requirements | Plans | Effort | Risk |
|-------|------|--------------|-------|--------|------|
| 33 | Provider Boundary + State Schema | STREAM-01..09 (9) | 4 | ~1.5 days | LOW |
| 34 | Mux REST Adapter + Server-Push Sync | MUX-01..08 (8) | 4 | ~2.0 days | MEDIUM |
| 35 | Signed-Webhook Plug + Idempotent Ingest | MUX-09..14 (6) | 4 | ~2.5 days | HIGH |
| 36 | Public DX, Onboarding, CI Proof | MUX-15..19 (5) | 3 | ~1.5 days | MEDIUM |
| 37 (optional) | Browser → Mux Direct Creator Upload | MUX-20..23 (4) | 2 | ~1.0 days | LOW |

**Totals:** 5 phases, 17 plans, 32 requirements covered.

#### Phase Details

##### Phase 33 — Provider Boundary + State Schema

**Goal:** Lock the public seam without adding any Mux code. Land the Ecto
migration, behaviour, capability vocabulary, profile DSL key, dispatch rule,
and error vocabulary so downstream adapter work has a stable contract.

**Depends on:** v1.5 archive (Phase 32 shipped); no new external dependencies.

**Requirements:** STREAM-01, STREAM-02, STREAM-03, STREAM-04, STREAM-05,
STREAM-06, STREAM-07, STREAM-08, STREAM-09 (9 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `mix test` passes with `Rindle.Streaming.Provider` promoted from a reserved
   behaviour to a runtime contract with locked `@callback` signatures
   (capability query, asset create/get/delete, signed playback URL, webhook
   verify, optional direct-creator-upload).
2. The `media_provider_assets` Ecto table exists via additive migration with no
   change to `media_assets` or `media_variants`; `Rindle.Domain.MediaProviderAsset`
   schema/changeset/FSM cover `pending → uploading → processing → ready |
   errored | deleted` transitions.
3. Image-only and AV-only profiles compile and exercise the v1.4 lifecycle
   byte-for-byte; the new `:streaming` DSL key is validated through
   NimbleOptions and refuses raw provider knobs.
4. `Rindle.Delivery.streaming_url/3` dispatches via the locked decision tree
   (provider-ready → provider URL; in-flight → `:provider_asset_not_ready`;
   errored → `:provider_sync_failed`; no row → progressive fallback or
   strict-mode error when `opts[:strict]` is set).
5. The five new `Rindle.Error` reason atoms freeze with exact-text parity
   (`:provider_asset_not_ready`, `:provider_webhook_invalid`,
   `:provider_sync_failed`, `:provider_quota_exceeded`,
   `:streaming_provider_requires_asset_struct`); `Rindle.Capability.report/0`
   includes detected streaming providers and signed-playback configuration
   status.
6. No Mux code is merged in this phase.

**Plans:** 4 plans (planned 2026-05-06 by `/gsd-plan-phase 33`). Wave 1 (parallel):
plans 01, 02, 04 — independent. Wave 2: plan 03 — depends on 01 (capabilities) +
02 (`MediaProviderAsset` schema for Repo lookup) + 04 (5 new error atoms used in
dispatch return values).

Plans:
- [x] 33-01-PLAN.md — Capabilities vocabulary + Provider behaviour (STREAM-01, STREAM-02) — 2026-05-06
- [x] 33-02-PLAN.md — Migration + MediaProviderAsset schema + FSM + Inspect redaction (STREAM-03, STREAM-04) — 2026-05-06
- [x] 33-03-PLAN.md — Profile DSL `:streaming` key + Delivery dispatch tree (STREAM-05, STREAM-06) — 2026-05-06
- [x] 33-04-PLAN.md — Error vocabulary + parity freeze + Capability.report (STREAM-07, STREAM-08, STREAM-09) — 2026-05-06

**UI hint**: no

##### Phase 34 — Mux REST Adapter + Server-Push Sync

**Goal:** First real adapter. Server pushes a finished mp4 to Mux from existing
`Rindle.Processor.AV` output; durable provider state tracks Mux asset id +
playback id; signed-playback URLs work.

**Depends on:** Phase 33 (provider behaviour, schema, DSL, dispatch rule,
error vocabulary).

**Requirements:** MUX-01, MUX-02, MUX-03, MUX-04, MUX-05, MUX-06, MUX-07, MUX-08
(8 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `mux ~> 3.2` and `jose ~> 1.11` ship as **optional** deps; adopters who
   don't enable streaming pay zero transitive cost; credential resolution lives
   entirely in `Application.get_env`.
2. `Rindle.Streaming.Provider.Mux` implements every locked behaviour callback
   (capabilities, create/get/delete asset, signed playback URL, webhook
   verify); `Rindle.Workers.MuxIngestVariant` Oban worker pushes a Rindle-produced
   AV variant to Mux from server context using a private signed storage URL,
   persists `provider_asset_id` + `playback_id`, and advances the FSM
   `pending → uploading → processing`.
3. A cassette-based ExUnit suite drives a 720p sample through `MuxIngestVariant`;
   the matching `media_provider_assets` row reaches `:ready` via simulated
   webhook (Phase 35 wires up the live verification); `streaming_url/3` returns
   a Mux-signed playback URL whose JWT verifies against the test signing-key
   fixture (TTL respects `signed_url_ttl_seconds`, no hidden 7-day default).
4. `MuxIngestVariant` is idempotent under Oban `unique` keyed on
   `(asset_id, profile, variant_name)`; re-running yields the same
   `media_provider_assets` row, never a duplicate; atomic-promote on
   flip-to-`ready` aborts when `recipe_digest` or `storage_key` changed during
   ingest (mirrors AV-03-10).
5. `Rindle.Workers.MuxSyncProviderAsset` defensively polls
   `processing`/`uploading` rows older than the configured floor and
   transitions to `:errored` with reason `:provider_asset_stuck` past the
   stuck-threshold cap; provider ingest and sync emit telemetry under
   `[:rindle, :provider, :ingest, :start | :stop | :exception]` and
   `[:rindle, :provider, :sync, :resolved | :stuck]` with documented
   schemas.

**Plans:** 4 plans (TBD by `/gsd-plan-phase 34`). Plan-count guidance: MUX-01..08
≈ 4–5 plans; chosen 4 to match the v1.5 rhythm and Phase 34's MEDIUM risk
profile.

**UI hint**: no

##### Phase 35 — Signed-Webhook Plug + Idempotent Ingest

**Goal:** Webhooks become the primary readiness signal — cryptographically
verified, replay-protected, secret-rotation-aware, and Oban-deferred. Highest-
fidelity phase: raw-body cache, multi-secret rotation, replay protection, and
idempotency all land here.

**Depends on:** Phase 34 (provider state in `media_provider_assets`,
`Rindle.Streaming.Provider.Mux` behaviour implementation).

**Requirements:** MUX-09, MUX-10, MUX-11, MUX-12, MUX-13, MUX-14 (6 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `Rindle.Delivery.WebhookPlug` is a mountable provider-aware Plug that
   adopters mount via a documented `forward` declaration; the shipped
   `Rindle.Delivery.WebhookBodyReader` reads the raw body and bypasses
   `Plug.Parsers` JSON decoding for the webhook scope.
2. Bypass-driven ExUnit posts a fixture `video.asset.ready` payload with a
   real HMAC signature against the Plug; `Rindle.Workers.IngestProviderWebhook`
   idempotently flips the matching `media_provider_assets` row to `:ready`,
   persists `playback_ids`, and broadcasts `:provider_asset_ready` PubSub.
3. A second identical post is a no-op (Oban `unique` keyed on the Mux event
   UUID); replay attack with a 600s-old timestamp returns 400 with
   `:provider_webhook_invalid`; signature mismatch returns the same 400 with
   the same atom (operators distinguish via telemetry metadata, not error
   variants).
4. Multi-secret rotation works: the Plug tries `:webhook_secrets` in order,
   first-match wins, and a metric records which secret index matched so
   operators can confirm rotation completed before retiring the previous
   secret; tolerance is configurable up to 900s and rejected below 60s.
5. Workers exceeding `max_attempts` leave the affected row in its
   last-known good state with `last_sync_error` populated; `mix
   rindle.runtime_status --provider-stuck` lists stuck/uploading rows older
   than the configured threshold (extends the v1.5 surface; no new
   dead-letter queue).

**Plans:** 4 plans (TBD by `/gsd-plan-phase 35`). Plan-count guidance: MUX-09..14
≈ 3–4 plans; chosen 4 because Phase 35 is the highest-risk phase in the
milestone (HIGH risk; ~40% of milestone effort) and warrants the slightly
finer-grained verification rhythm.

**UI hint**: no

##### Phase 36 — Public DX, Onboarding, CI Proof

**Goal:** Lock the adopter onboarding path; prove the package-consumer story
matches v1.5's bar.

**Depends on:** Phase 35 (Plug, workers, durable state all working
end-to-end).

**Requirements:** MUX-15, MUX-16, MUX-17, MUX-18, MUX-19 (5 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `Rindle.Profile.Presets.MuxWeb` ships alongside the existing
   `Rindle.Profile.Presets.Web` and demonstrates `:streaming` opt-in with the
   `:signed` named playback policy.
2. `mix rindle.doctor` validates streaming configuration — token id/secret,
   signing key id + RSA private key, webhook secrets, and a 5s smoke ping to
   `Mux.Video.Assets.list/1` — and reports per-profile streaming status with
   PASS/FAIL.
3. A fresh `mix phx.new` adopter app installs Rindle, declares
   `Rindle.Profile.Presets.MuxWeb`, runs `mix rindle.doctor`, uploads a sample
   mp4, and renders a `<video>` tag whose `src` resolves to a Mux-signed HLS
   URL — all from CI, all from the published artifact.
4. The generated-app package-consumer proof harness has a `mux-enabled` lane
   alongside the existing `image-only` and `av-enabled` lanes; PR builds run
   cassette-based Mux fixtures by default; a gated `mux-soak` lane runs against
   real Mux every PR labelled `streaming`.
5. `guides/streaming_providers.md` ships the Mux-only section (env vars,
   signing-key creation, secret rotation, raw-body cache wiring, ngrok-style
   local tunnel guidance, doctor smoke); README and getting-started gain a
   "Streaming with Mux" subsection that points at the new guide while the
   image and AV onboarding paths remain the canonical first-run story.

**Plans:** 3 plans (TBD by `/gsd-plan-phase 36`). Plan-count guidance: MUX-15..19
≈ 3–4 plans; chosen 3 to match Phase 32's velocity baseline (3 plans) and the
fact that this phase is mostly DX/docs/CI-infra integration rather than novel
runtime work.

**UI hint**: yes

##### Phase 37 (optional) — Browser → Mux Direct Creator Upload

**Goal:** Adopters who don't want server-side ingest cost can let the browser
PUT directly to Mux. Skip this phase if Phases 33–36 ran long; it is a clean
v1.7 addition.

**Status:** OPTIONAL. Pulls forward only if Phases 33–36 ship under budget.

**Depends on:** Phase 36 (full adopter onboarding lane working in CI; presets
and doctor in place).

**Requirements:** MUX-20, MUX-21, MUX-22, MUX-23 (4 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `Rindle.Streaming.Provider.Mux.create_direct_upload/2` returns
   `%{upload_url, upload_id, provider_asset_id}` after creating a
   `media_provider_assets` row in `:pending` state with
   `direct_creator_upload: true`.
2. `Rindle.Streaming.Capabilities.require_streaming/2` gate exists and
   surfaces the `:direct_creator_upload` capability to adopters.
3. End-to-end LiveView test creates a direct upload, simulates client PUT,
   posts the `video.upload.asset_created` and `video.asset.ready` webhooks,
   and the LiveView receives both PubSub events
   (`:provider_asset_created`, `:provider_asset_ready`,
   `:provider_asset_errored` extend the v1.4 PubSub vocabulary through
   `Rindle.LiveView.subscribe/2`).
4. The `IngestProviderWebhook` worker links upload-id to asset-id when the
   direct-creator flow completes via the `video.upload.asset_created`
   handler.

**Plans:** 2 plans (TBD by `/gsd-plan-phase 37`). Plan-count guidance:
MUX-20..23 ≈ 2–3 plans; chosen 2 because this phase is small additive surface
on already-built primitives (LOW risk).

**UI hint**: yes

#### Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 33 — Provider Boundary + State Schema | 4/4 | Complete | 2026-05-06 |
| 34 — Mux REST Adapter + Server-Push Sync | 0/4 | Not started | — |
| 35 — Signed-Webhook Plug + Idempotent Ingest | 0/4 | Not started | — |
| 36 — Public DX, Onboarding, CI Proof | 0/3 | Not started | — |
| 37 (optional) — Browser → Mux Direct Creator Upload | 0/2 | Not started | — |

#### Coverage

- Total v1.6 requirements: **32** (STREAM-01..09 = 9, MUX-01..23 = 23)
- Mapped: **32 / 32** ✓
- Orphaned: 0
- Duplicated across phases: 0

## Archive

<details>
<summary>✅ v1.5 Adopter Hardening & Lifecycle Repair (Phases 29–32) — SHIPPED 2026-05-06</summary>

Full archive: [.planning/milestones/v1.5-ROADMAP.md](.planning/milestones/v1.5-ROADMAP.md)

</details>

<details>
<summary>✅ v1.4 Video & Audio Wedge (Phases 23–28) — SHIPPED 2026-05-05</summary>

Full archive: [.planning/milestones/v1.4-ROADMAP.md](.planning/milestones/v1.4-ROADMAP.md)

</details>

<details>
<summary>✅ v1.3 Live Publish & API Ergonomics (Phases 15–22) — SHIPPED 2026-05-02</summary>

Full archive: [.planning/milestones/v1.3-ROADMAP.md](.planning/milestones/v1.3-ROADMAP.md)

</details>

<details>
<summary>✅ v1.2 First Hex Publish (Phases 10–14) — SHIPPED 2026-04-29</summary>

Full archive: [.planning/milestones/v1.2-ROADMAP.md](.planning/milestones/v1.2-ROADMAP.md)

</details>

<details>
<summary>✅ v1.1 Adopter Hardening (Phases 6–9) — SHIPPED 2026-04-28</summary>

Full archive: [.planning/milestones/v1.1-ROADMAP.md](.planning/milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 MVP (Phases 1–5) — SHIPPED</summary>

Full archive: [.planning/milestones/v1.0-ROADMAP.md](.planning/milestones/v1.0-ROADMAP.md)

</details>
