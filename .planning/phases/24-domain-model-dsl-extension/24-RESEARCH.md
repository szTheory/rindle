# Phase 24: Domain Model & DSL Extension - Research

**Researched:** 2026-05-02
**Domain:** Elixir Ecto schema extension, profile DSL composition, FSM additive transitions, Phase 23 ↔ 24 probe-layer integration
**Confidence:** HIGH (codebase fully read; precedents verified; CONTEXT.md D-01 through D-23 already locked)

## Summary

Phase 24 extends the Rindle profile DSL and `MediaAsset` / `MediaVariant` domain
to support `:image | :video | :audio | :waveform` variants while preserving
byte-for-byte compatibility for every existing v1.0 image-only profile. The
phase has eleven requirements (AV-02-01 through AV-02-11) and the user has
already locked twenty-three implementation decisions (D-01 through D-23) in
`24-CONTEXT.md`. Research scope is therefore narrow and prescriptive: fill the
gray areas (per-kind NimbleOptions schema bodies, Sanitizer placement,
recipe-digest stability mechanism, idiomatic Elixir patterns, peer-library
lessons, MIME-dispatched probe insertion shape, FSM additive invariants), and
hand the planner code-shaped artifacts.

The dominant risk in this phase is **recipe-digest drift** (D-14): if `:kind`
gets persisted into the validated variant spec for image-default profiles, every
existing adopter's variants flip to `stale` on upgrade and re-process. The
mechanism this research recommends (drop `:kind` from the validated variant
spec when omitted; keep `:kind` ONLY when explicitly declared; snapshot v1.3
digest BEFORE validator changes) is the canonical fix.

The second-largest risk is **`Rindle.tmp/` orphan tempfile leakage** if a probe
fails inside the inline `analyzing` chain and the function returns without
deleting the downloaded source — this research prescribes `try/after` cleanup
with `OrphanReaper` as the safety net (4h threshold).

The third-largest risk is **byte vs. character truncation** in
`MetadataSanitizer`: AV-02-10 specifies "1024 bytes" but `String.slice/3` in
Elixir 1.15 (the project minimum) operates on graphemes. `String.byte_slice/3`
was added in Elixir 1.17 — too new for the CI matrix. This research provides a
codepoint-aligned byte-truncation primitive that works on Elixir 1.15.

**Primary recommendation:** Implement Phase 24 in five plans following the
phase boundary (CONTEXT.md `<domain>`): (1) Migration + schema-layer enums,
(2) FSM additive states + per-kind changeset validation, (3) Per-kind
NimbleOptions schemas + recipe-digest stability, (4) `Rindle.Probe` behaviour
+ `Rindle.AV.MetadataSanitizer` + `Rindle.Probe.AVProbe`/`Image` adapters,
(5) MIME-dispatched probe insertion in `PromoteAsset` + adopter parity test.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Migration (additive columns + defaults) | Database / Storage | — | All existing rows must remain valid via column defaults; Ecto schema layer maps `:string` ↔ atom. |
| `:kind`/`:output_kind` enum mapping | Domain (Ecto schema) | — | Precedent (`@states` lists + `validate_inclusion`) is schema-layer not PG-layer; `Ecto.Enum` available but unused — match existing precedent first. |
| Per-kind variant validation | Profile (compile-time DSL) | — | NimbleOptions runs inside `Rindle.Profile.__using__/1` macro; image-only adopters hit zero new code paths. |
| Recipe digest stability | Profile (compile-time DSL) | — | `:kind` persistence into the validated map is what breaks digests; control happens at validator output, not at digest function. |
| FSM transitions (asset + variant) | Domain | — | Plain `@allowed_transitions` map; additive only. |
| MIME-dispatched probe step | Workers / Lifecycle | Domain (state writes) | `PromoteAsset` is the orchestrator; Domain owns the changeset that persists probe output. |
| Container metadata sanitization | AV (Probe.AVProbe call site) | Probe behaviour result reshape | Sanitization happens AFTER raw FFprobe extraction (Phase 23) and BEFORE the changeset (Phase 24) — clean seam. |
| Backward-compat parity test | Test harness (canonical adopter) | Profile + Lifecycle | Anchors the v1.3 digest snapshot and the byte-for-byte image lifecycle. |

## Standard Stack

### Core (already in tree, no new deps required)

| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| `nimble_options` | `~> 1.1` | Compile-time DSL validation | Already used by `Rindle.Profile.Validator`; per-kind dispatch fits the `:keys` + custom validator idiom. [VERIFIED: `mix.exs`] |
| `ecto_sql` | `~> 3.11` | Schema + migration | Already used for all 8 prior migrations. [VERIFIED: `mix.exs`] |
| `jason` | (transitive) | JSON encoding for digest input + FFprobe parse | Already used by `Rindle.Profile.Digest` and `Rindle.AV.Ffprobe`. [VERIFIED: `lib/rindle/profile/digest.ex:11`] |
| `muontrap` | (Phase 23) | Subprocess wrapper for FFprobe | Reused indirectly via `Rindle.AV.Subprocess`. [VERIFIED: Phase 23 in tree] |

### No new runtime dependencies required for Phase 24.

`Ecto.Enum` is a transitive feature of `ecto`; it is **available** but the
existing precedent across 6 schemas
(`media_asset.ex:88`, `media_variant.ex:76`, `media_upload_session.ex:85`,
`media_processing_run.ex:62`) is `field :state, :string` + `validate_inclusion`.
**Recommendation: match precedent — use `:string` field + `@kinds` list +
`validate_inclusion(:kind, @kinds)`** for symmetry. CONTEXT.md D-01 names
"`Ecto.Enum` at the schema layer for atom mapping" but does not forbid the
`:string` + `validate_inclusion` shape, and the precedent is unanimous. The
tradeoff: `Ecto.Enum` gives `cast` of strings → atoms automatically; the
existing precedent gives string-only at the boundary. Image-only adopter rows
default to `"image"` either way. [ASSUMED: planner picks; precedent argues for
`:string`]

**Installation:** No `mix.exs` changes for Phase 24. [VERIFIED: every primitive
already in tree]

**Version verification:**
- Elixir 1.15 minimum (CI matrix `1.15` + `1.17`) — `String.byte_slice/3` is
  Elixir 1.17+, **NOT usable** for the truncation primitive. [VERIFIED:
  `.github/workflows/ci.yml`]
- `nimble_options ~> 1.1` supports nested `:keys` schemas and custom
  validators. [VERIFIED: hexdocs.pm/nimble_options/NimbleOptions.html]

## Validation Architecture

