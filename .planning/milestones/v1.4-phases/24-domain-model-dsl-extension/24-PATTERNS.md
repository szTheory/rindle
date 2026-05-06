# Phase 24: Domain Model & DSL Extension - Pattern Map

**Mapped:** 2026-05-02
**Files analyzed:** 16 (5 new + 11 modified)
**Analogs found:** 16 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `priv/repo/migrations/<ts>_extend_media_for_av.exs` | migration (additive) | DDL | `priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs` | exact (additive `alter` migration with `:string` defaults) |
| `lib/rindle/probe.ex` | behaviour contract | type-dispatched analyzer | `lib/rindle/processor.ex` | exact (single-callback behaviour with module attribute docs) |
| `lib/rindle/probe/image.ex` | adapter (libvips) | local-path in → result map out | `lib/rindle/processor/image.ex` | exact (same `@behaviour` + libvips call surface) |
| `lib/rindle/probe/av_probe.ex` | adapter (FFprobe shim wrapper) | local-path in → reshaped+sanitized result map | `lib/rindle/processor/image.ex` (shape) + `lib/rindle/av/ffprobe.ex` (delegation) | role-match + delegation match |
| `lib/rindle/av/metadata_sanitizer.ex` | pure transform module | string/map in → sanitized string/map out | `lib/rindle/av/ffprobe.ex` lines 43-60 (`sanitize/1` recursive walker) | role-match (recursive sanitizer pattern; new bytes-aware truncate primitive) |
| `test/rindle/backward_compat/v13_digest_snapshot_test.exs` | snapshot test (load-bearing) | digest equality | `test/rindle/profile/profile_test.exs:74-103` | role-match (extends digest stability test pattern) |
| `test/rindle/probe_test.exs` | unit test (behaviour + adapters) | mock runner / fixture file | `test/rindle/av/probe_test.exs` (mock runner pattern) + `test/rindle/av/ffprobe_test.exs` (`@moduletag :tmp_dir`) | role-match |
| `test/rindle/av/metadata_sanitizer_test.exs` | unit test (pure function) | string in → string out | `test/rindle/av/ffprobe_test.exs:19-49` (`parse_and_sanitize/1` describe block) | exact |
| `test/rindle/profile/validator_test.exs` (new or split) | unit test (per-kind dispatch) | DSL strings → compile result | `test/rindle/profile/profile_test.exs:17-48` (`assert_raise ArgumentError` + `Code.compile_string`) | exact |
| `lib/rindle/domain/asset_fsm.ex` (modified) | FSM transitions map | discrete state machine | self (current `@allowed_transitions`) | exact (additive map edits only) |
| `lib/rindle/domain/variant_fsm.ex` (modified) | FSM transitions map | discrete state machine | self (current `@allowed_transitions`) | exact (additive map edits only) |
| `lib/rindle/domain/media_asset.ex` (modified) | Ecto schema + changeset | DB row write/read | self (existing `cast`/`validate_inclusion` pattern) + `validate_inclusion` precedent at line 88 | exact |
| `lib/rindle/domain/media_variant.ex` (modified) | Ecto schema + changeset | DB row write/read | self (existing `cast`/`validate_inclusion` pattern at line 76) | exact |
| `lib/rindle/profile/validator.ex` (modified) | NimbleOptions DSL validator | compile-time keyword list → validated map | self (existing `@variant_schema` + `validate_variant!/2` at lines 50-71, 186-208) | exact |
| `lib/rindle/workers/promote_asset.ex` (modified) | Oban worker (lifecycle chain) | DB row state machine + side effects | self (existing `advance_to_promoting/2` chain at lines 42-66) | exact (insertion point inside `validating` clause) |
| `test/rindle/domain/lifecycle_fsm_test.exs` (modified) | FSM regression test | `transition/2` assertions | self (lines 13-73) | exact (extend with new edges + regression guards) |
| `test/adopter/canonical_app/lifecycle_test.exs` (modified) | adopter parity test | full MinIO lifecycle | self (lines 104-191 happy-path test) | exact (extend with `refute Map.has_key?(spec, :kind)` + digest snapshot reference) |

## Pattern Assignments

### `priv/repo/migrations/<ts>_extend_media_for_av.exs` (migration, DDL)

**Analog:** `priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs` (additive `alter` migration; same shape) and `priv/repo/migrations/20260424155129_create_media_assets.exs` (column-type precedents).

**Whole-file analog excerpt** (`extend_media_upload_sessions_for_multipart.exs:1-12`):

```elixir
defmodule Rindle.Repo.Migrations.ExtendMediaUploadSessionsForMultipart do
  use Ecto.Migration

  def change do
    alter table(:media_upload_sessions) do
      add :upload_strategy, :string, null: false, default: "presigned_put"
      add :multipart_upload_id, :string
      add :multipart_parts, :map, null: false, default: %{}
    end
  end
end
```

