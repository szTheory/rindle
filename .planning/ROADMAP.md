# Roadmap: Rindle

## Milestones

- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, see archive)
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28)
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29)
- 🚧 **v1.3 Live Publish & API Ergonomics** — Phases 15–19 (in progress)

## Phases

<details>
<summary>✅ v1.2 First Hex Publish (Phases 10–14) — SHIPPED 2026-04-29</summary>

- [x] Phase 10: Publish Readiness (2/2 plans) — completed 2026-04-28
- [x] Phase 11: Protected Publish Automation (3/3 plans) — completed 2026-04-28
- [x] Phase 12: Public Verification and Release Operations (2/2 plans) — completed 2026-04-28
- [x] Phase 13: Release Traceability and Runbook Alignment (2/2 plans) — completed 2026-04-29
- [x] Phase 14: Validation Closure for Publish Milestone (2/2 plans) — completed 2026-04-29

Full archive: [.planning/milestones/v1.2-ROADMAP.md](.planning/milestones/v1.2-ROADMAP.md)

</details>

<details>
<summary>✅ v1.1 Adopter Hardening (Phases 6–9) — SHIPPED 2026-04-28</summary>

- [x] Phase 6: Adopter Runtime Ownership (3/3 plans) — completed 2026-04-28
- [x] Phase 7: Multipart Uploads (3/3 plans) — completed 2026-04-28
- [x] Phase 8: Storage Capability Confidence (3/3 plans) — completed 2026-04-28
- [x] Phase 9: Install & Release Confidence (3/3 plans) — completed 2026-04-28

