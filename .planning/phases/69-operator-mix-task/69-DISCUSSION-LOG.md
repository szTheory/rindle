# Phase 69: Operator mix task - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 69-operator-mix-task
**Mode:** assumptions
**Areas analyzed:** Task naming & architecture, Owner identity input, Dry-run default & execute opt-in, Output format & exit codes, Documentation & public boundary

## Assumptions Presented

### Task naming & architecture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship `Mix.Tasks.Rindle.BatchOwnerErasure` as `mix rindle.batch_owner_erasure`; thin wrapper calling `Rindle` facade directly, no new `Rindle.Ops.*` module | Confident | `lib/mix/tasks/rindle.runtime_status.ex`; Phase 68 CONTEXT D-02 |

### Owner identity input
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Required `--owners-file PATH` with JSON array of `{"owner_type", "owner_id"}` entries; build lightweight structs via `String.to_existing_atom/1` | Likely | `lib/rindle/internal/owner_erasure.ex:165`; batch boundary tests; mix task atom-safety patterns |

### Dry-run default & execute opt-in
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Default preview via `preview_batch_owner_erasure/2`; execute requires `--no-dry-run` or `--execute` alias | Confident | ROADMAP Phase 69 criterion #3; `lib/mix/tasks/rindle.cleanup_orphans.ex` |

### Output format & exit codes
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Text summary default; `--format json` for full report; exit 0 on ok, exit 1 on any error including partial batch failure with report printed | Likely | `runtime_status` format split; Phase 68 D-08 partial-failure tuple; backfill/cleanup exit patterns |

### Documentation & public boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Rich `@moduledoc` with input schema, exit codes, guide cross-links; add to `api_surface_boundary_test.exs`; defer guide body to Phase 70 | Confident | ROADMAP criterion #2; `guides/operations.md` D-18; existing mix task boundary test |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## External Research

Not performed — codebase evidence sufficient for all assumptions.
