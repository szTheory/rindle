# Phase 24: Domain Model & DSL Extension - Context

**Gathered:** 2026-05-02 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Adopters can declare `:image | :video | :audio | :waveform` variants on the
existing profile DSL with operator-queryable typed columns, while every
existing image-only profile compiles and runs byte-for-byte unchanged.

In scope:
- One additive Ecto migration (`:kind`, `:output_kind`, typed probe columns,
  `error_reason` on `media_assets`)
- Per-kind NimbleOptions schemas in `Rindle.Profile.Validator`
- `transcoding` asset state and `cancelled` variant state (additive, no
  removal of existing edges)
- New `Rindle.Probe` behaviour with `Rindle.Probe.Image` and
  `Rindle.Probe.AVProbe` adapters
- MIME-dispatched probe step inserted into existing `analyzing` lifecycle
- Container metadata sanitization (truncate 1024 bytes, strip control chars)
  layered on top of Phase 23's HTML-escape
- Backward-compat parity test using existing `test/adopter/canonical_app/`
  fixture, anchored on a recipe-digest snapshot

Out of scope (Phase 25 and later):
- Any FFmpeg transcoding or `Rindle.Processor.AV` implementation
- Worker idempotency, output post-condition probe, atomic-promote race guard
- Stock 720p preset (`Rindle.Profile.Presets.Web`)
- `Rindle.cancel_processing/1` implementation (Phase 27); Phase 24 only adds
  the `cancelled` FSM terminal state so the API can land cleanly later
</domain>

<decisions>
## Implementation Decisions

### Migration

- **D-01:** Single additive migration `priv/repo/migrations/<ts>_extend_media_for_av.exs`.
  Use `:string` columns (not Postgres `CREATE TYPE` enums) with `Ecto.Enum` at
  the schema layer for atom mapping. Specifically:
  - `media_assets`: `add :kind, :string, null: false, default: "image"`,
    `add :width, :integer`, `add :height, :integer`,
    `add :duration_ms, :bigint`, `add :has_video_track, :boolean`,
    `add :has_audio_track, :boolean`, `add :error_reason, :text`
  - `media_variants`: `add :output_kind, :string, null: false, default: "image"`,
    `add :duration_ms, :bigint`, `add :width, :integer`, `add :height, :integer`
  - No `disable_ddl_transaction`, no `lock_timeout` — match all 8 prior
    migrations.
- **D-02:** `media_assets` gains `error_reason :text` column (parity with
  existing `media_variants.error_reason` at
  `priv/repo/migrations/20260425090100_create_media_variants.exs:11`) so
  AV-02-09's "send asset to quarantined with `error_reason` set" contract is
  fulfillable. This is a Phase 24 addition not strictly named in AV-02-01 but
  required by AV-02-09.
- **D-03:** `duration_ms` is `:bigint` (precedent: existing `byte_size` column
  in `create_media_assets.exs:9`). Integer milliseconds, not float seconds.
- **D-04:** Existing rows are valid pre-deploy via column defaults
  (`default: "image"` for both enums). No data backfill step.

### Probe Naming (resolves Phase 23 ↔ AV-02-05 collision)

- **D-05:** Keep `Rindle.AV.Probe` (`lib/rindle/av/probe.ex`) as-is — it is
  the *boot-time* version probe (`check_ffmpeg!/1`) and stays.
- **D-06:** Introduce a new per-asset probe behaviour at
  `lib/rindle/probe.ex`:
  ```elixir
  @callback probe(source :: term()) :: {:ok, result()} | {:error, term()}
  @callback accepts?(content_type :: binary()) :: boolean()
  ```
  Result map shape: `%{kind, width?, height?, duration_ms?, has_video_track?,
  has_audio_track?, metadata?}`.
- **D-07:** Bundled adapters:
  - `Rindle.Probe.Image` at `lib/rindle/probe/image.ex` — wraps the existing
    libvips path used by `Rindle.Processor.Image`.
  - `Rindle.Probe.AVProbe` at `lib/rindle/probe/av_probe.ex` — thin reshape
    over `Rindle.AV.Ffprobe.probe/1` (Phase 23). Reshapes raw FFprobe JSON
    `{:ok, %{"format" => ..., "streams" => ...}}` into the standardized
    result map.
