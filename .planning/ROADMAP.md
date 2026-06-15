# Roadmap: Rindle

## Milestones

- 🔄 **v1.19 Design-System Stress-Test** — Phases 94–102 (IN PROGRESS; maintainer-pull quality milestone, SEED-002; fractal admin/operator DS uplift + Cohort inner-page restyle; charter 2026-06-14; hex 0.3.x target)
- ⏸️ **v1.18 Admin Console & Adoption Lab** — Phases 86–93 (tech_debt — HUMAN-UAT pending: 19/19 reqs + 8/8 phases verified, HUMAN-UAT for 90/91/92 not yet signed off; NOT shipped; charter 2026-06-10; ships as hex 0.3.0; [audit](milestones/v1.18-MILESTONE-AUDIT.md))
- ✅ **b1.0 Brand Foundations** — Phases 81–85 (brand track, non-feature; shipped 2026-06-10, [archive](milestones/b1.0-ROADMAP.md), [audit](milestones/b1.0-MILESTONE-AUDIT.md))
- ✅ **v1.17 Adopter-Confidence Hygiene** — Phases 78–80 (shipped 2026-05-27, [archive](milestones/v1.17-ROADMAP.md), [audit](milestones/v1.17-MILESTONE-AUDIT.md))
- ✅ **v1.16 CI Enforcement & Planning Hygiene** — Phases 75–77 (shipped 2026-05-27, [archive](milestones/v1.16-ROADMAP.md))
- ✅ **v1.15 Maintenance & Proof Honesty** — Phases 71–74 (shipped 2026-05-27, [audit](milestones/v1.15-MILESTONE-AUDIT.md))
- ✅ **v1.14 Bulk Owner-Erasure Orchestration** — Phases 67–70 (shipped 2026-05-27, [archive](milestones/v1.14-ROADMAP.md))
- ✅ **v1.13 Cancel Direct Upload** — Phases 64–66 (shipped 2026-05-27, [archive](milestones/v1.13-ROADMAP.md))
- ✅ **v1.12 Adopter Truth & Maintenance Hygiene** — Phases 60–63 (shipped 2026-05-27, [archive](milestones/v1.12-ROADMAP.md))
- ✅ **v1.11 Tus Protocol Completion** — Phases 56–59 (shipped 2026-05-27, [archive](milestones/v1.11-ROADMAP.md))
- ✅ **v1.10 Owner Account Erasure** — Phases 53–55 (shipped 2026-05-26, [archive](milestones/v1.10-ROADMAP.md))
- ✅ **v1.9 Phoenix Tus DX Completion** — Phases 48–52 (shipped 2026-05-25, [archive](milestones/v1.9-ROADMAP.md))
- ✅ **v1.8 Resumable Browser Ingest** — Phases 42–47 (shipped 2026-05-25, [archive](milestones/v1.8-ROADMAP.md))
- ✅ **v1.7 GCS Resumable Adapter** — Phases 37–41 (shipped 2026-05-08, [archive](milestones/v1.7-ROADMAP.md))
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07, [archive](milestones/v1.6-ROADMAP.md))
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06, [archive](milestones/v1.5-ROADMAP.md))
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, [archive](milestones/v1.4-ROADMAP.md))
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, [archive](milestones/v1.3-ROADMAP.md))
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, [archive](milestones/v1.2-ROADMAP.md))
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, [archive](milestones/v1.1-ROADMAP.md))
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, [archive](milestones/v1.0-ROADMAP.md))

## Phases

### v1.19 Design-System Stress-Test (Phases 94+) — IN PROGRESS

**Charter (2026-06-14):** Maintainer-pull **quality** milestone (SEED-002). Elevate the whole
design system to an award-winning bar — fractally (component → meta-component → page) and
**without regressions** — across the mountable admin/operator console **and** the Cohort
demo's inner pages, in service of real user flows. Near-zero new dependencies: extend the
existing `tokens.json → .mjs → rindle-admin.css` pipeline (admin) and hand-authored
`cohort.css` + `CohortComponents` (demo). No Tailwind in `rindle`, no JS animation lib in
`rindle`, no SaaS visual-regression, no Storybook. Likely ships as hex **0.3.x**.

**Build order (research-locked, repo-verified):** Foundation FIRST (Phase 94 — harden +
CI-gate the token→CSS pipeline; it is *un-gated today* and is the idempotency / no-regression
anchor that blocks everything). Then **two parallel tracks** — Track A (admin DS:
component → meta-component → page) and Track B (Cohort restyle: `.ck-*` component layer +
net-new dark/reduced-motion contract → page-by-page migration → daisyUI retirement). Within
each track, fractal **Level 1 → 2 → 3 is a hard dependency** (pages compose only from finished
primitives — this is what makes quality compound idempotently). **Re-converge LAST** (Phase
102 — full light/dark/mobile visual matrix + idempotency double-run gate + milestone audit).

