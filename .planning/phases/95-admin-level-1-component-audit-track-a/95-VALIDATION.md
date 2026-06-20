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
| **Full suite command** | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs && node brandbook/src/admin-gallery-check.mjs && node brandbook/src/sync-admin-css.mjs && cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css && mix test --include integration test/brandbook/admin_design_system_validation_test.exs` |
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
| 95-02-02 | 02 | 1 | UPLIFT-01 | T-95-05/T-95-06 | Gallery checker validates component/state matrix, focus-visible tokens, active-vs-focus distinction, and live polish focus/no-outline helpers | browser | `node --check examples/adoption_demo/e2e/support/admin-polish.js && grep -q 'requiredComponentStateMatrix' brandbook/src/admin-gallery-check.mjs && grep -q 'assertComponentStateMatrix' brandbook/src/admin-gallery-check.mjs && out=$(node brandbook/src/admin-gallery-check.mjs) && case "$out" in *'admin gallery check passed - 10 screenshots written'*) printf '%s\n' "$out";; *) printf '%s\n' "$out"; exit 1;; esac && grep -q 'OVERLAP_ENFORCED = false' examples/adoption_demo/e2e/support/admin-polish.js` | yes | pending |
| 95-03-01 | 03 | 3 | UPLIFT-01 | T-95-10/T-95-12 | ExUnit wrapper and guide encode the Phase 95 contract without running the full integration gate before shipped CSS sync | source/docs | `mix format --check-formatted test/brandbook/admin_design_system_validation_test.exs && grep -q 'form-controls' test/brandbook/admin_design_system_validation_test.exs && grep -q 'admin gallery check passed - 10 screenshots written' test/brandbook/admin_design_system_validation_test.exs && grep -q 'form-controls-light.png' test/brandbook/admin_design_system_validation_test.exs && grep -q 'node brandbook/src/sync-admin-css.mjs' guides/admin_design_system.md && grep -q 'focus-visible' guides/admin_design_system.md && grep -Eq 'outline: ?none' guides/admin_design_system.md` | yes | pending |
| 95-03-02 | 03 | 3 | UPLIFT-01 | T-95-09/T-95-11 | Shipped CSS is byte-identical to brandbook CSS and the ExUnit wrapper runs only after sync with integration tests included | integration | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs && node brandbook/src/admin-gallery-check.mjs && node brandbook/src/sync-admin-css.mjs && cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css && mix_out=$(mix test --include integration test/brandbook/admin_design_system_validation_test.exs) && case "$mix_out" in *'0 tests, 0 failures'*) exit 1;; esac && printf '%s\n' "$mix_out"` | yes | pending |

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
