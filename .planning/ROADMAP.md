# Roadmap: Rindle

## Milestones

- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, see archive)
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28)
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29)
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02)
- 🚧 **v1.4 Video & Audio Wedge** — Phases 23–28 (in progress)

## Phases

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

### 🚧 v1.4 Video & Audio Wedge (In Progress)

**Milestone Goal:** Extend Rindle from image-first to image+video+audio by shipping a system-FFmpeg-backed processor (`Rindle.Processor.AV`), an `ffprobe`-driven analyzer, and `Rindle.HTML.video_tag/3` + `audio_tag/3` helpers — all riding the existing v1.0 architectural seams (`Rindle.Processor` behaviour, `MediaAsset`/`MediaVariant` rows, Oban workers, signed-URL delivery) without breaking image-only adopters.

**Source of truth:** `.planning/research/v1.4/SYNTHESIS.md` (locked decisions; agent-authored, not user-asked).

- [ ] **Phase 23: AV Foundations** — Capability vocabulary, FFmpeg/FFprobe shim, MuonTrap subprocess discipline, boot probe, `mix rindle.doctor`, security argv hygiene, four-cap resource enforcement
- [ ] **Phase 24: Domain Model & DSL Extension** — Single additive migration adding `:kind`/`:output_kind`/probe columns, per-kind NimbleOptions schemas, `transcoding` and `cancelled` FSM states, `Rindle.Probe` behaviour with `Rindle.Probe.AVProbe`, backward compat for image-only profiles
- [ ] **Phase 25: Rindle.Processor.AV** — H.264+AAC mp4 transcode, scene-detected poster, AAC/MP3 audio transcode, EBU R128 loudnorm, JSON waveform peaks, idempotent worker, output post-condition probe, orphan-tempfile sweeper, race guard
- [ ] **Phase 26: Delivery Surface** — `Rindle.Delivery.streaming_url/3` no-op delegate (reserves the surface), range-aware `Rindle.Delivery.LocalPlug` for dev parity, RFC 5987 download filenames, signed-URL TTL guidance per content type
- [ ] **Phase 27: HTML Helpers + LiveView Integration** — `Rindle.HTML.video_tag/3` + `audio_tag/3` mirroring `picture_tag/3`, `Rindle.LiveView.subscribe/2`, `Rindle.cancel_processing/1`, rate-limited PubSub progress, frozen error vocabulary
- [ ] **Phase 28: Onboarding, Docs, CI Proof** — Stock 720p web preset profile fixture, per-platform install paths (macOS / Ubuntu / Fly.io / Heroku / Render / GitHub Actions), real-world smartphone-source video round-trip in CI, parity gates, anti-pattern grep gate

## Phase Details

### Phase 23: AV Foundations
**Goal**: Adopters with video / audio profiles get a fail-fast, capability-honest, security-disciplined FFmpeg foundation that every later phase rides on
**Depends on**: Phase 22 (v1.3 complete)
**Requirements**: AV-01-01, AV-01-02, AV-01-03, AV-01-04, AV-01-05, AV-01-06, AV-01-07, AV-01-08, AV-01-09, AV-01-10
**Success Criteria** (what must be TRUE):
  1. Adopter declaring a `:video` or `:audio` variant on a profile sees the supervisor refuse to start with a `Rindle.Error{reason: {:ffmpeg_not_found, ...}}` if FFmpeg is missing or older than 6.0, with the message naming the exact platform install command needed
  2. Adopter can run `mix rindle.doctor MyApp.Profile` and get per-variant PASS / FAIL output with `mix phx.gen`-style fix guidance, and the task exits non-zero on any FAIL so CI catches it
  3. Operator can call `Rindle.Capability.report/0` from an admin page or CI log and read the detected FFmpeg version, supported codec list, and supported container list
  4. CI grep gate fails the build if any future commit reintroduces `System.shell/2`, `:os.cmd/1`, raw `Port.open/2` for FFmpeg/FFprobe, or string-interpolated argv anywhere under `lib/rindle/`
  5. Image-only adopters on minimal Docker images upgrade to v1.4 without FFmpeg installed and see no boot-time regression (capability probe stays silent unless an AV profile is declared)
