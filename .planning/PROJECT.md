# Rindle

## Current Milestone: v1.4 Video & Audio Wedge

**Goal:** Extend Rindle from image-first to image+video+audio by shipping a system-FFmpeg-backed processor (`Rindle.Processor.AV`), an `ffprobe`-driven analyzer, and `Rindle.HTML.video_tag/3` + `audio_tag/3` helpers — all riding the existing `Rindle.Processor` behaviour, `MediaAsset`/`MediaVariant` rows, Oban workers, and signed-URL delivery.

**Target features:**
- Video / audio domain model — single `media_assets` table + `:kind` discriminator (`:image | :video | :audio`); single `media_variants` table + `:output_kind` (`:image | :video | :audio | :waveform`); typed probe columns for duration / dimensions / track presence; JSONB metadata for codec / bitrate / tags; one additive migration; existing image profiles compile unchanged
- AV processor — `Rindle.Processor.AV` shells out to FFmpeg via FFmpex with MuonTrap-supervised subprocesses; ships H.264+AAC mp4 transcode, scene-detected poster, AAC/MP3 audio transcode, EBU R128 single-pass loudnorm, and JSON waveform peaks; idempotent worker; output post-condition probe; orphan-tempfile sweeper
- Capability negotiation — new `Rindle.Processor.Capabilities` module mirrors existing `Rindle.Storage.Capabilities`; `mix rindle.doctor` reports per-variant capability status with `mix phx.gen`-style fix messages; boot probe runs `ffmpeg -version` + `-codecs` and fails fast at supervisor boot when video/audio profiles are configured but FFmpeg is missing
- Delivery surface — production stays signed-redirect (S3/R2/GCS/MinIO already serve `Range` natively, zero BEAM time on streaming bytes); new opt-in `Rindle.Delivery.LocalPlug` gives dev parity for `Rindle.Storage.Local`; `Rindle.Delivery.streaming_url/3` ships as a no-op delegate so Mux / Cloudflare Stream provider adapters can land post-v1.4 without template churn
- HTML + LiveView ergonomics — `Rindle.HTML.video_tag/3` and `audio_tag/3` mirror existing `picture_tag/3` shape with codec-aware `<source>` ordering and DSL-resolved poster; `Rindle.LiveView.subscribe/2` exposes per-variant transcode progress via PubSub (`rindle:variant:#{id}`) for live status UIs; `Rindle.cancel_processing/1` cancels in-flight transcodes
- Security invariants for AV — argv-array discipline (no shells, no string interpolation); mandatory `-protocol_whitelist file,crypto,data`; four-cap enforcement (`-t` / `-fs` / `-timelimit` / external wall-clock); MuonTrap-supervised subprocess with cgroup parent-death kill; sweepable `Rindle.tmp/` root with scheduled orphan reaper; FFmpeg minimum version 6.0 enforced at boot; HLS / DASH / MKV ingest explicitly rejected; container metadata treated as untrusted UGC

## Current State

Milestone `v1.3 Live Publish & API Ergonomics` shipped on `2026-05-02`
(Phases 15–22, 21 plans). v1.3 delivered the first live Hex.pm publish with
post-publish HTTP probe for `hexdocs.pm/rindle`, locked the public API
surface boundary, brought `@doc`/`@spec`/`@moduledoc` coverage to 100/100/100
enforced via `mix doctor --raise`, shipped ergonomic `attachment_for/2`,
`ready_variants_for/1` and `!`-bang convenience helpers, tightened Dialyzer
struct resolution, and resolved residual LiveView correctness issues. v1.4
opens the video / audio wedge: Rindle finally moves beyond image-first and
extends the same lifecycle architecture (FSMs, durable variant rows, Oban
workers, signed delivery) to mp4 / mov / webm video and mp3 / m4a / wav /
flac / ogg audio.

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

### Active

<!-- v1.4 requirements — updated 2026-05-02 -->

- [ ] AV foundations: capability vocabulary, processor capabilities behaviour,
  MuonTrap subprocess discipline, FFmpeg boot probe, `mix rindle.doctor`,
  argv-array safety, `-protocol_whitelist` defaults, four-cap resource
  enforcement (AV-01)
- [ ] Domain model + DSL extension: `:kind` and `:output_kind` migration with
  typed probe columns; per-kind NimbleOptions schemas in profile validator;
  `transcoding` asset state and `cancelled` variant state; `Rindle.Probe`
  behaviour with bundled `Rindle.Probe.AVProbe` (AV-02)
- [ ] `Rindle.Processor.AV` ships H.264+AAC mp4 transcode, scene-detected
  poster, AAC/MP3 audio transcode, EBU R128 loudnorm, and JSON waveform
  peaks; idempotent worker with output post-condition probe and orphan
  tempfile sweeper (AV-03)
- [ ] Delivery surface: `Rindle.Delivery.streaming_url/3` ships as no-op
  delegate (kind: :progressive); `Rindle.Delivery.LocalPlug` provides
  range-aware dev parity for `Rindle.Storage.Local`; signed-URL TTL guidance
  documented per content type (AV-04)
- [ ] HTML helpers + LiveView integration: `Rindle.HTML.video_tag/3` and
  `audio_tag/3` mirror `picture_tag/3` with codec-aware sources and
  DSL-resolved poster; `Rindle.LiveView.subscribe/2` exposes
  rate-limited PubSub progress; `Rindle.cancel_processing/1` cancels
  in-flight transcodes (AV-05)
- [ ] Onboarding + CI proof: stock 720p web preset profile fixture; per-
  platform install paths documented (macOS, Ubuntu, Fly.io, Heroku, Render,
  GitHub Actions); CI verifies FFmpeg detection plus a real-world
  smartphone-source video round-trip; capability-mismatch error vocabulary
  frozen with parity test (AV-06)

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

**v1.1 result:** the adopter-owned runtime boundary is now real, multipart
uploads are additive on top of the existing trusted promotion flow, capability
claims are centralized and proved against MinIO, and a fresh Phoenix consumer
can install the built package and follow a docs path that is enforced by tests.

**v1.2 inflection point:** Rindle now looks like a publishable library, but the
first public `Hex.pm` release path has not yet been exercised for real.
Distribution, owner/auth setup, rollback posture, and future release routine
need one deliberate public cut before the next milestone shifts back to API or
upload-surface expansion.

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
| `Rindle.Delivery.streaming_url/3` ships as a no-op delegate now to reserve the surface for HLS / Mux / CF Stream provider adapters | Active Storage's mistake was conflating progressive-blob URLs with manifest URLs; reserving the namespace now means adopter video templates won't churn when streaming providers land | Locked v1.4 |

## Historical Snapshot

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
*Last updated: 2026-05-02 — v1.3 archived (PUBLISH-01/02/03, API-01/02/03/04, VERIFY-02 → Validated); v1.4 Video & Audio Wedge opens with AV-01..AV-06 active; security invariants extended to 13 (FFmpeg argv discipline, `-protocol_whitelist`, four-cap enforcement, untrusted container metadata, MKV/HLS rejection, MuonTrap-supervised subprocess); `Rindle.Processor.AV` locked over Membrane / NIFs / bundled providers based on cross-language peer-lib evidence (Active Storage, Shrine, Spatie, CarrierWave, Django).*
