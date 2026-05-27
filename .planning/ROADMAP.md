# Roadmap: Rindle

## Milestones

- 🚧 **v1.13 Cancel Direct Upload** — Phases 64–66 (started 2026-05-27)
- ✅ **v1.12 Adopter Truth & Maintenance Hygiene** — Phases 60–63 (shipped 2026-05-27, see archive)
- ✅ **v1.11 Tus Protocol Completion** — Phases 56–59 (shipped 2026-05-27, see archive)
- ✅ **v1.10 Owner Account Erasure** — Phases 53–55 (shipped 2026-05-26, see archive)
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

## Milestone Goal (v1.13)

Give adopters a first-class way to abort an abandoned Mux direct creator upload
before the browser finishes PUT, using the same `asset_id` they received at
create time.

## Phase Plan

| Phase | Name | Goal | Requirements | Success criteria |
|-------|------|------|--------------|------------------|
| 64 | Cancel contract & persistence | 4/4 | Complete   | 2026-05-27 |
| 65 | Mux cancel implementation | Ship adapter + `Streaming.cancel_direct_upload/1` | CANCEL-04 | 3 |
| 66 | Proof & adopter guidance | Tests + guide note | PROOF-01, TRUTH-01 | 3 |

**Coverage:** 6/6 requirements mapped ✓

### Phase 64: Cancel contract & persistence

**Goal:** Freeze the public cancel boundary before code lands.

**Requirements:** CANCEL-01, CANCEL-02, CANCEL-03

**Success criteria:**

1. Public `@spec` and error vocabulary for `cancel_direct_upload/1` are documented.
2. Additive persistence for provider `upload_id` is specified (migration or metadata field).
3. FSM allowlist includes a terminal cancel edge from `uploading` (and `pending` if applicable).
4. Security invariant 14 redaction rules apply to stored `upload_id`.

### Phase 65: Mux cancel implementation

**Goal:** Implement cancel end-to-end for Mux direct creator uploads.

**Requirements:** CANCEL-04

**Success criteria:**

1. Mux adapter implements optional `cancel_direct_upload/1` via `Mux.Video.Uploads.cancel/2`.
2. `Rindle.Streaming.cancel_direct_upload/1` resolves profile, loads row, calls adapter, updates FSM.
3. Idempotent cancel when Mux upload already cancelled or row already terminal.

### Phase 66: Proof & adopter guidance

**Goal:** Prove cancel behavior and document adopter expectations.

**Requirements:** PROOF-01, TRUTH-01

**Success criteria:**

1. Hermetic Mux ClientMock tests cover cancel + error normalization.
2. Streaming integration test covers create → cancel → terminal state.
3. `guides/streaming_providers.md` includes cancel section with Mux-only scope note.

## Deferred to v1.14+ / Later

- Admin/bulk owner-erasure orchestration
- Force-delete semantics for still-shared assets
- Second streaming provider (Cloudflare/Bunny)
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions

## Archive

- [.planning/milestones/v1.12-ROADMAP.md](milestones/v1.12-ROADMAP.md)
- [.planning/milestones/v1.12-REQUIREMENTS.md](milestones/v1.12-REQUIREMENTS.md)
- [.planning/milestones/v1.12-MILESTONE-AUDIT.md](milestones/v1.12-MILESTONE-AUDIT.md)
