---
phase: 111-regression-locks
plan: 03
subsystem: test-harness
tags: [js-harness, dedupe, focus-visible, keyboard-modality, refactor, LOCK-03]
requires:
  - "examples/adoption_demo/e2e/support/admin-polish.js module.exports + 2 Tab-first focus sites"
  - "brandbook/src/admin-gallery-check.mjs adoptionRequire(...admin-polish.js) import + 1 focus site"
provides:
  - "Single exported focusVisibly(page, locator) helper in admin-polish.js owning the Tab-first :focus-visible workaround"
  - "All three former raw focus({ focusVisible: true }) call sites routed through focusVisibly"
  - "Post-dedupe call-form invariant: admin-polish.js == 1 (helper only), gallery == 0 (the LOCK-04 precondition)"
affects:
  - "examples/adoption_demo/e2e/support/admin-polish.js"
  - "brandbook/src/admin-gallery-check.mjs"
tech-stack:
  added: []
  patterns:
    - "Single-source-of-truth dedupe of a stateful browser-quirk workaround via existing CommonJS module.exports + adoptionRequire import (no new module system)"
    - "Helper always blurs-first-if-active so the dedupe PRESERVES (not just moves) site 1 semantics; idempotent for all sites"
    - "Extract only the Tab+focus prelude from site 2's larger state-reading evaluate; focus persists across evaluate calls"
key-files:
  created: []
  modified:
    - "examples/adoption_demo/e2e/support/admin-polish.js"
    - "brandbook/src/admin-gallery-check.mjs"
decisions:
  - "focusVisibly placed as a top-level async function after outlineScopeHints; exported in module.exports adjacent to assertFocusVisibleTokens (D-02 convention)"
  - "Helper Tab press swallows the error with .catch(() => {}) (matches the demo call sites; the gallery's bare press adopts the swallow, which is intended per D-02 discretion)"
  - "Gallery site 3: the Tab press was hoisted OUT of the loop pre-dedupe; post-dedupe focusVisibly is called per-iteration (Tab+focus per item), matching the plan's 'single await focusVisibly per iteration' instruction"
  - "Helper doc-comment reworded to '.focus(...) with the focusVisible option' so the prose does not match the call-form regex used by LOCK-04 (keeps admin-polish.js call-form count == 1)"
metrics:
  duration: "6 min"
  completed: "2026-06-28"
  tasks: 2
  files: 2
status: complete
---

# Phase 111 Plan 03: LOCK-03 focus-visible modality dedupe into focusVisibly — Summary

Deduped the Tab-first `:focus-visible` keyboard-modality workaround into ONE exported helper
`focusVisibly(page, locator)` in `admin-polish.js`, and routed all three former raw
`focus({ focusVisible: true })` call sites (two in `admin-polish.js`, one in
`admin-gallery-check.mjs`) through it. Post-dedupe the call-form modality call lives in exactly
one place — the precondition LOCK-04 (Plan 04) asserts.

## What Was Built

A single source of truth for the browser-quirk modality workaround:

```js
// admin-polish.js — sole owner of the focusVisible call-form
async function focusVisibly(page, locator) {
  await page.keyboard.press("Tab").catch(() => {});
  await locator
    .evaluate((element) => {
      if (document.activeElement === element) element.blur();
      element.focus({ focusVisible: true });
    })
    .catch(() => {});
}
```

- **Helper definition + export (Task 1):** `focusVisibly` is a top-level async function placed
  after `outlineScopeHints`, and added to `module.exports` adjacent to `assertFocusVisibleTokens`
  — the same convention the gallery already imports via `adoptionRequire`. The blur-first-if-active
  step is LOAD-BEARING (RESEARCH Pitfall 2 / T-111-06): site 1 relies on re-focusing an
  already-focused element, so the helper always blurs-first, which is idempotent and safe for all
  three sites.
- **Site 1 (`assertFocusVisibleTokens`):** the inline Tab + blur-first + focus block was removed and
  replaced with `await focusVisibly(page, item);`. Behavior preserved identically.
- **Site 2 (`assertFocusVisibleVsPointer`):** the focus was the FIRST statement inside a LARGER
  state-reading `item.evaluate((el, contract) => {...})` that returns computed-style state
  (RESEARCH Pitfall 3 / T-111-07). Only the Tab+focus prelude was extracted: `await focusVisibly(page, item);`
  now precedes the unchanged state-reading evaluate (focus persists across evaluate calls). The
  evaluate's parameters, body, and `matchesFV: el.matches(":focus-visible")` return are preserved exactly.
