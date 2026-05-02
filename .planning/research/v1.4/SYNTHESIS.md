# Rindle v1.4 — Synthesis & Locked Recommendation

**Date:** 2026-05-02
**Sources:** ADAPTER.md, LIFECYCLE.md, DELIVERY-DX.md, FOOTGUNS.md (parallel research)
**Confidence:** HIGH (cross-research convergence on every major axis)
**Decision posture:** Locked unless flagged otherwise. User overrides any lock by saying so.

---

## 1. The One-Paragraph v1.4

**v1.4 = "Video and Audio Wedge."** Rindle extends from image-first to image+video+audio by shipping a system-FFmpeg-backed processor (`Rindle.Processor.AV`), a `Rindle.Probe.AVProbe` analyzer, and `Rindle.HTML.video_tag/3` + `audio_tag/3` helpers — all riding the existing v1.0 architectural seams (`Rindle.Processor` behaviour, `MediaAsset`/`MediaVariant` rows, Oban workers, signed-URL delivery). The domain model gains a `:kind` discriminator (`:image | :video | :audio`) on assets and an `:output_kind` on variants (`:image | :video | :audio | :waveform`), with operator-queryable typed columns for duration/dimensions/track presence and JSONB for codec/bitrate/tags. The processor pattern stays the same: one variant = one Oban job = one out-of-process FFmpeg invocation = one durable row, with hard resource caps, argv-array safety, `-protocol_whitelist`-required ingest, MuonTrap-supervised subprocesses, and orphan-tempfile sweeping. Production delivery stays signed-redirect (S3/R2/GCS already serve `Range` natively); a thin opt-in `Rindle.Delivery.LocalPlug` gives dev parity for the `Rindle.Storage.Local` adapter. A `Rindle.Delivery.streaming_url/3` ships as a no-op delegate so adopter video templates won't churn when post-v1.4 Mux/Cloudflare-Stream provider adapters land. HLS/DASH/DRM/ABR ladders/live streaming are explicitly out of scope.

---

## 2. Locked Decisions (Default — agent-decided, not asked)