> **Required.** `nyquist_validation` is enabled by default (config absent).

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (Elixir built-in), Oban.Testing for worker assertions |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test --include unit --exclude integration --exclude adopter` |
| Full suite command | `mix test` (includes `:adopter` lane against MinIO) |
| Compile-only check | `mix compile --warnings-as-errors` (catches DSL macro regressions) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| AV-02-01 | Migration adds `:kind`, `:output_kind`, typed probe columns + `error_reason` | unit (migration) | `mix test test/rindle/domain/migration_test.exs` | Wave 0 (new file) |
| AV-02-02 | `kind` enum on `media_assets`; `output_kind` enum on `media_variants` | unit (schema) | `mix test test/rindle/domain/media_asset_test.exs test/rindle/domain/media_variant_test.exs` | extend existing |
| AV-02-03 | `transcoding` asset state added; `available → transcoding → ready/degraded/quarantined` valid | unit (FSM) | `mix test test/rindle/domain/lifecycle_fsm_test.exs:13` | extend existing (line 13 area) |
| AV-02-04 | `cancelled` variant state added; `queued/processing/planned → cancelled` valid | unit (FSM) | `mix test test/rindle/domain/lifecycle_fsm_test.exs:47` | extend existing (line 47 area) |
| AV-02-05 | `Rindle.Probe` behaviour callback contract; `Rindle.Probe.AVProbe`/`Image` implement | unit (behaviour) | `mix test test/rindle/probe_test.exs` | Wave 0 (new file) |
| AV-02-06 | Per-kind NimbleOptions schemas validate variant opts; specific error messages | unit (validator) | `mix test test/rindle/profile/validator_test.exs` | Wave 0 (new file) |
| AV-02-07 | Default `:kind` to `:image` when omitted | unit (validator) + parity (digest) | `mix test test/rindle/profile/profile_test.exs:74 test/rindle/backward_compat/v13_digest_snapshot_test.exs` | extend + Wave 0 |
| AV-02-08 | Compile-time rejection of `:from_variant` | unit (validator) | `mix test test/rindle/profile/validator_test.exs` (raise assertion) | Wave 0 |
| AV-02-09 | Probe step in `analyzing` dispatches by MIME; failure → `quarantined` + `error_reason` | integration (worker) | `mix test test/rindle/workers/promote_asset_test.exs` | extend existing |
| AV-02-10 | Container metadata truncated to 1024 bytes; control chars stripped | unit (sanitizer) | `mix test test/rindle/av/metadata_sanitizer_test.exs` | Wave 0 (new file) |
| AV-02-11 | Existing image-only profile compiles + runs byte-for-byte unchanged on v1.4 | parity (adopter) | `mix test test/adopter/canonical_app/lifecycle_test.exs --include adopter` | extend existing |

### Sampling Rate

- **Per task commit:** `mix test --exclude integration --exclude adopter --warnings-as-errors`
- **Per wave merge:** `mix test --warnings-as-errors`
- **Phase gate:** Full suite green + adopter lane green before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `test/rindle/domain/migration_test.exs` — covers AV-02-01 (migration smoke + Repo column-presence assertion)
- [ ] `test/rindle/probe_test.exs` — covers AV-02-05 (behaviour contract + adapter dispatch)
- [ ] `test/rindle/profile/validator_test.exs` — covers AV-02-06, AV-02-07, AV-02-08 (per-kind schemas + default + `from_variant` rejection)
- [ ] `test/rindle/backward_compat/v13_digest_snapshot_test.exs` — covers AV-02-11 (load-bearing v1.3 digest snapshot for `:thumb`)
- [ ] `test/rindle/av/metadata_sanitizer_test.exs` — covers AV-02-10 (byte truncation + control-char stripping + UTF-8 boundary)
- [ ] Extend `test/rindle/domain/lifecycle_fsm_test.exs` for AV-02-03, AV-02-04 transitions
- [ ] Extend `test/rindle/workers/promote_asset_test.exs` for AV-02-09 MIME-dispatched probe + quarantine

### Validation Dimensions Each Plan Must Validate

| Dimension | Why | Specific Boundary |
|---|---|---|
| **Recipe digest stability** | Silent stale-flip of every adopter's image variants on upgrade is a P0 regression | Snapshotted v1.3 digest of the canonical `:thumb` variant must equal v1.4-computed digest; `:kind` MUST NOT appear in the digested map for image-default profiles |
| **FSM additive invariants** | Existing image flow must be byte-for-byte identical | Existing transitions (`available → processing`, `available → quarantined`, `processing → ready/quarantined`) untouched; new transitions are pure additions |
| **Per-kind schema validation** | Adopter misuse must be caught at compile time with actionable message | Each `:kind` value rejects keys not in its schema; `:image` schema rejects `:codec`/`:duration_ms`; `:video` schema rejects `:peaks`; etc. |
| **Per-kind changeset validation** | Field/kind consistency at the row level (AV-02-09 sets typed columns from probe) | `:audio` row with `width != nil` → changeset error; `:image` row with `duration_ms != nil` → changeset error; `:image` row with `has_video_track != nil` → changeset error |
| **Sanitization byte-truncation correctness** | UTF-8 boundary must not produce invalid binary | Truncation never emits a partial codepoint; strict ≤ 1024 bytes; control chars in `\x00-\x1F` minus `\t` stripped (kept: `\t`, `\n`, `\r`?? — D-19 says "except `\t`" — kept = `\t` only) |
| **Adopter parity (full lifecycle)** | Ship-or-die gate for AV-02-11 | Existing canonical adopter test + new digest snapshot test both pass |

### Boundary Conditions

| Boundary | Test Input | Expected Behavior |
|---|---|---|
| 1024-byte UTF-8 character boundary | 1023-byte ASCII + 1 multi-byte char (3 bytes) — total 1026 | Truncate at 1023 (drop the multi-byte; never emit invalid binary) |
| Exactly 1024 bytes | 1024-byte ASCII string | Returned unchanged |
| 1024 bytes ending mid-codepoint | 1023-byte ASCII + first byte of multi-byte char (truncated input) | Drop the 1 partial byte; return 1023 |
| Control character ranges | `\x00`, `\x07`, `\x1F` | Stripped |
| Tab preserved | `\t` (`\x09`) | Kept (D-19: "except `\t`") |
| Newline behavior | `\n` (`\x0A`), `\r` (`\x0D`) | **Stripped** per literal D-19 ("Strip control characters `\x00-\x1F` except `\t`"). Newlines fall in `\x00-\x1F` and are NOT in the exception list. |
| DEL char `\x7F` | `\x7F` | NOT stripped (out of `\x00-\x1F` range per D-19) — but the planner may want to broaden to `\x7F` since DEL is also a control character. **Recommendation:** keep D-19 verbatim (only `\x00-\x1F` minus `\t`); add a TODO if DEL coverage matters. [ASSUMED: D-19 is canonical] |

### Adversarial Inputs

| Adversary | Test | Defense Verified |
|---|---|---|
| Malformed FFprobe JSON | Feed `Rindle.Probe.AVProbe` a non-JSON binary | Returns `{:error, :invalid_json}` (Phase 23 already handles); probe step transitions asset to `quarantined` |
| FFprobe output with embedded HTML | `<script>alert(1)</script>` in title tag | Phase 23 HTML-escape applied at FFprobe layer; Phase 24 truncate+strip applied on top; both layers preserved (D-21) |
| FFprobe output with 1MB title field | Tag with megabyte-scale string | Truncated to 1024 bytes with no invalid UTF-8 |
| Mixed-kind profile with overlapping option names | `:thumb` (image) and `:hero` (video) both declaring `:width` | Each variant validates against its kind schema; both pass; no schema cross-talk |
| Profile with `:kind => :unknown` | `variants: [bad: [kind: :unknown, ...]]` | Compile-time `ArgumentError` with `mix phx.gen`-style fix hint listing the four allowed kinds |
| Profile with `:from_variant` reference | `variants: [poster: [kind: :image, from_variant: :hero]]` | Compile-time `ArgumentError` (AV-02-08) |
| v1.0 image-only profile (no `:kind`) | Existing canonical adopter profile | Compiles unchanged; recipe digest unchanged byte-for-byte; lifecycle test passes |
| `:image`-default profile then explicitly-`:image` profile | Two equivalent specs | Same recipe digest (proves `:kind` not persisted in image-default cases) |
| Probe failure with downloaded tempfile | Force `Rindle.Probe.AVProbe` to return `{:error, :ffprobe_failed}` | Tempfile deleted (try/after); asset transitions to `quarantined` with `error_reason` set; OrphanReaper safety net cleans up if try/after fails |
| Concurrent re-upload during analyzing | Re-stage asset while probe in flight | (Out of scope for Phase 24 — Phase 25 atomic-promote race guard handles this; Phase 24 only sets up the surface) |

## Architecture Patterns

### System Architecture Diagram

```
                    Profile DSL (compile time)
                           │
                           ▼
            Rindle.Profile.Validator.validate!/1
                           │
              ┌────────────┴────────────┐
              │  pop :kind, default :image (D-13)
              │            │
              │            ▼
              │  dispatch to per-kind schema:
              │   ├── @image_variant_schema   (existing, unchanged)
              │   ├── @video_variant_schema   (NEW)
              │   ├── @audio_variant_schema   (NEW)
              │   └── @waveform_variant_schema (NEW)
              │            │
              │            ▼
              │  drop :kind from validated map
              │  IFF default-:image (D-14)
              └────────────┬────────────┘
                           ▼
              Rindle.Profile.Digest.for_variant
              (unchanged; deterministic)
                           │
                           ▼
              recipe_digest/1 (per profile module)


        Upload arrives → MediaUploadSession.completed
                           │
                           ▼
                 Workers.PromoteAsset.perform/1
                           │
              validating ─→ analyzing ─→ promoting ─→ available
                           │
                           ▼ (D-16 inline body)
              ┌──────────────────────────────────┐
              │ 1. Download to Rindle.tmp/<uuid> │
              │ 2. Rindle.Security.Mime.detect/1 │
              │ 3. dispatch by accepts?/1:       │
              │    ├── Probe.Image  (libvips)    │
              │    └── Probe.AVProbe (FFprobe)   │
              │       │                          │
              │       ├─ ok → reshape → sanitize │
              │       │       (Rindle.AV.        │
              │       │        MetadataSanitizer)│
              │       │       → MediaAsset       │
              │       │         changeset write  │
              │       │       → state: promoting │
              │       │                          │
              │       └─ error → state:          │
              │            quarantined           │
              │            + error_reason        │
              │                                  │
              │ 4. always: File.rm(tempfile)     │
              │    (try/after);                  │
              │    OrphanReaper safety net (4h)  │
              └──────────────────────────────────┘
                           │
                           ▼
                 enqueue ProcessVariant jobs
```

### Recommended Project Structure (Additive)

```
lib/rindle/
├── profile/
│   └── validator.ex              # extended: per-kind schemas + dispatch
├── domain/
│   ├── asset_fsm.ex              # extended: + transcoding edges
│   ├── variant_fsm.ex            # extended: + cancelled edges
│   ├── media_asset.ex            # extended: + :kind, typed cols, error_reason
│   └── media_variant.ex          # extended: + :output_kind, typed cols
├── probe.ex                      # NEW: Rindle.Probe behaviour
├── probe/
│   ├── image.ex                  # NEW: wraps libvips
│   └── av_probe.ex               # NEW: wraps Rindle.AV.Ffprobe
├── av/
│   ├── ffprobe.ex                # UNCHANGED (Phase 23, keep HTML-escape)
│   ├── probe.ex                  # UNCHANGED (boot probe; do NOT rename)
│   └── metadata_sanitizer.ex     # NEW: byte truncate + control-char strip
└── workers/
    └── promote_asset.ex          # extended: insert MIME-dispatched probe step

priv/repo/migrations/
└── 20260502NNNNNN_extend_media_for_av.exs  # NEW: single additive migration

test/rindle/
├── profile/
│   ├── profile_test.exs          # extended: digest stability for image-default
│   └── validator_test.exs        # NEW: per-kind validation
├── domain/
│   ├── lifecycle_fsm_test.exs    # extended: + transcoding/cancelled paths
│   └── migration_test.exs        # NEW (optional): column existence smoke
├── av/
│   └── metadata_sanitizer_test.exs # NEW
├── probe_test.exs                # NEW
├── backward_compat/
│   └── v13_digest_snapshot_test.exs # NEW (load-bearing per D-22, D-23)
└── workers/
    └── promote_asset_test.exs    # extended: probe dispatch + quarantine
```

### Pattern 1: Per-Kind NimbleOptions Schema with Pre-Dispatch (D-12, D-13)

**What:** Pop `:kind` from variant opts before NimbleOptions validation.
Dispatch to a kind-specific schema. Re-attach `:kind` to validated output ONLY
if explicitly declared (default-`:image` → omit; explicit-`:image` → also omit
for digest parity, see Pattern 2).

**When to use:** Any DSL where the option set varies by a discriminator atom.
The pattern keeps each schema small and produces specific error messages
("variant `:hero`: unknown option :peaks for kind :video").

**Example (drop into `lib/rindle/profile/validator.ex`):**

```elixir
# Replace existing @variant_schema with @image_variant_schema (verbatim).
# Add per-kind module attributes.

@image_variant_schema [
  mode: [type: {:in, [:fit, :fill, :crop]}, required: true,
    doc: "Resize strategy. `:crop` requires both :width and :height."],
  width: [type: {:or, [:pos_integer, nil]}, default: nil,
    doc: "Target width in pixels."],
  height: [type: {:or, [:pos_integer, nil]}, default: nil,
    doc: "Target height in pixels."],
  format: [type: {:in, [:jpeg, :png, :webp, :avif]}, default: :jpeg,
    doc: "Output container/codec."],
  quality: [type: {:or, [{:in, 1..100}, nil]}, default: nil,
    doc: "Output quality (1-100)."]
]

# Sourced from SYNTHESIS §2.4 in/out format scope. Anything in the
# "Out of v1.4" column (HLS, DASH, MKV, raw AAC, etc.) MUST NOT appear here.
@video_variant_schema [
  preset: [type: {:in, [:web_720p, :web_480p]}, required: true,
    doc: "Named transcode preset. Phase 25 ships :web_720p; :web_480p reserved."],
  codec: [type: {:in, [:h264]}, default: :h264,
    doc: "Video codec. Only :h264 supported in v1.4 (named-presets-only)."],
  container: [type: {:in, [:mp4]}, default: :mp4,
    doc: "Output container. Only :mp4 supported in v1.4."],
  audio_codec: [type: {:in, [:aac, :none]}, default: :aac,
    doc: "Audio codec for muxed output. :none drops audio."],
  width: [type: {:or, [:pos_integer, nil]}, default: nil,
    doc: "Target width in pixels (overrides preset default)."],
  height: [type: {:or, [:pos_integer, nil]}, default: nil,
    doc: "Target height in pixels (overrides preset default)."],
  faststart: [type: :boolean, default: true,
    doc: "Move moov atom to start (`+faststart`) for progressive playback."],
  max_duration_seconds: [type: {:or, [:pos_integer, nil]}, default: nil,
    doc: "Override profile-level max duration; nil inherits."]
]

