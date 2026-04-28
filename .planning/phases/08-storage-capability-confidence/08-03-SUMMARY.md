---
phase: 08-storage-capability-confidence
plan: 03
subsystem: docs
tags: [storage, r2, s3, exdoc, capabilities]
requires:
  - phase: 08-storage-capability-confidence
    provides: shared capability vocabulary plus MinIO-backed contract proof
provides:
  - opt-in Cloudflare R2 contract lane on the shipped S3 adapter seam
  - canonical storage capability guide wired into ExDoc
  - profile and delivery docs aligned to the tagged unsupported capability contract
affects: [storage, direct-upload, delivery, adopter-guides]
tech-stack:
  added: []
  patterns: [opt-in live provider verification, canonical capability guide, explicit proof-boundary docs]
key-files:
  created: [test/rindle/storage/r2_test.exs, guides/storage_capabilities.md]
  modified: [mix.exs, guides/profiles.md, guides/secure_delivery.md]
key-decisions:
  - "Keep Cloudflare R2 on the shipped Rindle.Storage.S3 seam and prove it only through an opt-in/manual lane."
  - "Document MinIO as the default real-provider proof and R2 as a separate auditable manual contract lane."
  - "Describe future resumable support as additive reserved capability vocabulary, not as a shipped API."
patterns-established:
  - "Provider-specific live lanes must skip loudly when secrets are absent instead of pretending to be part of default CI."
  - "Capability and proof-posture docs should live in one canonical guide and be linked from profile and delivery guides."
requirements-completed: [CAP-03, CAP-04]
duration: 3min
completed: 2026-04-28
---

# Phase 08 Plan 03: Storage Capability Confidence Summary

**Opt-in Cloudflare R2 contract coverage with a canonical storage capability guide and explicit proof-boundary documentation**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-28T14:06:30Z
- **Completed:** 2026-04-28T14:09:37Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `test/rindle/storage/r2_test.exs` as an opt-in `:r2` lane that uses the shipped `Rindle.Storage.S3` adapter seam, skips loudly without `RINDLE_R2_*` secrets, and asserts the reserved resumable capability fails with `{:error, {:upload_unsupported, :resumable_upload}}`.
- Published `guides/storage_capabilities.md` as the canonical adopter-facing capability matrix and wired it into `mix docs`.
- Removed docs drift from `guides/profiles.md` and `guides/secure_delivery.md` by pointing both at the shared guide and tightening their wording around tagged unsupported delivery/upload flows, R2 proof posture, and additive future resumable semantics.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the opt-in Cloudflare R2 contract lane per the resolved Phase 8 strategy** - `c3652f7`
2. **Task 2: Publish the canonical capability guide and remove docs drift** - `8c40d5b`

## Verification

- `mix test test/rindle/storage/r2_test.exs --include r2` - passed with skip (`1 test, 0 failures, 1 skipped`). No `RINDLE_R2_*` credentials were present, so the opt-in/manual lane stayed out of default execution as intended.
- `mix docs` - passed. ExDoc generated successfully and emitted two pre-existing `Phoenix.LiveView.Upload.allow_upload/3` hidden-doc warnings from `lib/rindle/live_view.ex`.
- `rg -n "guides/storage_capabilities\\.md" mix.exs` - passed (`mix.exs:104`).
- `rg -n "(Cloudflare R2|r2|resumable|upload_unsupported|delivery_unsupported|manual verification|opt-in)" guides/storage_capabilities.md guides/profiles.md guides/secure_delivery.md` - passed.
- Positive-overclaim audit for default-CI R2, bespoke R2 adapter, and shipped GCS/public resumable API wording - passed (`No positive overclaims found in updated guides`).

## Files Created/Modified

- `test/rindle/storage/r2_test.exs` - Opt-in live R2 contract lane for presigned PUT, `head/2`, signed URL generation, multipart upload, and explicit reserved resumable failure.
- `guides/storage_capabilities.md` - Canonical capability vocabulary, tagged unsupported-flow contract, provider matrix, and proof-boundary guide.
- `mix.exs` - Added the capability guide to ExDoc extras.
- `guides/profiles.md` - Replaced stale inline capability claims with guidance that points to the canonical matrix and tagged failure contract.
- `guides/secure_delivery.md` - Tightened signed-delivery capability wording and documented the opt-in/manual R2 delivery proof boundary.

## Decisions Made

- Kept R2 documentation and verification scoped to the existing `Rindle.Storage.S3` seam instead of implying a provider-specific adapter.
- Treated absent R2 credentials as an explicit manual-verification gate, not as a failing CI responsibility.
- Kept future resumable semantics documentation at the reserved capability-vocabulary level only.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first overclaim grep matched explicit negations such as "does not claim live R2 proof in default CI." The check was narrowed to positive-only wording so the final honesty audit reflects actual promises instead of the guardrails documenting what is not shipped.

## Known Stubs

None.

## User Setup Required

None - no external service configuration was changed in repo defaults. Manual R2 verification still requires adopters to export the `RINDLE_R2_*` environment variables documented in `guides/storage_capabilities.md`.

## Next Phase Readiness

- Adopters now have one canonical capability guide for Local, MinIO, generic S3-compatible providers, and Cloudflare R2.
- The repo has an auditable R2 contract lane without overstating default-CI proof or shipping a bespoke R2/GCS/resumable surface.

## Self-Check: PASSED

- Verified `.planning/phases/08-storage-capability-confidence/08-03-SUMMARY.md` exists on disk.
- Verified commits `c3652f7` and `8c40d5b` exist in git history.
