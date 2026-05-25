# Phase 45: Browser -> Mux Direct Creator Upload (sibling, droppable) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents. Decisions live in `45-CONTEXT.md`; this file preserves how they were
> arrived at.

**Date:** 2026-05-24
**Phase:** 45-browser-mux-direct-creator-upload-sibling-droppable
**Mode:** assumptions + subagent research
**Areas analyzed:** public ownership boundary, correlation/linker strategy,
frontend/DX posture, profile ergonomics

## Assumptions Presented

### Public ownership boundary
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Direct creator upload should live behind a streaming-owned public entrypoint, not `MediaUploadSession` / `Upload.Broker` public ownership. | Likely | Reserved callback on `Rindle.Streaming.Provider`; durable provider-row/FSM already shipped; direct-upload research and roadmap both frame this as a provider-asset flow. |

### Correlation and linker strategy
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `video.upload.asset_created` should be linked via Mux `passthrough`, not `provider_asset_id`, because the provider asset id is unknown at create time. | Confident | Typed Mux event normalizer already separates upload id and provider asset id; worker currently no-ops because provider-asset lookup cannot work pre-link. |

### Frontend / DX posture
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Controller/JSON baseline plus UpChunk should be the primary integration story; LiveView should wrap the same contract as a convenience path. | Likely | Existing optional `Rindle.LiveView` posture, Phase 45 UI spec, Mux direct-upload docs, Phoenix LiveView external-upload seam. |

### Profile ergonomics
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `MuxWeb` should stay unchanged and direct upload should land as an explicit sibling preset/path. | Likely | `MuxWeb` currently locks `:server_push`; direct upload changes ingest/custody semantics materially; additive preset is least-surprise. |

## Research Applied

### Area 1 — Public ownership boundary
- Subagent verdict: add `Rindle.Streaming.create_direct_upload/2`; keep
  `Upload.Broker` reuse tactical/internal only.
- Key tradeoff: one additive public seam is preferable to muddying the meaning
  of `Broker` or inventing fake storage-session semantics for provider upload.

### Area 2 — Correlation / linker strategy
- Subagent verdict: `passthrough` as primary linker, optional internal
  `upload_id` as secondary ops/debug field.
- Key tradeoff: one nullable correlation column is cleaner and more future-proof
  than making provider ids the business key.

### Area 3 — Frontend / DX posture
- Subagent verdict: controller/JSON endpoint is the baseline; LiveView
  `allow_direct_upload/4` is the convenience wrapper.
- Key tradeoff: framework-agnostic docs and controller friendliness matter more
  than a slightly more magical LiveView-only story.

### Area 4 — Profile ergonomics
- Subagent verdict: keep `MuxWeb` untouched; add a sibling preset for direct
  creator upload; preserve explicit custom profile config as the escape hatch.
- Key tradeoff: one more preset is worth it to preserve semver safety and least
  surprise.

## Corrections Made

No user corrections were required. The initial assumptions were validated and
strengthened with subagent research.

## Preference Capture

- Future GSD work should continue to bias toward research-first, ecosystem-aware,
  coherent one-shot recommendation sets and should decide by default rather than
  escalating routine design choices.
- Escalation remains reserved for high-blast-radius decisions only: semver
  reshapes, destructive/irreversible changes, security/compliance boundaries,
  recurring cost surprises, or scope/milestone changes.

## Canonical References Consulted

- `prompts/gsd-rindle-elixir-oss-dna.md`
- `prompts/gsd-rindle-research-index.md`
- `prompts/phoenix-media-uploads-lib-deep-research.md`
- `prompts/rindle-brand-book.md`
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/research/v1.8/MUX-DIRECT-UPLOAD-RESEARCH.md`
- `.planning/research/v1.8-MUX-SDK-BOUNDARY.md`
- `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md`
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md`
- `.planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-UI-SPEC.md`
- `lib/rindle/streaming/provider.ex`
- `lib/rindle/streaming/provider/mux.ex`
- `lib/rindle/streaming/provider/mux/event.ex`
- `lib/rindle/workers/ingest_provider_webhook.ex`
- `lib/rindle/domain/media_provider_asset.ex`
- `lib/rindle/profile/presets/mux_web.ex`
- `lib/rindle/profile/validator.ex`
- `lib/rindle/live_view.ex`
- `guides/streaming_providers.md`