- **D-08:** Keep `Rindle.AV.Ffprobe` as-is. `Rindle.Probe.AVProbe` is a thin
  reshaping adapter on top, not a rename.

### FSM Touch Points

- **D-09:** Asset FSM addition in `lib/rindle/domain/asset_fsm.ex`:
  - Add to `@allowed_transitions`: `"available"` gains `"transcoding"`; new
    key `"transcoding" => ["ready", "degraded", "quarantined"]`.
  - Existing `"available" => ["processing", "quarantined"]` edge stays
    unchanged so image flows are byte-for-byte preserved.
  - Add `"transcoding"` to `@states` in `lib/rindle/domain/media_asset.ex`
    (line 34 area).
- **D-10:** Variant FSM addition in `lib/rindle/domain/variant_fsm.ex`:
  - Add to `@allowed_transitions`: `"queued"`, `"processing"`, `"planned"`
    each gain `"cancelled"`; new key `"cancelled" => []` (terminal).
  - Add `"cancelled"` to `@states` in `lib/rindle/domain/media_variant.ex`
    (line 33 area).
- **D-11:** Per-kind validation in
  `Rindle.Domain.MediaAsset.changeset/2` enforces kind/field consistency:
  no `width`/`height` on `:audio`, no `duration_ms` or `has_video_track` on
  `:image`. Specific error messages per field.

### Profile DSL & Per-Kind NimbleOptions Schemas

- **D-12:** `lib/rindle/profile/validator.ex` defines four module attributes:
  - `@image_variant_schema` — current `@variant_schema` (lines 50-71)
    preserved verbatim (`mode`, `width`, `height`, `format`, `quality`)
  - `@video_variant_schema` — keys to be defined in plan (per-kind allowlists
    informed by SYNTHESIS §2.4)
  - `@audio_variant_schema`
  - `@waveform_variant_schema`
- **D-13:** Pre-NimbleOptions dispatch step in `validate_variant!/2`
  (`validator.ex:186-208`): pop `:kind` from variant opts with default
  `:image`, dispatch to the per-kind schema, raise `ArgumentError` with
  `mix phx.gen`-style fix hint on unknown kind:
  `"variant `:thumb` declared `:kind => :unknown`; allowed: :image | :video
  | :audio | :waveform"`.
- **D-14: DIGEST STABILITY (load-bearing).** `:kind` MUST NOT be persisted
  into the validated variant spec for image-default cases, OR
  `Rindle.Profile.Digest` MUST be patched to deterministically yield identical
  v1.0 digests for `:image` variants. The plan MUST include a
  digest-snapshot test (snapshotted v1.3 digest value for the canonical
  `:thumb` variant) — see D-22. Recipe-digest drift would silently flip every
  existing adopter's variants to `stale` on upgrade.
- **D-15:** Compile-time guard inside `validate_variant!/2` raises if
  `:from_variant` appears in any variant spec (AV-02-08). Currently unused
  anywhere (`grep from_variant lib/ test/` returns zero matches), so this is
  forward-looking only.

### Analyzing Lifecycle: MIME Dispatch + Probe Insertion

- **D-16:** Insert probe step inline in
  `lib/rindle/workers/promote_asset.ex:56-66` (`validating → analyzing →
  promoting` chain). New `analyzing` body:
  1. Download source to a `Rindle.tmp/` path (Phase 23 sweepable root)
  2. Detect MIME via existing `Rindle.Security.Mime.detect/1`
     (`lib/rindle/security/mime.ex:8`) — 8KB magic-byte sniff via ExMarcel
  3. Dispatch by `Rindle.Probe.Image.accepts?/1` /
     `Rindle.Probe.AVProbe.accepts?/1`
  4. Write probe result to asset row (`kind`, typed columns, sanitized
     `metadata`)
  5. On probe error: transition to `"quarantined"` with `error_reason` set
