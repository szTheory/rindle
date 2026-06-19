---
phase: 102
slug: re-converge-visual-matrix-idempotency-gate-milestone-audit
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-19
---

# Phase 102 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright `@playwright/test@1.60.0` for browser matrix; ExUnit/Mix for Cohort contract checks; Node scripts for static token/contrast/idempotency gates |
| **Config file** | `examples/adoption_demo/playwright.config.js`; `examples/adoption_demo/mix.exs`; `.github/workflows/ci.yml` |
| **Quick run command** | `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js` |
| **Targeted command** | `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js e2e/cohort-pages.spec.js e2e/cohort-styleguide.spec.js` |
| **Contract command** | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` |
| **Static command** | `node brandbook/src/cohort-contrast.mjs` |
| **Full suite command** | `bash scripts/ci/adoption_demo_e2e.sh` |
| **Estimated runtime** | quick: <10s; targeted/static/contract: minutes; full wrapper: CI-scale |

---

## Sampling Rate

- **After every task commit:** Run the quick JS syntax command plus the narrow command for the touched surface.
- **After every plan wave:** Run the targeted Playwright matrix specs, `cohort_migration_contract_test.exs`, and `cohort-contrast.mjs`.
- **Before `$gsd-verify-work`:** Full `scripts/ci/adoption_demo_e2e.sh`, brandbook double-run diff proof, traceability docs, and milestone audit evidence must be green/current.
- **Max feedback latency:** Use quick syntax/static/contract checks before expensive browser wrapper runs; do not batch more than two implementation tasks without an automated proof command.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 102-W0-01 | TBD | 0 | VIS-01, VIS-02 | T-102-01 | Admin root assertions stay explicit and strict-locator safe | source + Playwright | `node --check examples/adoption_demo/e2e/support/admin.js examples/adoption_demo/e2e/admin-screenshots.spec.js` | yes | pending |
| 102-W0-02 | TBD | 0 | VIS-01 | T-102-02 | Cohort hard-fail visual assertions cannot be bypassed by warn-mode catches | source + Playwright | `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js` | yes | pending |
| 102-W0-03 | TBD | 0 | VIS-01, VIS-02 | T-102-03 | Theme params are allowlisted and rendered dark state is asserted | ExUnit + Playwright | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | yes | pending |
| 102-W1-01 | TBD | 1 | VIS-01, VIS-02 | T-102-02 | Admin + Cohort matrix fails on computed-style defects across light/dark/mobile | Playwright | `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js e2e/cohort-pages.spec.js e2e/cohort-styleguide.spec.js` | yes | pending |
| 102-W1-02 | TBD | 1 | VIS-02, VIS-03, VIS-04 | T-102-04 | Optional visual artifacts remain non-blocking and secrets are not exposed | static + docs | `node brandbook/src/cohort-contrast.mjs && node brandbook/src/admin-gallery-check.mjs` | yes | pending |
| 102-W2-01 | TBD | 2 | VIS-02 | T-102-05 | Generated admin assets are idempotent and Cohort CSS remains hand-authored | idempotency | `node brandbook/src/tokens-build.mjs && node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs && node brandbook/src/admin-gallery-check.mjs && node brandbook/src/sync-admin-css.mjs && node brandbook/src/cohort-contrast.mjs && git diff --exit-code` | yes | pending |
| 102-W2-02 | TBD | 2 | VIS-01, VIS-02, VIS-03, VIS-04 | T-102-06 | Milestone claims match exact verification evidence | full gate + audit | `bash scripts/ci/adoption_demo_e2e.sh` | yes | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `examples/adoption_demo/e2e/support/admin.js` - strict admin root locator disambiguation.
- [ ] `examples/adoption_demo/e2e/support/admin-polish.js` - explicit focus contract and surface/admin-backstop scoping.
- [ ] Cohort LiveViews - rendered light/dark route support for non-upload migrated pages.
- [ ] Cohort E2E route matrix - hard-fail light/dark/mobile coverage across locked Cohort surfaces.
- [ ] Closeout docs - traceability, roadmap, state, and v1.19 milestone audit evidence plan.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| v1.19 milestone audit truthfulness | VIS-04 | Requires comparing command evidence, traceability claims, and release-train posture | Review `.planning/milestones/v1.19-MILESTONE-AUDIT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` after all commands pass. |
| Optional pixel/gallery artifact classification | VIS-03, VIS-04 | Non-blocking status is a documentation and CI-topology assertion, not only a runtime behavior | Confirm `.github/workflows/ci.yml` and Playwright specs do not make screenshots the VIS-01 blocker; audit docs must label them non-blocking if present. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify commands or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive implementation tasks without automated verify.
- [ ] Wave 0 covers all missing readiness references.
- [ ] No watch-mode flags.
- [ ] Full wrapper and idempotency proof are recorded before closure.
- [ ] `nyquist_compliant: true` set in frontmatter after planner maps tasks to concrete plan IDs.

**Approval:** pending
