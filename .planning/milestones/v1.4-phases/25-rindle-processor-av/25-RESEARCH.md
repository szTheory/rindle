# Phase 25: Rindle.Processor.AV - Research

**Researched:** 2026-05-05
**Domain:** Elixir/Oban/FFmpeg AV processing pipeline on top of Rindle's existing durable variant lifecycle. [VERIFIED: required repo reads + official docs]
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Verbatim copy from `.planning/phases/25-rindle-processor-av/25-CONTEXT.md`; all items below inherit `[VERIFIED: .planning/phases/25-rindle-processor-av/25-CONTEXT.md]`.

### Recipe Surface and Presets

- **D-01:** Keep Phase 25 on the existing flat `variants: %{...}` DSL. Do not
  introduce a nested `av:` block, a builder DSL, or a profile-local preset
  registry in v1.4.
- **D-02:** For `kind: :video | :audio | :waveform`, `preset` is the primary
  public control surface in v1.4. AV recipes are preset-led, not ad-hoc
  FFmpeg-led.
- **D-03:** Preserve the current "named presets only" posture from the v1.4
  research. `codec`, `container`, bitrate shape, and the FFmpeg argv skeleton
  are preset-owned, not caller-owned.
- **D-04:** Allow only a tiny override envelope on top of presets. The allowed
  family is: `normalize`, `two_pass`, `channels`, `faststart`, and explicit
  poster/waveform selection hooks where needed. Anything broader reintroduces
  the Paperclip/CarrierWave-style footgun surface the v1.4 research rejected.
- **D-05:** Normalize every AV recipe into one canonical internal map before
  computing `recipe_digest`, enqueueing jobs, or building FFmpeg argv. Digest
  stability must depend on the normalized recipe, not map ordering or preset
  implementation details.
- **D-06:** Advanced/custom FFmpeg workflows remain outside core Phase 25.
  Adopters who need raw filter graphs, unusual codecs, or provider-delegated
  pipelines should supply a custom `Rindle.Processor`, not push raw args into
  the bundled processor.

### Poster and Thumbnail-Strip Behavior

- **D-07:** Poster extraction is a first-class explicit declared variant, not a
  hidden sidecar. It should persist and fail like any other derivative row.
- **D-08:** Poster remains an `output_kind: :image` derivative with a canonical
  variant name of `:poster` in docs/examples. Phase 27 helpers should consume
  it explicitly via `poster: :poster`, not by auto-discovery.
- **D-09:** Thumbnail strips are supported in core Phase 25 but remain explicit
  opt-in variants. They are not automatically bundled into a stock video
  variant and are not required for the default onboarding story.
- **D-10:** The stock `Rindle.Profile.Presets.Web` story should teach an
  explicit `:web_720p` video variant plus an explicit `:poster` image variant.
  `:scrub_strip` is optional and shown only when the adopter actually needs a
  scrubbing UI.
- **D-11:** Poster frame selection should follow the Rails-style
  scene-detection fallback chain already locked in research: first I-frame
  after a scene change threshold, then first I-frame, then first frame. The
  result is still surfaced as a normal variant row, not as a separate preview
  abstraction.

### Waveform Posture

- **D-12:** Waveform is a first-class `:waveform` derivative for both
  `:audio` assets and `:video` assets that actually contain an audio track.
  Silent video should fail deterministically at processing time with a
  variant-level failure reason.
- **D-13:** The public waveform surface should stay narrow in v1.4: one named
  preset-led contract, not an audio-tooling mini-language.
- **D-14:** The recommended default waveform preset is a single overview-style
  preset (`:overview`) mapped to the existing 1000-bucket default from the
  v1.4 requirements/research.
- **D-15:** The v1.4 waveform JSON contract should be:
  `%{length: bucket_count, sample_rate: analysis_rate, peaks: [[min, max], ...]}`.
  `peaks` values are normalized floats in `-1.0..1.0`.
- **D-16:** `length` means bucket count, not raw array length or source sample
  length. This must be documented precisely so JS consumers do not guess.
- **D-17:** Do not expose `channels`, `bits`, `samples_per_pixel`, arbitrary
  peak counts, raw filters, or full `audiowaveform` compatibility in v1.4.
  Rindle should ship the wedge, not a DSP toolkit.
- **D-18:** The current Phase 24 waveform validator surface
  (`peaks/sample_rate/channels`) should be treated as provisional. Planning for
  Phase 25 should collapse the documented public contract to the narrower
  preset-owned shape above, even if backward-compatible internal normalization
  is used under the hood.

### Partial-Failure and Aggregate State Semantics

- **D-19:** Use best-effort aggregate failure semantics. Successful sibling
  variants remain persisted and deliverable even if another declared variant
  fails.
- **D-20:** Asset-level `quarantined` remains reserved for source-trust and
  source-validity failures: probe rejection, MIME/security rejection, or
  source-race invalidation. A sibling transcode failure must not quarantine the
  whole asset.
- **D-21:** Asset enters `transcoding` when the first AV variant begins, and
  the asset aggregate state is recomputed from persisted variant rows after
  every terminal variant transition.
- **D-22:** Asset becomes `ready` only when every declared variant for the
  profile is `ready`.
- **D-23:** Asset becomes `degraded` when one or more declared variants are in
  terminal `failed` or `cancelled` states while the original asset or one or
  more sibling derivatives remain usable.
- **D-24:** v1.4 should not introduce required/optional variant criticality.
  Every declared variant participates equally in the aggregate outcome until a
  future phase explicitly adds that policy surface.
- **D-25:** Recovery means retrying/regenerating the failed variant only. Do
  not roll back, purge, or invalidate already-ready siblings solely because one
  sibling failed.

### Worker Shape, Queue, and Tempfile Posture

