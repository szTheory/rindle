# Phase 55: Proof + Adopter Guidance - Research

**Researched:** 2026-05-26
**Domain:** owner-erasure proof closure, adopter-lane lifecycle proof, and support-truth guardrails
**Confidence:** HIGH

## Summary

Phase 55 should stay a proof-and-guidance phase, not a runtime-semantics phase.
The core owner-erasure facade is already implemented in `lib/rindle.ex` and
`lib/rindle/internal/owner_erasure.ex`, and the repo already has the right
proof seams: hermetic facade coverage in `test/rindle/owner_erasure_test.exs`,
worker safety coverage in `test/rindle/workers/purge_storage_test.exs`,
public-boundary checks in `test/rindle/api_surface_boundary_test.exs`, the
canonical adopter lane in `test/adopter/canonical_app/lifecycle_test.exs`, and
support-truth freeze points in `guides/user_flows.md` plus
`test/install_smoke/docs_parity_test.exs`.

The main gap is not missing APIs. The main gap is that the current hermetic
coverage proves report semantics and enqueue behavior but does not yet close
the full owner-erasure lifecycle by showing orphaned assets actually purge
while retained shared assets survive through the real worker boundary. The
canonical adopter lane also still stops at `attach/4` and `detach/3`; it does
not yet prove `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` as
the supported account-deletion surface. Finally, the docs-parity layer still
freezes the temporary Story 5 note rather than a fuller executable guide
section and active planning-artifact truth.

The recommended split is two plans:

1. `PROOF-03` + `PROOF-04` proof closure across hermetic and canonical
   adopter lanes
2. `TRUTH-02` guidance + planning-truth guardrails across docs, parity, and
   active planning artifacts

## File Touch Points

### Hermetic proof and public-boundary seams

- `test/rindle/owner_erasure_test.exs`
- `test/rindle/workers/purge_storage_test.exs`
- `test/rindle/attach_detach_test.exs`
- `test/rindle/api_surface_boundary_test.exs`

### Canonical adopter proof lane

- `test/adopter/canonical_app/lifecycle_test.exs`
- `test/support/data_case.ex`
- `config/test.exs` only if adopter-lane harness wiring needs it

### Guidance and support-truth guardrails