**Proof strategy (RESOLVED in research — single gate, no flaky blocker):** Deterministic
computed-style assertions (the `admin-polish.js` pattern, generalized over admin + Cohort) are
the **single merge-blocking** visual gate in the `adoption-demo-e2e` lane — deterministic,
self-explaining (its offender list IS the analyze→fix worklist), and flakiness-controlled
(`freezeMotion`, `animations:disabled`, `workers:1`). Golden-PNG pixel baselines
(`toHaveScreenshot()`) are **optional / non-blocking** — permitted only if CI-generated,
motion-frozen, and font-stable; never merge-blocking until proven stable. The committed PNG
matrix stays a human-review artifact, not a CI assertion.

**Locked decisions (carried / new):** The two design systems stay **deliberately separate but
coherent** — `rindle-admin` (`.rindle-admin-*` BEM, generated, host-Tailwind-independent) and
`cohort.css` (`.ck-*`, hand-authored, emerald brand) share vocabulary but **never** a
stylesheet, token file, or build step. Generated `rindle-admin.css` is **never hand-edited**
(generator is the only writer). Migration is **class-by-class, never element-by-element**,
preserving every `id` / `data-testid` / `phx-hook` as a frozen behavior contract. Anti-features
out of scope: metrics/charting dashboard, dark-by-inversion, color-only status,
animate-everything, generating `cohort.css` from `tokens.json`.

> ⚠️ **Opens over an un-closed v1.18.** v1.18 Admin Console & Adoption Lab is held at
> `status: tech_debt` pending maintainer HUMAN-UAT sign-off (Phases 90/91/92). This is a
> deliberate, recorded maintainer scope move (2026-06-14), not an oversight. v1.18's phase
> section and archive content below are preserved verbatim; close it via
> `/gsd-complete-milestone v1.18` once UAT is signed off.

Each phase runs full GSD: research → plan → execute → verify, with a maintainer go/no-go gate
between phases (`auto_advance: false`).

- [ ] **Phase 94: Foundation — Token Pipeline CI Gate & New Token Categories** — close the
  un-gated-pipeline gap (NEW `brandbook-tokens` CI job: regen + contrast + gallery-check +
  `git diff --exit-code`), add the token categories the uplift needs (motion presets, dark
  elevation/shadow ladder, fluid type/space + breakpoints, semantic dark status surfaces), and
  generalize the `admin-polish.js` computed-style gate to target any root. **Blocks everything.**
  (PIPE-01, PIPE-02, VIS-01 groundwork)
- [ ] **Phase 95 [Track A]: Admin Level-1 Component Audit** — every `rindle-admin-*` component ×
  full state matrix (default/hover/focus-visible/active/disabled/loading/empty/error/skeleton)
  × light/dark/auto/mobile; token-backed `:focus-visible`; extend gallery + contrast pairs.
  (UPLIFT-01)
- [ ] **Phase 96 [Track B]: Cohort Component Layer + Dark / Reduced-Motion Contract** — build the
  `.ck-*` Level-1 + Level-2 primitives (table/stat/form/tabs/detail/toolbar) + `CohortComponents`
  + a `/styleguide` gallery route; **author the net-new dark `[data-theme]` contract and
  `prefers-reduced-motion` block in `cohort.css`** (neither exists today), replace all color
  literals with tokens, extend the WCAG gate to both themes. (COHORT-06)
- [ ] **Phase 97 [Track A]: Admin Level-2 Meta-Components** — toolbars, sortable/sticky-header/
  bulk-select data tables, filter bars, action panels, detail drill-downs, confirm/destructive
  panels, drawers, toasts as cohesive units; rhythm / alignment / density / overlap gates.
  (UPLIFT-02)
- [ ] **Phase 98 [Track A]: Admin Level-3 Page Composition + Motion / Mobile / A11y / IA /
  Microcopy** — assemble every console surface from primitives only; purposeful reduced-motion-
  aware sub-300ms LiveView-coordinated motion; mobile-first at all breakpoints; keyboard / focus
  / ARIA / WCAG-AA-both-themes a11y; gov.uk/GDS task-first IA; operator-voice microcopy per
  surface JTBD. (UPLIFT-03, UPLIFT-04, UPLIFT-05, UPLIFT-06, UPLIFT-07, UPLIFT-08)
- [ ] **Phase 99 [Track B]: Cohort Page Migrations (the small 7)** — `/dashboard`, `/ops`,
  member, lesson, post, media, account → `.ck-*`, class-by-class, preserving every
  `id`/`data-testid`/`phx-hook`; each page's behavior e2e specs stay green. (COHORT-01,
  COHORT-03, COHORT-04)
- [ ] **Phase 100 [Track B]: Cohort `/upload` Migration (all tabs)** — isolated (484 lines,
  tab-structured, heaviest `PresignedPut`/`MultipartUpload`/`Copy` hooks); migrate class-by-class
  preserving the frozen behavior contract; upload behavior specs green. (COHORT-02)
