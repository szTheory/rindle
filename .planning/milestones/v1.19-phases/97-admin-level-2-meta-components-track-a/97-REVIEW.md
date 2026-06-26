---
phase: 97-admin-level-2-meta-components-track-a
reviewed: 2026-06-17T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - brandbook/admin-gallery/index.html
  - brandbook/src/admin-css-build.mjs
  - brandbook/src/admin-design-system-data.mjs
  - brandbook/src/admin-gallery-check.mjs
  - brandbook/src/admin-gallery.mjs
  - brandbook/tokens/rindle-admin.css
  - examples/adoption_demo/e2e/support/admin-polish.js
  - priv/static/rindle_admin/rindle-admin.css
  - test/brandbook/admin_design_system_validation_test.exs
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 97: Code Review Report

**Reviewed:** 2026-06-17
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 97 adds eight Level-2 "meta-component" cohesion units (toolbar, data-table, filter-bar, action-panel, detail-drilldown, confirm-panel, drawer, toast-stack) to the generated Rindle Admin gallery, plus the supporting CSS, build/parity self-checks, the static gallery generator, and two new e2e polish checks (`assertConsistentRhythm`, `assertNoHorizontalScroll`). The build/parity and Elixir validation tests are thorough about *selector presence* and *spacing rhythm*, but two new accessibility/correctness defects slip through precisely because the gates do not cover them:

