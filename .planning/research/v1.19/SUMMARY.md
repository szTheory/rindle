# Project Research Summary

**Project:** Rindle — v1.19 Design-System Stress-Test
**Domain:** Fractal design-system uplift on an existing token→CSS pipeline + two Phoenix LiveView surfaces (mountable admin/operator console + Cohort demo app)
**Researched:** 2026-06-14
**Confidence:** HIGH (all integration points read from live repo; deps verified against Hex/npm; LiveView + motion patterns verified against docs)

## Executive Summary

This is a **maintainer-pull quality milestone**, not a feature milestone. The job is to elevate two already-working UI surfaces — the shipped `rindle-admin` console DS and the Cohort demo's daisyUI-scaffolded inner pages — to an award-winning bar **fractally** (component → meta-component → page) and **without regressions**. The dominant risk is not "ugly UI"; it is **silently breaking working flows or thrashing prior work** while chasing polish. Almost every capability needed already exists in the repo: the `.mjs` token→CSS generator, the WCAG contrast gate, the deterministic `admin-polish.js` computed-style proof loop, the `[data-theme]` light/dark contract, and the Playwright `adoption-demo-e2e` lane. This is a **near-zero-new-dependency** milestone (no Tailwind in `rindle`, no JS animation lib in `rindle`, no hosted visual-regression SaaS, no Storybook). The recommended approach is to *extend the existing seams*, not introduce new tooling.

**The one structural prerequisite that must land first (Phase 94):** the `.mjs` token→CSS pipeline is **not gated in CI today** (`grep brandbook ci.yml` → nothing). Token edits can land with no automated regen/contrast/parity check — the artifact (`rindle-admin.css`, committed in two locations) can silently drift from `tokens.json`. A new `brandbook-tokens` CI job (regenerate + contrast + gallery-parity + `git diff --exit-code`) is the **idempotency / no-regression anchor** for the whole milestone and blocks everything else. Without it, every later phase risks invisible drift, defeating the charter's "each run only moves quality forward" mandate.

The build is **two tracks that parallelize after the Phase 94 foundation**: Track A (admin DS: component → meta-component → page) and Track B (Cohort: build a `.ck-*` component layer, then retire daisyUI page-by-page, **class-by-class not element-by-element**, preserving every `id`/`data-testid`/`phx-hook`), re-converging into a full light/dark/mobile matrix + milestone audit. Key net-new (not audit) work: Cohort's `cohort.css` has **no dark `[data-theme]` contract and no `prefers-reduced-motion` block today** — both must be authored during migration, mirroring the admin pipeline's conventions.

## Reconciled Decision: Visual-Proof Strategy (read this first)

STACK.md and ARCHITECTURE.md/PITFALLS.md gave a **direct conflict** on the highest-leverage proof addition. STACK.md recommended adopting Playwright `toHaveScreenshot()` golden-baseline pixel diffing (noting the current `admin-screenshots.spec.js` writes 22 PNGs but never compares them). ARCHITECTURE.md and PITFALLS.md — which inspected the actual CI and the existing deterministic `admin-polish.js`/`freezeMotion` gate — recommended **avoiding golden PNGs** as flaky on this cross-platform CI (the repo already paid the flaky-action tax with ffmpeg/setup-action) and instead extending the computed-style assertions as the merge-blocking proof.

**Decision — ONE strategy for the roadmapper and `/gsd:ui-phase` to inherit:**

> **The deterministic computed-style `admin-polish.js` gate remains the SINGLE merge-blocking visual proof**, generalized to run over Cohort surfaces in the same `adoption-demo-e2e` lane. It is deterministic, self-explaining (returns an aggregated offender list = the analyze→fix worklist), and already flakiness-controlled (`freezeMotion`, `animations:"disabled"`, `workers:1`, explicit tolerances). The committed PNG matrix stays a **human-review artifact**, not a CI assertion. Pixel-baseline `toHaveScreenshot()` is **optional and non-blocking** — permitted only if baselines are **CI-generated (Linux), motion-frozen, font-stable (`document.fonts.ready`), and dynamic regions masked**; it may be added later as an *assistive* signal but must never become merge-blocking until proven stable.

