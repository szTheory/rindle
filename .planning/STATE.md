---
gsd_state_version: 1.0
milestone: v1.8
milestone_name: Resumable Browser Ingest
status: ready_to_plan
last_updated: 2026-05-25T04:29:02.628Z
last_activity: 2026-05-25 -- Phase 46 execution started
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 25
  completed_plans: 25
  percent: 67
stopped_at: Phase 46 complete (2/2) — ready to discuss Phase 47
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-22)

**Core value:** Media, made durable.
**Current focus:** Phase 47 — audit traceability metadata backfill
generated-app tus package-consumer proof (`TUS-14`). Phase 45 is now verified
passed; the milestone is blocked only on the live install-smoke tus flow.

## Current Position

Phase: 47
Plan: Not started
Status: Ready to plan
Last activity: 2026-05-25

Progress: [███████████████_____] 75% (3/4 phases verified complete; Phase 44 has one remaining proof gap)

## Milestone Roadmap (v1.8)

Phase numbering continues from v1.7 (last phase = 41). Execution order:
42 → 43 → 44 → 45. Phase 45 (Mux direct upload) is independent of the tus spine
(42–44) and is **droppable under budget pressure** — the clean cut if the
milestone runs long.

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 42 | tus Protocol Edge (bare Plug) | TUS-01..05, POLISH-01 | Verified passed |
| 43 | S3 Multipart Backing + MinIO Proof | TUS-06..09 | Verified passed |
| 44 | Auth Hardening, DX, Docs, Telemetry, CI Proof | TUS-10..14, POLISH-02 | Audit gap (`TUS-14`) |
| 45 | Browser → Mux Direct Creator Upload (droppable) | MUX-20..23 | Verified passed |

Hex semver: cut `0.2.0` (additive only, still pre-1.0) at v1.8 close.

## Recent Completion

- Last completed milestone: `v1.7 GCS Resumable Adapter`
- Scope: Phases 37-41, 17 plans, 18/18 reqs validated
- Tag: `v1.7` (milestone close tag)
- Archive files:
  - `.planning/milestones/v1.7-ROADMAP.md`
  - `.planning/milestones/v1.7-REQUIREMENTS.md`
  - `.planning/milestones/v1.7-MILESTONE-AUDIT.md`
  - `.planning/milestones/v1.7-phases/` (Phases 37-41 artifacts)
  - `.planning/milestones/v1.6-ROADMAP.md`
  - `.planning/milestones/v1.6-REQUIREMENTS.md`
  - `.planning/milestones/v1.6-phases/` (Phases 33-36 artifacts)

## Pending Todos

- Phase 34/35 code-review polish is now in-milestone scope: POLISH-01 folds into
  Phase 42 (natural locality with the Mux files MUX-20..23 also touch), POLISH-02
  folds into Phase 44. Resolve via `/gsd-code-review N --fix` or explicit waiver.

- Architect `TusPlug` as a thin protocol-versioned edge so IETF RUFH (tus 2.0)
  can be an additive second handler later (TUS-RESEARCH.md §13) — not a v1.8
  deliverable, but a Phase 42 design constraint.

## Blockers/Concerns

- One blocker remains before milestone close: the generated-app tus
  package-consumer proof (`bash scripts/install_smoke.sh tus`) still fails with
  a socket-reset error during the live Node `tus-js-client` flow, so `TUS-14`
  is not yet satisfied.

- MEDIUM confidence on adopter *demand* for tus (no in-repo adopter ticket; case
  inferred from the v1.4 AV wedge). Architecture/scope confidence is HIGH. Phase
  45 (Mux direct) is the budget-pressure release valve.

## Deferred Items (to v1.9+ or out of scope)

