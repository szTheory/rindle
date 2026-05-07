# Rindle

## Current State

Milestone `v1.6 Provider Boundary + Mux` shipped on `2026-05-07` (Phases 33-36,
15 plans, 28/32 requirements validated). Rindle now ships a runtime provider
contract with `Rindle.Streaming.Provider.Mux` as the reference adapter:
server-push ingest from existing AV variants, signed HLS playback via
JOSE-signed JWT, mountable signed-webhook Plug with multi-secret rotation +
replay protection, durable provider state in `media_provider_assets`,
defensive Oban-driven sync, and a generated-app `mux-enabled` package-consumer
proof lane alongside the v1.5 image-only and AV-enabled lanes. The
optional/deferred `:mux ~> 3.2` + `:jose ~> 1.11` deps mean non-streaming
adopters pay zero transitive cost.

Milestone v1.6 closes the streaming wedge that v1.4's reserved
`streaming_url/3` seam pointed at. The next milestone is open for definition
via `/gsd-new-milestone`. Locked v1.7+ adapter scope: GCS resumable adapter
(`v1.6-CANDIDATE-GCS.md`, 5 phases) and tus protocol (`v1.6-CANDIDATE-TUS.md`,
5 phases) are research-locked candidates; Phase 37 (browser→Mux direct
creator upload, MUX-20..23) deferred to v1.7 since v1.6 budget held without
pulling forward.

## Next Milestone Goals

No active milestone yet — start with `/gsd-new-milestone`. Candidate scope:

- **v1.7 — GCS Resumable Adapter** (locked plan): `Rindle.Storage.GCS` adapter
  on the existing `Rindle.Storage` behaviour using `goth ~> 1.4` + `finch` +
  `gcs_signed_url`; resumable upload session promotion (RESUMABLE-01..14);
  generated-app GCS proof lane.
- **v1.7 — Phase 37 pull-forward** (browser→Mux direct creator upload,
  MUX-20..23): small additive surface on already-built primitives,
  `Rindle.Streaming.Provider.Mux.create_direct_upload/2`, LiveView PubSub
  vocabulary extension.
- **v1.7+ — Code-review polish**: address Phase 36 CR-01/02/03 soak-lane
  defects + ~25 Warning/Info findings deferred from Phases 34/35/36.
- **v1.8 — tus Resumable Upload Protocol** (locked plan): mountable
  `Rindle.Upload.TusPlug` macro on `tussle ~> 0.3.1`; HMAC-signed tus URLs;
  S3 multipart `UploadPart` per-PATCH on the S3 path; Ecto-backed Tussle cache.

## Historical Milestone: v1.6 Provider Boundary + Mux (SHIPPED 2026-05-07)

**Goal:** Productize `Rindle.Streaming.Provider` as a real adapter contract and
ship Mux as the single reference streaming provider — turning v1.4's reserved
`streaming_url/3` seam into provider-aware playback with durable provider state,
signed-webhook ingest, and Oban-driven sync — without expanding into a video
platform.

**Target features:**
- Provider behaviour contract (locked callbacks, capability vocabulary).
- `Rindle.Streaming.Provider.Mux` reference adapter (server-push ingest from an
  existing AV-produced variant; signed HLS playback via JOSE-signed JWT).
- `Rindle.Delivery.WebhookPlug` mountable signed-webhook plug with multi-secret
  rotation, replay window, and idempotent Oban-deferred ingest.
- New `media_provider_assets` Ecto table for durable provider state (additive;
  no changes to `media_assets` or `media_variants`).
- Profile DSL `:streaming` key with locked named-preset playback policy
  (`:signed` / `:public`); raw provider knobs forbidden.
- Provider-aware `streaming_url/3` dispatch rule with non-strict default
  (progressive fallback while ingest is in flight) and `:strict` opt for
  provider-only.
- Five additive locked error atoms; v1.4-frozen delivery telemetry preserved
  with one documented metadata extension (`kind: :hls`).
- Generated-app package-consumer `mux-enabled` proof lane alongside the existing
  image-only and av-enabled lanes.

