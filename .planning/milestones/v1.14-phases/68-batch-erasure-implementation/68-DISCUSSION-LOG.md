# Phase 68: Batch erasure implementation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 68-batch-erasure-implementation
**Mode:** assumptions
**Areas analyzed:** Per-owner isolation & orchestration, Input dedupe & ordering, Aggregate bucket assembly, Partial failure & idempotency, Boundary & opts

## Assumptions Presented

### Per-owner isolation & orchestration
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Sequential loop; one `OwnerErasure.execute/2` transaction per owner; no batch Multi | Confident | `lib/rindle/internal/owner_erasure.ex`, Phase 67 D-12 |
| Orchestration as private helpers on `Rindle` facade | Likely | `lib/rindle.ex` delegation pattern |

### Input dedupe & ordering
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `Enum.uniq_by(&owner_ref/1)` after validation; first wins | Confident | `validate_batch_owners/2`, `owner_erasure_batch_boundary_test.exs` |
| Report `owners` list in deduped input order | Likely | Phase 67 D-02 |

### Aggregate bucket assembly
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Sum counts + concat entries per bucket; no cross-owner dedupe | Likely | `owner_erasure_bucket/0`, ROADMAP aggregate criteria |
| Batch `mode` matches calling function | Confident | `owner_erasure_batch_report/0` type |

### Partial failure & idempotency
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Continue loop on per-owner error (execute/preview) | Likely | BULK-03, `metadata_backfill.ex` |
| `{:error, {:batch_owner_failed, %{owner:, reason:, partial_report:}}}` on failure | Unclear → locked as D-08 | Frozen entry type, ROADMAP partial-failure criterion |
| Idempotency via per-owner `OwnerErasure` rerun | Confident | `owner_erasure_test.exs` |

### Boundary & opts
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Replace `:not_implemented` stubs; update boundary test | Likely | `lib/rindle.ex` stubs |
| Do not forward batch opts to `OwnerErasure` yet | Likely | `OwnerErasure` ignores `_opts` |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## External Research

None required — codebase and Phase 67 context sufficient.
