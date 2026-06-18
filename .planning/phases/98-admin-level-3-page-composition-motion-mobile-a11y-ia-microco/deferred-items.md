# Phase 98 — Deferred Items

## P1 CSS defect (filed by 98-02b, Pitfall 2 — do NOT add CSS in P2b)

**Missing `.rindle-admin-visually-hidden` utility class.**
- **Discovered during:** 98-02b surface migrations (Task 1, Assets).
- **Context:** D-98-08 / UI-SPEC §D require each migrated data `<table>` to carry a
  `<caption>` naming the surface, and the plan states "visually-hidden ok". P2b adds
  `<caption class="rindle-admin-visually-hidden">…</caption>` on all six surfaces, but
  `brandbook/src/admin-css-build.mjs` (P1) never authored a `.rindle-admin-visually-hidden`
  selector (grep over `brandbook/tokens/rindle-admin.css` returns 0). The `<thead>` is
  visually-hidden at <760 via its own dedicated rule, but there is no general utility for
  the caption, so the caption currently renders visibly at ≥760.
- **Why not fixed here:** All CSS is authored in P1's generator (D-98-12/Pitfall 2). Adding
  the utility in P2b would hand-edit generated CSS and violate the generated-CSS boundary.
- **Suggested P1/P4 fix:** add `.rindle-admin-visually-hidden { position:absolute; width:1px;
  height:1px; overflow:hidden; clip:rect(0 0 0 0); clip-path:inset(50%); white-space:nowrap; }`
  to `admin-css-build.mjs` (same recipe already used inline for the stacked `<thead>` at
  L1264-1273) and add it to `requiredSelectors`.
