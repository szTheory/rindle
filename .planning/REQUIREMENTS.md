# Requirements: Rindle

**Defined:** 2026-05-27 (v1.19 archived 2026-06-19)
**Milestone:** none active — v1.18 + v1.19 both shipped & archived; next is /gsd-new-milestone
**Core Value:** Media, made durable.

## v1.18 Admin Console & Adoption Lab — ✅ SHIPPED 2026-06-20 (archived)

All 19 requirements (`ADMIN-01..06`, `DS-01..03`, `DEMO-01..03`, `E2E-01..02`, `DX-01..03`,
`PRIN-01`, `TRUTH-07`) satisfied across phases 86–93; HUMAN-UAT for phases 90/91/92 signed off
2026-06-20. Full requirement text + traceability archived to
[`milestones/v1.18-REQUIREMENTS.md`](milestones/v1.18-REQUIREMENTS.md).

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

### v1.18 Admin Console & Adoption Lab (phases 86–93) — ✅ shipped, archived

Full 19-row traceability lives in
[`milestones/v1.18-REQUIREMENTS.md`](milestones/v1.18-REQUIREMENTS.md). 19/19 Complete/Satisfied;
HUMAN-UAT for phases 90/91/92 signed off 2026-06-20. Carried-forward deferrals remain live:

| Requirement | Phase | Status |
|-------------|-------|--------|
| PAUSE-01/02/03 | — | Satisfied (PAUSE-03 amended/extended) |
| LIFE-06-* / STREAM-10-* | v1.20+ (on signal) | Deferred |
| TRANS-01 / PRIV-01 | — | Deferred |

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-06-20 — v1.18 closed `shipped` after maintainer HUMAN-UAT sign-off
(phases 90/91/92); requirements archived to `milestones/v1.18-REQUIREMENTS.md`. v1.19 archived
2026-06-19. No active milestone — next milestone seeds a fresh requirements set. LIFE-06/STREAM-10
remain shifted to v1.20+.*
