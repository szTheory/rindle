# Rindle v1.4 — Adapter & Processing Posture for Video / Audio

**Status:** Decision document. Opinionated. Locked recommendations.
**Researcher confidence:** HIGH on tooling axis, HIGH on process model axis, MEDIUM on format scope axis (final preset list is a knob, not a contract).
**Last updated:** 2026-05-02

---

## 1. TL;DR — Locked Recommendation

**Rindle v1.4 ships an FFmpeg-binary processor adapter (`Rindle.Processor.Video` and `Rindle.Processor.Audio`) that shells out to a system-installed FFmpeg/FFprobe via [FFmpex](https://hex.pm/packages/ffmpex) (which uses Rambo for safe argv-array execution) and runs the transcode inside the existing `Rindle.Workers.ProcessVariant` Oban worker, wrapped by `MuonTrap.cmd/3` for OS-process containment so a crashing/orphaned FFmpeg can never outlive the BEAM job. We do not ship a Membrane pipeline in v1.4. We do not ship a delegated provider adapter in v1.4. Both remain documented escape hatches: `Rindle.Processor` is already a behaviour, so adopters can drop in a Membrane-, Mux-, or Cloudflare-Stream-backed processor without us shipping one. v1.4 covers table-stakes operations only — poster-frame extraction, single-rendition web-friendly MP4 transcode, audio EBU-R128 normalization, audio waveform peaks (JSON), and ffprobe-driven analyzer metadata. HLS, DASH, DRM, ABR ladders, and live streaming are explicitly out of scope. Capability honesty stays the contract: the new processor advertises `:video_transcode | :video_poster | :audio_transcode | :audio_normalize | :audio_waveform` capabilities, and any unsupported format/codec/container fails as a tagged `{:error, {:processor_unsupported, ...}}` rather than a degraded surprise.

**One-sentence justification:** FFmpeg is what every peer library — Active Storage, Shrine, Spatie, CarrierWave, Django, Laravel, even Membrane internally — actually executes for table-stakes video/audio operations; FFmpex+Rambo+MuonTrap is the idiomatic Elixir stack to run it safely under Oban; Membrane is the right tool for *streaming pipelines*, not for "make me a 720p MP4 + a poster JPEG."

---

## 2. Tooling Axis — How Do We Touch Bytes?

### 2.1 Options Surveyed

| Option | What it is | Hex package | State |
|---|---|---|---|
| **FFmpeg binary via FFmpex** | Build argv with FFmpex's builder API, exec via Rambo (forks a tiny supervisor binary that reaps children) | [`ffmpex ~> 0.11.1`](https://hex.pm/packages/ffmpex) | Updated 2026-05-02 — actively maintained ([changelog](https://github.com/talklittle/ffmpex/blob/master/CHANGELOG.md)) |
| **FFmpeg binary via raw `System.cmd/3` / `Port`** | Hand-roll argv | stdlib | Works, but loses argv-injection safety story and zombie cleanup |
| **FFmpeg binary via [MuonTrap](https://github.com/fhunleth/muontrap)** | Same as above but with cgroup containment + guaranteed kill on BEAM-process exit | [`muontrap`](https://hexdocs.pm/muontrap/) | Maintained, Nerves-grade |
| **Membrane Framework** | Native Elixir multimedia *pipelines* (process-per-element, GenServer-based) | [`membrane_core ~> 1.2`](https://hexdocs.pm/membrane_core/) + per-codec/per-format plugins | Actively maintained, RTC.ON 2025 conference, real production in WebRTC/RTSP/RTMP servers |
| **Boombox** | Thin "Stream-style" facade on Membrane: `Boombox.run(input: "in.mp4", output: "out.mp4")` | [`membraneframework/boombox`](https://github.com/membraneframework/boombox) | Early but usable; the team itself describes it as polish-stage |
| **Xav** | NIF wrapper around FFmpeg's libav* C libraries (read/decode oriented) | [`xav ~> 0.11`](https://hex.pm/packages/xav) | Maintained June 2025; what `Image.Video` already uses for poster frames |
| **Vix + Image.Video** | Already in Rindle's deps (libvips). `Image.Video` extracts poster frames via either `xav` or `evision` | already in Rindle | Available now |
| **Provider-delegated (Mux, Cloudflare Stream, Transloadit)** | Library never touches bytes; uploads source to provider, polls/webhook for asset, returns playback ID | [`mux ~> 4.x`](https://github.com/muxinc/mux-elixir) (official); no official Cloudflare Stream / Transloadit Elixir SDK | Mux has solid Elixir client; CF Stream / Transloadit need hand-rolled HTTP |

### 2.2 Pros / Cons / Tradeoffs

| Criterion | FFmpeg + FFmpex | Membrane (or Boombox) | Provider-delegated | Xav (NIF) |
|---|---|---|---|---|
| Zero-knowledge install path | **System install (1 step)** | **System install + multiple Membrane plugins** (often need apt/brew packages anyway: x264, libavcodec) | **Cloud account, secrets** | NIF compile — but **xav is precompiled** for common targets |
| Time to first 720p MP4 | Hours | Days | Hours (account, signed URLs) | Days (decode loop is on you; not a transcoder) |
| Memory ceiling for 4K input | OS-process bounded (cgroups via MuonTrap) | **In-BEAM**; OOMs the whole VM if a frame buffer goes wild | N/A (offloaded) | **In-BEAM** |
| Resource isolation | Excellent (separate OS process; killable; cgroup-able) | Pipeline lives in supervised GenServers in *the same* BEAM as Phoenix | Excellent (cloud) | Poor (NIFs share scheduler & memory; long decodes block scheduler if not dirty-NIF) |
| Streaming protocols (RTSP, RTMP, WebRTC, HLS DVR) | Pain | **The reason Membrane exists** | Their job | None |
| Frame-by-frame programmatic logic | Awkward | Excellent | None | Excellent |
| One-shot transcode of an MP4 to a smaller MP4 | **Trivial** (1 ffmpeg call) | Pipeline boilerplate (see below) | Trivial (API call) | Many lines (you write the encoder loop) |
| Honest capability advertising | Easy: ffprobe at boot, advertise codec list | Hard: many plugins, many codec gotchas | Easy: provider docs are the contract | Easy |
| Argv injection safety | **Solved by FFmpex+Rambo argv-array exec** (cf. Jellyfin CVE [GHSA-866x-wj5j-2vf4](https://github.com/jellyfin/jellyfin/security/advisories/GHSA-866x-wj5j-2vf4)) | N/A | N/A | N/A |
| CVE blast radius | FFmpeg has many CVEs ([cve list](https://www.cvedetails.com/vulnerability-list/vendor_id-3611/Ffmpeg.html)) but runs out-of-process | Same FFmpeg CVEs **inside the BEAM** (via NIF plugins) | None on adopter | Same FFmpeg CVEs in BEAM |
| Maintenance burden on Rindle | Low (FFmpeg is the world's transcoder; FFmpex is a stable thin wrapper) | High (codec plugin churn) | Low + per-provider client maintenance | Medium (decode loop drift) |
| Footprint added to adopter mix.lock | 2 deps (FFmpex + MuonTrap) | **Many** transitive deps (`membrane_core`, plugin packages, often precompiled C deps) | 1 HTTP client | 1 NIF |
| Backward-compat with v1.0 image flow | Identical pattern (`Rindle.Processor` behaviour) | Different mental model | Different lifecycle (asynchronous webhooks) | Different mental model |

### 2.3 What Peer Libraries Actually Picked

This is the most informative slice of the research:

| Peer library | Tooling | Notes worth copying |
|---|---|---|
| **Rails Active Storage** ([VideoPreviewer](https://github.com/rails/rails/blob/c5bb138e43390a191ddb7aa4e0f46e7af8563dcc/activestorage/lib/active_storage/previewer/video_previewer.rb)) | FFmpeg system binary, shell out, parse JSON ffprobe | Ships an `AudioAnalyzer` and `VideoAnalyzer` that just call ffprobe ([source](https://api.rubyonrails.org/classes/ActiveStorage/Analyzer/AudioAnalyzer.html)). Uses scene-detection ([PR #39096](https://github.com/rails/rails/pull/39096)) for a non-black poster frame. Pre-checks `ffmpeg -version` at runtime ([PR #39047](https://github.com/rails/rails/pull/39047)) — clean error vs cryptic `ENOENT`. |
| **Shrine + streamio-ffmpeg** ([processing.md](https://github.com/shrinerb/shrine/blob/master/doc/processing.md)) | FFmpeg system binary via streamio-ffmpeg | Derivatives are a *functional* transformation: input file in, named output files out. Map keys become DB-tracked derivative names. This is exactly the shape Rindle's `MediaVariant` already has. |
| **Spatie Laravel Media Library** ([Video.php](https://github.com/spatie/laravel-medialibrary/blob/main/src/Conversions/ImageGenerators/Video.php)) | FFmpeg system binary via `php-ffmpeg/php-ffmpeg` | Configurable ffmpeg/ffprobe paths. Conversions auto-fire on `mp4/mov/webm`. Setting `setExtractVideoFrameAtSecond` is the only knob most apps ever need. |
| **CarrierWave + carrierwave-video** ([rheaton](https://github.com/rheaton/carrierwave-video)) | FFmpeg system binary | **Footgun catalogue** (see §6): version-incompatible flags, confusing watermark errors, broken on Android-source video, OGV defaults are bad. |
| **Django** ([django-video-encoding](https://github.com/escaped/django-video-encoding)) | FFmpeg system binary backend, abstract base class for swap-out | The *backend* abstraction is exactly Rindle's `Processor` behaviour. Default backend `video_encoding.backends.ffmpeg.FFmpegBackend` is the "happy path"; users implement their own to delegate. |
| **Node.js fluent-ffmpeg** ([archived 2025-05](https://github.com/fluent-ffmpeg/node-fluent-ffmpeg/issues/1324)) | FFmpeg system binary via fluent builder | **Cautionary tale**: archived. Lessons: don't try to be a full ffmpeg DSL; expose the underlying argv; keep the surface small. |
| **Cloudinary / imgproxy** | Their own services / Go binary | Not directly applicable — they *are* the transcoder. But their **signed-URL contract** is what Rindle's signed delivery already does. |
| **Active Storage `AudioAnalyzer` (Rails 7+)** | ffprobe | Returns `{ duration, bit_rate, sample_rate, tags }` — the exact shape Rindle's `Rindle.Analyzer` should produce. |
| **Mux Elixir SDK** ([mux-elixir](https://github.com/muxinc/mux-elixir)) | HTTP API client | If we ever need delegated, this is the polished example to wrap behind `Rindle.Processor`. |

**Verdict from the peer survey:** every battle-tested adapter for video/audio in adjacent ecosystems shells out to FFmpeg. Membrane and Xav are right for *streaming* and *decode-loop* products, not for "host-app wants a 720p MP4 and a poster JPG." The Dockyard / Software Mansion crowd would, in our specific framing (library, not platform; one-shot transcodes; Oban worker; want install to be `apt install ffmpeg`), pick FFmpex over a Membrane pipeline. Software Mansion themselves built Boombox precisely because direct Membrane is too much pipeline boilerplate for one-shot file conversion.

### 2.4 Locked Tooling Recommendation

**Adopt FFmpex + Rambo (FFmpex's bundled exec) + MuonTrap, with FFmpeg/FFprobe required as system binaries.**

- `FFmpex` builds argv as an *array* (not a shell string), eliminating the entire class of argument-injection vulnerabilities documented in [Jellyfin GHSA-866x-wj5j-2vf4](https://github.com/jellyfin/jellyfin/security/advisories/GHSA-866x-wj5j-2vf4).
- `Rambo` (already used by FFmpex internally) handles the zombie-process / orphan-on-BEAM-crash class of bug that `Porcelain` famously failed at and that node-fluent-ffmpeg never fully solved ([issue #138](https://github.com/fluent-ffmpeg/node-fluent-ffmpeg/issues/138), [#1145](https://github.com/fluent-ffmpeg/node-fluent-ffmpeg/issues/1145)).
- `MuonTrap` is wrapped *around* the call only when the adopter opts in via a config knob (e.g. `processor: [container: :muontrap, cgroup_path: "rindle/transcode"]`), to give Linux-on-prod-server adopters a clean way to RSS-cap a runaway FFmpeg.
- `xav` and `evision` are **rejected** for v1.4 even though `Image.Video` can use them. Reason: they pull FFmpeg into the BEAM as a NIF, which means a crafted MP4 that triggers a libavformat heap overflow ([CVE-2025-1373 family](https://www.sentinelone.com/vulnerability-database/cve-2025-1373/)) takes down the BEAM, not just the worker. Out-of-process FFmpeg fails as `{:error, exit_code}` and Oban retries.
- `Membrane` is **rejected** for v1.4 — see §3 process-model rationale and §6 footgun #2.
- Provider-delegated adapters are **rejected from v1.4 core ship** — adopters who need Mux/CF Stream implement `Rindle.Processor` themselves; we'll publish a guide and an example module in docs, not a package.

---

## 3. Process Model Axis — Where Does the Transcode Run?

### 3.1 Options

| Model | Description |
|---|---|
| **In-BEAM (NIF)** | xav / evision / Membrane plugins. CPU work shares scheduler unless dirty-NIF. |
| **In-BEAM (pure Elixir)** | Pure-Elixir GenServer pipeline (Membrane). Many BEAM processes, all in our VM. |
| **OS-process (Port / Rambo / MuonTrap)** | FFmpeg binary forked from the Oban worker, communicates over stdio/exit-code. |
| **External worker / sidecar** | Dedicated transcode node, dispatched via Oban-on-other-node or pub/sub. |
| **Containerized** | Each transcode in a fresh Docker / gVisor sandbox. |
| **Delegated** | Hand bytes (or a presigned URL) to Mux/CF Stream/Transloadit; receive a webhook. |

### 3.2 The Oban Question

**Can multi-minute transcodes run inside an Oban worker?** Yes, with caveats well-understood by the Oban community.

From [Oban docs](https://hexdocs.pm/oban/Oban.Worker.html) and [community forum](https://elixirforum.com/t/long-running-oban-cron-jobs/51935):

| Concern | Mitigation |
|---|---|
| Default 60s per-attempt timeout if not set | `def timeout(_), do: :timer.minutes(30)` on the worker |
| Long jobs hold a queue slot during deploy/restart (graceful shutdown ≥ 25–60s default) | Bump `:shutdown_grace_period` to e.g. 5 min; use `:cancel`/`:snooze` returns; give the queue dedicated nodes (Oban [splitting-queues recipe](https://hexdocs.pm/oban/splitting-queues.html)) |
| CPU-intensive tasks starve Phoenix queues | **Dedicated `:rindle_video` queue** with low concurrency (1–2), separate from `:rindle_process` |
| Crashing FFmpeg orphan process | MuonTrap binds child lifetime to the BEAM proc; Rambo launches a tiny supervisor that reaps |
| Memory spike on 4K video | OS process is RSS-capped; not a BEAM concern |
| Retry storms on poison input | Rindle existing `MediaVariant.state = :failed` + bounded `max_attempts: 3` |

The Oban community already handles "video transcoding is one notorious type of CPU intensive work" by isolating queues onto dedicated nodes ([Soren recipe](https://sorentwo.com/2019/11/05/oban-recipes-part-7-splitting-queues)). This is exactly what our `Rindle.Workers.ProcessVariant` pattern allows.

### 3.3 What Peer Libraries Did

| Peer | Process model | Lesson |
|---|---|---|
| Active Storage | OS-process FFmpeg from ActiveJob (Sidekiq/SolidQueue) worker | Same shape as Oban + ProcessVariant. **Right.** |
| Shrine + streamio-ffmpeg | OS-process FFmpeg from Sidekiq derivatives job | Same shape. **Right.** |
| Spatie | OS-process FFmpeg from Laravel queue | Same shape. **Right.** |
| Membrane | In-BEAM GenServer pipelines | Right *for streaming products*. **Wrong shape** for one-shot file derivatives. |
| node-fluent-ffmpeg | OS-process from Node | Right shape, **wrong DSL** (got too clever, archived). |
| Mux | Delegated, webhook-driven | Right for *some adopters*; not a default for a library that wants zero cloud setup. |

**Pattern that wins:** OS-process FFmpeg, dispatched from a job queue, with per-worker timeout, dedicated queue, retry, and durable `MediaVariant` record. That's exactly Rindle's existing image worker pattern — we extend it, we don't replace it.

### 3.4 Pros / Cons

| Model | Pros | Cons | Verdict for v1.4 |
|---|---|---|---|
| OS-process via Oban worker (recommended) | Crash isolation; cgroup-able; matches existing image flow; backward compatible; no new runtime concept | Adopter must `apt install ffmpeg`; queue tuning needed for big videos | **CHOSEN** |
| In-BEAM NIF (Xav, Membrane plugins) | No system install (xav precompiled); native Elixir | FFmpeg CVE → BEAM crash; long decode blocks scheduler unless careful | Rejected for transcode; **acceptable for cheap operations like ffprobe-via-xav metadata** but we won't pick it up because ffprobe binary already does this with zero NIF risk |
| Membrane in-BEAM pipeline | Composable; native; great DX for streaming | Many transitive deps; pipeline boilerplate for one-shot; same FFmpeg CVE concerns; not the right abstraction for "make me one MP4" | Rejected |
| External worker (separate Elixir node) | Strong isolation; easy horizontal scale | New runtime concept; Oban already handles this with queue routing | Out of scope; the *Oban queue routing* version is sufficient |
| Containerized per-job | Maximal isolation; clean security story | Requires Docker/gVisor; adopter ops burden; cold start | **Documented escape hatch**, not default |
| Delegated to Mux / CF Stream | Zero ops; HLS/DRM/ABR for free | Cost; cloud lock-in; not "library does it for me" | **Documented escape hatch via custom `Rindle.Processor`**, not default |

### 3.5 Locked Process-Model Recommendation

1. **Default**: `Rindle.Workers.ProcessVariant` dispatches video and audio variants to FFmpeg via FFmpex, on a new dedicated `:rindle_media` queue (override-able). Concurrency default 1; profile-configurable.
2. **Per-worker timeout**: `def timeout(%Oban.Job{} = job)`; default 30 min; profile-configurable per variant spec.
3. **Containment knob**: opt-in `MuonTrap.cmd/3` wrapping with optional cgroup path. Linux-only; macOS dev passes the call through unwrapped.
4. **Backward compat**: existing image variant path is unchanged. The dispatcher picks `Rindle.Processor.Image | .Video | .Audio` based on the variant spec's `:kind` key, defaulting to `:image` to preserve existing profiles.
5. **Dedicated queue rationale**: image and short-audio variants are O(seconds); long video transcodes are O(minutes). Mixing them on one queue starves image throughput. We document the recipe; we don't force separation in code (still one queue at minimum), but we ship a config example.

---

## 4. Format Scope Axis — What Does v1.4 Actually Process?

### 4.1 In Scope (Table Stakes)

**Inputs accepted (validated via magic-byte sniff + ffprobe):**

| Family | Containers | Codecs | Why |
|---|---|---|---|
| Video | `mp4`, `mov`, `webm`, `mkv` (read-only fallback) | H.264, H.265, VP9, AV1 (decode only) | These are what phones, desktops, and browsers produce. Rejecting AVI / WMV / FLV is fine for v1.4. |
| Audio | `mp3`, `m4a` (AAC), `wav`, `flac`, `ogg` (Vorbis/Opus) | AAC, MP3, FLAC, PCM, Vorbis, Opus | Same rationale. |

**Outputs (named-preset variants only — no unsigned dynamic transforms; matches existing Rindle DoS posture):**

| Operation | Output | Default preset |
|---|---|---|
| Video transcode | `mp4` (H.264 baseline/main + AAC) | 720p, CRF 23, AAC 128k |
| Video poster frame | `jpg` / `webp` | Scene-detection at first non-black keyframe (Active Storage's algorithm) |
| Audio transcode | `m4a` (AAC) or `mp3` | 128 kbps mono/stereo |
| Audio normalization | `m4a` / `mp3` with `-af loudnorm=I=-16:TP=-1.5:LRA=11` | EBU R128 single-pass (fast, "good enough"); two-pass available as a profile option |
| Audio waveform peaks | JSON `{ length: N, sample_rate: SR, peaks: [...] }` | 1000 peaks default; configurable |
| Probe / metadata | `Rindle.Analyzer` map | `{ width, height, duration, bit_rate, sample_rate, codec_name, container, has_audio, has_video, display_aspect_ratio, rotation }` |

**Capability vocabulary additions:**

```elixir
@type capability ::
        # existing storage caps unchanged
        | :video_transcode
        | :video_poster
        | :audio_transcode
        | :audio_normalize
        | :audio_waveform
```

### 4.2 Explicitly Out of Scope for v1.4

| Capability | Why deferred | When/where it lands |
|---|---|---|
| HLS playlists (m3u8) | Streaming format, not a one-shot derivative; needs segment lifecycle management | v1.5+ or delegate to Mux/CF Stream |
| DASH (.mpd) | Same as HLS | Same as HLS |
| Adaptive bitrate (ABR) ladder | Multiple renditions + manifest authoring + segmenter coordination | v1.5+; would need a `Rindle.RenditionSet` concept |
| DRM (Widevine, FairPlay, PlayReady) | Cert provisioning, key servers, license servers — full platform territory | Never in core; provider-delegated only |
| Live streaming (RTMP ingest, WebRTC) | Different domain (streaming framework, not lifecycle library) | Membrane territory; never in Rindle core |
| Subtitle / caption burn-in | Adopter-specific | Custom `Rindle.Processor` |
| Watermarking | Adopter-specific (CarrierWave footgun: opaque errors when watermark missing) | Custom `Rindle.Processor` |
| Animated GIF / WebP from video | Edge case | v1.5+ if asked |
| Hardware-accelerated transcode (NVENC, QSV) | Adopter ops/hardware-specific | Document as a config flag, no default |
| Frame-accurate trimming / non-linear edit | Out of "lifecycle library" scope | Custom processor |
| Spectrogram, fingerprinting (Chromaprint) | Specialty | Custom processor |
| Live transcribe / AI captioning | Already excluded by core PROJECT.md; provider-delegated only | Already documented |

### 4.3 Locked Format-Scope Recommendation

v1.4 ships **the Active-Storage-equivalent surface for video and audio**: ffprobe-driven metadata, web-friendly transcode, poster, normalize, waveform. We **do not** become a streaming platform. Adopters who need HLS/DASH/DRM follow our "delegate to a streaming provider via a custom `Rindle.Processor`" doc page and reach for [`mux-elixir`](https://github.com/muxinc/mux-elixir) or roll a Cloudflare Stream / Transloadit HTTP client. Capability honesty is the contract: a profile that asks for `:hls_segments` returns `{:error, {:processor_unsupported, :hls_segments}}` against the bundled processor — no degraded fallback.

---

## 5. Idiomatic Elixir Pattern Blueprint

### 5.1 Module Layout

```
lib/rindle/
├── processor.ex                      # existing behaviour (unchanged)
├── processor/
│   ├── image.ex                      # existing, unchanged
│   ├── video.ex                      # NEW — H.264 transcode, poster
│   ├── audio.ex                      # NEW — transcode, normalize
│   ├── waveform.ex                   # NEW — JSON peaks
│   ├── ffmpeg.ex                     # NEW — shared FFmpex/Rambo/MuonTrap shim, capability probe at boot
│   └── ffprobe.ex                    # NEW — JSON metadata reader for Analyzer
├── analyzer.ex                       # existing behaviour (unchanged)
├── analyzer/
│   ├── image.ex                      # existing libvips path
│   ├── video.ex                      # NEW — wraps Processor.FFprobe for video metadata
│   └── audio.ex                      # NEW — wraps Processor.FFprobe for audio metadata
└── workers/
    └── process_variant.ex            # MODIFIED — dispatch by variant spec :kind
```

### 5.2 Behaviour Stays the Same

`Rindle.Processor` is already the right shape — `process(source, variant_spec, destination) :: {:ok, dest} | {:error, term}`. We do **not** add a callback. We *augment* the contract with capability advertising:

```elixir
defmodule Rindle.Processor do
  @callback process(source :: Path.t(), variant_spec :: map(), destination :: Path.t()) ::
              {:ok, Path.t()} | {:error, term()}

  @callback capabilities() :: [Rindle.Storage.Capabilities.capability()]
  @callback supports?(variant_spec :: map()) :: boolean()
  # both default-implementable via __using__/Code.ensure_loaded? guard
end
```

(`capabilities/0` is optional with a default `[]` to preserve backward compatibility with existing custom processors.)

### 5.3 Variant Spec Shape (Profile DSL Extension)

```elixir
defmodule MyApp.PodcastProfile do
  use Rindle.Profile

  variants do
    # existing image syntax unchanged
    variant :poster, processor: Rindle.Processor.Video, kind: :video_poster, at_seconds: :scene
    variant :web,    processor: Rindle.Processor.Video, kind: :video_transcode,
                     width: 1280, height: 720, codec: :h264, audio_codec: :aac,
                     audio_bitrate: 128, crf: 23
    variant :preview, processor: Rindle.Processor.Audio, kind: :audio_transcode,
                      codec: :aac, bitrate: 96, channels: 2
    variant :loud,    processor: Rindle.Processor.Audio, kind: :audio_normalize,
                      target_lufs: -16, true_peak: -1.5, lra: 11
    variant :wave,    processor: Rindle.Processor.Waveform, kind: :audio_waveform,
                      peaks: 1000, format: :json
  end
end
```

The dispatcher in `ProcessVariant` reads `variant_spec[:processor]` (defaulting to `Rindle.Processor.Image` for backward compat with existing image-only profiles) and calls its `process/3`.

### 5.4 Worker Wiring (Sketch)

```elixir
defmodule Rindle.Workers.ProcessVariant do
  use Oban.Worker, queue: :rindle_media, max_attempts: 3

  @impl Oban.Worker
  def timeout(%Oban.Job{args: %{"variant_name" => name, "asset_id" => id}}) do
    # Look up profile/variant; default 30 min for video, 5 min for audio, 60s image
    Rindle.Internal.Variants.timeout_for(id, name)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # ...existing image flow unchanged...
    # NEW: dispatch on variant_spec[:processor]
    processor = Map.get(variant_spec, :processor, Rindle.Processor.Image)

    with :ok <- ensure_capability(processor, variant_spec),
         {:ok, _} <- processor.process(source_tmp, variant_spec, dest_tmp) do
      # ... atomic update unchanged ...
    end
  end

  defp ensure_capability(processor, %{kind: kind}) when not is_nil(kind) do
    if function_exported?(processor, :supports?, 1) and processor.supports?(%{kind: kind}) do
      :ok
    else
      {:error, {:processor_unsupported, kind}}
    end
  end
  defp ensure_capability(_, _), do: :ok
end
```

### 5.5 FFmpeg Shim (the only "new infrastructure")

```elixir
defmodule Rindle.Processor.FFmpeg do
  @moduledoc false
  alias FFmpex
  alias FFmpex.{StreamSpecifier, Options}

  @doc """
  Run an FFmpex Command struct, optionally containerized via MuonTrap.

  Returns `{:ok, stdout}` or `{:error, {stderr_or_reason, exit_code}}`.

  Honors `Application.get_env(:rindle, :processor_runner, :rambo)`:
    * `:rambo` — default; uses FFmpex.execute/1 (which uses Rambo)
    * `{:muontrap, opts}` — wraps via MuonTrap.cmd/3 with cgroup containment
  """
  def run(command, opts \\ []) do
    # FFmpex builds argv as a list — argv-injection-safe by construction
    case Application.get_env(:rindle, :processor_runner, :rambo) do
      :rambo ->
        FFmpex.execute(command)

      {:muontrap, mt_opts} ->
        {bin, args} = FFmpex.prepare(command)
        case MuonTrap.cmd(bin, args, [stderr_to_stdout: true] ++ mt_opts) do
          {output, 0} -> {:ok, output}
          {output, code} -> {:error, {output, code}}
        end
    end
  end

  @doc "Boot-time capability probe. Caches result in :persistent_term."
  def probe_capabilities do
    case System.find_executable(ffmpeg_path()) do
      nil -> {:error, :ffmpeg_not_found}
      path ->
        # query supported codecs / formats once; cache
        {output, 0} = System.cmd(path, ["-hide_banner", "-codecs"])
        :persistent_term.put({__MODULE__, :codecs}, parse_codecs(output))
        :ok
    end
  end

  defp ffmpeg_path, do: Application.get_env(:rindle, :ffmpeg_path, "ffmpeg")
end
```

### 5.6 Telemetry Surface (New, but Versioned)

Add events under the existing public telemetry contract. **Do not** change existing event names (locked in v1.3 API audit).

```
[:rindle, :processor, :video, :start | :stop | :exception]
[:rindle, :processor, :audio, :start | :stop | :exception]
[:rindle, :processor, :ffprobe, :start | :stop | :exception]
[:rindle, :processor, :ffmpeg_not_found]   # boot probe failure
```

Metadata: `%{profile: ..., variant: ..., kind: ..., duration_ms: ..., codec: ..., container: ..., bytes_in: ..., bytes_out: ...}`.

### 5.7 Boot-Time Health Check (Cribbed from Active Storage's `ffmpeg_exists?`)

On `Application.start/2`, run `Rindle.Processor.FFmpeg.probe_capabilities/0` non-fatally. Log a clear warning if FFmpeg is missing — but do not crash; an adopter using only image profiles must boot fine. The `:rindle_media` queue config remains opt-in.

This is the install-time honesty: when a video profile is configured but FFmpeg is missing, *first variant insert* fails fast with a tagged error and a telemetry event, not a buried `enoent`.

---

## 6. Footguns to Avoid (Numbered, Cited)

1. **Argument injection via filenames or codec params.** [Jellyfin GHSA-866x-wj5j-2vf4](https://github.com/jellyfin/jellyfin/security/advisories/GHSA-866x-wj5j-2vf4) is the canonical case: untrusted `VideoCodec` passed as a single shell-string lets an attacker write arbitrary files via additional `-i` / `-y output` arguments. **Mitigation:** FFmpex builds argv as a list; never `System.cmd("ffmpeg #{flags}")`; never interpolate user-controlled strings into argv except as positional argument values that we further validate against our preset enum.

2. **Membrane plugin tax.** Pulling `membrane_h264_ffmpeg_plugin` + audio plugins + format plugins drags many transitive deps and often *still* requires native build steps. ([membrane_h264_ffmpeg_plugin](https://hexdocs.pm/membrane_h264_ffmpeg_plugin/) wraps FFmpeg + x264 as a NIF.) **Mitigation:** don't ship Membrane in v1.4. Document Membrane as the right tool for streaming/SFU products and link [Boombox](https://github.com/membraneframework/boombox) for streaming-curious adopters.

3. **Zombie / orphan FFmpeg processes** when the BEAM job crashes. Erlang's default `Port` does not propagate exits — a long FFmpeg can outlive the BEAM. ([Erlang Forums discussion](https://erlangforums.com/t/open-port-and-zombie-processes/3111).) **Mitigation:** Rambo (FFmpex's default) ships a tiny supervisor binary that wait()s on the child. Optionally MuonTrap gives cgroup-level enforcement. Never use `System.cmd/3` directly without one of these.

4. **`System.cmd/3` blows up memory on long output.** Port output is not demand-driven; long FFmpeg stderr accumulates in the BEAM mailbox. **Mitigation:** redirect stderr to file or use `stderr_to_stdout: true` with line-buffered pipes (Rambo + FFmpex handle this; MuonTrap needs `:into` option set explicitly).

5. **CarrierWave-video lessons (footgun catalogue):** version-incompatible flags (`-preset` vs `-vpre`), confusing `ffmpeg` errors when watermark file missing, broken on Android-source video despite encoding tweaks, OGV defaults are bad. **Mitigation:** stick to mainstream H.264/AAC for output; surface raw stderr in `:error` tuples and telemetry; do not invent a watermark feature in v1.4 (footgun #1 about confusing errors); test our preset against varied real-world phone uploads in CI.

6. **Default poster = first frame is wrong** for any video that fades in from black. ([Rails PR #39096](https://github.com/rails/rails/pull/39096) fixed this by using FFmpeg `select=eq(pict_type\,I)` or the scene filter.) **Mitigation:** copy Rails' algorithm — first I-frame after a scene change with `>0.4` threshold, fallback to first I-frame, fallback to first frame.

7. **Audio `loudnorm` single-pass produces measurably worse results than two-pass.** ([loudnorm filter docs](https://ayosec.github.io/ffmpeg-filters-docs/7.1/Filters/Audio/loudnorm.html).) **Mitigation:** default to single-pass (faster, fits one-shot worker), expose `two_pass: true` as a variant_spec option for high-fidelity podcast workflows.

8. **Oban graceful-shutdown timeout is shorter than transcode.** Default 25s (`:shutdown_grace_period`) — long videos get killed mid-transcode on every deploy. **Mitigation:** document a `:shutdown_grace_period` recommendation (e.g. 5 min) for adopters running `:rindle_media` queue; surface this in install docs; consider `{:snooze, period}` return on signal handling (Oban Pro feature, document for those who have it).

9. **Disk space exhaustion** on `System.tmp_dir!()` — concurrent 4K transcodes can fill `/tmp` fast. **Mitigation:** copy Active Storage's pattern of cleanup-in-`ensure`; document a `:tmp_dir` config knob; emit telemetry for `tmp_bytes_used`; recommend adopters mount a separate volume for transcode tmp.

10. **CVE blast radius via NIF FFmpeg.** Xav/Membrane embed libavformat/libavcodec inside the BEAM via NIFs. A malformed MP4 triggering [CVE-2025-1373](https://www.sentinelone.com/vulnerability-database/cve-2025-1373/) (use-after-free) takes down the whole BEAM, not just the worker. **Mitigation:** keep FFmpeg out of the BEAM. Subprocess crashes show up as `{:error, exit_code}`; Oban retries; the Phoenix process serving HTTP keeps serving.

11. **MIME spoofing.** Active Storage and Shrine both burned on this. **Mitigation:** Rindle already enforces magic-byte sniffing via `Rindle.Security`; the new processors must call into the existing sniffer, not trust `Content-Type` from the upload session, and must additionally cross-check the ffprobe-detected container against the sniffed container before transcode.

12. **Unbounded variant explosion.** Already locked by PROJECT.md ("named presets only by default"). **Reinforce in v1.4:** the audio-waveform peaks count and the video transcode dimensions are *preset* values per profile. We do not accept query-param-driven `?width=N` variants for video/audio. (DoS surface for transcode is much worse than image — a 4K AV1 → AV1 transcode can run minutes per request.)

13. **Backward-compat regression on existing image profiles.** **Mitigation:** the `:processor` and `:kind` keys must default-to image. CI must include a profile that uses *only* the v1.0 image syntax (no `:processor` key) and prove it still works byte-for-byte.

14. **"It works on my Mac"** — adopters on macOS dev (Homebrew FFmpeg) hit subtly different feature flags than CI on Ubuntu. **Mitigation:** boot-time capability probe (§5.5) snapshots the codec list; CI runs on Ubuntu LTS with stock `apt install ffmpeg`; docs say "test against the Ubuntu version your prod runs."

15. **Provider-delegated adapters create lifecycle ambiguity** — Mux returns "ready" via webhook hours after upload. If we shipped one, our `MediaVariant` FSM would need a `:waiting_for_provider` state that we have explicitly avoided. **Mitigation:** out of scope for v1.4 core; if an adopter implements their own delegated processor, they own the FSM extension via custom states stored in `MediaVariant.metadata`.

16. **Audio waveform format proliferation.** Different frontends want different shapes (raw f32, dat, JSON, audiowaveform's `.dat`). **Mitigation:** v1.4 ships JSON only (`{ length, sample_rate, peaks: [-0.93, 0.81, ...] }`). Document that custom formats are a custom processor.

17. **No ffprobe in PATH.** Common on minimal Docker images. **Mitigation:** boot probe checks both ffmpeg and ffprobe; tagged `{:error, :ffprobe_not_found}` is its own distinct error so adopter docs can say "we found ffmpeg but not ffprobe — install `ffmpeg` package, not just the `ffmpeg` binary."

---

## 7. DX/UX Wins to Copy from Peer Libraries

1. **Active Storage's `ffmpeg_exists?` boot check** — a missing binary fails fast with a clear error, not a cryptic exit code from job N hours later. ([rails/rails#39047](https://github.com/rails/rails/pull/39047)) → boot-time `Rindle.Processor.FFmpeg.probe_capabilities/0`.

2. **Active Storage's keyframe scene-detection poster** — solves "video starts with a black fade" without adopter intervention. ([rails/rails#39096](https://github.com/rails/rails/pull/39096)) → Rindle ships `at_seconds: :scene` as the default.

3. **Shrine's "derivatives are a function: input file → named output files"** — adopter writes a transformation, not a DAG. ([shrinerb/shrine derivatives](https://shrinerb.com/docs/plugins/derivatives)) → Rindle's existing variant model is already this shape; preserve it.

4. **Spatie's "auto-fire on `mp4/mov/webm`"** — opinionated default that "just works" for the common case. ([Spatie defining-conversions](https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions)) → Rindle ships a stock "web" profile preset adopters can extend.

5. **Active Storage's `AudioAnalyzer` returning `{ duration, bit_rate, sample_rate, tags }`** — exact shape and key set so adopters writing audio UIs aren't confused. ([Rails 7.1 sample_rate addition](https://blog.saeloun.com/2023/05/29/extract-sample-rate-of-audio-from-audio-analyzer/)) → adopt verbatim, plus add `:codec_name` since it's free from ffprobe.

6. **Django backend abstraction (`BaseEncodingBackend`)** — even the framework's own backend is just one implementation of a swap-out interface. ([django-video-encoding base.py](https://github.com/escaped/django-video-encoding/blob/master/video_encoding/backends/base.py)) → Rindle's `Rindle.Processor` behaviour already gives adopters this superpower; we just write better docs about it.

7. **Spatie's `setExtractVideoFrameAtSecond`** — one obvious knob covers 95% of "give me a thumbnail at 5s" needs. → Rindle exposes `at_seconds: integer | float | :scene`.

8. **Mux's official Elixir SDK existence** ([muxinc/mux-elixir](https://github.com/muxinc/mux-elixir)) — when adopters do need delegated, the path is `def process(_, _, _), do: Mux.Video.Assets.create(...)`. Document this as the canonical "delegate to a provider" example.

9. **node-fluent-ffmpeg's archive announcement** ([fluent-ffmpeg #1324](https://github.com/fluent-ffmpeg/node-fluent-ffmpeg/issues/1324)) — explicit "stop using this" lesson: don't try to be the all-encompassing FFmpeg DSL. **Rindle never invents one.** Adopters with exotic needs write a custom processor and call FFmpex directly.

10. **imgproxy's signed-URL contract** ([imgproxy signing docs](https://docs.imgproxy.net/usage/signing_url)) — already adopted by Rindle's signed delivery; reinforce that signed-only is the rule for all variants, including waveform JSON (a 4K-waveform DoS is real).

11. **Heroku's blog post about ImageMagick → libvips switch** ([Heroku blog](https://blog.heroku.com/rails-active-storage)) — libvips is "10x faster, 1/10 memory" of ImageMagick. Lesson for our docs: "for video, use FFmpeg — it has no equivalent rival in our domain space." Don't apologize for shelling out.

12. **MuonTrap's "Keep Your Ports Contained" framing** ([MuonTrap README](https://github.com/fhunleth/muontrap)) — the *naming* of the problem ("uncontained ports") teaches adopters about a class of bug they didn't know about. Borrow the framing in our security docs.

---

## 8. Open Questions Worth Escalating to the User

I am locking everything else. Two questions remain that **only** the project owner should decide because they shift public surface area / adopter contracts.

### Q1 (HIGH-IMPACT — public capability vocabulary): Should the new capabilities be on **`Rindle.Processor`** or extend **`Rindle.Storage.Capabilities`**?

Today `Rindle.Storage.Capabilities` is a *storage* capability vocabulary (`:presigned_put`, `:multipart_upload`, etc.). v1.4 introduces *processing* capabilities (`:video_transcode`, `:audio_normalize`, `:audio_waveform`, ...). Two options:

- **(A) Extend `Rindle.Storage.Capabilities`** with processor capability atoms. Pro: one capability vocabulary. Con: muddies the storage/processor boundary that is already cleanly separated, and forces a future `Rindle.Capabilities.processor_caps/0` filter.
- **(B) Introduce a peer module `Rindle.Processor.Capabilities`** with the same shape (`known/0`, `safe/1`, `supports?/2`, `require/2`). Pro: clean separation; matches existing `Rindle.Storage` ↔ `Rindle.Processor` symmetry. Con: two vocabularies; docs need to teach both.

This is a v1.4 milestone-spanning architectural decision and should be locked at planning time, not in a PR. **My recommendation is (B)** — clean separation, mirrors the existing `Storage` ↔ `Processor` split, no risk of a future processor capability colliding with a storage capability name.

### Q2 (HIGH-IMPACT — install posture): Do we tolerate adopters whose hosts have **no** FFmpeg?

Three viable postures:

- **(A) FFmpeg required if any video/audio profile is configured; image-only adopters unaffected.** Boot probe warns; first variant insert with a video profile errors with `:ffmpeg_not_found`. (My default recommendation.)
- **(B) FFmpeg always required from v1.4 onward.** Simpler error surface; everyone knows the contract. Cost: every existing image-only adopter on a minimal Docker image breaks on upgrade.
- **(C) Bundle precompiled FFmpeg (via `elixir_make` + GitHub-Releases-style precompiled-package pattern, e.g. like Vix does for libvips).** Cost: large package, license complexity (FFmpeg is LGPL but x264 is GPL — bundling x264 forces our package GPL, which is a dealbreaker), per-platform release matrix. **I think this is actively a bad idea** given x264, but the user may want to consider the slim "FFmpeg-without-x264" build for default-encoder-is-VP9 adopters.

I am locking **(A)** unless the user explicitly disagrees.

---

## Sources

### Tooling axis
- FFmpex GitHub — [talklittle/ffmpex](https://github.com/talklittle/ffmpex)
- FFmpex Hex — [hex.pm/packages/ffmpex](https://hex.pm/packages/ffmpex)
- FFmpex docs — [hexdocs.pm/ffmpex](https://hexdocs.pm/ffmpex/FFmpex.html)
- Membrane Framework — [membrane.stream](https://membrane.stream/), [membraneframework/membrane_core](https://github.com/membraneframework/membrane_core)
- Membrane H264 FFmpeg plugin — [hexdocs.pm/membrane_h264_ffmpeg_plugin](https://hexdocs.pm/membrane_h264_ffmpeg_plugin/)
- Boombox — [membraneframework/boombox](https://github.com/membraneframework/boombox), [Software Mansion blog](https://blog.swmansion.com/boombox-a-simple-streaming-library-on-top-of-membrane-307649c09d63)
- Xav — [hex.pm/packages/xav](https://hex.pm/packages/xav), [elixir-webrtc/xav](https://github.com/elixir-webrtc/xav)
- Vix — [akash-akya/vix](https://github.com/akash-akya/vix)
- Image library — [elixir-image/image](https://github.com/elixir-image/image), [Image.Video docs](https://hexdocs.pm/image/Image.Video.html)
- Mux Elixir SDK — [muxinc/mux-elixir](https://github.com/muxinc/mux-elixir)
- Cloudflare API client — [princemaple/elixir-cloudflare-api-client](https://github.com/princemaple/elixir-cloudflare-api-client)
- Rambo — [jayjun/rambo](https://github.com/jayjun/rambo)
- MuonTrap — [fhunleth/muontrap](https://github.com/fhunleth/muontrap)
- ExCmd — [hexdocs.pm/ex_cmd](https://hexdocs.pm/ex_cmd/readme.html)
- erlexec — [saleyn/erlexec](https://github.com/saleyn/erlexec)
- ElixirMake precompilation — [hexdocs.pm/elixir_make/precompilation_guide](https://hexdocs.pm/elixir_make/precompilation_guide.html)

### Process model axis
- Oban Worker — [hexdocs.pm/oban/Oban.Worker](https://hexdocs.pm/oban/Oban.Worker.html)
- Oban Splitting Queues — [hexdocs.pm/oban/splitting-queues](https://hexdocs.pm/oban/splitting-queues.html)
- Oban Recipes — Splitting Queues (Soren) — [sorentwo.com](https://sorentwo.com/2019/11/05/oban-recipes-part-7-splitting-queues)
- Long-running Oban discussion — [Elixir Forum](https://elixirforum.com/t/long-running-oban-cron-jobs/51935)
- Oban shutdown handling — [Elixir Forum](https://elixirforum.com/t/how-to-deal-with-very-long-running-oban-jobs-during-queue-shutdown/69083)
- `System.cmd` streaming pitfalls — [tonyc.github.io](https://tonyc.github.io/posts/managing-external-commands-in-elixir-with-ports/), [memdump video streaming in Elixir](https://akash-akya.github.io/posts/video-streaming-in-elixir/)
- Erlang ports zombies — [Erlang Forums](https://erlangforums.com/t/open-port-and-zombie-processes/3111)

### Format scope axis
- Active Storage VideoAnalyzer — [api.rubyonrails.org](https://api.rubyonrails.org/classes/ActiveStorage/Analyzer/VideoAnalyzer.html)
- Active Storage AudioAnalyzer — [api.rubyonrails.org](https://api.rubyonrails.org/classes/ActiveStorage/Analyzer/AudioAnalyzer.html)
- Active Storage VideoPreviewer source — [github.com/rails/rails](https://github.com/rails/rails/blob/c5bb138e43390a191ddb7aa4e0f46e7af8563dcc/activestorage/lib/active_storage/previewer/video_previewer.rb)
- Active Storage scene-detection poster — [rails/rails PR #39096](https://github.com/rails/rails/pull/39096)
- Active Storage `ffmpeg_exists?` boot check — [rails/rails PR #39047](https://github.com/rails/rails/pull/39047)
- Audio loudnorm EBU R128 — [FFmpeg docs](https://ayosec.github.io/ffmpeg-filters-docs/7.1/Filters/Audio/loudnorm.html), [Peter Forgacs guide](https://peterforgacs.github.io/2018/05/20/Audio-normalization-with-ffmpeg/), [32blog complete guide](https://32blog.com/en/ffmpeg/ffmpeg-audio-normalization-loudnorm)
- Audio waveform peaks — [bbc/audiowaveform](https://github.com/bbc/audiowaveform), [t4nz/ffmpeg-peaks](https://github.com/t4nz/ffmpeg-peaks)

### Peer library lessons
- Shrine derivatives — [shrinerb.com/docs/plugins/derivatives](https://shrinerb.com/docs/plugins/derivatives), [shrinerb/shrine processing](https://github.com/shrinerb/shrine/blob/master/doc/processing.md)
- Shrine atomic helpers / race conditions — [shrinerb.com/docs/plugins/atomic_helpers](https://shrinerb.com/docs/plugins/atomic_helpers), [shrine derivatives RFC #386](https://github.com/shrinerb/shrine/issues/386)
- Spatie Laravel Media Library — [spatie.be docs](https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions), [Video.php source](https://github.com/spatie/laravel-medialibrary/blob/main/src/Conversions/ImageGenerators/Video.php)
- CarrierWave video — [rheaton/carrierwave-video](https://github.com/rheaton/carrierwave-video)
- Django video-encoding — [escaped/django-video-encoding](https://github.com/escaped/django-video-encoding), [base backend](https://github.com/escaped/django-video-encoding/blob/master/video_encoding/backends/base.py)
- node-fluent-ffmpeg phase-out — [fluent-ffmpeg #1324](https://github.com/fluent-ffmpeg/node-fluent-ffmpeg/issues/1324)
- imgproxy — [docs.imgproxy.net](https://docs.imgproxy.net/), [signing URL](https://docs.imgproxy.net/usage/signing_url)
- Heroku Active Storage post — [blog.heroku.com](https://blog.heroku.com/rails-active-storage)

### Security
- Jellyfin argument injection — [GHSA-866x-wj5j-2vf4](https://github.com/jellyfin/jellyfin/security/advisories/GHSA-866x-wj5j-2vf4)
- FFmpeg security page — [ffmpeg.org/security.html](https://ffmpeg.org/security.html)
- FFmpeg CVE list — [cvedetails.com](https://www.cvedetails.com/vulnerability-list/vendor_id-3611/Ffmpeg.html)
- CVE-2025-1373 — [SentinelOne writeup](https://www.sentinelone.com/vulnerability-database/cve-2025-1373/)
- FFmpeg security review — [hoop.dev](https://hoop.dev/blog/ffmpeg-security-review-risks-vulnerabilities-and-mitigation-strategies)
