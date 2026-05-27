# Requirements: Rindle

**Defined:** 2026-05-27
**Milestone:** v1.15 Maintenance & Proof Honesty
**Core Value:** Media, made durable.

## v1.15 Requirements

Maintenance-only milestone. No new public feature surface.

### CI Proof Honesty

- [x] **CI-01**: Maintainer can read a CI lane severity matrix (merge-blocking vs advisory)
      in `RUNNING.md` covering quality, integration, contract, package-consumer, adopter,
      and optional soak lanes.

- [x] **CI-02**: `package-consumer` and `adopter` workflow jobs fail the workflow on failure
      (remove job-level `continue-on-error: true`).

### Operator Proof

- [x] **PROOF-06**: Mix task integration test drives `batch_owner_failed` partial report
      printing and exit 1 when batch execute fails mid-run.

### Validation Closure

- [ ] **VAL-01**: Phases 68–70 validation artifacts reach Nyquist-compliant state via
      `/gsd-validate-phase` or equivalent gap-fill.

### Support Truth

- [ ] **TRUTH-04**: `guides/operations.md` reflects all shipped mix tasks; `TusPlug`
      moduledoc scope section matches implemented tus extensions.

### Milestone Audit

- [ ] **AUDIT-01**: Milestone audit confirms 100% requirement coverage and no planning drift.

## Future Requirements

Deferred to v1.16+ (demand-gated):

- **LIFE-06**: Force-delete policy for assets with surviving attachments
- **STREAM-10**: Second streaming provider as contract test
- **TRANS-01**: Signed dynamic image transforms (job 33)
- **PRIV-01**: EXIF privacy stripping on originals (job 34)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Force-delete shared assets | Separate high-blast-radius milestone; not bundled into maintenance |
| Second streaming provider | Explicit adopter demand only |
| New public API surface | Maintenance milestone charter |
| Admin LiveView erasure UI | Host-app concern |
| Release CI bypass removal | High-impact; document in CI-01 matrix; tighten separately if needed |
| Making dialyzer/credo merge-blocking | Advisory lanes remain in quality job for now |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CI-01 | Phase 71 | Complete |
| CI-02 | Phase 71 | Complete |
| PROOF-06 | Phase 72 | Complete |
| VAL-01 | Phase 73 | Pending |
| TRUTH-04 | Phase 74 | Pending |
| AUDIT-01 | Phase 74 | Pending |

**Coverage:**

- v1.15 requirements: 6 total
- Mapped to phases: 6
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after milestone v1.15 roadmap creation*
