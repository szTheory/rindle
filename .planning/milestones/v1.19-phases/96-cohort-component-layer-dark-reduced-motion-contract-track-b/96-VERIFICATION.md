---
phase: 96-cohort-component-layer-dark-reduced-motion-contract-track-b
verified: 2026-06-17T20:30:00Z
status: passed
score: 11/11 must-haves verified
overrides_applied: 0
human_verification_resolved:
  - test: "Run the Cohort styleguide Playwright spec against a booted demo: cd examples/adoption_demo && env -u NO_COLOR npx playwright test cohort-styleguide.spec.js (webServer auto-boots PORT=4102 PHX_SERVER=true MIX_ENV=test mix phx.server)"
    expected: "1 passed — the reduced-motion .ck-reveal probe resolves opacity:1/transform:none/animation-name:none BEFORE the first assertAdminPolish; both theme polish runs report in warn mode; the colorScheme auto-fallback probe and the 10-section component-existence loop pass."
    result: "PASSED — confirmed by local live run on 2026-06-17: '1 passed (15.1s)'. The warn-mode console offenders observed (daisyUI '.menu { outline:none }' host-chrome rule; '--rindle-focus-*' vs cohort '--ck-focus' token-name mismatch) are non-failing and are exactly the items deferred to Phase 102's warn→fail flip."
deferred:
  - truth: "Cohort polish gate flips warn -> merge-blocking fail; assertFocusVisibleTokens generalized for per-surface focus tokens; outline:none styleSheets scan scoped to gate root"
    addressed_in: "Phase 102"
    evidence: "Phase 102 goal: 'A single deterministic merge-blocking visual gate covers admin + Cohort across' light/dark; SC: 'cohort-screenshots.spec.js is merged into the matrix and the generalized admin-polish.js'. The phase explicitly owns the warn->fail flip (D-96-06 states this) and the focus-token generalization logged in deferred-items.md."
  - truth: "default :dev env mix compile --warnings-as-errors fails on pre-existing Mox warnings in AdoptionDemo.MuxCassette"
    addressed_in: "out-of-scope (pre-existing)"
    evidence: "deferred-items.md 96-01: pre-existing failure in an unrelated file (mox only: :test). Verified independently: MIX_ENV=test mix compile --warnings-as-errors exits 0 — no template/compile breakage from Phase 96 edits."
---

# Phase 96: Cohort Component Layer + Dark / Reduced-Motion Contract [Track B] Verification Report

