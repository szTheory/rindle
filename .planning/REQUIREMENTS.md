# Requirements: Rindle

**Defined:** 2026-05-27 (v1.19 charter added 2026-06-14)
**Milestone:** v1.19 Design-System Stress-Test (SEED-002; maintainer-pull quality milestone; hex 0.3.x)
**Core Value:** Media, made durable.

> ⚠️ **v1.19 opens over an un-closed v1.18.** v1.18 Admin Console & Adoption Lab is held at
> `status: tech_debt` pending maintainer HUMAN-UAT sign-off (Phases 90/91/92); its archive
> commit was reset away on `main`, so its requirements remain inline below (demoted, not
> archived) rather than in `.planning/milestones/v1.18-REQUIREMENTS.md`. Recorded maintainer
> decision (2026-06-14). Close via `/gsd-complete-milestone v1.18` once UAT is signed off.

## v1.19 Design-System Stress-Test (active)

**Charter (2026-06-14):** Maintainer-pull quality milestone (SEED-002). Elevate the whole
design system to an award-winning bar — fractally and without regressions — across the
admin/operator console **and** the Cohort example app's inner pages, in service of real user
flows. Two intertwined tracks (admin DS uplift + Cohort restyle) on a hardened token→CSS
pipeline, proven by a deterministic merge-blocking visual gate. LIFE-06/STREAM-10 stay
demand-gated and shift to v1.20+. Research: `.planning/research/v1.19/SUMMARY.md`.

### Foundation & Token Pipeline (PIPE)

- [x] **PIPE-01**: Token→CSS pipeline is gated in CI — a `brandbook-tokens` job regenerates
  `rindle-admin.css` + `cohort.css` from `tokens.json` via the `.mjs` scripts, runs the WCAG
  contrast gate, and fails on any uncommitted diff. Generated CSS is never hand-edited; this
  is the idempotency / no-regression anchor that lands before any visual work.

- [x] **PIPE-02**: Token system extended in `tokens.json` + the `.mjs` generators with the
  categories the uplift needs: motion presets (durations/easings), a true dark **elevation /
  shadow ladder** (semantic, not color-inversion), responsive **fluid type + space scales**
  with named breakpoints, and semantic dark-mode status surfaces — all flowing to both
  `rindle-admin` (BEM) and `cohort` (own DS), kept coherent but separate.

### Admin / Operator DS Uplift (UPLIFT)

- [ ] **UPLIFT-01**: Every admin component is on-brand and excellent across the full
  interaction-state matrix (default / hover / **focus-visible** / active / disabled / loading /
  empty / error / skeleton) in **light, dark, and system** — audited against tokens, with the
  `active` vs `focus-visible` distinction explicit and no one-off styles.

- [x] **UPLIFT-02**: Meta-components refined as cohesive units — toolbars, **sortable / sticky-
  header / bulk-select data tables**, filter bars, action panels, detail drill-downs,
  confirm/destructive panels, drawers, toasts — consistent rhythm, alignment, and density.

- [x] **UPLIFT-03**: Per-page composition pass over each console surface — visual hierarchy,
  spacing scale, and on-brand assembly of components into pages.

- [x] **UPLIFT-04**: Motion pass — purposeful, performant, **reduced-motion-aware** animation
  tied to brand motion tokens, sub-300ms, and **LiveView-coordinated** (`JS.transition` via
  `phx-mounted`/`phx-remove`; `transform`/`opacity` only; no `transition:all` on patched nodes).

- [x] **UPLIFT-05**: Mobile-first responsive — every console surface is correct and usable at
  all breakpoints.

- [x] **UPLIFT-06**: Accessibility audit — keyboard navigation, focus order + visible focus,
  ARIA semantics on custom components (menus, dialogs, tables, toasts), no keyboard traps in
  drawers/dialogs, and WCAG AA contrast in **both** themes.

- [x] **UPLIFT-07**: gov.uk/GDS-style information architecture — task-first triage home,
  least-surprise navigation and labels, progressive disclosure, serving onboarding /
  intermediate / advanced operators across happy / error / boundary paths.

- [x] **UPLIFT-08**: Microcopy on-brand in the **operator/SRE voice** (terse, diagnostic, GDS
  rules: say what happened + how to fix; no please/oops/sorry/jargon), tied to each surface's
  JTBD/persona.

### Cohort Example Inner-Page Restyle (COHORT)