**Column-type precedent excerpt** (`20260424155129_create_media_assets.exs:5-15`):

```elixir
create table(:media_assets) do
  add :state, :string, null: false, default: "staged"
  add :storage_key, :string, null: false
  add :content_type, :string
  add :byte_size, :bigint
  add :filename, :string
  add :metadata, :map, null: false, default: %{}
  add :recipe_digest, :string
  add :profile, :string, null: false

  timestamps()
end
```

**`error_reason :text` precedent excerpt** (`20260425090100_create_media_variants.exs:5-15`):

```elixir
create table(:media_variants) do
  add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
  add :name, :string, null: false
  add :state, :string, null: false, default: "planned"
  add :recipe_digest, :string, null: false
  add :storage_key, :string
  add :error_reason, :text
  add :generated_at, :utc_datetime_usec
  ...
```

**What to mirror:** Plain `use Ecto.Migration` + single `def change` with two `alter table/2` blocks (one for `:media_assets`, one for `:media_variants`). String enum columns get `null: false, default: "image"`; integer probe columns are nullable; durations use `:bigint` (matches `byte_size`); `error_reason` uses `:text`. No `disable_ddl_transaction`, no `lock_timeout` (no precedent for either).

---

### `lib/rindle/probe.ex` (behaviour, type-dispatched analyzer)

**Analog:** `lib/rindle/processor.ex` — symmetric naming chosen by SYNTHESIS §2.2.

**Full-file analog excerpt** (`lib/rindle/processor.ex:1-21`):

```elixir
defmodule Rindle.Processor do
  @moduledoc """
  Behaviour contract for media processors that generate variants.

  Implementations may read from and write to storage paths, but storage I/O
  must never occur inside database transactions.
  """

  @doc """
  Processes a source file according to a variant spec, writing the result to
  `destination`.

  The `variant_spec` is the recipe map declared by the profile's `variants/0`
  configuration. Implementations should write the processed output to
  `destination` and return `{:ok, destination}` on success. Storage I/O (such
  as downloading the source or uploading the result) MUST happen outside DB
  transactions; this callback operates on local paths only.
  """
  @callback process(source :: Path.t(), variant_spec :: map(), destination :: Path.t()) ::
              {:ok, Path.t()} | {:error, term()}
end
```

**What to mirror:** Bare `defmodule` + `@moduledoc` + `@callback` declarations. Two callbacks (`probe/1`, `accepts?/1`) — both use `:: {:ok, _} | {:error, term()}` style returns. Add `@type kind :: :image | :video | :audio` and `@type result :: %{...}` above the callbacks per RESEARCH.md Pattern 3. The "Storage I/O outside transactions" warning carries over verbatim; adapters operate on local `Path.t()` only.

---

### `lib/rindle/probe/image.ex` (adapter, libvips)

**Analog:** `lib/rindle/processor/image.ex`.

**Header excerpt** (`lib/rindle/processor/image.ex:1-46`):

```elixir
defmodule Rindle.Processor.Image do
  @moduledoc """
  Image processor adapter using the [Image](https://hex.pm/packages/image) library
  (powered by libvips/Vix).

  This is Rindle's bundled reference processor — symmetric with `Rindle.Storage.S3`
  and `Rindle.Storage.Local` for the `Rindle.Storage` behaviour. ...
  """

  @behaviour Rindle.Processor

  @impl Rindle.Processor
  @spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def process(source_path, variant_spec, destination_path) do
    width = Map.get(variant_spec, :width)
    height = Map.get(variant_spec, :height)
    mode = Map.get(variant_spec, :mode, :fit)
    format = Map.get(variant_spec, :format)
    quality = Map.get(variant_spec, :quality, 80)

    with {:ok, image} <- Image.open(source_path),
         {:ok, processed} <- apply_resize(image, width, height, mode),
         {:ok, _written} <- write_image(processed, destination_path, format, quality) do
      {:ok, destination_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end
```

**What to mirror:** `@behaviour Rindle.Probe` + `@impl Rindle.Probe` annotations on each callback; use the `Image.open/1` libvips entrypoint (already a project dependency); keep `with` chain shape so error tuples flow through unchanged. `accepts?/1` uses `String.starts_with?(content_type, "image/")` — single-clause, returns `false` for non-binaries.

---

### `lib/rindle/probe/av_probe.ex` (adapter, FFprobe shim wrapper)

**Analog:** `lib/rindle/processor/image.ex` (shape) + `lib/rindle/av/ffprobe.ex` (the wrapped function).

**Wrapped-call surface excerpt** (`lib/rindle/av/ffprobe.ex:9-28`):

```elixir
@doc """
Runs ffprobe on the given file path to extract JSON metadata.
"""
def probe(file_path) do
  args = [
    "-v", "error",
    "-print_format", "json",
    "-show_format",
    "-show_streams",
    file_path
  ]

  case Subprocess.run("ffprobe", args) do
    {output, 0} ->
      parse_and_sanitize(output)

    {output, status} ->
      {:error, {:ffprobe_failed, status, output}}
  end
end
```

