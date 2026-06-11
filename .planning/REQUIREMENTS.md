# Requirements: Rindle

**Defined:** 2026-05-27 (v1.18 charter added 2026-06-10)
**Milestone:** v1.18 Admin Console & Adoption Lab (maintainer-pull override of pause; hex 0.3.0)
**Core Value:** Media, made durable.

## v1.18 Admin Console & Adoption Lab (active)

**Charter (2026-06-10):** Maintainer-pull feature milestone, explicitly overriding the
PAUSE-03 reservation of v1.18+ for LIFE-06/STREAM-10. Those two gates remain demand-only
and move to v1.19+. This milestone reverses the prior "admin UI out of scope" decision
(JTBD T4) as a recorded scope change: a mountable, Rindle-branded admin console ships in
the `rindle` package, proven through the Cohort demo with full lifecycle-state seed
coverage, deterministic E2E, and Docker DX fixes.

### Admin Console (ADMIN)

- [ ] **ADMIN-01**: Host app mounts the console via a router macro with a host-supplied
  auth pipeline + `on_mount` hook; safe-by-default (refuses unauthenticated mount outside dev).
- [ ] **ADMIN-02**: Console ships fully self-contained precompiled assets (CSS/JS) — zero
  host asset-pipeline or Tailwind dependency; assets served by the library.
- [ ] **ADMIN-03**: Read surfaces — task-oriented home, assets list filterable by FSM state,
  asset detail (state timeline, variants, attachments), upload sessions, variant/job
  activity, doctor + runtime status.
- [ ] **ADMIN-04**: Ops actions — owner erasure preview/execute and batch erasure with
  deliberate destructive-action UX (typed confirmation, collateral preview), variant
  regeneration, quarantine review, lifecycle repair.
- [ ] **ADMIN-05**: Live updates via existing pubsub topics (`:asset`, `:variant`,
  `:upload_session`); queries isolated in `Rindle.Admin.Queries`, not the public facade.
- [ ] **ADMIN-06**: `phoenix_live_view` stays optional — console compiles away cleanly
  when absent (extends the `Code.ensure_loaded?` gating pattern); optional-dep matrix in CI.

### Design System (DS)

- [ ] **DS-01**: `rindle-admin` design system generated from `brandbook/tokens/tokens.json`
  (BEM + CSS custom properties); components rolled into the system, no one-off styles.
- [ ] **DS-02**: Light/dark/system theme picker as a first-class component
  (`data-theme` + `prefers-color-scheme`).
- [ ] **DS-03**: Mechanical WCAG AA contrast gate over console token pairs
  (reuse `brandbook/src/contrast.mjs` pattern).

### Demo / Adoption Evidence (DEMO)

- [ ] **DEMO-01**: Cohort gets its own lightweight brand, distinct from Rindle
  (rendered options checkpoint for maintainer pick; replaces Phoenix firebird placeholder).
- [ ] **DEMO-02**: Cohort exercises audio + document media types, and seeds express every
  asset/variant/session lifecycle state (incl. degraded, quarantined, failed, stale, expired).
- [ ] **DEMO-03**: Cohort mounts the admin console; click-around walkthrough documented.

### E2E / Shift-Left (E2E)

- [ ] **E2E-01**: Deterministic Playwright specs for the console (happy paths, main error
  cases, boundary conditions, theme switching, destructive flows) in a merge-blocking CI lane.
- [ ] **E2E-02**: Automated all-screens × light/dark screenshot capture feeding
  analyze→fix polish iteration passes.

### Docker DX (DX)

- [ ] **DX-01**: Compose stack is port-conflict-free alongside sibling projects
  (project namespacing + env-driven ports with sane defaults and conflict guidance).
- [ ] **DX-02**: Dockerfile layer caching fixed (deps fetched before source COPY) and a
  dev iteration path where style/template changes don't rebuild deps.
- [ ] **DX-03**: Launch prints a copy-pasteable URL map (app, admin console, MinIO console).

### Principles & Truth (PRIN / TRUTH)

- [ ] **PRIN-01**: Durable UI-principles doc (design-system values, audit checklist,
  deterministic-E2E rules) linked from `AGENTS.md` so future UI work never regresses.