**Plans**: 4 plans (estimated)
**UI hint**: no

### Phase 24: Domain Model & DSL Extension
**Goal**: Adopters can declare `:image | :video | :audio | :waveform` variants on the existing profile DSL with operator-queryable typed columns, while every existing image-only profile compiles and runs byte-for-byte unchanged
**Depends on**: Phase 23
**Requirements**: AV-02-01, AV-02-02, AV-02-03, AV-02-04, AV-02-05, AV-02-06, AV-02-07, AV-02-08, AV-02-09, AV-02-10, AV-02-11
**Success Criteria** (what must be TRUE):
  1. Adopter runs one additive Ecto migration and gets a `kind` enum on `media_assets`, an `output_kind` enum on `media_variants`, and typed probe columns (`width`, `height`, `duration_ms`, `has_video_track`, `has_audio_track`) without invalidating any existing image rows
  2. Adopter can write a profile with mixed `:kind` variants (image + video + audio + waveform) and the compiler validates each variant's options against the per-kind NimbleOptions schema with a specific error message and fix hint on misuse
  3. Adopter using a v1.0 image-only profile (no `:kind` declared) compiles, validates, and runs the full lifecycle end-to-end on v1.4 with zero source changes (CI-enforced parity)
  4. Operator querying `media_assets WHERE kind = :video AND has_audio_track = true` returns the right rows without parsing JSONB
  5. Adopter uploading a video file sees the asset transition through `analyzing → available → transcoding → ready` (or `→ degraded` / `→ quarantined`) with FSM logging, and any container metadata (title, artist, comment) is stored truncated to 1024 bytes with control characters stripped
**Plans**: 5 plans (estimated)
**UI hint**: no

### Phase 25: Rindle.Processor.AV
**Goal**: Adopters get production-quality video and audio derivatives — H.264+AAC mp4, scene-detected poster, AAC/MP3 audio, EBU R128 loudnorm, JSON waveform peaks — generated by an idempotent Oban worker with output verification, race-safe atomic promote, hard resource caps, and orphan-tempfile sweeping
**Depends on**: Phase 24
**Requirements**: AV-03-01, AV-03-02, AV-03-03, AV-03-04, AV-03-05, AV-03-06, AV-03-07, AV-03-08, AV-03-09, AV-03-10, AV-03-11, AV-03-12, AV-03-13, AV-03-14, AV-03-15, AV-03-16, AV-03-17, AV-03-18
**Success Criteria** (what must be TRUE):
  1. Adopter uploading a smartphone-source mp4 / mov / webm video and declaring a 720p H.264 + AAC variant gets back a playable mp4 with `+faststart` and a scene-detected poster jpeg / webp, with named-preset codec / bitrate / dimension allowlists enforced (no raw `filter_complex` reachable)
  2. Adopter uploading mp3 / m4a / wav / flac / ogg audio and declaring an AAC m4a or MP3 variant plus a JSON waveform variant gets back the transcoded audio, EBU R128-normalized when requested, and a `{length, sample_rate, peaks: [...]}` waveform JSON
  3. Operator can re-enqueue the same `(asset_id, variant_name)` job repeatedly and the worker is fully idempotent: same `recipe_digest`-derived `storage_key`, partial-output overwrite is safe, and the `unique` Oban constraint prevents stampedes
  4. Adopter re-uploading the source asset while a transcode is in flight sees the worker abort the atomic promote (`storage_key` / `recipe_digest` mismatch) instead of attaching a stale derivative — and the FFmpeg silent-truncation failure mode is caught by the post-condition probe (output `duration_ms` within 1% of source) flipping the variant to `failed`
  5. Operator inspecting the host running `:rindle_media` sees: a single sweepable `Rindle.tmp/` root, an `Rindle.Ops.SweepOrphanedTempFiles` Oban worker reaping orphans older than 4h, a refusal to enqueue when free disk is < 2× `max_output_bytes`, a refusal to run video transcodes on Lambda-class ephemeral runtimes, rate-limited (≤ 2/sec) per-variant progress on `rindle:variant:#{id}`, and the documented `[:rindle, :media, :transcode, :start | :stop | :exception]` telemetry triplet
