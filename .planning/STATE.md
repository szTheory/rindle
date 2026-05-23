---
gsd_state_version: 1.0
milestone: v1.8
milestone_name: Resumable Browser Ingest
status: executing
last_updated: "2026-05-23T09:18:24.726Z"
last_activity: 2026-05-23 -- Phase 43 execution started
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 9
  completed_plans: 4
  percent: 25
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-22)

**Core value:** Media, made durable.
**Current focus:** Phase 43 — s3-multipart-backing-minio-proof
bare mountable Plug (Local + S3/MinIO backing), plus browser→Mux direct creator
upload, so every browser ingest path converges into the one trusted
`verify_completion/2` promote lane. Roadmap written (4 phases, 42–45, 20/20
requirements mapped). Next: plan Phase 42.

## Current Position

Phase: 43 (s3-multipart-backing-minio-proof) — EXECUTING
Plan: 1 of 5
Status: Executing Phase 43
Last activity: 2026-05-23 -- Phase 43 execution started

Progress: [█████_______________] 25% (0/4 phases, 1/4 plans)

## Milestone Roadmap (v1.8)

Phase numbering continues from v1.7 (last phase = 41). Execution order:
42 → 43 → 44 → 45. Phase 45 (Mux direct upload) is independent of the tus spine
(42–44) and is **droppable under budget pressure** — the clean cut if the
milestone runs long.

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 42 | tus Protocol Edge (bare Plug) | TUS-01..05, POLISH-01 | Not started (ready to plan) |
| 43 | S3 Multipart Backing + MinIO Proof | TUS-06..09 | Not started |
| 44 | Auth Hardening, DX, Docs, Telemetry, CI Proof | TUS-10..14, POLISH-02 | Not started |
| 45 | Browser → Mux Direct Creator Upload (droppable) | MUX-20..23 | Not started |

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

- None blocking. The locked architecture (bare Plug, one `resumable_protocol`
  column, `:tus_upload` atom, `upload_part_stream/5` callback) is authoritative in
  `.planning/research/v1.8/` and is not to be relitigated during planning.

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

Last session: 2026-05-22T14:20:16.572Z
phases (42–45), 20/20 requirements mapped at 100% coverage. ROADMAP.md,
REQUIREMENTS.md traceability, and STATE.md updated.

**Last Completed Milestone:** v1.7 (Phases 37-41) — archived 2026-05-08,
tag `v1.7`.

**Next Step:** `/gsd:plan-phase 42` (decompose Phase 42 — tus Protocol Edge —
into executable plans).

## Operator Next Steps

- Plan Phase 42 with `/gsd:plan-phase 42`.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 42 P01 | 10min | 4 tasks | 8 files |

## Decisions

- [Phase ?]: tus foundation reuses the v1.7 resumable lane with one resumable_protocol discriminator column (D-10); :tus_upload advertised by Local only, no silent downgrade (D-09); initiate_tus_upload/2 makes no S3-multipart call for the Local sink (D-02)