1. The new sortable-header glyph paints with `--rindle-accent` (rindle-green #32D08C). On light surfaces that is ~1.96:1 against `surface-raised` — the project's own tokens.json explicitly documents "Rindle green on light fails at 1.81 - never use it there." The contrast gate misses it because the glyph is `::after` generated content, not a child text node. This is the BLOCKER.
2. The new data-table selection checkboxes carry `data-rindle-admin-input`, which the generated CSS styles with `width:100%; min-height:44px; border; radius; background` — applied unconditionally to `<input type="checkbox">`, producing a stretched/mis-rendered control. The target-size gate passes *because of* the bug rather than catching it.

Several quality issues around dead styling contracts and copied-fixture drift are also noted. `brandbook/tokens/rindle-admin.css` and `priv/static/rindle_admin/rindle-admin.css` are byte-identical (verified), satisfying ADMIN-02.

## Critical Issues

### CR-01: Active sort-direction glyph is unreadable on light surfaces (rindle-green ~1.96:1)

**File:** `brandbook/tokens/rindle-admin.css:725-733` (generator source `brandbook/src/admin-css-build.mjs:725-733`)
**Issue:**
The new sortable-header treatment paints the direction glyph with `--rindle-accent`:

```css
.rindle-admin-table__head th[aria-sort="ascending"] .rindle-admin-table__sort::after {
  content: "\2191";
  color: var(--rindle-accent);   /* #32D08C rindle-green */
}
.rindle-admin-table__head th[aria-sort="descending"] .rindle-admin-table__sort::after {
  content: "\2193";
  color: var(--rindle-accent);
}
```

On light themes `--rindle-accent` resolves to rindle-green (#32D08C) and the glyph sits on `--rindle-surface-raised` (porcelain #FBFEFC). Measured contrast is **~1.96:1** — below the 3:1 non-text minimum and far below 4.5:1 for text. `brandbook/tokens/tokens.json` documents this exact failure: *"rindle-green ... accent/large-graphic-only on light surfaces (measured 1.81 ... vs 4.5 required for text)"* and *"Rindle green on light fails at 1.81 - never use it there."* The `meta-data-table-light.png` artifact is captured in light theme, so the shipped output contains this defect.

It is unguarded: `assertReadableContrast` (admin-polish.js) and `assertDarkStatusChipContrast` (admin-gallery-check.mjs) detect text via child `TEXT_NODE`s (`hasOwnText`); `::after` generated content is never a child node, so the active sort glyph is never sampled. The inline comment claiming the treatment is "never color-only" is only partly true (the ↑/↓ vs ↕ glyph shape does change), but the *color contrast itself* still violates the design system's own rule.

**Fix:** Use a token legible on light surfaces for the active glyph; the shape change already carries the active/inactive signal, so rindle-green is unnecessary:

```css
.rindle-admin-table__head th[aria-sort="ascending"] .rindle-admin-table__sort::after,
.rindle-admin-table__head th[aria-sort="descending"] .rindle-admin-table__sort::after {
  color: var(--rindle-text); /* legible on both light surface-raised and dark elevation-1 */
}
```

Also extend `assertReadableContrast` to sample `::before`/`::after` color via `getComputedStyle(el, '::after')` so this class of defect is gated, not just patched once.

## Warnings

### WR-01: Data-table selection checkboxes inherit full text-input box styling (`width:100%`, 44px min-height, border, radius, surface fill)

**File:** `brandbook/src/admin-gallery.mjs:199,208,215,222,229` (data-table fixture) → styled by `brandbook/tokens/rindle-admin.css:373-405`
**Issue:**
Every selection checkbox in the new data-table unit carries `data-rindle-admin-input`:

```html
<input type="checkbox" data-rindle-admin-component="form-controls" data-rindle-admin-state="default" data-rindle-admin-input aria-label="Select all rows" checked>
```

The `[data-rindle-admin-input]` rule sets `min-height:44px; width:100%; padding; border:1px solid; border-radius; background:surface-raised`, with no `appearance`/checkbox special-casing (confirmed: no `type="checkbox"`/`appearance`/`accent-color` rules in the generated CSS). Applied to a native checkbox this stretches it toward full cell width / 44px height and paints a bordered, rounded, surface-filled box around the control — a rendering defect for the selection column. `assertTargetSizes` is fooled into *passing* because the inflated box reports ≥44px; the rhythm check skips it (the checkbox has no `rindle-admin-*` class). Five such checkboxes are introduced by this phase (a single pre-existing one lives at `admin-gallery.mjs:655`).

**Fix:** Drop `data-rindle-admin-input` from checkbox/radio inputs, or scope the box styling to text-like controls and add a checkbox branch:

```css
[data-rindle-admin-input]:where(:not([type="checkbox"]):not([type="radio"])) { /* existing box styles */ }
input[type="checkbox"][data-rindle-admin-input] { width: auto; min-height: auto; accent-color: var(--rindle-brand); }
```

### WR-02: Empty-state dashed-border contract is declared and tested but never rendered

**File:** `brandbook/tokens/rindle-admin.css:589-591`; fixture `brandbook/src/admin-gallery.mjs:684`
**Issue:**
The CSS declares `[data-rindle-admin-empty-state] { border-style: dashed; }`, the build self-check requires the `[data-rindle-admin-empty-state]` selector (`admin-css-build.mjs:989`), and the Elixir test asserts it (`admin_design_system_validation_test.exs:66`). But no element ever sets the `data-rindle-admin-empty-state` attribute — the empty-state div uses only `class="rindle-admin-empty-state"` + `data-rindle-admin-component="empty-state"` (grep for the attribute in HTML and generator returns nothing). The empty-state always renders solid-bordered; the dashed affordance is dead CSS, and the parity/test gates give false confidence because they only assert the selector exists *in the CSS string*, never that markup exercises it.

**Fix:** Add `data-rindle-admin-empty-state` to the empty-state fixture div in `admin-gallery.mjs` (and regenerate `index.html`), or remove the unused rule plus its parity/test assertions.

### WR-03: Theme picker "Focus" control is a dead, unpressable button that mislabels its own state

**File:** `brandbook/src/admin-gallery.mjs:571` / `brandbook/admin-gallery/index.html:278`
**Issue:**
A fourth theme-picker button is emitted with `data-rindle-admin-theme="focus"` to showcase focus-visible. It is wired into the same click handler as the real theme buttons (`controls.forEach(... setTheme(control.dataset.rindleAdminTheme))`). Clicking it calls `setTheme('focus')`, which the `allowedThemes` guard rejects and returns early — so the button is interactive (cursor:pointer, 44px target, matched by `[data-rindle-admin-theme]`) yet does nothing, and permanently advertises `aria-pressed="false"`. A keyboard/AT user reaches a control announcing a theme that can never be pressed.

**Fix:** Make the demonstration control non-interactive for theme switching — give it `disabled` and exclude it from the live picker, or use a distinct attribute not bound to the click handler / not matched by `[data-rindle-admin-theme]`.

### WR-04: Confirm-input enable logic dereferences `querySelector` results with no null guard

**File:** `brandbook/src/admin-gallery.mjs:761-765` / `brandbook/admin-gallery/index.html:713-717`
**Issue:**
```js
const input = document.querySelector('[data-rindle-admin-confirm-input]');
const action = document.querySelector('[data-rindle-admin-confirm-action]');
input.addEventListener('input', () => { action.disabled = input.value !== expectedOwner; });
```
Both results are dereferenced unguarded. Both nodes exist today (the Actions confirm-dialog supplies them; the new meta confirm-panel intentionally omits them). But this couples the gallery's entire inline script to one fixture: any future restructure that removes/reorders the confirm-input (or gives the meta panel the input attribute first in DOM order without the matching action) makes `input` or `action` `null`, and `addEventListener`/`.disabled` throws — breaking *all* subsequent gallery JS (theme switch, nav current-state). `admin-gallery-check.mjs` depends on `confirmAction.isDisabled()` toggling, so a regression would surface as a confusing downstream failure.

**Fix:**
```js
if (input && action) {
  input.addEventListener('input', () => { action.disabled = input.value !== expectedOwner; });
}
```

## Info

### IN-01: Large fixture duplication between generator and committed HTML

**File:** `brandbook/src/admin-gallery.mjs:168-355` vs `brandbook/admin-gallery/index.html:503-675`
**Issue:** Each meta panel exists twice — a template literal in the generator and verbatim in committed `index.html`. `assert_generated_clean` pins them, so drift is *caught*, but every fixture edit is a two-file change and reviewers must diff both. Inherent to the commit-the-artifact pattern; flagged for awareness.

### IN-02: `data-table` hard-codes "3 selected" against exactly 3 selected rows (magic literal)

**File:** `brandbook/src/admin-gallery.mjs:189,192,207,214,221`
**Issue:** The bulk-bar count (`3 selected`, `3 selected — Erase`) is a literal duplicated in two strings that must be hand-synced with the number of `checked` / `data-rindle-admin-selected` rows. Acceptable for a JS-free fixture, but a future row add/remove will silently desync the visible count from the selection state.

### IN-03: Polish-gate `OVERLAP_ENFORCED = true` comment contradicts the code

**File:** `examples/adoption_demo/e2e/support/admin-polish.js:29-30`
**Issue:** The comment says "Ship it in warn mode for one green CI cycle, then flip to a hard failure ..." but the constant is already `true` (hard-fail). The stale comment misleads a maintainer into thinking overlap is still warn-only. Update it to reflect that overlap is now enforcing.

---

_Reviewed: 2026-06-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