- [x] **COHORT-01**: `/dashboard` restyled onto the Cohort DS (`cohort.css` + `cohort_components.ex`).
- [x] **COHORT-02**: `/upload` (all tabs) restyled onto the Cohort DS.
- [x] **COHORT-03**: `/ops` restyled onto the Cohort DS.
- [x] **COHORT-04**: member / lesson / post / media / account pages restyled and consistent.
- [ ] **COHORT-05**: daisyUI/Tailwind scaffold retired from the inner pages — migrated
  **class-by-class, not element-by-element**, preserving every `id` / `data-testid` / `phx-hook`
  so behavior e2e stays green; the `default.css` `<link>` removed only once grep is clean.

- [x] **COHORT-06**: Cohort gains a dark `[data-theme]` contract **and** a
  `prefers-reduced-motion` block (net-new — `cohort.css` has neither today), with the new
  contrast pairs added to the WCAG gate and all color literals replaced by tokens.

### Proof & No-Regression (VIS)

- [x] **VIS-01**: Deterministic computed-style assertions (the `admin-polish.js` pattern) remain
  the **single merge-blocking** visual gate, extended to cover all admin + Cohort inner pages
  across light/dark in the `adoption-demo-e2e` lane.

- [ ] **VIS-02**: Uplift is idempotent / forward-only — each pass converges (double-run
  empty-diff check) with zero functional or visual regression to existing flows; every page
  migration is gated on its behavior e2e specs.

- [ ] **VIS-03** *(differentiator)*: Optional pixel-baseline screenshots (`toHaveScreenshot()`)
  may augment the gate **only** if CI-generated, motion-frozen, and font-stable — never a flaky
  merge blocker.

- [ ] **VIS-04** *(differentiator)*: Living component gallery (admin + Cohort) as an audit
  reference surface, kept in sync with the generated CSS and screenshotted by the visual lane.

## v1.18 Admin Console & Adoption Lab (tech_debt — HUMAN-UAT pending; not yet archived)

**Status:** All 19 requirements + 8 phases verified; milestone held at `tech_debt` awaiting
maintainer HUMAN-UAT sign-off on Phases 90/91/92. Retained inline (archival reset away on
`main`). Audit: `.planning/milestones/v1.18-MILESTONE-AUDIT.md`.

**Charter (2026-06-10):** Maintainer-pull feature milestone, explicitly overriding the
PAUSE-03 reservation of v1.18+ for LIFE-06/STREAM-10. This milestone reversed the prior
"admin UI out of scope" decision (JTBD T4): a mountable, Rindle-branded admin console ships
in the `rindle` package, proven through the Cohort demo with full lifecycle-state seed
coverage, deterministic E2E, and Docker DX fixes.

### Admin Console (ADMIN)

- [x] **ADMIN-01**: Host app mounts the console via a router macro with a host-supplied
  auth pipeline + `on_mount` hook; safe-by-default (refuses unauthenticated mount outside dev).

- [x] **ADMIN-02**: Console ships fully self-contained precompiled assets (CSS/JS) — zero
  host asset-pipeline or Tailwind dependency; assets served by the library.

- [x] **ADMIN-03**: Read surfaces — task-oriented home, assets list filterable by FSM state,
  asset detail (state timeline, variants, attachments), upload sessions, variant/job
  activity, doctor + runtime status.

- [x] **ADMIN-04**: Ops actions — owner erasure preview/execute and batch erasure with
  deliberate destructive-action UX (typed confirmation, collateral preview), variant
  regeneration, quarantine review, lifecycle repair.

- [x] **ADMIN-05**: Live updates via existing pubsub topics (`:asset`, `:variant`,
  `:upload_session`); queries isolated in `Rindle.Admin.Queries`, not the public facade.

- [x] **ADMIN-06**: `phoenix_live_view` stays optional — console compiles away cleanly
  when absent (extends the `Code.ensure_loaded?` gating pattern); optional-dep matrix in CI.

### Design System (DS)

- [x] **DS-01**: `rindle-admin` design system generated from `brandbook/tokens/tokens.json`
  (BEM + CSS custom properties); components rolled into the system, no one-off styles.

- [x] **DS-02**: Light/dark/system theme picker as a first-class component
  (`data-theme` + `prefers-color-scheme`).

- [x] **DS-03**: Mechanical WCAG AA contrast gate over console token pairs
  (reuse `brandbook/src/contrast.mjs` pattern).

### Demo / Adoption Evidence (DEMO)

- [x] **DEMO-01**: Cohort gets its own lightweight brand, distinct from Rindle
  (rendered options checkpoint for maintainer pick; replaces Phoenix firebird placeholder).