- [ ] **Phase 101 [Track B]: daisyUI Retirement** — grep the demo clean of daisyUI/utility classes
  → remove the `default.css` `<link>` → delete `default.css` → polish pass confirms no page
  regressed to unstyled. Gated on Phases 96/99/100 complete. (COHORT-05)
- [ ] **Phase 102: Re-Converge — Visual Matrix, Idempotency Gate & Milestone Audit** —
  `cohort-screenshots.spec.js` merged into the matrix; `admin-polish.js` flipped warn→fail as
  the single merge-blocking gate over admin + Cohort across light/dark/mobile; idempotency
  double-run empty-diff check; optional non-blocking pixel baselines + living gallery; milestone
  audit + requirements traceability + docs parity. Depends on both tracks. (VIS-01, VIS-02,
  VIS-03, VIS-04)

### 🔄 v1.18 Admin Console & Adoption Lab (Phases 86–93) — IN PROGRESS

**Charter (2026-06-10):** Maintainer-pull feature milestone — explicit, recorded override
of the PAUSE-03 v1.18+ reservation (LIFE-06/STREAM-10 stay demand-gated, now v1.19+).
Reverses the JTBD T4 "admin UI out of scope" exclusion as a deliberate scope change.
Ships as hex **0.3.0** (brand work releases separately as 0.2.0 first).

**Locked decisions:** D-v1.18-01 console ships in the `rindle` package, mountable
Oban-Web/LiveDashboard-style with self-contained assets; D-v1.18-02 hex 0.3.0 after the
0.2.0 brand release; D-v1.18-03 Cohort stays the demo domain, extended (audio + documents
+ full state-space seeds) — no E2E churn for its own sake.

Each phase runs full GSD: discuss → research → plan → execute → verify, with a
maintainer go/no-go gate between phases.

- [x] **Phase 86: Research & Architecture Lock** — parallel subagent research → locked ADRs: (completed 2026-06-11)
  LiveDashboard/Oban Web packaging (router macro, asset serving, CSP, CSS isolation,
  optional-dep matrix); gov.uk/GDS information architecture → persona/JTBD-driven console
  IA map; emilkowal.ski animation principles → restrained motion spec tied to brand
  `motion` tokens; Docker multi-project DX (COMPOSE_PROJECT_NAME / env ports / traefik
  tradeoffs); CSS architecture lock (BEM + custom properties generated from
  `brandbook/tokens/tokens.json` for the console; Cohort keeps Tailwind/daisyUI momentum).
  Output includes the UI-principles doc linked from `AGENTS.md` (PRIN-01).
- [x] **Phase 87: Docker & Demo DX** (early — every later UI phase iterates faster) — (completed 2026-06-11)
  project namespacing, env-driven ports + conflict guidance, layer-cache fix
  (deps before source COPY), dev style-change path without rebuilds, launch URL map,
  reader-empathetic docs. (DX-01..03)
- [x] **Phase 88: Admin Design System & UI Kit** — token-generated `rindle-admin` CSS
  (BEM), light/dark/system theme picker, core components (nav shell, tables,
  lifecycle-state chips, buttons, confirm dialog, drawer, toasts, empty states,
  skeletons), component-gallery screenshot harness, WCAG contrast gate.
  **Checkpoint: maintainer reviewed rendered gallery; requested anchor-navigation fix is
  implemented and regression-covered.** (completed 2026-06-11; DS-01..03, ADMIN-02 groundwork)
- [x] **Phase 89: Console Read Surfaces** — router macro + host-auth `on_mount` + (completed 2026-06-12)
  asset-serving plug (safe by default); home, assets list/detail, upload sessions,
  variant/job activity, doctor + runtime status; pubsub live updates;
  `Rindle.Admin.Queries` isolation; optional-dep CI matrix. (ADMIN-01..03, 05, 06)
- [x] **Phase 90: Console Ops Actions** — erasure preview/execute + batch with (completed 2026-06-13; UAT complete 2026-06-14 — destructive-UX gate automated into merge-blocking CI)
  destructive-action UX (typed confirmation, collateral preview), variant regeneration,
  quarantine review, lifecycle repair. (ADMIN-04)
- [x] **Phase 91: Cohort Demo Evolution** — Cohort's own lightweight brand (completed 2026-06-12)
  (**rendered options checkpoint**), audio + document profiles, seeds expressing every
  lifecycle state, mounts the console, click-around walkthrough. (DEMO-01..03)
- [x] **Phase 92: E2E & Screenshot-Driven Polish Loop** — deterministic console Playwright (completed 2026-06-13; UAT complete 2026-06-14 — screenshot visual-polish review automated into the merge-blocking CI lane via `admin-polish.js`; 0 human UAT)
  specs (happy/error/boundary/theme/destructive) in a merge-blocking lane; all-screens ×
  light/dark capture → analyze → fix polish passes. (E2E-01..02)