@audio_variant_schema [
  preset: [type: {:in, [:m4a_128k, :mp3_128k]}, required: true,
    doc: "Named audio preset (codec + bitrate combination)."],
  codec: [type: {:in, [:aac, :mp3]}, default: :aac,
    doc: "Audio codec. v1.4 supports :aac (m4a) and :mp3 only."],
  container: [type: {:in, [:m4a, :mp3]}, default: :m4a,
    doc: "Output container; must match codec."],
  bitrate_kbps: [type: {:or, [:pos_integer, nil]}, default: nil,
    doc: "Override preset bitrate in kbps."],
  channels: [type: {:in, [1, 2, nil]}, default: nil,
    doc: "Channel count: 1=mono, 2=stereo, nil=preserve source."],
  normalize: [type: :boolean, default: false,
    doc: "Apply EBU R128 single-pass loudnorm (-16 LUFS, -1.5 TP, 11 LRA)."],
  two_pass: [type: :boolean, default: false,
    doc: "Two-pass loudnorm for higher fidelity (Phase 25)."]
]

@waveform_variant_schema [
  format: [type: {:in, [:json]}, default: :json,
    doc: "Output format. Only :json supported in v1.4."],
  peaks: [type: :pos_integer, default: 1000,
    doc: "Number of peak samples in the output array."],
  sample_rate: [type: {:or, [:pos_integer, nil]}, default: nil,
    doc: "Resample audio before peak extraction; nil = source rate."],
  channels: [type: {:in, [1, 2, nil]}, default: nil,
    doc: "Channel count for analysis: 1=mono mix, 2=stereo, nil=source."]
]

@allowed_kinds [:image, :video, :audio, :waveform]

defp validate_variant!(name, variant_opts) when is_atom(name) do
  normalized = normalize_variant_opts!(variant_opts)
  {kind, kind_explicit?, rest} = pop_kind!(name, normalized)
  guard_no_from_variant!(name, rest)  # AV-02-08

  schema = schema_for_kind(kind)

  validated_kw =
    rest
    |> NimbleOptions.validate!(schema)
    |> Keyword.new()

  if kind == :image do
    validate_variant_dimensions!(name, Keyword.fetch!(validated_kw, :mode),
      Keyword.fetch!(validated_kw, :width), Keyword.fetch!(validated_kw, :height))
  end

  validated_kw
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  |> Map.new()
  |> maybe_put_kind(kind, kind_explicit?)
rescue
  error in NimbleOptions.ValidationError ->
    reraise ArgumentError,
            "variant #{inspect(name)}: #{Exception.message(error)}",
            __STACKTRACE__
end

defp pop_kind!(name, opts) do
  case Keyword.pop(opts, :kind, nil) do
    {nil, rest} -> {:image, false, rest}
    {kind, rest} when kind in @allowed_kinds -> {kind, true, rest}
    {bad, _rest} ->
      raise ArgumentError,
            "variant #{inspect(name)} declared `:kind => #{inspect(bad)}`; " <>
              "allowed: :image | :video | :audio | :waveform"
  end
end

defp guard_no_from_variant!(name, opts) do
  if Keyword.has_key?(opts, :from_variant) do
    raise ArgumentError,
          "variant #{inspect(name)} declared `:from_variant`; cross-variant " <>
            "chaining is not supported. Variants depend only on the source asset. " <>
            "(AV-02-08)"
  end
end

defp schema_for_kind(:image), do: @image_variant_schema
defp schema_for_kind(:video), do: @video_variant_schema
defp schema_for_kind(:audio), do: @audio_variant_schema
defp schema_for_kind(:waveform), do: @waveform_variant_schema

# D-14 LOAD-BEARING: omit :kind from the validated map for default-:image
# AND explicit-:image, so v1.0 image profiles digest identically to v1.4
# explicit-:image profiles AND to v1.0 (no :kind) profiles. The :kind
# information is recoverable from the variant SCHEMA at runtime via the
# variant's structure (presence of :preset / :peaks / etc.); the persisted
# spec doesn't need to carry it. For non-image kinds, :kind IS persisted
# so MediaVariant.changeset can route by it.
defp maybe_put_kind(map, :image, _explicit?), do: map
defp maybe_put_kind(map, kind, _explicit?), do: Map.put(map, :kind, kind)
```

**Source:** Pattern derived from existing `lib/rindle/profile/validator.ex:186-208`
+ NimbleOptions hexdocs `:keys` nested-schema idiom (CITED:
hexdocs.pm/nimble_options/NimbleOptions.html). [VERIFIED: codebase grep
`from_variant` returns 0 hits — D-15 forward-looking guard is safe.]

### Pattern 2: Recipe-Digest Stability via `:kind` Omission (D-14)

**What:** The digest function (`Rindle.Profile.Digest.for_variant/2`) hashes
the variant spec map after canonical key/value normalization
(`lib/rindle/profile/digest.ex:39-65`). If `:kind` lands in the map for
image variants, every existing v1.0 image profile's digest changes — silent
regeneration of every adopter's variants on upgrade.

**Why omission, not patch:** Two viable approaches were considered:

| Option | What | Tradeoff |
|---|---|---|
| **(a) Omit `:kind` from validated map for `:image`** | Validator never adds `:kind` for image kinds (default OR explicit) | Simpler; localized to validator; digest.ex untouched. Can't distinguish `:image` from omitted at the variant-spec level (acceptable — `:image` is the default). **Recommended.** |
| **(b) Patch `Digest.for_variant` to filter `:kind` for image** | Digest module knows the discriminator | Cross-cutting concern bleeds into the hash function; introduces a special case in a deterministic primitive. **Rejected.** |
| **(c) Both** | Defense in depth | Code path divergence; only one is the contract. **Rejected.** |

**Recommendation: (a) only.** See Pattern 1's `maybe_put_kind/3`. The digest
module stays unchanged. The contract is "the validated variant spec is the
hashable surface; the validator decides what's in it." This is the same
contract that already applies to `nil`-valued options being stripped at
`validator.ex:201`.

**Pre-flight verification (D-23):** Before any validator changes, snapshot the
v1.3 digest of the canonical `:thumb` variant. The fixture is
`test/adopter/canonical_app/profile.ex` (`thumb: [mode: :fit, width: 64,
height: 64]`).

```elixir
# test/rindle/backward_compat/v13_digest_snapshot_test.exs
defmodule Rindle.BackwardCompat.V13DigestSnapshotTest do
  @moduledoc """
  Load-bearing snapshot of the v1.3 recipe digest for the canonical adopter
  profile's :thumb variant. If this test fails on v1.4, the validator is
  persisting :kind into image-default specs (D-14 violation) and every
  existing adopter's image variants will silently flip to :stale on upgrade.

  The expected digest below was captured via:

      mix run -e \\
        'IO.puts(Rindle.Adopter.CanonicalApp.Profile.recipe_digest(:thumb))'

  ON A v1.3 CHECKOUT, BEFORE Phase 24 validator changes. Do not regenerate
  this value casually.
  """

  use ExUnit.Case, async: true

  alias Rindle.Adopter.CanonicalApp.Profile, as: AdopterProfile

  # Captured 2026-05-02 on commit <SHA before Phase 24 starts>:
  @v13_thumb_digest "<TO BE CAPTURED IN PLAN 1, TASK 1 BEFORE ANY validator.ex EDITS>"

  test "image-default :thumb digest matches v1.3 snapshot" do
    assert AdopterProfile.recipe_digest(:thumb) == @v13_thumb_digest
  end

  test "explicit :kind => :image yields the same digest as omitted :kind" do
    explicit = compile_profile_with_explicit_image_kind()
    omitted = compile_profile_with_omitted_kind()

    assert explicit.recipe_digest(:thumb) == omitted.recipe_digest(:thumb)
  end

  # Helpers compile fresh modules at test time per the Code.compile_string
  # pattern at test/rindle/profile/profile_test.exs:179-195.
  defp compile_profile_with_explicit_image_kind, do: ...
  defp compile_profile_with_omitted_kind, do: ...
end
```

**Source:** Pattern derived from `test/rindle/profile/profile_test.exs:74-103`
(existing digest-stability test). [VERIFIED: codebase read.]

### Pattern 3: `Rindle.Probe` Behaviour (D-06, D-07)

**What:** Define a tiny behaviour that mirrors `Rindle.Processor`. Two
adapters: `Rindle.Probe.Image` (libvips) and `Rindle.Probe.AVProbe` (FFprobe
via Phase 23). Dispatch by `accepts?/1` on detected MIME.

**When to use:** Whenever the project has a "type-dispatched analyzer"
shape. Symmetric with `Rindle.Processor` + `Rindle.Processor.Image`
(SYNTHESIS §2.2 explicit choice).

**Example (`lib/rindle/probe.ex`):**

```elixir
defmodule Rindle.Probe do
  @moduledoc """
  Behaviour contract for content-analysis probes.

  Probes inspect a local file path (already downloaded out of storage) and
  return a normalized result map describing the content's kind, dimensions,
  duration, track presence, and free-form metadata. Storage I/O happens
  outside this callback; probes operate on local paths only.

  See:
    * `Rindle.Probe.Image` — libvips-backed image probe (no FFmpeg required).
    * `Rindle.Probe.AVProbe` — FFprobe-backed video/audio probe.
  """

  @type kind :: :image | :video | :audio
  @type result :: %{
          required(:kind) => kind(),
          optional(:width) => pos_integer(),
          optional(:height) => pos_integer(),
          optional(:duration_ms) => non_neg_integer(),
          optional(:has_video_track) => boolean(),
          optional(:has_audio_track) => boolean(),
          optional(:metadata) => map()
        }

  @callback probe(source :: Path.t()) :: {:ok, result()} | {:error, term()}
  @callback accepts?(content_type :: String.t()) :: boolean()
