---
phase: 100
slug: cohort-upload-migration-all-tabs-track-b
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-18
---

# Phase 100 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `100-RESEARCH.md` → `## Validation Architecture`. Mirrors the Phase-99 decisive-test split applied to `/upload`, driven by the deterministic `?tab=` URL (NOT a client tab-click — that's the behavior specs' job).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (computed-style + behavior)** | Playwright (`@playwright/test`), Chromium-only, in the existing merge-blocking `adoption-demo-e2e` lane (boots `mix phx.server` + seeds + MinIO/Mux) |
| **Framework (static markup)** | ExUnit (`render_route`/`render` greps in `cohort_migration_contract_test.exs` — Phase-99 module, EXTENDED) |
| **Framework (token/literal gate)** | `node brandbook/src/cohort-contrast.mjs` (sanity re-run; the one new rule is token-only) |
| **Config file** | `examples/adoption_demo/playwright.config.js` |
| **Quick run command** | `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js` (polish) · `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` (frozen contract) |
| **Full suite command** | the `adoption-demo-e2e` CI lane (all behavior + polish specs) + `mix test` + `node brandbook/src/cohort-contrast.mjs` |
| **Estimated runtime** | ~quick: <30s ExUnit / ~2–4 min polish subset; full lane: existing CI budget |

---

## Sampling Rate

- **After every task commit:** ExUnit `/upload` frozen-contract test + the 6 per-tab polish cases + the behavior spec(s) for any flow touched must be green.
- **After every plan wave:** full `adoption-demo-e2e` lane (6 behavior specs + all `/upload` polish cases) + `mix test` + `node brandbook/src/cohort-contrast.mjs`.
- **Before `/gsd-verify-work`:** full lane green + ExUnit + `cohort-contrast.mjs` green.
- **Max feedback latency:** ~30s (ExUnit static gate) for the per-commit signal.

---

## Per-Task Verification Map

| Clause (from success criteria) | Crit | Home | Test Type | Automated Command |
|---|---|---|---|---|
| `/upload` (each `?tab=X`) renders a `[data-ck-root]` `.ck` shell | 1 | ExUnit + Playwright | static + behavior | `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` |
| Each tab's `.ck-*` controls pass the polish gate (focus ring, 44px, contrast) ×6 | 1 | Playwright `assertCohortPagePolish(page,{route:"/upload?tab=X",surface:"upload-X-cohort"})` (warn) | computed-style | `npx playwright test e2e/cohort-pages.spec.js` |
| Tab strip is links + `aria-current="page"` (NOT `role=tablist`/`role=tab`) | 1 | ExUnit (`assert =~ aria-current="page"`; `refute =~ role="tablist"`/`role="tab"`) | static | `mix test …cohort_migration_contract_test.exs` |
| Dark theme renders distinct tokens (image tab) | 1,3 | Playwright dark case — server `data-theme="dark"`, assert `[data-ck-root][data-theme="dark"]` | computed-style | `npx playwright test e2e/cohort-pages.spec.js` |
| Token-pair contrast unchanged (no new failing pair) | 1 | node `cohort-contrast.mjs` | token gate | `node brandbook/src/cohort-contrast.mjs` |
| daisyUI/Tailwind utilities RETIRED from `/upload` body (all tabs) | 1 | ExUnit `assert_daisyui_retired/1` per `?tab=X` (EXTEND `@retired_daisyui_classes` first) | static negative | `mix test …cohort_migration_contract_test.exs` |
| Every always-present `id`/`data-testid` survives per tab | 2 | ExUnit `assert_frozen_contract` per `?tab=X` | static | `mix test …cohort_migration_contract_test.exs` |
| Every `phx-hook` (`PresignedPut`/`PresignedVideoPut`/`PresignedMuxPut`/`MultipartUpload`) survives | 2 | ExUnit (`assert =~ phx-hook="…"` in tab panel) | static | `mix test …cohort_migration_contract_test.exs` |
| Every `phx-change`/`phx-submit` + `type=submit` survives | 2 | ExUnit (grep per tab) | static | `mix test …cohort_migration_contract_test.exs` |
| `:if`-only selectors (`tus-upload-error`, `image-upload-asset-id`, `mux-streaming-url`) survive | 2 | Playwright behavior specs (render only after a handler fires) | behavior | `npx playwright test e2e/{tus-resume,image-upload,mux-streaming}.spec.js` |
| No element restructured out of existence under a frozen id | 2 | Playwright behavior regression (6 specs) | behavior | `adoption-demo-e2e` lane |
| No `raw/1` introduced (HEEx auto-escape) | 2 | ExUnit (`assert_frozen_contract` `refute =~ "raw("`) | static negative | `mix test …cohort_migration_contract_test.exs` |
| `?theme=dark` param enum-validated (`~w(light dark)`, default light) | 1 sec | ExUnit + `ck_page` attr enum | static | `mix test …cohort_migration_contract_test.exs` |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] 6 per-tab polish cases in `e2e/cohort-pages.spec.js` (`route: "/upload?tab=X"`, `surface: "upload-X-cohort"`) — reuse exported `assertCohortPagePolish` (warn mode, `[data-ck-root]` guard inside).
- [ ] 1 dark polish case on the image tab — server `data-theme="dark"` (Pitfall F option 1: validated `?theme=dark` read in `mount`/`handle_params`, default light, enum-enforced by `ck_page`'s `theme` attr).
- [ ] 1 `/upload` per-tab `for`-comprehension test in `cohort_migration_contract_test.exs` (frozen contract + daisyUI retirement) with a small `panel_contract/1` per-tab selector map.
- [ ] EXTEND `@retired_daisyui_classes` with `tabs`, `text-red-600`, the standalone `tab ` token, `break-all` (Pitfall E) BEFORE the `/upload` retirement assertion.
- [ ] The ONE token-only `.ck-tabs__tab[aria-current="page"]` rule in `cohort.css` (D-100-05) — hand-authored, must pass the literal scanner; consolidate with the `[aria-selected="true"]` rule.

*Infrastructure already present and merge-blocking: `ck_page/1`, all target `.ck-*` primitives, `cohort-pages.spec.js`, `cohort_migration_contract_test.exs`, the 6 behavior specs, `admin-polish.js`, `cohort-contrast.mjs`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| (none) | COHORT-02 | All phase behaviors have automated verification (per-tab polish + frozen-contract + 6 behavior specs + token gate) | — |

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (ExUnit static gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