| Category | Item | Status |
|----------|------|--------|
| tus | Checksum extension (per-chunk SHA-1, 460) | deferred v1.9+ |
| tus | Concatenation / parallel partial uploads | deferred v1.9+ |
| tus | `Upload-Defer-Length` (size unknown at create) | deferred v1.9+ |
| tus | IETF RUFH / tus 2.0 (`104 Upload Resumption`) | deferred (architect edge for it) |
| tus | GCS-as-tus-backend / R2-native tus proxying | out of scope (GCS keeps Topology A) |
| tus | Rindle-owned tus JS client | out of scope (use tus-js-client/`@uppy/tus`) |
| tus | LiveView tus uploader component | deferred v1.9 |
| streaming | Second streaming provider (Cloudflare/Bunny) | deferred (no demand signal) |
| mux | `cancel_direct_upload/1` | deferred (Mux auto-`timed_out` covers it) |

Phase 36 CI-only UAT items (5) and Phase 34/35 advisory code-review debt are
addressed in v1.8: the UAT items close by observation during v1.8 CI; the
code-review debt is POLISH-01 (Phase 42) and POLISH-02 (Phase 44).

## Decision-Making Preference

- Authoritative decision hierarchy:
  1. `PROJECT.md` locked contract
  2. `STATE.md` current operational truth
  3. Phase `CONTEXT.md` files and locked research artifacts
  4. Bootstrap prompts
  5. Discussion logs and audit trails

- When these sources differ, prefer the highest item in the hierarchy and
  record the choice rather than reopening a settled local decision.

- Downstream agents should front-load research, use subagents when helpful,
  prefer coherent one-shot recommendation sets, and decide by default rather
  than escalating routine design choices.

- Recommendation sets should be ecosystem-aware and internally coherent:
  prefer idiomatic Elixir/Phoenix/Ecto/Plug patterns for this kind of
  library, check successful peer libraries/apps for lessons and footguns,
  and synthesize a single cohesive direction instead of presenting loosely
  related options back to the user.

- Default toward least-surprise public contracts, strong developer
  ergonomics, and operator-friendly behaviour. When a choice is advisory
  rather than truly blocking, prefer telemetry/docs/metadata over expanding
  the returned error surface.

- After research, the default output is one recommended path with rationale,
  notable risks, and rejected alternatives, not a menu of equal options.

- Escalate only for genuinely high-blast-radius decisions such as public
  semver reshapes, destructive or irreversible operations,
  security/compliance boundaries, real-cost surprises, or milestone/scope
  reshapes.

## Research Notes

- tus locked architecture: `.planning/research/v1.8/TUS-RESEARCH.md` (authoritative
  — bare Plug, no tussle/Phoenix, one `resumable_protocol` column, `:tus_upload`
  atom, `upload_part_stream/5`, §12 phase plan).

- Mux direct upload locked detail: `.planning/research/v1.8/MUX-DIRECT-UPLOAD-RESEARCH.md`
  (callback returns `provider_asset_id: nil` at create; correlate via Mux
  `passthrough`, not upload id).

- Sequencing rationale + budget cut order: `.planning/research/v1.8/STRATEGY-SEQUENCING.md`.
- Mux SDK boundary: stay on the official Elixir SDK with a thin adapter; see
  `.planning/research/v1.8-MUX-SDK-BOUNDARY.md`.

## Session Continuity

Last session: 2026-05-23T20:50:51.516Z
phases (42–45), 20/20 requirements mapped at 100% coverage. ROADMAP.md,
REQUIREMENTS.md traceability, and STATE.md updated.

**Last Completed Milestone:** v1.7 (Phases 37-41) — archived 2026-05-08,
tag `v1.7`.

**Next Step:** Fix the remaining Phase 44 generated-app tus proof failure, then
re-run `bash scripts/install_smoke.sh tus` and re-audit v1.8.

## Operator Next Steps

- Fix the Phase 44 generated-app tus package-consumer proof and re-run the v1.8 audit.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 42 P01 | 10min | 4 tasks | 8 files |
| Phase 43 P06 | 3min | 2 tasks | 2 files |
| Phase 43 P07 | 4min | - tasks | - files |
| Phase 43 P08 | 5min | 2 tasks | 2 files |
| Phase 43 P09 | 4min | 2 tasks | 2 files |
| Phase 43 P10 | 11min | 2 tasks | 1 file |
| Phase 43 P12 | 2min | 1 task | 2 files |