- **D-17:** Probe dispatch is by detected **MIME**, not by `kind` (since
  `kind` is the *output* of the probe step). Matches AV-02-09 explicitly.
- **D-18:** Inline insertion (single-worker chain in `PromoteAsset`), not a
  separate `Rindle.Workers.Probe` job. Matches the existing single-job shape
  and avoids two-worker coordination overhead. Orphan tempfile cleanup is
  handled by Phase 23's `Rindle.Ops.OrphanReaper`.

### Container Metadata Sanitization Layering

- **D-19:** New module `Rindle.AV.MetadataSanitizer` (or pure function
  `Rindle.AV.Ffprobe.sanitize_container_metadata/1` — plan to choose):
  - Truncate to 1024 **bytes** via `byte_size/1` (NOT `String.length/1`),
    matching AV-02-10's "1024 bytes" wording.
  - Strip control characters `\x00-\x1F` except `\t`.
- **D-20:** Apply sanitization in `Rindle.Probe.AVProbe` AFTER calling
  `Rindle.AV.Ffprobe.probe/1` and BEFORE writing into the asset's
  `metadata` JSONB.
- **D-21:** Keep Phase 23's existing HTML-escape at the FFprobe shim layer
  (`lib/rindle/av/ffprobe.ex:43-50`). Both layers serve different purposes:
  ingest-time strip = stored-data hygiene; render-time escape = output
  defense in depth. Do not collapse them.

### Backward-Compat Parity Test (AV-02-11)

- **D-22:** Use `test/adopter/canonical_app/profile.ex` +
  `test/adopter/canonical_app/lifecycle_test.exs` as the parity fixture.
  Add a new ExUnit test asserting:
  1. The profile compiles unchanged on v1.4
  2. `Profile.variants()` returns identical map shape (no `:kind` key
     persisted in image-default cases)
  3. `Profile.recipe_digest(:thumb)` matches a snapshotted v1.3 digest
     value (the load-bearing assertion — catches D-14 drift)
  4. The full lifecycle test (already runs against MinIO end-to-end)
     continues to pass byte-for-byte
- **D-23:** Snapshot the canonical v1.3 `:thumb` digest BEFORE Phase 24
  edits the validator. Capture in
  `test/rindle/backward_compat/v13_digest_snapshot_test.exs` or extend the
  existing pattern at `test/rindle/profile/profile_test.exs:74-92`.

### Claude's Discretion

- Module placement choices for `Rindle.AV.MetadataSanitizer` vs pure
  function on `Rindle.AV.Ffprobe` (D-19) — planner picks based on call
  surface.
- Exact NimbleOptions schema bodies for video/audio/waveform variants
  (D-12) — derived from SYNTHESIS §2.4 format scope and §2.3 named-presets-only
  rule.
- Test file organization (single backward-compat test file vs extending
  existing).

### Folded Todos

None — `gsd-sdk query todo.match-phase 24` returned zero matches.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source-of-truth specs
- `.planning/research/v1.4/SYNTHESIS.md` §2.2 (Domain model), §2.3 (Profile
  DSL), §2.4 (Format scope in/out), §2.6 (Capability negotiation), §2.8
  invariant #10 (metadata sanitization)
- `.planning/REQUIREMENTS.md` AV-02-01 through AV-02-11 (lines 107-128)
- `.planning/PROJECT.md` Security Invariants 8-13 (lines 175-206)
- `.planning/ROADMAP.md` Phase 24 description (lines 69-80)

### FSMs (touch points for D-09, D-10)
- `lib/rindle/domain/asset_fsm.ex` lines 6-17 (`@allowed_transitions` map)
- `lib/rindle/domain/variant_fsm.ex` lines 4-13 (`@allowed_transitions` map)
- `lib/rindle/domain/media_asset.ex` lines 34-45 (state list), line 55
  (metadata JSONB), lines 75-90 (changeset shape — new `:kind` validation
  per D-11)
