# Rindle v1.4 — Domain Model & Lifecycle Surface for Video + Audio

**Research date:** 2026-05-02
**Question:** What is the right domain model + lifecycle surface for adding video and audio to Rindle in v1.4?
**Confidence:** HIGH (cross-language peer-library evidence + concrete Elixir/Ecto sketches)

---

## 1. TL;DR — Locked Recommendation

**Keep one `media_assets` table and one `media_variants` table. Add a non-null `kind`
column (`:image | :video | :audio`) defaulting to `:image` for existing rows.
Promote operator-queryable probe fields (`duration_ms`, `width`, `height`,
`has_video_track`, `has_audio_track`) to first-class typed columns; keep
codec/bitrate/container/tags in `metadata` JSONB. Variants stay first-class DB
records but gain an `output_kind` column so cross-kind derivatives
(video → poster image, video → audio extraction, audio → waveform image) are
plain rows, not special cases. Replace the `Rindle.Profile` flat variant map with
a `kind`-discriminated variant entry validated by NimbleOptions; add a
`Rindle.Probe` behaviour mirroring `Rindle.Processor`. Extend the asset FSM with
a `transcoding` state (long-running, snooze-friendly) and split `analyzing` into
`analyzing_meta` (cheap probe) + `analyzing_transcode_plan` (optional). All
existing image adopters continue to work because the new columns are nullable
or have defaults, and image-only profile DSL stays valid.**

This mirrors the *winning* model used by Active Storage (one `Blob`, polymorphic
attachments, `kind`-style routing of analyzers and previewers) and Shrine
(uploaders per kind with shared derivatives format), while avoiding Paperclip's
table-bloat trap and Cloudinary's split `resource_type` API surface that forces
callers to pre-know media kind on every request.

---

## 2. Media Kind Taxonomy

### 2.1 What peer libraries do

