# Requirements: Rindle

**Defined:** 2026-05-27 (b1.0 brand track added 2026-06-10)
**Milestone:** b1.0 Brand Foundations (brand track — feature pause remains active)
**Core Value:** Media, made durable.

> b1.0 is a non-feature brand-track milestone. Zero public API, zero `lib/` changes.
> The demand-gated pause for feature work (PAUSE-01..03) remains active; v1.18+ remains
> reserved for LIFE-06/STREAM-10.

## Pause Posture Requirements

No feature phases. These document maintainer obligations during maintenance mode.

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

## b1.0 Brand Track Requirements

### Brand Audit

- [ ] **BRAND-01**: Maintainer pressure-tests `prompts/rindle-brand-book.md` with
  KEEP/TIGHTEN/REWORK/ADD/REMOVE verdicts across ten lenses (distinctiveness, dev
  credibility, Elixir ecosystem fit, graphic design quality, UI/UX buildout,
  accessibility, voice/microcopy, marketing, artifact readiness, naming/legal posture);
  every major seed section receives a verdict with rationale.
- [ ] **BRAND-02**: One locked brand direction exists — final palette, type stack, voice
  posture, and the adoption-demo placeholder-logo conflict resolved — with every seed
  revision justified by a named audit-lens failure.

### Logo System

- [ ] **BRAND-03**: User selects the logo direction from 4–6 committed, genuinely distinct
  SVG candidates (≥2 integrated custom typemarks; no background containers; tight
  logotype; no subtitle on main lockups) presented via a visual sheet at an
  execute-phase checkpoint; selection recorded as a decision.
- [ ] **BRAND-04**: Winning direction is refined into a full system — primary lockup,
  icon-only mark, monochrome, dark/light treatments, favicon, social avatar,
  with-subtitle variant — all valid standalone SVGs honoring the hard constraints,
  icon legible at 16px.

### Tokens & Brand Book

- [ ] **BRAND-05**: `brandbook/tokens/tokens.json` + `tokens.css` define raw values,
  semantic roles, interaction states, dark-mode set, and focus spec; WCAG AA contrast
  is programmatically verified with a passing run.
- [ ] **BRAND-06**: A professional, self-contained, build-free static HTML brand book in
  `brandbook/` covers brand DNA, logo usage/misuse, color, typography, iconography,
  imagery, voice/microcopy, marketing copy bank, component examples, and do/don'ts,
  embedding the committed SVGs and tokens.
- [ ] **BRAND-07**: Repo hygiene holds — everything self-contained under `brandbook/`,
  SVG/text-first, raster only where a surface requires it, total ≤ 1.5 MB, no
  build-system dependencies — enforced by a check script.

### Integration (separable)

- [ ] **BRAND-08**: Logo/favicon wired into ex_doc config in `mix.exs`, README header
  lockup (light/dark aware), and a regenerable 1280×640 GitHub social preview — with
  `mix docs` and existing proof lanes green and zero `lib/` changes.

## Future Requirements (demand-gated)

Open only via `/gsd-new-milestone` with documented signal:

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
| Feature milestone without LIFE-06 / STREAM-10 signal | `block_feature_milestone_without_signal` |
| Website / domain / hosted landing page | b1.0 is repo-artifact only |
| Trademark/legal clearance for "Rindle" | Human-review item only (BRAND-01 flags it; no legal work in milestone) |
| Icon set / illustration library / motion implementation | Guidance only in brand book; assets deferred |
| `examples/adoption_demo` re-theming | Follow-up; only the placeholder-logo *decision* is in scope (BRAND-02) |
| Force-delete (LIFE-06) | Demand-gated; requires compliance charter |
| Second streaming provider (STREAM-10) | Demand-gated; requires named adopter |
| IETF RUFH / tus 2.0 | Long-tail |
| GCS-as-tus-backend | Adopter-request only |
| Standalone tus JS client package | Out of scope |
| Platform scope (DRM, HLS platform, admin UI) | Not a lifecycle library |

## Traceability

No feature phases during demand-gated pause. Brand-track phases 81–85 are non-feature.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PAUSE-01 | — | Satisfied (maintenance mode) |
| PAUSE-02 | — | Satisfied (threads canonical) |
| PAUSE-03 | — | Satisfied (2026-05-27 formalization) |
| BRAND-01 | Phase 81 | Pending |
| BRAND-02 | Phase 81 | Pending |
| BRAND-03 | Phase 82 | Pending |
| BRAND-04 | Phase 83 | Pending |
| BRAND-05 | Phase 84 | Pending |
| BRAND-06 | Phase 84 | Pending |
| BRAND-07 | Phase 84 | Pending |
| BRAND-08 | Phase 85 | Pending (separable) |
| LIFE-06-* | v1.18+ (on signal) | Deferred |
| STREAM-10-* | v1.18+ (on signal) | Deferred |
| TRANS-01 | — | Deferred |
| PRIV-01 | — | Deferred |

**Coverage:**
- Pause requirements: 3 total (documentation/posture)
- Brand-track requirements: 8 total, 8 mapped to phases 81–85, 0 unmapped
- Feature requirements: 0 active phases
- Unmapped feature reqs: N/A until demand signal

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-06-10 — b1.0 Brand Foundations charter (non-feature brand track)*
