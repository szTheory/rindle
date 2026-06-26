---
phase: 97-admin-level-2-meta-components-track-a
fixed_at: 2026-06-17T00:00:00Z
review_path: .planning/phases/97-admin-level-2-meta-components-track-a/97-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 97: Code Review Fix Report

**Fixed at:** 2026-06-17
**Source review:** .planning/phases/97-admin-level-2-meta-components-track-a/97-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (1 BLOCKER + 4 WARNING; 3 INFO findings out of scope)
- Fixed: 5
- Skipped: 0

All generated-CSS findings were fixed generator-first (`brandbook/src/admin-css-build.mjs`) and both CSS copies regenerated so they remain byte-identical per ADMIN-02 (verified with `cmp`). All gallery-fixture findings were fixed in the generator (`brandbook/src/admin-gallery.mjs`) and `brandbook/admin-gallery/index.html` regenerated so the committed artifact matches the `assert_generated_clean` pin.

## Fixed Issues

### CR-01: Active sort-direction glyph unreadable on light surfaces (rindle-green ~1.96:1)

**Files modified:** `brandbook/src/admin-css-build.mjs`, `brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`
**Commit:** 4c5948a
**Applied fix:** Changed the active sort-direction glyph color from `var(--rindle-accent)` (rindle-green #32D08C, which measures ~1.96:1 on light `surface-raised` and violates the project's own tokens.json rule) to `var(--rindle-text)`, which is legible on both light `surface-raised` and dark `elevation-1`. The active/inactive signal is still carried by the glyph shape change (up/down vs up-down), so dropping the accent tint does not lose information. Fixed in the generator and regenerated both CSS copies (still byte-identical). Updated the adjacent generator comment to document the contrast rationale.

Note: The review additionally recommended extending `assertReadableContrast` (admin-polish.js) to sample `::before`/`::after` pseudo-element color via `getComputedStyle(el, '::after')` so this defect class is gated, not just patched once. That is a gate/test-coverage enhancement beyond the source defect and was NOT applied in this pass — the underlying contrast defect itself is fully resolved. The gate enhancement remains available as a follow-up hardening item.

### WR-01: Data-table selection checkboxes inherit full text-input box styling

**Files modified:** `brandbook/src/admin-css-build.mjs`, `brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`
**Commit:** 0abec48
**Applied fix:** Scoped the `[data-rindle-admin-input]` box treatment (full-width, padded, bordered, surface-filled, 44px min-height) to text-like controls via `:where(:not([type="checkbox"]):not([type="radio"]))`, and added a dedicated rule for `input[type="checkbox"]` / `input[type="radio"]` that resets `width:auto; min-height:auto` and applies `accent-color: var(--rindle-brand)`. This keeps native selection controls at their intrinsic size instead of stretching them, while preserving the brand accent. Fixed in the generator and regenerated both CSS copies (parity self-check passes; byte-identical confirmed). The chosen CSS-scoping approach is generator-first and prevents the defect for any future checkbox carrying the attribute, rather than just dropping the attribute from current fixtures.

### WR-02: Empty-state dashed-border contract declared and tested but never rendered

**Files modified:** `brandbook/src/admin-gallery.mjs`, `brandbook/admin-gallery/index.html`
**Commit:** 751843e
**Applied fix:** Added the `data-rindle-admin-empty-state` boolean attribute to the empty-state fixture div in the generator (following the existing `data-rindle-admin-error-state` convention on the sibling error-state panel) and regenerated `index.html`. The previously-dead `[data-rindle-admin-empty-state] { border-style: dashed; }` CSS rule, the build self-check selector requirement, and the Elixir test assertion are now actually exercised by rendered markup instead of giving false confidence.

### WR-03: Theme picker "Focus" control is a dead, unpressable button mislabeling its state

**Files modified:** `brandbook/src/admin-gallery.mjs`, `brandbook/admin-gallery/index.html`
**Commit:** 2cbe96e
**Applied fix:** Replaced the demo button's bound `data-rindle-admin-theme="focus"` attribute (which `setTheme`'s `allowedThemes` guard always rejected, leaving the button interactive-but-inert and permanently advertising `aria-pressed="false"`) with a distinct, non-bound `data-rindle-admin-theme-demo` attribute, removed the misleading `aria-pressed`, and added a descriptive `aria-label` ("Focus-visible state demonstration (not a theme toggle)"). The button is no longer matched by the `[data-rindle-admin-theme]` click-handler selector and no longer announces a pressable theme it can never apply. It retains `data-rindle-admin-state="focus-visible"` (satisfying the theme-picker state matrix in admin-gallery-check.mjs:42) and stays focusable so it still demonstrates the focus-visible treatment. Verified `assertFocusVisibleTokens` uses `.first()` of the real theme buttons and `assertActiveDistinctFromFocus` targets `[data-rindle-admin-theme][aria-pressed="true"]`, neither of which depends on the demo button.

### WR-04: Confirm-input enable logic dereferences querySelector results with no null guard

**Files modified:** `brandbook/src/admin-gallery.mjs`, `brandbook/admin-gallery/index.html`
**Commit:** 86f0059
**Applied fix:** Wrapped the `input.addEventListener` / `action.disabled` logic in an `if (input && action) { ... }` guard so a future fixture restructure that removes or reorders the confirm-input/action nodes can no longer throw and break all subsequent gallery inline JS (theme switch, nav current-state). Fixed in the generator and regenerated `index.html`.

---

_Fixed: 2026-06-17_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
