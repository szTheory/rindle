---
gsd_state_version: 1.0
milestone: v1.10
milestone_name: owner-account-erasure
status: roadmap_defined
last_updated: 2026-05-26T00:00:00.000Z
last_activity: 2026-05-26 -- milestone v1.10 initialized
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
stopped_at: Ready for Phase 53 discussion and planning
---

# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** Media, made durable.
**Current focus:** v1.10 owner/account erasure contract, proof, and docs truth.

## Current Position

Phase: 53
Plan: none
Status: Milestone initialized
Last activity: 2026-05-26

Progress: [--------------------] 0% (phase 53 not started)

## Current Milestone

- Active milestone: `v1.10 Owner Account Erasure`
- Goal: deliver one auditable owner/account erasure facade with dry-run/report,
  execute semantics, orphan-only purge, and retained shared-asset behavior.
- Shared-asset rule: detach the erased owner's rows, purge only newly orphaned
  assets, and report retained shared assets explicitly.
- Planned phases: 53-55

## Next Step

- Run `$gsd-discuss-phase 53` to clarify the contract and report shape.
- Or run `$gsd-plan-phase 53` to go straight into implementation planning.

## Recent Completion

- Last completed milestone: `v1.9 Phoenix Tus DX Completion`
- Scope: Phases 48-52, 10 plans, 7/7 requirements validated
- Tag: `v1.9`
- Archive files:
  - `.planning/milestones/v1.9-ROADMAP.md`
  - `.planning/milestones/v1.9-REQUIREMENTS.md`
  - `.planning/milestones/v1.9-MILESTONE-AUDIT.md`

## Active Roadmap Snapshot

- **Phase 53 — Owner Erasure Contract + Truth Gate:** lock the public API
  boundary, dry-run/reporting vocabulary, shared-asset semantics, and non-goals.
- **Phase 54 — Execute + Orphan-Safe Purge Wiring:** implement the public
  execute lane and idempotent orphan-only purge behavior.
- **Phase 55 — Proof + Adopter Guidance:** prove orphan purge vs retained shared
  assets and replace hand-rolled account-deletion guidance.

## Accumulated Context

- Rindle is roughly `93%` done for its stated mission and now sits in the
  `90-95%` near-done band.
- The core adopter story is already real from shipped evidence: package-consumer
  install proof, canonical adopter lifecycle proof, image/AV processing,
  signed/private delivery, Mux streaming, browser→Mux direct creator upload,
  GCS resumable, and tus-backed resumable browser ingest on Local/S3 all exist
  in code, docs, and verification artifacts.
- The highest-leverage remaining core gap is first-class owner/account erasure
  over Rindle's existing attachment + cleanup model, not another backend or
  protocol extension.
- Phoenix tus DX completion is closed; richer Phoenix uploader abstractions
  remain optional convenience scope, not the default next wedge.
- Planning drift note: older ranking artifacts still predate the shipped v1.8
  browser→Mux direct-upload truth and the v1.9 Phoenix tus proof closure. Use
  `PROJECT.md`, this file, and `.planning/threads/2026-05-25-next-milestone-ordering.md`
  as the current sequencing source of truth.

## Blockers/Concerns

- No active blocker.
- Main implementation risk: owner erasure spans slot-scoped attachment rows and
  asset-scoped purge behavior, so the contract must preserve shared assets with
  surviving attachments.
- Main scope risk: admin UI, bulk orchestration, and force-delete semantics are
  tempting extensions but intentionally deferred out of `v1.10`.

## Deferred Items

| Category | Item | Status |
|----------|------|--------|
| tus | Checksum extension (per-chunk SHA-1, 460) | deferred v1.11+ |
| tus | Concatenation / parallel partial uploads | deferred v1.11+ |
| tus | `Upload-Defer-Length` (size unknown at create) | deferred v1.11+ |
| tus | IETF RUFH / tus 2.0 (`104 Upload Resumption`) | deferred |
| tus | GCS-as-tus-backend / R2-native tus proxying | out of scope |
| tus | Rindle-owned standalone tus JS client package | out of scope |
| tus | Richer reusable uploader component abstractions beyond the supported helper path | deferred |
| streaming | Second streaming provider (Cloudflare/Bunny) | deferred |
| mux | `cancel_direct_upload/1` | deferred |
| lifecycle | Admin or bulk owner-erasure orchestration | deferred |
| lifecycle | Force-delete policy for assets with surviving attachments | deferred |

## Session Continuity

Last session: 2026-05-26T00:00:00.000Z
`v1.10` is now active with requirements and roadmap defined.

**Current Milestone:** v1.10 (Phases 53-55) — owner/account erasure.

**Recommended Next Step:** discuss or plan Phase 53 first; do not jump straight
to execution until the dry-run/report shape and shared-asset truth are locked.