- [ ] **TRUTH-07**: Docs/facade parity for the scope reversal — `lib/rindle.ex` facade
  contract, `guides/`, JTBD-MAP T4 row, and README updated truthfully.

## Pause Posture Requirements (superseded for v1.18 duration)

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
  feature milestone (Admin Console & Adoption Lab). LIFE-06/STREAM-10 stay demand-gated
  and shift to v1.19+. Pause posture resumes after v1.18 unless a new charter exists.*

## Shipped Non-Feature Tracks

- **b1.0 Brand Foundations** (2026-06-10): BRAND-01..08 validated 8/8 — archived at
  `.planning/milestones/b1.0-REQUIREMENTS.md` ([audit](milestones/b1.0-MILESTONE-AUDIT.md)).

## Future Requirements (demand-gated)

Open only via `/gsd-new-milestone` with documented signal:

*(v1.19+ — shifted from v1.18 by the 2026-06-10 maintainer-pull override.)*

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
| Website / domain / hosted landing page | b1.0 is repo-artifact only |
| Trademark/legal clearance for "Rindle" | Human-review item only (BRAND-01 flags it; no legal work in milestone) |
| Force-delete (LIFE-06) | Demand-gated; requires compliance charter (v1.19+) |
| Second streaming provider (STREAM-10) | Demand-gated; requires named adopter (v1.19+) |
| IETF RUFH / tus 2.0 | Long-tail |
| GCS-as-tus-backend | Adopter-request only |
| Standalone tus JS client package | Out of scope |
| Platform scope (DRM, HLS platform, CDN replacement) | Not a lifecycle library |
| Console write paths beyond existing facade capabilities | v1.18 console surfaces existing operations only; no new lifecycle semantics |
| Console i18n / multi-tenancy / RBAC beyond host auth hook | Host-app concerns; ADMIN-01 delegates auth wholesale |

*Removed from this table 2026-06-10:* "admin UI" (now scoped, ADMIN-01..06) and
"`examples/adoption_demo` re-theming" (now scoped, DEMO-01) — v1.18 charter; "feature
milestone without signal" row superseded by the recorded PAUSE-03 override.

## Traceability

v1.18 Admin Console & Adoption Lab (phases 86–93; b1.0 brand-track rows archived).

| Requirement | Phase | Status |
|-------------|-------|--------|
| ADMIN-01 | Phase 89 | Planned |
| ADMIN-02 | Phase 88–89 | Planned |
| ADMIN-03 | Phase 89 | Planned |
| ADMIN-04 | Phase 90 | Planned |
| ADMIN-05 | Phase 89 | Planned |
| ADMIN-06 | Phase 89 | Planned |
| DS-01 | Phase 88 | Planned |
| DS-02 | Phase 88 | Planned |
| DS-03 | Phase 88 | Planned |
| DEMO-01 | Phase 91 | Planned |
| DEMO-02 | Phase 91 | Planned |
| DEMO-03 | Phase 91 | Planned |
| E2E-01 | Phase 92 | Planned |
| E2E-02 | Phase 92 | Planned |
| DX-01 | Phase 87 | Planned |
| DX-02 | Phase 87 | Planned |
| DX-03 | Phase 87 | Planned |
| PRIN-01 | Phase 86 | Planned |
| TRUTH-07 | Phase 93 | Planned |
| PAUSE-01 | — | Satisfied (maintenance mode, pre-v1.18) |
| PAUSE-02 | — | Satisfied (threads canonical) |
| PAUSE-03 | — | Satisfied; amended 2026-06-10 (maintainer-pull override for v1.18) |
| LIFE-06-* | v1.19+ (on signal) | Deferred |
| STREAM-10-* | v1.19+ (on signal) | Deferred |
| TRANS-01 | — | Deferred |
| PRIV-01 | — | Deferred |

**Coverage:**
- v1.18 requirements: 19 total, 19 mapped to phases 86–93, 0 satisfied (charter stage)
- Pause requirements: 3 total (PAUSE-03 amended for the override)
- Brand-track requirements: 8/8 validated and archived (b1.0)
- Unmapped active reqs: 0

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-06-10 — v1.18 Admin Console & Adoption Lab charter recorded (maintainer-pull override); LIFE-06/STREAM-10 shift to v1.19+*