## Decisions

- [Phase ?]: tus foundation reuses the v1.7 resumable lane with one resumable_protocol discriminator column (D-10); :tus_upload advertised by Local only, no silent downgrade (D-09); initiate_tus_upload/2 makes no S3-multipart call for the Local sink (D-02)
- [Phase 43]: tus_tail_path/2 delegates to private tail_path/2 (single Base.url_encode64 site preserved) so the reaper consumes the adapter's own canonical path computation (CR-02 source-of-truth)
- [Phase 43]: cross-node S3 tus resume with an absent local tail fails loudly with {:error, :tus_tail_missing} (mid-multipart = non-empty upload_id AND committed parts); single-node/sticky-session constraint documented in S3 moduledoc (CR-04)
- [Phase 43]: Rindle.tmp/ sweeper recurses into tus/ to age out individual regular files by per-file mtime (CR-03); deletion confined to <root>/tus/ regular files; report struct shape unchanged; whole-dir aging untouched for non-tus run dirs
- [Phase 43]: reaper tail removal routed through S3.tus_tail_path/2 with a threaded root (CR-02 source-of-truth); shared gated_expire/2 FSM-gates BOTH standard and tus expiry (WR-01); Local abort resolves the actual upload root (IN-03); PUBLIC abort_tus_backing(session, opts) arity-2 polymorphic abort exposed for the 43-09 DELETE path (CR-01)
- [Phase 43]: tus DELETE aborts the backing store BEFORE the aborted transition via the shared PUBLIC abort_tus_backing/2 (adapter+root from opts, upload_id from the row) so an explicitly-cancelled S3 multipart never leaks (CR-01); the update result is matched and returns 5xx on failure so the client is never falsely told 204 (WR-02); single-node/sticky-session S3 tus constraint documented in the TusPlug moduledoc (CR-04 Plug half)
- [Phase 43]: SC5/IN-04 closed with two MinIO @tag :minio integration cases — a tus DELETE on an S3-backed session asserts list_multipart_uploads is empty for the deleted key (CR-01, via the real TusPlug.call handler), and an abandoned session's on-disk tail file is asserted gone after a reap via S3.tus_tail_path/2 at the resolved opts[:root] || TempRunDir.root_dir() write-path root (CR-02 + CR-03); both stay CI-only and compile without MinIO
- [Phase 43]: CR-04 fully closed — guard_local_tail_present strengthened to fire on (parts != [] OR offset > committed_part_bytes) where committed_part_bytes = length(parts) * @s3_min_part_size, threading base_offset into the guard (43-12). Closes the pre-first-part window (sub-5-MiB first PATCH: upload_id set, parts: [], offset > 0) where a misrouted cross-node resume silently corrupted the object; brand-new FIRST PATCH (offset 0) and same-node tail-present resume stay {:ok}; bare :tus_tail_missing atom preserved
- [Phase 43]: CR-01 abort-FAILURE branch closed (43-11) — a tus DELETE whose backing abort fails persists a retryable tus_abort_failed:<reason> marker (still returns 204) and fetch_retryable_tus_abort_sessions/0 re-selects state=aborted+tus+multipart_upload_id+tus_abort_failed:% rows so the reaper re-aborts the orphaned S3 multipart next cron (ZERO permanent orphan). WR-03 reconciled: settle_tus_abort_success/2 settles a recovered aborted-tus row via persist_tus_abort_retry_success/2 (direct repo update to expired, marker cleared) WITHOUT the FSM-forbidden aborted->expired gated_expire; the GCS resumable_cancel_failed:% marker and non-terminal timeout-expiry still route through the FSM gate (WR-01 preserved); false reaper-compensation comment in tus_plug.ex corrected