- `lib/rindle/domain/media_variant.ex` lines 33, 37-50, 62-79 (variant
  schema + changeset for `:output_kind`)
- `test/rindle/domain/lifecycle_fsm_test.exs` lines 14-73 (FSM tests to
  extend)

### Profile validator + digest (touch points for D-12 through D-15)
- `lib/rindle/profile/validator.ex` lines 50-71 (existing `@variant_schema`
  to clone), 186-208 (`validate_variant!/2` dispatch site), 224
  (NimbleOptions wrapper)
- `lib/rindle/profile.ex` lines 35-115 (DSL macro shape, `recipe_digest/1`
  site)
- `lib/rindle/profile/digest.ex` (digest-stability surface — MUST NOT
  change for image profiles)
- `test/rindle/profile/profile_test.exs` lines 74-92 (existing
  digest-stability test pattern to extend)

### Probe behaviour landing (D-05 through D-08)
- `lib/rindle/av/probe.ex` line 8 (boot probe — DO NOT rename, see D-05)
- `lib/rindle/av/ffprobe.ex` line 12 (`probe/1` signature),
  lines 43-50 (HTML-escape — keep, see D-21)
- `lib/rindle/processor.ex` + `lib/rindle/processor/image.ex` (symmetric
  pattern that `Rindle.Probe` + `Rindle.Probe.Image` mirrors)

### Lifecycle insertion (D-16 through D-18)
- `lib/rindle/workers/promote_asset.ex` lines 44-66 (insertion point)
- `lib/rindle/security/mime.ex` line 8 (`detect/1` MIME primitive)
- `lib/rindle/ops/orphan_reaper.ex` (Phase 23 — handles tempfile cleanup)

### Migration precedent (D-01 through D-04)
- `priv/repo/migrations/20260424155129_create_media_assets.exs` lines 6, 9
  (string state column + bigint byte_size precedents)
- `priv/repo/migrations/20260425090100_create_media_variants.exs` line 11
  (`error_reason :text` precedent for D-02)

### Backward-compat parity (D-22, D-23)
- `test/adopter/canonical_app/profile.ex` (canonical v1.0 image-only
  fixture; "source of truth for `guides/getting_started.md (D-16)`" per its
  module doc)