**What to mirror:** New module `Rindle.Probe.AVProbe` declares `@behaviour Rindle.Probe`, `alias Rindle.AV.Ffprobe` and `alias Rindle.AV.MetadataSanitizer`. `probe/1` is a thin reshape adapter: `with {:ok, raw} <- Ffprobe.probe(source), do: {:ok, reshape(raw)}`. The reshape function pulls `format["duration"]`, finds video/audio streams via `Enum.find(streams, & &1["codec_type"] == "video")`, classifies kind, and pipes raw metadata through `MetadataSanitizer.sanitize/1` BEFORE returning (D-20). `accepts?/1` checks `String.starts_with?` against `"video/"` or `"audio/"`. Concrete shape per RESEARCH.md Pattern 3 lines 555-628.

---

### `lib/rindle/av/metadata_sanitizer.ex` (pure transform module)

**Analog:** `lib/rindle/av/ffprobe.ex:43-60` — the existing recursive `sanitize/1` walker (HTML-escape pass).

**Recursive walker analog excerpt** (`lib/rindle/av/ffprobe.ex:43-60`):

```elixir
defp sanitize(string) when is_binary(string) do
  string
  |> String.replace("&", "&amp;")
  |> String.replace("<", "&lt;")
  |> String.replace(">", "&gt;")
  |> String.replace("\"", "&quot;")
  |> String.replace("'", "&#39;")
end

defp sanitize(map) when is_map(map) do
  Map.new(map, fn {k, v} -> {k, sanitize(v)} end)
end

defp sanitize(list) when is_list(list) do
  Enum.map(list, &sanitize/1)
end

defp sanitize(other), do: other
```

**What to mirror:** Same four-clause recursive shape (binary / map / list / passthrough), but exposed as **public** `def sanitize/1` (not `defp`) so `Rindle.Probe.AVProbe` can call it. Replace the HTML-escape body with `strip_control_chars/1 |> truncate_to_bytes(@max_bytes)`. The bytes-aware truncate primitive is the only genuinely new code (RESEARCH.md Pattern 4 lines 743-768): `<<head::binary-size(max_bytes), _rest::binary>>` followed by `String.valid?/1` rewind. Use `@max_bytes 1024` and `@control_chars Enum.map(0x00..0x1F, &<<&1>>) -- [<<0x09>>]`. **Do NOT use `String.byte_slice/3`** (Elixir 1.17+; the CI matrix runs 1.15).

---

### `test/rindle/backward_compat/v13_digest_snapshot_test.exs` (snapshot test, load-bearing)

**Analog:** `test/rindle/profile/profile_test.exs:74-103` — existing digest stability tests.

**Analog excerpt** (`test/rindle/profile/profile_test.exs:74-103`):

```elixir
test "digest is stable when equivalent specs use reordered keys" do
  module_a =
    compile_profile("""
    storage: Rindle.StorageMock,
    variants: [
      thumb: [mode: :fit, width: 320, format: :jpeg, quality: 75]
    ],
    allow_mime: ["image/jpeg"],
    allow_extensions: [".jpg"],
    max_bytes: 5_000_000,
    max_pixels: 24_000_000
    """)

  module_b =
    compile_profile("""
    max_pixels: 24_000_000,
    allow_extensions: [".jpg"],
    variants: [
      thumb: [quality: 75, format: :jpeg, width: 320, mode: :fit]
    ],
    storage: Rindle.StorageMock,
    max_bytes: 5_000_000,
    allow_mime: ["image/jpeg"]
    """)

  digest_a = module_a.recipe_digest(:thumb)
  digest_b = module_b.recipe_digest(:thumb)

  assert digest_a == digest_b
end
```

**Helpers excerpt** (`test/rindle/profile/profile_test.exs:179-195`):

```elixir
defp compile_profile(profile_opts_source) do
  module_name = unique_module_name("CompiledProfile")

  source = """
  defmodule #{module_name} do
    use Rindle.Profile,
      #{profile_opts_source}
  end
  """

  [{compiled_module, _bytecode}] = Code.compile_string(source)
  compiled_module
end

defp unique_module_name(prefix) do
  :"Elixir.Rindle.Profile.#{prefix}#{System.unique_integer([:positive])}"
end
```

**What to mirror:** `use ExUnit.Case, async: true`. Three load-bearing tests:
1. `assert AdopterProfile.recipe_digest(:thumb) == @v13_thumb_digest` — captured BEFORE any validator edits (D-23 sequencing).
2. Two compile-string profiles (one with `kind: :image` explicit, one with `:kind` omitted) digest identically.
3. The validated variant map for an image profile has `refute Map.has_key?(spec, :kind)` — direct guard against D-14 drift.

