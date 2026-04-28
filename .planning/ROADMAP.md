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
same path instead of rediscovering it.

## Phases

**Phase Numbering:**
- Integer phases (10, 11, 12): planned milestone work continuing from v1.1
- Decimal phases (10.1, 10.2): urgent insertions if needed later

- [ ] **Phase 10: Publish Readiness** - Finalize metadata, ownership/auth
  setup, and preflight package/docs visibility for the first public release
- [ ] **Phase 11: Protected Publish Automation** - Turn the existing release
  lane into a real `Hex.pm` publish path guarded by environment controls and
  fail-fast release gates
- [ ] **Phase 12: Public Verification and Release Operations** - Prove the
  published package from Hex.pm and document the repeatable maintainer release
  and rollback path

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
**Plans**: 2 plans
**Success Criteria** (what must be TRUE):
1. A scoped publish credential can be used from the protected GitHub `release`
   environment without requiring local maintainer auth during the release run
2. The real publish step reuses the existing package, docs, and consumer-smoke
   gates instead of bypassing them
3. The workflow fails before publication when package contents, docs, or
   install proof drift

Plans:
- [ ] 11-01-PLAN.md — wire real publish auth and trigger policy into the
  existing release workflow
- [ ] 11-02-PLAN.md — make publish gating fail-safe and keep dry-run/build
  checks aligned with the live publish path

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

## Progress

**Execution Order:**
Phases execute in numeric order: 10 -> 11 -> 12

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 10. Publish Readiness | 0/2 | Pending | — |
| 11. Protected Publish Automation | 0/2 | Pending | — |
| 12. Public Verification and Release Operations | 0/2 | Pending | — |
