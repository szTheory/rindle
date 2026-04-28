# Roadmap: Rindle

## Overview

Milestone v1.1 focuses on the gaps that most affect adopter trust after the
v1.0 foundation shipped: runtime ownership that still leaks library internals,
direct-upload capability depth for larger production workloads, provider
compatibility honesty, and outside-in installation proof. The roadmap is
sequenced so the architectural boundary is corrected first, multipart support
builds on the corrected runtime contract, provider verification hardens those
flows, and the milestone closes by proving the package from a fresh adopter
perspective.

## Phases

**Phase Numbering:**
- Integer phases (6, 7, 8, 9): planned milestone work continuing from v1.0
- Decimal phases (6.1, 6.2): urgent insertions if needed later

- [x] **Phase 6: Adopter Runtime Ownership** - Replace consumer runtime
  hard-coding of `Rindle.Repo` with adopter-owned Repo resolution and prove it
  in the canonical adopter path
- [x] **Phase 7: Multipart Uploads** - Add first-class multipart direct-upload
  support, completion verification, and abort/recovery paths for larger
  workloads
- [ ] **Phase 8: Storage Capability Confidence** - Harden capability
  negotiation and verify provider-specific behavior across MinIO and
  Cloudflare R2
- [ ] **Phase 9: Install & Release Confidence** - Prove package-consumer
  installation in a fresh Phoenix app and align top-level docs with the real
  adopter path

## Phase Details

### Phase 6: Adopter Runtime Ownership
**Goal**: the adopter app truly owns the runtime Repo boundary, and the public
Rindle APIs no longer require or leak `Rindle.Repo` in consumer code paths
**Depends on**: Phase 5
**Requirements**: ADOPT-01, ADOPT-02, ADOPT-03, ADOPT-04
**Plans**: 3 plans
**Success Criteria** (what must be TRUE):
1. Setting `config :rindle, :repo, MyApp.Repo` causes public runtime paths to
   use `MyApp.Repo` without any consumer code touching `Rindle.Repo`
2. `Rindle.attach/4`, `Rindle.detach/3`, `Rindle.upload/3`, and direct-upload
   verification/attachment flows succeed against the configured adopter Repo
3. The canonical adopter integration uses an adopter-owned Repo end-to-end and
   no longer relies on the shared `Rindle.Repo` loophole
4. Guides and examples describe Repo and Oban ownership in adopter-first terms

Plans:
- [x] 06-01-PLAN.md — add the runtime Repo seam and remove facade-level `Rindle.Repo` ownership leaks
- [x] 06-02-PLAN.md — move broker flows and canonical adopter proof onto the runtime Repo contract
- [x] 06-03-PLAN.md — align guides with adopter-owned Repo setup and explicit default-Oban scope

### Phase 7: Multipart Uploads
**Goal**: larger production uploads have a first-class multipart path that
preserves Rindle's verification, cleanup, and state-machine guarantees
**Depends on**: Phase 6
**Requirements**: MULT-01, MULT-02, MULT-03, MULT-04
**Plans**: 3 plans
**Success Criteria** (what must be TRUE):
1. A supported S3-compatible adapter can initiate multipart uploads and return
   the data the client needs to upload parts safely
2. Completing a multipart upload and calling verification promotes the asset
   through the same trusted flow as the existing presigned PUT path
3. Abandoned multipart uploads can be detected and aborted by maintenance flows
   so incomplete uploads do not leak storage cost
4. Adapters that do not support multipart return explicit tagged capability
   errors instead of ambiguous runtime failures

Plans:
- [x] 07-01-PLAN.md — add multipart session persistence, storage callbacks, broker entrypoints, and tagged capability errors
- [x] 07-02-PLAN.md — close the maintenance repo seam and add retry-safe multipart abort cleanup
- [x] 07-03-PLAN.md — prove multipart completion and cleanup through the MinIO-backed integration and adopter harness

### Phase 8: Storage Capability Confidence
**Goal**: provider differences are encoded honestly in capability contracts and
verified against real backends so adopters know exactly what Rindle supports
**Depends on**: Phase 6, Phase 7
**Requirements**: CAP-01, CAP-02, CAP-03, CAP-04
**Plans**: 3 plans
**Success Criteria** (what must be TRUE):
1. Capability flags for upload and delivery flows are centralized, documented,
   and validated by tests
2. MinIO-backed integration coverage exercises both presigned PUT and multipart
   flows end-to-end
3. Cloudflare R2 behavior is documented and any unsupported flow fails with a
   tagged, user-actionable capability error
4. The capability model remains forward-compatible with a future GCS resumable
   adapter without changing current adopter-facing contracts

Plans:
- [x] 08-01-PLAN.md — centralize capability vocabulary and tagged unsupported behavior without changing current adopter contracts
- [ ] 08-02-PLAN.md — prove presigned PUT and multipart capability truth through the existing MinIO-backed adapter and adopter harnesses
- [ ] 08-03-PLAN.md — add the opt-in R2 contract lane, publish the R2-facing capability matrix, and remove docs drift while reserving additive resumable semantics

### Phase 9: Install & Release Confidence
**Goal**: a fresh Phoenix adopter can consume Rindle from the built artifact
and succeed without relying on repo-local assumptions or hidden setup knowledge
**Depends on**: Phase 6, Phase 8
**Requirements**: RELEASE-01, RELEASE-02, RELEASE-03
**Success Criteria** (what must be TRUE):
1. A package-consumer smoke path installs Rindle into a fresh Phoenix app from
   the built artifact and completes the canonical upload-to-delivery flow
2. CI validates installability from the built package, not only from the
   repository checkout
3. README and getting-started guidance match the proven adopter path, including
   Repo ownership, Oban expectations, and capability constraints

## Progress

**Execution Order:**
Phases execute in numeric order: 6 -> 7 -> 8 -> 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 6. Adopter Runtime Ownership | 3/3 | Complete | 2026-04-28 |
| 7. Multipart Uploads | 3/3 | Complete | 2026-04-28 |
| 8. Storage Capability Confidence | 1/3 | In Progress | — |
| 9. Install & Release Confidence | 0/0 | Pending | — |
