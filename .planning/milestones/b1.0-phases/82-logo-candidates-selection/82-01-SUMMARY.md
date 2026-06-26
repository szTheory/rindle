---
phase: 82
plan: 01
status: complete
completed: 2026-06-10
one_liner: Reproducible opentype.js SVG pipeline + five distinct candidate directions (30 SVGs) — three integrated typemarks among them; all constraint gates green at 0.70 MB total.
---

# 82-01 Summary

Pipeline in `brandbook/src/` (geometry/candidates/build/render/check + sheet generator);
OFL fonts committed (Space Grotesk Medium/Bold, Atkinson Regular, JetBrains Mono for
Phase 84). 30 candidate SVGs in `brandbook/assets/logo/candidates/`.

The five directions:
- **A Headgate** (mark+type) — open arch shelters a current flowing through it; asset dot rides the current
- **B Headwater r** (integrated typemark + monogram) — the r's arm flows below the baseline toward the word, carrying a bead
- **C Branch dot** (integrated typemark) — the i tittle branches into two variant dots above the ascender
- **D Outflow e** (integrated typemark) — the e terminal trails out as a delivery current with a bead
- **E Confluence** (mark+type interlocked) — three inputs merge into a current running under "ri"

Three visual iteration rounds via Playwright screenshots fixed: wordmark path truncation
(replaced opentype.js toPathData with own serializer), B reading as "ɔ/n" (arm now stops
at the font's terminal height; thin swash takes over), A reading as a snake (concept
re-grounded as Headgate), E underline clearance and convergence cleanup.

`node check.mjs`: 30 SVGs pass (viewBox, no text/rect/image/external refs, ≤8/16 KB);
xmllint all valid; brandbook/ total 0.70 MB.
