---
phase: 99
slug: cohort-page-migrations-the-small-7-track-b
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-18
---

# Phase 99 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source of truth: `99-RESEARCH.md` § Validation Architecture (per-clause gate-home split mirrors Phase 98's decisive test: "does proving it need the cascade/viewport/theme/real-render to resolve, or does a static substring scan fully prove it?").

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Behavior + computed-style framework** | Playwright (`@playwright/test`, Chromium) in the existing **`adoption-demo-e2e`** lane (boots `mix phx.server` + seeds; already merge-blocking) |
| **Config file** | `examples/adoption_demo/playwright.config.js` |
| **Static markup framework** | ExUnit (`render_to_string` / live render greps — frozen-contract survival + daisyUI retirement) |
| **Token/literal gate** | `node brandbook/src/cohort-contrast.mjs` (only re-relevant if a new `--ck-*` token/pair lands — it should not) |
| **Quick run command** | `cd examples/adoption_demo && npx playwright test e2e/<page-or-spec>.spec.js` |
| **Full suite command** | the `adoption-demo-e2e` CI lane (`npx playwright test` after seed/serve) + `mix test` |
| **Estimated runtime** | per-spec ~10–30s; full lane ~minutes |

---

## Sampling Rate

- **After every task commit (one atomic commit per page):** that page's existing behavior spec(s) + its new polish case + the ExUnit frozen-contract grep must be green.
- **After every plan wave:** full `adoption-demo-e2e` lane (all behavior specs + all 7 polish cases) + `mix test`.
- **Before `/gsd-verify-work`:** full lane green + ExUnit + `cohort-contrast.mjs` green.
- **Max feedback latency:** ~30s (single page spec) / minutes (full lane).

---

## Per-Task Verification Map

> Filled concretely once the planner finalizes the task IDs. The home assignment per clause is fixed by `99-RESEARCH.md` § Validation Architecture.

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 99-01-01 (ck_page + .ck-output) | 01 | 0/1 | COHORT-01/03/04 (enabler) | no new `raw/1`; HEEx auto-escape preserved | unit (ExUnit render) + node literal scan | `mix test` + `node brandbook/src/cohort-contrast.mjs` | ❌ W0 | ⬜ pending |
| 99-NN (dashboard) | per-page | — | COHORT-01 | frozen contract; no new param reflection | polish + behavior + ExUnit grep | `npx playwright test e2e/rendering.spec.js e2e/replace-detach.spec.js` + new dashboard polish case | ❌ W0 (polish case + grep) | ⬜ pending |
| 99-NN (ops) | per-page | — | COHORT-03 | frozen contract | polish + behavior + ExUnit grep | `npx playwright test e2e/ops-surfaces.spec.js e2e/batch-erasure.spec.js` + new ops polish case | ❌ W0 (polish case + grep) | ⬜ pending |
| 99-NN (member/lesson/post/media/account) | per-page | — | COHORT-04 | frozen contract | polish + behavior + ExUnit grep | `npx playwright test e2e/rendering.spec.js e2e/owner-erasure.spec.js` + new per-page polish cases | ❌ W0 (5 polish cases + greps) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `ck_page/1` scaffold in `cohort_components.ex` — the Wave-0 enabler all 7 pages depend on (mirrors Phase 98 P1).
- [ ] Optional token-only `.ck-output`/`.ck-pre` rule in `cohort.css` for the `<pre>` debug panels on ops/account (hand-authored; must pass the D-96-20 literal scanner).
- [ ] ExUnit frozen-contract + daisyUI-retirement greps per page (model on Phase 98 `render_to_string` idiom). Confirm the adoption-demo web ExUnit home (`examples/adoption_demo/test/`) during planning.
- [ ] `e2e/` per-page polish cases for the 7 routes (model on `cohort-styleguide.spec.js`), each guarding `[data-ck-root]` visibility first (Pitfall 5).
- *(Infrastructure already present + merge-blocking: the `adoption-demo-e2e` lane, `admin-polish.js` seam, `support/cohort.js`, `cohort-contrast.mjs`.)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pixel-perfect visual baseline | COHORT-01/03/04 | Pixel baselines + warn→fail flip are explicitly deferred to Phase 102 (VIS-*) | This phase: screenshot/polish in **warn/report mode** only; no human gate. |

*All behavior + contract + polish verifications are automated. Visual consistency rides the warn-mode polish/screenshot cases this phase.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (ck_page scaffold, polish cases, ExUnit greps)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (single page) / minutes (full lane)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
