# Phase 54: Execute + Orphan-Safe Purge Wiring - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents.
> Decisions captured in `54-CONTEXT.md` are authoritative; this log preserves
> the research and narrowing path.

**Date:** 2026-05-26
**Phase:** 54-execute-orphan-safe-purge-wiring
**Mode:** assumptions + advisor research
**Areas analyzed:** public execute lane, transaction boundary, orphan/shared
partitioning, purge-worker safety, idempotency/uniqueness, report ergonomics,
support-truth posture

## Assumptions Presented

### Public execute lane
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The execute capability should ship as `Rindle.erase_owner/2` with `Rindle.preview_owner_erasure/2` as its explicit dry-run companion. | Confident | `lib/rindle.ex`, `53-CONTEXT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md` |
| `erase_owner/2` should return `{:ok, owner_erasure_report()}` rather than bare `:ok` or a separate execute-only payload family. | Confident | `53-CONTEXT.md`, `lib/rindle.ex`, `.planning/REQUIREMENTS.md` |
| Owner erasure should reuse the existing owner struct + `id` input style already used by `attach/4` and `detach/3`. | Likely | `lib/rindle.ex`, current facade conventions |

### Transaction boundary and internal flow
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Preview and execute should share one internal planning/query path so both surfaces compute the same semantic partition. | Confident | `.planning/research/ARCHITECTURE.md`, `53-CONTEXT.md` |
| Execute should recompute the plan inside its own transaction path rather than trusting an earlier preview result. | Likely | shared-asset race analysis, current attachment/asset model |
| `Ecto.Multi` is the strongest fit for the dynamic detach set + purge enqueue set. | Likely | `Ecto.Multi` docs, current repo dynamic job-insert patterns |

### Shared-asset and purge safety
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Facade-side partitioning is required for honest reporting, but the purge worker must still re-check for surviving attachments immediately before deletion. | Confident | `lib/rindle/workers/purge_storage.ex`, `lib/rindle/domain/media_attachment.ex`, migration cascade rules, `.planning/research/PITFALLS.md` |
| The current worker is unsafe for shared assets because it deletes by `asset_id` unconditionally and then deletes the asset row. | Confident | `lib/rindle/workers/purge_storage.ex`, `priv/repo/migrations/20260425090000_create_media_attachments.exs` |
| Strengthening `PurgeStorage` should protect not only owner erasure but also existing `attach/4` and `detach/3` purge flows. | Confident | `lib/rindle.ex`, current enqueue points for replacement/detach |

### Idempotency and uniqueness
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Re-running `erase_owner/2` for an owner already cleared of attachments should return a stable zeroed report rather than error. | Confident | `.planning/REQUIREMENTS.md`, `detach/3` current no-op behavior, `test/rindle/attach_detach_test.exs` |
| Purge jobs should be unique by asset identity for active states, but worker idempotency must remain the primary safety guarantee. | Likely | Oban unique-jobs docs, `ProcessVariant` uniqueness pattern, variant-maintenance conflict handling |
| Enqueue conflicts should be surfaced semantically as "already queued" rather than treated as hard failures. | Likely | `lib/rindle/ops/variant_maintenance.ex`, `test/rindle/ops/variant_maintenance_test.exs` |

### Report ergonomics
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The frozen report buckets should remain the public contract: `attachments_to_detach`, `assets_to_purge`, `retained_shared_assets`, and `purge_enqueued`. | Confident | `53-CONTEXT.md`, `lib/rindle.ex`, docs parity tests |
| The least-surprise execute/preview distinction is a semantic field like `mode`, not a second payload family. | Likely | `53-CONTEXT.md`, current report-type posture |
| `retained_shared_assets` should explain retention with a field like `surviving_attachment_count` rather than leaking full surviving attachment rows. | Likely | proof-friendly DX reasoning, shared-asset safety focus |

## Advisor Research Summary

### Local code seam analysis
- Compared:
  - execute facade returning `{:ok, report}` vs bare `:ok`
  - facade-only partitioning vs worker-only partitioning vs both
  - no uniqueness vs active-state uniqueness vs durable external markers
  - minimal report vs semantic report with mode/conflict detail
- Recommendation:
  - keep the explicit execute facade
  - compute a shared internal plan
  - detach transactionally
  - enqueue unique purge jobs for only newly orphaned assets
  - harden `PurgeStorage` with a survivor-aware re-check
- Why:
  - this is the smallest coherent change set that closes the real shared-asset
    hazard without widening milestone scope

### Elixir / Phoenix / Ecto / Oban idioms
- Compared:
  - explicit paired facade functions vs mode-switched API vs public low-level planner
  - `Repo.transact` control flow vs `Ecto.Multi`
  - idempotent worker only vs uniqueness + idempotent worker vs extra app-level marker state
  - domain report maps vs raw internal structs
- Recommendation:
  - explicit paired facade functions
  - `Ecto.Multi` for the execute flow
  - idempotent worker first, uniqueness second
  - semantic domain report only
- Why:
  - least surprise for a destructive library surface
  - consistent with Phoenix context and Oban transaction patterns

### Cross-ecosystem lifecycle prior art
- Compared:
  - Rails Active Storage blob/attachment split
  - Shrine attacher + backgrounding model
  - Django/Wagtail conservative deletion + usage visibility
  - Spatie Media Library preserve-vs-delete ergonomics
- Recommendation:
  - combine Rails' structural shared-asset safety with Shrine's idempotent
    background lifecycle posture
  - keep any visibility/reporting semantic and advisory, not magical
- Why:
  - best fit for Rindle's attachment/asset model and explicit lifecycle mission

### Prompt and planning philosophy synthesis
- Compared:
  - broadening into admin/bulk/compliance surfaces
  - keeping a narrow lifecycle-core wedge
  - loose wording vs explicit support truth
- Recommendation:
  - implement exactly the promised owner-erasure contract and nothing broader
  - keep wording explicit, calm, and proof-oriented
- Why:
  - aligns with `PROJECT.md`, prompts, and the milestone ordering thread

## Corrections Made

No user corrections were made. The final recommendation set tightened the
original assumptions with concrete worker-safety and uniqueness details from
advisor research and direct code-seam analysis.

## External Research

- Rails Active Storage official guide and API docs:
  attachment vs purge split, shared-blob safety, and background purge posture.
- Shrine official docs:
  explicit attacher lifecycle verbs and backgrounding/idempotency lessons.
- Ecto official docs:
  `Ecto.Multi` as the dynamic transaction boundary.
- Oban official docs:
  transaction-safe job insertion and uniqueness semantics/limits.
- Wagtail/Django references:
  useful warning that usage visibility is advisory and not sufficient as a sole
  deletion safety mechanism.

## Footguns Locked For Planning

1. Do not let asset-scoped purge logic erase surviving owners on shared assets.
2. Do not hide storage deletion inside the DB transaction.
3. Do not ship a destructive mode-switched API when the explicit pair is
   already frozen.
4. Do not treat enqueue conflicts as operation failures if the desired outcome
   is already "purge is queued."
5. Do not overclaim execute semantics as immediate byte deletion.
6. Do not widen Phase 54 into admin UI, bulk orchestration, or force-delete
   policy work.