- [x] **Phase 93: Truth, Docs & Milestone Audit** — `guides/admin_console.md`, (completed 2026-06-13)
  user_flows + JTBD-MAP updates (T4 reversal), facade moduledoc truth fix
  (`lib/rindle.ex` "no admin UI" line), README/HexDocs, traceability closure,
  MILESTONE-AUDIT. (TRUTH-07)

## Phase Details

### Phase 94: Foundation — Token Pipeline CI Gate & New Token Categories

**Goal:** The token→CSS pipeline is gated in CI and carries the new token categories the uplift
needs, so all later visual work is idempotent and drift-proof. Blocks everything.

**Depends on:** v1.19 charter recorded; b1.0 tokens + `rindle-admin` pipeline shipped (v1.18).

**Requirements:** PIPE-01, PIPE-02, VIS-01 (groundwork)

**Success Criteria** (what must be TRUE):
1. A `brandbook-tokens` CI job regenerates `rindle-admin.css` (+ Cohort assets) from
   `tokens.json` via the `.mjs` scripts, runs the WCAG contrast gate, and **fails the build on
   any uncommitted diff** — generated CSS can no longer drift from source.
2. `tokens.json` + the `.mjs` generators emit the new categories — motion presets
   (durations/easings), a semantic dark **elevation/shadow ladder** (not color-inversion),
   fluid type + space scales with named breakpoints, and semantic dark status surfaces — flowing
   to both `rindle-admin` (BEM) and `cohort` (own DS), coherent but separate.
3. Re-running the generators with unchanged source produces a **byte-identical, empty-diff**
   artifact (idempotency anchor verified).
4. The `admin-polish.js` computed-style gate is generalized to target any root selector
   (`.rindle-admin-*` or `.ck-*`), ready to run over both surfaces.

**Plans:** TBD
**UI hint:** yes

---

### Phase 95: Admin Level-1 Component Audit [Track A]

**Goal:** Every admin component is on-brand and excellent across the full interaction-state
matrix in light, dark, and system — the settled Level-1 foundation pages will compose from.

**Depends on:** Phase 94

**Requirements:** UPLIFT-01

**Success Criteria** (what must be TRUE):
1. Every `rindle-admin-*` component renders correctly across default / hover / focus-visible /
   active / disabled / loading / empty / error / skeleton states in light, dark, and auto.
2. The `active` vs `focus-visible` distinction is explicit, with token-backed `:focus-visible`
   on every interactive selector (never bare `outline:none`).
3. The component gallery and `CONSOLE_CONTRAST_PAIRS` are extended to cover the new states; the
   contrast gate passes in both themes with no one-off styles.

**Plans:** TBD
**UI hint:** yes

---

### Phase 96: Cohort Component Layer + Dark / Reduced-Motion Contract [Track B]

**Goal:** Cohort has a complete `.ck-*` component + meta-component layer and a net-new dark and
reduced-motion contract, so its inner pages can migrate onto finished primitives.

**Depends on:** Phase 94

**Requirements:** COHORT-06

**Success Criteria** (what must be TRUE):
1. `.ck-*` Level-1 + Level-2 primitives (table, stat tile, form, tabs, detail block, toolbar)
   exist in `cohort.css` + `CohortComponents`, rendered in a `/styleguide` gallery route.
2. `cohort.css` gains a dark `[data-theme]` contract **and** a `prefers-reduced-motion` block
   (both net-new — neither exists today), with semantic elevation, not color-inversion.
3. All color literals in the Cohort DS are replaced by `--ck-*` tokens (grep-clean), and the new
   light + dark contrast pairs pass the WCAG gate.

**Plans:** TBD
**UI hint:** yes

---

### Phase 97: Admin Level-2 Meta-Components [Track A]

**Goal:** Admin meta-components read as cohesive units with consistent rhythm and density.

**Depends on:** Phase 95

**Requirements:** UPLIFT-02

**Success Criteria** (what must be TRUE):
1. Toolbars, sortable / sticky-header / bulk-select data tables, filter bars, action panels,
   detail drill-downs, confirm/destructive panels, drawers, and toasts are refined as composed
   units built only from Level-1 primitives.
2. Rhythm, alignment, and density are consistent across meta-components, verified by
   rhythm/overlap/no-horizontal-scroll gates in `admin-polish.js`.
3. Each meta-component appears in the gallery as a unit for visual-cohesion review.

**Plans:** TBD
**UI hint:** yes

---

### Phase 98: Admin Level-3 Page Composition + Motion / Mobile / A11y / IA / Microcopy [Track A]

**Goal:** Every console surface is an award-bar page assembled from primitives — motion,
responsive, accessible, task-first, and on-voice — serving real operator JTBDs.

**Depends on:** Phase 97

**Requirements:** UPLIFT-03, UPLIFT-04, UPLIFT-05, UPLIFT-06, UPLIFT-07, UPLIFT-08

**Success Criteria** (what must be TRUE):
1. Every admin surface is composed from Level-1/2 primitives only (no page-local one-offs),
   with on-brand visual hierarchy and spacing.