end
```

**Adapter (`lib/rindle/probe/av_probe.ex`):**

```elixir
defmodule Rindle.Probe.AVProbe do
  @moduledoc """
  FFprobe-backed probe for video and audio. Wraps `Rindle.AV.Ffprobe.probe/1`
  (Phase 23) and reshapes raw FFprobe JSON into the standardized
  `Rindle.Probe.result()` shape, then runs container-metadata sanitization
  (`Rindle.AV.MetadataSanitizer`) before returning.
  """

  @behaviour Rindle.Probe

  alias Rindle.AV.Ffprobe
  alias Rindle.AV.MetadataSanitizer

  @video_mime_prefixes ["video/"]
  @audio_mime_prefixes ["audio/"]

  @impl Rindle.Probe
  def accepts?(content_type) when is_binary(content_type) do
    Enum.any?(@video_mime_prefixes ++ @audio_mime_prefixes,
      &String.starts_with?(content_type, &1))
  end

  def accepts?(_), do: false

  @impl Rindle.Probe
  def probe(source) when is_binary(source) do
    with {:ok, raw} <- Ffprobe.probe(source) do
      {:ok, reshape(raw)}
    end
  end

  defp reshape(%{"format" => format, "streams" => streams}) do
    video_stream = Enum.find(streams, fn s -> s["codec_type"] == "video" end)
    audio_stream = Enum.find(streams, fn s -> s["codec_type"] == "audio" end)

    base = %{
      kind: classify_kind(video_stream, audio_stream),
      has_video_track: video_stream != nil,
      has_audio_track: audio_stream != nil,
      duration_ms: parse_duration_ms(format),
      metadata: MetadataSanitizer.sanitize(raw_metadata(format, streams))
    }

    base
    |> maybe_put_dimensions(video_stream)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp classify_kind(nil, _audio), do: :audio
  defp classify_kind(_video, _audio), do: :video

  defp parse_duration_ms(%{"duration" => dur}) when is_binary(dur) do
    case Float.parse(dur) do
      {seconds, _} -> trunc(seconds * 1000)
      :error -> nil
    end
  end

  defp parse_duration_ms(_), do: nil

  defp maybe_put_dimensions(map, %{"width" => w, "height" => h})
       when is_integer(w) and is_integer(h),
       do: Map.merge(map, %{width: w, height: h})

  defp maybe_put_dimensions(map, _), do: map

  defp raw_metadata(format, streams) do
    %{
      "format" => Map.get(format, "tags", %{}),
      "streams" => Enum.map(streams, &Map.get(&1, "tags", %{}))
    }
  end
end
```

**Adapter (`lib/rindle/probe/image.ex`) — sketch only, libvips path:**

```elixir
defmodule Rindle.Probe.Image do
  @behaviour Rindle.Probe

  @image_mime_prefixes ["image/"]

  @impl Rindle.Probe
  def accepts?(content_type) when is_binary(content_type),
    do: Enum.any?(@image_mime_prefixes, &String.starts_with?(content_type, &1))
  def accepts?(_), do: false

  @impl Rindle.Probe
  def probe(source) when is_binary(source) do
    with {:ok, image} <- Image.open(source) do
      {:ok,
       %{
         kind: :image,
         width: Image.width(image),
         height: Image.height(image)
       }}
    end
  end
end
```

**Source:** Symmetry with `lib/rindle/processor.ex` and
`lib/rindle/processor/image.ex`. [VERIFIED: codebase read.]

### Pattern 4: Sanitizer Module Placement (D-19)

**Question:** Should sanitization live in `Rindle.AV.MetadataSanitizer` (new
standalone module) or as `Rindle.AV.Ffprobe.sanitize_container_metadata/1`
(pure function on the existing module)?

**Recommendation: Standalone module `Rindle.AV.MetadataSanitizer`.** Three
reasons:

1. **Separation of concerns.** `Rindle.AV.Ffprobe` is the FFprobe shim (Phase
   23). It owns argv construction, JSON parsing, and the existing HTML-escape
   pass. Adding "container-metadata sanitization" to its surface conflates
   "the FFprobe call" with "post-extraction normalization." The sanitizer is
   called from `Rindle.Probe.AVProbe`, not `Rindle.AV.Ffprobe` (D-20: "AFTER
   calling `Rindle.AV.Ffprobe.probe/1` and BEFORE writing into the asset's
   `metadata` JSONB"). The natural call site is the reshape adapter.

2. **Testability.** A standalone module unit-tests cleanly without subprocess
   mocking. The sanitizer's only inputs are strings/maps; a focused test file
   (`test/rindle/av/metadata_sanitizer_test.exs`) covers the boundary
   conditions in this Validation Architecture without pulling in FFprobe.

3. **Reusability.** Phase 26's `Content-Disposition` RFC 5987 path also needs
   "strip control chars from untrusted metadata" (success criterion 4 in
   `ROADMAP.md:103`). Hoisting the primitive to its own module lets Phase 26
   import it without taking a dependency on the FFprobe shim.

**Module shape (`lib/rindle/av/metadata_sanitizer.ex`):**

```elixir
defmodule Rindle.AV.MetadataSanitizer do
  @moduledoc """
  Container-metadata sanitization for untrusted FFprobe output.

  Two passes applied to every string value in a metadata map:

    1. Strip control characters in `\\x00-\\x1F` except `\\t`.
    2. Truncate to 1024 bytes (codepoint-aligned; no invalid UTF-8 emitted).

  This is layered ON TOP of `Rindle.AV.Ffprobe`'s HTML-escape (Phase 23).
  Both layers are intentional — Phase 23's escape is render-time defense in
  depth (output safety), Phase 24's truncate-and-strip is ingest-time
  stored-data hygiene (input safety). Do not collapse them. (CONTEXT.md D-21)
  """

  @max_bytes 1024
  # Control chars \\x00-\\x1F minus \\t (\\x09).
  @control_chars Enum.map(0x00..0x1F, &<<&1>>) -- [<<0x09>>]

  @spec sanitize(map() | list() | binary() | term()) :: map() | list() | binary() | term()
  def sanitize(value) when is_binary(value) do
    value
    |> strip_control_chars()
    |> truncate_to_bytes(@max_bytes)
  end

  def sanitize(value) when is_map(value),
    do: Map.new(value, fn {k, v} -> {k, sanitize(v)} end)

  def sanitize(value) when is_list(value), do: Enum.map(value, &sanitize/1)
  def sanitize(value), do: value

  @doc false
  def strip_control_chars(string) when is_binary(string),
    do: Enum.reduce(@control_chars, string, &String.replace(&2, &1, ""))

  @doc """
  Truncates `string` to at most `max_bytes` bytes, never emitting an
  incomplete UTF-8 codepoint. Works on Elixir 1.15+ (does NOT use
  `String.byte_slice/3`, which is 1.17+).

  ## Examples

      iex> Rindle.AV.MetadataSanitizer.truncate_to_bytes("héllo", 4)
      "hé"

      iex> Rindle.AV.MetadataSanitizer.truncate_to_bytes("hello", 1024)
      "hello"

      iex> Rindle.AV.MetadataSanitizer.truncate_to_bytes("héllo", 3)
      "h"
  """
  @spec truncate_to_bytes(String.t(), non_neg_integer()) :: String.t()
  def truncate_to_bytes(string, max_bytes)
      when is_binary(string) and is_integer(max_bytes) and max_bytes >= 0 do
    if byte_size(string) <= max_bytes do
      string
    else
      <<head::binary-size(max_bytes), _rest::binary>> = string
      drop_trailing_partial_codepoint(head)
    end
  end

  # If `head` ends mid-codepoint, peel back bytes one at a time until the
  # remaining binary is valid UTF-8. UTF-8 codepoints are at most 4 bytes,
  # so this loop runs at most 3 times.
  defp drop_trailing_partial_codepoint(<<>>), do: <<>>

  defp drop_trailing_partial_codepoint(bin) when is_binary(bin) do
    if String.valid?(bin) do
      bin
    else
      size = byte_size(bin)
      <<shorter::binary-size(size - 1), _::binary>> = bin
      drop_trailing_partial_codepoint(shorter)
    end
  end
end
```

**Why not `String.slice/3` or `String.byte_slice/3`?**

- `String.slice/3` operates on graphemes, not bytes. Slicing the first 1024
  graphemes can produce well over 1024 bytes (a 4-byte codepoint counts as 1
  grapheme). The requirement (AV-02-10, security invariant 10) is "1024
  bytes" — bytes, exactly.
- `String.byte_slice/3` solves this perfectly but was added in **Elixir 1.17**
  (CITED: hexdocs.pm/elixir/1.17/changelog.html). The project's CI matrix
  includes Elixir 1.15 (`.github/workflows/ci.yml:23`); using `byte_slice/3`
  drops the 1.15 lane. The hand-rolled
  `<<head::binary-size(max_bytes), _rest::binary>>` + UTF-8-validity rewind
  works on every Elixir version and matches what `byte_slice/3` does
  internally.

**Source:** Elixir docs (CITED: hexdocs.pm/elixir/String.html on
`String.byte_slice/3` 1.17 introduction); UTF-8 codepoint rewind is the
standard idiom (CITED: hexdocs.pm/elixir/1.17/changelog.html § "v1.17.0
String"). [VERIFIED: codepoint-rewind algorithm proves termination because
UTF-8 codepoints are ≤4 bytes.]

### Pattern 5: Per-Kind Changeset Validation (D-11)

**What:** `Rindle.Domain.MediaAsset.changeset/2` enforces field/kind
consistency: no `width`/`height` on `:audio`, no `duration_ms` or
`has_video_track` on `:image`. Specific error messages per field.

**When to use:** When typed columns are populated by an external probe and
must be coherent with the row's discriminator.

**Example:**

```elixir
# In lib/rindle/domain/media_asset.ex (extending the existing changeset/2)

@kinds ~w(image video audio)
# NB: matches @allowed_kinds in validator EXCEPT :waveform — :waveform is
# only an OUTPUT kind, never a source-asset kind.

@kind_field_invariants %{
  "image" => %{forbidden: [:duration_ms, :has_video_track, :has_audio_track]},
  "video" => %{forbidden: []},  # video may have or lack audio track
  "audio" => %{forbidden: [:width, :height, :has_video_track]}
}

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
    :profile,
    :kind,
    :width,
    :height,
    :duration_ms,
    :has_video_track,
    :has_audio_track,
    :error_reason
  ])
  |> validate_required([:state, :storage_key, :profile, :kind])
  |> validate_inclusion(:state, @states)
  |> validate_inclusion(:kind, @kinds)
  |> validate_kind_field_consistency()
  |> unique_constraint(:storage_key)
end

defp validate_kind_field_consistency(changeset) do
  case get_field(changeset, :kind) do
    nil -> changeset
    kind ->
      forbidden = get_in(@kind_field_invariants, [kind, :forbidden]) || []

      Enum.reduce(forbidden, changeset, fn field, acc ->
        case get_field(acc, field) do
          nil -> acc
          _ ->
            add_error(acc, field,
              "must be nil for kind=#{kind} (probe column not applicable)",
              kind: kind, field: field)
        end
      end)
  end
