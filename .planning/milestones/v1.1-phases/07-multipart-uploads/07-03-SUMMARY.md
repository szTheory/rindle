---
phase: 07-multipart-uploads
plan: 03
subsystem: testing
tags: [multipart, minio, s3, integration, adopter]
requires:
  - phase: 07-multipart-uploads
    provides: persisted multipart session state, broker APIs, and retry-safe cleanup semantics from 07-01 and 07-02
provides:
  - Real MinIO-backed multipart adapter completion proof
  - Broker multipart integration coverage alongside presigned PUT coverage
  - Canonical adopter multipart completion and cleanup proof through the existing lifecycle lane
affects: [multipart-uploads, storage-capabilities, adopter-runtime, maintenance-workers]
tech-stack:
  added: []
  patterns: [MinIO multipart proofs use production-valid 5 MiB first parts, canonical multipart completion reuses the existing promotion and cleanup lanes]
key-files:
  created: []
  modified: [lib/rindle/storage/s3.ex, test/rindle/storage/s3_test.exs, test/rindle/upload/lifecycle_integration_test.exs, test/adopter/canonical_app/lifecycle_test.exs]
key-decisions:
  - "Keep multipart proof in the existing MinIO-backed suites instead of introducing a parallel harness."
  - "Use production-valid multipart part sizing in real MinIO tests so the proof matches S3 semantics rather than a toy split."
  - "Treat MinIO's `{:http_error, 404, ...}` HEAD response shape as `:not_found` so delete and cleanup proofs remain adapter-honest."
patterns-established:
  - "Canonical adopter multipart tests must upload real parts, capture MinIO ETags, and complete server-side before promotion assertions."
  - "Real S3-compatible multipart proofs should verify expire-then-cleanup ordering by asserting session expiry before remote abort-driven deletion."
requirements-completed: [MULT-01, MULT-02, MULT-03]
duration: 7 min
completed: 2026-04-28
---

# Phase 7 Plan 3: Multipart Proof Summary

**Real MinIO-backed multipart uploads now prove adapter completion, broker integration, adopter promotion, and abandoned-upload cleanup through Rindle's existing verification and maintenance lanes**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-28T12:12:30Z
- **Completed:** 2026-04-28T12:19:42Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a real MinIO multipart adapter round-trip that initiates, uploads two parts, completes with captured ETags, and verifies the final object with `head/2`.
- Added broker-level multipart lifecycle integration coverage without regressing the existing presigned PUT and proxied upload integration paths.
- Extended the canonical adopter lane to prove multipart completion converges into promotion, variants, delivery, attach/detach, and expire-then-cleanup abort semantics.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add MinIO-backed multipart adapter and broker integration proof** - `b1cd44c` (test), `18bd22e` (feat)
2. **Task 2: Extend the canonical adopter MinIO flow to multipart completion and cleanup** - `04919c3` (test)

Additional verification-driven fix:

- `1099b31` (fix) — normalize MinIO `HEAD` 404 responses and update the real multipart adapter proof to use valid 5 MiB first-part sizing.

## Files Created/Modified

- `lib/rindle/storage/s3.ex` - normalizes MinIO `{:http_error, 404, ...}` `HEAD` responses to `:not_found`.
- `test/rindle/storage/s3_test.exs` - proves real multipart initiate/upload-part/complete/head behavior against MinIO with valid S3 part sizing.
- `test/rindle/upload/lifecycle_integration_test.exs` - proves broker multipart completion alongside the existing presigned PUT integration coverage.
- `test/adopter/canonical_app/lifecycle_test.exs` - proves canonical adopter multipart completion, promotion, delivery, and cleanup against MinIO.

## Decisions Made

- Kept multipart proof work in the existing adapter, integration, and adopter files so multipart remains additive to the trusted presigned PUT lanes rather than branching into a second harness.
- Used a padded PNG fixture for canonical multipart proof so the first part satisfies the real S3/MinIO 5 MiB minimum while still exercising Rindle's image verification and variant path.
- Fixed adapter 404 normalization instead of weakening the MinIO assertions; the real provider harness exposed a legitimate response-shape gap.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized MinIO `HEAD` 404 responses surfaced by real harness verification**
- **Found during:** Task 2 verification
- **Issue:** `S3.head/2` returned `{:error, {:http_error, 404, ...}}` after delete under explicit MinIO config, which broke the existing `:not_found` contract used by the adapter proof.
- **Fix:** Added a dedicated `handle_head_response/1` clause for `{:http_error, 404, ...}` and updated the MinIO multipart proof to use production-valid part sizing.
- **Files modified:** `lib/rindle/storage/s3.ex`, `test/rindle/storage/s3_test.exs`
- **Verification:** `mix test test/rindle/storage/s3_test.exs --include minio`, `mix test test/rindle/upload/lifecycle_integration_test.exs`, and `mix test test/adopter/canonical_app/lifecycle_test.exs --include minio`
- **Committed in:** `1099b31`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The auto-fix was required to make the real MinIO proof truthful. No scope creep.

## Issues Encountered

- MinIO rejected the initial canonical multipart proof with `EntityTooSmall` because the first uploaded part was below the S3 minimum. The test fixture was changed to a production-valid multipart shape instead of loosening the proof.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 8 can build on real MinIO multipart proof for capability-honesty work without reopening broker or maintenance lifecycle design.
- The canonical adopter lane now proves both direct presigned PUT and multipart completion under the same verification and cleanup boundaries.

## Self-Check: PASSED

- Verified `.planning/phases/07-multipart-uploads/07-03-SUMMARY.md` exists on disk.
- Verified task commits `b1cd44c`, `18bd22e`, `1099b31`, and `04919c3` exist in git history.
- Scanned modified implementation and test files for placeholder or stub patterns; none found.