**Key context:**
- Single provider only — Cloudflare Stream / Bunny Stream / Transloadit are
  v1.7+ adapters that test the contract, not v1.6 scope.
- Mux SDK (`mux ~> 3.2`, optional dep) already implements the two highest-risk
  pieces (HMAC webhook verification + JOSE JWT signing); Rindle adds the
  contract, the Plug, and the dispatch rule rather than reimplementing them.
- Out of scope explicitly: live streaming/RTMP/WebRTC, DRM, multi-region
  failover, browser→Mux direct creator upload (Phase 37 is optional pull-forward
  only if time permits), tus protocol (deferred), GCS adapter (deferred).
- Locked recommendation:
  `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md`.

**Deferred candidates (reserved for v1.7+):**
- `GCS-01`: truthful `Rindle.Storage.GCS` resumable adapter — see
  `.planning/research/v1.6-CANDIDATE-GCS.md` for the locked v1.7 plan.
- `TUS-01`: tus protocol family on a mountable Plug — see
  `.planning/research/v1.6-CANDIDATE-TUS.md` for the locked v1.8 plan.

## What This Is

Rindle is an open-source Phoenix/Ecto-native media lifecycle library for
Phoenix applications. It manages the full media lifecycle after upload: staged
objects, validation, analysis, media assets, attachments,
variants/derivatives, background processing, signed delivery, cleanup,
regeneration, and operational visibility. Rindle is not a file upload helper;
it is the durable lifecycle layer that helps Phoenix teams ship media features
with production confidence.

## Core Value

Media, made durable.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- Phase 1 — Foundation: schemas, FSMs, profile DSL, validation primitives, and
  local/S3 storage adapters shipped in v1.0.
- Phase 2 — Upload & Processing: proxied/direct upload flows, image
  processing, Oban workers, and atomic attach/purge behavior shipped in v1.0.
- Phase 3 — Delivery & Observability: signed delivery, telemetry contract, and
  responsive image helpers shipped in v1.0.
- Phase 4 — Day-2 Operations: cleanup, regeneration, storage verification,
  metadata backfill, and maintenance workers shipped in v1.0.
- Phase 5 — CI & 1.0 Readiness: CI lanes, adopter integration, release lane,
  and narrative guides shipped in v1.0.
- Phase 6 — Adopter Runtime Ownership: public runtime Repo resolution,
  adopter-only lifecycle proofs, and adopter-first Repo/Oban guidance verified
  in v1.1.
- Phase 7 — Multipart Uploads: multipart session persistence, cleanup, and real
  MinIO-backed completion/abort proofs verified in v1.1.
- Phase 8 — Storage Capability Confidence: shared capability vocabulary,
  MinIO-backed proof, and honest Cloudflare R2 compatibility guidance verified
  in v1.1.
- Phase 9 — Install & Release Confidence: generated-app package-consumer smoke,
  CI and release reuse, and executable install-doc parity proof verified in
  v1.1.
- ✓ First public `Hex.pm` publish path exercised from the real repository
  workflow — v1.2 (Phase 11)
- ✓ Release automation performs a protected real publish and fails safely before
  publication if package/docs/install gates drift — v1.2 (Phase 11)
- ✓ Maintainer can verify the published package from Hex.pm and follow a
  documented rollback path — v1.2 (Phase 12)
- ✓ Release requirement traceability metadata and runbook aligned with live
  workflow contract — v1.2 (Phase 13)
- ✓ Phases 10 and 11 VALIDATION artifacts completed to Nyquist-compliant state
  — v1.2 (Phase 14)
- ✓ First live Hex.pm publish executed from the real repo workflow with
  `HEX_API_KEY` and post-publish public verification confirmed — v1.3
  (Phases 15/16, formally verified Phase 20) (PUBLISH-01)
- ✓ CI failures in the release pipeline diagnosed and fixed before live
  publish attempt — v1.3 (Phase 15, formally verified Phase 20) (PUBLISH-02)
- ✓ Routine release path documented and executable after first publish — v1.3
  (Phase 16, formally verified Phase 20) (PUBLISH-03)
