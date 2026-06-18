# Phase 98 — Deferred Items

## P1 CSS defect (filed by 98-02b, Pitfall 2 — do NOT add CSS in P2b) — RESOLVED in 98-04 (commit b637710)

**Missing `.rindle-admin-visually-hidden` utility class.** — RESOLVED: authored through the
full brandbook pipeline in 98-04 (`admin-css-build.mjs` → regen → contrast 58/58 → gallery-check →
`sync-admin-css.mjs`, byte-identical priv copy), added to `requiredSelectors`. The four migrated
table captions are now announced but unpainted at ≥760px. Original report retained below for audit.
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

## Local Playwright e2e lane could not be run during 98-04 execution (environment, not a defect)

- **Discovered during:** 98-04 Task 2 (after authoring the five computed-style backstops).
- **Context:** the `adoption-demo-e2e` lane's `global-setup.js` runs `mix ecto.create`, which
  failed locally with `FATAL 53300 too_many_connections` — the local Postgres was at 99/100
  connections (91 idle, leaked by prior `mix test` runs in this shared dev DB). This is the
  same pre-existing local Postgres noise recorded in the 98-01/98-03 summaries.
- **Why not resolved here:** terminating idle backends on the shared DB is out of plan scope.
  The backstop CODE is committed and statically validated (`node --check` passes both files;
  lockstep 24==24 verified; no warn→fail flip / no Cohort generalization in `git diff`). The
  live run is the explicit job of the 98-04 Task 3 BLOCKING human-verify checkpoint, and the
  lane runs on a clean DB in CI's merge-blocking `adoption-demo-e2e` job.
- **Action for the checkpoint approver:** run `cd examples/adoption_demo && npx playwright test`
  on a clean DB (or let CI run it) to exercise the five backstops live before sealing the phase.