end
```

**Source:** Idiomatic Ecto pattern; `validate_inclusion/3` and
`add_error/4` are stable since Ecto 2.x. [CITED:
hexdocs.pm/ecto/Ecto.Changeset.html.] Existing precedent at
`lib/rindle/domain/media_asset.ex:88`.

### Pattern 6: Inline Probe Insertion with `try/after` Cleanup (D-16, D-17, D-18)

**What:** Insert MIME-dispatched probe step inline in `PromoteAsset`'s
`analyzing → promoting` body. Use `try/after` to guarantee tempfile deletion
even on probe failure or unexpected exception. `Rindle.Ops.OrphanReaper`
(Phase 23, 4h threshold) is the safety net.

**Why inline (D-18):** Single-job advances `validating → analyzing →
promoting → available` already (`promote_asset.ex:42-66`). Splitting probe
into a separate worker introduces two-worker coordination overhead and a
tempfile-handoff problem (job A downloads, job B probes — where does the
tempfile live across job boundaries?). Inline keeps the tempfile lifetime
inside one process.

**Cross-check Phase 23 OrphanReaper interaction:** The reaper sweeps files
in `Rindle.tmp/` older than 4h
(`lib/rindle/ops/orphan_reaper.ex:25-26`). The probe step's `try/after`
deletes on the happy/error paths; OrphanReaper catches anything missed (BEAM
crash mid-probe, OS-level kill, etc.). The probe MUST write tempfiles
under the same `tmp_dir` the reaper uses
(`Application.get_env(:rindle, :tmp_dir, System.tmp_dir!())` per
`orphan_reaper.ex:108-110`).

**Example (`lib/rindle/workers/promote_asset.ex` extension):**

```elixir
# Replace existing advance_to_promoting/2 for the validating clause
# (lib/rindle/workers/promote_asset.ex:56-66) with the new probe-bearing
# body. The existing analyzing-and-already-promoting clauses stay.

defp advance_to_promoting(repo, %{state: "validating"} = asset) do
  with :ok <- AssetFSM.transition(asset.state, "analyzing", %{asset_id: asset.id}),
       {:ok, asset} <-
         asset
         |> MediaAsset.changeset(%{state: "analyzing"})
         |> repo.update(),
       {:ok, asset} <- run_probe_step(repo, asset) do
    advance_to_promoting(repo, asset)
  else
    {:error, :probe_failed, reason} -> quarantine_asset(repo, asset, reason)
    {:error, reason} -> {:error, reason}
  end
end

defp run_probe_step(repo, asset) do
  tmp_path = Path.join(tmp_dir(), "rindle_probe_#{Ecto.UUID.generate()}")

  try do
    with :ok <- download_to(asset, tmp_path),
         {:ok, mime} <- Rindle.Security.Mime.detect(tmp_path),
         {:ok, probe_module} <- dispatch_probe(mime),
         {:ok, result} <- probe_module.probe(tmp_path),
         {:ok, asset} <- write_probe_result(repo, asset, mime, result) do
      {:ok, asset}
    else
      {:error, reason} -> {:error, :probe_failed, reason}
    end
  after
    _ = File.rm(tmp_path)  # always delete; OrphanReaper is the safety net
  end
end

defp dispatch_probe(mime) do
  cond do
    Rindle.Probe.AVProbe.accepts?(mime) -> {:ok, Rindle.Probe.AVProbe}
    Rindle.Probe.Image.accepts?(mime)   -> {:ok, Rindle.Probe.Image}
    true -> {:error, {:no_probe_for_mime, mime}}
  end
end

defp write_probe_result(repo, asset, mime, result) do
  attrs =
    result
    |> Map.put(:content_type, mime)
    # :metadata is already sanitized by Rindle.Probe.AVProbe (D-20).

  asset
  |> MediaAsset.changeset(attrs)
  |> repo.update()
end

defp quarantine_asset(repo, asset, reason) do
  reason_string = inspect(reason)

  with :ok <- AssetFSM.transition(asset.state, "quarantined",
                %{asset_id: asset.id, reason: reason_string}),
       {:ok, _} <-
         asset
         |> MediaAsset.changeset(%{state: "quarantined", error_reason: reason_string})
         |> repo.update() do
    {:error, {:quarantined, reason}}
  end
end

defp tmp_dir, do: Application.get_env(:rindle, :tmp_dir, System.tmp_dir!())

defp download_to(asset, path) do
  # Storage adapter download — concrete shape lives in the storage behaviour;
  # the existing image flow already does this in ProcessVariant
  # (lib/rindle/workers/process_variant.ex:85). Reuse the same primitive.
end
```

**Source:** `try/after` is the canonical Elixir resource-cleanup idiom
(CITED: hexdocs.pm/elixir/Kernel.SpecialForms.html#try/1). OrphanReaper
threshold of 4h matches SYNTHESIS §2.9 default. [VERIFIED:
`lib/rindle/ops/orphan_reaper.ex:108-110`.]

### Pattern 7: FSM Additive Transitions (D-09, D-10)

**What:** Both FSMs are plain `@allowed_transitions` maps + a single
`transition/3` function. Adding states is purely additive: append to the map,
add the new state to `@states`, add tests asserting the new edges work AND
the old edges still work.

**Asset FSM extension (`lib/rindle/domain/asset_fsm.ex:6-17`):**

```elixir
@allowed_transitions %{
  "staged" => ["validating"],
  "validating" => ["analyzing"],
  "analyzing" => ["promoting", "quarantined"],   # NEW: + quarantined (probe-fail)
  "promoting" => ["available"],
  "available" => ["processing", "transcoding", "quarantined"],  # NEW: + transcoding
  "processing" => ["ready", "quarantined"],
  "transcoding" => ["ready", "degraded", "quarantined"],         # NEW: terminal-fan
  "ready" => ["degraded", "deleted"],
  "degraded" => ["quarantined", "deleted"],
  "quarantined" => ["deleted"],
  "deleted" => []
}
```

**Note vs CONTEXT.md D-09:** D-09 lists `"analyzing" => ["promoting"]`
unchanged. AV-02-09 requires probe-failure to send the asset to
`quarantined` from `analyzing`. The existing edge map at `:6-17` only allows
`analyzing → promoting`. So the plan MUST also add `analyzing → quarantined`
(the `try/after` quarantine path in Pattern 6 transitions FROM `analyzing`).
**This is a deviation from D-09 and a load-bearing addition.** Flag for
plan-checker review.

**Variant FSM extension (`lib/rindle/domain/variant_fsm.ex:4-13`):**

```elixir
@allowed_transitions %{
  "planned" => ["queued", "cancelled"],          # NEW: + cancelled
  "queued" => ["processing", "cancelled"],       # NEW: + cancelled
  "processing" => ["ready", "failed", "cancelled"], # NEW: + cancelled
  "ready" => ["stale", "missing", "purged"],
  "stale" => ["queued", "purged"],
  "missing" => ["queued", "purged"],
  "failed" => ["queued", "purged"],
  "cancelled" => [],                              # NEW: terminal
  "purged" => []
}
```

**Invariants to prove in tests** (extending
`test/rindle/domain/lifecycle_fsm_test.exs:13-44`):

```elixir
describe "asset transition matrix — additive (Phase 24)" do
  test "available → transcoding is allowed (NEW edge)" do
    assert :ok == AssetFSM.transition("available", "transcoding")
  end

  test "transcoding → ready/degraded/quarantined are allowed (NEW edges)" do
    assert :ok == AssetFSM.transition("transcoding", "ready")
    assert :ok == AssetFSM.transition("transcoding", "degraded")
    assert :ok == AssetFSM.transition("transcoding", "quarantined")
  end

  test "analyzing → quarantined is allowed (NEW; probe-failure path)" do
    assert :ok == AssetFSM.transition("analyzing", "quarantined")
  end

  # LOAD-BEARING REGRESSION GUARDS — existing edges UNCHANGED
  test "available → processing still allowed (image flow regression guard)" do
    assert :ok == AssetFSM.transition("available", "processing")
  end

  test "available → quarantined still allowed (regression guard)" do
    assert :ok == AssetFSM.transition("available", "quarantined")
  end

  test "processing → ready still allowed (regression guard)" do
    assert :ok == AssetFSM.transition("processing", "ready")
  end

  test "transcoding → ready/degraded/quarantined ONLY (no other terminal)" do
    refute :ok == AssetFSM.transition("transcoding", "deleted")
    refute :ok == AssetFSM.transition("transcoding", "available")
  end
end

describe "variant transition matrix — additive (Phase 24)" do
  test "queued/processing/planned each gain → cancelled (NEW)" do
    assert :ok == VariantFSM.transition("queued", "cancelled")
    assert :ok == VariantFSM.transition("processing", "cancelled")
    assert :ok == VariantFSM.transition("planned", "cancelled")
  end

  test "cancelled is terminal (NEW)" do
    refute :ok == VariantFSM.transition("cancelled", "queued")
    refute :ok == VariantFSM.transition("cancelled", "purged")
    refute :ok == VariantFSM.transition("cancelled", "ready")
  end

  # REGRESSION GUARDS
  test "ready → stale/missing/purged still allowed" do
    assert :ok == VariantFSM.transition("ready", "stale")
    assert :ok == VariantFSM.transition("ready", "missing")
    assert :ok == VariantFSM.transition("ready", "purged")
  end
