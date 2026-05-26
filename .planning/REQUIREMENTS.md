# Requirements: Rindle v1.10 — Owner Account Erasure

**Defined:** 2026-05-26
**Core Value:** Media, made durable.

**Goal:** Turn account deletion from a hand-rolled detach loop into one honest,
auditable lifecycle API with explicit dry-run/reporting, execute semantics, and
shared-asset retention.

## Capability Selection Rubric

| Capability family | Route-owner expectation | Bridge frequency | Permission / policy sensitivity | Support-matrix impact | Proof required | Package classification |
|-------------------|-------------------------|------------------|---------------------------------|-----------------------|----------------|------------------------|
| Owner/account erasure facade | Public `Rindle` lifecycle API | Low-frequency semantic | High: destructive/compliance-adjacent | None across current adapters | Hermetic lifecycle proof + adopter-facing proof | `core` |

## Packaging Ledger

| Surface | Classification | Notes |
|---------|----------------|-------|
| Public owner-erasure facade on `Rindle` | `core` | The supported account-deletion entrypoint for adopters |
| Internal query/execution helpers that compute detach/purge/retain sets | `core` | Hidden implementation detail behind the facade |
| Guide and proof updates for account deletion | `core` | Required to keep support truth honest |
| Admin UI / bulk erasure orchestration | `defer` | Useful later, but not part of the current narrow wedge |
| Force-delete policy for assets with surviving attachments | `defer` | Too destructive/high-blast-radius for this milestone |

## Proof Posture Gate

- **Merge-blocking hermetic proof:** integration coverage for dry-run/reporting,
  execute behavior, orphan purge, retained shared assets, and idempotent reruns.
- **Merge-blocking adopter-facing proof:** a smoke/example lane that exercises
  the public owner-erasure facade for account deletion rather than teaching
  adopters to hand-roll detach loops.
- **Advisory proof:** bulk-job orchestration, admin UI affordances, and broader
  compliance workflow guidance can wait until a later milestone.

## Support Truth Gate

- **Supported now:** one public owner/account erasure contract with explicit
  dry-run/reporting and execute semantics.
- **Retained shared assets:** if an asset still has surviving attachments after
  the erased owner's rows are removed, Rindle retains the asset in storage and
  reports that retention explicitly.
- **Maintenance boundary:** `mix rindle.cleanup_orphans` remains the
  upload-residue maintenance lane and is not the supported owner/account
  erasure API.
- **Missing prerequisite behavior:** callers must provide an owner struct or
  equivalent owner identity resolvable by the existing attachment model; if no
  attachments exist, the operation reports a no-op instead of failing.
- **Native rebuilds required:** no.
- **Rough-edge docs to publish:** account-deletion flow, shared-asset caveat,
  dry-run/reporting shape, and explicit non-goals (admin UI, force-delete,
  bulk orchestration).

## v1.10 Requirements

### Owner Erasure Contract

- [ ] **LIFE-01**: Adopter can request a dry-run owner/account erasure report
      and receive explicit totals and lists for attachments to detach, assets
      eligible for purge, and assets that will be retained because another live
      attachment still exists.
- [ ] **LIFE-02**: Adopter can execute owner/account erasure through one public
      facade call that detaches every attachment for that owner and reuses the
      existing async purge lane only for assets that become newly orphaned.
- [ ] **LIFE-03**: If any target asset still has a surviving attachment after
      the owner's rows are removed, Rindle retains that asset in storage and
      reports the retention explicitly instead of deleting shared media.
- [ ] **LIFE-04**: Re-running owner/account erasure for the same owner is
      idempotent and returns a stable no-op/report result rather than raising
      or double-purging already-cleared state.

### Proof And Truth Alignment

- [ ] **PROOF-03**: Hermetic lifecycle proof covers both orphan purge and
      retained shared-asset behavior for the owner-erasure contract.
- [ ] **PROOF-04**: Adopter-facing proof or smoke coverage exercises the
      recommended account-deletion flow against the public facade instead of
      direct `detach/3` loops.
- [ ] **TRUTH-02**: Guides and active planning artifacts describe owner/account
      erasure as the supported account-deletion surface and clearly defer admin
      UI, bulk orchestration, and force-delete-of-shared-assets policy.

## v2 Requirements

### Tus Follow-ons

- **TUS-15**: Browser client can supply checksum-backed chunk integrity for the
  supported tus extension set.
- **TUS-16**: Browser client can upload via concatenation / partial uploads
  when adopter demand justifies the extra complexity.
- **TUS-17**: Browser client can create uploads whose final size is unknown at
  creation time via `Upload-Defer-Length`.
- **TUS-18**: Rindle can offer an additive IETF RUFH / tus 2.0 surface without
  rewriting the current session machinery.

### Adjacent Lifecycle And Streaming Conveniences

- **MUX-24**: Adopter can cancel a direct Mux creator upload through a
  first-class public API.
- **STREAM-10**: A second streaming provider proves the provider contract
  without weakening capability honesty.
- **LIFE-05**: Operator can orchestrate bulk owner-erasure jobs or an admin UI
  without changing the core facade contract.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Force-delete behavior for assets with surviving attachments | Too destructive for the current milestone; the conservative shared-asset rule preserves current repo truth. |
| Admin UI for owner/account erasure | Operator UI is not required to prove the lifecycle contract. |
| Bulk compliance orchestration or scheduler-driven erasure jobs | The narrow wedge is the core facade API, not workflow orchestration. |
| tus protocol follow-ons | Lower leverage than closing the remaining core lifecycle gap. |
| `cancel_direct_upload/1` | Useful, but provider-specific and narrower than owner erasure. |
| Second streaming provider | Demand-driven breadth, not the current default next wedge. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| LIFE-01 | Phase 53 | Pending |
| TRUTH-02 | Phase 53 | Pending |
| LIFE-02 | Phase 54 | Pending |
| LIFE-03 | Phase 54 | Pending |
| LIFE-04 | Phase 54 | Pending |
| PROOF-03 | Phase 55 | Pending |
| PROOF-04 | Phase 55 | Pending |

**Coverage:**
- v1.10 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-26*
*Last updated: 2026-05-26 after initial milestone definition*
