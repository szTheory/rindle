# Requirements: Rindle

**Defined:** 2026-05-27
**Milestone:** Demand-gated pause (no feature charter; b1.0 brand track shipped 2026-06-10)
**Core Value:** Media, made durable.

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

## Shipped Non-Feature Tracks

- **b1.0 Brand Foundations** (2026-06-10): BRAND-01..08 validated 8/8 — archived at
  `.planning/milestones/b1.0-REQUIREMENTS.md` ([audit](milestones/b1.0-MILESTONE-AUDIT.md)).

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

No feature phases during demand-gated pause. (b1.0 brand-track rows archived.)

| Requirement | Phase | Status |
|-------------|-------|--------|
| PAUSE-01 | — | Satisfied (maintenance mode) |
| PAUSE-02 | — | Satisfied (threads canonical) |
| PAUSE-03 | — | Satisfied (2026-05-27 formalization) |
| LIFE-06-* | v1.18+ (on signal) | Deferred |
| STREAM-10-* | v1.18+ (on signal) | Deferred |
| TRANS-01 | — | Deferred |
| PRIV-01 | — | Deferred |

**Coverage:**
- Pause requirements: 3 total (documentation/posture)
- Brand-track requirements: 8/8 validated and archived (b1.0)
- Feature requirements: 0 active phases
- Unmapped feature reqs: N/A until demand signal

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-06-10 — b1.0 Brand Foundations shipped and archived; pause posture resumes*