Use the `compile_profile/1` + `unique_module_name/1` helper idiom verbatim. The captured v1.3 digest is a string literal at the top of the file with a comment block explaining provenance.

---

### `test/rindle/probe_test.exs` (unit test, behaviour + adapter dispatch)

**Analogs:** `test/rindle/av/probe_test.exs` (mock runner pattern; `assert_raise` style) + `test/rindle/av/ffprobe_test.exs` (`@moduletag :tmp_dir` for fixture files).

**Tmp-dir fixture analog excerpt** (`test/rindle/av/ffprobe_test.exs:1-17`):

```elixir
defmodule Rindle.AV.FfprobeTest do
  use ExUnit.Case, async: true
  alias Rindle.AV.Ffprobe

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    source = Path.join(tmp_dir, "input.mp4")
    %{source: source}
  end

  describe "probe/1" do
    test "handles ffprobe failure on invalid file", %{source: source} do
      File.write!(source, "dummy content")
      assert {:error, {:ffprobe_failed, _status, _output}} = Ffprobe.probe(source)
    end
  end
```

**What to mirror:** `use ExUnit.Case, async: true` + `@moduletag :tmp_dir` for tests that need a real file path. Cover (a) `Rindle.Probe.Image.accepts?/1` returns `true` for `image/jpeg`, `false` for `video/mp4`; (b) `Rindle.Probe.AVProbe.accepts?/1` returns `true` for `video/*` and `audio/*`, `false` for images; (c) round-trip a known-good FFprobe JSON through `AVProbe.probe/1` and assert `result.kind in [:video, :audio]`, `result.metadata` is sanitized. Mock runner pattern (anonymous-function injection, see `probe_test.exs:7-11`) is the standard idiom for substituting external commands.

---

### `test/rindle/av/metadata_sanitizer_test.exs` (unit test, pure function)

**Analog:** `test/rindle/av/ffprobe_test.exs:19-49` (`parse_and_sanitize/1` describe block).

**Analog excerpt** (`test/rindle/av/ffprobe_test.exs:19-49`):

```elixir
describe "parse_and_sanitize/1" do
  test "decodes JSON and HTML escapes string values" do
    json = """
    {
      "format": {
        "tags": {
          "title": "<script>alert(1)</script>"
        },
        "duration": "10.5"
      },
      "streams": [
        {
          "codec_name": "h264",
          "tags": {
            "language": "eng\\\" onerror=\\\"alert(1)"
          }
        }
      ]
    }
    """

    assert {:ok, metadata} = Ffprobe.parse_and_sanitize(json)
    assert metadata["format"]["tags"]["title"] == "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert metadata["format"]["duration"] == "10.5"
    ...
  end

  test "returns error on invalid JSON" do
    assert {:error, :invalid_json} = Ffprobe.parse_and_sanitize("{invalid")
  end
end
```

**What to mirror:** `use ExUnit.Case, async: true`. A `describe "sanitize/1"` block plus a `describe "truncate_to_bytes/2"` block. Boundary cases per RESEARCH.md Validation Architecture lines 152-162: 1023+1 (multi-byte) drops the partial codepoint; exactly-1024 returned unchanged; 1024 ending mid-codepoint rewinds; control chars `\x00`, `\x07`, `\x1F` stripped; `\t` preserved; `\n`/`\r` stripped (per literal D-19). Doctests on `truncate_to_bytes/2` are appropriate (RESEARCH.md Pattern 4 lines 727-742).

---

### `test/rindle/profile/validator_test.exs` (unit test, per-kind dispatch)

**Analog:** `test/rindle/profile/profile_test.exs:17-48` (compile-time `assert_raise ArgumentError` + `Code.compile_string`).

**Analog excerpt** (`test/rindle/profile/profile_test.exs:17-48`):

```elixir
test "invalid profile options raise at compile time" do
  assert_raise ArgumentError, fn ->
    Code.compile_string("""
    defmodule #{unique_module_name("InvalidProfileUnknownKey")} do
      use Rindle.Profile,
        storage: Rindle.StorageMock,
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        max_bytes: 1024,
        max_pixels: 1_000_000,
        variants: [thumb: [mode: :fit, width: 120]],
        unsupported_option: true
    end
    """)
  end
end

test "contradictory crop variant options raise at compile time" do
  assert_raise ArgumentError, ~r/requires both :width and :height/, fn ->
    Code.compile_string("""
    defmodule #{unique_module_name("InvalidProfileCrop")} do
      use Rindle.Profile,
        ...
        variants: [hero: [mode: :crop, width: 900]]
    end
    """)
  end
end
```