**Plans**: 6 plans (estimated)
**UI hint**: no

### Phase 26: Delivery Surface
**Goal**: Adopters keep production signed-redirect delivery (zero BEAM time on streaming bytes) and gain range-aware dev parity for `Rindle.Storage.Local`, while `Rindle.Delivery.streaming_url/3` reserves the surface so future Mux / Cloudflare Stream provider adapters land without template churn
**Depends on**: Phase 24 (does not require Phase 25)
**Requirements**: AV-04-01, AV-04-02, AV-04-03, AV-04-04, AV-04-05, AV-04-06, AV-04-07, AV-04-08
**Success Criteria** (what must be TRUE):
  1. Adopter calling `Rindle.Delivery.streaming_url(profile, key, opts)` from a `<video>` / `<audio>` template gets `{:ok, %{url, kind: :progressive, mime}}` today, and the same call site returns an HLS / DASH manifest URL untouched when a future `Rindle.Streaming.Provider` adapter (Mux / Cloudflare Stream) lands post-v1.4
  2. Dev adopter on `Rindle.Storage.Local` mounts `Rindle.Delivery.LocalPlug` and a browser playing the resulting `<video>` element issues a single `Range:` request that resolves via OS `sendfile(2)` (`Plug.Conn.send_file/5`); multi-range and unparseable Range fall back to a 200 + full-body response per RFC 7233
  3. Adopter mounting `Rindle.Delivery.LocalPlug` against a non-`Rindle.Storage.Local` adapter sees a fail-fast boot error, not a runtime error on first request — and the plug's `@moduledoc` clearly marks it dev-parity-only with documented production caveats
  4. Adopter requesting an asset with messy container metadata (title / artist / comment with control chars or non-ASCII) gets a `Content-Disposition: attachment; filename*=UTF-8''<sanitized>` header (RFC 5987) and never the raw container metadata
  5. Adopter consulting the docs sees signed-URL TTL guidance per content type (image 15 min, audio 1 h, video VOD 2 h, long-form video → token refresh hook), and operators see `[:rindle, :delivery, :streaming, :resolved]` and `[:rindle, :delivery, :range_request]` telemetry events with documented measurement / metadata schemas
**Plans**: 3 plans (estimated)
**UI hint**: no