- ✓ Public API surface reviewed for naming inconsistencies — v1.3 (Phase 17)
  (API-01)
- ✓ Missing convenience functions identified and added to public surface
  (`attachment_for/2`, `ready_variants_for/1`, `!`-bang variants) — v1.3
  (Phase 19) (API-02)
- ✓ `@doc`, `@spec`, `@moduledoc` coverage gaps resolved on public functions
  (100/100/100, enforced via `mix doctor --raise`) — v1.3 (Phase 18) (API-03)
- ✓ Breaking-change audit completed to lock the right surface area before 1.0
  — v1.3 (Phase 17) (API-04)
- ✓ HexDocs reachability probe verifies post-publish public docs availability
  — v1.3 (Phase 21) (VERIFY-02)
- ✓ AV capability negotiation, guarded FFmpeg/FFprobe subprocess execution,
  boot probing, and `mix rindle.doctor` shipped — v1.4 (Phase 23) (AV-01)
- ✓ Typed AV domain fields, per-kind DSL validation, probe dispatch, and
  image-only backward compatibility shipped — v1.4 (Phase 24) (AV-02)
- ✓ `Rindle.Processor.AV` shipped preset-led video/audio outputs, waveform
  generation, runtime guards, and durable worker contracts — v1.4 (Phase 25)
  (AV-03)
- ✓ Delivery gained `streaming_url/3`, local range-aware playback, RFC 5987
  filenames, and frozen delivery telemetry — v1.4 (Phase 26) (AV-04)
- ✓ Phoenix-facing AV helpers, LiveView progress/cancellation, and the locked
  AV error vocabulary shipped — v1.4 (Phase 27) (AV-05)
- ✓ Public AV onboarding, profile-aware doctor CI gates, smartphone-source
  lifecycle proof, and docs/telemetry parity shipped — v1.4 (Phase 28)
  (AV-06)
- ✓ Provider boundary contract — capability vocabulary, promoted
  `Rindle.Streaming.Provider` runtime behaviour, additive
  `media_provider_assets` Ecto table + FSM, profile DSL `:streaming` key,
  `streaming_url/3` dispatch tree, 5 streaming reason atoms with parity
  freeze, `Rindle.Capability.report/0` extension — v1.6 (Phase 33)
  (STREAM-01..09)
- ✓ Mux REST adapter + server-push sync — `mux ~> 3.2` + `jose ~> 1.11`
  optional deps, signed-playback URL minting via `Mux.Token` with explicit
  TTL (defeats 7-day default), `MuxIngestVariant` Oban worker with two-layer
  idempotency + atomic-promote race protection + 429 Retry-After snooze,
  `MuxSyncCoordinator` + `MuxSyncProviderAsset` defensive polling, telemetry
  redaction parity — v1.6 (Phase 34) (MUX-01..08)
- ✓ Signed-webhook plug + idempotent ingest — mountable
  `Rindle.Delivery.WebhookPlug`, raw-body cache pattern via
  `WebhookBodyReader`, `Mux.Webhooks.verify_header/4` HMAC-SHA256 verify,
  multi-secret rotation with `secret_index` telemetry, 60–900s configurable
  replay window, `IngestProviderWebhook` Oban worker idempotent on Mux event
  UUID, race-snooze on row-missing, two-topic PubSub broadcast,
  `mix rindle.runtime_status --provider-stuck` extension — v1.6 (Phase 35)
  (MUX-09..14)
- ✓ Public DX, onboarding, CI proof — `Rindle.Profile.Presets.MuxWeb` preset,
  `mix rindle.doctor --streaming` 4 PASS/FAIL checks + 5s smoke ping,
  `guides/streaming_providers.md` (341 lines), README + getting-started
  `Streaming with Mux (optional)` subsections, generated-app `mux-enabled`
  cassette lane (every PR) + label-gated `mux-soak` real-Mux sibling
  (`streaming`-labelled PRs only) with three-layer asset-leak mitigation
  — v1.6 (Phase 36) (MUX-15..19)

### Active

(None — milestone v1.6 closed. Start the next milestone with
`/gsd-new-milestone`.)