**What to mirror:** Same `assert_raise ArgumentError, ~r/.../, fn -> Code.compile_string(...) end` shape. Cover: (a) `:kind => :unknown` raises with the `mix phx.gen`-style fix-hint message (D-13); (b) `:from_variant` key raises (D-15, AV-02-08); (c) `:image` schema rejects `:codec`, `:duration_ms`; (d) `:video` schema rejects `:peaks`; (e) `:audio` schema rejects `:width`/`:height`; (f) default (`:kind` omitted) compiles successfully and produces an image variant; (g) explicit `kind: :image` compiles successfully and produces the same digest as the omitted-kind form (D-14 cross-check).

---

### `lib/rindle/domain/asset_fsm.ex` (modified, FSM transitions map)

**Analog:** self — current `@allowed_transitions` map. Edits are purely additive.

**Current state excerpt** (`lib/rindle/domain/asset_fsm.ex:6-17`):

```elixir
@allowed_transitions %{
  "staged" => ["validating"],
  "validating" => ["analyzing"],
  "analyzing" => ["promoting"],
  "promoting" => ["available"],
  "available" => ["processing", "quarantined"],
  "processing" => ["ready", "quarantined"],
  "ready" => ["degraded", "deleted"],
  "degraded" => ["quarantined", "deleted"],
  "quarantined" => ["deleted"],
  "deleted" => []
}
```

**What to mirror:** Same map literal; only the values change. Append `"transcoding"` to `"available" =>` and add the new key `"transcoding" => ["ready", "degraded", "quarantined"]`. Per RESEARCH.md Pattern 7 lines 998-1004, ALSO add `"quarantined"` to the `"analyzing"` value (probe-failure path requires it; D-09 omitted this and the planner must flag the deviation). The `transition/3` function body is unchanged.

---

### `lib/rindle/domain/variant_fsm.ex` (modified, FSM transitions map)

**Analog:** self — current `@allowed_transitions` map.

**Current state excerpt** (`lib/rindle/domain/variant_fsm.ex:4-13`):

```elixir
@allowed_transitions %{
  "planned" => ["queued"],
  "queued" => ["processing"],
  "processing" => ["ready", "failed"],
  "ready" => ["stale", "missing", "purged"],
  "stale" => ["queued", "purged"],
  "missing" => ["queued", "purged"],
  "failed" => ["queued", "purged"],
  "purged" => []
}
```

**What to mirror:** Append `"cancelled"` to the value lists for `"planned"`, `"queued"`, and `"processing"`. Add the new key `"cancelled" => []` (terminal). Match the existing string-state idiom (no atoms).

---

### `lib/rindle/domain/media_asset.ex` (modified, Ecto schema + changeset)

**Analog:** self.

**Current changeset excerpt** (`lib/rindle/domain/media_asset.ex:74-90`):

```elixir
@spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
def changeset(asset, attrs) do
  asset
  |> cast(attrs, [
    :state,
    :storage_key,
    :content_type,
    :byte_size,
    :filename,
    :metadata,
    :recipe_digest,
    :profile
  ])
  |> validate_required([:state, :storage_key, :profile])
  |> validate_inclusion(:state, @states)
  |> unique_constraint(:storage_key)
end
```

**Schema field precedent** (`lib/rindle/domain/media_asset.ex:34-65`):

```elixir
@states [
  "staged",
  "validating",
  "analyzing",
  "promoting",
  "available",
  ...
  "deleted"
]
...
schema "media_assets" do
  field :state, :string, default: "staged"
  field :storage_key, :string
  field :content_type, :string
  field :byte_size, :integer
  field :filename, :string
  field :metadata, :map, default: %{}
  field :recipe_digest, :string
  field :profile, :string
  ...
```

**What to mirror:** Add `"transcoding"` to `@states` (alphabetic placement is fine; existing list is roughly lifecycle-ordered — keep that). Add `@kinds ~w(image video audio)` module attribute. New schema fields:

```elixir
field :kind, :string, default: "image"
field :width, :integer
field :height, :integer
field :duration_ms, :integer  # bigint at DB layer; :integer at schema layer
field :has_video_track, :boolean
field :has_audio_track, :boolean
field :error_reason, :string
```

Extend `cast/3` field list with the seven new fields. Add `validate_required(..., :kind)` and `validate_inclusion(:kind, @kinds)`. Add `validate_kind_field_consistency/1` private function per RESEARCH.md Pattern 5 lines 815-857 (D-11 enforcement). The `validate_inclusion` precedent at line 88 is the exact pattern to clone for `:kind`.

---

### `lib/rindle/domain/media_variant.ex` (modified, Ecto schema + changeset)

**Analog:** self.

**Current changeset excerpt** (`lib/rindle/domain/media_variant.ex:33-79`):