| Library | Model | Trade-off |
|---|---|---|
| **Active Storage** ([VideoAnalyzer](https://api.rubyonrails.org/classes/ActiveStorage/Analyzer/VideoAnalyzer.html)) | One `ActiveStorage::Blob` table; analyzers register polymorphically and `accept?` the blob; previewers and variants dispatch by content-type | **RIGHT**: single table = simple migrations, queries cross all media. **WRONG**: variant vs preview is a leaky abstraction (`representation` collapses them). |
| **Shrine** ([uploaders](https://shrinerb.com/docs/advantages)) | One `Shrine` superclass; each *attachment* has a custom uploader subclass (`VideoUploader`, `ImageUploader`); derivatives stored in `<attachment>_data` JSONB column | **RIGHT**: per-kind validation ergonomics; **WRONG**: schema is a JSON blob, no SQL queryability — "find all videos > 10min" is hard. |
| **Spatie Media Library** ([video conversions](https://spatie.be/docs/laravel-medialibrary/v11/converting-other-file-types/using-image-generators)) | One `media` table; conversions are per-attachment image generators dispatched by MIME | **RIGHT**: zero ceremony; **WRONG**: video conversions are conceptually still "image generators" (poster only) — no native video output. |
| **Paperclip + paperclip-av-transcoder** ([repo](https://github.com/ruby-av/paperclip-av-transcoder)) | Per-attachment processors; metadata stored in optional `<attachment>_meta` JSON column | **WRONG**: deprecated; the metadata-as-blob pattern produced unqueryable telemetry that operators routinely complained about. |
| **CarrierWave + carrierwave-video** ([repo](https://github.com/rheaton/carrierwave-video)) | Versions DSL produces files; no schema for derivatives at all | **WRONG**: derivatives are inferred from filename conventions — no first-class records, breaks Day-2 ops. |
| **Cloudinary** ([upload API](https://cloudinary.com/documentation/image_upload_api_reference)) | API-level discriminator: `resource_type: image \| video \| raw`; **video covers both video AND audio** | **RIGHT**: discriminator forces explicit choice; **WRONG**: lumping audio under video is the wrong shape — duration semantics share, but display semantics don't. |
| **django-video-encoding** ([README](https://github.com/escaped/django-video-encoding)) | Separate `Format` model with `GenericRelation`; one row per encoded variant | **RIGHT**: variants are first-class queryable rows; **WRONG**: separate `Video` model from arbitrary attachments forces user to subclass. |

### 2.2 Tradeoff table

| Option | DB shape | Pattern-match in Elixir | Backward compat | Queryability | Complexity |
|---|---|---|---|---|---|
| **A. Single `media_assets` + `kind` enum + first-class probe columns** (LOCKED) | One table; `kind`, `duration_ms`, `width`, `height`, `has_video_track`, `has_audio_track` typed; codec/bitrate/tags in JSONB `metadata` | `case asset.kind do :image -> ...; :video -> ...; :audio -> ... end` — clean, exhaustive | New columns nullable; existing rows backfilled `:image`; no breakage | SQL-native: `WHERE kind = 'video' AND duration_ms > 600_000` | Low |
| B. Polymorphic via `ecto_discriminator` (separate schemas, shared base) | One table, multiple Ecto schema modules dispatching on type column | Per-schema modules feel familiar but require changeset duplication | Adds `type` column with default; works | Same as A | Medium — extra dep, splits docs across modules |
| C. Separate `image_assets` / `video_assets` / `audio_assets` tables | Three tables, three FSMs | No — every cross-kind operation needs three branches | Hard — forces image data migration | Hard — UNION queries, no single index | High |
| D. JSONB-only metadata blob (Shrine-style) | Single table, all probe data in `metadata` map | Pattern matching on map keys is fragile | Easy | Poor — every operator query is JSON path | Low to add, high in practice |

**LOCKED: Option A.** Reasons:

1. **Elixir's strength is exhaustive pattern matching on atoms.** A `kind` field
   typed as `Ecto.Enum` produces exactly the case-clause-warning safety net
   adopters expect.
2. **Operator queryability is in our security invariants** ("Missing/stale/failed
   variant states are visible, queryable, and actionable" — `PROJECT.md` line 151).
   JSONB-only loses this for video duration / track presence, which are the most
   common admin queries.
3. **Active Storage validates the single-table approach at scale.** Rails has
   shipped this for ~7 years across Image/Video/Audio/PDF without splitting tables.
4. **No additional dependencies.** `ecto_discriminator` and `polymorphic_embed`
   are mature but optional — option A delivers the value with vanilla Ecto.

### 2.3 Ecto schema sketch (changeset-friendly)

```elixir
defmodule Rindle.Domain.MediaAsset do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @kinds [:image, :video, :audio]
  @states [
    "staged", "validating", "analyzing",
    "promoting", "available",
    "transcoding",            # NEW — long-running variant work
    "processing",             # cheap variant work (image-style)
    "ready", "degraded",
    "quarantined", "deleted"
  ]

  schema "media_assets" do
    # === existing fields (unchanged) ===
    field :state, :string, default: "staged"
    field :storage_key, :string
    field :content_type, :string
    field :byte_size, :integer
    field :filename, :string
    field :recipe_digest, :string
    field :profile, :string

    # === NEW: kind discriminator ===
    field :kind, Ecto.Enum, values: @kinds, default: :image

    # === NEW: first-class probe columns (operator-queryable) ===
    field :width, :integer                  # px (image, video)
    field :height, :integer                 # px (image, video)
    field :duration_ms, :integer            # ms (video, audio)
    field :has_video_track, :boolean        # video only; nil for image/audio
    field :has_audio_track, :boolean        # video; bool for audio is always true

    # === remaining metadata stays in JSONB (codec, bitrate, tags, container, etc.) ===
    field :metadata, :map, default: %{}

    has_many :attachments, Rindle.Domain.MediaAttachment, foreign_key: :asset_id
    has_many :variants, Rindle.Domain.MediaVariant, foreign_key: :asset_id
    has_many :upload_sessions, Rindle.Domain.MediaUploadSession, foreign_key: :asset_id
    has_many :processing_runs, Rindle.Domain.MediaProcessingRun, foreign_key: :asset_id

    timestamps()
  end

  @cast_fields ~w(
    state storage_key content_type byte_size filename
    metadata recipe_digest profile kind
    width height duration_ms has_video_track has_audio_track
  )a

  def changeset(asset, attrs) do
    asset
    |> cast(attrs, @cast_fields)
    |> validate_required([:state, :storage_key, :profile, :kind])
    |> validate_inclusion(:state, @states)
    |> validate_kind_consistency()    # NEW — see below
    |> unique_constraint(:storage_key)
  end

  # Reject impossible combinations early, e.g. width on audio,
  # duration_ms on image, has_video_track set when kind == :audio.
  defp validate_kind_consistency(cs) do
    case get_field(cs, :kind) do
      :image ->
        cs
        |> reject_field(:duration_ms, "not allowed on image")
        |> reject_field(:has_video_track, "not allowed on image")
        |> reject_field(:has_audio_track, "not allowed on image")
      :audio ->
        cs
        |> reject_field(:width, "not allowed on audio")
        |> reject_field(:height, "not allowed on audio")
        |> reject_field(:has_video_track, "not allowed on audio")
      :video ->
        cs   # all probe fields allowed
      _ ->
        cs
    end
  end

  defp reject_field(cs, field, msg) do
    if is_nil(get_field(cs, field)), do: cs, else: add_error(cs, field, msg)
  end
end
```

**Why typed columns for these five?** They are the *queryable* fields. Operators
will always want: "videos longer than X", "assets with audio", "images in this
size range". They are also schema-stable across all probe backends (FFprobe,
libvips, libavformat). Codec, bitrate, tags, container, and frame rate stay in
`metadata` because they are diagnostic, not filterable in a typical admin
workflow, and their canonical names differ across probes.

---

## 3. Variant / Derivative Semantics

### 3.1 Lessons from peers

**Active Storage** ([Representable](https://api.rubyonrails.org/classes/ActiveStorage/Blob/Representable.html)):
splits the world into `variant` (image transforms) and `preview` (image extracted
from a non-image source). The unified `representation` method picks the right
one. **RIGHT**: separates "transform same kind" from "extract different kind".
**WRONG**: callers still have to know about both via `previewable?` /
`representable?` predicates — this leaks.

**Shrine** ([derivatives plugin](https://shrinerb.com/docs/plugins/derivatives)):
all derivatives are a flat hash in JSONB, regardless of output kind. Cross-kind
derivatives just have different filenames. **RIGHT**: uniform model, no special
case for posters. **WRONG**: stored as JSON blob → no `WHERE name='poster' AND
state='ready'` queries; rebuild-detection is a JSON diff, not row-level
`stale → queued`.

**django-video-encoding** ([Format model](https://github.com/escaped/django-video-encoding)):
each encoded format is a separate row with its own conversion result enum.
**RIGHT**: queryable, observable, retryable per-format — exactly what Rindle's
existing `MediaVariant` already does for images.

**Spatie Media Library** ([Video.php image generator](https://github.com/spatie/laravel-medialibrary/blob/main/src/Conversions/ImageGenerators/Video.php)):
the `Video` class is registered as an *image generator* — i.e., its only output
is a poster JPEG. **WRONG**: there is no model for "give me an mp4 transcode of
this video" — you'd need a separate plugin. Don't repeat this.

**ActiveEncode** ([gem](https://www.ruby-toolbox.com/projects/active_encode)):
abstracts FFmpeg, Elastic Transcoder, MediaConvert behind one interface.
**RIGHT**: pluggable encoder backend; **WRONG**: separate from Active Storage —
two mental models for the same asset.

### 3.2 Locked design — one variant table, `output_kind` column

Rindle's existing `MediaVariant` already nails what django-video-encoding got
right: each derivative is a queryable row with its own state. We extend it
with one column: `output_kind`, which can differ from the parent asset's `kind`.

```elixir
defmodule Rindle.Domain.MediaVariant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @output_kinds [:image, :video, :audio, :waveform]   # waveform = image-derived-from-audio
  @states ["planned", "queued", "processing", "ready",
           "stale", "missing", "failed", "purged"]

  schema "media_variants" do
    field :name, :string
    field :state, :string, default: "planned"
    field :recipe_digest, :string
    field :storage_key, :string
    field :byte_size, :integer
    field :content_type, :string
    field :error_reason, :string
    field :generated_at, :utc_datetime_usec

    # === NEW ===
    field :output_kind, Ecto.Enum, values: @output_kinds
    field :duration_ms, :integer        # for :video and :audio outputs
    field :width, :integer              # for :image, :video, :waveform
    field :height, :integer

    belongs_to :asset, Rindle.Domain.MediaAsset

    timestamps()
  end

  def changeset(variant, attrs) do
    variant
    |> cast(attrs, ~w(asset_id name state recipe_digest storage_key byte_size
        content_type error_reason generated_at output_kind
        duration_ms width height)a)
    |> validate_required([:asset_id, :name, :state, :recipe_digest, :output_kind])
    |> validate_inclusion(:state, @states)
    |> foreign_key_constraint(:asset_id)
    |> unique_constraint([:asset_id, :name])
  end
end
```

**Why `output_kind` and not infer from `content_type`?** Because operator
queries should be cheap — `WHERE output_kind = :image AND state = 'ready'` is a
B-tree hit. Parsing MIME types in WHERE clauses isn't.

**Why a `:waveform` value distinct from `:image`?** Waveforms are images, but
their *recipe* is fundamentally different (samples-per-pixel, peaks file vs PNG)
and operators routinely ask "regenerate just the waveforms". A separate enum
value lets that query stay one-line. Cost: one more enum value.

### 3.3 Cross-kind derivative table (concrete examples)

| Source asset `kind` | Variant `name` | Variant `output_kind` | Recipe |
|---|---|---|---|
| `:image` | `:thumb` | `:image` | resize 128×128, webp |
| `:image` | `:large` | `:image` | resize 1920×1080, jpeg |
| `:video` | `:web_mp4` | `:video` | h264/aac, 720p, fragmented |
| `:video` | `:poster` | `:image` | first scene-detected frame, jpeg |
| `:video` | `:thumbstrip` | `:image` | sprite sheet of 10 frames |
| `:video` | `:audio_only` | `:audio` | extract audio track, m4a |
| `:audio` | `:web_mp3` | `:audio` | mp3 192kbps |
| `:audio` | `:waveform_png` | `:waveform` | bbc/audiowaveform → png |

Each is one row in `media_variants` with its own state, recipe digest, retry
budget, and storage key. No special-case preview/representation distinction —
the variant *is* the unit of work, regardless of output kind.

### 3.4 What this gets right that peers miss

- **Shrine's flat-derivatives hash collapses across-kind work into JSON keys.**
  Rindle keeps it as rows so `Rindle.Repo.aggregate(MediaVariant, :count, :id,
  state: "failed", output_kind: :video)` is a one-line health query.
- **Active Storage's variant/preview distinction forces callers into two APIs.**
  Rindle's `Rindle.url(asset, :poster)` returns a signed URL the same way
  `Rindle.url(asset, :thumb)` does — adopters never care that one came from a
  cross-kind derivative.
- **CarrierWave's filename-based versions break invariants when storage moves.**
  Variants as rows survive any storage migration.

---

## 4. Probe / Analyze Step

### 4.1 What peers extract

| Library | Image probe | Video probe | Audio probe |
|---|---|---|---|
| **Active Storage** | width, height (libvips/MiniMagick) | width, height, **duration**, angle, display_aspect_ratio, **audio:bool**, **video:bool** ([VideoAnalyzer](https://api.rubyonrails.org/classes/ActiveStorage/Analyzer/VideoAnalyzer.html)) | duration, bit_rate, sample_rate, tags ([AudioAnalyzer](https://edgeapi.rubyonrails.org/classes/ActiveStorage/Analyzer/AudioAnalyzer.html)) |
| **Shrine `add_metadata`** ([metadata.md](https://github.com/shrinerb/shrine/blob/master/doc/metadata.md)) | mime, size; user-defined extras | duration, bitrate, resolution, frame_rate (via streamio-ffmpeg) | duration, sample_rate, channels |
| **FFprobe** ([docs](https://ffmpeg.org/ffprobe.html)) | n/a | full streams + format JSON | full streams + format JSON |
| **django-video-encoding** | n/a | width, height, duration on Video model | n/a |

### 4.2 Locked schema (typed + JSONB hybrid)

**First-class typed columns on `media_assets`** (queryable, stable across probes):

| Column | Type | Image | Video | Audio |
|---|---|---|---|---|
| `width` | integer | px | px | nil |
| `height` | integer | px | px | nil |
| `duration_ms` | integer | nil | ms | ms |
| `has_video_track` | boolean | nil | true/false | nil |
| `has_audio_track` | boolean | nil | true/false | always true |

**JSONB `metadata` map** (diagnostic, varies by probe):

```elixir
%{
  "container" => "mov",
  "video" => %{
    "codec" => "h264",
    "bitrate" => 2_400_000,
    "frame_rate" => 29.97,
    "pix_fmt" => "yuv420p",
    "rotation" => 0
  },
  "audio" => %{
    "codec" => "aac",
    "sample_rate" => 48_000,
    "channels" => 2,
    "bitrate" => 128_000
  },
  "tags" => %{"encoder" => "Lavc60.31.102", "creation_time" => "2025-..."},
  "probe_version" => "ffprobe-6.0",
  "probed_at" => "2026-05-02T10:42:00Z"
}
```

### 4.3 `Rindle.Probe` behaviour — symmetric with `Rindle.Processor`

```elixir
defmodule Rindle.Probe do
  @moduledoc """
  Behaviour contract for probing a source file to extract metadata.

  Implementations must be read-only on the source path and must return a map
  shaped like `Rindle.Probe.Result.t/0`. Probing happens before
  promote-and-attach, so it MUST be cheap and bounded.
  """

  @type result :: %{
    required(:kind) => :image | :video | :audio,
    optional(:width) => pos_integer(),
    optional(:height) => pos_integer(),
    optional(:duration_ms) => pos_integer(),
    optional(:has_video_track) => boolean(),
    optional(:has_audio_track) => boolean(),
    optional(:metadata) => map()
  }

  @callback probe(source :: Path.t()) :: {:ok, result()} | {:error, term()}
  @callback accepts?(content_type :: String.t()) :: boolean()
end
```

**Why a behaviour, not a function?** Symmetric with `Rindle.Processor` — adopters
who use a non-FFmpeg backend (Membrane, AWS MediaInfo, custom NIF) implement
the same callback. Active Storage's `accept?` registry is the proven pattern;
we copy it.

**Recommended bundled adapters (parallel to `Rindle.Storage.S3` /
`Rindle.Processor.Image`):**

- `Rindle.Probe.Image` — uses existing `Image`/Vix; extracts `width`, `height`,
  basic EXIF
- `Rindle.Probe.AVProbe` — FFprobe via [FFmpex](https://hex.pm/packages/ffmpex);
  extracts everything for video/audio. Optional dep; runtime check on first use.

**Probe output is bounded.** Like Active Storage's analyzer registry, a probe
that times out or returns ambiguous results sends the asset to `quarantined`
with `error_reason` set — never to `available`. This matches the existing
`Mime.detect` failure path.

### 4.4 What we get right vs Active Storage

- Active Storage's video analyzer **doesn't return codec or bitrate** ([source
  field list](https://api.rubyonrails.org/classes/ActiveStorage/Analyzer/VideoAnalyzer.html))
  — operators routinely vendor-patch to add it. We capture them in `metadata`
  by default.
- Active Storage stores `duration` as float seconds with float-rounding
  surprises. We store `duration_ms` as integer — exact, sortable, no
  serialization edge cases.
- Active Storage analysis is *post*-attach (lazy `analyze_later`). Rindle's
  existing FSM puts probe between `validating` and `promoting`, so the asset is
  never `available` with missing core metadata — matches our security
  invariant 7.

---

## 5. Profile DSL Extension

### 5.1 Constraints from current code

`Rindle.Profile.Validator` validates one flat variant schema (`mode`, `width`,
`height`, `format`, `quality`). Every variant entry shares this shape — that's
the assumption v1.4 must break carefully.

### 5.2 Idiomatic Elixir DSL choice

Looking at peer Elixir DSLs:

| DSL | Discrimination strategy |
|---|---|
| Phoenix.Component (`attr :kind, :atom, values: [...]`) | Required field with `values` constraint |
| Absinthe (`field :name, :type`) | Type system carries the discriminator |
| Ecto schema (`field :tag, Ecto.Enum, values: [...]`) | Same — typed enum |
| LiveView macros (`live_session`) | Block-style with kind-specific options |
| NimbleOptions ([docs](https://hexdocs.pm/nimble_options)) | Nested schemas via `:keys` per kind |

**LOCKED: same flat keyword/map syntax adopters already use, with required
`:kind` discriminator and per-kind nested `NimbleOptions` schemas.** The user
writes one map per variant; the validator branches on `:kind`. No new macro
shape, no new module split — same `use Rindle.Profile, ...` everywhere.

Why not separate `image_variant`/`video_variant` macros? Two reasons:

1. **Adopter mental model: one DSL, not three.** The whole point of media-kind
   agnosticism (PROJECT.md key decision row 1) is that adopters declare profiles
   uniformly.
2. **NimbleOptions already supports discriminated nested schemas.** Per-kind
   schemas via `:keys` is the idiomatic Elixir form. No need to invent macros.

### 5.3 Concrete example

```elixir
defmodule MyApp.HeroVideoProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 2_000_000_000,             # 2 GB
    delivery: %{public: false, signed_url_ttl_seconds: 1800},
    variants: %{
      web_mp4: %{
        kind: :video,
        processor: Rindle.Processor.AV,
        container: :mp4,
        video: %{codec: :h264, max_height: 720, bitrate: "2400k"},
        audio: %{codec: :aac, bitrate: "128k"}
      },
      poster: %{
        kind: :image,
        processor: Rindle.Processor.AV,    # poster comes from video probe
        source: :video_frame,              # tells processor to grab a frame
        at_seconds: :scene_detect,         # or e.g. 2.5
        width: 1920, height: 1080, mode: :fit, format: :jpeg, quality: 85
      },
      thumbstrip: %{
        kind: :image,
        processor: Rindle.Processor.AV,
        source: :video_sprite,
        frame_count: 10,
        width: 320, height: 180, format: :webp
      },
      audio_only: %{
        kind: :audio,
        processor: Rindle.Processor.AV,
        container: :m4a,
        audio: %{codec: :aac, bitrate: "192k"}
      }
    }
end
```

```elixir
defmodule MyApp.PodcastProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    allow_mime: ["audio/mpeg", "audio/mp4", "audio/wav", "audio/flac"],
    max_bytes: 500_000_000,
    delivery: %{public: false, signed_url_ttl_seconds: 1800},
    variants: %{
      web_mp3: %{
        kind: :audio,
        processor: Rindle.Processor.AV,
        container: :mp3,
        audio: %{codec: :mp3, bitrate: "192k"}
      },
      waveform: %{
        kind: :waveform,
        processor: Rindle.Processor.Waveform,    # bbc/audiowaveform binary
        width: 1200, height: 240,
        background: "#0e0e0e", color: "#ffffff",
        format: :png
      }
    }
end
```

### 5.4 Validator changes (minimal, additive)

Existing `@variant_schema` in `lib/rindle/profile/validator.ex` becomes the
`:image` schema; new schemas added per-kind. The top-level NimbleOptions schema
gains required `:kind` and dispatches:

```elixir
@image_variant_schema [
  mode: [type: {:in, [:fit, :fill, :crop]}, required: true],
  width: [type: {:or, [:pos_integer, nil]}, default: nil],
  height: [type: {:or, [:pos_integer, nil]}, default: nil],
  format: [type: {:in, [:jpeg, :png, :webp, :avif]}, default: :jpeg],
  quality: [type: {:or, [{:in, 1..100}, nil]}, default: nil]
]

@video_variant_schema [
  container: [type: {:in, [:mp4, :webm, :mov]}, default: :mp4],
  source: [type: {:in, [:original, :video_frame, :video_sprite]}, default: :original],
  at_seconds: [type: {:or, [:pos_integer, :float, {:in, [:scene_detect]}]}, default: 0],
  frame_count: [type: :pos_integer, default: 1],
  video: [type: :keyword_list, default: []],   # nested schema: codec, max_height, bitrate
  audio: [type: :keyword_list, default: []],
  width: [type: {:or, [:pos_integer, nil]}, default: nil],
  height: [type: {:or, [:pos_integer, nil]}, default: nil],
  format: [type: :atom, default: :jpeg]        # only used when source: :video_frame/:video_sprite
]

@audio_variant_schema [
  container: [type: {:in, [:mp3, :m4a, :ogg, :wav]}, default: :mp3],
  audio: [type: :keyword_list, default: []]    # nested: codec, bitrate, sample_rate, channels
]

@waveform_variant_schema [
  width: [type: :pos_integer, required: true],
  height: [type: :pos_integer, required: true],
  background: [type: :string, default: "#000000"],
  color: [type: :string, default: "#ffffff"],
  format: [type: {:in, [:png, :svg, :json]}, default: :png]
]

defp validate_variant!(name, %{kind: :image} = opts), do:
  validate_against(name, opts, @image_variant_schema, :image)
defp validate_variant!(name, %{kind: :video} = opts), do:
  validate_against(name, opts, @video_variant_schema, :video)
defp validate_variant!(name, %{kind: :audio} = opts), do:
  validate_against(name, opts, @audio_variant_schema, :audio)
defp validate_variant!(name, %{kind: :waveform} = opts), do:
  validate_against(name, opts, @waveform_variant_schema, :waveform)
defp validate_variant!(name, opts) when not is_map_key(opts, :kind) do
  # Backward compatibility: existing image-only profiles omit :kind.
  validate_variant!(name, Map.put(opts, :kind, :image))
end
```

**Why this is the right shape:** existing profiles work unchanged (the
backward-compat clause defaults `:kind` to `:image`). New profiles add
`kind: :video`/`:audio`/`:waveform` with kind-appropriate options. Validation
errors stay at compile time and stay specific (e.g., `variant :poster:
:at_seconds must be a positive number, :scene_detect, or nil`).

---

## 6. Lifecycle FSM Additions

### 6.1 Asset FSM — extended state diagram

```
                 staged
                   ├─→ validating
                          ├─→ analyzing
                                ├─→ promoting
                                      ├─→ available
                                            ├─→ processing ─┬─→ ready
                                            ├─→ transcoding ┤   ↑
                                            └─→ quarantined │   │
                                                            └───┘
                          (any) ─→ quarantined ─→ deleted
                          ready ─→ degraded ─→ deleted
```

**Diff vs current:**

- New asset state: `transcoding`. Distinct from `processing` because retry
  semantics, telemetry, and timeouts differ. Variant FSM unchanged in shape but
  picks up the same retry rules.
- `analyzing` stays one state but the *probe step* inside it now dispatches to
  `Rindle.Probe.Image` or `Rindle.Probe.AVProbe` based on detected MIME from
  the validation step. No FSM change required for this — it's an
  implementation detail behind one state transition.
- All existing asset transitions preserved.

```elixir
@allowed_transitions %{
  "staged" => ["validating"],
  "validating" => ["analyzing"],
  "analyzing" => ["promoting", "quarantined"],   # add quarantine path
  "promoting" => ["available"],
  "available" => ["processing", "transcoding", "quarantined"],   # add transcoding
  "processing" => ["ready", "quarantined"],
  "transcoding" => ["ready", "degraded", "quarantined"],          # NEW
  "ready" => ["processing", "transcoding", "degraded", "deleted"],# allow re-derive
  "degraded" => ["processing", "transcoding", "quarantined", "deleted"],
  "quarantined" => ["deleted"],
  "deleted" => []
}
```

### 6.2 Variant FSM — unchanged shape, retry semantics tightened

The existing 8 states (`planned/queued/processing/ready/stale/missing/failed/purged`)
are sufficient. The change is in **retry policy**, which is a worker concern,
not an FSM concern:

- Image variants: existing exponential backoff (default Oban) is correct.
- Video/audio variants: longer backoff base + fewer retries + Oban `:snooze`
  for "system busy" classes.

```elixir
defmodule Rindle.Workers.VariantTranscode do
  use Oban.Worker, queue: :rindle_transcode, max_attempts: 5

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt, unsaved_error: %{reason: :ffmpeg_busy}}) do
    # External resource pressure — wait longer
    {:snooze, 60 * attempt}
  end

  def backoff(%Oban.Job{attempt: attempt}) do
    # Default exponential with longer base for transcodes
    trunc(:math.pow(2, attempt) * 30)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    # Idempotency invariant: if a previous attempt wrote partial output to
    # storage, we MUST overwrite or delete it before retrying. Variant
    # storage_key is deterministic from recipe_digest, so overwrite is safe.
    ...
  end
end
```

### 6.3 Footgun list (with mitigations)

| Footgun | What goes wrong | Mitigation |
|---|---|---|
| **Stuck "transcoding"** state after host crash | Asset/variant rows say `processing`/`transcoding` forever; admin can't tell live job from zombie | (a) Oban already provides `attempted_at` and orphan detection. (b) Add `Rindle.Reconcile` task that looks up Oban job state for variants in `processing`/`transcoding`. (c) Ship a `mix rindle.reconcile` task. |
| **Partial derivative success** (mp4 ok, poster failed) | Asset is `ready`-eligible by some readers but not others | Asset `ready` requires **all** declared variants `ready`. If any are `failed`, asset → `degraded`. Spatie does this; Active Storage does not (preview can fail silently) — copy Spatie. |
| **FFmpeg silent partial output** ([Jellyfin issue](https://github.com/jellyfin/jellyfin/issues/13668)) | ffmpeg exits 0 with a truncated/zero-byte file | Post-condition check: probe the *output* file with same `Rindle.Probe.AVProbe`; require duration within 1% of source. If mismatch → `failed`. |
| **FFmpeg installed at probe time but missing at transcode** | Adopter installs ffmpeg in test container only | Capability check at boot: `Rindle.Capability.detect/0` writes telemetry event `[:rindle, :capability, :ffmpeg]` on first call; profile compile-time fails fast if profile uses `:video`/`:audio` and no AV backend is reachable. |
| **Re-upload while transcode in progress** | New upload races old derivatives ([Shrine atomic_persist](https://shrinerb.com/docs/processing)) | Existing `recipe_digest` already serves as guard — when worker writes results, it must `update_all` with `WHERE recipe_digest = $matched`. Mismatch → variant becomes `stale`, not `ready`. (Same pattern current image worker uses; just enforce.) |
| **Long jobs blow Oban execution time** | Default Oban timeout cuts off 30-min transcode | Document `:rindle_transcode` queue with explicit timeout; recommend Oban Pro `:hibernate_after` for adopters who need it. Workers must report progress via telemetry every N seconds for ops visibility. |
| **Cross-kind derivative dependency loops** | Poster requires the source's frame, but profile may declare `from_variant: :web_mp4` (shrink poster from transcoded video) | LOCKED: variants depend only on the **source asset**, never on each other. Disallow `from_variant` references in v1.4. (django-video-encoding, Shrine make this mistake — variants chain → debugging nightmares.) |
| **Memory pressure on probe** | FFprobe on a 4-hour video can eat several GB | Probe runs in subprocess via `FFmpex` (already does) and we set strict `-analyzeduration` / `-probesize` caps in the AVProbe adapter. Document why. |
| **Audio-only mp4 misclassified as video** | ffprobe says "video stream" because of cover art image | `has_video_track: true` requires *moving* image (frame_rate ≥ 5fps). AVProbe checks this; otherwise classify as `:audio`. |
| **Unicode filenames break ffmpeg on Windows** | Out of scope but warns in install docs | Document that Rindle requires Linux/macOS for FFmpeg path; not a hard constraint but a known limitation. |

### 6.4 Telemetry — same shape, new keys

The existing `[:rindle, :asset, :state_change]` event picks up `:transcoding`
transitions for free (the FSM emits the same event on any transition). No new
event names required, which preserves the public-contract telemetry boundary
(PROJECT.md key decision row 4).

New optional metadata in events when applicable:

```elixir
:telemetry.execute(
  [:rindle, :asset, :state_change],
  %{system_time: ..., duration_ms: 1200},   # transcoded duration if known
  %{from: "available", to: "transcoding", kind: :video, profile: ...}
)
```

---

## 7. Backward Compat / Migration Plan

### 7.1 Migration strategy: nullable + default + multi-step

Following the [Ecto best-practice for adding nullable
columns](https://hexdocs.pm/ecto_sql/Ecto.Migration.html), we ship the schema
change in **one migration**, but in three logical steps inside it:

```elixir
defmodule Rindle.Repo.Migrations.V14AddMediaKind do
  use Ecto.Migration

  def up do
    # 1. Add kind column with default :image so existing rows are valid.
    alter table(:media_assets) do
      add :kind, :string, null: false, default: "image"
      add :width, :integer
      add :height, :integer
      add :duration_ms, :integer
      add :has_video_track, :boolean
      add :has_audio_track, :boolean
    end

    # 2. Backfill probe fields from existing metadata JSONB for image rows
    #    that had width/height stored there. (No-op if metadata didn't carry them.)
    execute """
    UPDATE media_assets
       SET width  = (metadata->>'width')::integer,
           height = (metadata->>'height')::integer
     WHERE kind = 'image'
       AND metadata ? 'width'
       AND width IS NULL
    """

    # 3. Add the variant column and a partial index for kind-scoped queries.
    alter table(:media_variants) do
      add :output_kind, :string
      add :duration_ms, :integer
      add :width, :integer
      add :height, :integer
    end

    execute """
    UPDATE media_variants
       SET output_kind = 'image'
     WHERE output_kind IS NULL
    """

    # Now make output_kind NOT NULL after backfill.
    alter table(:media_variants) do
      modify :output_kind, :string, null: false
    end

    create index(:media_assets, [:kind])
    create index(:media_assets, [:kind, :duration_ms])
    create index(:media_variants, [:output_kind, :state])
  end

  def down do
    drop index(:media_variants, [:output_kind, :state])
    drop index(:media_assets, [:kind, :duration_ms])
    drop index(:media_assets, [:kind])

    alter table(:media_variants) do
      remove :output_kind
      remove :duration_ms
      remove :width
      remove :height
    end

    alter table(:media_assets) do
      remove :kind
      remove :width
      remove :height
      remove :duration_ms
      remove :has_video_track
      remove :has_audio_track
    end
  end
end
```

### 7.2 Profile DSL backward compat

Existing image-only profiles continue to compile and run **unchanged** because
the validator's `validate_variant!/2` defaults `kind: :image` when omitted (see
section 5.4). Adopters who upgrade to v1.4 see no diff; adopters who add video
add `kind: :video` to new variant entries.

### 7.3 Public API backward compat

- `Rindle.url(asset, :variant_name)` — unchanged signature.
- `Rindle.attach/2` — unchanged.
- `Rindle.Profile` callbacks — unchanged signatures (`storage_adapter/0`,
  `variants/0`, `upload_policy/0`, `validate_upload/1`, `delivery_policy/0`,
  `recipe_digest/1`).
- New: `Rindle.probe(asset)` returning `{:ok, %{...}} | {:error, term()}` —
  additive only; replaces no existing function.

### 7.4 Optional dependency posture

`FFmpex` and `bbc/audiowaveform` are **optional** runtime dependencies
declared via `optional: true` in `mix.exs`:

```elixir
{:ffmpex, "~> 0.11", optional: true},
```

`Rindle.Capability.video?/0` and `Rindle.Capability.audio?/0` runtime-detect at
first call and:
- log `:warning` if a profile uses `kind: :video` but no FFmpeg is on PATH,
- raise at compile time only if `Mix.env() in [:test, :dev]` (so production
  boots with degraded posture, never crashes the whole app on capability
  detect).

This mirrors how Active Storage handles missing FFmpeg (`previewable?` returns
false) and respects PROJECT.md constraint row 5 (capability honesty).

### 7.5 Deprecation: none

v1.4 deprecates **nothing**. Image-first remains the wedge; video/audio are
purely additive.

---

## 8. Open Questions to Escalate

Only two questions survived the locked-recommendation filter — both genuinely
load-bearing for v1.4 scope and v2.0 semver posture.

### Q1. Should `Rindle.Processor.AV` be a single module that handles both video AND audio, or should we ship `Rindle.Processor.Video` + `Rindle.Processor.Audio` as separate adapters?

**Why it matters:** ffmpeg conceptually treats them as the same backend (one
binary, one CLI). But **adopters who only need audio** (podcast apps) would
prefer not to think about video at all. Module split is a public API decision
that becomes hard to undo after v2.0.

**Lean recommendation:** ship `Rindle.Processor.AV` (single adapter) because
audio extraction from video is a real workflow that needs both code paths in
one place. But this is a public-API/semver-impactful call.

**Peer evidence:**
- Shrine: per-attachment uploaders (kind-discriminated) — favours splitting.
- Active Storage: one `Analyzer` registry but separate `VideoAnalyzer` and
  `AudioAnalyzer` classes — splits at the *analyzer* level but unifies at the
  *blob* level. This is what we'd actually be doing if we split.
- ActiveEncode: one engine for video; doesn't address audio cleanly.

### Q2. Should `:waveform` be a first-class `output_kind` enum value or just `:image` with a known recipe shape?

**Why it matters:** `output_kind` is an `Ecto.Enum` — adding values later is
forward-compatible (just a migration), but existing operator dashboards,
external systems, and customer integrations querying `WHERE output_kind =
'image'` would silently miss waveforms if we later split them out. This is a
data-shape decision with downstream visibility implications.

**Lean recommendation:** keep `:waveform` as a distinct enum value because
operator queries differ ("regenerate all waveforms" is a real workflow), the
recipe shape differs, and the cost is one enum value at migration time.

---

## Sources

### Active Storage / Rails
- [ActiveStorage::Analyzer::VideoAnalyzer](https://api.rubyonrails.org/classes/ActiveStorage/Analyzer/VideoAnalyzer.html)
- [ActiveStorage::Analyzer::AudioAnalyzer](https://edgeapi.rubyonrails.org/classes/ActiveStorage/Analyzer/AudioAnalyzer.html)
- [ActiveStorage::Blob::Representable](https://api.rubyonrails.org/classes/ActiveStorage/Blob/Representable.html)
- [ActiveStorage::Preview](https://edgeapi.rubyonrails.org/classes/ActiveStorage/Preview.html)
- [ActiveStorage now pre-processes PDFs and videos (Saeloun)](https://blog.saeloun.com/2024/01/22/transform-job-accepts-previewable-files/)
- [Rails 7 adds AudioAnalyzer (Saeloun)](https://blog.saeloun.com/2021/06/30/rails-7-adds-audio-analyzer-to-active-storage/)
- [Rails 7.1 sample rate extraction (Shakacode)](https://www.shakacode.com/blog/rails-7-1-adds-option-to-extract-audio-sample-rate/)
- [Build Custom ActiveStorage Analyzers (AppSignal)](https://blog.appsignal.com/2025/07/30/build-custom-activestorage-analyzers-for-ruby-on-rails.html)
- [Active Storage Overview](https://guides.rubyonrails.org/active_storage_overview.html)
- [active_encode (Ruby Toolbox)](https://www.ruby-toolbox.com/projects/active_encode)

### Shrine
- [Shrine derivatives plugin](https://shrinerb.com/docs/plugins/derivatives)
- [Shrine processing](https://shrinerb.com/docs/processing)
- [Shrine metadata](https://github.com/shrinerb/shrine/blob/master/doc/metadata.md)
- [Shrine advantages](https://shrinerb.com/docs/advantages)
- [Video Processing with Shrine and FFmpeg (Jarosinski)](https://www.martinjarosinski.com/posts/video-processing-with-shrine-and-ffmpeg/)
- [Better File Uploads with Shrine: Processing (Janko)](https://janko.io/better-file-uploads-with-shrine-processing/)

### Spatie / Laravel Media Library
- [Defining conversions](https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions)
- [Image generators](https://spatie.be/docs/laravel-medialibrary/v11/converting-other-file-types/using-image-generators)
- [Video.php](https://github.com/spatie/laravel-medialibrary/blob/main/src/Conversions/ImageGenerators/Video.php)

### Paperclip / CarrierWave
- [paperclip-av-transcoder](https://github.com/ruby-av/paperclip-av-transcoder)
- [carrierwave-video](https://github.com/rheaton/carrierwave-video)
- [CarrierWave 3.x changelog](https://www.rubydoc.info/gems/carrierwave/frames)

### django-video-encoding / Cloudinary
- [django-video-encoding README](https://github.com/escaped/django-video-encoding/blob/master/README.md)
- [Cloudinary Upload API resource_type](https://cloudinary.com/documentation/image_upload_api_reference)
- [Cloudinary glossary](https://cloudinary.com/documentation/cloudinary_glossary)

### FFmpeg / FFprobe
- [FFprobe documentation](https://ffmpeg.org/ffprobe.html)
- [FFprobe JSON output (TechOverflow)](https://techoverflow.net/2022/10/21/how-to-get-video-metadata-as-json-using-ffmpeg-ffprobe/)
- [FFmpeg extract frames (Shotstack)](https://shotstack.io/learn/ffmpeg-extract-frames/)
- [Audio waveform with FFmpeg (Shotstack)](https://shotstack.io/learn/ffmpeg-create-waveform/)

### Elixir libraries
- [FFmpex](https://hex.pm/packages/ffmpex)
- [FFmpex on GitHub](https://github.com/talklittle/ffmpex)
- [Xav (FFmpeg wrapper)](https://github.com/elixir-webrtc/xav)
- [Membrane Framework](https://membrane.stream/)
- [Membrane core](https://github.com/membraneframework/membrane_core)
- [Membrane.Element.Base lifecycle](https://hexdocs.pm/membrane_core/0.7.0/Membrane.Element.Base.html)
- [Oban.Worker docs](https://hexdocs.pm/oban/Oban.Worker.html)
- [Oban — long-running jobs](https://medium.com/@jonnyeberhardt7/keep-calm-and-let-oban-handle-your-elixir-background-jobs-67e4f04d7522)
- [NimbleOptions](https://hexdocs.pm/nimble_options/NimbleOptions.html)
- [Polymorphic embeds for Ecto](https://hexdocs.pm/polymorphic_embed/readme.html)
- [EctoDiscriminator](https://hexdocs.pm/ecto_discriminator/0.2.5/readme.html)
- [Polymorphic embeds (Schultzer)](https://danschultzer.com/posts/polymorphic-embeds-in-ecto)
- [Ecto.Migration](https://hexdocs.pm/ecto_sql/Ecto.Migration.html)
- [JSONB queries with Ecto (theScore)](https://techblog.thescore.com/2022/06/23/embedded-schema-queries-with-ecto/)

### BBC audiowaveform
- [bbc/audiowaveform](https://github.com/bbc/audiowaveform)
- [bbc/peaks.js](https://github.com/bbc/peaks.js/)

### Footgun references
- [Transcoding stuck (Immich)](https://github.com/immich-app/immich/issues/10560)
- [Transcoding job killed (Jellyfin)](https://github.com/jellyfin/jellyfin/issues/11640)
- [FFmpeg exits with code 0 mid-file (Jellyfin)](https://github.com/jellyfin/jellyfin/issues/13668)
- [Active Storage video preview fails in active job (Rails)](https://github.com/rails/rails/issues/37124)
- [Inaccurate video previewer docs (Rails)](https://github.com/rails/rails/issues/51802)
- [VideoAnalyzer duration missing (Rails)](https://github.com/rails/rails/issues/40130)
