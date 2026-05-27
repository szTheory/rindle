# Requirements: Rindle

**Defined:** 2026-05-27
**Milestone:** v1.17 Adopter-Confidence Hygiene
**Core Value:** Media, made durable.

## v1.17 Requirements

Micro milestone (Branch C). No new public API. Execute phases **78 → 79**.

### Support Truth

- [ ] **TRUTH-06**: Post-v116 assessment and path-to-done threads accurately describe CI
  severity — `mix coveralls` merge-blocking, `proof` merge-blocking — with no stale
  "unit tests advisory" or contradictory rough-edge claims; `ci.yml` is cited as source
  of truth.

### Planning Truth

- [ ] **PLAN-02**: JTBD-MAP anchor verified at v1.16 shipped boundary; PROJECT.md, STATE.md,
  and ROADMAP.md reflect v1.17 charter and demand-gated posture for LIFE-06 / STREAM-10.

### CI Policy

- [ ] **CI-04**: Maintainer records an explicit decision on Credo and Dialyzer severity
  (merge-blocking vs advisory); `RUNNING.md` CI matrix and `ci.yml` comments match that
  decision with rationale (fork latency, signal value, or green-main honesty).

## Future Requirements

Deferred to v1.18+ (demand-gated):

- **LIFE-06**: Force-delete policy for assets with surviving attachments
- **STREAM-10**: Second streaming provider as contract test
- **TRANS-01**: Signed dynamic image transforms (job 33)
- **PRIV-01**: EXIF privacy stripping on originals (job 34)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Force-delete (LIFE-06) | Demand-gated; requires compliance charter |
| Second streaming provider (STREAM-10) | Demand-gated; requires named adopter |
| New `lib/` public API | v1.17 is hygiene-only |
| Credo/Dialyzer merge-blocking without explicit decision | Policy must be recorded first (CI-04) |
| Release `gate-ci-green` bypass tightening | Out of scope per RUNNING.md |
| IETF RUFH / tus 2.0 | Long-tail |
| GCS-as-tus-backend | Adopter-request only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRUTH-06 | Phase 78 | Pending |
| PLAN-02 | Phase 78 | Pending |
| CI-04 | Phase 79 | Pending |

**Coverage:**

- v1.17 requirements: 3 total
- Mapped to phases: 3
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after milestone v1.17 roadmap*
