---
phase: 08-storage-capability-confidence
plan: 02
subsystem: test
tags: [minio, s3, uploads, capabilities, integration]
requires:
  - phase: 07-multipart-uploads
    provides: multipart broker and S3 adapter flows verified against MinIO semantics
provides:
  - Unified MinIO adapter proof for `:presigned_put` and `:multipart_upload`
  - Broker-level MinIO lifecycle proof for both direct-upload lanes
  - Canonical adopter capability assertions across both direct-upload paths
affects: [storage-capabilities, direct-uploads, adopter-runtime]
tech-stack:
  added: []
  patterns: [real HTTP presigned uploads, capability assertions at lifecycle entrypoints, MinIO-backed end-to-end regression proof]
key-files:
  created: []
  modified: [test/rindle/storage/s3_test.exs, test/rindle/upload/lifecycle_integration_test.exs, test/adopter/canonical_app/lifecycle_test.exs]
decisions:
  - Keep CAP-02 proof inside the existing MinIO-backed suites rather than introducing a second harness or helper path.
  - Assert `:presigned_put` and `:multipart_upload` at the start of each real direct-upload scenario so capability honesty is proven before remote I/O begins.
metrics:
  duration: 7 min
  completed: 2026-04-28
---

# Phase 8 Plan 2: MinIO Capability Confidence Summary

**The shipped S3 adapter, broker lifecycle, and canonical adopter lane now prove the same MinIO-backed upload capability contract for both presigned PUT and multipart uploads**

## Performance

- **Completed:** 2026-04-28T14:04:51Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Reworked the MinIO S3 adapter proof so presigned PUT performs a real HTTP upload before `head/2`, `download/2`, and deletion checks, while multipart stays on the same adapter contract.
- Added broker-level MinIO integration tests for both direct presigned PUT and multipart completion, each asserting upload capabilities before exercising the real remote flow and promotion.
- Tightened the canonical adopter lane so both direct-upload paths assert the same capability contract before they continue into promotion, variants, signed delivery, attach, and detach.

## Task Commits

1. **Task 1: Extend the MinIO S3 adapter proof so both upload capabilities are exercised under one contract** - `1e78af0`
2. **Task 2: Re-run the broker and adopter lifecycle proofs through the same capability contract** - `256143d`

## Verification

- `mix test test/rindle/storage/s3_test.exs --include minio` — passed (`3 tests, 0 failures, 2 skipped`)
- `mix test test/rindle/upload/lifecycle_integration_test.exs --include integration` — passed (`8 tests, 0 failures`)
- `mix test test/adopter/canonical_app/lifecycle_test.exs --include minio` — passed (`3 tests, 0 failures`)

## Decisions Made

- Used the real presigned PUT path in the adapter and broker proofs instead of `store/3` or filesystem shortcuts, matching the CAP-02 trust boundary.
- Added MinIO broker proof in the existing lifecycle integration suite rather than migrating that responsibility entirely to the canonical adopter lane.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Verified `.planning/phases/08-storage-capability-confidence/08-02-SUMMARY.md` exists on disk.
- Verified commits `1e78af0` and `256143d` exist in git history.
