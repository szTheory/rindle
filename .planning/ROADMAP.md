# Roadmap: Rindle

## Current Status

Milestone `v1.2 First Hex Publish` is now the active milestone. It builds on
Phase 9's built-artifact install proof by exercising one real public `Hex.pm`
publish and turning that path into a guarded, reusable release workflow.

## Overview

The roadmap stays deliberately narrow. Phase 10 closes the remaining publish
readiness gaps around metadata, owner/auth setup, and preflight visibility.
Phase 11 upgrades the existing release lane from dry-run-only proof to a real,
protected publish path. Phase 12 then proves the public package from the
outside in and captures the maintainer runbook so future releases reuse the
same path instead of rediscovering it. Phase 13 closes the audit's
traceability and runbook drift, and Phase 14 finishes the remaining Nyquist
validation artifacts needed for a clean milestone closeout.

## Phases

**Phase Numbering:**
- Integer phases (10, 11, 12, 13, 14): planned milestone work continuing from
  v1.1
- Decimal phases (10.1, 10.2): urgent insertions if needed later

- [x] **Phase 10: Publish Readiness** - Finalize metadata, ownership/auth
  setup, and preflight package/docs visibility for the first public release
- [x] **Phase 11: Protected Publish Automation** - Turn the existing release
  lane into a real `Hex.pm` publish path guarded by environment controls and
  fail-fast release gates
- [x] **Phase 12: Public Verification and Release Operations** - Prove the
  published package from Hex.pm and document the repeatable maintainer release
  and rollback path
- [x] **Phase 13: Release Traceability and Runbook Alignment** - Close audit
  debt in requirement metadata, summary traceability, and release-doc/workflow
  parity coverage
- [x] **Phase 14: Validation Closure for Publish Milestone** - Finish the (completed 2026-04-29)
  remaining Phase 10 and Phase 11 validation artifacts so the milestone can
  pass audit without draft Nyquist residue

## Phase Details

### Phase 10: Publish Readiness
**Goal**: the repo is explicitly ready for a first public `Hex.pm` publish, and
maintainers can inspect exactly what will ship before any live upload happens
**Depends on**: Phase 9
**Requirements**: RELEASE-04, RELEASE-05
**Plans**: 2 plans
**Success Criteria** (what must be TRUE):
1. Package metadata, publish ownership expectations, and release versioning
   steps are documented explicitly instead of being implicit maintainer memory
2. Maintainers can build and inspect the exact tarball contents that will ship
   to Hex.pm
3. Docs generation and release-facing guides are checked before any real
   publish step is allowed to run

Plans:
- [ ] 10-01-PLAN.md — tighten package metadata, versioning, and first-publish
  checklist/runbook inputs
- [ ] 10-02-PLAN.md — harden tarball/docs preflight checks around the existing
  build and smoke path

### Phase 11: Protected Publish Automation
**Goal**: the release workflow can perform a real `Hex.pm` publish with the
same preflight checks already proved locally while keeping the write credential
and trigger path narrowly controlled
**Depends on**: Phase 10
**Requirements**: RELEASE-06, RELEASE-07
**Plans**: 3 plans
**Success Criteria** (what must be TRUE):
1. A scoped publish credential can be used from the protected GitHub `release`
   environment without requiring local maintainer auth during the release run
2. The real publish step reuses the existing package, docs, and consumer-smoke
   gates instead of bypassing them
3. The workflow fails before publication when package contents, docs, or
   install proof drift

Plans:
- [x] 11-01-PLAN.md — wire real publish auth and trigger policy into the
  existing release workflow
- [x] 11-02-PLAN.md — make publish gating fail-safe and keep dry-run/build
  checks aligned with the live publish path
- [x] 11-03-PLAN.md — move dry-run publish validation into CI so the release
  flow is exercised continuously outside the protected live publish lane

### Phase 12: Public Verification and Release Operations
**Goal**: Rindle's first public release is proved from the outside in and the
maintainer runbook is strong enough to make future releases routine
**Depends on**: Phase 11
**Requirements**: RELEASE-08, RELEASE-09
**Plans**: 2 plans
**Success Criteria** (what must be TRUE):
1. A fresh consumer path can resolve the published Rindle version from Hex.pm
   and complete the canonical install flow
2. Maintainers have clear first-publish, future-release, and rollback/revert
   instructions tied to the actual shipped workflow
3. The public release path no longer depends on repo-local package shortcuts
   for confidence

Plans:
- [ ] 12-01-PLAN.md — add post-publish Hex.pm consumer verification and public
  package resolution proof
- [ ] 12-02-PLAN.md — finalize maintainer release, rollback, and future-routine
  documentation around the proved workflow

### Phase 13: Release Traceability and Runbook Alignment
**Goal**: the v1.2 release milestone is traceable end to end in the planning
artifacts, and maintainer documentation stays aligned with the shipped release
workflow
**Depends on**: Phase 12
**Requirements**: RELEASE-04, RELEASE-05, RELEASE-06, RELEASE-07, RELEASE-08,
RELEASE-09
**Gap Closure**: Closes v1.2 audit tech debt around requirement metadata,
summary frontmatter, stale release-guide language, and missing doc/workflow
parity coverage
**Plans**: 2 plans
**Success Criteria** (what must be TRUE):
1. `.planning/REQUIREMENTS.md`, phase verification reports, and summary
   frontmatter agree on requirement completion status for `RELEASE-04` through
   `RELEASE-09`
2. Phase 11 and Phase 12 summaries expose requirement completion using one
   consistent frontmatter key that the audit tooling can consume directly
3. `guides/release_publish.md` matches the shipped release workflow contract,
   and an automated parity check prevents this class of drift from recurring

Plans:
- [ ] 13-01-PLAN.md — normalize requirement trace metadata across summaries,
  requirements tracking, and audit-facing planning artifacts
- [ ] 13-02-PLAN.md — align `guides/release_publish.md` with the live workflow
  contract and add a parity check for future drift

### Phase 14: Validation Closure for Publish Milestone
**Goal**: the milestone's remaining partial validation artifacts are completed
so audit closure no longer depends on draft Nyquist state
**Depends on**: Phase 13
**Requirements**: none
**Gap Closure**: Closes the v1.2 audit's partial Nyquist status for Phases 10
and 11
**Plans**: 2 plans
**Success Criteria** (what must be TRUE):
1. Phase 10 validation reflects the tests and wave artifacts that now exist,
   with sign-off fields advanced from pending/draft where appropriate
2. Phase 11 validation reflects the shipped publish automation and validation
   probes, with wave completion and approval state no longer left incomplete
3. A follow-up milestone audit can treat Phases 10 through 12 as fully closed
   without special-casing validation residue

Plans:
- [x] 14-01-PLAN.md — bring Phase 10 validation artifacts to completed,
  evidence-backed state
- [x] 14-02-PLAN.md — bring Phase 11 validation artifacts to completed,
  evidence-backed state

## Progress

**Execution Order:**
Phases execute in numeric order: 10 -> 11 -> 12

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 10. Publish Readiness | 2/2 | Complete | 2026-04-28 |
| 11. Protected Publish Automation | 3/3 | Complete | 2026-04-28 |
| 12. Public Verification and Release Operations | 2/2 | Complete | 2026-04-28 |
| 13. Release Traceability and Runbook Alignment | 0/2 | Pending | — |
| 14. Validation Closure for Publish Milestone | 2/2 | Complete    | 2026-04-29 |
