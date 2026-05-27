# Requirements — Milestone v1.12 Adopter Truth & Maintenance Hygiene

**Milestone:** v1.12 — **shipped** 2026-05-27  
**Goal:** Align planning artifacts, JTBD frontier, public moduledocs, and API-surface tests with shipped v1.11 reality — without adding capability requirements.

## Requirements

### Planning truth

- [x] **TRUTH-01**: JTBD-MAP regenerated with anchor v1.11; no ranked gap treats shipped tus/Mux-direct/erasure as next default work.
- [x] **TRUTH-02**: MILESTONES.md includes v1.11 shipped entry; PROJECT Context/Support-Truth match shipped code.
- [x] **TRUTH-03**: Public moduledocs for streaming/direct-upload no longer claim Phase 37 deferral.

### Public surface & operations

- [x] **SURF-01**: API surface boundary test reflects intentional public modules (incl. GCS, Streaming, Provider, TusPlug).
- [x] **OPS-01**: Dependency patch/minor batch merged with green CI + install-smoke evidence.

### Proof

- [x] **PROOF-01**: Parity + install-smoke tus lane green; audit documents evidence paths.

## Out of Scope

- `cancel_direct_upload/1`
- Second streaming provider
- IETF RUFH / tus 2.0
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions
- Admin/bulk owner-erasure orchestration
- Force-delete semantics for still-shared assets

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRUTH-01 | 60 | validated |
| TRUTH-02 | 60 | validated |
| TRUTH-03 | 61 | validated |
| SURF-01 | 62 | validated |
| OPS-01 | 62 | validated |
| PROOF-01 | 63 | validated |
