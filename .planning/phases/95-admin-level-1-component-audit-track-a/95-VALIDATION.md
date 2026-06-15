---
phase: 95
slug: admin-level-1-component-audit-track-a
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-15
---

# Phase 95 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node scripts, Playwright Chromium, ExUnit/Mix |
| **Config file** | `examples/adoption_demo/playwright.config.js`; `mix.exs` |
| **Quick run command** | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` |
| **Full suite command** | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs && node brandbook/src/admin-gallery-check.mjs && mix test --include integration test/brandbook/admin_design_system_validation_test.exs` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs`
- **After every plan wave:** Run `node brandbook/src/admin-gallery-check.mjs`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 95-01-01 | 01 | 1 | UPLIFT-01 | T-95-01 | Generated admin CSS remains token-backed and synced to shipped CSS | build | `node brandbook/src/admin-css-build.mjs && git diff --exit-code -- brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` | yes | pending |
| 95-01-02 | 01 | 1 | UPLIFT-01 | T-95-02 | Contrast coverage includes all Level-1 state/theme pairs without one-off styles | build | `node brandbook/src/admin-contrast.mjs` | yes | pending |
| 95-02-01 | 02 | 1 | UPLIFT-01 | T-95-03 | Gallery exposes explicit component/state markers for the Level-1 matrix | browser | `node brandbook/src/admin-gallery-check.mjs` | yes | pending |
| 95-02-02 | 02 | 1 | UPLIFT-01 | T-95-04 | Integration wrapper validates generated artifacts and dependency boundaries | integration | `mix test --include integration test/brandbook/admin_design_system_validation_test.exs` | yes | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] Normalize shared Level-1 component and state constants so `form-controls`, `error-state`, `loading-state`, and singular component names are first-class.
- [ ] Extend `admin-gallery-check.mjs` to assert focus-visible token values, active-vs-focus distinction, disabled/loading/empty/error/skeleton coverage, and exact state markers.
- [ ] Decide whether the integration-tagged ExUnit invocation should be documented in the plan or made easier to run.

---

## Manual-Only Verifications

All Phase 95 behaviors have automated verification through Node, Playwright, or ExUnit gates.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references identified by research
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-15