- **D-26:** Keep the core Rindle invariant: one variant row = one job = one
  explicit terminal state. `Rindle.Workers.ProcessVariant` should evolve into
  the AV-capable worker; Phase 25 should not introduce hidden multi-output jobs
  disguised as one variant.
- **D-27:** AV processing should run on a dedicated `:rindle_media` queue,
  separate from the existing image processing queue, so long-running video jobs
  do not starve short image work.
- **D-28:** All temp files for a transcode run live under a single sweepable
  root `Rindle.tmp/<uuid>/`, not scattered direct `System.tmp_dir!/0` files.
- **D-29:** Phase 25 should add a dedicated `Rindle.Ops.SweepOrphanedTempFiles`
  worker with the v1.4-researched hourly cadence and a default 4-hour threshold
  instead of overloading the current generic orphan reaper behavior.
- **D-30:** Refuse enqueue/start when free disk is below `2 × max_output_bytes`
  for the resolved recipe. This stays a hard protective invariant, not a soft
  warning.
- **D-31:** Progress reporting stays explicit and rate-limited per variant
  topic, matching the already-locked v1.4 telemetry/progress posture. Do not
  infer progress from logs or from partial files.

### Decision-Making Preference (Carried Forward)

- **D-32:** Continue the existing project preference already recorded in
  `.planning/STATE.md` and prior contexts: the agent decides by default,
  performs deep research up front, and escalates only for VERY impactful items
  (public semver reshapes, destructive actions, or similarly irreversible
  changes). Phase 25 has no remaining unresolved item that crosses that bar.

### Claude's Discretion

None stated in `25-CONTEXT.md`. [VERIFIED: .planning/phases/25-rindle-processor-av/25-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)

Verbatim copy from `.planning/phases/25-rindle-processor-av/25-CONTEXT.md`; all items below inherit `[VERIFIED: .planning/phases/25-rindle-processor-av/25-CONTEXT.md]`.

- Compile-time preset-family sugar that expands into explicit poster/strip
  variants. Worth revisiting only after the explicit runtime shape is proven.
- Required/optional variant criticality flags.
- Full `audiowaveform` compatibility modes, split-channel exports, or editor/DSP
  tuning knobs.
- Implicit poster discovery or helper-level auto-magic.
- Reusable preset registries or module-returned opaque preset structs.
- HLS/DASH/ABR/DRM/provider-delegated streaming surfaces.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| AV-03-01 | `Rindle.Processor.AV` behaviour + capabilities | Plan 1 defines the module boundary, capability list, and normalized recipe compiler. [VERIFIED: REQUIREMENTS.md + codebase read] |
| AV-03-02 | H.264/AAC mp4 transcode | Plan 3 owns the video command builder and preset envelope. [VERIFIED: REQUIREMENTS.md] |
| AV-03-03 | Scene-detected poster extraction | Plan 3 owns poster fallback chain and image-output verification. [VERIFIED: REQUIREMENTS.md + 25-CONTEXT D-07..D-11] |
| AV-03-04 | Thumbnail strip | Plan 3 keeps strip explicit and opt-in. [VERIFIED: REQUIREMENTS.md + 25-CONTEXT D-09] |
| AV-03-05 | AAC/MP3 audio transcode | Plan 4 owns audio-only transcode recipes. [VERIFIED: REQUIREMENTS.md] |
| AV-03-06 | Loudnorm | Plan 4 owns single-pass default and `two_pass: true` branch. [VERIFIED: REQUIREMENTS.md + ffmpeg loudnorm docs] |
| AV-03-07 | Waveform JSON | Plan 4 narrows the public contract to `preset: :overview` while keeping internal normalization compatible. [VERIFIED: REQUIREMENTS.md + 25-CONTEXT D-12..D-18] |
| AV-03-08 | Idempotent worker | Plan 2 owns deterministic keying and replay-safe temp/upload flow. [VERIFIED: REQUIREMENTS.md + existing worker seam] |
| AV-03-09 | Post-condition probe | Plan 5 inserts output verification before upload/ready flip. [VERIFIED: REQUIREMENTS.md] |
| AV-03-10 | Atomic promote race guard | Plan 2 owns reload/compare before terminal write. [VERIFIED: REQUIREMENTS.md] |
| AV-03-11 | Dedicated queue + timeout + uniqueness | Plan 2 owns worker options and job construction. [VERIFIED: REQUIREMENTS.md + Oban docs] |
| AV-03-12 | `Rindle.tmp/<uuid>` temp root | Plan 2/5 share run-dir creation and cleanup contract. [VERIFIED: REQUIREMENTS.md + 25-CONTEXT D-28] |
| AV-03-13 | Hourly orphan sweeper | Plan 5 owns the new ops worker and telemetry. [VERIFIED: REQUIREMENTS.md + 25-CONTEXT D-29] |
| AV-03-14 | Disk-space precheck | Plan 5 adds enqueue-time and start-time guards. [VERIFIED: REQUIREMENTS.md + 25-CONTEXT D-30] |
| AV-03-15 | Ephemeral runtime detection | Plan 5 adds boot/runtime guard and warning path. [VERIFIED: REQUIREMENTS.md] |
| AV-03-16 | Telemetry triplet | Plan 6 extends the public telemetry contract. [VERIFIED: REQUIREMENTS.md + telemetry contract test] |
| AV-03-17 | PubSub progress | Plan 6 owns explicit throttled progress emission and tests. [VERIFIED: REQUIREMENTS.md + 25-CONTEXT D-31] |
| AV-03-18 | Stock web preset | Plan 6 lands `Rindle.Profile.Presets.Web` and adopter proof. [VERIFIED: REQUIREMENTS.md + 25-CONTEXT D-10] |
</phase_requirements>

## Summary

