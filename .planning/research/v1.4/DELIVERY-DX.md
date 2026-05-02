# v1.4 — Delivery Surface & Frontend DX for Video/Audio

**Scope:** Locked recommendations for the *delivery surface* (URL resolution, range
requests), the *HTML helpers* (`video_tag/2`, `audio_tag/2`), the *LiveView
upload + transcode-status story*, *capability negotiation* extensions, and
*telemetry/error vocabulary* for video and audio in Rindle v1.4.

**Out of scope (per `.planning/PROJECT.md`):** HLS/DASH manifest generation,
DRM, adaptive bitrate transcoding pipelines, GPU runtimes, FFmpeg/Membrane
processor adapters. These are explicitly deferred to provider adapters
(Mux/Cloudflare Stream/Transloadit) **after** v1.4. v1.4's job is to land the
*surface* that those providers can plug into without the public API changing.

---

## 1. TL;DR — Locked Recommendation

**Keep the existing `Rindle.Delivery.url/3` and `variant_url/4` signatures
unchanged for v1.4.** Video/audio playback works with the *same signed-redirect
strategy* as images, because S3, R2, GCS, and any signed-URL CDN already honor
HTTP `Range` requests on the upstream object — the browser's `<video>` element
talks directly to S3 and gets `206 Partial Content` for free. **Do not build a
range-request proxy in the BEAM.** Range proxies are scheduler-stalls,
backpressure traps (`Plug.Cowboy.Conn.chunk/2` has no backpressure — see
[plug_cowboy#10](https://github.com/elixir-plug/plug_cowboy/issues/10)), and a
duplication of what S3 already does. **Add only:** (a) a thin `Rindle.Delivery.Local`
range-aware Plug for *dev parity* with `Rindle.Storage.Local`, behind a config
flag; (b) `Rindle.HTML.video_tag/3` and `audio_tag/3` matching the existing
`picture_tag/3` shape but with media-element semantics (poster integration via
the existing variant DSL, codec-aware `<source>` ordering, `preload="metadata"`
default); (c) a `Rindle.Processor.capabilities/0` callback parallel to the
storage one, so adopters can ask `Rindle.declare_video_variant?(profile)` at
boot rather than discovering missing FFmpeg at first transcode; (d) PubSub
broadcasting from a new `Rindle.Workers.ProcessVariant` progress hook on
topic `"rindle:variant:#{variant_id}"` carrying `{progress, stage, eta_ms}`
events; (e) a future-shaped `Rindle.Delivery.streaming_url/3` reserved as a
**no-op in v1.4** that delegates to `url/3` but is the *named extension point*
for Mux/Cloudflare Stream provider adapters, so no API break is needed when
HLS lands. Lock error vocabulary now (8 variants below) so adopters never see
`{:error, :enoent}` raw.

---

## 2. Delivery Model — Range Requests, Signed URLs, Plug Posture

### 2.1 What peer libraries do

| Library | Strategy | Range support | Notes |
|---|---|---|---|
| **Active Storage `DiskController`** | Proxy through Rails | Added in Rails 7 ([PR #41437](https://github.com/rails/rails/pull/41437)) | Disk-only adapter; production almost always uses `S3Service` redirect. Puma does not natively support range — Rails recommends [delegating to NGINX `X-Sendfile`](https://medium.com/@themastercado/video-streaming-using-rails-and-nginx-70df2b80174b). [Rails issue #32193](https://github.com/rails/rails/issues/32193) ran for *3 years* before range was added. |
| **Active Storage `S3Service` / `RedirectController`** | 302 to S3 presigned URL | S3 does range natively | This is the production path. The 302 redirect is the [`/rails/active_storage/blobs/redirect/...`](https://api.rubyonrails.org/v7.1/classes/ActiveStorage/Attachment.html) URL. |
| **Active Storage `Streaming` (Rails 7+)** | `send_blob_stream` chunks through Rails | Yes, but uses `ActionController::Live` | Marketing favors this for "secure" delivery; in practice it's the slow path. |
| **Shrine `derivation_endpoint`** | Rack app dynamically derives + serves | Yes, returns `206` with `Content-Range` ([docs](https://shrinerb.com/docs/plugins/derivation_endpoint)) | Designed for *image* derivations; range is a side effect of `Rack::File`. Not optimized for multi-GB video. |
| **Shrine `download_endpoint`** | Rack app proxies origin | Inherits Rack range behavior | Used for private signed-URL emulation when origin doesn't support signing. |
| **Cloudflare Stream** | Manifest URL with token; player fetches segments directly from edge | Range is per-segment, not relevant | URL pattern: `https://customer-<CODE>.cloudflarestream.com/<TOKEN>/manifest/video.m3u8` ([docs](https://developers.cloudflare.com/stream/viewing-videos/securing-your-stream/)). Two token strategies: API tokens for `<1k/day`, signing keys for higher. |
| **Mux** | Playback ID + JWT in URL | Per-segment; HLS by default | [Signed playback policies](https://www.mux.com/articles/securing-video-playback-with-signed-urls). |
| **Cloudinary `cl_video_tag`** | Helper generates `<video>` with multiple `<source>`; URLs are CDN-signed | CDN handles range | [Source](https://github.com/cloudinary/cloudinary_gem/blob/master/lib/cloudinary/video_helper.rb): generates `<source>` per `source_types: [:webm, :mp4, :ogv]` with codec-aware MIME types and an auto-poster from the middle frame. |
| **Spatie Laravel Media Library** | Defers entirely to Laravel filesystem disks (S3/local) | Inherits | Conversions defined per-collection: `addMediaConversion('thumb')->extractVideoFrameAtSecond(20)->performOnCollections('videos')` ([docs](https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions)). |

### 2.2 What they got RIGHT

- **Active Storage redirect mode** — the right default. The library issues a
  302 to a signed S3 URL and the browser does the `Range` dance with S3. The
  app process is freed in milliseconds. This matches Rindle's current image
  delivery exactly.
- **Cloudinary** — codec-aware `<source>` ordering, auto-poster from variant
  DSL. Adopter writes one helper call; the library handles everything.
- **Cloudflare Stream / Mux** — token in URL path (not query string) so CDN
  cache keys naturally segment per user-token-bucket. Dual token strategy
  (API-issued for low volume, key-signed for high volume) is a real
  insight — Rindle's signed URLs are already key-signed via ExAws.

### 2.3 What they got WRONG

- **Active Storage `DiskController`** — range *not added until Rails 7*. For 3
  years, anyone using local disk in dev had broken seek-bar behavior in
  Safari. **Rindle must not ship this footgun.** Local dev parity matters; the
  fix is small.
- **Active Storage `Streaming` concern** — surface looks attractive ("just
  call `send_blob_stream`!") but using `ActionController::Live` ties up a
  request thread for the entire viewing session. On Puma without NGINX
  in front, this is a DoS vector. The Rails docs even tell you to delegate to
  NGINX via `X-Sendfile`.
- **Shrine `derivation_endpoint` for video** — designed for fast image
  derivations; downloading multi-GB video to derive a 1MB poster is
  fundamentally the wrong shape, but the API doesn't tell you that.
- **`Plug.Cowboy.Conn.chunk/2` for video proxying** — known issue
  ([plug_cowboy#10](https://github.com/elixir-plug/plug_cowboy/issues/10)):
  no backpressure, full stream "realized" almost immediately in cowboy stream
  handler. Memory blows up. Rindle must avoid this path.

### 2.4 Locked recommendation — Plug-level

**Production path (S3, R2, MinIO, GCS):** Unchanged. Adopter app calls
`Rindle.Delivery.variant_url(profile, asset, variant)`. Library returns a
short-lived signed S3 GET URL. Adopter app issues a 302 redirect (or
embeds the URL directly in `<video src>`). S3 honors `Range` headers
natively. **Zero BEAM time spent on streaming bytes.**

**Dev/local path:** A new opt-in Plug, `Rindle.Delivery.LocalPlug`, mounted
in adopter's router *only when* the configured storage adapter is
`Rindle.Storage.Local`. This Plug:

1. Verifies the signed token (HMAC over `key + expiry + actor_subject`)
2. Resolves the storage path via `Rindle.Storage.Local`
3. Parses a single-range `Range: bytes=N-M` header (multi-range explicitly
   *unsupported*; fall back to full body, matching [Plug PR #526](https://github.com/elixir-plug/plug/pull/526)'s
   approach)
4. Calls `Plug.Conn.send_file/5` with the parsed `offset` + `length` and
   status `206` plus `Content-Range`/`Accept-Ranges: bytes` headers
5. On unparseable `Range`, falls back to status `200` + full file (graceful
   degradation per RFC 7233)
6. Refuses to mount unless the storage adapter is local — fail fast at
   adopter boot, not at first request

This is **only for dev parity**, not a production posture. The `@moduledoc`
must say so loudly. Adopters are *welcome* to mount it in production at
their own risk, with the same caveats Rails docs apply to `DiskController`
(no scaling, no CDN fronting, no concurrent-request safety beyond what the
OS `sendfile(2)` provides).

### 2.5 Range-request handling sketch

```elixir
defmodule Rindle.Delivery.LocalPlug do
  @moduledoc """
  Range-aware delivery Plug for `Rindle.Storage.Local`.

  **Dev parity only.** Mount this in production at your own risk. For S3, R2,
  GCS, MinIO, and any signed-URL CDN, prefer `Rindle.Delivery.url/3` and 302
  redirects — those backends honor `Range` requests natively and don't tie up
  a BEAM scheduler for the duration of playback.
  """
  @behaviour Plug
  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with {:ok, key, ttl} <- verify_signed_path(conn),
         {:ok, %{size: size}} <- Rindle.Storage.Local.head(key, []),
         {:ok, path} <- resolve_path(key) do
      conn
      |> put_resp_header("accept-ranges", "bytes")
      |> put_resp_header("cache-control", "private, max-age=#{ttl}")
      |> serve_file(path, size, get_req_header(conn, "range"))
    else
      {:error, :not_found} -> send_resp(conn, 404, "")
      {:error, :unauthorized} -> send_resp(conn, 403, "")
      {:error, :expired} -> send_resp(conn, 410, "")
    end
  end

  # Single-range only. Multi-range falls through to full body. RFC 7233.
  defp serve_file(conn, path, size, [range_header]) do
    case parse_byte_range(range_header, size) do
      {:ok, offset, length, content_range} ->
        conn
        |> put_resp_header("content-range", content_range)
        |> put_resp_header("content-length", Integer.to_string(length))
        |> send_file(206, path, offset, length)

      :error ->
        # Unparseable range -> serve full file (graceful degradation)
        conn |> put_resp_header("content-length", Integer.to_string(size))
             |> send_file(200, path)
    end
  end

  defp serve_file(conn, path, size, _no_range) do
    conn |> put_resp_header("content-length", Integer.to_string(size))
         |> send_file(200, path)
  end

  # bytes=N-M | bytes=N- | bytes=-M
  defp parse_byte_range("bytes=" <> spec, size) do
    case String.split(spec, "-") do
      [from, ""] ->
        from = String.to_integer(from)
        {:ok, from, size - from, "bytes #{from}-#{size - 1}/#{size}"}
      ["", suffix] ->
        suffix_len = String.to_integer(suffix)
        from = max(0, size - suffix_len)
        {:ok, from, size - from, "bytes #{from}-#{size - 1}/#{size}"}
      [from, to] ->
        from = String.to_integer(from)
        to = min(String.to_integer(to), size - 1)
        {:ok, from, to - from + 1, "bytes #{from}-#{to}/#{size}"}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp parse_byte_range(_, _), do: :error
end
```

**Why `send_file/5` and not `send_chunked/2` + `chunk/2`:** `send_file/5`
uses the OS `sendfile(2)` syscall when available, bypassing BEAM heap and
giving the kernel zero-copy delivery
([Lucas Sifoni's deep dive](https://lucassifoni.info/blog/deep-dive-plug-conn-send-file/)).
`send_chunked` lacks backpressure on Cowboy and will OOM on large videos.

### 2.6 Footgun: Signed URL TTL during long playback

Already discussed in [Mux's signed-URL guide](https://www.mux.com/articles/securing-video-playback-with-signed-urls):
"too short interrupts users; too long defeats security". Existing Rindle
default `signed_url_ttl_seconds` is per-profile. **Locked recommendation:**
Document a profile-level recommendation table in v1.4 docs:

| Content type | Recommended TTL |
|---|---|
| Image (current default) | 900s (15min) — unchanged |
| Audio (≤30min typical) | 3_600s (1h) |
| Video VOD (≤2h typical) | 7_200s (2h) |
| Long-form video (>2h) | Adopter must implement [token refresh hook](#54-transcode-progress-pubsub-pattern) on the player side |

For HLS later (out-of-scope v1.4), the player handles fresh manifest fetches.
For progressive MP4 in v1.4, **the URL must outlive the longest expected
playback session** because the browser makes range requests against the
same URL. If it expires mid-playback, seek breaks. This is a documentation
fix, not a code fix.

---

## 3. Streaming Opt-In Surface — Future-Proofing for HLS/Mux/Cloudflare

### 3.1 What Active Storage got wrong

Active Storage *does not* expose a streaming-aware delivery URL primitive.
Adopters who add Mux/Cloudflare must either (a) bypass Active Storage's URL
helpers entirely and write their own, or (b) shoehorn streaming URLs into
the same `rails_blob_path` / `rails_storage_proxy_path` helpers and lose
the type safety of "this is a manifest URL, not a binary URL". The result
is that every Active Storage + Mux integration in the wild is bespoke.

**Lesson:** Reserve the namespace for streaming URLs *now*, even if the
implementation in v1.4 is a no-op alias. Adopters writing v1.4 code today
should be writing the API call shape that will work unchanged in v2.0
when Mux adapter ships.

### 3.2 Locked recommendation — `Rindle.Delivery.streaming_url/3`

```elixir
defmodule Rindle.Delivery do
  @doc """
  Returns a streaming-protocol-aware delivery URL.

  In v1.4 this delegates to `url/3` for backends that don't differentiate
  (S3, R2, GCS, Local) — progressive MP4 over signed redirect is the
  default video posture. Adopters who later swap in a streaming provider
  adapter (Mux, Cloudflare Stream, Transloadit) get HLS manifest URLs
  *without changing template code*.

  Returns `{:ok, %{url: String.t(), kind: :progressive | :hls | :dash, mime: String.t()}}`.
  """
  @spec streaming_url(module(), String.t(), keyword()) ::
          {:ok, %{url: String.t(), kind: atom(), mime: String.t()}}
          | {:error, term()}
  def streaming_url(profile, key, opts \\ []) do
    # v1.4 default: delegate to signed-redirect with kind: :progressive
    case url(profile, key, opts) do
      {:ok, url} ->
        {:ok, %{url: url, kind: :progressive, mime: opts[:mime] || "video/mp4"}}
      err -> err
    end
  end
end
```

**Why a separate function, not a flag on `url/3`:** The return *shape*
differs. A progressive MP4 URL is a binary-blob URL; an HLS manifest URL
is a text manifest that itself references segment URLs. They have different
caching semantics, different MIME types, different range semantics. Forcing
them through `url/3` means either (a) callers must always inspect a
discriminator, or (b) the streaming case looks like an unsigned redirect.
Active Storage's mistake was conflating these. **Don't repeat it.**

**Why ship the no-op now, not later:** Adopters writing v1.4 code today
can call `Rindle.Delivery.streaming_url/3` from their template helpers.
When Mux adapter lands, no template changes. The v1.4 contract is "use
`streaming_url/3` for `<video>` and `<audio>` source URLs;
`url/3` is for signed downloads/CDN-cacheable images". This is the
*surface segregation* Active Storage missed.

### 3.3 Provider adapter behaviour sketch

```elixir
defmodule Rindle.Streaming.Provider do
  @moduledoc """
  Behaviour for streaming-protocol providers. Reserved for v2.0+;
  v1.4 ships only the surface, not implementations.
  """

  @type kind :: :progressive | :hls | :dash
  @type stream_meta :: %{url: String.t(), kind: kind(), mime: String.t()}

  @callback streaming_url(profile :: module(), key :: String.t(), opts :: keyword()) ::
              {:ok, stream_meta()} | {:error, term()}

  @callback capabilities() :: [:hls | :dash | :progressive | :live | :live_dvr]
end
```

Profiles will eventually opt in:

```elixir
defmodule MyApp.VideoProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    streaming: Rindle.Streaming.Mux,    # future, post-v1.4
    variants: %{...}
end
```

In v1.4 the `:streaming` key is unused; absence implies "delegate to
`Rindle.Delivery.url/3`, kind: `:progressive`."

---

## 4. HTML Helpers — `video_tag/3`, `audio_tag/3`

### 4.1 Peer-library shape

**Rails 7.1 `video_tag` ([docs](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html)):**
- Accepts `String | [String] | ActiveStorage::Blob`
- Single source: `<video src="...">`
- Multiple sources: `<video><source src="..." /><source src="..." /></video>`
- Options: `:size`, `:poster`, `:poster_skip_pipeline`, plus standard HTML5
  attrs (`controls`, `autoplay`, `preload`, `muted`, `loop`)
- Active Storage attachments unpack via `polymorphic_path` automatically

**Cloudinary `cl_video_tag` ([source](https://github.com/cloudinary/cloudinary_gem/blob/master/lib/cloudinary/video_helper.rb)):**
- `:source_types` defaulting to `[:webm, :mp4, :ogv]`
- Per-source-type transformations via `:source_transformation`
- `:poster` accepting String, Hash with `public_id`, or Hash without (auto-frame
  from middle of video) — *this is the killer feature*, the helper integrates
  with the variant DSL
- Codec-specific MIME types (`video/mp4; codecs="avc1.42E01E"`)
- Fallback content via block

**`phoenix_html_helpers` ([Hex](https://hexdocs.pm/phoenix_html_helpers/PhoenixHTMLHelpers.Tag.html)):**
- Generic `tag/2`, `content_tag/3` only — no media-specific helpers
- Phoenix has *never* shipped video/audio tag helpers; users hand-roll them

**WebVTT `<track>` ([W3C](https://www.w3.org/WAI/WCAG21/Techniques/html/H95.html)):**
- Captions/subtitles attached as `<track kind="captions" srclang="en" label="English" src="...">`
- WCAG 2.1 H95 compliance requires this for video; v1.5+ surface but reserve
  the keyword now

### 4.2 What they got RIGHT vs WRONG

| | Right | Wrong |
|---|---|---|
| **Rails `video_tag`** | Active Storage attachment auto-resolution; minimal API | No codec-aware source ordering; no built-in poster integration with variant pipeline; `:size: "16x10"` is bizarre |
| **Cloudinary `cl_video_tag`** | Auto-poster from variant; `:source_types` pattern; codec-specific MIME | Hard-coded codec list; tightly coupled to Cloudinary CDN |
| **Phoenix.HTML** | (Doesn't ship one — clean slate for Rindle) | Adopters today reinvent this poorly |

### 4.3 Locked recommendation — DX

**Principle of least surprise:** the helper should look exactly like
`picture_tag/3` from v1.0. Same shape: `(profile, asset, opts)`. Same
variant resolution semantics. Same fallback to original on missing/stale
variants. Same opts pass-through for HTML attributes.

```elixir
defmodule Rindle.HTML do
  @doc """
  Renders a `<video>` element with `<source>` entries for each ready video
  variant and a fallback `<source>` to the original asset.

  Variant order in `:variants` is preserved as `<source>` order, which
  determines codec-priority (browser picks the first it can play). Stale
  or non-ready variants are skipped — the fallback always resolves to the
  original asset.

  ## Options

    * `:variants` — list of `{name, %{type: "video/mp4", codecs: "..."}}` tuples,
      `%{name: ..., type: ...}` maps, or bare atom variant names. Order matters:
      first = highest priority. Bare atoms get MIME inferred from variant
      content_type metadata.
    * `:poster` — variant atom (e.g. `:poster_jpg`) resolved through the variant
      DSL, or a literal URL string, or `false` to suppress.
    * `:tracks` — list of caption/subtitle track maps (reserved for v1.5+);
      shape `[%{kind: :captions, srclang: "en", label: "English", src: url}]`.
    * `:preload` — `:auto | :metadata | :none`, default `:metadata`. Per
      [web.dev guidance](https://web.dev/fast-playback-with-preload/), metadata
      is the safe default — duration + dimensions without burning bandwidth.
    * `:controls`, `:autoplay`, `:loop`, `:muted` — pass-through HTML5 attrs.
    * `:placeholder` — string `src` when no variant is ready and the asset has
      no `:storage_key`.
    * Any other key is rendered as a literal HTML attribute on the `<video>`.

  ## Example

      <%= Rindle.HTML.video_tag(MyApp.VideoProfile, asset,
            variants: [
              {:hd_webm, %{type: "video/webm; codecs=\\\"vp9\\\""}},
              {:hd_mp4,  %{type: "video/mp4; codecs=\\\"avc1.640028\\\""}},
              {:sd_mp4,  %{type: "video/mp4"}}
            ],
            poster: :poster_jpg,
            controls: true,
            preload: :metadata,
            class: "rounded-lg w-full"
          ) %>
  """
  @spec video_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()
  def video_tag(profile, asset, opts \\ [])

  @doc """
  Renders an `<audio>` element with `<source>` entries.

  Same opts shape as `video_tag/3` minus `:poster`. Defaults `:preload` to
  `:metadata` and `:controls` to `true` (audio without controls is a UX
  anti-pattern unless explicitly disabled).
  """
  @spec audio_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()
  def audio_tag(profile, asset, opts \\ [])
end
```

### 4.4 Adopter-facing example

```heex
<%!-- A Rindle video profile with three variants and a poster --%>
<%= Rindle.HTML.video_tag(@profile, @asset,
      variants: [
        {:web_webm, %{type: "video/webm"}},
        {:web_mp4, %{type: "video/mp4"}},
        :original
      ],
      poster: :poster_jpg,
      preload: :metadata,
      controls: true,
      class: "aspect-video w-full",
      "aria-label": @asset.title
    ) %>

<%!-- Audio, dead simple --%>
<%= Rindle.HTML.audio_tag(@profile, @asset,
      variants: [{:normalized_mp3, %{type: "audio/mpeg"}}, :original]
    ) %>
```

Generated HTML:

```html
<video class="aspect-video w-full" aria-label="Sintel trailer"
       controls preload="metadata"
       poster="https://signed-url-for-poster.jpg?...">
  <source src="https://signed-url-for-webm.webm?..." type="video/webm">
  <source src="https://signed-url-for-mp4.mp4?..." type="video/mp4">
  <source src="https://signed-url-for-original.mp4?...">
  Your browser does not support video playback.
</video>
```

### 4.5 Why these defaults, locked

- **`preload="metadata"`** — Web.dev consensus, video.js consensus. Saves
  user bandwidth (especially mobile) while still showing duration + first
  frame. `auto` is too aggressive; `none` makes seek bars unusable.
- **Codec-specific MIME** — without `codecs="..."`, browser must download a
  byte to detect; with it, browser picks correctly upfront. Cloudinary
  ships this; Rails doesn't.
- **`:poster` as variant atom** — integrates with the existing variant DSL.
  Adopter declares `variant :poster_jpg, processor: Rindle.Processor.Image, frame: 5_000`
  in their profile (poster is *just another variant* — image variant whose
  source is a video frame at second N). The helper resolves the variant URL
  and wires it to the `poster=` attribute. This is what Cloudinary got right
  and Rails got wrong. **Crucial:** poster generation requires a video processor
  with `:video_frame_extract` capability — surfaced via the capability behaviour
  in §6.
- **`:tracks` reserved but unimplemented** — Captions are WCAG 2.1 H95
  required for accessibility but require a separate variant flavor (text,
  not media binary). Defer to v1.5; reserve the keyword now so v1.5 doesn't
  break the helper signature.
- **No HLS-specific opts in v1.4** — `streaming_url/3` returns `kind: :hls`
  in the future and the helper *will need to change* (HLS uses one `<source
  type="application/vnd.apple.mpegurl">` not multiple). v1.4 helper assumes
  progressive MP4 only. Detection via `streaming_url/3` return shape is the
  v2.0 path; document the plan in `@moduledoc`.
- **Picture-element for posters with srcset** — *Rejected for v1.4.* The
  `<video poster>` attribute does not accept srcset (it's a single URL).
  Responsive posters via `<picture>` would require ditching the native
  `poster` attr and stacking `<picture>` + `<video>`. Adopters who need it
  can hand-roll; a future helper can address it. Don't bake complexity in
  v1.4 for a niche need.

---

## 5. LiveView Integration — Upload + Progress + Transcode Status

### 5.1 What v1.0–v1.3 already does

`Rindle.LiveView.allow_upload/4` configures presigned PUT uploads via
`Rindle.Upload.Broker.sign_url/1`. This works for video files — multipart
upload (v1.1) handles files >5GB transparently when adopters use
[UpChunk](https://docs.mux.com/docs/upload-files-directly) or equivalent.
The `external_fn` returns a `:url`, `:method`, `:headers` payload that
LiveView's JS upload entries consume.

**Gap for v1.4:** transcode is *post-upload*. The upload completes, the
asset is `ready`, but variants are still being processed by Oban workers —
that is the long pole. Operators want to see "processing 60%". Adopters
want to display "your video is being prepared" in their LiveView, with
real-time updates and *no polling*.

### 5.2 Peer-library lessons

**[DockYard's "Live Streaming with LiveView and Mux"](https://dockyard.com/blog/2020/09/25/live-streaming-with-liveview-and-mux-in-under-70-lines-of-code):**
Webhook from Mux → PubSub broadcast → LiveView `handle_info`. Pattern
established years ago and still the right shape.

**[Hex Shift on Phoenix LiveView + Oban real-time monitoring](https://dev.to/hexshift/phoenix-liveview-meets-oban-real-time-interfaces-powered-by-background-jobs-30ka):**
Worker emits `Phoenix.PubSub.broadcast(MyApp.PubSub, "report:#{job_id}", %{progress: 80})`,
LiveView subscribes in mount and updates assigns in `handle_info`.

**[Phoenix LiveView UploadWriter](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.UploadWriter.html):**
For chunk-by-chunk processing during upload — relevant for adopters who
want to *transcode while uploading* (MediaRecorder live cases). Out of
scope for v1.4 core but the surface should not preclude it.

**[Membrane telemetry](https://hexdocs.pm/membrane_core/Membrane.Telemetry.html):**
Membrane Core 1.2.0 introduced per-callback telemetry events. When the
Membrane processor adapter ships post-v1.4, those events should bubble
through Rindle's PubSub; design for that now.

**[FFmpeg `-progress` flag](https://www.ffmpeg.org/ffmpeg.html):**
Native `-progress pipe:1` writes structured key=value pairs to stdout
(`out_time_us=...`, `frame=...`, `progress=continue|end`). When the FFmpex
adapter ships post-v1.4, parse this stream. For v1.4, none of this exists
in core — but the *PubSub event shape* must match what the future processor
adapter will emit, so adopters writing dashboards now don't have to rewrite.

### 5.3 What they got RIGHT vs WRONG

- **DockYard pattern** — RIGHT: webhook → PubSub → LiveView is the cleanest
  shape and works regardless of where transcode happens (in-process or in
  Mux's cloud).
- **Active Storage** — WRONG: zero progress visibility for variant generation.
  Variant URLs return `loading.gif` placeholder until Active Storage's
  on-the-fly generator finishes, then magically swap. No way for adopter UI
  to show progress.
- **Spatie Media Library** — RIGHT-ish: `queued()` conversions emit Laravel
  events that adopters can listen to. WRONG: not surfaced in any official
  Livewire/Inertia helper, so adopters reinvent.

### 5.4 Locked recommendation — Transcode-progress PubSub pattern

**Topic naming convention:**

```
"rindle:variant:#{variant_id}"          — per-variant progress (most granular)
"rindle:asset:#{asset_id}"              — asset-level rollup (one fan-out per asset)
"rindle:upload_session:#{session_id}"   — upload progress (already exists)
```

**Event shapes (broadcast as `{:rindle_event, event_type, payload}`):**

```elixir
{:rindle_event, :variant_started,
  %{variant_id: id, profile: MyApp.VideoProfile, name: :hd_mp4,
    started_at: ~U[...], estimated_duration_ms: 120_000}}

{:rindle_event, :variant_progress,
  %{variant_id: id, profile: ..., name: :hd_mp4,
    progress: 0..100, stage: :transcoding,
    eta_ms: 45_000, frames_processed: 1234, frames_total: 5678}}

{:rindle_event, :variant_ready,
  %{variant_id: id, profile: ..., name: :hd_mp4,
    duration_ms: 118_233, output_size_bytes: 45_678_900}}

{:rindle_event, :variant_failed,
  %{variant_id: id, profile: ..., name: :hd_mp4,
    error: %Rindle.Error{action: :process_variant, reason: ...},
    retryable?: true, attempt: 2, max_attempts: 5}}
```

**Adopter-facing helper** (new in v1.4):

```elixir
defmodule Rindle.LiveView do
  @doc """
  Subscribe a LiveView socket to processing-status events for the given
  variant, asset, or upload session. Subsequent events arrive as
  `{:rindle_event, type, payload}` messages handled in `handle_info/2`.

  Returns the subscription topic for later unsubscribe.
  """
  @spec subscribe(:variant | :asset | :upload_session, term()) :: String.t()
  def subscribe(scope, id) do
    topic = topic_for(scope, id)
    Phoenix.PubSub.subscribe(Rindle.Config.pubsub(), topic)
    topic
  end

  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(topic), do: Phoenix.PubSub.unsubscribe(Rindle.Config.pubsub(), topic)

  defp topic_for(:variant, id), do: "rindle:variant:#{id}"
  defp topic_for(:asset, id), do: "rindle:asset:#{id}"
  defp topic_for(:upload_session, id), do: "rindle:upload_session:#{id}"
end
```

**Adopter usage:**

```elixir
def handle_event("save", %{"video" => _}, socket) do
  results = Rindle.LiveView.consume_uploaded_entries(socket, :video, fn entry, meta ->
    Rindle.LiveView.subscribe(:asset, meta.asset_id)
    {:ok, %{asset_id: meta.asset_id, status: :processing}}
  end)
  {:noreply, assign(socket, uploaded: results)}
end

def handle_info({:rindle_event, :variant_progress, %{progress: p, name: n}}, socket) do
  {:noreply, assign(socket, transcoding_progress: %{name: n, percent: p})}
end

def handle_info({:rindle_event, :variant_ready, payload}, socket) do
  {:noreply, socket
    |> assign(transcoding_progress: %{name: payload.name, percent: 100})
    |> push_event("variant_ready", payload)}
end

def handle_info({:rindle_event, :variant_failed, %{error: err}}, socket) do
  {:noreply, put_flash(socket, :error, Exception.message(err))}
end
```

**Template:**

```heex
<div :if={@transcoding_progress}>
  <p>Preparing {@transcoding_progress.name}...</p>
  <progress value={@transcoding_progress.percent} max="100">
    {@transcoding_progress.percent}%
  </progress>
</div>
```

### 5.5 Why a separate `subscribe/2` and not auto-subscribe in `consume_uploaded_entries`

- LiveView mounts must be deterministic; surprise PubSub subscriptions are
  hard to reason about during unmount.
- Some adopters don't *want* live status (e.g. they re-render via
  AsyncResult or polling for their own UI taste).
- Explicit subscribe is one extra line and three orders of magnitude more
  legible.

### 5.6 Cancellation and progress UX

LiveView's existing `cancel_upload/3` already covers *upload* cancellation
([docs](https://hexdocs.pm/phoenix_live_view/uploads.html)). What v1.4 must
add is **transcode cancellation**:

```elixir
@spec cancel_processing(asset_id :: any()) :: :ok | {:error, :not_processing}
def Rindle.cancel_processing(asset_id)
```

Implementation: cancel queued/executing Oban jobs for variants of this
asset, mark variants as `cancelled` (new variant_fsm state), broadcast
`{:rindle_event, :variant_cancelled, ...}`. v1.4 should ship the API and
fsm transition; the actual ffmpeg-process-killing belongs to the
processor adapter. `Rindle.Processor.Image` is fast enough that
cancellation rarely matters; for video it's table stakes.

### 5.7 Backpressure / progress emission rate

ffmpeg can fire progress events many times per second. Don't broadcast
every one — that's a LiveView-storm. **Locked:** the worker throttles
broadcasts to `≤2/second` per variant via `:timer.tc` gating (or a
GenServer wrapper if processors are concurrent on one variant, which they
should not be). Documented loudly as "PubSub events are rate-limited;
don't depend on receiving every frame update."

---

## 6. Capability Negotiation — Processors

### 6.1 Existing pattern

Storage adapters advertise `capabilities/0`:

```elixir
@impl true
def capabilities, do: [:presigned_put, :head, :signed_url, :multipart_upload]
```

Used at runtime: `Rindle.Storage.Capabilities.require_upload(adapter, :multipart_upload)`
returns `{:error, {:upload_unsupported, :multipart_upload}}` if missing.

### 6.2 The video adopter's nightmare

Adopter declares:

```elixir
defmodule MyApp.VideoProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: %{
      hd_mp4: %{processor: Rindle.Processor.Video, codec: :h264, ...}
    }
end
```

…on a server with no FFmpeg installed. Without capability negotiation,
this fails at *first variant transcode*, *several minutes* after upload,
in an Oban worker, with whatever cryptic error FFmpex emits. The adopter
sees a notification icon, no failure on the upload, no signal at boot or
in `mix test`.

### 6.3 Locked recommendation — Processor capability behaviour

```elixir
defmodule Rindle.Processor do
  @typedoc """
  Processor capability vocabulary.

  Image-processor capabilities:
    * `:image_resize` — variant DSL `width`, `height`, `resize: ...`
    * `:image_format_convert` — variant DSL `format: :webp | :avif | ...`
    * `:image_strip_metadata` — variant DSL `strip_metadata: true`

  Video-processor capabilities (reserved; no core processor in v1.4):
    * `:video_transcode` — variant DSL `codec:`, `bitrate:`, `container:`
    * `:video_frame_extract` — variant DSL `frame: ms` (poster generation)
    * `:video_thumbnail_strip` — variant DSL `thumbnails: %{count:, size:}`
    * `:video_clip` — variant DSL `start_ms:`, `end_ms:`

  Audio-processor capabilities (reserved; no core processor in v1.4):
    * `:audio_normalize` — variant DSL `normalize: :ebu_r128 | :peak | ...`
    * `:audio_transcode` — variant DSL `codec: :aac | :opus | :mp3`
    * `:audio_waveform` — variant DSL `waveform: %{width:, height:}`
  """
  @type capability ::
          :image_resize | :image_format_convert | :image_strip_metadata
          | :video_transcode | :video_frame_extract
          | :video_thumbnail_strip | :video_clip
          | :audio_normalize | :audio_transcode | :audio_waveform

  @callback process(source :: Path.t(), variant_spec :: map(), destination :: Path.t()) ::
              {:ok, Path.t()} | {:error, term()}

  @doc """
  Returns the capabilities supported by this processor.

  Optional callback. Defaults to `[]` for backward compatibility with
  existing v1.0-v1.3 processors. Processors that override should declare
  honestly — claiming a capability you can't fulfill is the worst possible
  failure mode for adopters.
  """
  @callback capabilities() :: [capability()]
  @optional_callbacks [capabilities: 0]
end
```

**Boot-time validation** (new in v1.4, runs in `Rindle.Profile.compile/1`
or via a Mix task):

```elixir
@spec validate_profile!(module()) :: :ok | no_return()
def Rindle.Profile.validate_profile!(profile) do
  storage = profile.storage_adapter()
  Enum.each(profile.variants(), fn {name, spec} ->
    processor = spec.processor
    required = Rindle.Profile.required_processor_capabilities(spec)
    declared = capabilities_or_empty(processor)

    case required -- declared do
      [] -> :ok
      missing ->
        raise Rindle.Profile.IncompatibleVariant,
          profile: profile,
          variant: name,
          processor: processor,
          missing_capabilities: missing,
          declared_capabilities: declared
    end
  end)
  :ok
end
```

**Adopter sees at boot, not at upload time:**

```
** (Rindle.Profile.IncompatibleVariant) Profile MyApp.VideoProfile declares
   variant :hd_mp4 which requires processor capability :video_transcode,
   but processor MyApp.VideoProcessor only declares: [:image_resize].

   To fix:
     1. Verify FFmpeg is installed: `which ffmpeg` (Rindle's video
        processor requires FFmpeg ≥ 4.0 on PATH).
     2. Use a video-capable processor (e.g. Rindle.Processor.Video, post-v1.4).
     3. Remove the :hd_mp4 variant from MyApp.VideoProfile.

   Defining the variant against an image processor is unsupported.

   Variant: :hd_mp4
   Profile: MyApp.VideoProfile
   Processor: MyApp.VideoProcessor
   Required: [:video_transcode]
   Declared: [:image_resize]
```

**Mix task for explicit pre-flight check:**

```bash
mix rindle.doctor MyApp.VideoProfile
# ✓ storage adapter Rindle.Storage.S3 supports [:presigned_put, :multipart_upload, :signed_url, :head]
# ✓ variant :poster_jpg requires [:image_resize, :image_format_convert] — supported by Rindle.Processor.Image
# ✗ variant :hd_mp4 requires [:video_transcode] — NOT supported by any registered processor
#
# 1 issue found. See https://hexdocs.pm/rindle/processors.html
```

### 6.4 Why capabilities, not behaviour-implements checks

Behaviour-implements only tells you a module exists. It does *not* tell
you "FFmpeg is on the PATH" or "Vix.Vips loaded successfully". Capabilities
are a *runtime claim* that the processor itself owns — the processor
checks its own preconditions at boot and amends its `capabilities/0`
return accordingly. This is the same pattern `Rindle.Storage.Local` uses
when claiming `:local` (a real boot-time check that the storage root is
writable could remove `:local` from the capability list, surfacing in
`mix rindle.doctor`).

**Future processor authors:** opt in by implementing `capabilities/0`.
Existing image processor in v1.4 declares `[:image_resize, :image_format_convert,
:image_strip_metadata]` — additive, non-breaking.

---

## 7. Telemetry Events

### 7.1 Existing events

```
[:rindle, :delivery, :signed]   — measurements: %{system_time}; metadata: %{profile, adapter, mode}
```

Plus various processing events emitted by Oban workers.

### 7.2 Convention

Per [Telemetry conventions guide](https://keathley.io/blog/telemetry-conventions.html)
and `:telemetry.span/3` standard:

- Triplet `[..., :start]` + `[..., :stop]` + `[..., :exception]`
- `:start` measurements: `%{system_time, monotonic_time}`
- `:stop`/`:exception` measurements: `%{duration, monotonic_time}` plus
  custom counters
- Metadata is a map; never put high-cardinality data in event names

### 7.3 Locked event vocabulary for v1.4

#### Variant processing (replacing/augmenting current ad-hoc events)

```
[:rindle, :variant, :process, :start]
  measurements: %{system_time, monotonic_time}
  metadata: %{variant_id, asset_id, profile, processor, variant_name,
              source_size_bytes, source_mime}

[:rindle, :variant, :process, :stop]
  measurements: %{duration, monotonic_time, output_size_bytes,
                  frames_processed (optional), audio_samples_processed (optional)}
  metadata: %{variant_id, asset_id, profile, processor, variant_name,
              output_mime}

[:rindle, :variant, :process, :exception]
  measurements: %{duration, monotonic_time}
  metadata: %{variant_id, asset_id, profile, processor, variant_name,
              kind, reason, stacktrace}
```

#### Variant progress (new — fires during long transcodes)

```
[:rindle, :variant, :progress]
  measurements: %{percent (0-100), elapsed_ms, eta_ms,
                  frames_processed (optional), frames_total (optional)}
  metadata: %{variant_id, asset_id, profile, processor, variant_name, stage}

  stage ∈ #{:downloading_source, :transcoding, :uploading_output, :finalizing}
```

This event is emitted *in addition to* the PubSub broadcast (§5.4). PubSub
is for adopter UI; telemetry is for operator dashboards/Prometheus/
APM. **Same metadata, two channels.** Operators can wire the telemetry
event to histograms; adopters can wire the PubSub to LiveView assigns.

#### Delivery (additive to existing event)

```
[:rindle, :delivery, :signed]                       — existing, unchanged
[:rindle, :delivery, :streaming, :resolved]         — new, kind: :progressive | :hls | :dash
[:rindle, :delivery, :range_request]                — new, fires from Rindle.Delivery.LocalPlug
  measurements: %{bytes_served, file_size, system_time}
  metadata: %{key, status (200|206), range_start (optional), range_end (optional)}
```

#### Capability checks

```
[:rindle, :profile, :validate, :start]
[:rindle, :profile, :validate, :stop]
[:rindle, :profile, :validate, :exception]
  metadata: %{profile, missing_capabilities (on exception)}
```

### 7.4 What NOT to emit

- Per-frame progress (would be 30+ Hz; flood telemetry handlers)
- PII/actor identifiers in metadata (use opaque `actor_subject` hash)
- Storage credentials anywhere

### 7.5 PromEx / observability integration

Don't ship a PromEx plugin in v1.4. Document the event names; adopters
who want Prometheus metrics can write a 30-line PromEx plugin. Shipping
one in core couples Rindle to a dashboard tool. Same posture as Phoenix
itself.

---

## 8. Error Message Vocabulary — 8 Locked Variants

### 8.1 Principles

1. **Exception messages must self-explain the fix**, not just the failure.
   "Could not process: `:enoent`" is unhelpful. "Could not process variant
   `:hd_mp4`: source file missing at `/tmp/rindle/abc.mp4`. The asset may
   have been purged before processing started; check for racing delete
   operations." is the bar.
2. **Suggest the next action.** `mix phx.gen` style: tell the user what
   command to run, what config to add.
3. **No `inspect/1` of internal terms in exception messages** — that
   surfaces internal `%Tesla.Env{}` structs and confuses adopters. Tagged
   atoms only; pretty-print the rest.
4. **Reuse the existing `Rindle.Error` exception type**, but expand its
   `message/1` clauses.

### 8.2 The 8 locked variants

#### `:processor_capability_missing`

```elixir
%Rindle.Error{
  action: :declare_variant,
  reason: {:processor_capability_missing,
           %{processor: MyApp.VideoProcessor, required: :video_transcode,
             declared: [:image_resize], variant: :hd_mp4, profile: MyApp.VideoProfile}}
}

# Message:
"""
Variant :hd_mp4 in MyApp.VideoProfile requires processor capability \
:video_transcode, but MyApp.VideoProcessor only declares: [:image_resize].

To fix:
  1. Confirm FFmpeg is installed and on PATH (`which ffmpeg`).
  2. Use a processor that declares :video_transcode.
  3. Or remove :hd_mp4 from the profile's variants/0.

Run `mix rindle.doctor MyApp.VideoProfile` to verify.
"""
```

#### `:ffmpeg_not_found`

```elixir
%Rindle.Error{
  action: :process_variant,
  reason: {:ffmpeg_not_found, %{searched_path: System.get_env("PATH")}}
}

# Message:
"""
FFmpeg executable not found on PATH.

Rindle's video and audio processors require FFmpeg ≥ 4.0. To fix:
  • macOS:        brew install ffmpeg
  • Debian/Ubuntu: apt-get install ffmpeg
  • Alpine/Docker: apk add ffmpeg

If FFmpeg is installed elsewhere, set:
  config :rindle, :ffmpeg_path, "/usr/local/bin/ffmpeg"
"""
```

#### `:variant_source_not_found`

```elixir
%Rindle.Error{
  action: :process_variant,
  reason: {:variant_source_not_found, %{key: "uploads/abc.mp4", asset_id: 42}}
}

# Message:
"""
Source file for asset 42 (storage key "uploads/abc.mp4") could not be \
downloaded from storage.

Likely causes:
  • The asset was purged before variant processing started (race condition
    between detach and the variant worker).
  • The storage adapter credentials lost permission to read the key.
  • The bucket policy blocks GET on this prefix.

Check Oban dashboard for the original ProcessVariant job; if it has been
retrying, the asset may be in a `quarantined` state.
"""
```

#### `:unsupported_codec`

```elixir
%Rindle.Error{
  action: :process_variant,
  reason: {:unsupported_codec,
           %{codec: :av1, processor: Rindle.Processor.Video, supported: [:h264, :vp9, :hevc]}}
}

# Message:
"""
Variant requires codec :av1 but Rindle.Processor.Video only supports: \
[:h264, :vp9, :hevc].

AV1 transcoding requires libaom or SVT-AV1 in your FFmpeg build:
  ffmpeg -codecs 2>&1 | grep av1

If your FFmpeg supports AV1 but Rindle still rejects it, file an issue at
https://github.com/szTheory/rindle/issues with `ffmpeg -version` output.
"""
```

#### `:streaming_not_configured`

```elixir
%Rindle.Error{
  action: :streaming_url,
  reason: {:streaming_not_configured, %{profile: MyApp.VideoProfile, requested_kind: :hls}}
}

# Message:
"""
MyApp.VideoProfile is not configured with a streaming provider, but :hls \
streaming was requested.

In Rindle v1.4, only :progressive (signed-redirect MP4/WebM) is supported \
out of the box. To use HLS:
  1. Wait for the Rindle.Streaming.Mux or Rindle.Streaming.Cloudflare
     adapter (post-v1.4).
  2. Or configure your profile with a custom streaming provider:

     use Rindle.Profile,
       storage:   Rindle.Storage.S3,
       streaming: MyApp.MyStreamingProvider

Until then, callers should use Rindle.Delivery.url/3 for progressive playback.
"""
```

#### `:variant_processing_cancelled`

```elixir
%Rindle.Error{
  action: :process_variant,
  reason: {:variant_processing_cancelled,
           %{variant_id: id, cancelled_at: ts, reason: :user_cancelled}}
}

# Message:
"""
Variant processing was cancelled (reason: user_cancelled, at: 2026-05-02 \
14:23:11Z).

This is expected when Rindle.cancel_processing/1 is called. The variant \
will not retry; re-trigger with Rindle.regenerate_variant/2 if needed.
"""
```

#### `:range_unparseable`

```elixir
%Rindle.Error{
  action: :serve_range,
  reason: {:range_unparseable, %{header: "bytes=abc-xyz"}}
}

# Logged but NOT raised — the Plug falls back to 200 + full body per
# RFC 7233 graceful-degradation. This error is emitted via Logger.warning
# and telemetry, not raised. Adopters who want strict mode opt-in via
# config :rindle, :strict_range_parsing, true (off by default).
```

#### `:capability_drift`

```elixir
%Rindle.Error{
  action: :validate_profile,
  reason: {:capability_drift,
           %{adapter: MyApp.MyStorage,
             previously: [:presigned_put, :head, :signed_url, :multipart_upload],
             now: [:presigned_put, :head, :signed_url],
             missing: [:multipart_upload]}}
}

# Message:
"""
Storage adapter MyApp.MyStorage previously advertised capability \
:multipart_upload but now does not.

This may indicate:
  • The adapter is misconfigured (e.g. credentials lost permission to
    initiate multipart uploads).
  • The provider has changed (e.g. Cloudflare R2 multipart compatibility
    is provider-version-sensitive — see Rindle's R2 docs).
  • A code change removed the capability.

To proceed, either:
  1. Restore the adapter's capability (check provider config / credentials).
  2. Migrate existing in-flight multipart uploads with `mix rindle.cleanup
     --multipart-orphans`.
  3. Drop the capability requirement from your profile.
"""
```

### 8.3 Why exactly these eight

These 8 cover the `cartesian product` of (high-frequency adopter mistake) ×
(high-cost-to-debug-without-good-message). Three of them (`:processor_capability_missing`,
`:ffmpeg_not_found`, `:capability_drift`) fire at boot/static-analysis time —
adopters never reach production with a broken setup. Three of them
(`:variant_source_not_found`, `:unsupported_codec`, `:streaming_not_configured`)
fire at runtime but are *deterministic* given the configuration —
documenting the cause maps directly to the fix. The last two cover graceful
operational situations (`:variant_processing_cancelled`, `:range_unparseable`)
where silence would be confusing.

### 8.4 Implementation note

Extend `Rindle.Error.message/1` with new clauses; don't introduce new
exception types. Adopters' rescue clauses already match `Rindle.Error`;
new variants slot in transparently.

---

## 9. Open Questions Worth Escalating

Per the user's escalation criteria (only VERY impactful — public API,
semver, destructive, security, cost, scope), exactly **two** questions
warrant a synchronous decision before v1.4 design locks:

### 9.1 SEMVER: Should `Rindle.Delivery.streaming_url/3` ship in v1.4 even though it's a no-op?

**Why escalate:** This is a *public API addition* that v1.4 commits to
forever (or breaks semver to remove). The function is a no-op delegate to
`url/3` in v1.4. Two options:

- **A (recommended in §3):** Ship it. Adopter video templates calling
  `streaming_url/3` will work unchanged when Mux adapter ships post-v1.4.
  No template churn. Cost: extra public function whose value is invisible
  in v1.4.
- **B:** Don't ship it. Adopters call `url/3` for v1.4 video, then migrate
  to `streaming_url/3` when Mux adapter lands. Cost: documented breaking
  change for HLS adopters in v2.0.

Recommendation A is in this document. Confirming because shipping a
public API surface that does nothing in its first release is unusual and
worth the maintainer's explicit blessing.

### 9.2 SCOPE: Should `Rindle.Delivery.LocalPlug` ship in core v1.4, or be a separate `rindle_dev_plug` package?

**Why escalate:** This is the only piece of v1.4 that touches Plug request/
response handling and parses HTTP headers. Once shipped in core, range-
parsing bugs become security-relevant CVEs against Rindle proper. The
boundary question:

- **A (recommended in §2.4):** Ship in core, mounted opt-in. ~80 LoC.
  Documented as dev-only. Maintains "Rindle works out of the box for new
  Phoenix adopters with local storage."
- **B:** Ship as separate `rindle_dev_plug` package. Adopters add one more
  dep. Core stays minimal. Reduces v1.4 attack surface.

Recommendation A is in this document because the friction of adding a
second package for the dev path will surprise new adopters. But B is the
more conservative move and a maintainer with strong "minimal core" taste
might prefer it.

---

## Sources

### Active Storage / Rails
- [Rails Active Storage Overview (edge guides)](https://edgeguides.rubyonrails.org/active_storage_overview.html)
- [ActiveStorage::DiskController API](https://api.rubyonrails.org/classes/ActiveStorage/DiskController.html)
- [Rails issue #32193 — DiskController doesn't support HTTP range](https://github.com/rails/rails/issues/32193)
- [Rails PR #41437 — Added Active Storage support for byte ranges](https://github.com/rails/rails/pull/41437)
- [Rails 7 ActiveStorage::Streaming (Kiprosh blog)](https://blog.kiprosh.com/rails-7-active-storage-streaming/)
- [Rails 7 adds direct ActiveStorage::Streaming support (Saeloun)](https://blog.saeloun.com/2021/03/24/rails-adds-active-storage-streaming/)
- [Rails 7.1 audio_tag/video_tag accept Active Storage attachments (BigBinary)](https://www.bigbinary.com/blog/rails-7-extends-support-for-audio-tag-and-video-tag)
- [Drifting Ruby — Streaming Videos with Active Storage](https://www.driftingruby.com/episodes/streaming-videos-with-active-storage)
- [Drifting Ruby — Adaptive Bitrate Streaming with Active Storage](https://www.driftingruby.com/episodes/adaptive-bitrate-streaming-with-active-storage)
- [Video streaming using Rails and NGINX (Medium)](https://medium.com/@themastercado/video-streaming-using-rails-and-nginx-70df2b80174b)
- [ActiveStorage::Attachment API (7.1)](https://api.rubyonrails.org/v7.1/classes/ActiveStorage/Attachment.html)
- [Rails AssetTagHelper — video_tag (apidock)](https://apidock.com/rails/ActionView/Helpers/AssetTagHelper/video_tag)
- [Rails AssetTagHelper — audio_tag (apidock)](https://apidock.com/rails/ActionView/Helpers/AssetTagHelper/audio_tag)

### Shrine
- [Shrine Derivation Endpoint plugin](https://shrinerb.com/docs/plugins/derivation_endpoint)
- [Shrine derivation_endpoint source](https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/derivation_endpoint.rb)
- [Shrine PR #342 — Add derivation_endpoint plugin](https://github.com/shrinerb/shrine/pull/342)

### Cloudflare Stream / Mux / Cloudinary
- [Cloudflare Stream — Securing your stream](https://developers.cloudflare.com/stream/viewing-videos/securing-your-stream/)
- [Cloudflare Stream API — Create Signed URL Tokens](https://developers.cloudflare.com/api/resources/stream/subresources/token/methods/create/)
- [Mux — Securing Video Playback with Signed URLs](https://www.mux.com/articles/securing-video-playback-with-signed-urls)
- [Mux — Video Streaming API Guide 2025](https://www.mux.com/articles/video-streaming-api-how-to-build-live-and-on-demand-video-into-your-app)
- [Cloudinary cl_video_tag source](https://github.com/cloudinary/cloudinary_gem/blob/master/lib/cloudinary/video_helper.rb)
- [Cloudinary Video Manipulation docs](https://cloudinary.com/documentation/video_manipulation_and_delivery)

### Spatie Laravel Media Library / imgproxy
- [Spatie Media Library — Defining conversions](https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions)
- [Spatie Media Library — Image generators (PDF/video)](https://spatie.be/docs/laravel-medialibrary/v11/converting-other-file-types/using-image-generators)
- [imgproxy — Signing a URL](https://docs.imgproxy.net/usage/signing_url)
- [imgproxy — Processing an image](https://docs.imgproxy.net/usage/processing?id=signature)

### Phoenix LiveView / Plug / Elixir
- [Phoenix LiveView Uploads (v1.1.28)](https://hexdocs.pm/phoenix_live_view/uploads.html)
- [Phoenix LiveView External Uploads (v1.1.28)](https://hexdocs.pm/phoenix_live_view/external-uploads.html)
- [Phoenix.LiveView.UploadWriter docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.UploadWriter.html)
- [Streaming Uploads with LiveView (Fly.io)](https://fly.io/phoenix-files/streaming-uploads-with-liveview/)
- [Live Streaming with LiveView and Mux (DockYard)](https://dockyard.com/blog/2020/09/25/live-streaming-with-liveview-and-mux-in-under-70-lines-of-code)
- [Video Uploads with Phoenix LiveView and Mux (Marcel Fahle)](https://marcelfahle.net/posts/2022-12-17-mux-uploads/)
- [Record Video and Upload with Phoenix LiveView Hooks (gusworkman)](https://gusworkman.com/blog/record-and-upload-media-in-phoenix-liveview)
- [Plug.Conn docs (v1.19.1)](https://hexdocs.pm/plug/Plug.Conn.html)
- [Plug.Conn.Status — partial_content (206)](https://hexdocs.pm/plug/Plug.Conn.Status.html)
- [Plug PR #526 — Range request support in Plug.Static](https://github.com/elixir-plug/plug/pull/526)
- [Plug issue #523 — Support for HTTP 1.1 range requests](https://github.com/elixir-plug/plug/issues/523)
- [Plug issue #492 — Streaming response body](https://github.com/elixir-plug/plug/issues/492)
- [plug_cowboy issue #10 — chunk/2 needs backpressure](https://github.com/elixir-plug/plug_cowboy/issues/10)
- [Lucas Sifoni — Deep dive Plug.Conn.send_file](https://lucassifoni.info/blog/deep-dive-plug-conn-send-file/)

### Phoenix.HTML
- [Phoenix.HTML v4.3.0 docs](https://hexdocs.pm/phoenix_html/Phoenix.HTML.html)
- [Phoenix.HTML changelog](https://github.com/phoenixframework/phoenix_html/blob/main/CHANGELOG.md)
- [PhoenixHTMLHelpers.Tag](https://hexdocs.pm/phoenix_html_helpers/PhoenixHTMLHelpers.Tag.html)

### Telemetry / Oban / Membrane
- [Telemetry conventions (Keathley)](https://keathley.io/blog/telemetry-conventions.html)
- [Telemetry hexdocs](https://hexdocs.pm/telemetry/readme.html)
- [Membrane.Telemetry docs (Membrane Core 1.2.2)](https://hexdocs.pm/membrane_core/Membrane.Telemetry.html)
- [Oban.Telemetry docs (v2.20.3)](https://hexdocs.pm/oban/Oban.Telemetry.html)
- [Phoenix LiveView + Oban real-time monitoring (Hex Shift)](https://dev.to/hexshift/phoenix-liveview-meets-oban-real-time-interfaces-powered-by-background-jobs-30ka)
- [The Magic of Phoenix LiveView and PubSub](https://experimentingwithcode.com/the-magic-of-phoenix-liveview-and-pubsub/)

### FFmpeg / Streaming protocols
- [FFmpeg documentation](https://www.ffmpeg.org/ffmpeg.html)
- [FFmpex hexdocs](https://hexdocs.pm/ffmpex/FFmpex.html)
- [HLS vs DASH (Mux)](https://www.mux.com/articles/hls-vs-dash-what-s-the-difference-between-the-video-streaming-protocols)
- [How to Serve HLS Video from S3](https://hlsbook.net/how-to-serve-hls-video-from-an-s3-bucket/)
- [Web.dev — Fast playback with audio and video preload](https://web.dev/fast-playback-with-preload/)
- [Surma — `<video>`, HTTP range requests & WHATWG streams](https://surma.dev/things/range-requests/)
- [Smoores — Serving Video with HTTP Range Requests](https://smoores.dev/post/http_range_requests/)

### Accessibility / WebVTT
- [W3C WCAG 2.1 H95 — track element for captions](https://www.w3.org/WAI/WCAG21/Techniques/html/H95.html)
- [WebVTT Format spec](https://www.w3.org/TR/webvtt1/)
- [MDN — WebVTT API](https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API)

### BEAM / Performance
- [The Perils of Large Files in Elixir (Nutrient)](https://pspdfkit.com/blog/2021/the-perils-of-large-files-in-elixir/)
- [The BEAM Book](https://blog.stenmans.org/theBeamBook/)
