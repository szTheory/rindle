---
phase: 92
slug: e2e-screenshot-driven-polish-loop
status: current
nyquist_compliant: true
plan_count: 5
task_count: 10
waves: 4
created: 2026-06-13
---

# Phase 92 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright (`@playwright/test`) plus targeted ExUnit for admin LiveViews |
| **Config file** | `examples/adoption_demo/playwright.config.js` |
| **Quick run command** | `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js` |
| **Full suite command** | `bash scripts/ci/adoption_demo_e2e.sh` |
| **Estimated runtime** | ~5-15 minutes for full adoption demo lane |

---

## Sampling Rate

- **After every task commit:** Run the targeted Playwright or ExUnit command named in the task.
- **After every plan wave:** Run `bash scripts/maintainer/check_adoption_proof_matrix.sh` plus the relevant admin Playwright specs.
- **Before `$gsd-verify-work`:** `bash scripts/ci/adoption_demo_e2e.sh` and `mix precommit` must pass.
- **Max feedback latency:** Targeted specs should give feedback in under 120 seconds; the full lane is acceptable only at plan/phase gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement(s) | Threat Ref(s) | Validation Focus | Automated Command(s) | Artifact / Source Check |
|---------|------|------|----------------|---------------|------------------|----------------------|-------------------------|
| 92-01-01 | 92-01 | 1 | E2E-01 | T-92-01, T-92-04, T-92-SC | Shared admin helper exports route, shell, theme, detail-link, redaction, and no-horizontal-scroll assertions. | <code>node -e "const admin = require('./examples/adoption_demo/e2e/support/admin'); if (admin.ADMIN_BASE !== '/admin/rindle') throw new Error('bad base'); if (admin.adminPath('assets') !== '/admin/rindle/assets') throw new Error('bad assets path'); if (admin.adminPath('/actions') !== '/admin/rindle/actions') throw new Error('bad slash path'); for (const key of ['visitAdmin','expectAdminShell','selectAdminTheme','firstAdminDetailHref','expectNoAdminRawSecrets','expectNoHorizontalScroll']) if (typeof admin[key] !== 'function') throw new Error('missing '+key);"</code> | `examples/adoption_demo/e2e/support/admin.js` exports required helpers and contains no `data-testid`. |
| 92-01-02 | 92-01 | 1 | E2E-01 | T-92-02, T-92-03 | Stable `data-rindle-admin-*` selectors render for actions, previews, forms, submits, and detail links. | <code>MIX_ENV=test mix test test/rindle/admin/live/actions_live_test.exs test/rindle/admin/live/home_assets_upload_test.exs</code><br><code>rg -n "data-testid" lib/rindle/admin && exit 1 &#124;&#124; exit 0</code> | Admin LiveView tests pass; `lib/rindle/admin` contains no `data-testid`. |
| 92-02-01 | 92-02 | 2 | E2E-01 | T-92-05, T-92-06, T-92-07, T-92-08, T-92-SC | Surface navigation, boundary states, detail pages, redaction, and horizontal-scroll checks. | <code>cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js</code><br><code>rg -n "data-testid&#124;waitForTimeout" examples/adoption_demo/e2e/admin-console.spec.js && exit 1 &#124;&#124; exit 0</code> | `admin-console.spec.js` imports `./support/admin`, uses admin selectors, and has no sleeps/test IDs. |
| 92-02-02 | 92-02 | 2 | E2E-01 | T-92-06, T-92-08, T-92-SC | Theme picker proof for light, dark, and auto through app-level controls. | <code>cd examples/adoption_demo && npx playwright test e2e/admin-theme.spec.js</code><br><code>rg -n "data-testid&#124;waitForTimeout&#124;emulateMedia" examples/adoption_demo/e2e/admin-theme.spec.js && exit 1 &#124;&#124; exit 0</code> | `admin-theme.spec.js` uses `selectAdminTheme` and does not rely on media emulation only. |
| 92-03-01 | 92-03 | 2 | E2E-01 | T-92-09, T-92-10, T-92-12, T-92-13 | Destructive owner and batch erasure coverage: preview, wrong confirmation blocking, exact confirmation, and receipts. | <code>cd examples/adoption_demo && npx playwright test e2e/admin-actions.spec.js --grep "owner&#124;batch"</code><br><code>rg -n "data-testid&#124;waitForTimeout" examples/adoption_demo/e2e/admin-actions.spec.js && exit 1 &#124;&#124; exit 0</code> | `admin-actions.spec.js` executes only generated owners and keeps seeded shared fixtures preview-only. |
| 92-03-02 | 92-03 | 2 | E2E-01 | T-92-10, T-92-11, T-92-13 | Non-destructive lifecycle repair, variant regeneration, and read-only quarantine review coverage. | <code>cd examples/adoption_demo && npx playwright test e2e/admin-actions.spec.js --grep "lifecycle&#124;variant&#124;quarantine"</code><br><code>cd examples/adoption_demo && npx playwright test e2e/admin-actions.spec.js</code> | Quarantine review has no submit controls or un-quarantine mutation. |
| 92-04-01 | 92-04 | 3 | E2E-02 | T-92-14, T-92-16, T-92-18 | Live Phoenix admin screenshot matrix captures light/dark desktop screens plus mobile shell/actions artifacts. | <code>cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js</code><br><code>test -f examples/adoption_demo/test-results/admin-screenshots/light/home-status.png && test -f examples/adoption_demo/test-results/admin-screenshots/dark/actions-owner-preview.png && test -f examples/adoption_demo/test-results/admin-screenshots/mobile/light/actions.png</code> | 22 expected PNGs exist under ignored `examples/adoption_demo/test-results/admin-screenshots/`. |
| 92-04-02 | 92-04 | 3 | E2E-02 | T-92-15, T-92-17, T-92-18 | Screenshot analyze-to-fix loop preserves generated CSS parity and records fix/no-regression evidence. | <code>node brandbook/src/admin-css-build.mjs</code><br><code>cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css</code><br><code>MIX_ENV=test mix test test/brandbook/admin_design_system_validation_test.exs test/rindle/admin/live/actions_live_test.exs</code><br><code>cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js</code> | `92-04-SUMMARY.md` lists fixes or the exact no-regression sentence required by the plan. |
| 92-05-01 | 92-05 | 4 | E2E-01, E2E-02 | T-92-19, T-92-23 | Proof matrix, drift gate, and README name all admin behavior and screenshot specs plus screenshot output path. | <code>bash scripts/maintainer/check_adoption_proof_matrix.sh</code><br><code>rg -n "e2e/admin-console.spec.js&#124;e2e/admin-theme.spec.js&#124;e2e/admin-actions.spec.js&#124;e2e/admin-screenshots.spec.js&#124;test-results/admin-screenshots" examples/adoption_demo/docs/adoption-proof-matrix.md scripts/maintainer/check_adoption_proof_matrix.sh examples/adoption_demo/README.md</code> | Matrix, drift gate, and README contain all four new spec filenames and `test-results/admin-screenshots`. |
| 92-05-02 | 92-05 | 4 | E2E-01, E2E-02 | T-92-20, T-92-21, T-92-22 | Existing merge-blocking `adoption-demo-e2e` lane remains the browser proof for behavior and screenshots. | <code>bash scripts/maintainer/check_adoption_proof_matrix.sh</code><br><code>bash scripts/ci/adoption_demo_e2e.sh</code><br><code>mix precommit</code> | `.github/workflows/ci.yml` keeps `adoption-demo-e2e`, required dependencies, artifact upload, no stale `12/12 Playwright specs` wording, and final `mix precommit` coverage. |

