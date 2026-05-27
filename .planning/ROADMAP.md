# Roadmap: Rindle

## Milestones

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

## Current Status

**Active Milestone:** None — v1.12 shipped 2026-05-27.

Use `$gsd-milestone-next-step` or `$gsd-new-milestone` to scope v1.13+ (demand-driven).

### ✅ Phase 60: Planning ledger & JTBD regeneration

- MILESTONES.md v1.11 + v1.8 entries; JTBD-MAP anchor v1.11; PROJECT/STATE drift fixed.

### ✅ Phase 61: Support-truth cleanup

- Removed stale Phase 37 deferral wording from streaming moduledocs and webhook table.

### ✅ Phase 62: Public surface & dependency hygiene

- Extended `api_surface_boundary_test`; patch/minor dep updates; tests green.

### ✅ Phase 63: Proof closure & milestone audit

- Parity + tus_plug tests green; `v1.12-MILESTONE-AUDIT.md` published.

## Deferred to v1.13+ / Later

- `cancel_direct_upload/1` (Mux) — demand-driven (see assessment thread)
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions beyond the supported helper path
- Second streaming provider (Cloudflare/Bunny)
- Admin or bulk compliance orchestration for owner erasure
- Force-delete semantics for assets that still have surviving attachments

## Archive

- [.planning/milestones/v1.12-ROADMAP.md](milestones/v1.12-ROADMAP.md)
- [.planning/milestones/v1.12-REQUIREMENTS.md](milestones/v1.12-REQUIREMENTS.md)
- [.planning/milestones/v1.12-MILESTONE-AUDIT.md](milestones/v1.12-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.11-MILESTONE-AUDIT.md](milestones/v1.11-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.10-ROADMAP.md](milestones/v1.10-ROADMAP.md)
- [.planning/milestones/v1.10-REQUIREMENTS.md](milestones/v1.10-REQUIREMENTS.md)
- [.planning/milestones/v1.10-MILESTONE-AUDIT.md](milestones/v1.10-MILESTONE-AUDIT.md)
