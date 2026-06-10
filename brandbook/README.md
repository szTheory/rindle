# Rindle Brand System

Self-contained brand system for Rindle. **Open `index.html` in a browser** — it is the
canonical brand book, rendered live from the design tokens (works offline from `file://`,
no build step).

## What lives here

| Path | What |
|---|---|
| `index.html` + `brand.css` | The brand book (single page; consumes the tokens, embeds the logo SVGs) |
| `tokens/tokens.json` | **Source of truth**: raw palette, semantic roles (light + dark), type scale, spacing, radii, focus, motion, and the WCAG contrast-pair declarations |
| `tokens/tokens.css` | Generated custom properties (`--rindle-*`) — never edit by hand |
| `assets/logo/` | Final logo system: lockups (primary/dark/mono/subtitle), icon-only marks, favicon set (`.svg`/16/32/`.ico`), social avatar |
| `assets/logo/candidates/` | Phase-82 exploration provenance: the five directions + Confluence refinement variants + comparison sheets |
| `fonts/` | Committed woff2 webfonts (Space Grotesk, Atkinson Hyperlegible, JetBrains Mono) + SIL OFL license texts |
| `src/` | Generation pipeline (Node, zero system deps beyond the repo's existing Playwright install) |

## Regenerating assets

```sh
cd brandbook/src
npm install               # opentype.js only
node tokens-build.mjs     # tokens.json -> tokens.css (with parity check)
node contrast.mjs         # WCAG AA gate over all declared pairs (exits 1 on failure)
node logo.mjs             # final logo SVGs from the locked geometry
node render-derived.mjs   # favicon-16/32.png + avatar-512.png (Playwright)
magick ../assets/logo/favicon-32.png ../assets/logo/favicon-16.png ../assets/logo/favicon.ico
node check.mjs            # constraint + size-budget gates (exits 1 on violation)
```

Committed SVGs are build artifacts (like a lockfile): edit `src/candidates.mjs` /
`src/geometry.mjs` and rebuild — never the SVGs directly.

## Hard rules (enforced by `src/check.mjs` + `src/contrast.mjs`)

- No background/container shapes on any mark; no `<text>` elements (type is outlined);
  no embedded rasters or external references in SVGs.
- The primary lockup never carries the tagline (`rindle-logo-subtitle.svg` is the only
  variant that does).
- Every declared color pair meets WCAG AA (4.5:1 text, 3:1 non-text). Rindle Green and
  Rind Lime are accent-only on light surfaces. Focus rings: Deep Current on light,
  Rindle Green on dark.
- `brandbook/` total ≤ 1.5 MB; SVGs ≤ 8 KB (subtitle/sheet ≤ 16 KB).

## Provenance

Built in milestone **b1.0 Brand Foundations** (phases 81–85). The pressure-test audit of
the original AI-research seed lives at `.planning/research/b1.0-brand-audit.md`; the seed
itself (`prompts/rindle-brand-book.md`) is preserved untouched as history. Logo direction
and execution were user-selected (decisions D-b1.0-04/05).