2. Motion is purposeful, reduced-motion-aware, sub-300ms, GPU-only (`transform`/`opacity`), and
   LiveView-coordinated (`JS.transition` via `phx-mounted`/`phx-remove`; no `transition:all` on
   patched nodes).
3. Every surface is correct and usable mobile-first at all breakpoints.
4. Keyboard navigation, focus order + visible focus, ARIA semantics on custom components, no
   keyboard traps in drawers/dialogs, and WCAG AA contrast hold in **both** themes.
5. IA is gov.uk/GDS task-first (triage home, progressive disclosure, least-surprise labels), and
   microcopy is in the terse operator/SRE voice tied to each surface's JTBD/persona.

**Plans:** TBD
**UI hint:** yes

---

### Phase 99: Cohort Page Migrations (the small 7) [Track B]

**Goal:** Cohort's seven small inner pages render on the `.ck-*` DS with behavior preserved.

**Depends on:** Phase 96

**Requirements:** COHORT-01, COHORT-03, COHORT-04

**Success Criteria** (what must be TRUE):
1. `/dashboard`, `/ops`, and the member / lesson / post / media / account pages are restyled
   onto `cohort.css` + `CohortComponents` and are visually consistent.
2. Migration is class-by-class (not element-by-element), preserving every `id` / `data-testid` /
   `phx-hook` as a frozen contract.
3. Each migrated page's existing behavior e2e specs stay green, and a Cohort screenshot/polish
   case is added per page.

**Plans:** TBD
**UI hint:** yes

---

### Phase 100: Cohort `/upload` Migration (all tabs) [Track B]

**Goal:** The heaviest inner page (`upload_live`, all tabs) is restyled without breaking its
hook-dense upload flows.

**Depends on:** Phase 96

**Requirements:** COHORT-02

**Success Criteria** (what must be TRUE):
1. `/upload` and all its tabs render on the `.ck-*` DS, migrated class-by-class.
2. Every `id` / `data-testid` / `phx-hook` (incl. `PresignedPut`, `MultipartUpload`, `Copy`) is
   preserved; the upload behavior e2e specs stay green across tabs.
3. A light/dark screenshot + polish case covers the upload surface.

**Plans:** TBD
**UI hint:** yes

---

### Phase 101: daisyUI Retirement [Track B]

**Goal:** The daisyUI/Tailwind scaffold is gone from the inner pages and the demo is grep-clean.

**Depends on:** Phase 96, Phase 99, Phase 100

**Requirements:** COHORT-05

**Success Criteria** (what must be TRUE):
1. A grep for daisyUI/utility classes across the demo inner pages is clean.
2. The `default.css` `<link>` is removed from `root.html.heex` and `default.css` is deleted —
   only after the grep is clean.
3. A final screenshot/polish pass confirms no page regressed to unstyled and all behavior e2e
   specs stay green.

**Plans:** TBD
**UI hint:** yes

---

### Phase 102: Re-Converge — Visual Matrix, Idempotency Gate & Milestone Audit

**Goal:** A single deterministic merge-blocking visual gate covers admin + Cohort across
light/dark/mobile, idempotency is proven, and the milestone is audited.

**Depends on:** Phase 98 (Track A) and Phase 101 (Track B)

**Requirements:** VIS-01, VIS-02, VIS-03, VIS-04

**Success Criteria** (what must be TRUE):
1. `cohort-screenshots.spec.js` is merged into the matrix and the generalized `admin-polish.js`
   computed-style gate runs over all admin + Cohort inner pages across light/dark in the
   `adoption-demo-e2e` lane as the **single merge-blocking** visual gate (flipped warn→fail).
2. A double-run idempotency check produces an empty diff with zero functional or visual
   regression to existing flows; every page migration is gated on its behavior e2e specs.
3. The full light/dark/mobile matrix is green for admin + Cohort; optional pixel baselines
   (`toHaveScreenshot()`) and the living component gallery exist only as **non-blocking**
   assistive/audit signals (CI-generated, motion-frozen, font-stable).
4. Milestone audit, requirements traceability (20/20), and docs parity are closed.

**Plans:** TBD
**UI hint:** yes

---

### Phase 86: Research & Architecture Lock

**Goal:** Lock the architecture, information architecture, animation, Docker DX, CSS, and
UI-principles decisions that downstream v1.18 phases must follow.

**Depends on:** v1.18 charter recorded; b1.0 brand assets and tokens available.

**Requirements:** PRIN-01

**Success criteria:**

1. LiveDashboard/Oban Web packaging decisions are recorded for router macro, asset serving,
   CSP, CSS isolation, and optional-dependency matrix.
2. Console information architecture is mapped from persona/JTBD lenses, with gov.uk/GDS
   research translated into maintainer-facing Rindle surfaces.
3. Motion principles are tied to brand `motion` tokens and remain restrained for an
   operational console.
4. Docker multi-project DX decisions cover `COMPOSE_PROJECT_NAME`, env-driven ports, and
   traefik tradeoffs.
