# Phase 64: Cancel contract & persistence - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 64-cancel-contract-persistence
**Mode:** assumptions
**Areas analyzed:** Public API shape, Error vocabulary, upload_id persistence, FSM terminal edge, Provider callback contract, Security/redaction, Phase boundary

---

## Assumptions Presented

### Public API shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `cancel_direct_upload(asset_id) -> :ok \| {:error, term()}` | Confident | `lib/rindle/streaming.ex`, `lib/rindle.ex` (`cancel_processing/1`), CANCEL-01 |
| No profile arg, no bang, no public upload_id | Confident | Create/cancel symmetry; `guides/streaming_providers.md` redaction posture |

### Error vocabulary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Reuse `:not_found`, `:streaming_not_configured`, `:provider_*` | Confident | `lib/rindle/error.ex`, streaming freeze tests |
| One new atom `:not_cancellable` + tagged maps | Confident | CANCEL-02 tagged errors; `:not_processing` precedent |
| Do not reuse `:provider_asset_not_ready` | Confident | Locked to `streaming_url/3` delivery dispatch |

### upload_id persistence
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Dedicated `provider_upload_id` column | Confident | CANCEL-03; `multipart_upload_id` precedent |
| Do not reuse `mux_passthrough` | Confident | MUX research §4.4; webhook vs cancel API distinction |
| No backfill | Confident | Historical rows lack Mux upload id |

### FSM terminal edge
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `pending → deleted` and `uploading → deleted` | Confident | Pre-link window coverage; CANCEL-02 |
| Reuse `"deleted"`, no `"cancelled"` state | Confident | Locked 6-state vocabulary; CANCEL-04 |
| FSM-first conditional update for race | Confident | `ingest_provider_webhook.ex` terminal rejection |

### Provider callback contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Optional `cancel_direct_upload(upload_id)` | Confident | Mirrors `delete_asset/1`; Mux SDK exists |
| Gate via `:direct_creator_upload` capability | Confident | Same gate as create path |

### Security / redaction
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `provider_upload_id` redacted like `provider_asset_id` | Confident | Invariant 14; `media_provider_asset.ex` Inspect |

## Corrections Made

No corrections — all assumptions confirmed by user ("1" / proceed).

## External Research Applied

- **Mux API:** Cancel keyed by upload id; only meaningful in `waiting`; 403 when too late; idempotent at app boundary required.
- **Active Storage:** No server cancel API — client abort + async cleanup; explicit cancel is optional convenience.
- **Shrine / Spatie:** No in-flight cancel — maintenance reaps orphans; separate stop from purge.
- **Rindle tus/multipart:** Provider handle persisted at mint, never returned publicly (`multipart_upload_id` pattern).
- **Deep-research prompts:** Normalized columns for queryable lifecycle state; provider handles on durable rows.

## Deferred Ideas Captured

- LiveView auto-cancel hook
- Local asset purge on cancel
- Stale direct-upload reaper
- Second provider cancel (MUX-25+)
