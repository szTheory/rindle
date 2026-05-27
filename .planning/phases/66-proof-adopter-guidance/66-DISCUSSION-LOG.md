# Phase 66: Proof & adopter guidance - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 66-proof-adopter-guidance
**Mode:** assumptions
**Areas analyzed:** Test placement, create→cancel integration, HTTP 403/404 proof, edge-case matrix, TRUTH-01 guide

## Assumptions Presented

### Test file placement
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend cancel + mux adapter tests; add HTTP Bypass file; no install-smoke | Confident | Phase 65 file split; OSS DNA layered proof; PROOF-01 wording |
| Leave `direct_upload_flow_test.exs` unchanged | Confident | Webhook failure domain separate from cancel |

### Create → cancel integration
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One create→cancel test in `cancel_direct_upload_test.exs` | Confident | Adopter grep target; PROOF-01 single matrix home |
| Not in `direct_upload_flow_test.exs` | Confident | Mux cancel ≠ webhook pipeline; Phase 65 deferred matrix |

### HTTP 403/404 proof
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Bypass tests on `Mux.HTTP` + `base_url` seam | Confident | D-14 adapter maps 4xx; re-cancel calls provider on `deleted` row |
| ClientMock `:ok` only at adapter/orchestration | Confident | `mux_cancel_upload_test.exs` pattern; delete_asset test gap lesson |

### Edge-case matrix
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 4 required tests + optional pending/quota | Confident | PROOF-01/CANCEL-02; `streaming.ex` branches |
| Skip ingest_mode integration test | Confident | `fetch_direct_upload_row` filter |

### TRUTH-01 guide
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| §4.1 subsection + §10 disambiguation + docs parity test | Confident | `resumable_uploads.md` colocate pattern; §10 Oban cancel ambiguity |

## Corrections Made

No corrections — user confirmed full research-backed recommendation set with "proceed".

## Auto-Resolved

N/A (not `--auto` mode).

## External Research

- Mux API: `PUT /uploads/{id}/cancel`; 403 when no longer cancellable
- UpChunk: client `abort()` only — no server cancel
- Active Storage: direct upload cancel = client `xhr.abort()` only
- S3/GCS: idempotent delete/cancel on missing resource — Bypass precedent in repo
- Subagent research: Elixir ExUnit idioms, OSS file layout, ecosystem comparisons