### 2.1 Tooling & process model
| Decision | Lock |
|---|---|
| **Transcoder** | System-installed FFmpeg + FFprobe (≥ 6.0). |
| **Elixir wrapper** | [`ffmpex`](https://hex.pm/packages/ffmpex) (argv-array safe; argv built as a list, never a shell string). |
| **Subprocess runner** | [`muontrap`](https://hexdocs.pm/muontrap/) on Linux production (cgroup-attached, kill-on-parent-death, optional CPU/RSS caps). [`rambo`](https://github.com/jayjun/rambo) (FFmpex's bundled exec) as fallback for macOS dev / Windows CI. |
| **Process isolation** | Out-of-process subprocess. **No** in-BEAM NIFs (`xav`, `evision`, `membrane_h264_ffmpeg_plugin`) — FFmpeg CVEs become BEAM crashes via NIF, but tagged `{:error, exit_code}` via subprocess. |
| **Membrane** | Rejected for v1.4. Right tool for streaming pipelines (RTSP/RTMP/WebRTC), wrong shape for one-shot file derivatives. Document as the right escape hatch for streaming-curious adopters. |
| **Provider-delegated (Mux, CF Stream, Transloadit)** | Rejected for v1.4 core ship. Document as a custom-`Rindle.Processor` recipe adopters implement themselves; ship a doc-only example. |
| **Job runner** | Existing Oban (matches v1.0–v1.3 invariant). New dedicated queue `:rindle_media` (default concurrency 2). Image queue stays separate so video transcodes can't starve fast image work. |
| **Worker timeout** | Per-worker `timeout/1` callback. Default: image 60s, audio 5 min, video 30 min. Profile-overridable. |
| **`shutdown_grace_period`** | Documented recommendation (5 min for adopters running `:rindle_media`). Not enforced by Rindle. |

### 2.2 Domain model
| Decision | Lock |
|---|---|
| **Schema split** | Single `media_assets` table + `kind` enum (`:image \| :video \| :audio`). Single `media_variants` table + `output_kind` enum (`:image \| :video \| :audio \| :waveform`). |
| **First-class probe columns on `media_assets`** | `width`, `height` (px), `duration_ms` (integer; not float seconds), `has_video_track`, `has_audio_track` (booleans). All nullable; populated by probe. |
| **JSONB `metadata`** | Codec, bitrate, container, frame_rate, sample_rate, channels, tags, rotation, probe_version, probed_at. Diagnostic; not filterable in normal queries. |
| **Cross-kind variants** | Plain rows. Video → poster image, video → audio extraction, audio → waveform image are all `media_variants` rows with `output_kind` set appropriately. **No** `from_variant` chaining (variants depend only on source asset). |
| **Backward compat** | New columns nullable or default-`:image`. Existing image-only profiles compile unchanged via DSL fallback (omitted `:kind` defaults to `:image`). One additive migration. |
| **`Rindle.Probe` behaviour** | New, symmetric with `Rindle.Processor`. Bundled adapters: `Rindle.Probe.Image` (existing libvips path) and `Rindle.Probe.AVProbe` (FFprobe via FFmpex; optional dep). |
| **Asset FSM** | Add `transcoding` state. Distinct from existing `processing` (different timeouts, retry semantics, telemetry visibility). |
| **Variant FSM** | Unchanged 8-state shape. Add `cancelled` state for `Rindle.cancel_processing/1` (see §2.5). |

### 2.3 Profile DSL
| Decision | Lock |
|---|---|
| **DSL shape** | Same flat `variants: %{...}` map adopters use today. `:kind` discriminator required for new entries; absent → defaults to `:image` (backward compat). |
| **Per-kind validation** | `NimbleOptions` schemas dispatched by `:kind` (image/video/audio/waveform). Compile-time errors with specific messages. |
| **Named presets only** | No raw `filter_complex`, no raw `-vf`, no user-controllable codec strings. Codec/container/format are atom enums validated against an allowlist. **PROJECT.md "named presets only by default" extends to v1.4 verbatim.** |
| **Stock preset** | Ship one named "web" video preset (720p H.264 + AAC + scene-detected poster) so adopters have a real demo, not just primitives. |

### 2.4 Format scope (in vs out)
| In v1.4 | Out of v1.4 |
|---|---|
| Inputs: mp4, mov, webm (read fallback for mkv) | HLS playlists (.m3u8), DASH (.mpd), playlist-style ingest |
| Inputs: mp3, m4a (AAC), wav, flac, ogg | DRM (Widevine, FairPlay, PlayReady) |
| Output: video transcode (H.264 + AAC, mp4 default) | Adaptive bitrate (ABR) ladders |
| Output: scene-detected poster frame (jpg/webp) | Live streaming (RTMP ingest, WebRTC) |
| Output: audio transcode (AAC m4a or MP3) | Subtitle / caption burn-in |
| Output: EBU R128 single-pass loudnorm (two-pass via opt-in flag) | Watermarking |
| Output: JSON waveform peaks (configurable count) | Hardware-accelerated transcode (NVENC/QSV) |
| Probe: ffprobe-derived metadata (full shape) | Animated GIF/WebP from video |
| Capabilities: `:video_transcode`, `:video_frame_extract`, `:video_thumbnail_strip`, `:audio_transcode`, `:audio_normalize`, `:audio_waveform` | Non-mainstream containers (FLV, AVI, WMV) |
| MKV ingest (rejected — attachment exfil vector) | Frame-accurate trimming / NLE |
| Raw AAC ingest (rejected — require m4a container) | Spectrogram, fingerprinting |
| | Dynamic per-request video transformation |

### 2.5 Public API additions
| API | Lock |
|---|---|
| **`Rindle.HTML.video_tag(profile, asset, opts)`** | Same shape as existing `picture_tag/3`. Codec-aware `<source>` ordering; poster as variant atom resolved through DSL; `preload="metadata"` default; `:tracks` keyword reserved for v1.5 captions. |
| **`Rindle.HTML.audio_tag(profile, asset, opts)`** | Mirror of `video_tag`, minus `:poster`. Defaults `controls: true`, `preload: :metadata`. |
| **`Rindle.Delivery.streaming_url(profile, key, opts)`** | Ships as no-op delegate to `url/3` with `kind: :progressive`. Adopter templates calling this will work unchanged when Mux/CF Stream adapters land post-v1.4. |
| **`Rindle.Delivery.LocalPlug`** | Opt-in, in core, mountable only when storage adapter is `Rindle.Storage.Local`. ~80 LoC. Single-range `Range:` header support via `Plug.Conn.send_file/5` (OS `sendfile(2)`). Multi-range and unparseable Range fall back to 200 + full body (RFC 7233 graceful degradation). Marked dev-parity in moduledoc; production at adopter's risk. |
| **`Rindle.LiveView.subscribe(:variant \| :asset \| :upload_session, id)`** | New helper. Returns subscription topic. Adopter handles `{:rindle_event, type, payload}` in `handle_info/2`. |
| **`Rindle.cancel_processing(asset_id)`** | New API. Cancels queued/executing Oban jobs for variants of the asset; flips variant state to `cancelled`; broadcasts cancellation event. |
| **`Rindle.probe(asset)`** | Additive. Returns `{:ok, %{...}}`. Replaces no existing function. |
| **`mix rindle.doctor [Profile]`** | New mix task. Validates profile against registered processors and storage adapter; reports per-variant capability status with concrete fix guidance. |

### 2.6 Capability negotiation (processor pattern)
| Decision | Lock |
|---|---|
| **Vocabulary placement** | New peer module `Rindle.Processor.Capabilities`, **not** `Rindle.Storage.Capabilities`. Mirrors existing `Storage` ↔ `Processor` split. Two clean vocabularies. |
| **`Rindle.Processor` callback additions** | `@callback capabilities() :: [capability()]` (optional, default `[]` for backward compat). `@callback supports?(variant_spec) :: boolean()` (optional, default-derived). |
| **Boot probe** | `Rindle.Processor.AV.probe_capabilities/0` runs `ffmpeg -version` and `ffmpeg -codecs` at app start. Caches in `:persistent_term`. Logs warning if missing; doesn't crash app. |
| **Profile compile-time validation** | `Rindle.Profile.validate_profile!/1` cross-checks declared variants against processor capabilities. Raises `Rindle.Profile.IncompatibleVariant` with `mix phx.gen`-style fix message. |
| **Telemetry on probe** | `[:rindle, :capability, :ffmpeg]` event with version, supported codec list, supported? boolean. |

### 2.7 Delivery posture
| Path | Lock |
|---|---|
| **Production (S3, R2, GCS, MinIO)** | Unchanged. Signed-redirect to upstream; browser does Range against S3 directly. **Zero BEAM time on streaming bytes.** |
| **Dev (`Rindle.Storage.Local`)** | New `Rindle.Delivery.LocalPlug` (§2.5). |
| **HLS/DASH** | Out of scope. `streaming_url/3` returns `kind: :progressive` in v1.4. Future provider adapter changes only the return shape, not the call site. |
| **Signed URL TTL guidance** | Documented per content type: image 15min, audio 1h, video 2h, long-form video → adopter implements token refresh hook. |

### 2.8 Security invariants (added to PROJECT.md §"Security invariants")

> **8.** FFmpeg/FFprobe subprocess invocation uses argv list only — never shell. All user-controllable parameters (codec, container, dimensions, duration, bitrate) are validated against named-preset allowlists before reaching argv.
>
> **9.** Every FFmpeg/FFprobe invocation passes `-protocol_whitelist file,crypto,data` and runs under hard caps for duration (`-t`), output size (`-fs`), CPU time (`-timelimit`), wall-clock time (external), and threads (`-threads`). Wall-clock kill is enforced externally; FFmpeg's `-timelimit` alone is insufficient.
>
> **10.** Container metadata (title, artist, comment, embedded subtitles, attachments) is treated as untrusted user-controlled content end-to-end. Rindle stores it opaquely (truncated, control-chars stripped); adopters MUST sanitize on render.
>
> **11.** HLS / DASH / playlist-style ingest is out of scope. Inputs accepted by ingest are single-container files only.
>
> **12.** Rindle declares an FFmpeg minimum version, capability-probes at supervisor boot, and refuses to start with stale or missing FFmpeg when video/audio profiles are configured. Adopters never silently inherit FFmpeg CVE exposure.
>
> **13.** Temp files for transcoding live under a single sweepable root (`Rindle.tmp/`); orphans are reaped by a scheduled `Rindle.Ops` worker. No transcode is allowed without an enforceable parent-death subprocess kill (MuonTrap on Linux; Rambo on macOS/Windows dev).

### 2.9 Operational defaults
| Knob | Default | Rationale |
|---|---|---|
| `:rindle_media` Oban queue concurrency | 2 | Conservative; image queue separate so video doesn't starve images. |
| `max_duration_seconds` (per profile) | 7200 (2h) | Covers podcasts, lectures, conference talks; rejects pathological inputs. |
| `max_output_bytes` | 500 MB | One 720p hour ≈ 500MB; adopter overrides per profile. |
| `max_wall_seconds` | 600 (10 min) | Covers most ≤2h transcodes at 720p; aggressive presets need explicit override. |
| `max_cpu_seconds` | 300 | FFmpeg `-timelimit`. |
| `ffmpeg_threads` | 2 | Predictable per-job CPU; concurrency scales separately. |
| FFmpeg minimum version | 6.0 | In Ubuntu 24.04 / Debian 12 / Alpine 3.19. Older = unpatched CVEs. |
| Tmp root | `Rindle.tmp/` under `System.tmp_dir!()` | Single sweepable prefix; configurable. |
| Tmp orphan sweeper threshold | 4h | Longer than any reasonable transcode + retry. |
| Disk-space precheck | Refuse enqueue if free < 2× `max_output_bytes` | Prevents most ENOSPC. |
| PubSub progress broadcast rate | ≤ 2/sec per variant | Avoids LiveView storm; documented. |
| Ephemeral runtime detection | Refuse video transcodes on Lambda/Vercel-like envs | 15-min cap, tiny `/tmp`; image variants OK. |

### 2.10 Telemetry events (v1.4 additions)
```
[:rindle, :variant, :process, :start | :stop | :exception]
[:rindle, :variant, :progress]                          (rate-limited; same metadata as PubSub)
[:rindle, :delivery, :streaming, :resolved]             (kind: :progressive | :hls | :dash)
[:rindle, :delivery, :range_request]                    (from LocalPlug)
[:rindle, :profile, :validate, :start | :stop | :exception]
[:rindle, :capability, :ffmpeg]                         (boot probe)
[:rindle, :media, :transcode, :start | :stop | :exception]
[:rindle, :media, :ffmpeg, :version_check]
[:rindle, :media, :probe, :stop]
[:rindle, :media, :sweep_orphans, :stop]
[:rindle, :media, :tmp_dir, :pressure]
[:rindle, :asset, :state_change]                        (existing; new metadata for transcoding transitions)
```

### 2.11 PubSub topic conventions
```
"rindle:variant:#{variant_id}"        — per-variant progress
"rindle:asset:#{asset_id}"            — asset-level rollup
"rindle:upload_session:#{session_id}" — existing
```
Event shape: `{:rindle_event, :variant_started | :variant_progress | :variant_ready | :variant_failed | :variant_cancelled, payload}`.

### 2.12 Error vocabulary (extends `Rindle.Error.message/1`)
8 locked variants documented in DELIVERY-DX.md §8.2:
1. `:processor_capability_missing` (boot/static-analysis)
2. `:ffmpeg_not_found` (boot/static-analysis)
3. `:capability_drift` (boot/static-analysis)
4. `:variant_source_not_found` (runtime, deterministic)
5. `:unsupported_codec` (runtime, deterministic)
6. `:streaming_not_configured` (runtime, deterministic)
7. `:variant_processing_cancelled` (graceful operational)
8. `:range_unparseable` (graceful operational, logged not raised)

All messages self-explain the fix in `mix phx.gen` style.

---

## 3. Anti-Patterns (Top 10 — "Rindle MUST NOT")

1. NEVER invoke FFmpeg via `System.shell/2`, `:os.cmd/1`, or any path interpolating strings into a shell command line.
2. NEVER accept user-controlled values in any FFmpeg flag position. Validated allowlists only.
3. NEVER invoke FFmpeg/FFprobe without `-protocol_whitelist file,crypto,data` on user-supplied inputs.
4. NEVER invoke FFmpeg without all four caps: `-t`, `-fs`, `-timelimit`, AND external wall-clock kill.
5. NEVER support HLS / DASH / m3u8 / mpd ingest in v1.4.
6. NEVER expose raw `filter_complex` or arbitrary FFmpeg filter graphs in adopter API.
7. NEVER treat container metadata as trusted (sanitize on render, never on FFmpeg call boundary).
8. NEVER block the BEAM scheduler with synchronous FFmpeg calls. Oban worker only. NIFs that wrap libavcodec are forbidden.
9. NEVER auto-cleanup temp files only "after storage write succeeds" without a sweeper. Sweeper is mandatory.
10. NEVER ship v1.4 without documented FFmpeg minimum version, startup capability probe, and per-platform install paths.

---

## 4. Phase Shape (for roadmapper, not user-decision)

Suggested phase ordering (5–6 phases, continues from Phase 22):

| # | Phase name | Goal | Key files | UI? |
|---|---|---|---|---|
| 23 | **AV Foundations** | Capability vocabulary, processor-capabilities behaviour, MuonTrap subprocess discipline, FFmpeg boot probe, `mix rindle.doctor`, security argv discipline, `-protocol_whitelist` defaults, resource caps. Foundation every later phase depends on. | `lib/rindle/processor/capabilities.ex`, `lib/rindle/processor/ffmpeg.ex`, `lib/rindle/processor/ffprobe.ex`, `lib/rindle/profile.ex` (validate), `mix.exs` (deps + version), tasks | no |
| 24 | **Domain Model & DSL Extension** | Migration adding `kind`/`output_kind`/probe columns; per-kind NimbleOptions schemas in profile validator; `transcoding` asset state; `cancelled` variant state; `Rindle.Probe` behaviour + `Rindle.Probe.AVProbe`; backward compat tests for existing image-only profiles. | `priv/repo/migrations/v1_4*`, `lib/rindle/domain/media_asset.ex`, `lib/rindle/domain/media_variant.ex`, `lib/rindle/probe.ex`, `lib/rindle/probe/av_probe.ex`, `lib/rindle/profile/validator.ex`, FSMs | no |
| 25 | **`Rindle.Processor.AV`** | The transcoder. Video transcode (H.264 + AAC), scene-detected poster, audio transcode, EBU R128 loudnorm, JSON waveform peaks. Idempotent worker; output post-condition probe; orphan tempfile sweeper; concurrent-transcode race guard. | `lib/rindle/processor/av.ex`, `lib/rindle/processor/waveform.ex`, `lib/rindle/workers/process_variant.ex`, `lib/rindle/ops/sweep_orphan_tempfiles.ex` | no |
| 26 | **Delivery Surface** | `Rindle.Delivery.streaming_url/3` (no-op delegate); `Rindle.Delivery.LocalPlug` (range-aware, dev parity); content-disposition with RFC 5987; signed URL TTL guidance docs. | `lib/rindle/delivery.ex`, `lib/rindle/delivery/local_plug.ex` | no (Plug, not page) |
| 27 | **HTML Helpers + LiveView Integration** | `Rindle.HTML.video_tag/3`, `audio_tag/3`; `Rindle.LiveView.subscribe/2`, `Rindle.cancel_processing/1`; PubSub progress events from worker; rate-limited broadcast. | `lib/rindle/html.ex`, `lib/rindle/live_view.ex` | yes |
| 28 | **Onboarding, Docs, CI Proof** | Stock 720p web preset profile fixture; `RUNNING.md` per-platform install paths (macOS, Ubuntu, Fly.io, Heroku, Render, GitHub Actions); CI verifies FFmpeg detection + a real-world smartphone-source video round-trip; `mix rindle.doctor` exit-status integrated; capability-mismatch error vocabulary frozen with parity test. | docs, `test/`, `.github/workflows/`, mix tasks | no |

Phase 23 must land before any other; Phase 24 before 25/26/27; 28 last. 25/26/27 have minimal ordering coupling between them.

---

## 5. What's Out of Scope (Explicit Exclusions)

| Capability | Why deferred |
|---|---|
| HLS playlists, DASH manifests | Streaming format, not one-shot derivative; needs segment lifecycle. v1.5+ or provider-delegated. |
| Adaptive bitrate (ABR) ladder | Multi-rendition + segmenter coordination + manifest authoring. v1.5+. |
| DRM (Widevine, FairPlay, PlayReady) | Cert provisioning, key servers — full platform territory. Provider-delegated only, never core. |
| Live streaming (RTMP/WebRTC ingest) | Different domain. Membrane territory; never Rindle core. |
| Subtitle / caption burn-in, watermarking | Adopter-specific; custom processor recipe. |
| Hardware acceleration (NVENC/QSV) | Adopter ops; document config flag, no default. |
| Animated GIF/WebP from video | v1.5+ if asked. |
| Spectrogram, fingerprinting (Chromaprint) | Specialty; custom processor. |
| Bundled provider adapters (Mux/CF Stream/Transloadit) | Ship doc-only example as custom-`Rindle.Processor`. Don't ship packaged adapter in core v1.4. |
| Picture-element responsive posters | Native `<video poster>` is single URL. Niche need; adopter hand-rolls. |
| Frame-accurate trimming / NLE | Custom processor. |
| Captions/subtitles `<track>` elements | Reserved as `:tracks` keyword in helper sig; implementation v1.5. |
| MKV ingest (general) | Attachment exfiltration vector. Reject in v1.4. |
| Raw AAC ingest | Reject; require m4a container. |
| Bundled precompiled FFmpeg | License complexity (x264 GPL); large package matrix. Document install path instead. |
| Membrane integration | Right tool for streaming, wrong tool for one-shot transcodes. |
| Broadway alongside Oban | Two job systems is worst of both. |

---

## 6. What I Locked Without Asking — Reasoning Audit

For maximum auditability of the one-shot decisions:

| Lock | Convergent rationale across research |
|---|---|
| FFmpeg over Membrane | Every peer lib (Active Storage, Shrine, Spatie, CarrierWave, Django, Mux internally) shells out to FFmpeg for one-shot. Membrane is the streaming-pipeline answer. |
| FFmpex + MuonTrap | argv-array safety (eliminates Jellyfin GHSA-866x-wj5j-2vf4 class). MuonTrap solves the BEAM-orphan-process problem cgroup-style. |
| Out-of-process subprocess (no NIFs) | FFmpeg CVE blast radius: NIF crash → BEAM death; subprocess crash → Oban retry. |
| Single `media_assets` + `:kind` enum | Active Storage validates this at scale (7+ years). Elixir pattern matching shines on atom enums. JSONB-only loses operator queryability. |
| `Rindle.Processor.AV` (single module, not Video/Audio split) | One ffmpeg binary, one CLI vocabulary, cross-kind workflows (video → audio extraction, audio → waveform image) need both code paths in one place. Active Storage *analyzers* split but *Blob* unifies. |
| `:waveform` as distinct `output_kind` | Operator queries differ ("regenerate all waveforms"); recipe shape differs; cost is one enum value. |
| New `Rindle.Processor.Capabilities` module (not extend Storage caps) | Mirrors existing `Storage` ↔ `Processor` symmetry. Two clean vocabularies. |
| FFmpeg required only when video/audio profile present | Image-only adopters on minimal Docker images don't break on upgrade. Capability honesty stays the contract. |
| `streaming_url/3` ships as no-op now | Adopter video templates won't churn when Mux/CF Stream lands. The surface segregation Active Storage missed. |
| `LocalPlug` in core opt-in | Friction of separate `rindle_dev_plug` package surprises new adopters. Clearly marked dev-parity in moduledoc. |
| Conservative resource defaults | Tightening later is breaking; loosening is non-breaking. Adopters who need more raise per profile. |
| Stay Oban-only (no Broadway) | Two job systems is worst of both. Oban's queue concurrency suffices for upload-driven workloads. |
| HLS/DASH ingest rejected | SSRF + RCE surface (CVE-2016-1897, CVE-2020-13904, etc.). Manifests are an attack surface; postpone behind a sanitizer milestone. |
| MKV ingest rejected | Attachment-exfiltration vector. WebM (Matroska subset) only on a strict subset. |
| Raw `filter_complex` rejected | Argument-injection class (S-1). Named presets compose pre-validated primitives only. |
| FFmpeg-only adapter, not pluggable behaviour for v1.4 | v1.2/v1.3 retro: tight scope shipped cleanly; broad scope generated cleanup phases. Defer pluggability to v1.5 if adopter feedback requests it. |
| Stock "web" preset shipped | Adopter has a real demo, not just primitives. Spatie's "build it yourself" punt is a documented anti-pattern. |
| `mix rindle.doctor` shipped | Active Storage's missing-FFmpeg-at-first-upload footgun is the canonical cautionary tale. Fail-fast at boot/CI/local. |

---

## 7. The (Optional) Open Escalation

Per memory rule (`feedback_research_driven_one_shot.md`), I escalate only items that pass the "VERY impactful" filter. Locking the AV-vs-split module decision because:
- It's a name. Renaming in v2.0 is a one-line `defdelegate` away.
- All four research agents leaned single (`Rindle.Processor.AV`).
- Cross-kind workflows (video → audio extraction) are real and concentrated in one module.

Locking the resource-cap defaults because:
- Tightening later is breaking; ship conservative; loosening is non-breaking.
- The numbers are profile-overridable; adopters with longer content raise per profile.

**No open escalations.** All decisions locked. User can object to any individual item.

---

## 8. References

See ADAPTER.md, LIFECYCLE.md, DELIVERY-DX.md, FOOTGUNS.md for full peer-library citations and CVE references. Top 10 most load-bearing:

1. [FFmpex](https://hex.pm/packages/ffmpex) + [MuonTrap](https://github.com/fhunleth/muontrap)
2. [Active Storage VideoAnalyzer](https://api.rubyonrails.org/classes/ActiveStorage/Analyzer/VideoAnalyzer.html) + [scene-detection PR #39096](https://github.com/rails/rails/pull/39096)
3. [Shrine derivatives](https://shrinerb.com/docs/plugins/derivatives) + [atomic_helpers](https://shrinerb.com/docs/plugins/atomic_helpers)
4. [Spatie Video.php](https://github.com/spatie/laravel-medialibrary/blob/main/src/Conversions/ImageGenerators/Video.php)
5. [Jellyfin GHSA-866x-wj5j-2vf4](https://github.com/jellyfin/jellyfin/security/advisories/GHSA-866x-wj5j-2vf4) (argv injection)
6. [Black Hat 2016 — Viral Video SSRF](https://blackhat.com/docs/us-16/materials/us-16-Ermishkin-Viral-Video-Exploiting-Ssrf-In-Video-Converters.pdf)
7. [Plug PR #526](https://github.com/elixir-plug/plug/pull/526) (range-request posture)
8. [Cloudinary cl_video_tag source](https://github.com/cloudinary/cloudinary_gem/blob/master/lib/cloudinary/video_helper.rb)
9. [Oban splitting queues](https://hexdocs.pm/oban/splitting-queues.html)
10. [BBC audiowaveform](https://github.com/bbc/audiowaveform)