### Phase 27: HTML Helpers + LiveView Integration
**Goal**: Phoenix adopters get `<video>` / `<audio>` template helpers that mirror the existing `picture_tag/3` shape with codec-aware sources and DSL-resolved poster, plus rate-limited LiveView progress UX and an explicit cancellation API — all wrapped in a frozen 8-variant error vocabulary that self-explains the fix
**Depends on**: Phase 24 (also benefits from Phase 25 for end-to-end demo, but does not require it for shipping the helper API)
**Requirements**: AV-05-01, AV-05-02, AV-05-03, AV-05-04, AV-05-05, AV-05-06, AV-05-07
**Success Criteria** (what must be TRUE):
  1. Adopter writing `<%= Rindle.HTML.video_tag(@profile, @asset, variants: [:web_720p, :web_480p], poster: :poster) %>` in a Phoenix template gets a valid `<video>` with codec-aware `<source>` ordering, DSL-resolved poster URL, `preload="metadata"` default, the reserved `:tracks` keyword for v1.5 captions, stale / non-ready variants skipped from the source list, and pass-through HTML attributes preserved
  2. Adopter writing `<%= Rindle.HTML.audio_tag(@profile, @asset, variants: [:m4a, :mp3]) %>` gets a `<controls>`-defaulted, `preload="metadata"` `<audio>` element with the same skip-stale-variants behaviour as `video_tag/3`
  3. LiveView adopter calling `Rindle.LiveView.subscribe(:variant, variant_id)` (or `:asset` / `:upload_session`) receives `{:rindle_event, :variant_started | :variant_progress | :variant_ready | :variant_failed | :variant_cancelled, payload}` messages in `handle_info/2` with rate-limited (≤ 2/sec) progress events and matching `unsubscribe/1` symmetry
  4. Adopter calling `Rindle.cancel_processing(asset_id)` while transcodes are in flight sees queued and executing Oban jobs cancelled, affected variants flipped to `cancelled`, `:variant_cancelled` events broadcast, and a `:ok | {:error, :not_processing}` return — never a silent no-op
  5. Adopter encountering any of the 8 frozen v1.4 error reasons (`:processor_capability_missing`, `:ffmpeg_not_found`, `:capability_drift`, `:variant_source_not_found`, `:unsupported_codec`, `:streaming_not_configured`, `:variant_processing_cancelled`, `:range_unparseable`) gets an `Rindle.Error.message/1` string that names the exact fix in `mix phx.gen` style — and the message text is locked by an ExUnit parity gate
**Plans**: 4 plans (estimated)
**UI hint**: yes

### Phase 28: Onboarding, Docs, CI Proof
**Goal**: A fresh Phoenix adopter can install Rindle on their target platform, declare one `:kind => :video` variant, run `mix rindle.doctor`, and successfully round-trip a real-world smartphone video through the full lifecycle — with CI proving the path on every commit
**Depends on**: Phases 23, 24, 25, 26, 27 (last phase; v1.4 ship gate)
**Requirements**: AV-06-01, AV-06-02, AV-06-03, AV-06-04, AV-06-05, AV-06-06, AV-06-07, AV-06-08
**Success Criteria** (what must be TRUE):
  1. New adopter on macOS, Ubuntu / Debian, Alpine, Fly.io, Heroku, Render, or GitHub Actions can copy-paste the per-platform FFmpeg install snippet from `RUNNING.md` (or equivalent docs page) and reach a working FFmpeg ≥ 6.0 install in one command per platform
  2. Onboarding guide teaches the smallest install path for video: `mix deps.get`, system FFmpeg install, declare one `:kind => :video` variant, run `mix rindle.doctor` — and a fresh `mix phx.new` consumer can follow it copy-pasteably to a green `mix rindle.doctor`
  3. CI runs `mix rindle.doctor` against every example / fixture profile and exits non-zero on any FAIL, blocking the build
  4. CI exercises a real-world smartphone-source video fixture (varying codec, container, rotation) through the full lifecycle — upload → probe → transcode → variant ready → poster → signed URL — using the stock `Rindle.Profile.Presets.Web` preset, and the build fails if any step breaks
  5. CI parity gate verifies the 8 locked error messages match documented text byte-for-byte, telemetry event names match the documented `:start / :stop / :exception` triplet conventions, and the anti-pattern grep gate refuses any new `System.shell/2`, `:os.cmd/1`, raw `Port.open/2` for FFmpeg/FFprobe, or string-interpolated argv pattern under `lib/rindle/`
**Plans**: 4 plans (estimated)
**UI hint**: no

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 23. AV Foundations | v1.4 | 0/4 | Not started | - |
| 24. Domain Model & DSL Extension | v1.4 | 0/5 | Not started | - |
| 25. Rindle.Processor.AV | v1.4 | 0/6 | Not started | - |
| 26. Delivery Surface | v1.4 | 0/3 | Not started | - |
| 27. HTML Helpers + LiveView Integration | v1.4 | 0/4 | Not started | - |
| 28. Onboarding, Docs, CI Proof | v1.4 | 0/4 | Not started | - |
