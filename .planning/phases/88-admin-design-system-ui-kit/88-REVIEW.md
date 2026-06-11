---
phase: 88-admin-design-system-ui-kit
reviewed: 2026-06-11T21:34:27Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - brandbook/admin-gallery/.gitignore
  - brandbook/admin-gallery/index.html
  - brandbook/src/admin-contrast.mjs
  - brandbook/src/admin-css-build.mjs
  - brandbook/src/admin-design-system-data.mjs
  - brandbook/src/admin-gallery-check.mjs
  - brandbook/src/admin-gallery.mjs
  - brandbook/tokens/rindle-admin.css
  - guides/admin_design_system.md
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 88: Code Review Report

**Reviewed:** 2026-06-11T21:34:27Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the static admin design-system CSS layer, generated gallery, browser/contrast checks, and guide. The `#assets` deep-link regression is covered, but the dark-theme status chip contract is not: generated CSS keeps light status-chip surfaces in dark mode while the contrast data checks a different background, so the automated gate can pass while the shipped dark gallery has sub-WCAG chip text.

## Critical Issues

### CR-01: Dark-theme status chips use light surfaces and bypass the contrast gate

**File:** `brandbook/tokens/rindle-admin.css:129`
**Issue:** The dark theme only overrides `--rindle-status-{state}` foreground tokens, leaving the light `--rindle-status-{state}-surface` variables from `:root` active. The chip rules at `brandbook/tokens/rindle-admin.css:296` then render dark foreground colors on light pastel chip backgrounds; for example the computed dark ready chip is `rgb(79, 215, 156)` on `rgb(224, 240, 232)`, about 1.54:1 contrast. The automated data also masks this: `brandbook/src/admin-design-system-data.mjs:77` checks dark status foregrounds against `surface-raised`, not the actual `status-{state}-surface` background used by `brandbook/src/admin-css-build.mjs:210`. This violates the guide's readable dark-theme/status-chip contract and lets a failing component ship with passing checks.

**Fix:**
```js
// brandbook/src/admin-css-build.mjs
for (const state of STATUS_STATES) {
  css += `
.rindle-admin-status-chip--${state} {
  color: var(--rindle-status-${state});
  background: var(--rindle-status-${state}-surface);
}
`;
}
```

Also add dark `status-*-surface` semantic tokens in `tokens.json` or emit dark-mode overrides that map those surfaces to `--rindle-surface-raised`, then update `CONSOLE_CONTRAST_PAIRS` so dark status-chip pairs check the same `status-${state}-surface` background the CSS actually renders.

---

_Reviewed: 2026-06-11T21:34:27Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
