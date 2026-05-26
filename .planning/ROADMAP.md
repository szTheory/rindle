# Roadmap: Rindle

## Milestones

- 🚧 **v1.10 Owner Account Erasure** — Phases 53–55 (started 2026-05-26)
- ✅ **v1.9 Phoenix Tus DX Completion** — Phases 48–52 (shipped 2026-05-25, see archive)
- ✅ **v1.8 Resumable Browser Ingest** — Phases 42–47 (shipped 2026-05-25, see archive)
- ✅ **v1.7 GCS Resumable Adapter** — Phases 37–41 (shipped 2026-05-08, see archive)
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07, see archive)
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06, see archive)
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, see archive)
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, see archive)
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, see archive)
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, see archive)
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, see archive)

## Current Status

`v1.10` is active. This milestone turns owner/account erasure into a supported
public lifecycle contract with dry-run/reporting, explicit shared-asset
semantics, and orphan-safe purge behavior. The roadmap intentionally excludes
bulk admin tooling, force-delete semantics for still-shared assets, and
additional provider/protocol breadth.

## Milestone Goal

Give adopters one auditable account-deletion flow that reports what will be
detached and purged, executes that work through a public facade, and preserves
shared assets unless they become newly orphaned.

## Phase Completion

- [ ] **Phase 53: Owner Erasure Contract + Truth Gate** — Freeze the public
  API boundary, report shape, shared-asset semantics, and non-goals for owner
  erasure. (`LIFE-01`, `TRUTH-02`)
- [ ] **Phase 54: Execute + Orphan-Safe Purge Wiring** — Implement the public
  execute lane, detach-all-owner semantics, retained-shared-asset handling, and
  idempotent no-op behavior. (`LIFE-02`, `LIFE-03`, `LIFE-04`)
- [ ] **Phase 55: Proof + Adopter Guidance** — Add hermetic/adopter proof and
  update guides to teach the supported account-deletion flow. (`PROOF-03`,
  `PROOF-04`)

## Proposed Roadmap

**3 phases** | **7 requirements mapped** | All covered ✓

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 53 | Owner Erasure Contract + Truth Gate | Lock the supported-now contract and reporting shape before any destructive API wiring lands. | LIFE-01, TRUTH-02 | 4 |
| 54 | Execute + Orphan-Safe Purge Wiring | Implement one public execute path that detaches owner rows, purges only orphaned assets, and remains idempotent. | LIFE-02, LIFE-03, LIFE-04 | 4 |
| 55 | Proof + Adopter Guidance | Prove the shared-asset/orphan split and replace hand-rolled account-deletion guidance with the public facade. | PROOF-03, PROOF-04 | 4 |

### Phase Details

**Phase 53: Owner Erasure Contract + Truth Gate**
Goal: Lock the public API boundary, dry-run/reporting vocabulary, shared-asset
retention policy, and docs truth before implementation work starts.
Requirements: `LIFE-01`, `TRUTH-02`
Success criteria:
1. The active requirements and docs name one recommended owner-erasure facade
   instead of advising adopters to hand-roll detach loops.
2. The dry-run/reporting result distinguishes attachments to detach, assets
   eligible for purge, and shared assets that will be retained.
3. The milestone records explicit non-goals: admin UI, bulk orchestration, and
   force-delete behavior for still-shared assets.
4. Shared-asset behavior is locked to "retain if any surviving attachment
   remains" and carried forward into implementation and proof.

**Phase 54: Execute + Orphan-Safe Purge Wiring**
Goal: Implement the public execute lane and reuse the existing async purge path
only when assets become newly orphaned after owner detachment.
Requirements: `LIFE-02`, `LIFE-03`, `LIFE-04`
Success criteria:
1. Adopters can execute owner/account erasure through one public facade call.
2. The execute lane detaches all attachments for the target owner without
   purging assets that still have surviving attachments.
3. Assets that become orphaned are enqueued into the existing purge lane with
   auditable results rather than deleted inline in the transaction.
4. Re-running erasure for the same owner returns a stable no-op/report result
   and does not double-purge or raise on already-cleared state.

**Phase 55: Proof + Adopter Guidance**
Goal: Freeze the supported owner-erasure contract with hermetic proof and
adopter-facing guidance.
Requirements: `PROOF-03`, `PROOF-04`
Success criteria:
1. Hermetic tests prove both orphan purge and retained-shared-asset behavior.
2. Adopter-facing proof or smoke coverage exercises the public facade instead
   of direct detach loops.
3. Guides describe dry-run/reporting, execute semantics, and retained-shared
   assets honestly.
4. Requirements, roadmap, and state stay traceable to the proof-added surface.

## Deferred to v1.11+ / Later

- tus Checksum / Concatenation
- `Upload-Defer-Length`
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions beyond the supported helper path
- Second streaming provider (Cloudflare/Bunny)
- `cancel_direct_upload/1` (Mux)
- Admin or bulk compliance orchestration for owner erasure
- Force-delete semantics for assets that still have surviving attachments

## Archive

- [.planning/milestones/v1.9-ROADMAP.md](milestones/v1.9-ROADMAP.md)
- [.planning/milestones/v1.9-REQUIREMENTS.md](milestones/v1.9-REQUIREMENTS.md)
- [.planning/milestones/v1.9-MILESTONE-AUDIT.md](milestones/v1.9-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.8-ROADMAP.md](milestones/v1.8-ROADMAP.md)
- [.planning/milestones/v1.8-REQUIREMENTS.md](milestones/v1.8-REQUIREMENTS.md)
- [.planning/milestones/v1.8-MILESTONE-AUDIT.md](milestones/v1.8-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.7-ROADMAP.md](milestones/v1.7-ROADMAP.md)
- [.planning/milestones/v1.7-REQUIREMENTS.md](milestones/v1.7-REQUIREMENTS.md)
- [.planning/milestones/v1.7-MILESTONE-AUDIT.md](milestones/v1.7-MILESTONE-AUDIT.md)
