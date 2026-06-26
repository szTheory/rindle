---
phase: 85
status: complete
completed: 2026-06-10
one_liner: "Brand live on adopter surfaces: ExDoc sidebar mark + favicon, light/dark README header, regenerable 1280x640 social preview - proof lanes green, zero lib/ changes."
plans:
  - 85-01: ex_doc logo/favicon wiring + README <picture> header
  - 85-02: social card source + 1280x640 PNG + milestone-close verification
---

# Phase 85 Summary

**HexDocs (85-01):** `mix.exs` `docs()` gains `logo:` + `favicon:`. Finding during
verification: ExDoc 0.40's sidebar is dark in *both* themes, so the logo points at
`rindle-mark-dark.svg` (porcelain + green) rather than a scheme-aware variant — verified
by screenshot of the generated `doc/readme.html`. `favicon.svg` lands in `doc/assets/`.
`mix docs` builds clean (no new warnings).

**README (85-01):** `<picture>` header above the H1 — dark/light lockups via
`prefers-color-scheme`, referenced by **absolute GitHub raw URLs** so the image renders
on GitHub, hex.pm, and HexDocs alike (the hex package excludes `brandbook/`, so relative
paths would 404 on hex.pm).

**Social preview (85-02):** `brandbook/assets/social/social-card.html` (consumes
tokens.css + committed fonts + lockup SVG) → Playwright → exactly 1280×640
`github-social-preview.png` (86 KB). Warm Shell, lockup, "Media, made durable.",
lifecycle strip.

**Verification:** docs-parity + release-docs-parity + behaviour-docs suites green
(48 tests, 0 failures); `mix format --check-formatted mix.exs` clean; `check.mjs` green
at 1.35 MB total. Zero `lib/` changes (BRAND-08, feature pause intact).

**Manual follow-ups (not committable):**
1. Upload `brandbook/assets/social/github-social-preview.png` in GitHub repo Settings →
   Social preview.
2. Optionally set `brandbook/assets/logo/avatar-512.png` as the GitHub org/repo avatar.
3. Logo/favicon appear on hexdocs.pm with the next Hex publish (docs are built at
   publish time).
