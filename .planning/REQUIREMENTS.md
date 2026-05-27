# Requirements: Rindle

**Defined:** 2026-05-27
**Milestone:** v1.16 CI Enforcement & Planning Hygiene (gap closure)
**Core Value:** Media, made durable.

## v1.16 Requirements

Gap-closure milestone from [v1.15 audit](milestones/v1.15-MILESTONE-AUDIT.md). No new public feature surface. Execute phases **77 → 76 → 75**.

### CI Proof Enforcement

- [ ] **CI-03**: Dedicated merge-blocking `proof` CI job runs `docs_parity_test.exs` and
      `batch_owner_erasure_task_test.exs`; adopter partial doc grep removed; `RUNNING.md`
      matrix updated.

### Support Truth

- [ ] **TRUTH-05**: `docs_parity_test.exs` locks TusPlug moduledoc scope via `Code.fetch_docs/1`
      contract test; `@moduledoc` interpolates `@tus_extensions` (single source of truth).

### Planning Truth

- [ ] **PLAN-01**: v1.15 Nyquist metadata closure (phases 71–72 VALIDATION rows) and
      `STATE.md` position block aligned to shipped / between-milestones truth.

## v1.15 Requirements (shipped)

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

- [x] **VAL-01**: Phases 68–70 validation artifacts reach Nyquist-compliant state via
      `/gsd-validate-phase` or equivalent gap-fill.

### Support Truth

- [x] **TRUTH-04**: `guides/operations.md` reflects all shipped mix tasks; `TusPlug`
      moduledoc scope section matches implemented tus extensions.

### Milestone Audit

- [x] **AUDIT-01**: Milestone audit confirms 100% requirement coverage and no planning drift.

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
| CI-03 | Phase 75 | Pending |
| TRUTH-05 | Phase 76 | Pending |
| PLAN-01 | Phase 77 | Pending |
| CI-01 | Phase 71 | Complete |
| CI-02 | Phase 71 | Complete |
| PROOF-06 | Phase 72 | Complete |
| VAL-01 | Phase 73 | Complete |
| TRUTH-04 | Phase 74 | Complete |
| AUDIT-01 | Phase 74 | Complete |

**Coverage:**

- v1.16 requirements: 3 total
- Mapped to phases: 3
- Unmapped: 0 ✓
- v1.15 requirements: 6 total (all complete)

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after v1.16 gap closure phases (75–77)*
