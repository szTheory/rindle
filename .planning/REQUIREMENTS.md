# Requirements: Rindle

**Defined:** 2026-05-27 (v1.19 archived 2026-06-19)
**Milestone:** none active — v1.19 shipped; v1.18 remains tech_debt pending HUMAN-UAT
**Core Value:** Media, made durable.

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
*Last updated: 2026-06-19 — v1.19 requirements were archived complete at
`.planning/milestones/v1.19-REQUIREMENTS.md` after the full wrapper, adoption-demo precommit,
targeted Cohort contract, and two-run idempotency proof passed. Live requirements retain v1.18
tech_debt (HUMAN-UAT pending) plus demand-gated future work. LIFE-06/STREAM-10 remain shifted to
v1.20+.*