**Candidate next requirements (deferred from v1.6):**
- `MUX-20..23`: browser→Mux direct creator upload — Phase 37 not pulled
  forward in v1.6; clean additive surface on already-built primitives.
- `GCS-01..04` + `RESUMABLE-01..14`: truthful `Rindle.Storage.GCS` resumable
  adapter — locked v1.7 plan in `.planning/research/v1.6-CANDIDATE-GCS.md`
- `TUS-01..19`: tus protocol family on a mountable Plug — locked v1.8 plan in
  `.planning/research/v1.6-CANDIDATE-TUS.md`
- Code-review polish for Phases 34/35/36 — CR-01/02/03 (Phase 36 soak-lane
  operational defects) + ~25 Warning/Info findings deferred to v1.7.

### Out of Scope

- Full HLS/DASH streaming platform, DRM, global adaptive video management —
  Rindle is a lifecycle library, not a media platform; these belong to provider
  adapters (Mux, Transloadit)
- Arbitrary unsigned dynamic transformation API — unsigned dynamic resizes are
  a DoS/cost vector; named presets and signed transforms only
- Built-in GPU/AI runtime requirements — AI processors are extension points
  backed by external providers, not core dependencies
- Office/PDF/SVG broad processing by default — requires hardened
  sandbox/container guidance that is not universally available
- "Cloud replacement" or managed CDN product positioning — Rindle is a
  library; CDN behavior is an adopter responsibility
- Full GCS adapter in v1.1 — capability design should remain ready for GCS, but
  the adapter and resumable flow stay deferred until after multipart/S3 support
- tus/resumable upload protocol in v1.1 — multipart is the nearer production
  need; tus remains a later adapter path
- FFmpeg/Membrane adapters in v1.1 — image-first remains the wedge; video/audio
  adapters follow once host-app/runtime boundaries are solid
- PDF preview adapter in v1.1 — still out-of-scope until sandboxing posture is
  documented
- Admin LiveView UI in v1.1 — operator workflows remain code/telemetry/task
  driven for now

## Context

**v1.6 result:** Rindle ships a real streaming provider contract with Mux as
the single reference adapter — the v1.4-reserved `streaming_url/3` seam now
backs a runtime behaviour, durable provider state, signed-webhook ingest with
multi-secret rotation, idempotent Oban-driven sync, and a generated-app
package-consumer `mux-enabled` proof lane alongside v1.5's image-only and
AV-enabled lanes. Optional `mux` + `jose` deps preserve zero transitive cost
for non-streaming adopters. The single-provider rule keeps the abstraction
honest; v1.7+ adapters (GCS, second streaming provider) become contract tests.

**Current milestone setup:** v1.6 closed. No new milestone is open yet.
Candidate expansion work: pull Phase 37 forward (browser→Mux direct creator
upload, MUX-20..23), GCS resumable adapter (locked v1.7 plan), tus protocol
(locked v1.8 plan), and code-review polish for Phase 36 soak-lane defects.

**Reference implementations:**
- Rails Active Storage: attachment/blob ownership patterns, redirect-style
  delivery, and background purge lessons
- Shrine: host-app ownership, atomic promotion, and derivatives as first-class
  records
- Spatie Media Library: strong "day-two" ergonomics and opinionated DX
- imgproxy: capability- and signature-driven delivery constraints

**Security invariants (must hold in all implementations):**
1. Never trust client MIME/filename; enforce magic-byte sniffing and allowlists
2. Do not attach/process direct uploads until completion is verified
3. Do not allow unbounded variant explosion; named presets only by default
4. Storage side effects are not hidden inside DB transactions
5. Purge paths are async, idempotent, and auditable
6. Concurrent replacement races resolve safely
7. Missing/stale/failed variant states are visible, queryable, and actionable
8. FFmpeg / FFprobe subprocess invocation uses argv list only — never shell.
   All user-controllable parameters (codec, container, dimensions, duration,
   bitrate) are validated against named-preset allowlists before reaching argv.