---

## Plan / Wave Overview

| Plan | Wave | Depends On | Requirement(s) | Task IDs |
|------|------|------------|----------------|----------|
| 92-01 | 1 | none | E2E-01 | 92-01-01, 92-01-02 |
| 92-02 | 2 | 92-01 | E2E-01 | 92-02-01, 92-02-02 |
| 92-03 | 2 | 92-01 | E2E-01 | 92-03-01, 92-03-02 |
| 92-04 | 3 | 92-02, 92-03 | E2E-02 | 92-04-01, 92-04-02 |
| 92-05 | 4 | 92-02, 92-03, 92-04 | E2E-01, E2E-02 | 92-05-01, 92-05-02 |

---

## Requirement Coverage

| Requirement | Covered By | Completion Evidence |
|-------------|------------|---------------------|
| E2E-01 | 92-01-01, 92-01-02, 92-02-01, 92-02-02, 92-03-01, 92-03-02, 92-05-01, 92-05-02 | Helper/selector foundation, admin console spec, theme spec, actions spec, proof matrix, drift gate, and full adoption demo E2E wrapper. |
| E2E-02 | 92-04-01, 92-04-02, 92-05-01, 92-05-02 | Screenshot matrix spec, screenshot artifact assertions, screenshot analyze-to-fix loop, proof matrix, drift gate, README, and full adoption demo E2E wrapper. |

