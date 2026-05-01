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

**Milestone Goal:** Close the real Hex.pm publish loop around the already-shipped `0.1.4` release flow, then clean up the public API surface before adoption grows.

- [x] **Phase 15: CI Integrity and Publish Preflight** — Capture exact-SHA remote proof and maintainer signoff for the shipped publish candidate
- [ ] **Phase 16: Live Publish Execution and Post-Publish Verification** — Close the remaining publish gaps after `0.1.4`: idempotent recovery reruns, revert rehearsal evidence, and runbook deviation capture
- [x] **Phase 17: API Surface Boundary Audit** — Apply @moduledoc false/@doc false to all internal modules, resolve naming inconsistencies, and complete breaking-change determination before any documentation additions
- [ ] **Phase 18: Documentation and Typespec Coverage** — Add @doc/@spec to all intentionally public surface and enforce coverage thresholds via mix doctor in CI
- [x] **Phase 19: Convenience API Additions** — Add helper functions and bang variants that adopters need on the public surface
- [x] **Phase 20: v1.3 Verification & Metadata Closure** — Produce missing VERIFICATION.md artifacts for Phases 15 and 16, reconcile SUMMARY/REQUIREMENTS metadata, commit Phase 17 LiveView corrective patch, and teach Phase 19 helpers in onboarding prose
- [ ] **Phase 21: VERIFY-02 hexdocs.pm Reachability Probe** — Add a first-party HTTP probe of `https://hexdocs.pm/rindle/<version>` to the post-publish public_verify job and a parity assertion test
- [ ] **Phase 22: LiveView Corrective Fixes** — Address CR-01/CR-02/WR-01..WR-05 + WR-04 onboarding nil-deref from Phase 20 code review

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
- [x] 15-02-PLAN.md — Capture exact-SHA remote CI proof and maintainer release-candidate signoff evidence

### Phase 16: Live Publish Execution and Post-Publish Verification
**Goal**: Maintainer can recover and verify the already-shipped `0.1.4` publish path without republishing, prove adopters can resolve the public package, and update the release runbook around the real deviations observed during the first publish window
**Depends on**: Phase 15
**Requirements**: PUBLISH-03, VERIFY-01, VERIFY-02, RELEASE-01, RELEASE-02
**Success Criteria** (what must be TRUE):
  1. Maintainer can rerun the recovery path against an exact immutable ref and see the workflow skip publish safely when that version is already live on Hex.pm
  2. Adopter can add `{:rindle, "~> 0.1.0"}` to a fresh Phoenix app's `mix.exs` and have `mix deps.get` resolve from the already-published Hex.pm package without access to the Rindle source repo
  3. Adopter can browse `hexdocs.pm/rindle` and find module documentation for the public package immediately after publish verification completes
  4. Maintainer can follow a step-by-step runbook for all routine releases after the first publish window, updated to reflect the observed deviations from `0.1.0` through `0.1.4`
  5. Maintainer can execute `mix hex.publish --revert VERSION` within the correction window using documented runbook steps
**Plans**: 2 plans
Plans:
- [x] 16-01-PLAN.md — Add the Hex.pm idempotency probe and its shimmed unit-test harness
- [x] 16-02-PLAN.md — Wire the probe into `release.yml` and align workflow/runbook parity around skip-on-rerun behavior
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
**Plans**: 5 plans
Plans:
- [x] 17-01-PLAN.md — Create the Wave 0 boundary-audit and facade-first docs parity harness
- [x] 17-02-PLAN.md — Hide internal infrastructure/helper modules and define ExDoc public module tiers
- [x] 17-03-PLAN.md — Hide domain FSM and stale-policy internals while preserving public schema data types
- [x] 17-04-PLAN.md — Add facade naming/logging compatibility shims, rewrite onboarding docs, and record the semver decision
- [x] 17-05-PLAN.md — Hide internal ops modules and pipeline workers while preserving supported operational entrypoints

### Phase 18: Documentation and Typespec Coverage
**Goal**: Every intentionally public function and module has @doc and @spec annotations, named struct types replace opaque types in all public specs, and CI prevents coverage regressions
**Depends on**: Phase 17
**Requirements**: API-06, API-07, API-08
**Success Criteria** (what must be TRUE):
  1. Adopter can read `@doc` annotations on every intentionally public module, function, and behaviour callback in the `Rindle` surface
  2. Adopter can use Dialyzer with accurate named struct types (`MediaAsset.t()`, `Attachment.t()`, etc.) in `@spec` annotations instead of opaque `map()` or `term()` return types on public functions
  3. `mix doctor --raise` passes in CI and a failing `@doc`/`@spec` addition causes the CI job to exit non-zero
