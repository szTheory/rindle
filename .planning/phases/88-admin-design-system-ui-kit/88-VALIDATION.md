---
phase: 88
slug: admin-design-system-ui-kit
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-11
---

# Phase 88 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via `mix test`; Node scripts for token, CSS, and contrast gates; Playwright 1.60.0 for screenshots |
| **Config file** | `mix.exs`; `examples/adoption_demo/playwright.config.js`; no root Playwright config |
| **Quick run command** | `node brandbook/src/tokens-build.mjs && node brandbook/src/contrast.mjs` plus Phase 88 admin generator/check commands after Wave 0 creates them |
| **Full suite command** | `mix coveralls`; Phase 88 Node gates; gallery screenshot command |
| **Estimated runtime** | ~180 seconds after screenshot harness exists |

---

## Sampling Rate

- **After every task commit:** Run the relevant generator/check command touched by that task.
- **After every plan wave:** Run all Phase 88 Node gates plus the gallery screenshot command.
- **Before `$gsd-verify-work`:** `mix coveralls`, Node token/admin contrast gates, and gallery screenshot review artifacts must be green or explicitly reviewed.
- **Max feedback latency:** 180 seconds for automated gates; maintainer gallery review remains manual.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 88-W0-01 | TBD | 0 | DS-01 | T-88-01 | Generated CSS stays namespaced and reproducible from token source | Node/golden smoke | `node brandbook/src/admin-css-build.mjs && rg -F '.rindle-admin-' brandbook/tokens/rindle-admin.css && rg -F -- '--rindle-' brandbook/tokens/rindle-admin.css` | No - Wave 0 | pending |
| 88-W0-02 | TBD | 0 | DS-02 | T-88-02 | Theme picker accepts only `light`, `dark`, and `auto` states | Playwright/browser smoke | `cd examples/adoption_demo && npx playwright test e2e/admin-gallery.spec.js --project=chromium` | No - Wave 0 | pending |
| 88-W0-03 | TBD | 0 | DS-03 | T-88-03 | Component token pairs meet WCAG AA thresholds mechanically | Node gate | `node brandbook/src/admin-contrast.mjs` | No - Wave 0 | pending |
| 88-W0-04 | TBD | 0 | ADMIN-02 groundwork | T-88-04 | Generated assets do not depend on host Tailwind, daisyUI, shadcn, or Radix packages | Static scan/package assertion | `rg -n 'tailwind|daisy|shadcn|radix|@apply|class="[^"]*(btn|card)' brandbook/tokens/rindle-admin.css brandbook/admin-gallery` must return no dependency leakage matches | No - Wave 0 | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] `brandbook/src/admin-css-build.mjs` - generates DS-01 component CSS.
- [ ] `brandbook/src/admin-contrast.mjs` or an extension to `brandbook/src/contrast.mjs` - covers DS-03 console token pairs.
- [ ] `brandbook/admin-gallery/index.html` or equivalent static gallery - renders all required components and states.
- [ ] `examples/adoption_demo/e2e/admin-gallery.spec.js` or a dedicated static gallery screenshot script - captures light, dark, and auto theme screenshots.
- [ ] Optional ExUnit package/file test if generated admin assets enter `mix.exs` package files in this phase.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Maintainer reviews rendered component gallery before later console phases rely on it | DS-01, DS-02, DS-03, ADMIN-02 groundwork | Human visual review is an explicit Phase 88 success criterion | Open the generated gallery, review screenshots for light/dark/auto themes and required component states, then record approval or requested changes in the phase summary |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify commands or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing validation references.
- [ ] No watch-mode flags in verification commands.
- [ ] Feedback latency < 180s for automated gates.
- [ ] `nyquist_compliant: true` set in frontmatter after Wave 0 validation is implemented.

**Approval:** pending