- `guides/user_flows.md`
- `guides/getting_started.md`
- `guides/operations.md`
- `test/install_smoke/docs_parity_test.exs`
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`

## Repo Facts The Planner Should Preserve

- `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` already exist as
  the public facade and are documented on `Rindle`. Phase 55 must prove and
  teach that surface rather than renaming it.
- `test/rindle/owner_erasure_test.exs` already covers preview/execute buckets,
  enqueue conflicts, and idempotent reruns. Extend it in place rather than
  introducing a new owner-erasure proof harness.
- `test/rindle/workers/purge_storage_test.exs` already proves the survivor-safe
  worker boundary and should remain the worker-specific safety seam.
- `test/adopter/canonical_app/lifecycle_test.exs` is the established
  adopter-shaped outside-in proof lane and is the right place to exercise
  preview/execute owner erasure.
- `guides/user_flows.md` already contains the account-deletion story. Phase 55
  should upgrade that story into a short executable canonical section rather
  than creating a standalone owner-erasure guide.
- `guides/getting_started.md` and `guides/operations.md` should remain thin
  pointer/boundary surfaces, not second canonical homes for the full semantics.
- `test/install_smoke/docs_parity_test.exs` already locks the current
  owner-erasure support-truth note and should remain the primary drift alarm.

## Risks and Planning Implications

### 1. Proof can drift into duplicated lifecycle matrices

If the plan adds a bespoke owner-erasure proof harness or expands generated-app
smoke, maintenance cost rises and proof taxonomy gets muddled. Keep the
existing split: hermetic ExUnit for semantic edges, canonical adopter lane for
public lifecycle reality, docs parity for support truth.

### 2. Canonical adopter proof must stay adopter-shaped

The canonical adopter lane currently uses real public surfaces through the
adopter Repo and MinIO-backed storage. Owner-erasure proof should be added as
another lifecycle chapter in that lane, not as repo-internal setup that bypasses
the adopter environment.

### 3. Docs truth can overclaim or fan out

Current guide wording still says the full executable facade lands in later
phase work. After proof lands, docs must flip to the supported-now posture,
but only in one canonical place. If multiple guides explain the full semantics
independently, wording drift becomes likely.

### 4. Planning truth must update with proof, not lag it

`PROOF-03`, `PROOF-04`, and the support-truth closure are only complete if the
active planning files stop describing owner erasure as merely being
"standardized" and instead describe it as the supported account-deletion
surface. The plan should make these planning-file updates explicit, not leave
them to verification cleanup.

## Validation Architecture

Plan verification should stay at three levels:

### Hermetic proof verification

- `mix test test/rindle/owner_erasure_test.exs --seed 0`
- `mix test test/rindle/owner_erasure_test.exs test/rindle/api_surface_boundary_test.exs --seed 0`
- optional supporting regression runs against
  `test/rindle/workers/purge_storage_test.exs` and
  `test/rindle/attach_detach_test.exs` when owner-erasure edge proof needs
  worker-boundary confirmation

### Canonical adopter verification

- `mix test test/adopter/canonical_app/lifecycle_test.exs --seed 0`
- assertions must prove the public preview/execute flow, retained shared assets,
  and orphan purge behavior through the adopter-shaped environment instead of
  `detach/3` loops

### Docs and planning-truth verification

- `mix test test/install_smoke/docs_parity_test.exs`
- targeted grep/file assertions for `guides/user_flows.md`,
  `guides/getting_started.md`, `guides/operations.md`,
  `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, and `.planning/STATE.md`
- public-boundary proof remains green through
  `mix test test/rindle/api_surface_boundary_test.exs --seed 0`

## Recommended Plan Boundaries

### Plan 01 - Proof closure (`PROOF-03`, `PROOF-04`)

Own the missing hermetic lifecycle assertions and the canonical adopter owner-
erasure lane. Keep this plan test-first and proof-heavy. It should not widen
into doc copy beyond minimal comments or assertion text.

### Plan 02 - Guidance and truth guardrails (`TRUTH-02`)

Own the canonical guide section, thin pointer/boundary updates, docs parity,
and active planning artifact truth. This plan should depend on Plan 01 so the
copy can describe the proved surface as supported now.

## Open Questions Resolved By Existing Context

- Expand generated-app/package-consumer smoke for owner erasure? No. The phase
  context explicitly keeps install smoke reserved for install/onboarding truth.
- Add a dedicated owner-erasure guide? No. `guides/user_flows.md` remains the
  canonical home.
- Create a new audit ledger/process-heavy truth ritual? No. Existing docs
  parity, API-boundary proof, and planning artifacts are the bounded guardrail
  set.
- Reopen runtime API shape or admin/bulk semantics? No. Phase 54 already froze
  the implementation contract and Phase 55 explicitly excludes that expansion.

## Planning Advice

- Make the hermetic proof task assert the whole lifecycle: preview/execute
  report semantics, worker-time orphan purge, retained shared-asset survival,
  and rerun stability.
- Keep canonical adopter proof narrow and public-surface based. The test should
  call `preview_owner_erasure/2` and `erase_owner/2`, not hand-build internal
  plans or re-teach `detach/3`.
- Upgrade Story 5 in `guides/user_flows.md` from a note into a short,
  executable owner-erasure section with a copy-pasteable preview/execute
  snippet and explicit "Rindle-managed associations only" wording.
- Use `guides/getting_started.md` and `guides/operations.md` for thin pointers
  only: getting-started points to the canonical flow, operations reinforces
  that `cleanup_orphans` remains maintenance-only.
- Treat `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, and `.planning/STATE.md`
  as part of the truth surface, not afterthought bookkeeping.
