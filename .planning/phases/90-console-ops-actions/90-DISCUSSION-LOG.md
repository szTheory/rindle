# Phase 90: Console Ops Actions - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-12
**Phase:** 90-console-ops-actions
**Mode:** assumptions
**Areas analyzed:** Actions Boundary, Owner Erasure UX, Variant And Repair Operations, Quarantine Review, Receipts And Test Shape

## Assumptions Presented

### Actions Boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Convert the existing `Actions` page into an executable LiveView hub, keep reads/previews in `Rindle.Admin.Queries`, and avoid new public admin facade helpers. | Confident | `.planning/ROADMAP.md`, `.planning/phases/89-console-read-surfaces/89-CONTEXT.md`, `lib/rindle/admin/live/actions_live.ex`, `lib/rindle/admin/queries.ex` |

### Owner Erasure UX
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Owner and batch erasure should be preview-first destructive flows with typed confirmation, collateral preview, and receipts. | Confident | `lib/rindle.ex`, `lib/rindle/internal/owner_erasure.ex`, `guides/admin_console_ia.md`, `guides/ui_principles.md` |

### Variant And Repair Operations
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Asset-scoped repair should use `Rindle.reprobe/1` and `Rindle.requeue_variants/2`, while broad stale/missing regeneration should use existing internal ops without a new public facade wrapper. | Likely | `lib/rindle.ex`, `lib/rindle/ops/lifecycle_repair.ex`, `lib/rindle/ops/variant_maintenance.ex`, `lib/mix/tasks/rindle.regenerate_variants.ex` |

### Quarantine Review
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Quarantine review should remain read-only triage over quarantined assets, with links or routing to supported deletion/erasure paths only. | Confident | `guides/admin_console_ia.md`, `guides/ui_principles.md`, `.planning/ROADMAP.md`, `lib/rindle/domain/asset_fsm.ex` |

### Receipts And Test Shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 90 should add stable LiveView selectors and tests for preview, typed confirmation, execute, error, and receipt states, while keeping screenshot polish and Cohort walkthrough work out of scope. | Confident | `guides/ui_principles.md`, `guides/admin_console_ia.md`, `test/rindle/admin/live/variants_runtime_actions_test.exs` |

## Corrections Made

### Variant And Repair Operations
- **Original assumption:** Broad variant regeneration should be handled behind the console without a public facade wrapper.
- **User correction:** None to the core direction, but the deeper research clarified the split more sharply.
- **Reason:** Research showed the cleanest fit is a distinct repair lane for `reprobe`/`requeue` and a separate broad regeneration lane for stale/missing variants.

## Auto-Resolved

None.

## External Research

- Phoenix LiveDashboard router pattern: https://hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.Router.html
- Oban Web operational-console pattern: https://hexdocs.pm/oban_web/Oban.Web.Router.html
- LiveView testing and event handling: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
- Django admin bulk-action caution: https://docs.djangoproject.com/en/6.0/ref/contrib/admin/actions/
- Rails Active Storage async purge: https://guides.rubyonrails.org/active_storage_overview.html
- Shrine derivative/security guidance: https://shrinerb.com/docs/plugins/derivatives
- Spatie Media Library regeneration: https://spatie.be/docs/laravel-medialibrary/v11/converting-images/regenerating-images
- GOV.UK and Carbon destructive-action guidance: https://design-system.service.gov.uk/patterns/check-answers/ and https://carbondesignsystem.com/community/patterns/remove-pattern/