**Tradeoff (stated plainly):** STACK.md is right that pixel diffing catches purely-visual regressions the computed-style gate can't see (e.g. a wrong color that still passes contrast, a layout that doesn't overlap but looks wrong). We accept that gap in exchange for a green, trustworthy, deterministic merge gate — because a flaky pixel gate gets rubber-stamped and *defeats* the no-regression mandate, which is the milestone's entire point. The computed-style gate proves the things that matter most under stress (contrast, clipping, 44px targets, overlap, stable dims, no horizontal scroll) and explains its failures; pixel diff is a nice-to-have layered on top *only once stable*. This resolves the conflict: **`admin-polish.js` is the gate; golden PNGs are optional/assistive, never the blocker.**

## Key Findings

### Recommended Stack

Near-zero new dependencies. Everything flows through the existing `tokens.json` → `.mjs` → `rindle-admin.css` pipeline for the admin DS, and hand-authored `cohort.css` + `CohortComponents` for the demo. No Tailwind, no JS animation lib, no SaaS, no Storybook in `rindle`. Detail: [STACK.md](STACK.md).

**Core technologies (extend, don't replace):**
- **`.mjs` token→CSS pipeline** (`admin-css-build.mjs`, `tokens-build.mjs`, `admin-contrast.mjs`, `admin-gallery.mjs`) — the only sanctioned way to ship admin CSS; self-verifying parity (`exact()` array equality) makes a regen a no-op diff when source == artifact (the idempotency anchor).
- **`@playwright/test ^1.57`** — already a devDependency; `admin-polish.js` computed-style gate + the screenshot matrix run here. `toHaveScreenshot()` available but **optional/non-blocking** per the decision above.
- **Phoenix `JS` commands + `phx-mounted`/`phx-remove`** — the dependency-free, morphdom-aware primitive for enter/leave motion keyed to brand motion tokens; correct because bare CSS `@keyframes` don't re-run across LiveView patches.
- **`[data-theme]` + `prefers-color-scheme`** — already the admin theme contract; gaps are an inline-head anti-FOUC script + `localStorage` persistence (admin), and bringing the same contract to Cohort (net-new).
- **Demo-only optionals (never in `rindle`):** `motion@12` (vendored, only if CSS can't express choreography) and `phoenix_storybook@1.2` (only if interactive variant playground is wanted; default is the hand-rolled/`/styleguide` gallery).

### Expected Features

"Features" here = the qualities that make an admin/operator DS excellent. Detail: [FEATURES.md](FEATURES.md).

**Must have (table stakes — penalized if missing):**
- Full **component-state matrix** (default/hover/focus-visible/active/disabled/loading/empty/error/skeleton/selected) verified per component in **both themes** — including the `active`/`focus-visible` distinction currently glossed.
- **Core meta-components:** data table (sort + sticky header + row-hover actions), chip-state filter bar, detail drawer, confirm/destructive panel, toasts, empty states.
- **Task-first IA** (gov.uk principles → operator console): triage home, inverted-pyramid drill-down, happy/empty/error/onboarding states per list.
- **GDS-grade microcopy** in the operator voice (errors say what happened + how to fix; no "please/oops/jargon"; never wipe entered input).
- **Reduced-motion-aware, sub-300ms, GPU-only motion** on the few moments that need it (drawer/toast/row-remove). WCAG 2.2.2 is a definition-of-done checkbox, not a phase.
- **Dark mode done right:** semantic tokens, a 4-level surface-elevation ladder (not shadow), per-mode tuned status scales — not invert-and-ship.

**Should have (differentiators):**
- **Asset state-timeline** in the detail drill (the operator's #1 triage artifact — turns archaeology into a glance).
- **Bulk-select + bulk-action bar**, **density toggle + persisted prefs**, **shareable triage deep-links** (URL-encoded filter/selection).
- **Living Cohort component gallery** (recommended: a `/styleguide` Phoenix route rendering the *real* `CohortComponents` — zero duplication, screenshot-able).

**Defer / anti-features (explicitly out of scope):**
- **Animate-everything / scroll-triggered reveals**, **color-only status**, **dark-by-inversion**, **toast-only error handling**, **modal-stacking confirm gauntlets**, **zebra-striped dense tables**, **inline-editing high-stakes lifecycle fields**.
- **Building a metrics/charting dashboard** — scope creep toward an observability platform; Rindle surfaces lifecycle *state*, not time-series telemetry. Hard no.

### Architecture Approach

An integration-and-build-order map over fixed substrate (the token pipeline and console architecture are shipped, not re-proposed). Two design systems stay **deliberately separate but coherent** — `rindle-admin` (shipped, host-Tailwind-independent, generated from `tokens.json`) and `cohort.css` (`.ck-*`, demo-local, hand-authored, emerald brand). They share vocabulary (status palette, fonts, radius, motion ethos) but **never share a stylesheet, token file, or build step**. Detail: [ARCHITECTURE.md](ARCHITECTURE.md).

**Major components / mechanisms:**
1. **`tokens.json` + `admin-design-system-data.mjs`** — single source of truth; new categories (elevation scale, motion presets, fluid/responsive type-space, differentiated dark status surfaces) are added here first; `admin-css-build.mjs` `exact()` refuses to drift.
2. **`brandbook-tokens` CI job (NEW)** — regen + contrast + gallery-check + `git diff --exit-code`; closes the only structural gap and makes drift a hard failure. **Phase 94, blocks all.**
3. **`admin-polish.js` proof loop (generalized)** — the merge-blocking computed-style gate, parameterized to target any root (admin or `.ck`), extended with a `cohort-screenshots.spec.js`.
4. **`CohortComponents` + `cohort.css`** — the demo's `.ck-*` component layer; inner LiveViews migrate onto it page-by-page; `default.css` (the daisyUI dump) is deleted **last**, gated on a clean grep.

### Critical Pitfalls

Top 5 of 8 (full set + recovery strategies: [PITFALLS.md](PITFALLS.md)).

1. **Restyle breaks behavior (class-coupled markup).** Inner pages carry `id`/`data-testid`/`phx-hook`/`phx-change`/`phx-submit` on the *same* elements as daisyUI classes (e.g. `upload_live.ex` `PresignedPut`, `MultipartUpload`, `Copy` hooks). → **Migrate class-by-class, never element-by-element**; treat behavior attributes as a frozen contract; snapshot a selector inventory; run the behavior specs (not just screenshots) after every page.
2. **Idempotency thrash.** Passes that hand-edit generated `rindle-admin.css`, append bottom-of-file overrides, or rewrite finalized microcopy oscillate across re-runs. → Generator is the only writer (CI-proven); each pass *rewrites an owned region to its computed target*, never appends; a double-run must produce an empty diff.
3. **Focus-visible / keyboard a11y silently lost** when leaving daisyUI's defaults. → Token-backed `:focus-visible` on every `.ck-*`/`.rindle-admin-*` interactive selector (never `outline:none` without replacement); ARIA-author dialogs/drawers/menus/tables to APG (trap + `Esc` + focus restore); keyboard pass + axe-core assertion as the durable gate.
4. **Dark-mode drift.** Cohort has no dark contract yet; color literals (`text-red-600` present in `upload_live.ex`) don't theme. → No raw color literals (grep gate); extend the contrast gate to **both themes** for every chip/text/button/empty/disabled/focus pair; elevation via surface tints, not heavier shadow.
5. **LiveView morphdom fights CSS transitions + reduced-motion missing.** Transitions on `phx-update="stream"`/pushed text flicker or double-play; `cohort.css` has no `prefers-reduced-motion`. → Use `JS.transition` via `phx-mounted`/`phx-remove` on patched nodes; never `transition:all` on hot nodes; add `prefers-reduced-motion` safety nets to both stylesheets; animate only `transform`/`opacity`.

(Also: #6 token-pipeline drift, #7 flaky visual regression — resolved by the proof decision above, #8 award-winning scope creep — anchor every pass to a documented JTBD and a per-surface "done" = the `/gsd:ui-review` pillars + behavior specs + gates.)

## Implications for Roadmap

Build order is **foundation → parallel Track A + Track B → re-converge**. Phase numbers continue at 94+. Within each track, fractal Level 1 → 2 → 3 is a **hard dependency** (a page may only use primitives that exist).

### Phase 94: Foundation — token categories + CI gate + proof-loop generalization
**Rationale:** The un-gated pipeline is the #1 bottleneck; idempotency/no-regression infrastructure must exist before any visual work. **Blocks everything.**
**Delivers:** `tokens.json` new categories (elevation scale, motion presets, fluid/responsive type-space, differentiated dark status surfaces); emit + parity in `admin-css-build.mjs`/`admin-design-system-data.mjs`; widened `CONSOLE_CONTRAST_PAIRS`; **NEW `brandbook-tokens` CI job** (regen + contrast + gallery-check + `git diff --exit-code`); `admin-polish.js` generalized to target any root.
**Avoids:** Pitfalls #2 (idempotency thrash) and #6 (token-pipeline drift).

### Track A (admin DS) — runs parallel to Track B after 94

**Phase A1 (95): Level-1 component audit** — every `rindle-admin-*` component × all states × light/dark/auto/mobile; fix contrast + polish; extend gallery. **Avoids** #3 (a11y), #4 (dark), #5 (motion).
**Phase A2 (97): Level-2 meta-components** — toolbars, table+filter, action panels, detail drills; rhythm/overlap gates.
**Phase A3 (99): Level-3 page composition** — all admin surfaces from primitives only; per-surface JTBD microcopy; full matrix + polish. **Avoids** #8 (scope creep) via per-surface "done".

### Track B (Cohort restyle) — runs parallel to Track A after 94

**Phase B1 (96): Cohort Level-1 components + `/styleguide` gallery + dark contract** — build `.ck-*` table/stat/form/tabs/detail primitives + `CohortComponents`; **author the net-new dark `[data-theme]` contract and `prefers-reduced-motion` block in `cohort.css`** (neither exists today). **Avoids** #4, #5.
**Phase B2 (98): Cohort Level-2 meta-components** — composed `.ck` groups; rhythm gates.
**Phase B3 (100): Page migrations (the small 7)** — dashboard, ops, member, lesson, post, media, account → `.ck-*`, **class-by-class, preserving every `id`/`data-testid`/`phx-hook`**; behavior specs green per page. **Avoids** #1.
**Phase B4 (101): `upload_live` migration** — isolated (484 lines, tab-structured, the heaviest hooks); its own phase. **Avoids** #1.
**Phase B5 (102): daisyUI retirement** — grep-clean → drop `default.css` `<link>` → delete `default.css` → polish pass. Gated on B1–B4 complete. **Avoids** "delete-too-early regresses to unstyled".

### Phase 103: Proof & matrix extension + milestone audit (re-converge)
**Rationale:** Depends on both tracks; the gate and matrix now cover everything.
**Delivers:** `cohort-screenshots.spec.js` merged into the matrix; `admin-polish.js` flipped warn→fail; full light/dark/mobile matrix green for admin + Cohort; requirements traceability + docs parity.

### Phase Ordering Rationale
- **94 blocks all** — token categories + CI gate + polish generalization are the substrate; visual work on un-gated tokens risks silent drift.
- **A and B are independent after 94** (different files/surfaces: `rindle-admin.css`/brandbook vs `cohort.css`/demo) → parallelize.
- **Level 1 → 2 → 3 is strict** within each track (no page-local one-offs; promote to a primitive first — keeps quality compounding).
- **B5 depends on B1–B4** (grep must be clean before deleting `default.css`); `upload_live` isolated because it's 4× any other page and the most hook-dense.
- Reduced-motion, a11y, dark-contrast, and selector-preservation are **per-phase definition-of-done gates**, not standalone phases.

### Research Flags

Phases likely needing deeper `/gsd:ui-phase` research/judging:
- **Phase 94:** the fluid type/space (`clamp()`) + container-query token shape and the differentiated-dark-status-surface model are genuine design decisions (STACK §5, ARCHITECTURE Pattern 2).
- **Phase B1 (96):** the net-new Cohort dark `[data-theme]` + reduced-motion contract has no prior art in `cohort.css` — needs a per-mode scale + elevation design, not just porting.
- **Phase A2/A3 + B2/B3:** meta-component composition and per-surface JTBD microcopy benefit from adversarial judging against the FEATURES table-stakes/anti-feature lists.

Standard patterns (lighter research):
- **Phase B3 (small-7 migrations):** mechanical class-by-class swap with a frozen selector contract — well-specified by ARCHITECTURE Pattern 3 + PITFALLS #1; execute, don't re-research.
- **Phase B5 (daisyUI retirement):** a grep-gated delete; pattern fully specified.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Pipeline + Playwright matrix read directly from repo; dep versions verified against Hex/npm; LiveView/motion against docs. The one cross-file conflict (pixel diff) is resolved above. |
| Features | HIGH | Cross-verified GDS official docs, NN/g, Material 3, enterprise-table practitioner analysis; tied to repo personas and the existing gallery. |
| Architecture | HIGH | All integration points (`.mjs` generators, `cohort.css`, `admin-polish.js`, `ci.yml`) read from live repo; build order grounded in verified file sizes/coupling. |
| Pitfalls | HIGH | Regression/idempotency/token surfaces repo-verified; MEDIUM only on animation + screenshot tuning (verified against current Playwright + LiveView docs). |

**Overall confidence:** HIGH

### Gaps to Address
- **Pixel-diff scope (resolved, but watch):** decision is computed-style gate = blocker, golden PNGs = optional/assistive. If a purely-visual regression slips through in practice, *then* invest in CI-generated stabilized baselines as a non-blocking signal — do not flip it to merge-blocking until proven stable.
- **Cohort dark scale (net-new, design judgment):** no existing dark contract to extend; Phase B1 must *author* a per-mode scale + elevation ladder, validated by extending the contrast gate to dark Cohort pairs.
- **Fluid type/space + container-query token shape:** STACK recommends `clamp()` + `@container`; the exact token shape (fluid bounds, named breakpoints the `.mjs` must interpolate) is a Phase 94 design decision.
- **Cohort gallery surface:** `/styleguide` Phoenix route (recommended) vs a generated static `cohort-gallery` — low-stakes, decide at B1.

## Sources

### Primary (HIGH confidence)
- Repo truth: `brandbook/tokens/tokens.json`, `brandbook/src/*.mjs` (build/contrast/gallery + `admin-design-system-data.mjs`), `examples/adoption_demo/priv/static/assets/{cohort,default}.css`, `lib/.../cohort_components.ex`, inner `*_live.ex` (esp. `upload_live.ex`), `e2e/admin-screenshots.spec.js` + `support/admin-polish.js` + `playwright.config.js`, `.github/workflows/ci.yml` (confirms brandbook pipeline NOT gated).
- `.planning/phases/88-admin-design-system-ui-kit/88-*.md` — DS contract, registry-safety boundary, 6-pillar conventions.
- `.planning/PROJECT.md` v1.19 charter + locked DS decisions (D-v1.18-04); `.planning/seeds/SEED-002-*`; `guides/user_flows.md` + `.planning/JTBD-MAP.md`.
- GOV.UK Design System (error component, design principles), NN/g (button states, dangerous-proximity), Material 3 interaction states.
- Phoenix LiveView docs — `JS.transition`, `phx-mounted`/`phx-remove`, morphdom patch behavior.

### Secondary (MEDIUM confidence)
- Pencil&Paper / Stéphanie Walter / Denovers — enterprise data-table UX patterns.
- Dark-mode token/elevation guides (Muzli, Bootcamp), verified against Material elevation guidance.
- Emil Kowalski motion principles (distilled; primary site unreachable at research time).
- Playwright visual-testing guides (testdino/Arbisoft) — `fonts.ready`, `animations:disabled`, masking, CI baselines.
- `phoenix_storybook@1.2.0`, `motion@12.40.0` — demo-only optionals, versions verified.

### Tertiary (LOW confidence)
- None load-bearing; demo-only optional libs would be validated at adoption time if pulled in.

---
*Research completed: 2026-06-14*
*Ready for roadmap: yes*
