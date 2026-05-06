# Phase 25: Rindle.Processor.AV - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `25-CONTEXT.md` are the source of truth.

**Date:** 2026-05-05
**Phase:** 25-rindle-processor-av
**Mode:** research-first discuss; user explicitly requested "all" areas plus deep subagent research and one-shot recommendations
**Areas analyzed:** preset surface, poster/thumbnail behavior, partial-failure semantics, waveform posture
**Subagents spawned (parallel):** `gsd-advisor-researcher` × 4

## User Preference Applied

- The user explicitly requested that GSD shift further toward research-first,
  one-shot recommendations, with escalation only for VERY impactful items.
- This matched the existing project posture already recorded in
  `.planning/STATE.md`, `.planning/config.json`, and prior contexts such as
  Phase 19.
- No blocking follow-up questions were necessary after the request to analyze
  all areas with subagents.

## Research Synthesis

### 1. Preset surface

Recommendation:
- Keep the current flat `variants: %{...}` DSL.
- Require named presets for AV kinds.
- Permit only a tiny allowlisted override envelope.

Why:
- Most idiomatic for Elixir/Phoenix libraries: plain data, compile-time
  validation, explicit atoms, no opaque runtime recipe objects.
- Avoids the long-tail "versions/styles but with passthrough knobs" footguns
  seen in older uploader libraries.

### 2. Poster and thumbnail behavior

Recommendation:
- Posters are explicit first-class variants.
- Thumbnail strips are supported but explicit opt-in only.
- No helper/runtime auto-magic around poster discovery.

Why:
- Best fit with Rindle's "one variant = one row = one job" architecture.
- Keeps future `video_tag/3` semantics explicit and unsurprising.

### 3. Partial-failure semantics

Recommendation:
- Best-effort aggregate model.
- Keep successful siblings; recompute asset state from variant rows.
- `quarantined` remains source-trust-only.

Why:
- Best match for Ecto/Oban-style explicit durable state.
- Strongest operator ergonomics and retry/recovery story.

### 4. Waveform posture

Recommendation:
- Keep waveform core but narrow.
- Treat it as audio-track-derived, not audio-asset-only.
- Ship a small JSON contract with min/max peak pairs and preset-owned shape.

Why:
- Good DX for Phoenix/web consumers.
- Avoids turning v1.4 into a DSP or editor toolkit.

## Coherence Checks Applied

- Rejected any option that introduced hidden sidecars or helper magic because it
  conflicted with the current explicit-row architecture.
- Rejected any option that widened the public FFmpeg tuning surface because it
  conflicted with the locked named-presets-only posture.
- Rejected optional/required variant criticality because it would add a new
  cross-cutting policy layer for little v1.4 benefit.
- Rejected rich waveform interoperability modes because they pushed the wedge
  beyond the milestone goal.

## GSD Preference Shift

Applied project-local config change:
- `.planning/config.json`
  `workflow.research_before_questions: false -> true`

Rationale:
- This is the cleanest config-level expression of the user's "shift left"
  preference that is already supported by the installed GSD workflow code.
- The project was already set to `skip_discuss: true` and
  `discuss_mode: "assumptions"`, so this change tightens behavior rather than
  changing direction.

## Outcome

No unresolved escalation items remain for Phase 25 discuss.

The final recommendation set is internally coherent:
- flat preset-led DSL
- explicit poster variant
- explicit opt-in thumbnail strip
- narrow waveform contract
- best-effort aggregate failure semantics
- explicit AV worker/queue/temp-root posture

Planning can proceed without another user round-trip.
