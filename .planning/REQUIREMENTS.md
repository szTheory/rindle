# Requirements: Rindle v1.5 — Adopter Hardening & Lifecycle Repair

**Defined:** 2026-05-05
**Core Value:** Media, made durable.
**Source:** milestone-definition research across `.planning/research/` candidate
direction memos plus current project context in `.planning/PROJECT.md`.

## v1.5 Requirements

### Adopter Proof Matrix

- [x] **PROOF-01**: Maintainer can generate a fresh package-consumer Phoenix
  app for an image-only profile and prove install, upload, processing, and
  signed delivery from the published Rindle artifact.
- [x] **PROOF-02**: Maintainer can generate a fresh package-consumer Phoenix
  app for an AV-enabled profile and prove install, probe, transcode, local
  playback, and signed delivery from the published Rindle artifact.
- [x] **PROOF-03**: CI proves the canonical adopter matrix across local storage
  and at least one real S3-compatible path without regressing the existing
  happy path.
- [x] **PROOF-04**: README, getting-started, AV onboarding, and ops guidance
  are kept in lockstep with the proved package-consumer flows by executable
  parity gates.

### Lifecycle Repair Operations

- [ ] **REPAIR-01**: Operator can re-probe an asset and persist refreshed probe
  fields without mutating unrelated lifecycle state.
- [ ] **REPAIR-02**: Operator can requeue failed or cancelled variants for a
  specific asset through an idempotent public repair surface.
- [ ] **REPAIR-03**: Operator can regenerate a variant set after preset or
  profile changes through an auditable, explicit operation.
- [ ] **REPAIR-04**: Operator can sweep orphaned temp files, stale lifecycle
  rows, and other repairable residue on demand as well as through scheduled
  maintenance.
- [ ] **REPAIR-05**: Repair operations emit tagged, operator-readable failure
  reasons and do not silently hide partial failure.

### Runtime Diagnostics & Operational Visibility

- [ ] **DIAG-01**: `mix rindle.doctor` detects runtime capability drift,
  missing queues, delivery plug misconfiguration, and stale migration state
  with actionable fix guidance.
- [ ] **DIAG-02**: Rindle exposes a documented runtime status report or
  equivalent operator query path for stuck or failed assets, variants, and
  upload sessions.
- [ ] **DIAG-03**: Telemetry for repair flows, runtime refusals, and operational
  drift is frozen with documented measurements and metadata.

### Upgrade & Migration Safety

- [ ] **UPGRADE-01**: Maintainer can upgrade a pre-v1.4 adopter app into the
  current AV-aware schema/runtime shape using additive migrations and documented
  steps only.
- [ ] **UPGRADE-02**: Interrupted AV processing and partial-upgrade states can
  be recovered through documented repair commands that are proven in CI.
- [ ] **UPGRADE-03**: Release and upgrade guides teach both greenfield install
  and existing-adopter upgrade paths without assuming a fresh app.

## v1.6+ Candidate Requirements

### Deferred Breadth Expansion

- **GCS-01**: Add a truthful `Rindle.Storage.GCS` adapter with explicit
  resumable-upload session semantics.
- **STREAM-01**: Productize the provider boundary behind `streaming_url/3` with
  one reference delegated streaming adapter.
- **TUS-01**: Add a separate resumable-upload protocol family only if adopter
  demand proves it is worth widening the library boundary.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Bundled provider adapters in v1.5 | Widening the support matrix before AV hardening would multiply blast radius |
| GCS adapter in v1.5 | Valuable, but breadth work should follow one hardening milestone first |
| tus / resumable protocol in v1.5 | Too boundary-expanding versus current adopter-hardening priority |
| HLS / DASH / DRM / live streaming | Still outside Rindle's core lifecycle scope and belongs to provider-delegated or dedicated streaming work |
| Generic cleanup/refactor bucket | This milestone must stay outcome-based: proof, repair, diagnostics, and upgrade safety only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROOF-01 | Phase 29 | Complete (29-01) |
| PROOF-02 | Phase 29 | Complete (29-02) |
| PROOF-03 | Phase 29 | Complete (29-03) |
| PROOF-04 | Phase 29 | Complete (29-04) |
| REPAIR-01 | Phase 30 | Pending |
| REPAIR-02 | Phase 30 | Pending |
| REPAIR-03 | Phase 30 | Pending |
| REPAIR-04 | Phase 30 | Pending |
| REPAIR-05 | Phase 30 | Pending |
| DIAG-01 | Phase 31 | Pending |
| DIAG-02 | Phase 31 | Pending |
| DIAG-03 | Phase 31 | Pending |
| UPGRADE-01 | Phase 32 | Pending |
| UPGRADE-02 | Phase 32 | Pending |
| UPGRADE-03 | Phase 32 | Pending |

**Coverage:**
- v1.5 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-05-05*
*Last updated: 2026-05-06 after phase 29 execution*