end
```

**Source:** Existing FSM tests at
`test/rindle/domain/lifecycle_fsm_test.exs:13-73`. [VERIFIED: codebase read.]

### Anti-Patterns to Avoid

- **Persisting `:kind` for image-default profiles.** Any place the validator
  output map carries `kind: :image` for a v1.0-shape variant breaks digest
  parity (D-14). Catch this in the load-bearing snapshot test.
- **Using `String.slice/3` for byte-bounded truncation.** `String.slice/3`
  operates on graphemes; "1024 bytes" requires byte arithmetic. Use the
  `binary-size` + UTF-8-validity rewind primitive in
  `Rindle.AV.MetadataSanitizer`.
- **Using `String.byte_slice/3`.** Available on Elixir 1.17+; the CI matrix
  includes 1.15. Will compile-fail the 1.15 lane.
- **Renaming `Rindle.AV.Probe` to `Rindle.Probe`.** D-05 explicitly keeps the
  boot probe distinct. Different lifetimes, different call sites.
- **Adding probe step as a separate Oban worker.** D-18 explicitly rejects
  this; tempfile coordination across two workers is harder and adds latency.
- **Sanitizing inside `Rindle.AV.Ffprobe`.** Conflates the FFprobe shim's
  responsibility (subprocess + JSON parse + HTML escape from Phase 23) with
  ingest-time hygiene. Sanitize in `Rindle.Probe.AVProbe` adapter (D-20).
- **Removing FFprobe HTML-escape (Phase 23 layer).** D-21 keeps both layers;
  they serve different purposes (render-time vs. ingest-time).
- **Using PG `CREATE TYPE` enums for `:kind` / `:output_kind`.** No precedent
  in any of the 8 existing migrations; D-01 explicitly chose `:string` +
  `Ecto.Enum` (or `validate_inclusion`) at the schema layer.
- **Touching `Rindle.Profile.Digest` to filter `:kind`.** Cross-cutting
  concern bleed; the validator owns what's hashable (Pattern 2).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Per-kind variant option validation | Hand-rolled `case kind` switches in the validator | `NimbleOptions.validate!/2` with a per-kind schema attribute (Pattern 1) | Already in tree; produces well-formatted errors; documents itself |
| MIME detection | Custom byte-prefix matchers | `Rindle.Security.Mime.detect/1` (Phase 1; ExMarcel 8KB sniff) | 8KB magic-byte sniffing + extension cross-check; battle-tested |
| FFprobe JSON parsing | Custom parser | `Jason.decode/1` (already used at `Rindle.AV.Ffprobe:34`) | Standard, tested |
| Tempfile cleanup | Manual `try/rescue` of every error path | `try/after` + `Rindle.Ops.OrphanReaper` (4h safety net) | `after` runs on every exit path including raises; OrphanReaper catches BEAM-death cases |
| FSM library | `:gen_statem`, `Machinery`, `gen_state_machine` | The existing `@allowed_transitions` map idiom | Two FSMs already use this; consistency wins; additive changes are 3-line edits |
| Recipe digest function | New SHA computation | `Rindle.Profile.Digest.for_variant/2` (unchanged) | Already deterministic; load-bearing for backward compat |
| Argv construction for FFprobe | String interpolation | `Rindle.AV.Subprocess` (Phase 23, MuonTrap-wrapped) | Argv-array discipline (security invariant 8) |
| `:kind` enum at the DB level | `CREATE TYPE` migrations | `:string` + `validate_inclusion` (precedent) OR `Ecto.Enum` (D-01) | No PG-enum precedent in the project; either schema-layer choice keeps ops simple |
| UTF-8-safe byte truncation | DIY codepoint table | The 4-line `binary-size` + `String.valid?/1` rewind in Pattern 4 | Standard idiom; UTF-8 ≤4 bytes per codepoint guarantees ≤3-iteration loop |

**Key insight:** Phase 24 is almost entirely an exercise in **composition of
existing primitives**. The only genuinely new primitives are
`Rindle.Probe` (3-line behaviour), the per-kind schemas (4 keyword lists),
and `Rindle.AV.MetadataSanitizer.truncate_to_bytes/2` (8 lines). Everything
else is wiring.

## Runtime State Inventory

> Phase 24 is an additive feature, not a rename or migration of state. This
> section is included to be exhaustive about what already exists in the
> field that the planner should NOT touch.

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | Existing `media_assets` rows have `metadata: %{}` (default per `:11` in migration); no `kind` column today; `media_variants` has no `output_kind` today. **Action:** column defaults `default: "image"` (D-01) make existing rows valid pre-deploy with no backfill (D-04). | None — defaults handle it |
| Live service config | None — Phase 24 has no external service registrations (no n8n, no Datadog, no Cloudflare Tunnel). | None — verified by codebase grep returning zero matches for service-config directories |
| OS-registered state | None — no Windows Task Scheduler, pm2, launchd, or systemd registrations. | None |
| Secrets/env vars | None — no new env var names introduced. Phase 23's `RINDLE_TMP_DIR` (or `:tmp_dir` Application env) is reused as-is. | None |
| Build artifacts | None — pure Elixir; `mix compile` regenerates everything. | None |

## Common Pitfalls

### Pitfall 1: Recipe-digest drift on upgrade (P0)

**What goes wrong:** v1.4 upgrade flips every existing image variant to
`stale` because the digest changed.

**Why it happens:** The validator persists `:kind => :image` into the
validated variant map (either as the default, or because it was dropped only
when not explicitly declared but image-default profiles passed through
NimbleOptions which inserted the default value). The digest function hashes
the map; one extra key changes the hash.

**How to avoid:** (1) `maybe_put_kind/3` MUST omit `:kind` for ALL `:image`
cases (default OR explicit) — see Pattern 1. (2) The load-bearing snapshot
test (Pattern 2) catches drift in CI before merge.

**Warning signs:** A new line `:kind` appears in the output of
`Profile.variants()` for an image-only profile in tests. The existing
`profile_test.exs:50` test (`variants/0 returns deterministic named
entries`) passes only `banner.mode == :crop` — it doesn't assert the
absence of `:kind`. Add an explicit `refute Map.has_key?(banner, :kind)`
to that test.

### Pitfall 2: Tempfile leak on probe failure

**What goes wrong:** `Rindle.tmp/` accumulates probed-but-failed sources.
Disk pressure builds. OrphanReaper sweeps after 4h, but in the interim
disk-full risk grows.

**Why it happens:** Probe step uses `with` chain; on `{:error, ...}` the
function exits without deleting the tempfile. `try/after` is omitted.

**How to avoid:** Always wrap the probe body in `try ... after _ =
File.rm(tmp_path) end`. See Pattern 6.

**Warning signs:** A test that simulates probe failure (mock `Rindle.Probe.AVProbe.probe/1` returning `{:error, _}`) leaves a file in
`System.tmp_dir!()`. Add an assertion: `refute File.exists?(tmp_path)`.

### Pitfall 3: Byte-truncation produces invalid UTF-8

**What goes wrong:** `metadata.title` arrives as 1500 bytes of UTF-8 with a
multi-byte character spanning bytes 1023-1025. Naïve truncation at byte 1024
emits a 1024-byte binary that ends with the first 2 bytes of a 3-byte
codepoint. PostgreSQL's `:map`/JSONB column rejects it (or worse, accepts
silently and the row reads back as `<<...invalid bytes...>>`).

**Why it happens:** `binary_part(string, 0, 1024)` doesn't know about UTF-8.
`String.slice/3` knows about graphemes but cuts at grapheme positions
(unbounded byte length).

**How to avoid:** `<<head::binary-size(max_bytes), _rest::binary>>` followed
by `String.valid?/1` rewind (Pattern 4). The loop runs ≤3 times because
UTF-8 codepoints are at most 4 bytes.

**Warning signs:** A property test feeding random binaries to
`MetadataSanitizer.truncate_to_bytes/2` and checking
`String.valid?/1 == true` for every output finds a counterexample.

### Pitfall 4: Per-kind schema rejects valid `:kind` for waveform

**What goes wrong:** The plan adds `:waveform` to the `media_assets.kind`
enum (since the typed column is `kind`). But `:waveform` is an OUTPUT kind
only — there's no such thing as a `:waveform` source asset. The asset's
`kind` enum should be `[:image, :video, :audio]`; the variant's
`output_kind` enum is `[:image, :video, :audio, :waveform]`.

**Why it happens:** Conflating the two enums. SYNTHESIS §2.2 is explicit:
"Single `media_assets` table + `kind` enum (`:image | :video | :audio`).
Single `media_variants` table + `output_kind` enum (`:image | :video |
:audio | :waveform`)."

**How to avoid:** Two separate `@kinds` lists. `MediaAsset.@kinds = ~w(image
video audio)`. `MediaVariant.@output_kinds = ~w(image video audio
waveform)`. The variant DSL `:kind` discriminator (`@allowed_kinds` in the
validator) is `[:image, :video, :audio, :waveform]` because waveform IS a
declarable variant kind. Three separate enums; same-shaped but different
domains.

**Warning signs:** A profile declaring `variants: [peaks: [kind: :waveform,
peaks: 1000]]` compiles but the resulting `media_variants` row has
`output_kind: :waveform` while the `media_assets.kind` column rejects
`waveform` for the source asset (correctly). The DSL accepts; the source
asset's kind is unchanged (audio source for a waveform variant is still
`audio`). This is the right behavior; the pitfall is conflating the three
enums into one.

### Pitfall 5: `analyzing → quarantined` edge missing

**What goes wrong:** Probe fails; quarantine path tries to transition
`analyzing → quarantined`; FSM rejects (current map only allows `analyzing →
promoting`); function returns error; asset stuck in `analyzing` forever.

**Why it happens:** D-09 lists "`analyzing` => [`promoting`]" unchanged. But
AV-02-09 requires probe-failure to send asset to `quarantined`, and the
probe runs FROM `analyzing`. The transition map needs the new edge.

**How to avoid:** Pattern 7's asset FSM extension explicitly adds
`"analyzing" => ["promoting", "quarantined"]`. **Flag for plan-checker:
this deviates from D-09's literal text but is required by AV-02-09's intent.**
The CONTEXT.md author missed this edge; the plan must include it.

**Warning signs:** An integration test for `Rindle.Workers.PromoteAsset`
where the probe is mocked to fail produces a `{:error,
{:invalid_transition, "analyzing", "quarantined"}}` log line.

## Code Examples

### Migration (`priv/repo/migrations/20260502NNNNNN_extend_media_for_av.exs`)

```elixir
defmodule Rindle.Repo.Migrations.ExtendMediaForAv do
  @moduledoc """
  Phase 24 — additive migration for AV support.

  Image-only adopters: existing rows valid pre-deploy via column defaults.
  No data backfill (D-04). No `disable_ddl_transaction`, no `lock_timeout`,
  matching every prior migration.
  """
  use Ecto.Migration

  def change do
    alter table(:media_assets) do
      add :kind, :string, null: false, default: "image"
      add :width, :integer
      add :height, :integer
      add :duration_ms, :bigint
      add :has_video_track, :boolean
      add :has_audio_track, :boolean
      add :error_reason, :text
    end

    alter table(:media_variants) do
      add :output_kind, :string, null: false, default: "image"
      add :duration_ms, :bigint
      add :width, :integer
      add :height, :integer
    end

    create index(:media_assets, [:kind])
    create index(:media_variants, [:output_kind])
  end
end
```

### MediaVariant Schema Extension

```elixir
# In lib/rindle/domain/media_variant.ex

@output_kinds ~w(image video audio waveform)

schema "media_variants" do
  field :name, :string
  field :state, :string, default: "planned"
  field :recipe_digest, :string
  field :storage_key, :string
  field :byte_size, :integer
  field :content_type, :string
  field :error_reason, :string
  field :generated_at, :utc_datetime_usec
  field :output_kind, :string, default: "image"
  field :duration_ms, :integer
  field :width, :integer
  field :height, :integer

  belongs_to :asset, Rindle.Domain.MediaAsset

  timestamps()
end