**Plans**: 5 plans
Plans:
- [x] 18-01-PLAN.md — Add :doctor dep, baseline .doctor.exs, CI step, and the failing doctor_thresholds_test.exs ratchet harness (RED-only)
- [x] 18-02-PLAN.md — Tighten Rindle facade @specs to schema struct types; declare named result types on Rindle.Storage and Rindle.Upload.Broker (D-03/D-04/D-05)
- [x] 18-03-PLAN.md — Add @doc to all 5 behaviour modules' @callbacks; add 6 missing @specs to Broker; promote Rindle.Processor.Image to public adapter (D-27); ship behaviour_docs_test.exs backstop
- [x] 18-04-PLAN.md — Add @doc/@spec to Profile macro and HTML helper; narrow worker @specs; add @deprecated to facade shim; verify Mix tasks; add README callback-doc convention note
- [x] 18-05-PLAN.md — Ratchet .doctor.exs to D-07 target (100/100/100/95/95); turn doctor_thresholds_test green; CHANGELOG entry; manual failing-doc regression probe; optional D-21 callback summaries

### Phase 19: Convenience API Additions
**Goal**: Adopters have concise helper functions and bang variants on the public Rindle surface so common operations do not require raw Ecto queries or manual error unwrapping
**Depends on**: Phase 18
**Requirements**: API-09, API-10, API-11
**Success Criteria** (what must be TRUE):
  1. Adopter can call `Rindle.attachment_for(owner, slot)` to fetch an attachment without writing a raw Ecto query
  2. Adopter can call `Rindle.ready_variants_for(asset)` to fetch ready variants without writing a raw Ecto query
  3. Adopter can use bang variants (`attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4`) for happy-path code that prefers exceptions over `{:error, reason}` tuples
  4. All new helper functions and bang variants have `@doc` and `@spec` annotations that pass `mix doctor --raise`
**Plans**:
- [x] 19-01-PLAN.md — RED test harness for convenience API + boundary allowlist for Rindle.Error (22 failing tests, 9 describe blocks)
- [x] 19-02-PLAN.md — GREEN implementation: Rindle.Error module + 8 facade functions (attachment_for/2,3, ready_variants_for/1, attach!/4, detach!/3, upload!/3, url!/3, variant_url!/4); mix.exs Facade group + CHANGELOG entry

### Phase 20: v1.3 Verification & Metadata Closure
**Goal**: All v1.3 phases have the verification artifacts and SUMMARY/REQUIREMENTS metadata required for `/gsd-audit-milestone v1.3` to report `passed`, residual Phase 17 LiveView corrections are committed, and Phase 19 helpers are taught in onboarding prose
**Depends on**: Phase 19
**Requirements**: PUBLISH-01, PUBLISH-02, PUBLISH-03, VERIFY-01, RELEASE-01, RELEASE-02
**Gap Closure**: Closes G1, G2, G3 from `.planning/v1.3-MILESTONE-AUDIT.md`, plus tech-debt items TD-17 (LiveView patch), TD-19 (onboarding prose), TD-Req (REQUIREMENTS.md traceability table inconsistency)
**Success Criteria** (what must be TRUE):
  1. `15-VERIFICATION.md` exists and records goal-backward verification for PUBLISH-01 and PUBLISH-02 with citations to `release_docs_parity_test.exs`, `package_metadata_test.exs`, and `release_preflight.sh`
  2. `16-VERIFICATION.md` exists and records goal-backward verification for PUBLISH-03, VERIFY-01, RELEASE-01, RELEASE-02 (and notes VERIFY-02 functional coverage with a forward reference to Phase 21 for the reachability probe)
  3. `16-01-SUMMARY.md` and `16-02-SUMMARY.md` `requirements_completed` frontmatter declare the full Phase 16 set including VERIFY-01, VERIFY-02, RELEASE-02 in the appropriate plan
  4. The Phase 17 LiveView corrective patch on `lib/rindle/live_view.ex` and `test/rindle/live_view_test.exs` is committed (8/8 tests pass)
  5. README.md and `guides/getting_started.md` teach `Rindle.attachment_for/2,3`, `Rindle.ready_variants_for/1`, and the five bangs in the first-run onboarding path
  6. `.planning/REQUIREMENTS.md` traceability table marks API-06/API-07/API-08 (and any other satisfied IDs) as `Complete`, the bold-span line breaks at L26–51 are tightened, and the coverage note matches the new state
