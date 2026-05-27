# Phase 65: Mux cancel implementation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 65-mux-cancel-implementation
**Mode:** assumptions (research-validated via subagents + prompts)
**Areas analyzed:** Orchestration flow, Mux adapter stack, Provider failure semantics, Test scope, Row lookup

## Assumptions Presented

### Orchestration flow (FSM-first hybrid)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Conditional `update_all` to `deleted` before provider call; re-read on 0-row update | Confident | 64-CONTEXT D-22; ingest_provider_webhook.ex linker race |
| Shared `@cancellable_states` constant for FSM/SQL parity | Likely | provider_asset_fsm.ex; variant_maintenance anti-pattern lesson |
| Rejected: provider-first (resumable mirror) | Confident | broker.ex cancel_resumable_session; inverts D-22 |
| Rejected: read-then-changeset without WHERE guard | Confident | TOCTOU vs video.upload.asset_created |

### Mux adapter + HTTP stack
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend Client + HTTP + adapter (mirror delete_asset/create_upload) | Confident | mux/client.ex, mux/http.ex, mux.ex |
| Map 403 AND 404 → `:ok` at HTTP layer | Confident | Mux SDK research; deps/mux Uploads.cancel/2 |
| 429 → :provider_quota_exceeded; other 4xx/5xx → :provider_sync_failed at adapter | Confident | mux.ex create_direct_upload normalization |
| Rejected: SDK direct in adapter without Client behaviour | Confident | Pitfall 4; Mox/cassette test lanes |

### Provider failure after local FSM transition
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Row stays `deleted`; return :provider_sync_failed; no rollback | Confident | 64-CONTEXT D-22 best-effort; PROJECT async purge posture |
| Idempotent re-cancel still attempts provider call | Likely | D-07 retry semantics; Stripe idempotency prior art |
| Rejected: rollback FSM on provider failure | Confident | Reopens webhook race window |
| Deferred: Oban retry worker | Likely | Mux timed_out backstop; CONTEXT deferred reaper |

### Test scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 65: impl + contract export flip + one happy-path Mox test | Confident | ROADMAP 65/66 split; create_direct_upload_test.exs precedent |
| Full PROOF-01 matrix deferred Phase 66 | Confident | REQUIREMENTS traceability; 64-RESEARCH.md |

### Row lookup + profile resolution
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| get_by(asset_id, ingest_mode: "direct_creator_upload") | Confident | delivery.ex contrast; multi-row footgun |
| String.to_existing_atom(row.profile); no MediaAsset load | Confident | mux_ingest_variant.ex worker pattern |
| Rejected: String.to_atom on profile | Confident | Atom exhaustion; repo standard |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed") after
research synthesis covering ecosystem prior art (Active Storage, Shrine, Spatie,
Stripe), prompts research, and Mux SDK audit.

## External Research Applied

- Mux upload lifecycle: `waiting → cancelled | timed_out | asset_created` —
  403 on cancel-no-longer-possible (not just 404)
- Active Storage / Shrine / Spatie: no server-side direct-upload cancel API;
  client abort + cleanup jobs — Rindle differentiator is durable row + provider API
- Stripe PaymentIntent cancel: idempotent retry on partial failure
- S3 multipart abort (Rindle tus): storage-first because cost threat — different
  domain than webhook promotion race
- prompts/phoenix-media-uploads-lib-deep-research.md: upload session ≠ asset;
  abort/cancel lifecycle verbs
- prompts/gsd-rindle-elixir-oss-dna.md: behaviour seams, no HTTP in DB tx,
  layered CI proof

## Auto-Resolved

Not applicable (interactive confirmation, not --auto mode).
