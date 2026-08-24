# Requirements: Rindle v1.25 Maintainer Craft & Feedback Velocity

**Defined:** 2026-08-24
**Core Value:** Media, made durable.
**Status:** Active

## Evidence and Craft

- [x] **CRAFT-01**: Maintainers have a finite inventory of non-Admin quality candidates from strict
  Credo, the curated complexity baseline, planning-provenance scans, mixed-responsibility hotspots,
  source-reading tests, runtime cycles, contributor-command drift, and CI measurements.
- [x] **CRAFT-02**: Every inventoried candidate is fixed, retained, or deferred with a concise
  reader-value rationale; file length, advisory count, and cycle count are never sufficient alone.
- [x] **PROV-01**: Live non-Admin comments, moduledocs, test names, scripts, and workflows contain no
  unreviewed Phase/Plan/internal decision markers.
- [x] **PROV-02**: Retained prose explains a current invariant, safety constraint, compatibility
  boundary, or failure behavior; no subjective AI-phrase detector becomes a permanent gate.

## Behavioral Test Ownership

- [x] **TEST-05**: Runtime-check tests are organized into core/ownership/migration, GCS/configuration,
  and orchestration contracts while existing focused streaming coverage remains intact.
- [x] **TEST-06**: Upload-maintenance tests separate orphan cleanup, standard/GCS abort behavior, and
  tus retry/reaper behavior with explicit fixture ownership and unchanged async safety.
- [x] **TEST-07**: Private-layout source snapshots are replaced by behavior, compiled metadata,
  structured parsing, or executable fixtures; narrow shipped-artifact contracts remain documented.

## Maintainability

- [x] **MAINT-01**: Optional Mux and GCS runtime diagnostics have hidden cohesive owners while check
  order, IDs, result shapes, injected seams, telemetry, and error vocabulary remain unchanged.
- [x] **MAINT-02**: The four normalized complexity/nesting findings owned by the mixed integration
  module are removed without replacement; the exact curated baseline decreases from 35 to at most 31.
- [x] **MAINT-03**: No compile-connected cycle is introduced. Schema associations are retained, and
  the facade/worker plus provider-configuration runtime cycles stay deferred absent concrete harm.
- [x] **DX-04**: Contributors have one current change-to-proof map with focused commands, integration
  boundaries, package-consumer profiles, and SAFE-01 ownership; docs, aliases, and CI agree.

## CI Feedback

- [x] **CI-10**: Merge-blocking coverage runs exactly once through `coveralls.multiple` with local and
  JSON analyzers and without `--slowest` trace serialization; JUnit and coverage artifacts remain.
- [x] **CI-11**: Required image-only PR consumer proof and the complete main/release five-profile proof
  retain their built-package installation, migration, boot, lifecycle, and report assertions.
- [x] **CI-12**: Image consumer proof starts independently of Quality, retains `CI Summary` gating,
  and removes unused Node/FFmpeg setup plus the redundant development-environment compile.
- [x] **CI-13**: Generated-app entry scripts install one centrally owned Phoenix generator version and
  prove cold installation, matching-version reuse, and actionable mismatch behavior.
- [ ] **CI-14**: Ten consecutive comparable non-cancelled PR runs achieve <=8 minutes median and <=10
  minutes p95 without weaker gates or newly introduced reruns. External-runner exceptions require
  job-level evidence, a named owner, and a dated follow-up.

## Preservation

- [x] **COV-05**: Authoritative coverage remains at or above 82.13%; tests are not added only to raise
  the percentage.
- [x] **SAFE-02**: Each implementation slice passes focused proof, `mix quality_signals`, SAFE-01, and
  its relevant integration/package lane without Admin, public API, schema/migration, telemetry/error,
  dependency-set, or release-proof drift.

## Out of Scope

| Item | Reason |
|------|--------|
| Admin/operator UI or adoption-demo visual work | The maintainer explicitly excluded it. |
| Public API, schema/migration, telemetry, or error redesign | This is behavior-preserving maintenance. |
| Broad dependency/toolchain upgrades | Requires a separate risk-ranked milestone. |
| Historical planning archives | They are durable provenance. |
| Blanket style/alias cleanup or coverage pursuit | Subjective or metric-only churn is not reader value. |
| Test partitioning or cache-topology redesign | Existing evidence does not justify the complexity. |
| Runtime-cycle extraction by graph count alone | No current compile or change-cost harm is demonstrated. |
| Forced package release | The milestone does not imply a Hex version bump. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CRAFT-01, CRAFT-02 | 127 | Verified |
| PROV-01, PROV-02 | 128 | Verified |
| TEST-05, TEST-06, TEST-07 | 129 | Verified |
| MAINT-01, MAINT-02, MAINT-03 | 130 | Verified |
| DX-04, CI-10, CI-11, CI-12, CI-13 | 131 | Verified |
| CI-14, COV-05, SAFE-02 | 132 | In progress — COV-05 and SAFE-02 verified; CI-14 awaits PR runs |

**Coverage:** 18 requirements; 18 mapped; 0 unmapped.

---
*Last updated: 2026-08-24 — 17/18 requirements verified; CI-14 timing receipt open.*