**Plans**: 3 plans
Plans:
- [x] 20-01-PLAN.md — Retrofit 15/16 VERIFICATION.md, fix 16 SUMMARY frontmatter, reconcile REQUIREMENTS.md (closes G1, G2, G3, TD-Req)
- [x] 20-02-PLAN.md — Commit residual Phase 17 LiveView corrective patch (closes 17-VERIFICATION.md:85-89 anti-patterns; TD-17)
- [x] 20-03-PLAN.md — Teach Phase 19 helpers (attachment_for, ready_variants_for, bangs) in README.md + guides/getting_started.md; extend docs_parity_test.exs (TD-19)
**UI hint**: no

### Phase 21: VERIFY-02 hexdocs.pm Reachability Probe
**Goal**: Adopters' contract that `hexdocs.pm/rindle/<version>` is reachable immediately after publish is observable in CI via a first-party HTTP probe, not only inferred from `mix hex.publish --yes` upload semantics
**Depends on**: Phase 20
**Requirements**: VERIFY-02
**Gap Closure**: Closes G4 from `.planning/v1.3-MILESTONE-AUDIT.md`
**Success Criteria** (what must be TRUE):
  1. `.github/workflows/release.yml` post-publish public_verify job issues an HTTP request against `https://hexdocs.pm/rindle/<version>` and fails the workflow on non-2xx response, with a bounded retry/backoff window aligned with hex.info index propagation
  2. A test asserts the probe step exists and is correctly wired (e.g., parity assertion in `test/install_smoke/release_docs_parity_test.exs` or a dedicated workflow-level test)
  3. The probe documentation is reflected in `guides/release_publish.md` so the runbook deviation history stays synchronized
**Plans**: TBD — to be drafted by `/gsd-plan-phase 21`
**UI hint**: no

### Phase 22: LiveView Corrective Fixes
**Goal**: Fix the code review and warning findings from Phase 20 regarding LiveView and onboarding nil-derefs.
**Depends on**: Phase 20
**Requirements**: TD-17
**Success Criteria** (what must be TRUE):
  1. LiveView components no longer trigger CR-01/CR-02 issues.
  2. Onboarding nil-deref (WR-04) and other warnings (WR-01..WR-05) are resolved.
**Plans**: 1 plan
Plans:
- [ ] 22-01-PLAN.md — Fix LiveView protocol defects, doc nil-derefs, and spec/warning issues
**UI hint**: no

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 10. Publish Readiness | v1.2 | 2/2 | Complete | 2026-04-28 |
| 11. Protected Publish Automation | v1.2 | 3/3 | Complete | 2026-04-28 |
| 12. Public Verification and Release Operations | v1.2 | 2/2 | Complete | 2026-04-28 |
| 13. Release Traceability and Runbook Alignment | v1.2 | 2/2 | Complete | 2026-04-29 |
| 14. Validation Closure for Publish Milestone | v1.2 | 2/2 | Complete | 2026-04-29 |
| 15. CI Integrity and Publish Preflight | v1.3 | 2/2 | Complete | 2026-04-30 |
| 16. Live Publish Execution and Post-Publish Verification | v1.3 | 2/2 | In Progress | - |
| 17. API Surface Boundary Audit | v1.3 | 5/5 | Complete    | 2026-04-30 |
| 18. Documentation and Typespec Coverage | v1.3 | 0/5 | Not started | - |
| 19. Convenience API Additions | v1.3 | 2/2 | Complete    | 2026-05-01 |
| 20. v1.3 Verification & Metadata Closure | v1.3 | 3/3 | Complete    | 2026-05-01 |
| 21. VERIFY-02 hexdocs.pm Reachability Probe | v1.3 | 0/0 | Not started | - |
| 22. LiveView Corrective Fixes | v1.3 | 0/1 | Not started | - |