```elixir
@states ["planned", "queued", "processing", "ready", "stale", "missing", "failed", "purged"]
...
schema "media_variants" do
  field :name, :string
  field :state, :string, default: "planned"
  field :recipe_digest, :string
  field :storage_key, :string
  field :byte_size, :integer
  field :content_type, :string
  field :error_reason, :string
  field :generated_at, :utc_datetime_usec
  ...
end

def changeset(variant, attrs) do
  variant
  |> cast(attrs, [
    :asset_id,
    :name,
    :state,
    :recipe_digest,
    :storage_key,
    :byte_size,
    :content_type,
    :error_reason,
    :generated_at
  ])
  |> validate_required([:asset_id, :name, :state, :recipe_digest])
  |> validate_inclusion(:state, @states)
  |> foreign_key_constraint(:asset_id)
  |> unique_constraint([:asset_id, :name])
end
```

**What to mirror:** Add `"cancelled"` to `@states`. Add `@output_kinds ~w(image video audio waveform)` module attribute. Add new schema fields: `field :output_kind, :string, default: "image"`, `field :duration_ms, :integer`, `field :width, :integer`, `field :height, :integer`. Extend `cast/3` field list. Add `validate_inclusion(:output_kind, @output_kinds)`. The validation idiom is identical to the `:state` line above.

---

### `lib/rindle/profile/validator.ex` (modified, NimbleOptions DSL validator)

**Analog:** self — existing `@variant_schema` + `validate_variant!/2`.

**Existing schema excerpt** (`lib/rindle/profile/validator.ex:50-71`):

```elixir
@variant_schema [
  mode: [
    type: {:in, [:fit, :fill, :crop]},
    required: true
  ],
  width: [
    type: {:or, [:pos_integer, nil]},
    default: nil
  ],
  height: [
    type: {:or, [:pos_integer, nil]},
    default: nil
  ],
  format: [
    type: {:in, [:jpeg, :png, :webp, :avif]},
    default: :jpeg
  ],
  quality: [
    type: {:or, [{:in, 1..100}, nil]},
    default: nil
  ]
]
```

**Existing dispatch excerpt** (`lib/rindle/profile/validator.ex:186-208`):

```elixir
defp validate_variant!(name, variant_opts) when is_atom(name) do
  normalized_variant_opts = normalize_variant_opts!(variant_opts)

  validated_variant =
    normalized_variant_opts
    |> NimbleOptions.validate!(@variant_schema)
    |> Keyword.new()

  mode = Keyword.fetch!(validated_variant, :mode)
  width = Keyword.fetch!(validated_variant, :width)
  height = Keyword.fetch!(validated_variant, :height)

  validate_variant_dimensions!(name, mode, width, height)

  validated_variant
  |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  |> Map.new()
rescue
  error in NimbleOptions.ValidationError ->
    reraise ArgumentError,
            "variant #{inspect(name)}: #{Exception.message(error)}",
            __STACKTRACE__
end
```

