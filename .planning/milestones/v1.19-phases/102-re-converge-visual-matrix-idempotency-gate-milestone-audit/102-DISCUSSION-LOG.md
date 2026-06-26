# Phase 102: Re-Converge - Visual Matrix, Idempotency Gate & Milestone Audit - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-18T23:28:22Z
**Phase:** 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
**Mode:** assumptions
**Areas analyzed:** Visual Gate Topology, Cohort Hard-Fail Readiness, Matrix Coverage And No-Regression, CI/Idempotency/Audit Closeout

## Assumptions Presented

### Visual Gate Topology

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 102's only merge-blocking visual gate should be the existing Playwright `adoption-demo-e2e` computed-style path: `assertAdminPolish` hard-fails over explicit admin and Cohort roots, while PNG captures, `toHaveScreenshot()`, and galleries remain non-blocking audit artifacts. | Confident | `.planning/ROADMAP.md`; `examples/adoption_demo/e2e/support/admin-polish.js`; `examples/adoption_demo/e2e/admin-screenshots.spec.js`; `.github/workflows/ci.yml` |

### Cohort Hard-Fail Readiness

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Before flipping Cohort warn to fail, the shared gate must become truly surface-aware for Cohort focus semantics and root-scoped outline scanning; Cohort dark coverage must be driven through `data-theme`/server route state, not Playwright `colorScheme` alone. | Confident | `.planning/phases/96-cohort-component-layer-dark-reduced-motion-contract-track-b/96-CONTEXT.md`; `examples/adoption_demo/e2e/support/admin-polish.js`; `examples/adoption_demo/e2e/cohort-pages.spec.js`; `examples/adoption_demo/priv/static/assets/cohort.css` |

### Matrix Coverage And No-Regression

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The unified matrix should preserve the current admin 24-state coverage and expand Cohort coverage from the existing `cohort-pages.spec.js` routes to full light/dark/mobile coverage for every inner page and upload tab, with existing behavior E2E/contract specs remaining the migration backstops. | Likely | `examples/adoption_demo/e2e/admin-screenshots.spec.js`; `examples/adoption_demo/e2e/cohort-pages.spec.js`; `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs`; `.planning/phases/100-cohort-upload-migration-all-tabs-track-b/100-VERIFICATION.md` |

### CI, Idempotency, And Audit Closeout

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Idempotency/audit closeout should use existing repo gates: generated admin CSS drift remains under `brandbook-tokens`, Cohort CSS remains hand-authored under `cohort-contrast`, the full `adoption_demo_e2e.sh` wrapper must be green, and requirements/docs closeout should follow the existing audit plus proof/docs parity patterns. Phase 102 likely must clear the current admin strict-locator E2E red before claiming the visual gate is green. | Likely | `.github/workflows/ci.yml`; `scripts/ci/adoption_demo_e2e.sh`; `.planning/phases/101-daisyui-retirement-track-b/deferred-items.md`; `.planning/REQUIREMENTS.md`; prior milestone audit artifacts |

## Corrections Made

No corrections - all assumptions confirmed by the user.

## External Research

No external research was performed. Codebase and planning artifacts provided enough evidence.