- [x] **DEMO-02**: Cohort exercises audio + document media types, and seeds express every
  asset/variant/session lifecycle state (incl. degraded, quarantined, failed, stale, expired).

- [x] **DEMO-03**: Cohort mounts the admin console; click-around walkthrough documented.

### E2E / Shift-Left (E2E)

- [x] **E2E-01**: Deterministic Playwright specs for the console (happy paths, main error
  cases, boundary conditions, theme switching, destructive flows) in a merge-blocking CI lane.

- [x] **E2E-02**: Automated all-screens × light/dark screenshot capture feeding
  analyze→fix polish iteration passes.

### Docker DX (DX)

- [x] **DX-01**: Compose stack is port-conflict-free alongside sibling projects
  (project namespacing + env-driven ports with sane defaults and conflict guidance).

- [x] **DX-02**: Dockerfile layer caching fixed (deps fetched before source COPY) and a
  dev iteration path where style/template changes don't rebuild deps.

- [x] **DX-03**: Launch prints a copy-pasteable URL map (app, admin console, MinIO console).

### Principles & Truth (PRIN / TRUTH)

- [x] **PRIN-01**: Durable UI-principles doc (design-system values, audit checklist,
  deterministic-E2E rules) linked from `AGENTS.md` so future UI work never regresses.

- [x] **TRUTH-07**: Docs/facade parity for the scope reversal — `lib/rindle.ex` facade
  contract, `guides/`, JTBD-MAP T4 row, and README updated truthfully.

## Pause Posture Requirements (superseded for v1.18/v1.19 duration)

These documented maintainer obligations during maintenance mode (2026-05-27 → 2026-06-10).

### Maintenance

- [x] **PAUSE-01**: Maintainer ships patch/minor Hex releases and issue-driven fixes without
  opening a feature milestone or new public API surface.
  *Brand/docs/marketing work is not feature work and does not violate this posture
  (b1.0 charter, 2026-06-10).*

- [x] **PAUSE-02**: Assessment and path-to-done threads remain canonical references for
  done-% and wedge ranking (`.planning/threads/2026-05-27-*`).

- [x] **PAUSE-03**: `PROJECT.md`, `STATE.md`, and `ROADMAP.md` reflect demand-gated pause
  with no active **feature** phases until LIFE-06 or STREAM-10 signal (brand-track
  phases 81–85 are non-feature).
  *Amended 2026-06-10: maintainer-pull override recorded — v1.18 opens as a self-directed
  feature milestone. Extended 2026-06-14: v1.19 Design-System Stress-Test is a maintainer-pull
  quality milestone (SEED-002). LIFE-06/STREAM-10 stay demand-gated and shift to v1.20+.*

## Shipped Non-Feature Tracks

- **b1.0 Brand Foundations** (2026-06-10): BRAND-01..08 validated 8/8 — archived at
  `.planning/milestones/b1.0-REQUIREMENTS.md` ([audit](milestones/b1.0-MILESTONE-AUDIT.md)).

## Future Requirements (demand-gated)

Open only via `/gsd-new-milestone` with documented signal:

*(v1.20+ — shifted from v1.18 by the 2026-06-10 override, and past v1.19 which is non-feature DS work.)*

### Lifecycle (LIFE-06)

- **LIFE-06-01**: Maintainer can preview collateral damage when force-deleting shared assets
- **LIFE-06-02**: Maintainer can opt in to `force:` purge (never default) on owner erasure
- **LIFE-06-03**: Batch erasure and operator CLI inherit force opt-in with proof + docs parity

**Trigger:** Concrete compliance/legal ticket recorded in milestone charter.

### Streaming (STREAM-10)

- **STREAM-10-01**: Second provider proves `Rindle.Streaming.Provider` contract gaps
- **STREAM-10-02**: One adapter ships with `mix rindle.doctor --streaming` extension
- **STREAM-10-03**: Hermetic proof + label-gated soak + guide parity

**Trigger:** Named adopter + provider choice documented.

### Long-tail polish

- **TRANS-01**: Signed dynamic image transforms (job 33)
- **PRIV-01**: EXIF/GPS strip on originals (job 34)