- `test/adopter/canonical_app/lifecycle_test.exs` (full MinIO lifecycle
  test)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.AV.Ffprobe.probe/1` (Phase 23) — raw FFprobe JSON extractor.
  `Rindle.Probe.AVProbe` wraps + reshapes (D-07).
- `Rindle.Security.Mime.detect/1` — 8KB magic-byte MIME sniff via ExMarcel.
  Drives probe dispatch (D-17).
- `Rindle.Ops.OrphanReaper` (Phase 23) — sweeps `Rindle.tmp/`. Probe step
  downloads sources here (D-16); cleanup is automatic.
- `Rindle.AV.Subprocess` (Phase 23) — MuonTrap four-cap subprocess wrapper
  used by `Rindle.AV.Ffprobe`.
- `Rindle.Profile.Validator` NimbleOptions infrastructure — already in
  place for image variants; per-kind schemas extend the same pattern.
- `Rindle.Processor` + `Rindle.Processor.Image` — symmetric pattern for
  the new `Rindle.Probe` behaviour and adapters.
- `validate_inclusion(:state, @states)` pattern (`media_asset.ex:88`,
  `media_variant.ex` equivalent) — reused for `:kind` and `:output_kind`
  validation at the schema layer (D-01 implies enums live at this layer,
  not in PG).

### Established Patterns
- **Hand-rolled FSMs:** Both asset and variant FSMs are plain
  `@allowed_transitions` maps + a single `transition/3` function. No
  Machinery, no gen_state_machine. Adding states is purely additive (D-09,
  D-10).
- **String state columns + schema-layer enums:** All 8 prior migrations use
  `:string` for state columns with `null: false, default: "..."`;
  validation lives in the Ecto schema. Phase 24 follows the same pattern
  for `:kind` and `:output_kind` (D-01).
- **Single-worker lifecycle chain:** `Rindle.Workers.PromoteAsset` advances
  through `validating → analyzing → promoting` inline in one job (D-18).
- **Layered defense for UGC:** Phase 23 chose to HTML-escape FFprobe output
  at the shim layer; Phase 24 layers ingest-time truncate+strip on top
  (D-19 through D-21).
- **Adopter canonical fixture:** `test/adopter/canonical_app/` is the
  documented "source of truth" for `guides/getting_started.md` and is the
  natural backward-compat anchor (D-22).

### Integration Points
- **Phase 23 `Rindle.AV.Ffprobe`** ← wrapped by new `Rindle.Probe.AVProbe`
  (D-07).
- **Phase 23 `Rindle.AV.Probe`** ← stays as boot probe; named distinct from
  the new per-asset `Rindle.Probe` behaviour to avoid collision (D-05, D-06).
- **Phase 23 `Rindle.Ops.OrphanReaper`** ← handles cleanup of tempfiles
  written by the new probe step (D-16).
- **Existing `Rindle.Workers.PromoteAsset`** ← gains MIME-dispatched probe
  step in its `analyzing` body (D-16).
- **Existing `Rindle.Profile.Validator` + `Rindle.Profile.Digest`** ←
  validator gains per-kind schemas (D-12); digest MUST stay byte-for-byte
  identical for image-default profiles (D-14).
- **Phase 25 (Rindle.Processor.AV)** depends on the new `:transcoding`
  state, `:output_kind` column, `Rindle.Probe.AVProbe`, and per-kind
  schemas — Phase 24 must land first.
- **Phase 27 (LiveView)** depends on the new `:cancelled` variant state for
  `Rindle.cancel_processing/1` to flip variants cleanly.
</code_context>

<specifics>
## Specific Ideas

- The migration filename should follow the existing `<timestamp>_<verb>_<noun>.exs`
  convention; suggest `extend_media_for_av` as the verb_noun.
- The probe behaviour at `lib/rindle/probe.ex` should mirror
  `Rindle.Processor` (`lib/rindle/processor.ex`) — symmetric naming was a
  deliberate SYNTHESIS choice (§2.2).
- Per-kind schemas should reference SYNTHESIS §2.4's in/out format scope
  table when defining the codec/container/format `:in` allowlists. Anything
  in the "Out of v1.4" column (HLS, DASH, DRM, ABR, MKV ingest, raw AAC,
  hardware accel, etc.) must NOT appear in any allowlist.
- Container metadata sanitization keys to cover (per AV-02-10): `title`,
  `artist`, `comment`, `tags`, plus any other free-text fields FFprobe
  surfaces.
</specifics>

<deferred>
## Deferred Ideas

- **Single combined boot+per-asset probe module** — considered (resolves
  the naming "collision") but rejected: boot probe is a one-shot
  version/CVE check; per-asset probe is a content analysis behaviour with
  multiple adapters. Different lifetimes, different call sites. Keep
  separate.
- **Two-worker chain (separate `Rindle.Workers.Probe` job)** — considered;
  rejected for now in favor of inline insertion (D-18). Reconsider in
  Phase 25 if FFprobe latency justifies a dedicated queue.
- **PG `CREATE TYPE` enums** — considered; rejected because no precedent
  in the existing 8 migrations and `Ecto.Enum` at the schema layer gives
  the same atom ergonomics with simpler ops (D-01).
- **`Rindle.Processor.AV` implementation** — Phase 25 scope.
- **`Rindle.cancel_processing/1` API + LiveView wiring** — Phase 27 scope.
  Phase 24 only adds the `cancelled` FSM terminal state.
- **Stock 720p preset (`Rindle.Profile.Presets.Web`)** — Phase 25 / 28
  scope.
- **`mix rindle.doctor` cross-checking the new per-kind schemas** — built
  in Phase 23 for AV foundations; extending the doctor task to validate
  per-kind variants against capabilities is a Phase 23 follow-up or Phase
  25 concern.

### Reviewed Todos (not folded)
None — phase-todo cross-reference returned zero matches.
</deferred>