**Phase Goal:** Cohort has a complete `.ck-*` component + meta-component layer and a net-new dark and reduced-motion contract, so its inner pages can migrate onto finished primitives.
**Verified:** 2026-06-17T20:30:00Z
**Status:** passed (live e2e green run confirmed locally 2026-06-17 — `1 passed (15.1s)`)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | (SC1) Six L1 + four L2 `.ck-*` primitives exist in `cohort.css` + `CohortComponents`, reachable at `/styleguide` | ✓ VERIFIED | 8 `def ck_*` (table/stat/detail/toolbar + field/input/select/tabs); 42 `.ck-table/stat/detail/toolbar` CSS root hits; `/styleguide` route present (1); 10 distinct `data-ck-section` markers (table/stat/form/tabs/detail/toolbar + data-table-block/stat-row/detail-panel/tabbed-section); all 8 components invoked in styleguide_live.ex |
| 2  | (SC2) `cohort.css` gains a net-new dark `[data-theme]` contract distinct from the prefers-color-scheme fallback | ✓ VERIFIED | `[data-theme="dark"]`=3; combined `:root, [data-theme="light"]` + `:root:not([data-theme])` auto-fallback both present; explicit dark block byte-equals the prefers-color-scheme fallback (50/50 tokens, 0 mismatches); `color-scheme`=6 |
| 3  | (SC2) Net-new `prefers-reduced-motion: reduce` block zeroes animation/transition on `.ck`, settles `.ck-reveal` | ✓ VERIFIED | `prefers-reduced-motion: reduce`=1 (no-preference preserved=1); `.001ms`×2 (animation+transition) in block; `.ck-reveal` opacity:1/transform:none; `!important` only inside the reduce block (3 declarations; the 4th grep hit is a comment) |
| 4  | (SC2) Semantic elevation, not color-inversion (lightness ladder) | ✓ VERIFIED | dark `--ck-surface #111d18` → `--ck-surface-overlay #16261f` (lighter = lightness elevation); per-theme `--ck-shadow-ink`/`--ck-glow-ink` base tokens feed one `rgb(var(--ck-*-ink)/<alpha>)` formula (12 hits) |
| 5  | (SC3) All color literals replaced by `--ck-*` tokens (grep-clean rule bodies) | ✓ VERIFIED | 0 bare `outline:none`; `scanLiterals` brace-depth scanner passes clean against shipped cohort.css; negative test: planted `color:#ff0000` in `.ck-badge` → `FAIL .ck-badge -> #ff0000`, exit 1 |
| 6  | (SC3) New light + dark contrast pairs pass the WCAG gate | ✓ VERIFIED | `node brandbook/src/cohort-contrast.mjs` exits 0 — `cohort contrast: 28/28 pairs pass`, no NaN, no "unknown token"; 14 pair-groups × light/dark |
| 7  | Sort header is a real `<button>` carrying `aria-sort`; form set integrates `Phoenix.HTML.FormField` with `aria-describedby`+`aria-invalid`; tabs are full WAI-ARIA APG with a `phx-hook="Tabs"` keyboard handler | ✓ VERIFIED | `aria-sort`=2 on `<th>` with nested `<button>`; `Phoenix.HTML.FormField`=7, `aria-describedby/invalid`=8; APG roles=7, `phx-hook="Tabs"`=2; Tabs hook object + registration in `hooks: {…}` map, Arrow/Home/End keys |
| 8  | `data-ck-root`/`data-theme` seam on the per-LiveView `.ck` div (not body); server-owned theme toggle (no localStorage); server-owned sort | ✓ VERIFIED | `data-ck-root`=2 on `.ck` div, `data-theme={@theme}`=1, 0 in layouts/root; `set_theme`=3, `data-ck-theme`=2, `aria-pressed`=2, `localStorage`=0; `set_sort/sort_by/sort_dir`=22 |
| 9  | Gallery uses real Cohort fiction + exact UI-SPEC copy, not lorem | ✓ VERIFIED | `Nothing here yet`=4, `No records match this view`=3, lesson/processing/quarantine/member fiction present; `lorem/ipsum`=0; `to_form`=3 (real FormField) |
| 10 | WCAG gate runs as a fast node step in `adoption-demo-e2e` BEFORE the browser run, never in `brandbook-tokens` | ✓ VERIFIED | `cohort-contrast.mjs`=1 in ci.yml, in adoption-demo-e2e lane (line 747), 0 in brandbook-tokens lane |
| 11 | Playwright spec drives `/styleguide` in D-96-21 order, reusing `assertAdminPolish` unchanged-in-intent over `[data-ck-root]`/`.ck-*` (warn mode), with reduced-motion + auto-fallback + component-existence probes | ✓ VERIFIED (artifact) — green run is human/CI item | `root: "[data-ck-root]"`=2; reduced-motion probe (`.ck-reveal` opacity/transform/animationName) precedes first `assertAdminPolish`; `emulateMedia` only after goto/waitForLiveSocket; `colorScheme:"dark"`=1; 6 L1 + 4 L2 existence matrix; node --check passes |