**Trigger:** Explicit product pull only.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Metrics / time-series / charting dashboard (Grafana-style) | Scope creep; Rindle surfaces lifecycle **state**, not time-series — anti-feature for an operator console (v1.19 research) |
| Dark mode by color-inversion | Must be semantic tokens + a real elevation ladder (PIPE-02); inversion is an anti-pattern |
| Color-only status indication | Status must pair color with label/icon (a11y + UPLIFT-01); color-only is an anti-feature |
| Animate-everything / decorative motion | Motion is purposeful + reduced-motion-aware only (UPLIFT-04); gratuitous motion hurts operators |
| New console lifecycle semantics or write paths beyond v1.18 surface | v1.19 is DS quality only; no reopening tus / owner-erasure / provider surfaces |
| Adopting Tailwind or a JS animation lib in the `rindle` package | Self-contained assets + generated BEM stay the constraint (ADMIN-02 / DS-01) |
| Website / domain / hosted landing page | b1.0 is repo-artifact only |
| Force-delete (LIFE-06) / Second streaming provider (STREAM-10) | Demand-gated; require charter (v1.20+) |
| IETF RUFH / tus 2.0 · GCS-as-tus-backend · Standalone tus JS client | Long-tail / adopter-request only |
| Platform scope (DRM, HLS platform, CDN replacement) | Not a lifecycle library |

## Traceability

### v1.19 Design-System Stress-Test (phases 94–102)

| Requirement | Phase | Status |
|-------------|-------|--------|
| PIPE-01 | Phase 94 | Complete |
| PIPE-02 | Phase 94 | Complete |
| UPLIFT-01 | Phase 95 | Pending |
| UPLIFT-02 | Phase 97 | Complete |
| UPLIFT-03 | Phase 98 | Complete |
| UPLIFT-04 | Phase 98 | Complete |
| UPLIFT-05 | Phase 98 | Complete |
| UPLIFT-06 | Phase 98 | Complete |
| UPLIFT-07 | Phase 98 | Complete |
| UPLIFT-08 | Phase 98 | Complete |
| COHORT-01 | Phase 99 | Complete |
| COHORT-02 | Phase 100 | Complete |
| COHORT-03 | Phase 99 | Complete |
| COHORT-04 | Phase 99 | Complete |
| COHORT-05 | Phase 101 | Pending |
| COHORT-06 | Phase 96 | Complete |
| VIS-01 | Phase 102 | Complete |
| VIS-02 | Phase 102 | Pending |
| VIS-03 | Phase 102 | Pending |
| VIS-04 | Phase 102 | Pending |

**Coverage:** v1.19 requirements: 20 total, **20 mapped** to phases 94–102 (100%). VIS-01 has
groundwork in Phase 94 (generalizing `admin-polish.js`) but is *owned* by Phase 102 where it
becomes the single merge-blocking gate.

### v1.18 Admin Console & Adoption Lab (phases 86–93; tech_debt)

| Requirement | Phase | Status |
|-------------|-------|--------|
| ADMIN-01 | Phase 89 | Complete |
| ADMIN-02 | Phase 88–89 | Complete |
| ADMIN-03 | Phase 89 | Complete |
| ADMIN-04 | Phase 90 | Complete |
| ADMIN-05 | Phase 89 | Complete |
| ADMIN-06 | Phase 89 | Complete |
| DS-01 | Phase 88 | Complete |
| DS-02 | Phase 88 | Complete |
| DS-03 | Phase 88 | Complete |
| DEMO-01 | Phase 91 | Complete |
| DEMO-02 | Phase 91 | Complete |
| DEMO-03 | Phase 91 | Complete |
| E2E-01 | Phase 92 | Complete |
| E2E-02 | Phase 92 | Complete |
| DX-01 | Phase 87 | Complete |
| DX-02 | Phase 87 | Complete |
| DX-03 | Phase 87 | Complete |
| PRIN-01 | Phase 86 | Satisfied |
| TRUTH-07 | Phase 93 | Complete |
| PAUSE-01/02/03 | — | Satisfied (PAUSE-03 amended/extended) |
| LIFE-06-* / STREAM-10-* | v1.20+ (on signal) | Deferred |
| TRANS-01 / PRIV-01 | — | Deferred |

**Coverage:** v1.18 requirements: 19 total, 19 mapped to phases 86–93, all Complete/Satisfied
(milestone held at `tech_debt` pending HUMAN-UAT).

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-06-14 — v1.19 Design-System Stress-Test traceability filled by roadmapper:
PIPE→94, UPLIFT-01→95, UPLIFT-02→97, UPLIFT-03..08→98, COHORT-06→96, COHORT-01/03/04→99,
COHORT-02→100, COHORT-05→101, VIS-01..04→102 (20/20 mapped, 100%). v1.18 reqs demoted to
tech_debt (HUMAN-UAT pending, archival reset away). LIFE-06/STREAM-10 shifted to v1.20+.*