Full archive: [.planning/milestones/v1.1-ROADMAP.md](.planning/milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 MVP (Phases 1–5) — SHIPPED</summary>

Full archive: [.planning/milestones/v1.0-ROADMAP.md](.planning/milestones/v1.0-ROADMAP.md)

</details>

### 🚧 v1.3 Live Publish & API Ergonomics (In Progress)

**Milestone Goal:** Execute Rindle's first real Hex.pm publish from the repo workflow and clean up the public API surface before adoption grows.

- [ ] **Phase 15: CI Integrity and Publish Preflight** — Fix any CI failures on the release candidate and verify all preflight gates pass before the live tag is pushed
- [ ] **Phase 16: Live Publish Execution and Post-Publish Verification** — Push v0.1.0 tag to trigger release workflow, confirm package resolves from Hex.pm, and update the routine release runbook
- [ ] **Phase 17: API Surface Boundary Audit** — Apply @moduledoc false/@doc false to all internal modules, resolve naming inconsistencies, and complete breaking-change determination before any documentation additions
- [ ] **Phase 18: Documentation and Typespec Coverage** — Add @doc/@spec to all intentionally public surface and enforce coverage thresholds via mix doctor in CI
- [ ] **Phase 19: Convenience API Additions** — Add helper functions and bang variants that adopters need on the public surface

## Phase Details

### Phase 15: CI Integrity and Publish Preflight
**Goal**: Maintainer can confirm CI is green on the release candidate and all preflight gates pass, so the first live publish has no known failure modes
**Depends on**: Phase 14 (v1.2 complete)
**Requirements**: PUBLISH-01, PUBLISH-02
**Success Criteria** (what must be TRUE):
  1. Maintainer can run the full CI suite against the release candidate commit and see a green result with no failing jobs
  2. Maintainer can inspect package metadata (`:description`, `:licenses`, `:links`), verify a `CHANGELOG.md` with a `0.1.0` entry exists, and confirm the `rindle` package name is available on Hex.pm
  3. Maintainer can run `mix hex.build --unpack` and confirm tarball contents match expectations before any live push
  4. All preflight gates in `scripts/release_preflight.sh` pass on the exact commit to be tagged
**Plans**: 2 plans
Plans:
- [x] 15-01-PLAN.md — Harden shared preflight unpack/changelog contract and close the repo-owned tarball failure path
- [ ] 15-02-PLAN.md — Capture exact-SHA remote CI proof and maintainer release-candidate signoff evidence

### Phase 16: Live Publish Execution and Post-Publish Verification
**Goal**: Maintainer can push a v0.1.0 git tag and have the release workflow publish `rindle 0.1.0` to Hex.pm automatically, and adopters can immediately resolve and browse the published package
**Depends on**: Phase 15
**Requirements**: PUBLISH-03, VERIFY-01, VERIFY-02, RELEASE-01, RELEASE-02
**Success Criteria** (what must be TRUE):
  1. Maintainer pushes a `v0.1.0` git tag and the release workflow completes — `rindle 0.1.0` appears on Hex.pm — with no manual intervention beyond the tag push
  2. Adopter can add `{:rindle, "~> 0.1.0"}` to a fresh Phoenix app's `mix.exs` and have `mix deps.get` resolve from Hex.pm without access to the Rindle source repo
  3. Adopter can browse `hexdocs.pm/rindle` and find module documentation immediately after publish completes
  4. Maintainer can follow a step-by-step runbook for all routine releases after `0.1.0` updated to reflect any observed deviations from the first live publish
  5. Maintainer can execute `mix hex.publish --revert VERSION` within the correction window using documented runbook steps
**Plans**: TBD
**UI hint**: no

### Phase 17: API Surface Boundary Audit
**Goal**: The public-vs-internal boundary is explicitly locked — all internal modules are hidden from documentation, naming inconsistencies are resolved or deferred, and the breaking-change decision is recorded before any @doc additions
**Depends on**: Phase 16
**Requirements**: API-01, API-02, API-03, API-04, API-05
**Success Criteria** (what must be TRUE):
  1. All internal modules (Storage.Local, Storage.S3, Storage.Capabilities internal helpers, Security.*, Profile.Digest, domain FSMs) have `@moduledoc false` or `@doc false` applied and do not appear in ExDoc output
  2. The `verify_upload/2` vs `complete_multipart_upload/3` vocabulary inconsistency is resolved — either renamed to a consistent verb or explicitly documented as distinct operations
  3. `log_variant_processing_failure/3` is either removed from the public `Rindle` facade or annotated `@doc false` with an explicit rationale
  4. Adopter can read consistent module and function names across the public `Rindle` surface with no mismatched verb, noun, or arity patterns
  5. A breaking-change determination document exists — renames affecting published function signatures are either shipped before `0.1.0` or explicitly deferred to `v0.2.0` with a recorded rationale
**Plans**: TBD

### Phase 18: Documentation and Typespec Coverage
**Goal**: Every intentionally public function and module has @doc and @spec annotations, named struct types replace opaque types in all public specs, and CI prevents coverage regressions
**Depends on**: Phase 17
**Requirements**: API-06, API-07, API-08
**Success Criteria** (what must be TRUE):
  1. Adopter can read `@doc` annotations on every intentionally public module, function, and behaviour callback in the `Rindle` surface
  2. Adopter can use Dialyzer with accurate named struct types (`MediaAsset.t()`, `Attachment.t()`, etc.) in `@spec` annotations instead of opaque `map()` or `term()` return types on public functions
  3. `mix doctor --raise` passes in CI and a failing `@doc`/`@spec` addition causes the CI job to exit non-zero
**Plans**: TBD

### Phase 19: Convenience API Additions
**Goal**: Adopters have concise helper functions and bang variants on the public Rindle surface so common operations do not require raw Ecto queries or manual error unwrapping
**Depends on**: Phase 18
**Requirements**: API-09, API-10, API-11
**Success Criteria** (what must be TRUE):
  1. Adopter can call `Rindle.attachment_for(owner, slot)` to fetch an attachment without writing a raw Ecto query
  2. Adopter can call `Rindle.ready_variants_for(asset)` to fetch ready variants without writing a raw Ecto query
  3. Adopter can use bang variants (`attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4`) for happy-path code that prefers exceptions over `{:error, reason}` tuples
  4. All new helper functions and bang variants have `@doc` and `@spec` annotations that pass `mix doctor --raise`
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 10. Publish Readiness | v1.2 | 2/2 | Complete | 2026-04-28 |
| 11. Protected Publish Automation | v1.2 | 3/3 | Complete | 2026-04-28 |
| 12. Public Verification and Release Operations | v1.2 | 2/2 | Complete | 2026-04-28 |
| 13. Release Traceability and Runbook Alignment | v1.2 | 2/2 | Complete | 2026-04-29 |
| 14. Validation Closure for Publish Milestone | v1.2 | 2/2 | Complete | 2026-04-29 |
| 15. CI Integrity and Publish Preflight | v1.3 | 1/2 | In Progress | - |
| 16. Live Publish Execution and Post-Publish Verification | v1.3 | 0/TBD | Not started | - |
| 17. API Surface Boundary Audit | v1.3 | 0/TBD | Not started | - |
| 18. Documentation and Typespec Coverage | v1.3 | 0/TBD | Not started | - |
| 19. Convenience API Additions | v1.3 | 0/TBD | Not started | - |