- **Site 3 (gallery, Task 2):** `focusVisibly` was added to the existing
  `adoptionRequire(...admin-polish.js)` destructure (no new module system). The standalone Tab press
  (hoisted out of the loop) and the raw `locator.evaluate(...el.focus...)` inside the loop were both
  removed and replaced with a single per-iteration `await focusVisibly(page, locator);`.

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | LOCK-03 — define focusVisibly in admin-polish.js and replace both local sites | 446f2c6 | examples/adoption_demo/e2e/support/admin-polish.js |
| 2 | LOCK-03 — consume focusVisibly in the gallery, remove the raw site | 043f620 | brandbook/src/admin-gallery-check.mjs |

## Verification

- `node --check` passes for both `admin-polish.js` and `admin-gallery-check.mjs`.
- `require(...).focusVisibly` is a `function` (exported successfully).
- Call-form count: `grep -cE 'focus[(][{] focusVisible: true [}][)]'` → **admin-polish.js == 1**
  (inside the helper only), **admin-gallery-check.mjs == 0**.
- Repo-wide (`examples/`, `brandbook/`, `*.js`/`*.mjs`/`*.cjs`): exactly ONE call-form occurrence,
  at `admin-polish.js:129` inside `focusVisibly` — the LOCK-04 single-source invariant holds.
- Semantic-preservation checks: both former local sites now call `focusVisibly(page, item)`; site 2's
  `matchesFV: el.matches(":focus-visible")` return is intact; the `:425` explanatory comment is
  unchanged; the gallery `:170` comment text was updated only to reference the shared helper (no
  call-form prose, no behavior change).
- OBS-02 content-drift guard: `grep -rn "focusVisible\|admin-polish\|admin-gallery" test/` — the only
  match (`test/brandbook/admin_design_system_validation_test.exs`) references the JS file *paths* and
  runs the gallery script; it asserts **no** modality literal that this edit changed (`grep -n
  'focusVisible\|keyboard.press\|focus(\|Tab'` over that test → empty). No red-main risk.
- Behavioral parity (`assertFocusVisibleTokens` / `assertFocusVisibleVsPointer` / gallery focus ring)
  is CI-delegated per house practice for the `adoption-demo-e2e` + gallery-check lanes (no local
  browser run); the dedupe is a pure prelude extraction that preserves the Tab-first sequence and
  blur-first semantics, so the deduped helper produces the identical focus state at each site.
- Zero `lib/` change; no `test/*.exs` touched; no `ci.yml` literal touched → no semver impact, no
  new attack surface, no OBS-02 risk to existing meta-tests.

## Deviations from Plan

None — plan executed exactly as written.

One incidental, in-scope adjustment worth noting (not a plan deviation): the helper's own
explanatory comment originally read `.focus({ focusVisible: true })` in prose, which the Task-1
verification regex (`focus[(][{] focusVisible: true [}][)]`) counted as a second occurrence. The
comment was reworded to `.focus(...)` with the `focusVisible` option so the prose no longer matches
the call-form pattern — keeping the call-form count at exactly 1 (the actual code line). This is the
same class of "comment prose vs code call-form" distinction the plan flagged for the `:425` and
`:170` source comments.

## Known Stubs

None.

## Threat Flags

None. This is an internal test-harness refactor (demo + brandbook JS, NOT adopter-facing `lib/`).
Threat register dispositions are satisfied: T-111-06 (site 1 blur-first preserved via always-blur-first
helper), T-111-07 (site 2 state-reading evaluate + return kept intact, only the prelude extracted),
T-111-08 (dedupe collapses to one helper; LOCK-04 in Plan 04 will assert the post-dedupe
single-occurrence invariant). No new endpoint, secret, package, schema, or trust-boundary surface.

## Self-Check: PASSED

- Modified file exists: `examples/adoption_demo/e2e/support/admin-polish.js` — FOUND.
- Modified file exists: `brandbook/src/admin-gallery-check.mjs` — FOUND.
- Commit exists: `446f2c6` — FOUND (`refactor(111-03): dedupe focus-visible modality into focusVisibly helper`).
- Commit exists: `043f620` — FOUND (`refactor(111-03): route gallery focus site through focusVisibly helper`).