5. CSS architecture is locked: console uses BEM + generated custom properties from
   `brandbook/tokens/tokens.json`; Cohort keeps Tailwind/daisyUI momentum.
6. UI-principles document is linked from `AGENTS.md`.

**Plans:** 3/3 plans complete

Plans:
- [x] 86-01-PLAN.md — Lock mountable console architecture and task-first IA.
- [x] 86-02-PLAN.md — Lock console CSS architecture and operational motion.
- [x] 86-03-PLAN.md — Lock Docker demo DX and link UI principles from `AGENTS.md`.

---

### Phase 87: Docker & Demo DX

**Goal:** Make the demo stack fast and conflict-free before the UI-heavy phases iterate on it.

**Depends on:** Phase 86

**Requirements:** DX-01, DX-02, DX-03

**Success criteria:**

1. Compose stack can run alongside sibling projects via namespacing and env-driven ports.
2. Port conflict guidance is documented with sane defaults.
3. Dockerfile layer cache fetches deps before source COPY.
4. Dev iteration path supports style/template changes without rebuilding deps.
5. Launch flow prints a copy-pasteable URL map for app, admin console, and MinIO console.

**Plans:** 3/3 plans complete

Plans:

**Wave 1**

- [x] 87-01-PLAN.md - Env-driven compose ports and launch URL map.
- [x] 87-02-PLAN.md - Dockerfile dependency-cache ordering.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 87-03-PLAN.md - Docker quick-try and proof-matrix docs.

---

### Phase 88: Admin Design System & UI Kit

**Goal:** Ship the token-generated `rindle-admin` design system and component kit that the
console implementation will use.

**Depends on:** Phase 86 and Phase 87

**Requirements:** DS-01, DS-02, DS-03, ADMIN-02 groundwork

**Success criteria:**

1. `rindle-admin` CSS is generated from `brandbook/tokens/tokens.json` using BEM and CSS
   custom properties.
2. Light/dark/system theme picker is implemented as a first-class component.
3. Core components exist for nav shell, tables, lifecycle-state chips, buttons, confirm
   dialog, drawer, toasts, empty states, and skeletons.
4. Component-gallery screenshot harness exists for maintainer review.
5. Mechanical WCAG AA contrast gate covers console token pairs.
6. Maintainer reviews rendered gallery before later console phases rely on it.

**Plans:** 3/3 plans complete

Plans:

**Wave 1**

- [x] 88-01-PLAN.md — Generate `rindle-admin` CSS and console contrast gates.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 88-02-PLAN.md — Generate component gallery and screenshot/theme harness.

**Wave 3** *(blocked on Waves 1–2 completion)*

- [x] 88-03-PLAN.md — Document design-system operation and run maintainer gallery review.

---

### Phase 89: Console Read Surfaces

**Goal:** Ship the mountable console read experience with safe host integration, self-contained
assets, live updates, and isolated admin queries.

**Depends on:** Phase 88

**Requirements:** ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-05, ADMIN-06

**Success criteria:**

1. Host app mounts the console via router macro with host auth pipeline and `on_mount` hook.
2. Console asset-serving plug is safe by default and self-contained.
3. Home, assets list/detail, upload sessions, variant/job activity, doctor, and runtime status
   read surfaces are available.
4. PubSub live updates use existing `:asset`, `:variant`, and `:upload_session` topics.
5. Queries remain isolated in `Rindle.Admin.Queries`, not added to the public facade.
6. Optional-dependency CI matrix proves `phoenix_live_view` compiles away cleanly when absent.

**Plans:** 7/7 plans complete

Plans:

**Wave 1**

- [x] 89-01-PLAN.md — Mount router macro and safe host-auth boundary.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 89-02-PLAN.md — Package and prove self-contained admin assets.
- [x] 89-03-PLAN.md — Build isolated admin read query boundary.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 89-04-PLAN.md — Implement shell, Home/Status, Assets, and Upload Sessions.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 89-05-PLAN.md — Complete Variants/Jobs, Runtime/Doctor, and Actions read surfaces.

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 89-06-PLAN.md — Add upload-session PubSub broadcasts and invalidation proof.

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 89-07-PLAN.md — Add optional LiveView compile-away CI proof.

---

### Phase 90: Console Ops Actions

**Goal:** Add operational console actions for existing lifecycle capabilities without adding new
lifecycle semantics.

**Depends on:** Phase 89

**Requirements:** ADMIN-04

**Success criteria:**

1. Owner erasure preview/execute and batch erasure are exposed with deliberate destructive UX.
2. Typed confirmation and collateral preview are required for destructive actions.
3. Variant regeneration, quarantine review, and lifecycle repair reuse existing facade
   capabilities.
4. Console actions do not introduce new lifecycle semantics beyond recorded v1.18 scope.

**Plans:** 2/2 plans complete

Plans:

**Wave 1**

- [x] 90-01-PLAN.md — Owner erasure and batch erasure with typed-confirmation destructive UX.
- [x] 90-02-PLAN.md — Variant regeneration, lifecycle repair, and quarantine-review triage.