Phase 25 should stay additive and build on the exact seams already in tree: `Rindle.Workers.ProcessVariant` for one-row/one-job execution, `Rindle.AV.Subprocess` for subprocess supervision, `Rindle.Probe.AVProbe` for source/output probing, and the Phase 24 `kind`/`output_kind` lifecycle additions. [VERIFIED: `lib/rindle/workers/process_variant.ex`, `lib/rindle/av/subprocess.ex`, `lib/rindle/probe/av_probe.ex`, `lib/rindle/domain/media_asset.ex`, `lib/rindle/domain/media_variant.ex`]

The roadmap's "6 plans" estimate is correct if the phase is split by invariant boundaries rather than by codec/output type alone. [VERIFIED: `.planning/ROADMAP.md`; INFERENCE from code seams] The right split is: processor boundary and normalization, worker/idempotency, video outputs, audio/waveform outputs, runtime safeguards/ops, then telemetry/progress/presets/tests. [VERIFIED: requirements + codebase read]

The most important planning correction is to **not** center Phase 25 on the current `Rindle.Processor.Ffmpeg` prototype. [VERIFIED: `lib/rindle/processor/ffmpeg.ex`] It joins argv into a shell-like string for validation and already shows a flaky `:epipe` failure in its direct execution test, while the repo already has a stronger long-lived seam in `Rindle.AV.Subprocess` plus `MuonTrap.cmd/3`. [VERIFIED: `lib/rindle/processor/ffmpeg.ex`, `lib/rindle/security/argv.ex`, `test/rindle/processor/ffmpeg_test.exs`, `lib/rindle/av/subprocess.ex`; CITED: https://hexdocs.pm/muontrap/MuonTrap.html]

**Primary recommendation:** Keep `Rindle.Processor.AV` as the public processor module, use preset normalization into a canonical internal recipe map, execute FFmpeg/FFprobe through `Rindle.AV.Subprocess`, evolve `ProcessVariant` instead of replacing it, and defer any `FFmpex` adoption because it is not in the repo and does not change the safety model for this phase. [VERIFIED: `mix.exs` lacks `:ffmpex`; CITED: https://hexdocs.pm/ffmpex/readme.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Preset normalization and digest-stable AV recipe compilation | Profile/Domain | Processor | The normalized map must exist before enqueue, digest, and argv build. [VERIFIED: `lib/rindle/profile.ex`, `lib/rindle/profile/validator.ex`, 25-CONTEXT D-05] |
| FFmpeg/FFprobe command execution | Processor/AV runtime | Ops | `Rindle.AV.Subprocess` is already the subprocess choke point. [VERIFIED: `lib/rindle/av/subprocess.ex`] |
| One variant row = one job lifecycle | Worker | Domain | `ProcessVariant` already owns row fetch, transitions, download, process, upload, final write. [VERIFIED: `lib/rindle/workers/process_variant.ex`] |
| Aggregate asset state recomputation | Domain | Worker | Asset `transcoding/ready/degraded` is a persisted lifecycle concern, triggered from terminal variant transitions. [VERIFIED: `lib/rindle/domain/asset_fsm.ex`, 25-CONTEXT D-21..D-25] |
| Disk/runtime admission control | Worker/Ops | Processor | Free-space and ephemeral-runtime checks gate execution before CPU-heavy work begins. [VERIFIED: REQUIREMENTS.md AV-03-14..15] |
| Orphan temp sweeping | Ops | Worker | Sweeper is out-of-band safety net; worker still owns best-effort local cleanup. [VERIFIED: 25-CONTEXT D-28..D-29; `lib/rindle/ops/orphan_reaper.ex`] |
| Progress/telemetry contract | Worker | Public contract tests | Progress is produced by the job; contract stability is enforced in tests. [VERIFIED: REQUIREMENTS.md AV-03-16..17; `test/rindle/contracts/telemetry_contract_test.exs`] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---|---|---|---|
| `muontrap` | `1.7.0` in repo, latest Hex `1.7.0` published 2025-12-01. [VERIFIED: `mix.lock`; CITED: https://hex.pm/packages/muontrap/versions] | Parent-death-safe subprocess execution with timeout/cgroup options. [CITED: https://hexdocs.pm/muontrap/MuonTrap.html] | Already in tree and directly matches the process-lifecycle invariant Phase 25 needs. [VERIFIED: `mix.exs`, `lib/rindle/av/subprocess.ex`] |
| `oban` | `2.21.1` in repo; latest Hex `2.22.1` published 2026-04-30. [VERIFIED: `mix.lock`; CITED: https://hex.pm/packages/oban/versions] | Durable worker execution, uniqueness, timeout callbacks. [CITED: https://hexdocs.pm/oban/Oban.Worker.html] | Existing job model already matches one-row/one-job Rindle architecture; do not upgrade mid-phase. [VERIFIED: `mix.exs`, `lib/rindle/workers/process_variant.ex`] |
| `ffmpeg` | Host-installed `8.0.1`; project minimum `>= 6.0`. [VERIFIED: local `ffmpeg -version`; `lib/rindle/av/probe.ex`] | Video/audio transcode, poster/strip extraction, loudnorm, waveform source. [CITED: https://ffmpeg.org/ffmpeg.html, https://ffmpeg.org/ffmpeg-filters.html] | Current milestone scope is explicitly system-FFmpeg-backed. [VERIFIED: `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`] |
| `ffprobe` | Host-installed `8.0.1`. [VERIFIED: local `ffprobe -version`] | Source and output probe for typed metadata and post-conditions. [VERIFIED: `lib/rindle/av/ffprobe.ex`, `lib/rindle/probe/av_probe.ex`] | Phase 24 already wired the probe seam; Phase 25 should reuse it for output verification. [VERIFIED: codebase read] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|---|---|---|---|
| `image` | `0.65.0`. [VERIFIED: `mix.lock`] | Existing image processor/probe path. [VERIFIED: `lib/rindle/probe/image.ex`] | Keep for image output verification and any image-side post-processing that should remain symmetric with current image flows. [ASSUMED] |
| `jason` | `1.4.4`. [VERIFIED: `mix.lock`] | Parse FFprobe JSON and encode waveform JSON. [VERIFIED: `lib/rindle/av/ffprobe.ex`] | Use instead of adding `jq` as a required adopter dependency. [VERIFIED: env check found `jq`; INFERENCE: avoid extra host requirement] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Direct `Rindle.AV.Subprocess` argv builder | `FFmpex 0.11.0` builder. [CITED: https://hexdocs.pm/ffmpex/readme.html] | `FFmpex` is not in `mix.exs`, is only a command builder, and does not replace `MuonTrap` supervision; adding it expands change surface without removing the need for preset normalization or execution hardening. [VERIFIED: `mix.exs`; CITED: https://hexdocs.pm/ffmpex/readme.html] |
| Single `Rindle.Processor.AV` | Separate `Video` and `Audio` processors | Cross-kind workflows (`video -> poster`, `video -> waveform`, `video -> audio`) become more scattered; requirements and context already prefer one public module. [VERIFIED: REQUIREMENTS.md AV-03-01; 25-CONTEXT D-26] |
| JSON generation in Elixir | `jq` or `audiowaveform` sidecars | `jq` is available locally but not guaranteed for adopters, and `audiowaveform` is absent here; Phase 25 should not add new host prerequisites for a narrow waveform contract. [VERIFIED: local env check] |

**Installation:** No new Mix dependencies are recommended for Phase 25. [VERIFIED: `mix.exs`; INFERENCE from current seams]

**Version verification:** Repo-locked package versions were verified from `mix.lock`, and current Hex release metadata was checked for `oban` and `muontrap`. [VERIFIED: `mix.lock`; CITED: https://hex.pm/packages/oban/versions, https://hex.pm/packages/muontrap/versions]

## Recommended 6-Plan Decomposition

| Plan | Focus | Requirements | Primary Files | Load-Bearing Invariant |
|---|---|---|---|---|
| P1 | Public AV processor boundary + recipe normalization | AV-03-01, groundwork for 02/05/07/18 | `lib/rindle/processor/av.ex` (new), `lib/rindle/profile/validator.ex`, `lib/rindle/profile.ex`, optional `lib/rindle/profile/presets/web.ex` stub | Public surface stays preset-led; every AV recipe becomes one canonical internal map before digest or argv. [VERIFIED: 25-CONTEXT D-02..D-05] |
| P2 | Worker evolution: idempotency, queue isolation, atomic promote, aggregate recompute | AV-03-08, 10, 11, 12 | `lib/rindle/workers/process_variant.ex`, `lib/rindle/domain/asset_fsm.ex`, possible new aggregate helper, worker tests | One variant row = one job = one temp run dir = one terminal variant write. [VERIFIED: 25-CONTEXT D-21..D-31; current worker seam] |
| P3 | Video outputs: mp4 transcode, poster, thumbnail strip | AV-03-02, 03, 04 | `lib/rindle/processor/av.ex`, internal command-builder helpers, `test/rindle/processor/av_test.exs` | Poster and strip remain explicit sibling variants, never hidden sidecars. [VERIFIED: 25-CONTEXT D-07..D-11] |
| P4 | Audio outputs: m4a/mp3, loudnorm, waveform | AV-03-05, 06, 07 | `lib/rindle/processor/av.ex`, possible `lib/rindle/processor/av/waveform.ex` helper, validator narrowing tests | Waveform contract stays narrow and preset-owned; silent video with waveform fails deterministically. [VERIFIED: 25-CONTEXT D-12..D-18] |
| P5 | Runtime safeguards + ops | AV-03-09, 13, 14, 15 | `lib/rindle/av/subprocess.ex`, `lib/rindle/ops/sweep_orphaned_temp_files.ex` (new), worker enqueue/start guard code | Every run is bounded by post-condition probe, disk admission, runtime guard, and sweepable temp-root hygiene. [VERIFIED: REQUIREMENTS.md; `.planning/research/v1.4/FOOTGUNS.md`] |
| P6 | Telemetry, progress throttling, presets, adopter proof | AV-03-16, 17, 18 | telemetry contract tests, worker tests, `test/adopter/canonical_app/lifecycle_test.exs`, preset tests | Public operator surface is frozen here: event names, metadata shape, topic shape, stock preset story. [VERIFIED: REQUIREMENTS.md; telemetry contract test] |

**Recommended ordering:** `P1 -> P2 -> P3 -> P4 -> P5 -> P6`. [VERIFIED: phase dependency reasoning from code seams]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit + Oban.Testing. [VERIFIED: existing test files] |
| Config file | `test/test_helper.exs`. [VERIFIED: repo tree] |
| Quick run command | `mix test test/rindle/processor/av_test.exs test/rindle/workers/process_variant_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/profile/presets_web_test.exs`. [ASSUMED] |
| Full phase command | `mix test test/rindle/processor/av_test.exs test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs test/rindle/contracts/telemetry_contract_test.exs test/adopter/canonical_app/lifecycle_test.exs`. [ASSUMED] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| AV-03-01 | `Rindle.Processor.AV` behaviour + capabilities | unit | `mix test test/rindle/processor/av_test.exs` | ❌ Wave 0 |
| AV-03-02 | mp4 transcode preset envelope | unit/integration | `mix test test/rindle/processor/av_test.exs` | ❌ Wave 0 |
| AV-03-03 | poster fallback chain | integration | `mix test test/rindle/processor/av_test.exs --only poster` | ❌ Wave 0 |
| AV-03-04 | explicit thumbnail strip | integration | `mix test test/rindle/processor/av_test.exs --only strip` | ❌ Wave 0 |
| AV-03-05 | audio transcode presets | unit/integration | `mix test test/rindle/processor/av_test.exs --only audio` | ❌ Wave 0 |
| AV-03-06 | loudnorm single/two-pass | unit/integration | `mix test test/rindle/processor/av_test.exs --only loudnorm` | ❌ Wave 0 |
| AV-03-07 | waveform JSON contract | unit/integration | `mix test test/rindle/processor/av_test.exs --only waveform` | ❌ Wave 0 |
| AV-03-08 | replay-safe same `(asset_id, variant_name)` | integration | `mix test test/rindle/workers/process_variant_test.exs --only idempotent` | extend existing |
| AV-03-09 | output post-condition probe | integration | `mix test test/rindle/workers/process_variant_test.exs --only post_condition` | extend existing |
| AV-03-10 | stale-source atomic promote guard | integration | `mix test test/rindle/workers/process_variant_test.exs --only race_guard` | extend existing |
| AV-03-11 | `:rindle_media` queue, timeout, unique | unit | `mix test test/rindle/workers/process_variant_test.exs --only worker_opts` | extend existing |
| AV-03-12 | `Rindle.tmp/<uuid>` run root | integration | `mix test test/rindle/workers/process_variant_test.exs --only tmp_root` | extend existing |
| AV-03-13 | hourly orphan sweeper | unit | `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs` | ❌ Wave 0 |
| AV-03-14 | disk-pressure precheck | unit/integration | `mix test test/rindle/workers/process_variant_test.exs --only disk_precheck` | extend existing |
| AV-03-15 | ephemeral-runtime refusal | unit | `mix test test/rindle/processor/av_runtime_guard_test.exs` | ❌ Wave 0 |
| AV-03-16 | telemetry triplet contract | contract/integration | `mix test test/rindle/contracts/telemetry_contract_test.exs --only av_media` | extend existing |
| AV-03-17 | progress PubSub ≤ 2/sec | integration | `mix test test/rindle/workers/process_variant_test.exs --only progress` | extend existing |
| AV-03-18 | stock preset + adopter proof | integration/adopter | `mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --include adopter` | ❌ / extend existing |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/processor/av_test.exs test/rindle/workers/process_variant_test.exs`. [ASSUMED]
- **Per wave merge:** add `test/rindle/workers/promote_asset_test.exs` and the sweeper/telemetry lanes. [ASSUMED]
- **Phase gate:** run the full phase command plus the adopter lane. [ASSUMED]

### Wave 0 Gaps

- `test/rindle/processor/av_test.exs` must be created first; it becomes the codec/preset/poster/strip/audio/waveform anchor. [VERIFIED: repo tree]
- `test/rindle/ops/sweep_orphaned_temp_files_test.exs` should replace new work on `orphan_reaper_test.exs`; the old generic reaper can stay as legacy coverage. [VERIFIED: repo tree]
- `process_variant_test.exs` needs fixture-backed AV cases and should stop relying on invalid dummy ffmpeg input for success-path proof. [VERIFIED: existing worker and processor tests]
- `telemetry_contract_test.exs` must gain the new AV event family before implementation finishes, otherwise event drift will go unguarded. [VERIFIED: current contract allowlist has only six non-AV events]

## Architecture Patterns

### System Architecture Diagram

```text
Profile DSL
  -> Validator accepts flat preset-led AV variant specs
  -> Normalizer resolves preset + tiny override envelope
  -> recipe_digest derives from normalized recipe
  -> PromoteAsset inserts MediaVariant rows + ProcessVariant jobs

ProcessVariant(job)
  -> fetch asset + variant
  -> transition variant queued -> processing
  -> create Rindle.tmp/<uuid> run dir
  -> download source to run dir
  -> optional start-time runtime/disk guard
  -> Rindle.Processor.AV.process(source, normalized_spec, run_dir)
     -> ffmpeg/ffprobe via Rindle.AV.Subprocess
     -> explicit progress callbacks (throttled)
     -> output temp artifact(s)
  -> post-condition probe on output
  -> upload deterministic storage_key
  -> reload asset and abort ready flip on stale source mismatch
  -> mark variant ready/failed/cancelled
  -> recompute asset state from persisted sibling variants
  -> cleanup run dir

Hourly Sweeper
  -> scan Rindle.tmp/*
  -> delete stale run dirs older than threshold
  -> emit orphan telemetry
```

### Pattern 1: Preset Normalization Before Digest and Argv

**What:** Resolve every AV spec into one canonical internal map such as `%{kind: :video, preset: :web_720p, output_kind: :video, video_codec: :h264, audio_codec: :aac, container: :mp4, width: 1280, height: 720, crf: 23, audio_bitrate_kbps: 128, faststart: true, normalize: false, two_pass: false}` before computing `recipe_digest/1`, choosing a processor path, or building argv. [VERIFIED: 25-CONTEXT D-02..D-05]

**When to use:** Immediately after `profile_module.variants()` lookup in the worker and in any future enqueue path. [VERIFIED: current `ProcessVariant` seam]

**Why it matters:** It is the only clean way to preserve digest stability, deterministic storage keys, and the "tiny override envelope" without letting implementation details leak into public config. [VERIFIED: 25-CONTEXT D-03..D-05]

### Pattern 2: Run-Directory Ownership by the Worker

**What:** The worker creates `Rindle.tmp/<uuid>/`, places `source`, `output`, and progress artifacts underneath it, and removes the directory in `after` cleanup. [VERIFIED: 25-CONTEXT D-28; current temp usage in `ProcessVariant`]

**When to use:** For every AV variant run, including poster and waveform runs. [VERIFIED: D-26 + D-28]

**Why it matters:** The current scattered `System.tmp_dir!()` filenames in `ProcessVariant` and `OrphanReaper` are insufficient for safe sweeping and disk accounting. [VERIFIED: `lib/rindle/workers/process_variant.ex`, `lib/rindle/ops/orphan_reaper.ex`]

### Pattern 3: Output Verification Before Upload, Race Check Before Ready

**What:** Probe the local output artifact after FFmpeg exits 0, fail fast on invalid/truncated output, then upload, then reload asset and compare `storage_key`/`recipe_digest` before the final `ready` write. [VERIFIED: REQUIREMENTS.md AV-03-09..10]

**When to use:** For `output_kind: video | audio`; for `output_kind: image`, use the existing image probe to verify dimensions/MIME instead of AV duration checks. [VERIFIED: Phase 24 probe modules; ASSUMED for image-output branch]

**Why it matters:** It separates "bad artifact" from "stale source race" and keeps both failures variant-scoped rather than quarantining the asset. [VERIFIED: 25-CONTEXT D-19..D-25]

### Anti-Patterns to Avoid

- **Do not extend `Rindle.Security.Argv` string-validation as the main safety mechanism:** the locked invariant is argv-array discipline and preset allowlists, not building bigger regexes around joined command strings. [VERIFIED: `.planning/PROJECT.md`; `lib/rindle/security/argv.ex`; current `Rindle.Processor.Ffmpeg`]
- **Do not make poster or strip hidden side effects of the video variant:** each output must have its own row, state, retry path, and failure visibility. [VERIFIED: 25-CONTEXT D-07..D-10, D-26]
- **Do not require `jq` or `audiowaveform` for the shipped wedge:** neither is part of the existing adopter contract, and `audiowaveform` is absent here. [VERIFIED: env check]
- **Do not reuse `:rindle_process` for AV jobs:** long-running transcodes will starve image work. [VERIFIED: 25-CONTEXT D-27]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Subprocess supervision | Raw `Port.open/2` wrapper | `MuonTrap.cmd/3` through `Rindle.AV.Subprocess` | Parent-death kill, timeout, and cgroup options are already documented there. [VERIFIED: `lib/rindle/av/subprocess.ex`; CITED: https://hexdocs.pm/muontrap/MuonTrap.html] |
| Queue uniqueness/timeout | Custom duplicate suppression | Oban `unique` + `timeout/1` | Oban already supports both and the repo has a concrete uniqueness pattern in `VariantMaintenance`. [VERIFIED: `lib/rindle/ops/variant_maintenance.ex`; CITED: https://hexdocs.pm/oban/Oban.Worker.html] |
| Waveform sidecar toolchain | `jq`/`audiowaveform` hard dependency | Elixir-side JSON assembly from FFmpeg output | Keeps the waveform wedge within current host assumptions. [VERIFIED: env check; ASSUMED implementation detail] |

**Key insight:** The repo already contains the right abstractions; Phase 25 succeeds by consolidating them behind `Rindle.Processor.AV`, not by introducing a second abstraction stack. [VERIFIED: codebase read]

## Common Pitfalls

### Pitfall 1: The prototype `Rindle.Processor.Ffmpeg` becomes the plan center

**What goes wrong:** Planning around `lib/rindle/processor/ffmpeg.ex` preserves its joined-string validation path and leaks preset logic into a low-level module. [VERIFIED: `lib/rindle/processor/ffmpeg.ex`]
**Why it happens:** The file already exists and looks like a head start. [VERIFIED: repo tree]
**How to avoid:** Treat it as disposable prototype code; `lib/rindle/processor/av.ex` is the public seam and `Rindle.AV.Subprocess` is the execution seam. [VERIFIED: 25-CONTEXT specific ideas + codebase read]
**Warning signs:** New code keeps calling `Argv.validate/1` on joined command strings. [VERIFIED: current prototype]

### Pitfall 2: Post-condition probe runs after upload or only for some paths

**What goes wrong:** A silently truncated or malformed output reaches storage and can be marked ready before validation catches it. [VERIFIED: REQUIREMENTS.md AV-03-09]
**Why it happens:** Upload-success is easy to confuse with artifact-validity. [INFERENCE]
**How to avoid:** Probe local output first, then upload, then race-check before `ready`. [VERIFIED: recommended Pattern 3]
**Warning signs:** Worker code flips `ready` immediately after `store/3`. [VERIFIED: current image worker pattern]

### Pitfall 3: Stale-source guard only checks asset existence

**What goes wrong:** Re-upload during transcode can still attach derivatives from the old object. [VERIFIED: REQUIREMENTS.md AV-03-10]
**Why it happens:** The current worker does not reload/compare source identity before final write. [VERIFIED: `lib/rindle/workers/process_variant.ex`]
**How to avoid:** Compare both `asset.storage_key` and expected `recipe_digest` on reload. [VERIFIED: REQUIREMENTS.md AV-03-10]
**Warning signs:** Ready writes do not consult freshly loaded asset state. [VERIFIED: current worker]

### Pitfall 4: Sweeper keeps file-level semantics instead of run-dir semantics

**What goes wrong:** Partial run cleanup misses auxiliary files or deletes files still owned by an active job. [VERIFIED: current `OrphanReaper` only scans top-level regular files]
**Why it happens:** The existing generic reaper predates AV run directories. [VERIFIED: `lib/rindle/ops/orphan_reaper.ex`]
**How to avoid:** Sweep directories under `Rindle.tmp/*`, not only flat files. [VERIFIED: D-28..D-29]
**Warning signs:** New AV code creates subdirectories but tests stay on flat-file reap semantics. [VERIFIED: current tests]

### Pitfall 5: Disk-pressure guard only happens at enqueue time

**What goes wrong:** Free space can disappear between enqueue and job start, producing mid-run `ENOSPC` failures. [VERIFIED: 25-CONTEXT D-30 says enqueue/start]
**Why it happens:** Enqueue-time checks are simpler. [INFERENCE]
**How to avoid:** Check at enqueue and again when the worker acquires the run dir. [VERIFIED: D-30]
**Warning signs:** Guard code exists only in `PromoteAsset.enqueue_variants/2`. [ASSUMED future risk]

### Pitfall 6: Progress is inferred from logs or file size

**What goes wrong:** Progress becomes noisy, wrong, or unthrottled. [VERIFIED: 25-CONTEXT D-31]
**Why it happens:** FFmpeg already prints stderr, so the temptation is to scrape it loosely. [INFERENCE]
**How to avoid:** Use FFmpeg's structured `-progress` output and throttle to <= 2 events/sec. [CITED: https://ffmpeg.org/ffmpeg.html]
**Warning signs:** PubSub messages depend on stderr parsing regexes or file byte growth. [ASSUMED future risk]

### Pitfall 7: Waveform API leaks provisional Phase 24 keys

**What goes wrong:** `peaks/sample_rate/channels` become public API instead of internal normalization inputs. [VERIFIED: 25-CONTEXT D-18]
**Why it happens:** The validator already accepts them today. [VERIFIED: `lib/rindle/profile/validator.ex`]
**How to avoid:** Public docs/examples/tests should only teach `preset: :overview`; keep legacy keys as internal compatibility if needed. [VERIFIED: D-13..D-18]
**Warning signs:** New docs or preset tests assert direct public control of bucket counts/channels. [ASSUMED future risk]

### Pitfall 8: Fixture strategy uses invalid dummy inputs

**What goes wrong:** Tests exercise process spawning but not correct AV behavior, and the current prototype already shows an `:epipe` failure on dummy input. [VERIFIED: `test/rindle/processor/ffmpeg_test.exs`; local `mix test` run]
**Why it happens:** Invalid input is easy to generate. [INFERENCE]
**How to avoid:** Build tiny real AV fixtures with FFmpeg in tests, as the current probe tests already do. [VERIFIED: `test/rindle/probe/av_probe_test.exs`]
**Warning signs:** Success-path AV tests write `"dummy"` to `.mp4` and assert only that the process failed. [VERIFIED: `test/rindle/processor/ffmpeg_test.exs`]

## Code Examples

### Normalized Video Recipe

```elixir
# Canonical internal map after preset normalization.
%{
  kind: :video,
  output_kind: :video,
  preset: :web_720p,
  container: :mp4,
  video_codec: :h264,
  audio_codec: :aac,
  width: 1280,
  height: 720,
  crf: 23,
  audio_bitrate_kbps: 128,
  faststart: true,
  normalize: false,
  two_pass: false
}
```

Source rationale: preset-led, tiny-override envelope. [VERIFIED: 25-CONTEXT D-02..D-05]

### Worker Flow Guard Order

```elixir
with {:ok, spec} <- Rindle.Processor.AV.normalize(variant_spec),
     {:ok, run_dir} <- TempRunDir.create(),
     :ok <- DiskGuard.check!(spec),
     :ok <- RuntimeGuard.check!(asset, spec),
     {:ok, artifact} <- Rindle.Processor.AV.process(source_tmp, spec, run_dir, progress: progress_fun),
     :ok <- OutputProbe.verify!(artifact, asset, spec),
     {:ok, storage_meta} <- upload_variant(asset, variant, artifact),
     :ok <- ReadyGuard.check_asset_unchanged!(repo, asset, variant) do
  persist_ready(...)
end
```

Source rationale: combines AV-03-08..15 in the order that preserves correct failure attribution. [VERIFIED: REQUIREMENTS.md; codebase read]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Flat image-only worker on `:rindle_process` | Separate AV queue with explicit timeout/unique controls | Phase 25 | Prevents long transcodes from starving image work. [VERIFIED: 25-CONTEXT D-27; Oban docs] |
| Tempfiles directly under `System.tmp_dir!()` | Sweepable run directories under `Rindle.tmp/<uuid>/` | Phase 25 | Makes orphan cleanup, disk accounting, and per-run cleanup deterministic. [VERIFIED: current worker temp usage + D-28] |
| Probe only source uploads | Probe source and finished AV outputs | Phase 24 -> 25 | Adds silent-truncation defense before ready flip. [VERIFIED: Phase 24 probe seam + AV-03-09] |

**Deprecated/outdated:**

- `Rindle.Processor.Ffmpeg` as the main public plan seam is outdated for this phase; keep or remove it only as an internal migration detail. [VERIFIED: current tree; INFERENCE]
- Generic `OrphanReaper` semantics are insufficient for AV run directories; use a new AV-specific sweeper worker. [VERIFIED: current reaper behavior + D-29]

## Project Constraints (from CLAUDE.md)

No `./CLAUDE.md` file exists in the repo root, so there are no additional project-local constraints beyond the planning artifacts already read. [VERIFIED: repo root check]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | `image` may still be useful for image-output verification/post-processing in the AV worker even if FFmpeg writes poster/strip bytes directly. | Standard Stack | Planner may over-scope image-side integration work. |
| A2 | The proposed quick/full test commands and some `--only` tags are recommended structure, not existing exact lane names yet. | Validation Architecture | Planner may need a Wave 0 test-lane task before using those commands verbatim. |
| A3 | Image-output post-condition verification should route through `Rindle.Probe.Image` while AV duration tolerance remains limited to video/audio outputs. | Architecture Patterns | Worker/output-probe code may need a slightly different verification split. |
| A4 | Replace-vs-retain handling for `Rindle.Processor.Ffmpeg` is folded into P1 rather than a separate seventh plan. | Resolved cleanup scope | Low; Plan 01 already carries the public-seam correction and keeps `Rindle.Processor.Ffmpeg` as delegate-or-retire-only migration detail. |

If any assumption becomes a locked planning constraint, confirm it before execution. [ASSUMED]

## Open Questions (RESOLVED)

1. **Keep `Rindle.Processor.Ffmpeg` as compat wrapper or retire immediately?**
   - Resolution: fold cleanup/replacement into Plan 01 and do not create a separate cleanup plan. [VERIFIED: `.planning/phases/25-rindle-processor-av/25-01-PLAN.md`]
   - What we know: the file exists, is prototype-grade, and is not the right public seam. [VERIFIED: `lib/rindle/processor/ffmpeg.ex`]
   - Execution consequence: `Rindle.Processor.Ffmpeg` may remain only as a thin compatibility delegate during the migration, but Phase 25 planning treats `Rindle.Processor.AV` as the sole public seam from P1 onward. [VERIFIED: `25-01-PLAN.md`; INFERENCE from plan scope]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| `ffmpeg` | All AV output generation | ✓ | `8.0.1` | None. [VERIFIED: local command] |
| `ffprobe` | Source/output probe | ✓ | `8.0.1` | None. [VERIFIED: local command] |
| Elixir | Build/test | ✓ | `1.19.5` | None. [VERIFIED: local command] |
| Mix | Build/test | ✓ | `1.19.5` | None. [VERIFIED: local command] |
| `jq` | Optional waveform alternative only | ✓ | `1.7.1` | Use Elixir/Jason anyway. [VERIFIED: local command] |
| `audiowaveform` | Optional waveform alternative only | ✗ | — | Use FFmpeg + Elixir JSON assembly. [VERIFIED: local command] |

**Missing dependencies with no fallback:**

- None for planning in this environment. [VERIFIED: local env check]

**Missing dependencies with fallback:**

- `audiowaveform` is absent; Phase 25 should not depend on it. [VERIFIED: local env check]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | Not phase-owned. [VERIFIED: scope read] |
| V3 Session Management | no | Not phase-owned. [VERIFIED: scope read] |
| V4 Access Control | no | Delivery/auth concerns land in later phases. [VERIFIED: ROADMAP phase split] |
| V5 Input Validation | yes | Preset allowlists, MIME/probe validation, protocol whitelist, runtime guards. [VERIFIED: `.planning/PROJECT.md`, `25-CONTEXT.md`] |
| V6 Cryptography | no | No new crypto primitive is introduced here. [VERIFIED: scope read] |

### Known Threat Patterns for Phase 25

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Playlist/network SSRF through FFmpeg protocols | Information Disclosure / Tampering | Always prepend `-protocol_whitelist` before `-i`; default allowed protocols are otherwise broad. [CITED: https://ffmpeg.org/ffmpeg-protocols.html] |
| Resource exhaustion (CPU/time/file size) | Denial of Service | Enforce `-t`, `-fs`, `-timelimit`, and external wall timeout. [VERIFIED: `.planning/PROJECT.md`; CITED: https://ffmpeg.org/ffmpeg-all.html, https://hexdocs.pm/muontrap/MuonTrap.html] |
| Stale-source overwrite | Tampering | Reload asset and compare identity before terminal write. [VERIFIED: AV-03-10] |
| Queue starvation | Denial of Service | Dedicated `:rindle_media` queue. [VERIFIED: D-27] |
| Metadata/log injection | Information Disclosure | Keep Phase 24 metadata sanitization and treat metadata as untrusted UGC. [VERIFIED: `lib/rindle/av/metadata_sanitizer.ex`, `.planning/PROJECT.md`] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/25-rindle-processor-av/25-CONTEXT.md` - locked decisions, scope, deferred ideas.
- `.planning/ROADMAP.md` - phase goal, plan count, success criteria.
- `.planning/REQUIREMENTS.md` - AV-03-01..18 requirement text.
- `.planning/research/v1.4/SYNTHESIS.md`, `ADAPTER.md`, `LIFECYCLE.md`, `FOOTGUNS.md` - prior narrowed AV posture.
- `lib/rindle/workers/process_variant.ex`, `lib/rindle/processor.ex`, `lib/rindle/processor/ffmpeg.ex`, `lib/rindle/profile/validator.ex`, `lib/rindle/profile.ex`, `lib/rindle/domain/media_asset.ex`, `lib/rindle/domain/media_variant.ex`, `lib/rindle/domain/asset_fsm.ex`, `lib/rindle/domain/variant_fsm.ex`, `lib/rindle/ops/orphan_reaper.ex` - exact code seams.
- https://hexdocs.pm/oban/Oban.Worker.html - uniqueness and timeout behavior.
- https://hexdocs.pm/muontrap/MuonTrap.html - supervised subprocess and cgroup/timeout options.
- https://ffmpeg.org/ffmpeg.html - option ordering and `-progress`.
- https://ffmpeg.org/ffmpeg-protocols.html - `protocol_whitelist`.
- https://ffmpeg.org/ffmpeg-all.html - `-t`, `-fs`, `+faststart`.
- https://ffmpeg.org/ffmpeg-filters.html - `loudnorm` and scene-detection/scdet docs.

### Secondary (MEDIUM confidence)

- https://hexdocs.pm/ffmpex/readme.html - builder semantics for `FFmpex`.
- https://hex.pm/packages/oban/versions - current Oban release metadata.
- https://hex.pm/packages/muontrap/versions - current MuonTrap release metadata.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - repo dependencies and host tools were directly verified; official docs confirmed behavior. [VERIFIED: repo + local env; CITED: official docs]
- Architecture: HIGH - the required seams are already present in code and align with the locked context. [VERIFIED: codebase read]
- Pitfalls: HIGH - each listed risk is either directly visible in current code/tests or already locked in the v1.4 research corpus. [VERIFIED: codebase + planning docs]

**Research date:** 2026-05-05
**Valid until:** 2026-06-05

## RESEARCH COMPLETE
