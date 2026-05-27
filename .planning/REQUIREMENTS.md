# Requirements: Rindle v1.14 — Bulk Owner-Erasure Orchestration

**Defined:** 2026-05-27
**Core Value:** Media, made durable.

**Goal:** Extend the shipped v1.10 single-owner erasure facade with batch preview/execute
and an operator surface so compliance teams can orchestrate multi-owner erasure without
hand-rolled loops — policy-first, reusing `OwnerErasure` internals.

## v1.14 Requirements

### Bulk Erasure Policy & Contract

- [ ] **BULK-01**: Operator can preview erasure for a bounded batch of owners and receive
      an aggregate report with per-owner `owner_erasure_report()` entries plus batch totals
      for attachments to detach, assets to purge, and retained shared assets.
- [ ] **BULK-02**: Batch preview enforces a configurable maximum owner count (default bounded)
      and returns a tagged error when the batch exceeds the limit.
- [ ] **BULK-03**: Batch execute processes each owner through the existing single-owner
      erasure planner with transactional per-owner isolation — one owner failure does not
      roll back completed owners in the batch.

### Batch Implementation

- [ ] **BULK-04**: Adopter can execute batch owner erasure through one public API call that
      reuses `Rindle.Internal.OwnerErasure` and preserves the v1.10 report vocabulary per owner.
- [ ] **BULK-05**: Re-running batch erasure for the same owner set is idempotent and returns
      stable no-op/report results for already-cleared owners.

### Operator Surface

- [ ] **OPS-02**: Operator can run batch owner-erasure preview or execute from a `mix rindle.*`
      task with documented CLI contract (owner identity input format, dry-run default, exit codes).

### Proof & Support Truth

- [ ] **PROOF-05**: Hermetic proof covers batch preview aggregation, per-owner isolation on
      execute, partial failure handling, idempotent rerun, and retained shared-asset semantics
      unchanged from v1.10.
- [ ] **TRUTH-03**: Guides and active planning artifacts document batch erasure as the supported
      multi-owner orchestration surface and explicitly defer force-delete, admin UI, and scheduler
      workflows.

## Future Requirements

- **LIFE-06**: Force-delete policy for assets with surviving attachments (explicit opt-in
  destructive policy — separate milestone).
- **STREAM-10**: Second streaming provider as contract test (explicit demand only).
- **TRANS-01**: Signed dynamic image transforms (job 33 — explicit adopter pull).
- **PRIV-01**: EXIF privacy stripping on originals (job 34 — explicit adopter pull).

## Out of Scope

| Feature | Reason |
|---------|--------|
| Force-delete for assets with surviving attachments | Conflicts with v1.10 conservative shared-asset contract; separate high-blast-radius milestone |
| Admin LiveView UI for erasure | Operator UI is not required; mix task + API sufficient |
| Scheduler/cron-driven erasure jobs | Host-app concern; Rindle provides orchestration primitives only |
| Changes to single-owner `preview_owner_erasure/2` / `erase_owner/2` semantics | v1.10 contract frozen; batch wraps existing planner |
| Bulk Mux/streaming/tus operations | Unrelated to lifecycle erasure wedge |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BULK-01 | Phase 67 | Pending |
| BULK-02 | Phase 67 | Pending |
| BULK-03 | Phase 68 | Pending |
| BULK-04 | Phase 68 | Pending |
| BULK-05 | Phase 68 | Pending |
| OPS-02 | Phase 69 | Pending |
| PROOF-05 | Phase 70 | Pending |
| TRUTH-03 | Phase 70 | Pending |

**Coverage:**
- v1.14 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after milestone v1.14 roadmap creation*