**What to mirror:** Rename `@variant_schema` → `@image_variant_schema` (verbatim body). Add three new module attributes (`@video_variant_schema`, `@audio_variant_schema`, `@waveform_variant_schema`) — concrete bodies in RESEARCH.md Pattern 1 lines 318-363. Add `@allowed_kinds [:image, :video, :audio, :waveform]`. Replace `validate_variant!/2` body per RESEARCH.md Pattern 1 lines 367-403: pop `:kind` (default `:image`), guard `:from_variant`, dispatch via `schema_for_kind/1`, run image-specific dimension check only when `kind == :image`, and finalize with `maybe_put_kind/3` that **omits `:kind` from the output map for ALL `:image` cases (default OR explicit)** — D-14 load-bearing. Keep the `rescue NimbleOptions.ValidationError -> reraise ArgumentError` shape (it's the established error-message style).

---

### `lib/rindle/workers/promote_asset.ex` (modified, Oban worker chain)

**Analog:** self — existing `advance_to_promoting/2` chain at lines 42-66.

**Existing insertion-point excerpt** (`lib/rindle/workers/promote_asset.ex:42-66`):

```elixir
defp advance_to_promoting(_repo, %{state: "promoting"}), do: :ok

defp advance_to_promoting(repo, %{state: "analyzing"} = asset) do
  with :ok <- AssetFSM.transition(asset.state, "promoting", %{asset_id: asset.id}),
       {:ok, _asset} <-
         asset
         |> MediaAsset.changeset(%{state: "promoting"})
         |> repo.update() do
    :ok
  else
    {:error, reason} -> {:error, reason}
  end
end

defp advance_to_promoting(repo, %{state: "validating"} = asset) do
  with :ok <- AssetFSM.transition(asset.state, "analyzing", %{asset_id: asset.id}),
       {:ok, asset} <-
         asset
         |> MediaAsset.changeset(%{state: "analyzing"})
         |> repo.update() do
    advance_to_promoting(repo, asset)
  else
    {:error, reason} -> {:error, reason}
  end
end
```

**What to mirror:** Extend the `validating` clause's `with` chain with a new `{:ok, asset} <- run_probe_step(repo, asset)` line BEFORE the recursive `advance_to_promoting/2` call. Add `defp run_probe_step/2` per RESEARCH.md Pattern 6 lines 909-925 — uses `try/after _ = File.rm(tmp_path)` for guaranteed cleanup. Add `defp dispatch_probe/1` (cond on `Rindle.Probe.AVProbe.accepts?/1` then `Rindle.Probe.Image.accepts?/1`). Add `defp quarantine_asset/3` for the failure branch. Use `Rindle.Security.Mime.detect/1` for MIME (D-17 — dispatch by detected MIME, not by `kind`). Tempfile path is `Path.join(tmp_dir(), "rindle_probe_#{Ecto.UUID.generate()}")` so `Rindle.Ops.OrphanReaper` (Phase 23) is the safety net. Match the existing else-branch error-tuple shape exactly.

---

### `test/rindle/domain/lifecycle_fsm_test.exs` (modified, FSM regression test)

**Analog:** self — lines 13-73.

**Analog excerpt** (`test/rindle/domain/lifecycle_fsm_test.exs:13-44`):

```elixir
describe "asset transition matrix" do
  test "accepts the nominal asset lifecycle path" do
    assert :ok == AssetFSM.transition("staged", "validating")
    assert :ok == AssetFSM.transition("validating", "analyzing")
    assert :ok == AssetFSM.transition("analyzing", "promoting")
    assert :ok == AssetFSM.transition("promoting", "available")
    assert :ok == AssetFSM.transition("available", "processing")
    assert :ok == AssetFSM.transition("processing", "ready")
  end

  test "accepts degraded, quarantine, and terminal delete branches" do
    assert :ok == AssetFSM.transition("ready", "degraded")
    assert :ok == AssetFSM.transition("available", "quarantined")
    assert :ok == AssetFSM.transition("processing", "quarantined")
    ...
  end

  test "rejects non-allowlisted asset jumps" do
    assert {:error, {:invalid_transition, "staged", "ready"}} =
             AssetFSM.transition("staged", "ready")
    ...
  end
end
```

**What to mirror:** Add a new `describe "asset transition matrix — additive (Phase 24)"` block per RESEARCH.md Pattern 7 lines 1026-1058 — covers `available → transcoding`, `transcoding → ready/degraded/quarantined`, `analyzing → quarantined`. **Critically, also add regression-guard tests** asserting the existing edges (`available → processing`, `processing → ready`, `available → quarantined`) still pass — these are byte-for-byte image-flow guards. Mirror for variant FSM with the cancelled-edges block per RESEARCH.md Pattern 7 lines 1060-1080. Use the same `assert :ok == FSM.transition(...)` and `{:error, {:invalid_transition, ...}}` patterns — do NOT introduce new helpers.

---

### `test/adopter/canonical_app/lifecycle_test.exs` (modified, adopter parity test)

**Analog:** self — existing happy-path test at lines 104-191.

**Variant assertion excerpt** (`test/adopter/canonical_app/lifecycle_test.exs:155-158`):

```elixir
ready_variants =
  Repo.all(Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id))

assert Enum.all?(ready_variants, &(&1.state == "ready"))
```

**What to mirror:** Add a new test (or extend the existing `:adopter`-tagged test) per D-22 with these assertions:
1. `AdopterProfile.variants()` returns the same map shape as v1.3 — `refute Map.has_key?(thumb, :kind)` for the image-default `:thumb` entry.
2. `AdopterProfile.recipe_digest(:thumb)` matches the snapshotted v1.3 digest (the same constant that anchors `v13_digest_snapshot_test.exs`).
3. The full lifecycle test (lines 104-191 happy-path) continues to pass byte-for-byte — no edits to the existing assertions.
4. The `@moduletag :adopter` tag stays — this is the gated lane that runs against MinIO.

---

## Shared Patterns

### Schema-Layer String Enums (D-01)

**Source:** `lib/rindle/domain/media_asset.ex:34-45, 88` and `lib/rindle/domain/media_variant.ex:33, 76`.

**Apply to:** `media_asset.ex` (`:kind`), `media_variant.ex` (`:output_kind`).

**Excerpt:**

```elixir
@states ["staged", "validating", "analyzing", ..., "deleted"]
...
field :state, :string, default: "staged"
...
|> validate_inclusion(:state, @states)
```

**What to mirror:** String-typed column + module-attribute allowlist + `validate_inclusion/3`. Six existing schemas use this pattern; do not deviate to `Ecto.Enum` (no precedent).

---

### `assert_raise ArgumentError` for compile-time DSL errors

**Source:** `test/rindle/profile/profile_test.exs:17-48`.

**Apply to:** All new validator tests asserting D-13 (`:kind => :unknown`), D-15 (`:from_variant`), and per-kind schema rejections.

**Excerpt:**

```elixir
test "..." do
  assert_raise ArgumentError, ~r/regex matching the fix hint/, fn ->
    Code.compile_string("""
    defmodule #{unique_module_name("...")} do
      use Rindle.Profile, ...
    end
    """)
  end
end
```

**What to mirror:** `Code.compile_string` + `unique_module_name/1` + regex-bounded `assert_raise`. Avoid bare `assert_raise ArgumentError, fn -> ... end` for cases where the message wording is part of the contract (per D-13's `mix phx.gen`-style fix hint, the message IS the contract).

---

### `with` Chain + `else {:error, reason} -> {:error, reason}` (Workers)

**Source:** `lib/rindle/workers/promote_asset.ex:44-65`.

**Apply to:** New `run_probe_step/2`, `quarantine_asset/3`, and `dispatch_probe/1` helpers.

**Excerpt:**

```elixir
with :ok <- AssetFSM.transition(...),
     {:ok, _asset} <- ... |> repo.update() do
  :ok
else
  {:error, reason} -> {:error, reason}
end
```

**What to mirror:** Worker code uses `with` chains exclusively for happy-path composition. Failure cases bubble unchanged tuples. Do not introduce `case`-on-each-step or nested `try`. The `try/after` for tempfile cleanup wraps the entire `with`.

---

### Recursive Sanitizer Walker (binary / map / list / passthrough)

**Source:** `lib/rindle/av/ffprobe.ex:43-60` (existing HTML-escape walker).

**Apply to:** New `Rindle.AV.MetadataSanitizer.sanitize/1` (truncate + control-char strip).

**Excerpt:**

```elixir
def sanitize(string) when is_binary(string), do: ...
def sanitize(map) when is_map(map),
  do: Map.new(map, fn {k, v} -> {k, sanitize(v)} end)
def sanitize(list) when is_list(list), do: Enum.map(list, &sanitize/1)
def sanitize(other), do: other
```

**What to mirror:** Same four-clause shape; only the binary clause's body changes (control-char strip → byte-truncate, in that order). Keep map/list recursion unchanged. **Promote to `def` (public)** so `Rindle.Probe.AVProbe` can call it (the existing one in Ffprobe is `defp` — do not change that; the new one is its own module).

---

### `@moduletag :tmp_dir` for Real-File Fixtures

**Source:** `test/rindle/av/ffprobe_test.exs:5-10`, `test/rindle/ops/orphan_reaper_test.exs:5-33`.

**Apply to:** `test/rindle/probe_test.exs` (downloaded fixtures), worker tests that exercise the probe path.

**Excerpt:**

```elixir
@moduletag :tmp_dir

setup %{tmp_dir: tmp_dir} do
  source = Path.join(tmp_dir, "input.mp4")
  %{source: source}
end
```

**What to mirror:** ExUnit's built-in `:tmp_dir` tag provides a per-test directory; never call `System.tmp_dir!()` directly in test setup. Cleanup is automatic.

---

### Mock-Runner Function Injection

**Source:** `test/rindle/av/probe_test.exs:7-11`.

**Apply to:** Tests that exercise external-command paths without invoking the real binary.

**Excerpt:**

```elixir
mock_runner = fn "ffmpeg", ["-version"] ->
  {"ffmpeg version 6.0.0 ...\n", 0}
end

assert :ok = Probe.check_ffmpeg!(mock_runner)
```

**What to mirror:** Anonymous function passed as a function-injection argument. The `check_ffmpeg!/1` callee defaults the runner to `&System.cmd/2` in production and accepts the mock at test time. Use this pattern when extending probe tests if FFprobe-binary-free coverage is desired.

---

### Telemetry Emission on FSM Transitions

**Source:** `lib/rindle/domain/asset_fsm.ex:34-50`, `lib/rindle/domain/variant_fsm.ex:21-37`.

**Apply to:** No code changes required — but be aware that adding the new `transcoding` and `cancelled` edges automatically emits `:rindle, :asset, :state_change` and `:rindle, :variant, :state_change` events with `from`/`to` metadata. Plan-level test assertions on telemetry are optional but cheap.

**Excerpt:**

```elixir
:telemetry.execute(
  [:rindle, :asset, :state_change],
  %{system_time: System.system_time()},
  %{profile: ..., adapter: ..., from: current_state, to: target_state}
)
```

**What to mirror:** Nothing — this is automatic. Just don't break it.

---

## No Analog Found

None. Every Phase 24 file has a strong analog in the codebase. The only genuinely new primitive is the bytes-aware UTF-8-safe truncate function (`MetadataSanitizer.truncate_to_bytes/2`), which is fully specified in RESEARCH.md Pattern 4 — the planner can use that excerpt verbatim.

## Metadata

**Analog search scope:**
- `lib/rindle/` (full tree, 8 directories)
- `priv/repo/migrations/` (all 8 migrations)
- `test/rindle/` (full tree)
- `test/adopter/canonical_app/`

**Files scanned:** 22 source files + 9 test files + 8 migrations = 39 total
**Pattern extraction date:** 2026-05-02
**Codebase confidence:** HIGH — every analog excerpt was read line-by-line; line numbers verified against the current main-branch state.
