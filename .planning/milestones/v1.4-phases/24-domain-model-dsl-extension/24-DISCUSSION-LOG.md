# Phase 24: Domain Model & DSL Extension - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-02
**Phase:** 24-domain-model-dsl-extension
**Mode:** assumptions
**Areas analyzed:** Migration, Probe Naming, FSM Touch Points, Profile DSL & NimbleOptions, Cross-Variant Chaining, Analyzing Lifecycle, Metadata Sanitization, Backward-Compat Test
**Calibration tier:** minimal_decisive (per memory `feedback_research_driven_one_shot.md`)

## Assumptions Presented

### Migration
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Single additive migration using `:string` columns + `Ecto.Enum` at schema layer; defaults make existing rows valid pre-deploy; add `error_reason :text` to `media_assets` for AV-02-09 | Confident | All 8 prior migrations use `:string` for state columns; zero `CREATE TYPE` references; `media_variants.error_reason` precedent at `priv/repo/migrations/20260425090100_create_media_variants.exs:11`; `bigint` precedent for byte_size in `create_media_assets.exs:9` |

### Probe Naming
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep `Rindle.AV.Probe` as boot probe; new `Rindle.Probe` behaviour at `lib/rindle/probe.ex`; adapters `Rindle.Probe.Image` (libvips) and `Rindle.Probe.AVProbe` (thin reshape over `Rindle.AV.Ffprobe`) | Likely | `lib/rindle/av/probe.ex:8` is unambiguously `check_ffmpeg!/1` boot check; `Rindle.AV.Ffprobe.probe/1:12` returns raw FFprobe JSON; symmetric with `Rindle.Processor` + `Rindle.Processor.{Image,FFmpeg}` |

### FSM Touch Points
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Edit exactly 4 files; both FSMs are hand-rolled `@allowed_transitions` maps; additive (existing `available → processing` edge stays) | Confident | `asset_fsm.ex:6-17`, `variant_fsm.ex:4-13`; no Machinery/gen_state_machine; existing FSM tests at `lifecycle_fsm_test.exs:14-44` continue to pass |

### Profile DSL & NimbleOptions
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Four `@*_variant_schema` attributes; pre-NimbleOptions step pops `:kind` (default `:image`) and dispatches; **digest stability is load-bearing** — `:kind` must NOT be persisted into validated spec for image-default cases OR `Profile.Digest` must be patched to yield identical v1.0 digest | Likely | `validator.ex:50-71` defines existing schema; `validate_variant!/2:186-208` is the dispatch site; existing digest-stability test at `profile_test.exs:74-92` |

### Cross-Variant Chaining
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `from_variant` is unused today; add a single compile-time guard with fix-hint message | Confident | `grep from_variant lib/ test/` returns zero matches |

### Analyzing Lifecycle
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Inline insertion in `promote_asset.ex:56-66` `validating → analyzing → promoting` chain; MIME-detect via `Rindle.Security.Mime.detect/1`; dispatch by `accepts?/1`; quarantine on failure with `error_reason` | Likely | `analyzing` is currently no-op pass-through; `media_asset.ex:55` has metadata JSONB ready; `Rindle.Security.Mime.detect/1:8` does 8KB magic-byte sniffing |

### Metadata Sanitization
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New `Rindle.AV.MetadataSanitizer` (or pure function on `Rindle.AV.Ffprobe`); truncate 1024 bytes via `byte_size/1` + strip control chars; layer ON TOP of existing HTML-escape | Confident | SYNTHESIS §2.2 + invariant 10 = ingest sanitization for stored data; HTML-escape is render-side defense; both serve different purposes |

### Backward-Compat Parity Test
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Use `test/adopter/canonical_app/profile.ex` + `lifecycle_test.exs`; assert recipe-digest snapshot matches v1.3 value | Confident | Canonical app is "source of truth for `guides/getting_started.md` (D-16)" per its module doc; lifecycle test already runs against MinIO end-to-end |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

None performed — SYNTHESIS already locked the high-level decisions and the
codebase provided clear evidence for the implementation gray areas. The
assumptions-analyzer subagent's `Needs External Research` section was
empty.

## Sources Consulted

- `.planning/PROJECT.md` (vision, security invariants, key decisions)
- `.planning/REQUIREMENTS.md` (AV-02-01 through AV-02-11)
- `.planning/ROADMAP.md` (phase 24 description)
- `.planning/research/v1.4/SYNTHESIS.md` (locked decisions, source of truth)
- `.planning/STATE.md` (current milestone state)
- `.planning/phases/23-av-foundations/23-*-SUMMARY.md` (Phase 23 artifacts
  to integrate against)
- Codebase analysis via `gsd-assumptions-analyzer` subagent: 8-15 source
  files including `lib/rindle/domain/{asset_fsm,variant_fsm,media_asset,
  media_variant}.ex`, `lib/rindle/profile/{validator,digest}.ex`,
  `lib/rindle/profile.ex`, `lib/rindle/workers/promote_asset.ex`,
  `lib/rindle/security/mime.ex`, `lib/rindle/av/{probe,ffprobe,
  subprocess}.ex`, `lib/rindle/processor.ex`, `lib/rindle/processor/
  image.ex`, `priv/repo/migrations/*`, `test/rindle/profile/profile_test.exs`,
  `test/rindle/domain/lifecycle_fsm_test.exs`, `test/adopter/canonical_app/
  profile.ex`