**Score:** 11/11 truths verified (truth 11's artifact + wiring verified; its live-browser green run routed to human/CI verification)

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Cohort polish gate warn→fail flip + generalized focus-token lookup + scoped outline:none scan | Phase 102 | Phase 102 goal/SC own the merge-blocking matrix + generalized admin-polish.js; D-96-06 defers the flip to Phase 102; logged in deferred-items.md |
| 2 | default `:dev` `mix compile --warnings-as-errors` fails on pre-existing Mox warnings | out-of-scope (pre-existing) | Unrelated file (`AdoptionDemo.MuxCassette`, mox `only: :test`); `MIX_ENV=test` compile exits 0 — no Phase-96 breakage |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `examples/adoption_demo/priv/static/assets/cohort.css` | Dark `[data-theme]` contract, reduced-motion block, overlay ladder, shadow-ink tokens, literal-clean bodies | ✓ VERIFIED | 1038L; all gates pass |
| `…/components/cohort_components.ex` | 8 `ck_*` function components | ✓ VERIFIED | 695L; all 8 defined + invoked |
| `…/assets/js/app.js` | Tabs roving-tabindex hook, registered | ✓ VERIFIED | Tabs hook + registration in hooks map |
| `…/live/styleguide_live.ex` | `.ck` shell w/ seam, toggle, server sort, seeded fiction, 10 sections | ✓ VERIFIED | 399L; all markers + fiction present |
| `…/router.ex` | `/styleguide` in `:browser` scope | ✓ VERIFIED | route line present |
| `brandbook/src/cohort-design-system-data.mjs` | `COHORT_CONTRAST_PAIRS` (28) + `MIN_TARGET_PX=44` | ✓ VERIFIED | 96L; 28 pairs, both themes, no tokens.json coupling |
| `brandbook/src/cohort-contrast.mjs` | Resolver + :root fallback + compositing + WCAG + coverage + parity + scanLiterals + exit | ✓ VERIFIED | 327L; exits 0; negative tests real |
| `…/e2e/cohort-styleguide.spec.js` | Ordered drive + probes + existence loop | ✓ VERIFIED (artifact) | 170L; node --check passes; green run is CI/human item |
| `…/e2e/support/admin-polish.js` | Reused gate (parseColor fix) | ✓ VERIFIED | parseColor defined (ported byte-equal), offender-safe outline check |
| `.github/workflows/ci.yml` | cohort-contrast node step in adoption-demo-e2e | ✓ VERIFIED | line 747, correct lane |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `[data-theme="dark"]` | prefers-color-scheme `:root:not([data-theme])` | controlled duplication | ✓ WIRED | byte-equal parity (50/50, 0 mismatch); D-96-18 parity check active |
| shadow formulas | `--ck-shadow-ink` base token | `rgb(var(--ck-shadow-ink)/<alpha>)` | ✓ WIRED | 12 formula hits |
| `ck_tabs` | app.js Tabs hook | `phx-hook="Tabs"` | ✓ WIRED | hook object + hooks-map registration |
| `ck_input` | `Phoenix.HTML.FormField` | `attr :field` + aria wiring | ✓ WIRED | FormField=7, aria=8 |
| router `:browser` | `StyleguideLive` | `live("/styleguide", …)` | ✓ WIRED | route present |
| theme toggle | `.ck` root `data-theme` | `phx-click set_theme` | ✓ WIRED | server-owned, no localStorage |
| `COHORT_CONTRAST_PAIRS` | cohort.css values | byte-equal parity (raw strings) | ✓ WIRED | drift negative-test fails per SUMMARY; gate exits 0 |
| ci.yml adoption-demo-e2e | cohort-contrast.mjs | node step before Playwright | ✓ WIRED | line 747 |
| spec | admin-polish `assertAdminPolish` | `{ root:"[data-ck-root]", interactiveSelectors }` | ✓ WIRED | reused unchanged-in-intent (warn mode) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| WCAG contrast gate green | `node brandbook/src/cohort-contrast.mjs` | `28/28 pairs pass`, exit 0 | ✓ PASS |
| Literal scanner catches planted hex | run gate against temp copy w/ `color:#ff0000` in `.ck-badge` | `FAIL .ck-badge -> #ff0000`, exit 1 | ✓ PASS |
| Literal scanner clean on shipped css | run gate against temp copy of cohort.css | exit 0 | ✓ PASS |
| Data module shape | node import of COHORT_CONTRAST_PAIRS | 28 pairs, MIN_TARGET_PX=44, all themed, on-brand pair both themes | ✓ PASS |
| Demo compiles (no template breakage) | `MIX_ENV=test mix compile --warnings-as-errors` | exit 0 | ✓ PASS |
| JS syntax | `node --check` on spec, app.js, admin-polish.js | all OK | ✓ PASS |
| Styleguide e2e green | `npx playwright test e2e/cohort-styleguide.spec.js` | requires booted server + Chromium | ? SKIP → human/CI |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| Cohort WCAG/literal gate | `node brandbook/src/cohort-contrast.mjs` | exit 0, 28/28 | PASS |

(No conventional `scripts/*/tests/probe-*.sh` declared for this phase; the contrast gate is the runnable verification probe and was executed independently.)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| COHORT-06 | 96-01..05 | Dark `[data-theme]` contract + `prefers-reduced-motion` block (net-new) + WCAG pairs added + color literals replaced by tokens | ✓ SATISFIED | SC1/2/3 all verified above; gate exits 0; no color value changed |

No orphaned requirements: REQUIREMENTS.md maps only COHORT-06 to Phase 96; it is claimed by every plan's `requirements: [COHORT-06]` frontmatter and marked Complete (line 244).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER in any of the 9 modified files | ℹ️ Info | Clean |

### Independent Assessment of Executor-Flagged Items

**Flagged item 1 — D-96-23 `--ck-faint` contradiction (Plan 96-04, "Option A"):**
VERDICT: **Resolved acceptably. No color value changed; gate exits 0.**
- D-96-23's own text records `--ck-faint` measures **2.77:1 on `--ck-bg`** yet states it is "asserted at 3:1 only" while forbidding any `--ck-*` color-value change — an internally unsatisfiable instruction. A 2.77 value cannot clear a 3.0 floor without changing the color.
- Option A sets the LIGHT decorative pair floor to `min: 2.7` (measured 2.77 clears it; WCAG SC 1.4.3/1.4.11 exempt decorative/non-text from a contrast minimum), keeps the DARK twin at `min: 3` (passes 4.74), and changes NO color value.
- Independently confirmed: the only `-` (removed) color lines in the whole-phase cohort.css diff are `--ck-bg-glow` rgba (refactored into the ink-token formula — derivation, not palette) and rule-body `color:#fff` (moved to `var(--ck-on-brand)`). All locked palette hexes (`--ck-faint #8a9a92`/`#6f857b`, `--ck-bg #f7f8f6`, `--ck-btn-bg #047857`, `--ck-on-brand #ffffff`, `--ck-muted #586b63`) are present and unchanged. `node brandbook/src/cohort-contrast.mjs` exits 0 with `2.77 >= 2.7` on the light faint row.
- The resolution is the only path satisfying D-96-23's hard "no color change" constraint; it is documented in the SUMMARY `key-decisions` as maintainer-approved Option A.

**Flagged item 2 — admin-polish.js edit despite byte-identical request (Plan 96-05, commit b2eacd7):**
VERDICT: **Admin-behavior-preserving. NOT a contract violation.**
- Independently confirmed the pre-edit file (b2eacd7~1) **referenced `parseColor` at lines 361-362 inside `assertFocusVisibleTokens` but never defined it** — a genuine latent `ReferenceError` that crashes the shared gate for ANY caller whose focused control reaches the outline-color comparison, not a Cohort special case. The file's own comment (line 12) already claimed `parseColor` was "ported."
- The ported `parseColor` is byte-equal logic to the canonical source `brandbook/src/admin-gallery-check.mjs:208-217`.
- The try/catch wrapper changes nothing for admin: when colors parse (admin tokens always parse), `colorMismatch` is computed identically to before; the catch path only fires on a previously-crashing unparseable color, recording an offender per the adjacent width/offset checks' contract. Zero Cohort-specific branching; no admin offender count / threshold / pass-fail outcome changes.
- The literal "byte-identical" wording (D-96-06 / T-96-11) could not be honored only because the shipped gate was crash-broken the moment it ran over a focusable surface. The constraint's INTENT ("do not weaken or fork the gate for Cohort") is preserved; the fix strengthens the gate for admin and Cohort alike. Properly documented as a maintainer-visible note in 96-05-SUMMARY. The spec correctly re-throws ReferenceError/TypeError (so the very crash this fixed would still fail the spec) — the fix and the warn-mode design are mutually consistent.

### Human Verification Required

#### 1. Cohort styleguide Playwright spec — live green run

**Test:** `cd examples/adoption_demo && (PORT=4102 PHX_SERVER=true MIX_ENV=test mix phx.server &) ; sleep 8 ; npx playwright test e2e/cohort-styleguide.spec.js --project=chromium` (or the `adoption-demo-e2e` CI lane).
**Expected:** `1 passed`. Reduced-motion `.ck-reveal` probe resolves opacity:1/transform:none/animation-name:none before the first `assertAdminPolish`; both theme polish runs report (warn mode); colorScheme auto-fallback probe and the 10-section component-existence loop pass.
**Why human:** Requires a booted Phoenix server + Chromium that the static verification pass cannot run cheaply. The spec artifact exists, is syntactically valid, drives the exact D-96-21 order, and wires to the (now crash-free) real gate; only the live-browser pass remains to confirm. SUMMARY claims `1 passed`.

### Gaps Summary

No gaps. All three ROADMAP success criteria and all plan-frontmatter must-haves are met in the codebase: the six L1 + four L2 `.ck-*` primitives exist and render at `/styleguide`; the net-new dark `[data-theme]` contract and `prefers-reduced-motion` block exist with lightness-based elevation; color literals are confined to token blocks (mechanically enforced by a working `scanLiterals`); and the light+dark WCAG gate exits 0 (28/28) with no color value changed. Both executor-flagged items were independently assessed as correct/acceptable. The only open item is the live-browser e2e green run (truth 11), which is routed to human/CI verification, and two correctly-deferred follow-ups (Phase 102 warn→fail flip + focus-token generalization; pre-existing Mox compile hygiene).

---

_Verified: 2026-06-17T20:30:00Z_
_Verifier: Claude (gsd-verifier)_