**Status:** Verified 8/8 must-haves; HUMAN-UAT pending (destructive-action UX review).

---

### Phase 91: Cohort Demo Evolution

**Goal:** Evolve Cohort into the adoption lab that proves the console across branded demo
surfaces, media types, and lifecycle states.

**Depends on:** Phase 90

**Requirements:** DEMO-01, DEMO-02, DEMO-03

**Success criteria:**

1. Cohort gets a lightweight brand distinct from Rindle after a rendered options checkpoint.
2. Demo covers audio and document media profiles.
3. Seeds express every asset, variant, and upload-session lifecycle state, including degraded,
   quarantined, failed, stale, and expired.
4. Cohort mounts the admin console.
5. Click-around walkthrough is documented.

**Plans:** 3/3 plans complete

Plans:

**Wave 1**

- [x] 91-01-PLAN.md — Replace default Phoenix logo with new distinct Cohort brand.
- [x] 91-02-PLAN.md — Define Audio/Document profiles and seed database with lifecycle edge cases.
- [x] 91-03-PLAN.md — Mount Rindle Admin console in Cohort and document walkthrough.

---

### Phase 92: E2E & Screenshot-Driven Polish Loop

**Goal:** Make console behavior and polish deterministic through merge-blocking Playwright and
all-screens screenshot iteration.

**Depends on:** Phase 91

**Requirements:** E2E-01, E2E-02

**Success criteria:**

1. Deterministic Playwright specs cover happy paths, main error cases, boundary conditions,
   theme switching, and destructive flows.
2. Console E2E lane is merge-blocking.
3. Automated screenshot capture covers all screens in light and dark mode.
4. Screenshot analyze-to-fix polish passes are run until visual regressions are resolved.

**Plans:** 5/5 plans complete

Plans:

**Wave 1**

- [x] 92-01-PLAN.md — Create admin E2E helper and stable selector foundation.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 92-02-PLAN.md — Add admin surface, boundary, detail, redaction, and theme specs.
- [x] 92-03-PLAN.md — Add destructive and non-destructive admin action specs.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 92-04-PLAN.md — Add live all-screen screenshots and run screenshot polish iteration.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 92-05-PLAN.md — Wire specs into proof matrix, drift gate, docs, and CI lane truth.

---

### Phase 93: Truth, Docs & Milestone Audit

**Goal:** Close v1.18 with truthful docs, public-surface parity, traceability closure, and a
milestone audit.

**Depends on:** Phase 92

**Requirements:** TRUTH-07

**Success criteria:**

1. `guides/admin_console.md` documents the console accurately.
2. `user_flows` and `JTBD-MAP` reflect the T4 admin UI reversal.
3. `lib/rindle.ex` no longer claims there is no admin UI.
4. README and HexDocs describe the shipped console truthfully.
5. Requirements traceability is closed.
6. v1.18 milestone audit is written.

**Plans:** 4/4 plans complete

Plans:
- [x] 93-01-PLAN.md — Fix facade moduledoc + operations/troubleshooting/user_flows admin-UI denials (F1–F5).
- [x] 93-02-PLAN.md — Reverse JTBD-MAP T4 admin-UI exclusion (idempotent anchor) + close REQUIREMENTS traceability.
- [x] 93-03-PLAN.md — Author guides/admin_console.md, wire into mix.exs extras, add README mention.
- [x] 93-04-PLAN.md — Parity-test lock (Nyquist) + regenerate v1.18 milestone audit + UAT-status checkpoint.

**Audit:** [.planning/milestones/v1.18-MILESTONE-AUDIT.md](milestones/v1.18-MILESTONE-AUDIT.md) — status `tech_debt` (19/19 reqs + 8/8 phases verified; HUMAN-UAT for phase 92 pending before `shipped`).

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 94. Foundation — Token Pipeline CI Gate & New Categories | 2/4 | In Progress|  |
| 95. Admin Level-1 Component Audit [A] | 0/? | Not started | - |
| 96. Cohort Component Layer + Dark/Reduced-Motion [B] | 0/? | Not started | - |
| 97. Admin Level-2 Meta-Components [A] | 0/? | Not started | - |
| 98. Admin Level-3 Pages + Motion/Mobile/A11y/IA/Microcopy [A] | 0/? | Not started | - |
| 99. Cohort Page Migrations (small 7) [B] | 0/? | Not started | - |
| 100. Cohort /upload Migration [B] | 0/? | Not started | - |
| 101. daisyUI Retirement [B] | 0/? | Not started | - |
| 102. Re-Converge — Visual Matrix, Idempotency & Audit | 0/? | Not started | - |

<details>
<summary>✅ b1.0 Brand Foundations (Phases 81–85) — SHIPPED 2026-06-10</summary>