9. Every FFmpeg / FFprobe invocation passes `-protocol_whitelist file,crypto,data`
   and runs under hard caps for duration (`-t`), output size (`-fs`), CPU
   time (`-timelimit`), wall-clock time (external), and threads (`-threads`).
   Wall-clock kill is enforced externally; FFmpeg's `-timelimit` alone is
   insufficient.
10. Container metadata (title, artist, comment, embedded subtitles,
    attachments) is treated as untrusted user-controlled content end-to-end.
    Rindle stores it opaquely (truncated, control-chars stripped); adopters
    MUST sanitize on render.
11. HLS / DASH / playlist-style ingest is out of scope. Inputs accepted by
    ingest are single-container files only (mp4, mov, webm, m4a, mp3, wav,
    flac, ogg).
12. Rindle declares an FFmpeg minimum version (≥ 6.0), capability-probes at
    supervisor boot, and refuses to start with stale or missing FFmpeg when
    video / audio profiles are configured. Adopters never silently inherit
    FFmpeg CVE exposure.
13. Temp files for transcoding live under a single sweepable root
    (`Rindle.tmp/`); orphans are reaped by a scheduled `Rindle.Ops` worker.
    No transcode is allowed without an enforceable parent-death subprocess
    kill (MuonTrap on Linux; Rambo on macOS / Windows dev).
14. Raw provider identifiers (`provider_asset_id`, provider upload IDs,
    provider session URIs) are never exposed in adopter-facing paths,
    URLs, logs, telemetry metadata, or `inspect/2` output. Only the
    public-side `playback_id` (or equivalent) crosses into URLs. Telemetry
    metadata redacts provider-internal IDs to last-4-char tags. Provider
    bearer credentials (Mux signing keys, GCS resumable session URIs, tus
    upload URLs) are treated as secrets at rest and in transit; custom
    `Inspect` impls on persistence rows redact them. (Added v1.6.)

## Constraints

- **Tech stack**: Elixir/Phoenix/Ecto only in core; no non-Elixir runtime in
  the library
- **Repo ownership**: adopter apps own the runtime Repo and DB credentials; the
  library may keep `Rindle.Repo` only as a local test/dev harness
- **Background jobs**: Oban remains the required job backend; multipart flows
  and cleanup must integrate with Oban rather than invent a parallel runner
- **Security defaults**: private delivery remains the default; multipart support
  must preserve the same verification and allowlist guarantees as presigned PUT
- **Capability honesty**: adapters must advertise only what they truly support;
  unsupported flows must fail as tagged errors, not degraded surprises
- **Backward compatibility**: existing presigned PUT flows stay supported;
  multipart is additive and must not break current adopters
