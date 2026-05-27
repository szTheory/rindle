# Roadmap: Rindle

## Milestones

- 🚧 **v1.14 Bulk Owner-Erasure Orchestration** — Phases 67–70 (in progress)
- ✅ **v1.13 Cancel Direct Upload** — Phases 64–66 (shipped 2026-05-27, [archive](milestones/v1.13-ROADMAP.md))
- ✅ **v1.12 Adopter Truth & Maintenance Hygiene** — Phases 60–63 (shipped 2026-05-27, [archive](milestones/v1.12-ROADMAP.md))
- ✅ **v1.11 Tus Protocol Completion** — Phases 56–59 (shipped 2026-05-27, [archive](milestones/v1.11-ROADMAP.md))
- ✅ **v1.10 Owner Account Erasure** — Phases 53–55 (shipped 2026-05-26, [archive](milestones/v1.10-ROADMAP.md))
- ✅ **v1.9 Phoenix Tus DX Completion** — Phases 48–52 (shipped 2026-05-25, [archive](milestones/v1.9-ROADMAP.md))
- ✅ **v1.8 Resumable Browser Ingest** — Phases 42–47 (shipped 2026-05-25, [archive](milestones/v1.8-ROADMAP.md))
- ✅ **v1.7 GCS Resumable Adapter** — Phases 37–41 (shipped 2026-05-08, [archive](milestones/v1.7-ROADMAP.md))
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07, [archive](milestones/v1.6-ROADMAP.md))
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06, [archive](milestones/v1.5-ROADMAP.md))
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, [archive](milestones/v1.4-ROADMAP.md))
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, [archive](milestones/v1.3-ROADMAP.md))
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, [archive](milestones/v1.2-ROADMAP.md))
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, [archive](milestones/v1.1-ROADMAP.md))
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, [archive](milestones/v1.0-ROADMAP.md))

## Phases

### Phase 67: Bulk erasure policy & contract

**Goal:** Freeze the batch erasure boundary before implementation lands.
**Depends on:** Phase 66 (v1.13)
**Requirements:** BULK-01, BULK-02

**Success criteria:**
1. Aggregate batch report type and per-owner report nesting are frozen in public `@spec`s.
2. Batch size limit, error vocabulary, and explicit non-goals (no force-delete, no admin UI) are documented.
3. Contract artifacts pass api_surface_boundary expectations for new public types.

### Phase 68: Batch erasure implementation

**Goal:** Implement batch preview/execute reusing `OwnerErasure` with per-owner isolation.
**Depends on:** Phase 67
**Requirements:** BULK-03, BULK-04, BULK-05

**Success criteria:**
1. Batch preview returns aggregate + per-owner reports matching v1.10 vocabulary.
2. Batch execute detaches and enqueues purge per owner without cross-owner transaction coupling.
3. Partial failure returns per-owner results; idempotent rerun is stable for cleared owners.

### Phase 69: Operator mix task

**Goal:** Ship documented operator surface for batch erasure preview/execute.
**Depends on:** Phase 68
**Requirements:** OPS-02

**Success criteria:**
1. `mix rindle.*` task accepts owner identity input with dry-run default.
2. Task `@moduledoc` defines exit codes, input format, and links to operations guide.
3. Execute mode requires explicit flag (no accidental destructive default).

### Phase 70: Proof & adopter guidance

**Goal:** Prove batch erasure behavior and document adopter/operator expectations.
**Depends on:** Phase 69
**Requirements:** PROOF-05, TRUTH-03

**Success criteria:**
1. Hermetic proof matrix covers batch preview, execute, partial failure, idempotent rerun, shared assets.
2. `guides/operations.md` or `guides/user_flows.md` documents batch erasure lane.
3. Docs parity test freezes batch erasure vocabulary and deferrals (force-delete, admin UI).

---

<details>
<summary>✅ v1.13 Cancel Direct Upload (Phases 64–66) — SHIPPED 2026-05-27</summary>

- [x] Phase 64: Cancel contract & persistence (4/4 plans) — completed 2026-05-27
- [x] Phase 65: Mux cancel implementation (2/2 plans) — completed 2026-05-27
- [x] Phase 66: Proof & adopter guidance (2/2 plans) — completed 2026-05-27

Full phase details: [.planning/milestones/v1.13-ROADMAP.md](milestones/v1.13-ROADMAP.md)

</details>

## Deferred to v1.15+ / Later

- Force-delete semantics for still-shared assets
- Second streaming provider (Cloudflare/Bunny)
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions
- Signed dynamic image transforms / EXIF privacy stripping

## Archive

- [.planning/milestones/v1.13-ROADMAP.md](milestones/v1.13-ROADMAP.md)
- [.planning/milestones/v1.13-REQUIREMENTS.md](milestones/v1.13-REQUIREMENTS.md)
- [.planning/milestones/v1.13-MILESTONE-AUDIT.md](milestones/v1.13-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.12-ROADMAP.md](milestones/v1.12-ROADMAP.md)
- [.planning/milestones/v1.12-REQUIREMENTS.md](milestones/v1.12-REQUIREMENTS.md)
- [.planning/milestones/v1.12-MILESTONE-AUDIT.md](milestones/v1.12-MILESTONE-AUDIT.md)
