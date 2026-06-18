---
phase: 101
slug: daisyui-retirement-track-b
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-18
---

# Phase 101 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for deterministic source/render gates; Playwright for browser backstops |
| **Config file** | `examples/adoption_demo/test/test_helper.exs`; `examples/adoption_demo/playwright.config.js` |
| **Quick run command** | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` |
| **Full suite command** | `cd examples/adoption_demo && mix test` |
| **Estimated runtime** | ~60-180 seconds targeted; full browser lane depends on local services |

---

## Sampling Rate

- **After every task commit:** Run `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs`
- **After every CSS or visual markup change:** Run `node brandbook/src/cohort-contrast.mjs`
- **After every plan wave:** Run `cd examples/adoption_demo && mix test`
- **Before deleting `default.css`:** Targeted ExUnit retirement/source gate must be green except for the expected link/file assertions being introduced in the same destructive step.
- **Before `/gsd:verify-work`:** Run targeted ExUnit, full `mix test`, `node brandbook/src/cohort-contrast.mjs`, `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js`, and the upload behavior specs or full `bash scripts/ci/adoption_demo_e2e.sh`.
- **Max feedback latency:** keep deterministic ExUnit/CSS feedback under 5 minutes before moving to browser backstops.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 101-01-01 | 01 | 1 | COHORT-05 | T-101-01 | Flash uses escaped HEEx text; no `raw/1` or sensitive flash data introduced | source/render | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | yes | pending |
| 101-01-02 | 01 | 1 | COHORT-05 | T-101-02 | Info flash is polite status; error flash is assertive alert; manual dismiss only | source/render | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | yes | pending |
| 101-01-03 | 01 | 1 | COHORT-05 | - | `.ck-flash` / `.ck-alert` CSS uses existing `--ck-*` tokens and no literal color values | static CSS | `node brandbook/src/cohort-contrast.mjs` | yes | pending |
| 101-01-04 | 01 | 1 | COHORT-05 | - | Layout wrapper Tailwind utilities are absent from source and full composed render | source/render | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | yes | pending |
| 101-01-05 | 01 | 1 | COHORT-05 | - | Dead generator landing files are deleted, not excluded from scans | source/file | `cd examples/adoption_demo && mix test` | yes | pending |
| 101-01-06 | 01 | 1 | COHORT-05 | - | `default.css` link is removed and `priv/static/assets/default.css` no longer exists | source/file | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | no, needs W0 assertions | pending |
| 101-01-07 | 01 | 1 | COHORT-05 | - | Pages remain styled and upload behavior still works after scaffold removal | browser | `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js` | yes | pending |

---

## Wave 0 Requirements

- [ ] `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` - widen `assert_daisyui_retired/1` to full composed render rather than `page_body/1`.
- [ ] `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` - add source/file assertions for `root.html.heex`, `core_components.ex`, `layouts.ex`, deleted generator files, and deleted `default.css`.
- [ ] `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` - add explicit info/error flash render assertions for role, `aria-live`, `.ck-alert--*`, inline SVG replacement, and keyed manual dismiss.
- [ ] `examples/adoption_demo/priv/static/assets/cohort.css` - add `.ck-flash` / `.ck-alert` before expecting the contrast/literal gate to remain green.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Final visual judgment for toast placement and no unstyled page regression | COHORT-05 | Existing Playwright polish lane is warn-mode and does not fail Phase 101 on visual judgement | Review local Playwright output/screenshots for the 8 Cohort inner pages and `/upload` tabs after `default.css` deletion. Confirm no page appears unstyled and flash placement does not occlude primary upload controls. |

---

## Required Automated Backstops

| Behavior | Command |
|----------|---------|
| Retirement contract | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` |
| Full adoption demo unit lane | `cd examples/adoption_demo && mix test` |
| Cohort literal/color scanner | `node brandbook/src/cohort-contrast.mjs` |
| Cohort page polish backstop | `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js` |
| Upload behavior backstop | `cd examples/adoption_demo && npx playwright test e2e/image-upload.spec.js e2e/video-upload.spec.js e2e/multipart-upload.spec.js e2e/liveview-upload.spec.js e2e/mux-streaming.spec.js e2e/tus-resume.spec.js` |
| Full CI-like browser lane | `bash scripts/ci/adoption_demo_e2e.sh` |

---

## Validation Sign-Off

- [ ] All PLAN.md tasks have automated verify commands or cite the Wave 0 assertions above.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing deterministic assertions from `101-RESEARCH.md`.
- [ ] No watch-mode flags.
- [ ] Feedback latency under 5 minutes for deterministic gates.
- [ ] `nyquist_compliant: true` set in frontmatter after PLAN.md tasks map to this strategy.

**Approval:** pending
