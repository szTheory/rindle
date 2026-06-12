---
phase: 88
slug: admin-design-system-ui-kit
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-11
audited: 2026-06-12
---

# Phase 88 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via `mix test`; Node scripts for token, CSS, gallery, and contrast gates; Playwright for browser screenshots |
| **Config file** | `mix.exs`; `test/test_helper.exs`; `examples/adoption_demo/package.json`; `examples/adoption_demo/playwright.config.js` |
| **Quick run command** | `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` |
| **Full suite command** | `mix coveralls`; `mix test test/brandbook/admin_design_system_validation_test.exs --include integration`; Phase 88 Node gates when debugging individual scripts |
| **Estimated runtime** | ~5 seconds for the focused validation test on a prepared local checkout |

The focused ExUnit validation is tagged `:integration` because it executes the
Playwright screenshot harness through `brandbook/src/admin-gallery-check.mjs`.
Default `mix test` / `mix coveralls` lanes do not need to install Node browser
dependencies just to validate non-admin library code. Phase 88 validation must
run the focused command explicitly.

---

## Sampling Rate

- **After every task commit:** Run the relevant generator/check command touched by that task.
- **After every plan wave:** Run `mix test test/brandbook/admin_design_system_validation_test.exs --include integration`.
- **Before `$gsd-verify-work`:** Run the focused validation test plus the phase-level checks recorded in `88-VERIFICATION.md`.
- **Before release prep:** Preserve the repo-level gates from `RUNNING.md`; Phase 88's browser validation remains an explicit focused lane.
- **Max feedback latency:** ~5 seconds locally for automated Phase 88 validation after Playwright dependencies are present; maintainer gallery review remains manual.

---

## Requirement Coverage Map

| Requirement | Status | Automated Evidence | Test File |
|-------------|--------|--------------------|-----------|
| DS-01 | COVERED | `node brandbook/src/admin-css-build.mjs`; generated CSS selector/theme/token assertions; generated drift check | `test/brandbook/admin_design_system_validation_test.exs` |
| DS-02 | COVERED | `node brandbook/src/admin-gallery-check.mjs`; exact theme transitions, confirm-dialog behavior, section anchors, and seven screenshot artifacts | `test/brandbook/admin_design_system_validation_test.exs` |
| DS-03 | COVERED | `node brandbook/src/admin-contrast.mjs`; `node brandbook/src/contrast.mjs`; contrast-pair context assertions | `test/brandbook/admin_design_system_validation_test.exs` |
| ADMIN-02 groundwork | COVERED | Guide command/package-boundary assertions; forbidden dependency/style leakage scan over implementation files; `mix.exs` package-boundary assertion | `test/brandbook/admin_design_system_validation_test.exs` |

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 88-01-T1 | 88-01 | 1 | DS-01, ADMIN-02 groundwork | T-88-01, T-88-02, T-88-05 | Generated CSS stays reproducible, namespaced, token-backed, and free of host UI dependency leakage | ExUnit + Node/golden smoke | `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` | Yes | green |
| 88-01-T2 | 88-01 | 1 | DS-03 | T-88-03 | Console token pairs meet WCAG AA thresholds mechanically and unknown tokens fail the gate | ExUnit + Node gate | `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` | Yes | green |
| 88-02-T1 | 88-02 | 2 | DS-01, DS-02, ADMIN-02 groundwork | T-88-06, T-88-07, T-88-08, T-88-10 | Static gallery renders allowlisted surfaces, states, components, and theme controls without host routing or styling dependency leakage | ExUnit + generated HTML/source assertions | `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` | Yes | green |
| 88-02-T2 | 88-02 | 2 | DS-02 | T-88-06, T-88-09 | Browser harness proves `data-theme` light/dark/auto behavior, confirmation gating, hash navigation, and screenshot artifact generation | ExUnit + Playwright harness | `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` | Yes | green |
| 88-03-T1 | 88-03 | 3 | DS-01, DS-02, DS-03, ADMIN-02 groundwork | T-88-13, T-88-14, T-88-15 | Operating guide documents commands, component inventory, package boundary, phase boundary, and forbidden dependencies | ExUnit source assertions | `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` | Yes | green |
| 88-03-T2 | 88-03 | 3 | DS-01, DS-02, DS-03, ADMIN-02 groundwork | T-88-11, T-88-12 | Maintainer visually approved the generated gallery after the section-anchor fix; screenshots remain generated from fixture data only | Playwright artifact check + human checkpoint | `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` plus maintainer approval recorded in `88-HUMAN-UAT.md` | Yes | green |

*Status: pending, green, red, flaky*

---

## Generated Validation Test

`test/brandbook/admin_design_system_validation_test.exs` covers:

- DS-01: CSS generator exit status, generated header, required BEM selectors, theme scopes, focus/motion tokens, `var(--rindle-...)` usage, and generated CSS drift.
- DS-02: gallery browser harness exit status, `data-theme="light|dark|auto"` controls, required `data-rindle-admin-component` selectors, six section anchors, confirmation fixture, and seven screenshot files.
- DS-03: console contrast context coverage plus admin/base contrast gate summaries.
- ADMIN-02 groundwork: admin design-system guide commands, package boundary, forbidden dependency list, forbidden implementation leakage scan, and no premature `priv/static/rindle_admin` package move.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions | Status |
|----------|-------------|------------|-------------------|--------|
| Maintainer reviews rendered component gallery before later console phases rely on it | DS-01, DS-02, DS-03, ADMIN-02 groundwork | Human visual acceptance is an explicit Phase 88 checkpoint; Playwright verifies behavior and screenshots but not taste/readability approval | Open `brandbook/admin-gallery/index.html` and review the seven screenshots for readable themes, unclipped text, visible focus, labeled status chips with non-color marks, and confirm-dialog collateral preview | approved in `88-HUMAN-UAT.md` and `88-VERIFICATION.md` |

---

## Validation Audit 2026-06-12

| Metric | Count |
|--------|-------|
| Gaps found | 4 |
| Resolved | 4 |
| Escalated | 0 |

Audit result:

- State A: existing `88-VALIDATION.md` was present but still reflected pre-execution Wave 0 pending checks.
- Added focused automated coverage in `test/brandbook/admin_design_system_validation_test.exs`.
- Converted DS-01, DS-02, DS-03, and ADMIN-02 groundwork from pending validation intent to covered requirement rows.
- Preserved the maintainer visual review as manual-only because the phase explicitly required human gallery approval.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or a recorded manual checkpoint.
- [x] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] Wave 0 coverage is implemented and represented by the focused validation test.
- [x] No watch-mode flags in verification commands.
- [x] Feedback latency < 180s for automated Phase 88 gates on a prepared checkout.
- [x] `nyquist_compliant: true` set in frontmatter after validation implementation.

**Approval:** automated coverage added; maintainer visual approval remains recorded from Phase 88 execution.