- **Docs posture**: practical, copy-pasteable, production-aware, and
  maintainer-to-maintainer in tone

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Media-agnostic core, image-first implementation | Images are the highest-leverage wedge; core domain model must not assume image so video/audio can slot in later | ✓ Good |
| Variants are first-class DB records, not hidden filenames | Queryable state enables admin, retries, stale detection, cleanup, and reporting | ✓ Good |
| Oban as required job backend | Oban is SQL-backed, persistent, observable, and supports transactional enqueueing | ✓ Good |
| Telemetry naming and metadata are public contracts | Operators will build dashboards and alerts against these; silent breakage is unacceptable | ✓ Good |
| Named presets only by default; dynamic transforms opt-in and signed | Unsigned dynamic transforms are a DoS/cost vector | ✓ Good |
| Async purge after DB commit | Storage I/O inside DB transactions is a consistency and latency trap | ✓ Good |
| Repo ownership is adopter-first (`repo: MyApp.Repo`), not library-owned | Matches idiomatic Ecto library architecture and avoids split ownership | ✓ Good |
| `Rindle.Repo` is test/dev harness only, not a consumer runtime dependency | Keeps library development practical while preserving adopter-owned runtime boundaries | ✓ Validated in Phase 6 |
| Capability-driven storage negotiation is the contract boundary | Backend support differs materially across S3-compatible providers and future GCS/resumable flows | ✓ Validated in Phase 8 |
| Multipart uploads belong in v1.1, not v1.0 | Presigned PUT was enough for the first release, but larger production workloads need a better direct-upload path | ✓ Validated in Phase 7 |
| Install proof should be package-consumer-first | A passing repo CI lane is not the same as a fresh Phoenix adopter succeeding from the published artifact | ✓ Validated in Phase 9 |
| First public Hex publish should be scoped narrowly and exercised before broader API cleanup | The release path is the remaining trust gap and should become routine before new surface-area bets | ✓ Validated in Phases 10–14 |
| Public API surface and convenience helpers locked before 1.0 | Adoption pressure grows after first publish; renames carry semver cost | ✓ Validated in Phases 17–19 |
| Video / audio ships via system FFmpeg subprocess (FFmpex + MuonTrap), not Membrane / NIFs / bundled provider | Out-of-process subprocess crashes retry cleanly via Oban; NIFs that wrap libavcodec turn FFmpeg CVEs into BEAM crashes; Membrane is the right tool for streaming pipelines, wrong tool for one-shot file derivatives; every peer lib (Active Storage, Shrine, Spatie, CarrierWave, Django) shells out to FFmpeg | Locked v1.4 |
| Single `media_assets` + `:kind` discriminator (vs polymorphic / split tables) | Active Storage validates the single-table approach at scale; Elixir pattern matching shines on atom enums; operator queryability requires typed columns, not JSONB-only | Locked v1.4 |
| Variants stay first-class DB rows with `:output_kind`; cross-kind derivatives (video → poster image, audio → waveform) are plain rows, no special cases | Day-2 ops queries (`WHERE state='failed' AND output_kind=:video`) stay SQL-native; Shrine's flat-derivatives JSON blob loses this | Locked v1.4 |
| HLS / DASH / DRM / live streaming / dynamic per-request video transforms remain out of core scope | Streaming framework territory (Mux, Cloudflare Stream, Membrane); manifest ingest is an SSRF + RCE surface (CVE-2016-1897, CVE-2020-13904, multiple HackerOne reports) | Locked v1.4 |
| Provider-delegated processors (Mux / Cloudflare Stream / Transloadit) ship as a documented custom-`Rindle.Processor` recipe, not as bundled adapters in core | Adopter contract stays narrow; adapter pluggability can land in v1.5+ if real adopter feedback requests it; v1.2 / v1.3 retro confirmed tight scope ships cleanly | Locked v1.4 |
| `Rindle.Delivery.streaming_url/3` ships as a no-op delegate now to reserve the surface for HLS / Mux / CF Stream provider adapters | Active Storage's mistake was conflating progressive-blob URLs with manifest URLs; reserving the namespace now means adopter video templates won't churn when streaming providers land | ✓ Validated in v1.6 (Phase 33: 8-branch dispatch tree on the reserved surface; zero adopter churn) |
| `Rindle.Streaming.Provider` is the contract boundary, not adapter modules; Mux is the reference adapter, not the contract | Single-provider rule keeps abstraction honest; second adapter (Cloudflare/Bunny) is the contract test in v1.7+, not v1.6 scope | Locked v1.6 |
| `mux ~> 3.2` + `jose ~> 1.11` ship as optional deps, not required deps | Adopters who don't enable streaming pay zero transitive cost; Mux SDK's Tesla + JOSE surface stays adapter-local | ✓ Validated v1.6 (Phase 34) |
| Webhook signature verification delegates to `Mux.Webhooks.verify_header/4`, not reimplemented in Rindle | Mux SDK's HMAC + JOSE implementations are the highest-risk pieces; reimplementing risks divergence from the provider's own constant-time semantics | ✓ Validated v1.6 (Phase 35) |
| Raw-body cache for webhooks is the `Plug.Parsers :body_reader` MFA pattern, not a separate route or `pull_request_target`-style escape hatch | Same pattern Stripe.WebhookPlug uses; mountable via documented `forward` declaration; bypasses JSON decoding only in the webhook scope | ✓ Validated v1.6 (Phase 35) |
| Provider-internal IDs (Mux `asset_id`, upload IDs, session URIs) redact to last-4-char tag in telemetry, logs, and `Inspect` output (security invariant 14) | Raw provider IDs leak across adopter boundaries in dashboards and traces; cross-cutting parity test enforces last-4 redaction at every emit site | Locked v1.6 |
| Generated-app `mux-soak` lane is label-gated (`streaming` PR label), not on every PR; cassette lane runs every PR with zero secrets | Real-Mux quota + cost; fork-PR safety: secrets resolve to empty strings on forks via `pull_request` (NOT `pull_request_target`) trigger | ✓ Validated v1.6 (Phase 36) |
| Phase 37 (browser→Mux direct creator upload) ships only if Phases 33-36 ship under budget | Single-provider rule keeps milestone scope honest; direct-creator-upload is small additive surface on already-built primitives — clean v1.7 deferral | ✓ Deferred to v1.7 (Phases 33-36 closed at budget without pulling forward) |