def changeset(variant, attrs) do
  variant
  |> cast(attrs, [
    :asset_id, :name, :state, :recipe_digest, :storage_key,
    :byte_size, :content_type, :error_reason, :generated_at,
    :output_kind, :duration_ms, :width, :height
  ])
  |> validate_required([:asset_id, :name, :state, :recipe_digest, :output_kind])
  |> validate_inclusion(:state, @states)
  |> validate_inclusion(:output_kind, @output_kinds)
  |> foreign_key_constraint(:asset_id)
  |> unique_constraint([:asset_id, :name])
end
```

### Validator Test for AV-02-08 (`from_variant` rejection)

```elixir
test "from_variant in any variant spec raises at compile time (AV-02-08)" do
  assert_raise ArgumentError, ~r/cross-variant chaining is not supported/, fn ->
    Code.compile_string("""
    defmodule #{unique_module_name("InvalidProfileFromVariant")} do
      use Rindle.Profile,
        storage: Rindle.StorageMock,
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        variants: [
          hero: [mode: :fit, width: 1200],
          poster: [kind: :image, mode: :fit, width: 320, from_variant: :hero]
        ]
    end
    """)
  end
end
```

## State of the Art

### Peer-Library Lessons for Per-Kind Variant Declaration

| Library | What They Do | Lesson for Rindle Phase 24 |
|---|---|---|
| **Rails Active Storage variants** ([CITED](https://edgeapi.rubyonrails.org/classes/ActiveStorage/Variant.html)) | Variants are **image-only**; videos/PDFs use `representation` which falls back to `preview` (poster generation). `preprocessed: true` raises `InvariableError` on video. Rails 7.1 added `TransformJob` pre-processing of videos/PDFs. | **Don't repeat the Active Storage mistake**: Active Storage's variant API was retrofitted onto a model that assumed image-only. Adopters who declared a `:thumb` variant on a video attachment got runtime errors years after writing the code. Rindle's per-kind discriminator at the DSL boundary catches this at compile time. |
| **Shrine `:derivatives` plugin** ([CITED](https://shrinerb.com/docs/plugins/derivatives)) | Multi-named processors. Adopters write conditional `case content_type` blocks to dispatch to image vs. video processing. Closer to Rindle's shape. | **Adopt Shrine's clean separation**: separate processing pipelines per file type. **Avoid Shrine's punt**: Shrine makes the dispatch the adopter's responsibility (custom `case content_type` in adopter code). Rindle bakes the dispatch into the DSL via `:kind`, so the adopter writes declarative `kind: :video` instead of imperative `if content_type =~ "video"`. |
| **CarrierWave `process` callbacks** ([CITED](https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-use-callbacks)) | `process :method, if: :is_image?` style. Adopters declare a method per file type and a guard predicate per `process` call. | **Avoid the predicate-on-every-process anti-pattern**: leads to copy-paste guards across 5+ `process` lines. Rindle's per-variant `:kind` is more declarative — one declaration per variant, not one guard per processor invocation. |
| **Spatie laravel-medialibrary** | "Conversions" defined per file type via separate methods on the model. | **Backward-compat lesson**: Spatie's older API conflated image/video; the v8+ rewrite split conversions per file type explicitly. Rindle does this from the start. |
| **Django imagekit** ([CITED](https://django-imagekit.readthedocs.io/)) | `ImageSpec` classes with class-attribute `processors`. Static declaration, no dispatcher. Pure-image scope (no video). | **Lesson on naming**: `ImageSpec` baked image-ness into the name; expanding to video required parallel classes (`VideoSpec`?) that didn't exist. Rindle's `Rindle.Profile` is type-agnostic — `:kind` is data, not class hierarchy. |
| **Node Sharp / multer-thumbnail** | Image-only. Video tooling lives in separate libraries (fluent-ffmpeg). | **Lesson on scope**: bundling image and video processors in the same library is uncommon in Node. Rindle taking on both via discriminator is more like Spatie/Shrine than Sharp. |

**Takeaways for Phase 24:**

1. **Per-kind option validation at compile time** is what every mature library
   adds eventually (Active Storage representation/preview split, Spatie v8,
   Shrine derivatives). Rindle skipping the v1.0-style image-only validator
   altogether and replacing it with a per-kind dispatcher is the correct
   long-term shape.
2. **Backward-compat for image-only profiles** — every library that added
   video later had to handle "old syntax." Active Storage chose runtime
   `InvariableError`; Spatie introduced new conversion classes; Shrine just
   says "your conditional-dispatch code keeps working." Rindle's choice
   (default `:kind => :image` when omitted) is the cleanest: zero adopter
   code changes, zero new branches in adopter code.
3. **Per-kind output declarations** (`:output_kind` on variant) — none of the
   peers do this cleanly. Active Storage has implicit "if input is video,
   output is image (preview)." Shrine punts to adopter conditionals. Rindle's
   explicit `:output_kind` (computed from `:kind` of the variant declaration:
   `:image` source + `:image` variant = same kind out; `:video` source +
   `:image` variant kind = poster; etc.) is novel and operator-queryable.
   This is a Rindle-specific advantage worth documenting.

### Old vs. Current Approach

| Old Approach (Rindle v1.0–v1.3) | Current Approach (v1.4) | When Changed | Impact |
|---|---|---|---|
| Single `@variant_schema` for image-only | Per-kind schema dispatched by `:kind` | Phase 24 | DSL extends without breaking; image profiles compile unchanged |
| Source-asset `kind` implicit (image only) | Explicit `:kind` enum on `media_assets` | Phase 24 | Operator queries (`WHERE kind = 'video'`) become typed |
| Variant output type implicit | Explicit `:output_kind` enum on `media_variants` | Phase 24 | Cross-kind workflows (video → poster image) become first-class |
| FSM transitions: `available → processing → ready/quarantined` | Adds `available → transcoding → ready/degraded/quarantined` parallel branch | Phase 24 | Image flow byte-for-byte unchanged; video flow has its own retry/timeout posture (Phase 25) |
| Phase 23 FFprobe HTML-escape only | Phase 23 HTML-escape + Phase 24 truncate-and-strip layered | Phase 24 (additive) | Defense in depth; both layers preserved per D-21 |

**Deprecated/outdated:** None — Phase 24 is purely additive.

## Project Constraints (from CLAUDE.md)

`./CLAUDE.md` does not exist in the working directory. The applicable
constraints come from `.planning/PROJECT.md` (security invariants 1-13) and
the per-phase decisions in `24-CONTEXT.md` (D-01 through D-23). Specifically:

- **Security invariant 8:** Argv-array discipline (Phase 23 already enforces
  via `Rindle.AV.Subprocess`).
- **Security invariant 10:** Container metadata is untrusted; truncate +
  control-char strip at ingest; adopters MUST sanitize on render. **Phase 24
  is the implementation point for the ingest-side primitive.**
- **Security invariant 13:** Tempfiles under `Rindle.tmp/`; OrphanReaper
  sweeps. **Phase 24's probe step writes there explicitly.**
- **PROJECT.md "named presets only by default" extends to v1.4 verbatim**
  (SYNTHESIS §2.3): video/audio per-kind schemas use `{:in, [...]}` atom
  enums for codec/container/format — no string passthrough.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | `Ecto.Enum` is available transitively via `ecto`, but the project's existing precedent is `:string` + `validate_inclusion`. The planner picks. CONTEXT.md D-01 mentions "Ecto.Enum at the schema layer for atom mapping" — the planner may interpret this as a directive. | Standard Stack | Either choice works; if the planner picks `Ecto.Enum`, the test patterns must change slightly (atom values at the boundary). Symmetry argues for `:string`. |
| A2 | Per-kind schema bodies for `:video`, `:audio`, `:waveform` (Pattern 1) are derived from SYNTHESIS §2.4 in/out scope and §2.3 named-presets-only. The actual Phase 25 codec/preset shape may force minor adjustments (e.g., `:web_480p` may not ship in v1.4). | Pattern 1 | Schema keys may need pruning during Phase 25; today's schemas are forward-leaning. The `:preset` allowlist is the most likely to change. |
| A3 | DEL char `\x7F` is not stripped by `Rindle.AV.MetadataSanitizer` because D-19 specifies only `\x00-\x1F` minus `\t`. Newlines (`\n`, `\r`) ARE stripped because they fall in `\x00-\x1F` and are not exception-listed. | Pattern 4 | If the user wants to keep newlines (titles often have them), D-19 needs amending. The literal interpretation strips them, which is the safer ingest-time default — adopter renders the title as a single line anyway. |
| A4 | `analyzing → quarantined` edge MUST be added to `AssetFSM.@allowed_transitions`. CONTEXT.md D-09 didn't list this, but AV-02-09 requires it for the probe-failure path. **This is the only known deviation from D-09's literal text.** | Pattern 7, Pitfall 5 | If wrong, the probe-failure path can't transition the asset; a separate state-corruption fix would be needed. The deviation is small and required by AV-02-09's text. |
| A5 | `MediaAsset.@kinds` has THREE values (`image`, `video`, `audio`) while the variant DSL `:kind` and `MediaVariant.@output_kinds` have FOUR (`image`, `video`, `audio`, `waveform`). `:waveform` is an output-only kind. SYNTHESIS §2.2 confirms. | Pitfall 4 | If the planner accidentally adds `:waveform` to `MediaAsset.@kinds`, no immediate harm — there's no path that creates a waveform-source-asset row — but the schema becomes misleading. |
| A6 | `Rindle.AV.MetadataSanitizer` is a standalone module (not pure function on `Rindle.AV.Ffprobe`). Recommendation made on test-isolation, separation-of-concerns, and Phase 26 reuse grounds. The user marked this "planner picks" (CONTEXT.md, Claude's Discretion section). | Pattern 4 | Either choice works; the standalone module is more reusable but adds one file. |
| A7 | The v1.3 `:thumb` digest snapshot value (`@v13_thumb_digest`) MUST be captured in plan 1 task 1 BEFORE any validator.ex edits. The plan must include this as a discrete step (`mix run -e 'IO.puts(...)'` on a clean v1.3 checkout, capture into the test file). | Pattern 2 | If captured AFTER validator changes, the snapshot is whatever the new validator produces — not a regression guard. Plan ordering is load-bearing. |
| A8 | Probe step downloads source via the existing storage adapter (same primitive `ProcessVariant` uses at `lib/rindle/workers/process_variant.ex:85`). The exact storage download API may need a small extraction/refactor if `ProcessVariant` does it inline today. | Pattern 6 | If the download primitive is hard-coded inside ProcessVariant, the planner extracts it into a shared helper; this is a small refactor task. |

## Open Questions

1. **Should `:kind` ever appear in the validated variant spec for `:video` /
   `:audio` / `:waveform`?** Pattern 1 sets `maybe_put_kind/3` to persist
   `:kind` for non-image kinds (so `MediaVariant.changeset/2` can route by
   it). But this creates an asymmetry with `:image` (where `:kind` is
   omitted for digest stability). **Recommendation:** persist `:kind` for
   non-image kinds; the digest stability invariant only matters for image
   profiles (no v1.0 video/audio profiles exist to be regressed).
   - What we know: image-default profiles MUST omit `:kind` from the digested
     map (D-14).
   - What's unclear: whether `:kind` for non-image variants in the digested
     map is desirable or a bug.
   - Recommendation: omit for image, persist for video/audio/waveform. The
     digest stability concern is image-specific.

2. **What happens to a `:waveform` source detection?** The probe dispatches
   by MIME. Audio MIMEs go to `Rindle.Probe.AVProbe`. The probe returns
   `kind: :audio` for audio sources. There's never a "waveform source." A
   waveform variant of an audio asset is a row in `media_variants` with
   `output_kind: :waveform`, generated by `Rindle.Processor.AV` (Phase 25).
   Phase 24 has no waveform-specific runtime path — only the DSL declaration
   and the `output_kind` enum value. **Confirm this is the intent.**
   - What we know: SYNTHESIS §2.2 confirms `output_kind: :waveform`.
   - What's unclear: Whether Phase 24 needs any waveform-specific code at
     all beyond the DSL schema and the enum value.
   - Recommendation: ship the schema + the enum value in Phase 24; leave the
     processor work for Phase 25. No Phase 24 code reads `output_kind ==
     :waveform`.

3. **Should the per-kind validator support a `:custom` escape hatch for
   adopters who need an unusual codec/container?** Currently, the schemas
   are atom enums (`{:in, [...]}`). An adopter who wants, e.g., `:vp9` for a
   custom Phase 25-style processor cannot declare it.
   - What we know: SYNTHESIS §2.3 is unambiguous: "named presets only by
     default. PROJECT.md's named-presets-only invariant extends to v1.4
     verbatim."
   - What's unclear: nothing — the locked decision is "no custom codecs in
     v1.4."
   - Recommendation: do NOT add a `:custom` escape hatch in Phase 24. Defer
     to v1.5 if adopter feedback requests it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir | All Phase 24 code | ✓ | ~> 1.15 (CI matrix: 1.15, 1.17) | — |
| OTP | All Phase 24 code | ✓ | 26 (Elixir 1.15) / 27 (Elixir 1.17) | — |
| `nimble_options` | Per-kind schema dispatch | ✓ | ~> 1.1 (in `mix.exs`) | — |
| `ecto`/`ecto_sql` | Migration + schemas | ✓ | ~> 3.11 | — |
| `jason` | Digest, FFprobe parse | ✓ | (transitive) | — |
| PostgreSQL | Migration target | ✓ (CI + dev) | as configured | — |
| FFprobe (system binary) | `Rindle.Probe.AVProbe` runtime | Conditional | ≥ 6.0 (Phase 23 boot probe enforces) | If missing on adopter machine: image-only profiles work; video/audio profiles fail at boot probe (Phase 23 contract). |
| MinIO | Adopter parity test (`lifecycle_test.exs`) | ✓ in CI; conditional locally | as configured | Local devs without MinIO can run `mix test --exclude adopter` |

**Missing dependencies with no fallback:** None for Phase 24 itself — every
primitive needed is either pure Elixir or already in tree.

**Missing dependencies with fallback:** FFprobe is required only when an
adopter declares video/audio variants. Image-only profiles never call
`Rindle.Probe.AVProbe.probe/1`. The probe-step dispatch in `PromoteAsset`
runs `Rindle.Probe.Image.accepts?/1` first for image MIMEs — if the asset is
an image, FFprobe is never invoked.

## Security Domain

> Required — `security_enforcement` is enabled (no config override).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | Not in Phase 24 scope |
| V3 Session Management | no | Not in Phase 24 scope |
| V4 Access Control | no | Variant access stays in `Rindle.Delivery` (Phase 26) |
| V5 Input Validation | yes | NimbleOptions per-kind schemas (compile-time); `Rindle.Security.Mime.detect/1` (8KB magic-byte sniff) at probe-dispatch time; `Rindle.AV.MetadataSanitizer` for FFprobe output |
| V6 Cryptography | n/a | No new crypto surface; SHA-256 in `Rindle.Profile.Digest` is unchanged and used only for deterministic identifiers, not security |
| V7 Error Handling | yes | `error_reason :text` on `media_assets` (D-02) carries quarantine reason; never echoes user-controlled content unsafely (it's stored, not rendered, and adopters render it through their own pipeline) |
| V11 Business Logic | yes | FSM additive transitions enforce that probe-failure leads ONLY to quarantine (not to `available` or `ready`); recipe digest stability prevents silent regeneration of every adopter's variants on upgrade |

### Known Threat Patterns for {Phase 24 stack}

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Container metadata XSS via FFprobe-extracted titles | Tampering, Information Disclosure | Phase 23 HTML-escape (render-time defense) + Phase 24 truncate+control-strip (ingest-time hygiene) — both layers, both preserved (D-21) |
| Untrusted FFprobe JSON producing oversized titles → JSONB column bloat / DOS | Denial of Service | `Rindle.AV.MetadataSanitizer.truncate_to_bytes/2` 1024-byte cap per string field (AV-02-10) |
| Profile DSL accepting arbitrary `:codec`/`:container` strings → argv injection class | Tampering | NimbleOptions `{:in, [:atom_list]}` validation; no string passthrough (security invariant 8 + SYNTHESIS §2.3 named-presets-only) |
| Cross-variant chaining via `:from_variant` allowing constructed input file paths | Tampering | Compile-time AV-02-08 rejection of `:from_variant` in any variant spec (D-15) |
| Tempfile leak in `Rindle.tmp/` accumulating untrusted content | Denial of Service | `try/after` cleanup in probe step + `OrphanReaper` 4h safety net (Phase 23) |
| Probe-step exit without state transition → asset stuck in `analyzing` | Denial of Service (functional) | FSM `analyzing → quarantined` edge (Pattern 7); supervisor + Oban retries on transient failures |
| Recipe-digest drift on upgrade silently regenerating every adopter's variants | (Operational impact, not security per se, but P0 regression class) | Load-bearing v1.3 digest snapshot test (D-14, D-22, D-23) |
| Invalid UTF-8 in JSONB column from naïve byte truncation | Tampering (data corruption) | Codepoint-aligned `binary-size` + `String.valid?/1` rewind (Pattern 4) |
| Migration adds `null: false` without default → existing rows reject | Denial of Service (deployment) | `default: "image"` on both `kind` and `output_kind` (D-01, D-04) |

## Sources

### Primary (HIGH confidence)
- Codebase: `lib/rindle/profile/validator.ex` (lines 50-71, 186-208, 224)
- Codebase: `lib/rindle/profile/digest.ex` (full file)
- Codebase: `lib/rindle/profile.ex` (full file)
- Codebase: `lib/rindle/domain/asset_fsm.ex`, `variant_fsm.ex`, `media_asset.ex`, `media_variant.ex`
- Codebase: `lib/rindle/av/ffprobe.ex`, `lib/rindle/av/probe.ex`, `lib/rindle/av/subprocess.ex`
- Codebase: `lib/rindle/processor.ex`, `lib/rindle/processor/image.ex`
- Codebase: `lib/rindle/workers/promote_asset.ex` (lines 42-66)
- Codebase: `lib/rindle/security/mime.ex`, `lib/rindle/ops/orphan_reaper.ex`
- Codebase: `priv/repo/migrations/*.exs` (8 prior migrations)
- Codebase: `test/rindle/domain/lifecycle_fsm_test.exs`, `test/rindle/profile/profile_test.exs`
- Codebase: `test/adopter/canonical_app/profile.ex`, `lifecycle_test.exs`
- `.planning/phases/24-domain-model-dsl-extension/24-CONTEXT.md` (D-01 through D-23, locked)
- `.planning/REQUIREMENTS.md` (AV-02-01 through AV-02-11)
- `.planning/research/v1.4/SYNTHESIS.md` (§2.2, §2.3, §2.4, §2.6, §2.8)
- `.planning/PROJECT.md` (Security Invariants 8-13)
- `.planning/ROADMAP.md` (Phase 24 description, lines 69-80)

### Secondary (MEDIUM confidence — verified with cross-references)
- [Elixir String docs (`String.byte_slice/3` introduced in 1.17)](https://hexdocs.pm/elixir/1.17/changelog.html)
- [Elixir String docs (`String.slice/3` grapheme semantics)](https://hexdocs.pm/elixir/String.html)
- [NimbleOptions docs (nested `:keys` schemas)](https://hexdocs.pm/nimble_options/NimbleOptions.html)
- [Ecto.Changeset docs (`validate_inclusion`, `add_error`)](https://hexdocs.pm/ecto/Ecto.Changeset.html)
- [Rails Active Storage Variant API](https://edgeapi.rubyonrails.org/classes/ActiveStorage/Variant.html) — InvariableError on video; representation/preview split
- [Rails 7.1 ActiveStorage TransformJob preprocesses videos/PDFs](https://blog.saeloun.com/2024/01/22/transform-job-accepts-previewable-files/)
- [Shrine derivatives plugin docs](https://shrinerb.com/docs/plugins/derivatives) — multi-named processors, adopter-conditional dispatch
- [CarrierWave processing wiki — `process :method, if:` pattern](https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-use-callbacks)
- [Django ImageKit advanced usage — `ImageSpec` per-spec processors](https://django-imagekit.readthedocs.io/en/latest/advanced_usage.html)

### Tertiary (LOW confidence — informational only, not load-bearing)
- General Elixir community pattern: `try/after` for resource cleanup (no single citation; standard idiom)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every dependency is in `mix.exs` and verified
- Architecture patterns: HIGH — every code excerpt is derived from existing in-tree precedent
- Pitfalls: HIGH — three of the five (digest drift, tempfile leak, FSM edge gap) are codebase-verified blast radii
- Per-kind schema bodies: MEDIUM — derived from SYNTHESIS §2.4; Phase 25 may force minor pruning
- Sanitizer placement: HIGH — recommendation grounded in three concrete reasons (separation, testability, Phase 26 reuse)
- Recipe digest mechanism: HIGH — Pattern 2 reasoning is direct from `digest.ex` reading; option (a) is the minimal safe change

**Research date:** 2026-05-02
**Valid until:** 2026-06-02 (1 month — codebase is stable, but Phase 25 work may surface schema-shape adjustments)

## RESEARCH COMPLETE
