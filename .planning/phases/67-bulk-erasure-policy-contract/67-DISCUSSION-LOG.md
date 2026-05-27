# Phase 67: Bulk erasure policy & contract - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 67-bulk-erasure-policy-contract
**Mode:** assumptions
**Areas analyzed:** Batch report shape, Public API naming, Batch size limit, Support-truth pivot

---

## Assumptions Presented

### Batch report shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `owner_erasure_batch_report/0` with aggregate buckets + per-owner nested `owner_erasure_report/0` entries | Likely | `.planning/REQUIREMENTS.md` BULK-01; `lib/rindle.ex`; `lib/rindle/internal/owner_erasure.ex` |

### Public API naming
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `preview_batch_owner_erasure/2` and `erase_batch_owner_erasure/2` on `Rindle`; both `@spec`s frozen in Phase 67 | Likely | `lib/rindle.ex` single-owner naming; `test/rindle/streaming/cancel_direct_upload_contract_test.exs` |

### Batch size limit
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Default `max_owners: 100`; `{:error, {:batch_too_large, %{requested:, max:}}}`; unique-owner dedupe | Likely | BULK-02; `lib/rindle/streaming.ex` tagged errors; ops opts defaults |

### Support-truth pivot
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Moduledoc + boundary/contract tests in Phase 67; guides deferred to Phase 70 | Likely | `lib/rindle.ex` moduledoc; `api_surface_boundary_test.exs`; `docs_parity_test.exs`; ROADMAP phase split |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## External Research

None required — codebase and planning artifacts sufficient.