- [x] Phase 81: Brand Audit & Direction Lock (2/2 plans) — completed 2026-06-10
- [x] Phase 82: Logo Candidates & User Selection (2/2 plans) — completed 2026-06-10 (user pick: E Confluence, e1)
- [x] Phase 83: Logo System Refinement (2/2 plans) — completed 2026-06-10
- [x] Phase 84: Design Tokens & HTML Brand Book (3/3 plans) — completed 2026-06-10
- [x] Phase 85: Repo Surface Integration (2/2 plans) — completed 2026-06-10

Full phase details: [.planning/milestones/b1.0-ROADMAP.md](milestones/b1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.17 Adopter-Confidence Hygiene (Phases 78–80) — SHIPPED 2026-05-27</summary>

- [x] Phase 78: Assessment & Planning Truth (2/2 plans) — completed 2026-05-27
- [x] Phase 79: CI Static-Analysis Policy Closure (2/2 plans) — completed 2026-05-27
- [x] Phase 80: Post-Ship Planning Hygiene (2/2 plans) — completed 2026-05-27

Full phase details: [.planning/milestones/v1.17-ROADMAP.md](milestones/v1.17-ROADMAP.md)

</details>

<details>
<summary>✅ v1.16 CI Enforcement & Planning Hygiene (Phases 75–77) — SHIPPED 2026-05-27</summary>

- [x] Phase 77: Planning Artifact Cleanup (3/3 plans) — completed 2026-05-27
- [x] Phase 76: TusPlug Doc Parity Lock (2/2 plans) — completed 2026-05-27
- [x] Phase 75: Merge-Blocking Proof Lanes (5/5 plans) — completed 2026-05-27

Full phase details: [.planning/milestones/v1.16-ROADMAP.md](milestones/v1.16-ROADMAP.md)

</details>

<details>
<summary>✅ v1.15 Maintenance & Proof Honesty (Phases 71–74) — SHIPPED 2026-05-27</summary>

- [x] Phase 71: CI Proof Honesty (2/2 plans) — completed 2026-05-27
- [x] Phase 72: Mix Batch Failure Proof (1/1 plan) — completed 2026-05-27
- [x] Phase 73: Nyquist Validation Closure (4/4 plans) — completed 2026-05-27
- [x] Phase 74: Support Truth & Milestone Audit (2/2 plans) — completed 2026-05-27

Audit: [.planning/milestones/v1.15-MILESTONE-AUDIT.md](milestones/v1.15-MILESTONE-AUDIT.md)

</details>

## Demand-Gated Pause — Superseded for v1.18/v1.19 (2026-06-10 / 2026-06-14)

**Formalized:** 2026-05-27 | **Status:** Overridden by maintainer-pull v1.18 charter
(recorded in PAUSE-03 amendment, `.planning/REQUIREMENTS.md`) and extended by the v1.19
Design-System Stress-Test quality milestone (2026-06-14). The demand gates themselves
remain intact for v1.20+:

- **LIFE-06** — compliance/legal ticket for force-delete shared assets, or
- **STREAM-10** — named adopter for second streaming provider

Pause posture resumes after v1.19 ships unless a new charter exists.
See [post-v116 assessment](threads/2026-05-27-post-v116-milestone-assessment.md).

## Deferred to v1.20+ / Later

- Force-delete semantics for still-shared assets (LIFE-06) — compliance pull only
- Second streaming provider (Cloudflare/Bunny) — explicit adopter demand only
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions
- Signed dynamic image transforms / EXIF privacy stripping

## Archive

- [.planning/milestones/b1.0-ROADMAP.md](milestones/b1.0-ROADMAP.md)
- [.planning/milestones/b1.0-REQUIREMENTS.md](milestones/b1.0-REQUIREMENTS.md)
- [.planning/milestones/b1.0-MILESTONE-AUDIT.md](milestones/b1.0-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.17-ROADMAP.md](milestones/v1.17-ROADMAP.md)
- [.planning/milestones/v1.17-REQUIREMENTS.md](milestones/v1.17-REQUIREMENTS.md)
- [.planning/milestones/v1.17-MILESTONE-AUDIT.md](milestones/v1.17-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.16-ROADMAP.md](milestones/v1.16-ROADMAP.md)
- [.planning/milestones/v1.16-REQUIREMENTS.md](milestones/v1.16-REQUIREMENTS.md)
- [.planning/milestones/v1.15-MILESTONE-AUDIT.md](milestones/v1.15-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.14-ROADMAP.md](milestones/v1.14-ROADMAP.md)
- [.planning/milestones/v1.14-REQUIREMENTS.md](milestones/v1.14-REQUIREMENTS.md)
- [.planning/milestones/v1.14-MILESTONE-AUDIT.md](milestones/v1.14-MILESTONE-AUDIT.md)

---
*Last updated: 2026-06-14 — v1.19 Design-System Stress-Test roadmap added (SEED-002; phases 94–102: foundation token-pipeline CI gate → parallel Track A admin DS uplift + Track B Cohort restyle → re-converge visual matrix; hex 0.3.x target). Opens over un-closed v1.18 (tech_debt, HUMAN-UAT pending) by recorded maintainer decision.*
