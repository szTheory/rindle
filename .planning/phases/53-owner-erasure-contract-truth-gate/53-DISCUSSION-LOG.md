# Phase 53: owner-erasure-contract-truth-gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents.
> Decisions captured in `53-CONTEXT.md` are authoritative; this log preserves
> the research and narrowing path.

**Date:** 2026-05-26
**Phase:** 53-owner-erasure-contract-truth-gate
**Mode:** assumptions + advisor research
**Areas analyzed:** public API shape, report shape, shared-asset semantics,
execution boundary, support-truth posture, repo-level discuss posture

## Assumptions Presented

### Public API shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The owner-erasure capability should ship as a public `Rindle` facade, not as a Mix-task-first or worker-first surface. | Likely | `lib/rindle.ex`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md` |
| The least-surprise public shape is two explicit verbs: `preview_owner_erasure/2` and `erase_owner/2`. | Likely | `lib/rindle.ex`, Elixir/Phoenix context conventions, Active Storage `detach`/`purge` split, Shrine attacher docs |

### Reporting contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Dry-run and execute should share one stable `{:ok, report}` contract. | Confident | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `lib/rindle/ops/upload_maintenance.ex` |
| The report must expose explicit totals and lists for `attachments_to_detach`, `assets_to_purge`, and `retained_shared_assets`. | Confident | `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, project research docs |

### Shared-asset semantics
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Assets with surviving attachments must be retained; only newly orphaned assets may enter purge. | Confident | `lib/rindle/domain/media_asset.ex`, `lib/rindle/domain/media_attachment.ex`, `.planning/threads/2026-05-25-next-milestone-ordering.md`, Active Storage shared-blob semantics |
| Configurable force-delete policy should not ship in `v1.10`. | Confident | `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, milestone non-goals |

### Execution boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Execute should keep DB detach work transactional and preserve async purge as a separate job lane. | Confident | `lib/rindle.ex`, `lib/rindle/workers/purge_storage.ex`, `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md`, Oban/Ecto docs |

### Support-truth and discuss posture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `cleanup_orphans` should remain maintenance-only in support truth, not be taught as the owner-erasure API. | Confident | `guides/user_flows.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md` |
| Future discuss/planning should narrow aggressively and ask only rare high-blast-radius follow-ups. | Confident | `.planning/PROJECT.md`, `.planning/METHODOLOGY.md`, `prompts/gsd-rindle-gsd-bootstrap-brief.md` |

## Advisor Research Summary

### Public API shape
- Compared:
  - single facade with preview/execute mode option
  - explicit `preview_owner_erasure/2` + `erase_owner/2`
  - Mix-task/worker/internal-first surfaces
- Recommendation:
  - explicit paired facade functions on `Rindle`
- Why:
  - clearest intent at call sites
  - strongest support truth
  - most idiomatic for Phoenix/Ecto-style app-facing APIs

### Report/result shape
- Compared:
  - explicit partitioned semantic report
  - count-only summary
  - raw row/internal return shapes
  - separate dry-run vs execute payload families
- Recommendation:
  - one shared semantic report keyed by `attachments_to_detach`,
    `assets_to_purge`, and `retained_shared_assets`
- Why:
  - proof-friendly
  - auditable
  - least surprising
  - semver-stable

### Shared-asset semantics and execution
- Compared:
  - retain shared assets; purge only newly orphaned assets
  - force-delete all assets touched by the owner
  - configurable destructive policy
  - transaction + async purge vs inline deletion
- Recommendation:
  - retain shared assets
  - delete owner attachment rows transactionally
  - enqueue async purge only for newly orphaned assets
- Why:
  - fits current attachment-vs-asset model
  - preserves Rindle’s durability posture
  - avoids deleting media still referenced elsewhere

### Support-truth and repo-level posture
- Compared:
  - docs-only truth swap
  - contract-first planning consolidation
  - broader compliance/admin expansion
- Recommendation:
  - contract-first consolidation in planning surfaces now
  - public docs update later, only after the facade exists
- Why:
  - avoids overclaiming unimplemented behavior
  - shifts future discuss/planning into research-first narrowing mode

## Corrections Made

No corrections yet — this pass captured the researched recommendation set and
persisted it into phase context and repo-level planning posture.

## External Research

- Rails Active Storage:
  attachment vs purge split, shared-blob safety, and background purge lessons
  from official guides/API docs.
- Shrine:
  attachment-centric public API and backgrounding lessons from official docs.
- Ecto / Oban:
  transactional boundary and async/idempotent job guidance from official docs.

## Repo-Level Posture Updates Applied

- `.planning/PROJECT.md` — tightened discuss-phase default and support-truth
  boundary wording.
- `.planning/METHODOLOGY.md` — added a narrow-then-escalate lens.
- `.planning/REQUIREMENTS.md` — clarified `cleanup_orphans` is not the owner
  erasure API.
- `.planning/JTBD-MAP.md` — reframed job 32 around the new facade milestone.
- `prompts/gsd-rindle-gsd-bootstrap-brief.md` and
  `prompts/gsd-rindle-bootstrap-command.md` — sharpened research-first
  assumptions-mode posture.
