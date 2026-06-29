# Requirements: Rindle — v1.22 OSS Quality & Trust Hardening

**Defined:** 2026-06-29
**Core Value:** Media, made durable.
**Charter:** SEED-005 (software-quality consolidation arc). Non-feature/DX milestone; ships a 0.3.x minor
(0.4.0 reserved for v1.23's breaking schema isolation). Low risk, no breaking change. Also lays the
versioned `Rindle.Migration` substrate v1.23 builds the schema prefix onto.

## Milestone v1.22 Requirements

Each maps to exactly one roadmap phase (phases begin at 113).

### Evaluation Baseline (EVAL)

- [ ] **EVAL-01**: Maintainer can read a concise, evidence-cited scored-weakness summary of Rindle's OSS
  quality (the milestone's opening artifact) — the sharpened 2026-06-29 recon naming weak dimensions
  (governance/trust, versioning/positioning, host-app respectfulness) vs. already-strong ones (telemetry,
  docs IA, public API, CI/testing). Right-sized; not the full 36-dimension report.

### OSS Trust & Governance (TRUST)

- [ ] **TRUST-01**: Repo has a `SECURITY.md` with a vulnerability-disclosure policy appropriate for a
  library handling untrusted uploads, MIME sniffing, signed delivery, and webhook HMAC verification.
- [ ] **TRUST-02**: Repo has a `CODE_OF_CONDUCT.md`.
- [ ] **TRUST-03**: Repo has issue templates (`.github/ISSUE_TEMPLATE/`) and a `PULL_REQUEST_TEMPLATE.md`
  that guide a good bug report / feature proposal / PR (the existing CONTRIBUTING is CI-only — these add
  the newcomer on-ramp).

### Hex Package Metadata (META)

- [ ] **META-01**: Hex `package.links` exposes "Changelog" and "Docs" entries (HexDocs convention, surfaced
  on hex.pm) alongside the existing GitHub link.
- [ ] **META-02**: Hex `package` declares `maintainers`.

### Versioning & Stability (VERSION)

- [ ] **VERSION-01**: README and CONTRIBUTING state the SemVer / pre-1.0 stability contract — "0.x: API may
  change between minor versions; see CHANGELOG" — and a short note on what 1.0 will mean.
- [ ] **VERSION-02**: `guides/upgrading.md` is generalized into a reusable upgrade-notes structure (versioned
  sections), not just the single pre-0.1.4 image-only→AV case, so every future change has a documented home.

### README Positioning (README)

- [ ] **README-01**: README leads with an image-only "first attachment in ~2 minutes" path that needs no
  FFmpeg/libvips; the heavier AV quickstart is demoted below it.
- [ ] **README-02**: README has a clear "what Rindle is NOT / when not to use it" block (lift the existing
  copy from `guides/user_flows.md`).

### Versioned Migration Module (MIGRATE)

- [ ] **MIGRATE-01**: Adopters install Rindle's tables via a versioned, idempotent `Rindle.Migration.up/1`
  + `down/1` module (Oban-style), replacing the raw 15-file `Ecto.Migrator` copy-paste install path; README,
  getting-started, and upgrading docs updated to the new 3-line migration. Non-breaking — default schema
  stays `public`; existing adopters' already-applied migrations remain valid.
- [ ] **MIGRATE-02**: Rindle no longer creates the shared `oban_jobs` table on the adopter's behalf; the
  adopter owns `Oban.Migration`, documented in install/upgrade guides. (Removes the latent host-Oban collision.)

### Release & Planning Hygiene (HYGIENE)

- [ ] **HYGIENE-01**: The stuck Hex 0.3.2 release is cut so the merged-but-unreleased v1.21 `lib/` fixes
  (`:epipe` absorb, `$callers` config override) reach adopters; PROJECT.md / MILESTONES reconcile the prior
  "ships as Hex 0.3.2" claim with reality.
- [ ] **HYGIENE-02**: Stale `status: open` frontmatter on SEED-003 / SEED-004 is corrected to `consumed`
  (they shipped as v1.20 / v1.21).

## Future Requirements (v1.23 — Postgres Schema Isolation, breaking → 0.4.0)

Deferred to the next milestone; tracked but not in this roadmap.

### Schema Isolation (ISO23)

- **ISO23-01**: `rindle` Postgres schema is the default via config-driven `@schema_prefix` (`use
  Rindle.Schema` macro over the 6 domain modules); `prefix: "public"` is the one-line opt-out.
- **ISO23-02**: The 4 manual escapes are handled — raw-SQL `runtime_checks.ex` (2 sites) and Oban-binding
  queries (2 sites) — so health checks resolve in the right schema and `oban_jobs` is not contaminated.
- **ISO23-03**: Documented breaking-upgrade path — `prefix: "public"` opt-out + `ALTER TABLE … SET SCHEMA`
  move migration; ships 0.4.0 with a release-please breaking-change note.
- **ISO23-04**: Isolation proof — suite green under default `prefix: "rindle"`; a tagged lane proves rows
  land in the prefix and `oban_jobs` stays in `public`; demo app provisions end-to-end into `rindle`.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full 36-dimension scored quality report | Replaced by the right-sized EVAL-01 summary; recon already found the weak dimensions with high confidence |
| szTheory peer-dep bumps | Rindle depends on zero szTheory-owned packages — empty workstream (recon-confirmed) |
| CI/CD performance milestone | Already delivered by v1.20 (SEED-003) + v1.21 (SEED-004); the pasted audit is SEED-003 |
| `mix test --partitions` parallelization | Deliberately evidence-gated on a measured core-starvation showing (DEFER-02) |
| Breaking schema-default flip to `rindle` | That is v1.23 (0.4.0); v1.22 stays non-breaking and ships the migration substrate only |
| New media features (LIFE-06 force-delete, STREAM-10 second provider) | Demand-gated; this arc is non-feature hardening |
| Sibling-lib adoption (e.g. `oban_powertools`) | Separate future question, not this arc |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EVAL-01 | Phase 113 | Pending |
| HYGIENE-01 | Phase 113 | Pending |
| HYGIENE-02 | Phase 113 | Pending |
| TRUST-01 | Phase 114 | Pending |
| TRUST-02 | Phase 114 | Pending |
| TRUST-03 | Phase 114 | Pending |
| META-01 | Phase 114 | Pending |
| META-02 | Phase 114 | Pending |
| VERSION-01 | Phase 115 | Pending |
| VERSION-02 | Phase 115 | Pending |
| README-01 | Phase 115 | Pending |
| README-02 | Phase 115 | Pending |
| MIGRATE-01 | Phase 116 | Pending |
| MIGRATE-02 | Phase 116 | Pending |

**Coverage:**
- v1.22 requirements: 14 total
- Mapped to phases: 14 ✓
- Unmapped: 0

**Phase distribution:**
- Phase 113 (Evaluation Baseline & Release Hygiene): EVAL-01, HYGIENE-01, HYGIENE-02 (3)
- Phase 114 (OSS Trust & Governance): TRUST-01, TRUST-02, TRUST-03, META-01, META-02 (5)
- Phase 115 (Versioning & README Positioning): VERSION-01, VERSION-02, README-01, README-02 (4)
- Phase 116 (Versioned `Rindle.Migration` Module): MIGRATE-01, MIGRATE-02 (2)

---
*Requirements defined: 2026-06-29*
*Last updated: 2026-06-29 — roadmap created; all 14 v1.22 requirements mapped to Phases 113–116 (100% coverage)*
