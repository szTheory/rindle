# Phase 42: tus Protocol Edge (bare Plug) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-22
**Phase:** 42-tus-protocol-edge-bare-plug
**Mode:** assumptions (calibration: minimal_decisive — per documented user decision-making preference)
**Areas analyzed:** storage-sink seam ownership, creator-identity capture, tus URL/token transport, PATCH read-loop bounds, POLISH-01 execution

## Context

The v1.8 architecture is exhaustively locked in `.planning/research/v1.8/TUS-RESEARCH.md`
(810-line one-shot research pass). The assumptions-mode analyzer's job was therefore
NOT to re-decide architecture but to (a) verify the locked seams still exist in live
code and (b) surface the genuine Phase-42 implementation gray areas the research left
to planning. All seams verified with no material drift.

## Seam Verification (all CONFIRMED, no material drift)

| Seam | Status | Evidence |
|------|--------|----------|
| Broker resumable entrypoints | CONFIRMED | `broker.ex:182` (`initiate_resumable_session/2`), `:334`, `:370`, `:566` (`persist_resumable_session/5`), compensation `:566-640` |
| `verify_completion/2` | CONFIRMED | `broker.ex:418-485`; head trust `:427`; `Ecto.Multi` + Oban `:465`; telemetry `:469` |
| `media_upload_sessions` columns + Inspect | CONFIRMED | `media_upload_session.ex:48-60`; redacting `Inspect` `:104-113`; **no creator-identity column** |
| `"resuming"` FSM lane | CONFIRMED | `upload_session_fsm.ex:8-9`; `@states` `media_upload_session.ex:36` |
| Capabilities `@known` / `require_upload` | CONFIRMED | `capabilities.ex:20-28` (no `:tus_upload` yet); `require_upload/2` returns tuple `:49-57` (not a raise) |
| WebhookPlug `init/1` fail-fast | CONFIRMED | `webhook_plug.ex:86-102` (raises), `:105-111` (method guard) |
| LocalPlug `Plug.Crypto` signing | CONFIRMED (shape nuance) | `local_plug.ex:66` verify; token from `query_params["token"]` `:64` (research said "path"); `exp` check `:67-72`; `actor_subject` in payload `:122` |
| Storage `@optional_callbacks` | CONFIRMED | `storage.ex:282-285`; capability type union `:17-24` |
| Reaper resumable/multipart branches | CONFIRMED | `upload_maintenance.ex` multipart abort `:324-349`; resumable cancel `:413-467`, `:551-555`; cleanup `:273-281`; query `:143`. Branches on `upload_strategy`/`session_uri` only — no `resumable_protocol` yet (the bug the new column fixes) |

## Assumptions Presented

### Storage-sink seam ownership (Phase 42 vs 43)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Local-inline tmp-append in 42; generic `upload_part_stream/5` born in 43 | Likely | `local.ex` no multipart; part-numbered signature fits S3 not file-append; TUS-06 scoped to Phase 43 in ROADMAP; TUS-02 "initiates S3 multipart" is stale wording vs Phase-42 Local-only goal |

### Creator-identity capture (forward-compat for Phase 44 TUS-10)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Capture-but-don't-enforce, in HMAC token payload not a column | Likely | No actor column in schema; `LocalPlug` actor_subject lives in signed payload (`local_plug.ex:122`); preserves one-column budget; HMAC-covered + auto-redacted |

### tus URL / token transport shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Signed token = final path segment (`/uploads/tus/<token>`), from `conn.path_info` | Likely | Canonical tus shape; clients treat `Location` as opaque REST resource; CORS proxies mangle query strings on cross-origin HEAD/PATCH; deliberate divergence from LocalPlug query-param |

### PATCH read-loop bounds
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `read_length: 1 MiB`, ceiling from `max_size`; Claude's discretion, not config | Confident | TUS-RESEARCH §2/§10 locks 1 MiB read_length + per-PATCH ceiling; only `max_size` is adopter-facing |

### POLISH-01 execution
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Selective fix (~8) + waive (~3), NOT blanket `--fix` | Likely | 4 Blockers already fixed (front-matter commits); WR-07 is a documented v1.7 deferral; findings heterogeneous (real bugs vs deferrals vs defensive-only) |

## Corrections Made

No corrections — user selected "Yes, lock all". All five assumption areas confirmed
as recommended and written to CONTEXT.md as decisions D-01 through D-13.

## POLISH-01 Triage (from 34-REVIEW.md)

Blockers BL-01..04 already fixed. 12 advisories:

| ID | Sev | File | Recommend |
|----|-----|------|-----------|
| WR-01 | Warning | `mux/http.ex:49-52` | Fix (KeyError → error tuple) |
| WR-02 | Warning | `mux.ex:298-304` | Fix (header casing) |
| WR-03 | Warning | `mux_sync_provider_asset.ex:155-163` | Fix-or-document (stale age_ms) |
| WR-04 | Warning | `mux_sync_provider_asset.ex:155-187` | Fix (FSM-rejected → retry burn) |
| WR-05 | Warning | `mux.ex:307-311`, `event.ex:38-42` | Fix (unknown status passthrough) |
| WR-06 | Warning | `mux_sync_provider_asset.ex:148-150` | Fix (last_sync_error breadcrumb) |
| WR-07 | Warning | `mux_sync_coordinator.ex:85-94` | **Waive** (documented v1.7 deferral) |
| WR-08 | Warning | `mux_sync_coordinator.ex:95-104` | Fix (swallowed insert failures) |
| WR-09 | Warning | `mux_ingest_variant.ex:163-175` | Fix (invariant-14: raw reason leak) |
| IN-01 | Info | `mux/event.ex:54-63` | Waive (no live caller) |
| IN-02 | Info | `mux_sync_coordinator_test.exs:55-110` | Fix (test hygiene) |
| IN-03 | Info | `mux.ex:266` | Waive (defensive only) |

Locality note: requirement ties POLISH-01 to Mux files MUX-20..23 touch, but that
Mux work is Phase 45, not 42 — the ride-along rationale is weak; fixes stand alone.
Roadmap-locked, not relitigated.

## External Research

None performed — TUS-RESEARCH.md + live codebase cover every Phase-42 decision.
The only unresolved item (real adopter demand) is a milestone-level MEDIUM-confidence
concern already flagged in the research (§14), not a Phase-42 implementation gap.
