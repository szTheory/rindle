# Phase 49: LiveView Tus Productization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents.
> Decisions are captured in `49-CONTEXT.md`; this log preserves the analysis.

**Date:** 2026-05-25
**Phase:** 49-liveview-tus-productization
**Mode:** assumptions + advisor subagents
**Areas analyzed:** server contract, client uploader contract, UI-state model, boundary discipline

## Assumptions Presented

### Phoenix / LiveView server contract
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `Rindle.LiveView.allow_tus_upload/4` should remain a thin LiveView convenience seam rather than growing into a broader Phoenix abstraction. | Confident | `lib/rindle/live_view.ex`, `guides/resumable_uploads.md`, `test/rindle/live_view_test.exs`, `.planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md` |
| The canonical setup story should stay in `guides/resumable_uploads.md`, with `Rindle.LiveView` docs acting as a thin pointer layer. | Confident | `guides/resumable_uploads.md`, `test/install_smoke/phoenix_tus_truth_parity_test.exs`, `.planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md` |

### Client uploader contract
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The supported browser client should stay a tiny documented `uploader: "RindleTus"` adapter over `tus-js-client`, not a Rindle-owned JS package. | Confident | `guides/resumable_uploads.md`, `lib/rindle/live_view.ex`, `test/install_smoke/generated_app_smoke_test.exs`, `.planning/REQUIREMENTS.md` |
| `@uppy/tus` should remain compatible but non-canonical for Phase 49. | Likely | `guides/resumable_uploads.md`, project support-truth posture in `.planning/PROJECT.md` and Phase 48 context |

### UI-state model
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `100%` transport progress must not be presented as "ready". | Confident | `guides/resumable_uploads.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md` |
| The public Phase 49 state model should stay small and honest: `uploading -> verifying -> ready/error`, with richer sublabels optional. | Likely | `guides/resumable_uploads.md`, `lib/rindle/live_view.ex`, `.planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-CONTEXT.md` |

### Boundary discipline
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 49 should freeze the narrow helper path only and explicitly defer UI-kit / standalone-JS / broader Phoenix-abstraction work. | Confident | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md`, `.planning/research/v1.8/STRATEGY-SEQUENCING.md` |
| The maintainer preference should be shifted left by strengthening project-level recommendation-posture wording, not by reopening milestone scope. | Likely | `.planning/PROJECT.md`, `prompts/gsd-rindle-gsd-bootstrap-brief.md`, `.planning/RETROSPECTIVE.md` |

## Advisor Research Applied

### Server contract
- Recommendation: keep `allow_tus_upload/4` as a thin LiveView convenience seam
  and freeze the exact contract instead of introducing a second abstraction
  layer.
- Main lessons: Phoenix external uploads are already the idiomatic contract
  surface; Shrine's narrow endpoint posture is a better fit than a framework-
  owned uploader; Active Storage is useful but teaches caution around hidden
  lifecycle truth.

### Client uploader contract
- Recommendation: keep a copy-pasteable `RindleTus` snippet over
  `tus-js-client`; treat `@uppy/tus` as compatible but not canonical.
- Main lessons: backend libraries should own the server contract and proof
  posture, not a whole browser widget stack, unless they intentionally become a
  cross-language product.

### UI-state model
- Recommendation: keep a two-layer public truth model where `100%` means
  transfer complete, `verifying` means server truth pending, and `ready` means
  the existing lifecycle gate passed.
- Main lessons: successful systems consistently separate upload completion from
  backend readiness; conflating them creates the most common support footgun.

### Boundary discipline
- Recommendation: freeze only the narrow helper path in Phase 49; defer a UI
  kit, standalone JS package, and broader Phoenix abstraction surface.
- Main lessons: Rindle's value is lifecycle durability after upload, not early
  overbuild of frontend convenience layers.

## Corrections Made

None. The user requested deeper research via subagents and a one-shot cohesive
recommendation set; the research reinforced the original assumptions rather than
overturning them.

## Final Locked Recommendation Set

1. Keep `Rindle.LiveView.allow_tus_upload/4` as a thin LiveView seam and make
   the supported option contract explicit.
2. Keep the canonical browser path as a tiny documented `RindleTus` uploader
   over `tus-js-client`.
3. Freeze a small honest UI-state vocabulary: `uploading -> verifying ->
   ready/error`, with richer sublabels left optional.
4. Hold the Phase 49 boundary hard: no uploader kit, no standalone JS package,
   no broader Phoenix abstraction.
5. Reinforce the decide-by-default recommendation posture in project-level
   artifacts so future GSD runs inherit it more mechanically.

---

*Audit log only. Decisions live in `49-CONTEXT.md`.*