---

## Wave Gates

| Gate | Plans | Required Automated Evidence |
|------|-------|-----------------------------|
| Wave 1 | 92-01 | Node helper export/path check; focused admin LiveView tests; no `data-testid` under `lib/rindle/admin`. |
| Wave 2 | 92-02, 92-03 | Targeted `admin-console`, `admin-theme`, and `admin-actions` Playwright specs; grep gates for no `data-testid`, no sleeps, and no media-only theme proof. |
| Wave 3 | 92-04 | `admin-screenshots` Playwright spec; 22 PNG artifact checks; CSS generator; brandbook/priv CSS parity; targeted design/admin tests. |
| Wave 4 | 92-05 | Proof matrix drift gate; source checks for all spec filenames; full `bash scripts/ci/adoption_demo_e2e.sh` packaged browser lane; final `mix precommit`. |

---

## Manual-Only Verifications

None. The former visual-polish review was automated on 2026-06-14 (see below).

## Automated (formerly manual)

| Behavior | Requirement | Discharged By |
|----------|-------------|---------------|
| Visual polish judgment after screenshots | E2E-02 | `e2e/support/admin-polish.js` `assertAdminPolish` runs inside `admin-screenshots.spec.js` `capture()` on all 22 surface/theme/viewport states, asserting: no clipped text, WCAG contrast (≥4.5:1 text / ≥3:1 large, effective-background resolved), 44px interactive target sizes, no interactive overlap, and stable/correct raster dimensions (PNG IHDR). Transitions are frozen before reads so colors are settled, not mid-tween. Runs in the merge-blocking `adoption-demo-e2e` lane. |

The gate surfaced two real defects the manual review had missed: theme-picker option buttons at 36px (< 44px target), and dark-theme `text-on-brand` rendering cream on luminous green/salmon at 1.81:1 (primary, theme-toggle, and destructive buttons). Both fixed in `brandbook/src/admin-css-build.mjs` / `tokens.json` and synced to `priv/static`; new dark-theme contrast pairs added to `brandbook/src/admin-design-system-data.mjs` so the brandbook contrast gate enforces them.

---

## Validation Sign-Off

- [x] Plans `92-01` through `92-05` are mapped.
- [x] All 10 tasks across the five plans are mapped.
- [x] Waves 1 through 4 match PLAN frontmatter.
- [x] Requirements `E2E-01` and `E2E-02` are mapped to actual plan/task IDs.
- [x] Every task has at least one `<automated>` verification command.
- [x] No missing-scaffold placeholders remain in this validation strategy.
- [x] No watch-mode flags.
- [ ] Feedback latency < 120s for targeted specs during execution.
- [x] `nyquist_compliant: true` set in frontmatter

**Strategy status:** current after revision 1 on 2026-06-13.