## Historical Snapshot

<details>
<summary>v1.6 Provider Boundary + Mux (Phases 33–36) — SHIPPED 2026-05-07</summary>

Milestone v1.6 turned v1.4's reserved `streaming_url/3` seam into a real
provider contract with Mux as the single reference adapter, without making
Rindle a video platform. Delivered: `Rindle.Streaming.Provider` runtime
behaviour with locked callbacks, additive `media_provider_assets` durable
state schema, profile DSL `:streaming` key, 8-branch dispatch tree,
`Rindle.Streaming.Provider.Mux` reference adapter (server-push ingest,
signed HLS playback, defensive sync workers, security-invariant-14
telemetry redaction), mountable `Rindle.Delivery.WebhookPlug` with
multi-secret rotation + replay protection + raw-body cache, idempotent
`IngestProviderWebhook` Oban worker, public `Rindle.Profile.Presets.MuxWeb`,
`mix rindle.doctor --streaming` validation, `guides/streaming_providers.md`
adopter reference, and a generated-app `mux-enabled` package-consumer
proof lane (cassette every PR + label-gated real-Mux soak). Optional
`mux` + `jose` deps mean non-streaming adopters pay zero transitive cost.

Full artifacts live in:

- [.planning/milestones/v1.6-ROADMAP.md](.planning/milestones/v1.6-ROADMAP.md)
- [.planning/milestones/v1.6-REQUIREMENTS.md](.planning/milestones/v1.6-REQUIREMENTS.md)

</details>

<details>
<summary>v1.5 Adopter Hardening & Lifecycle Repair (Phases 29–32) — SHIPPED 2026-05-06</summary>

Milestone v1.5 turned the fresh AV wedge into a much more truthful adoption and
operations story. Delivered: package-consumer proof for image-only and
AV-enabled installs from shipped artifacts, explicit `reprobe` and
`requeue_variants` repair surfaces, dry-run-first sweep and truthful
regeneration guidance, deterministic `mix rindle.doctor` and
`mix rindle.runtime_status` diagnostics, additive repair/runtime telemetry, and
a generated-app proof lane for upgrading pre-v1.4 adopters into the current
AV-aware shape and recovering cancelled work.

Full artifacts live in:

- [.planning/milestones/v1.5-ROADMAP.md](.planning/milestones/v1.5-ROADMAP.md)
- [.planning/milestones/v1.5-REQUIREMENTS.md](.planning/milestones/v1.5-REQUIREMENTS.md)
- [.planning/milestones/v1.5-MILESTONE-AUDIT.md](.planning/milestones/v1.5-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.4 Video & Audio Wedge (Phases 23–28) — SHIPPED 2026-05-05</summary>

Milestone v1.4 expanded Rindle from image-first into image+video+audio without
changing the core lifecycle philosophy. Delivered: AV capability negotiation,
guarded FFmpeg/FFprobe subprocesses, typed `kind`/`output_kind` domain fields,
`Rindle.Processor.AV`, range-aware local playback, `video_tag/3` and
`audio_tag/3`, LiveView progress/cancellation contracts, and a smartphone-source
adopter proof lane that locks the public onboarding story into docs and CI.

Full artifacts live in:

- [.planning/milestones/v1.4-ROADMAP.md](.planning/milestones/v1.4-ROADMAP.md)
- [.planning/milestones/v1.4-REQUIREMENTS.md](.planning/milestones/v1.4-REQUIREMENTS.md)
- [.planning/milestones/v1.4-MILESTONE-AUDIT.md](.planning/milestones/v1.4-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.3 Live Publish & API Ergonomics (Phases 15–22) — SHIPPED 2026-05-02</summary>

Milestone v1.3 executed Rindle's first real Hex.pm publish from the
repository workflow and locked the public API surface before adoption
pressure grew. Delivered: live `0.1.0` publish via the protected release
workflow with `HEX_API_KEY`, post-publish HTTP probe for `hexdocs.pm/rindle`
reachability, explicit `Rindle.Error` struct with typed reasons across
constraints / variants / attachments, 100/100/100 `@doc` / `@spec` /
`@moduledoc` coverage enforced via `mix doctor --raise`, ergonomic
`attachment_for/2` / `ready_variants_for/1` plus `!`-bang variants on the
public facade, tightened Dialyzer struct resolution, residual LiveView
correctness fixes, and goal-backward retrospective metadata closure for
Phases 15 and 16.

Full artifacts live in:

- [.planning/milestones/v1.3-ROADMAP.md](.planning/milestones/v1.3-ROADMAP.md)
- [.planning/milestones/v1.3-REQUIREMENTS.md](.planning/milestones/v1.3-REQUIREMENTS.md)
- [.planning/milestones/v1.3-MILESTONE-AUDIT.md](.planning/milestones/v1.3-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.2 First Hex Publish (Phases 10–14) — SHIPPED 2026-04-29</summary>

Milestone v1.2 proved Rindle's first real `Hex.pm` publication path end to end.
Delivered: shared release preflight, protected live publish with scoped
credentials, version drift gate, automated CI dry-run publish, post-publish
public verification job, maintainer release runbook with rollback/revert, and
Nyquist-compliant validation artifacts for all milestone phases.

Full artifacts live in:

- [.planning/milestones/v1.2-ROADMAP.md](.planning/milestones/v1.2-ROADMAP.md)
- [.planning/milestones/v1.2-REQUIREMENTS.md](.planning/milestones/v1.2-REQUIREMENTS.md)
- [.planning/milestones/v1.2-MILESTONE-AUDIT.md](.planning/milestones/v1.2-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.1 Adopter Hardening (Phases 6–9) — SHIPPED 2026-04-28</summary>

The `v1.1` milestone focused on adopter runtime ownership, multipart
upload support, capability honesty across MinIO and Cloudflare R2, and
package-consumer install proof from the built artifact.

Full artifacts live in:

- [.planning/milestones/v1.1-ROADMAP.md](.planning/milestones/v1.1-ROADMAP.md)
- [.planning/milestones/v1.1-REQUIREMENTS.md](.planning/milestones/v1.1-REQUIREMENTS.md)
- [.planning/milestones/v1.1-MILESTONE-AUDIT.md](.planning/milestones/v1.1-MILESTONE-AUDIT.md)

</details>

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? Move to Out of Scope with reason
2. Requirements validated? Move to Validated with phase reference
3. New requirements emerged? Add to Active
4. Decisions to log? Add to Key Decisions
5. "What This Is" still accurate? Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check; still the right priority?
3. Audit Out of Scope; reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-07 after v1.6 milestone — Provider Boundary + Mux shipped (Phases 33-36, 15 plans, 28/32 requirements validated; STREAM-01..09 + MUX-01..19 → Validated; MUX-20..23 deferred to v1.7). Active section now empty pending `/gsd-new-milestone`. Key Decisions extended with 8 new locked v1.6 outcomes (provider contract boundary, optional `mux`/`jose` deps, webhook signature delegation to `Mux.Webhooks.verify_header/4`, raw-body MFA pattern, security invariant 14, label-gated soak lane, Phase 37 deferral). Historical Snapshot prepended with v1.6 entry. Next: release-please auto-bumps `0.1.4 → 0.2.0` after `v1.6` tag pushes.*
