---
phase: 84
status: complete
completed: 2026-06-10
one_liner: "Design tokens (38 raw + 26 semantic, full dark set, focus + border-strong fixes) with a 38/38 WCAG gate, rendered live by a self-contained single-page HTML brand book at 1.26 MB total."
plans:
  - 84-01: tokens.json + tokens.css generator (parity-checked) + contrast.mjs gate
  - 84-02: index.html shell + essence/logo/color/typography sections
  - 84-03: voice/microcopy/components/imagery/applications/do-dont + budget pass
---

# Phase 84 Summary

**Tokens (BRAND-05):** `brandbook/tokens/tokens.json` is the source of truth — raw
palette (38), semantic roles for light *and dark* (26), interaction states
(hover/active/disabled via brand-hover/active + disabled treatments), status chip tint
surfaces, fixed type scale, 8px-base spacing, radii, focus spec, motion durations.
`tokens-build.mjs` generates `tokens.css` (`:root` + `[data-theme=dark]` +
`prefers-color-scheme` auto scope) with a JSON↔CSS parity check. `contrast.mjs` enforces
all 38 declared WCAG pairs — the gate caught two real failures during build (processing
and danger chip tints at 4.23/4.39) which were lightened to pass; the audit's two seed
defects are fixed as tokens (`border-strong` #75847B at 3.87:1; focus = Deep Current on
light / Rindle Green on dark).

**Brand book (BRAND-06):** `brandbook/index.html` + `brand.css` — single page, fixed
anchor nav, zero JS, renders offline from `file://`. Zero hex literals outside
tokens.css; every swatch, chip, button, input, card, lifecycle rail, and code block is
live DOM styled by the tokens, including a `[data-theme=dark]` demo region. Sections:
cover, essence (pillars + personality), logo system (usage/misuse/construction), color
(measured ratios printed on swatches), typography (live specimens from committed woff2),
voice, microcopy (status vocab, empty states, errors, modal), components & layout,
imagery/icons/motion, applications & copy bank, do/don't + LLM capsule.

**Hygiene (BRAND-07):** webfonts committed (204 KB woff2 + OFL texts); Phase-82 evidence
re-encoded to JPEG; `check.mjs` green: 57 SVGs pass constraints, brandbook/ total
1.26 MB (≤ 1.5 MB) with headroom for the Phase-85 social card.

Verification: full-page + per-section Playwright screenshots reviewed; fonts render from
file://; dark region demonstrates the dark token set live.
