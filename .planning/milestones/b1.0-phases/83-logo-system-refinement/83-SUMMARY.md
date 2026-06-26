---
phase: 83
status: complete
completed: 2026-06-10
one_liner: "Full logo system shipped from the locked e1 Confluence: 8 SVG variants + favicon set (svg/16/32/ico, dark-mode aware) + centered 512 avatar - all gates green at 1.26 MB total."
---

# Phase 83 Summary

`brandbook/src/logo.mjs` (+ `render-derived.mjs`) builds the complete system from the
single `confluence()` source of truth:

| Asset | File |
|---|---|
| Primary lockup | `brandbook/assets/logo/rindle-logo.svg` |
| Dark lockup | `rindle-logo-dark.svg` |
| Mono lockup (currentColor) | `rindle-logo-mono.svg` |
| With-subtitle (the only tagline variant) | `rindle-logo-subtitle.svg` |
| Icon-only mark light/dark/mono | `rindle-mark{,-dark,-mono}.svg` |
| Favicon (simplified 2-tributary cut, `prefers-color-scheme` aware) | `favicon.svg` + `favicon-16.png` + `favicon-32.png` + `favicon.ico` |
| Social avatar | `social-avatar.svg` + `avatar-512.png` |

Fixes during refinement: avatar mark optically centered (was hugging the top edge);
favicon rasterization moved from data:-URL to temp-file HTML (Chromium blocks file://
subresources inside data: documents — produced blank PNGs).

Verification: `check.mjs` green across 57 SVGs (no containers, no text elements, no
external refs, size budgets); PNGs confirmed real via `file`; 16px favicon legible in
mock tab (screenshot evidence). BRAND-04 satisfied.
