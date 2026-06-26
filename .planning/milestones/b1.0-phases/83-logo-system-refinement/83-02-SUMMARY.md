---
phase: 83
plan: 02
status: complete
completed: 2026-06-10
one_liner: "Derived favicon and social avatar surfaces shipped from regenerable SVG sources, including SVG/16/32/ICO favicon assets and a centered 512px avatar."
---

# 83-02 Summary

Derived raster-facing brand assets were shipped from regenerable SVG sources:

- `brandbook/assets/logo/favicon.svg`
- `brandbook/assets/logo/favicon-16.png`
- `brandbook/assets/logo/favicon-32.png`
- `brandbook/assets/logo/favicon.ico`
- `brandbook/assets/logo/social-avatar.svg`
- `brandbook/assets/logo/avatar-512.png`

The favicon uses the simplified two-tributary cut for small-size legibility and
supports dark-mode awareness via `prefers-color-scheme`. The social avatar uses
the dark mark on a Deep Current square surface, with the mark optically centered
after refinement.

`brandbook/src/render-derived.mjs` handles the exact-pixel rasterization path via
Playwright. During refinement, rasterization moved from a `data:` URL document to
a temp-file HTML document because Chromium blocked `file://` subresources inside
`data:` documents, which had produced blank PNGs.

Verification is recorded in the Phase 83 rollup summary: `check.mjs` passed,
PNGs were confirmed real via `file`, and the 16px favicon remained legible in a
mock browser-tab screenshot. BRAND-04 is satisfied for derived assets.

No deviations from plan.
