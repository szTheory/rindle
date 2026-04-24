---
phase: 01-foundation
plan: "05"
subsystem: security
tags: [upload-validation, mime-detection, ex-marcel, filename-sanitization, storage-keys]

requires:
  - phase: 01-foundation
    provides: profile upload policy fields and lifecycle transition states
provides:
  - Magic-byte MIME detection with extension/MIME consistency enforcement
  - Upload byte and pixel guardrails with quarantine-tagged rejection tuples
  - Filename sanitization and generated storage key primitives independent from user path input
  - Promotion gate checks that block direct-upload promotion before verification state is valid
affects: [upload-broker, promotion-flow, quarantine-branch, storage-adapter-keys]

tech-stack:
  added: [ex_marcel]
  patterns: [magic-byte-as-authoritative, quarantine-tagged-errors, split-filename-vs-storage-key]

key-files:
  created:
    - lib/rindle/security/mime.ex
    - lib/rindle/security/upload_validation.ex
    - lib/rindle/security/storage_key.ex
    - lib/rindle/security/filename.ex
    - test/rindle/security/upload_validation_test.exs
  modified:
    - lib/rindle/security/mime.ex
    - lib/rindle/security/upload_validation.ex

key-decisions:
  - "Treat magic-byte detection as authoritative and ignore client-reported MIME for policy decisions."
  - "Model all rejection paths as {:error, {:quarantine, reason}} tuples so promotion callers can branch deterministically."
  - "Keep filename sanitization separate from storage key generation to prevent user-path influence on object keys."

patterns-established:
  - "Validation Pipeline: MIME + extension checks, then limits, then promotion gate before metadata normalization."
  - "Promotion Gate Pattern: direct uploads must be in verifying/completed state before promotion can continue."

requirements-completed:
  - SEC-01
  - SEC-02
  - SEC-03
  - SEC-04
  - SEC-05
  - SEC-06
  - SEC-07
  - SEC-08

duration: 4 min
completed: 2026-04-24
---

# Phase 01 Plan 05: Upload Security Primitives Summary

**Upload security gates now rely on byte-level MIME detection, strict extension/limit enforcement, and non-user-controlled naming primitives before any promotion path can proceed.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-24T17:41:16Z
- **Completed:** 2026-04-24T17:45:20Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Added `Rindle.Security.Mime.detect/1` with ExMarcel-based magic-byte detection and extension consistency helper checks.
- Added `Rindle.Security.UploadValidation` gates for MIME/extension allowlists, max bytes, max pixels, promotion-state gating, and promotion metadata packaging.
- Added `Rindle.Security.Filename.sanitize/1` and `Rindle.Security.StorageKey.generate/3` to split user-facing names from internal object key generation.
- Added a focused rejection-path test matrix covering spoofing, guardrail failures, direct-upload gate enforcement, and successful sanitized/keyed promotion output.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement magic-byte MIME detection and extension consistency checks** - `82959f1` (feat)
2. **Task 2: Implement size/pixel validation plus sanitized filename and generated storage key** - `9fa16f1` (feat)
3. **Task 3: Add rejection-path security tests covering spoofing and promotion-gate failures** - `c9c873a` (test)

**Plan metadata:** pending docs commit for this summary

## Files Created/Modified
- `lib/rindle/security/mime.ex` - Magic-byte MIME detection and extension-to-MIME consistency checks.
- `lib/rindle/security/upload_validation.ex` - Security validation pipeline, limits, and promotion gate.
- `lib/rindle/security/filename.ex` - Sanitized client filename handling for safe metadata storage.
- `lib/rindle/security/storage_key.ex` - Generated storage key construction with controlled profile/asset segments.
- `test/rindle/security/upload_validation_test.exs` - Rejection-path and success-path security verification suite.

## Decisions Made
- ExMarcel integration is guarded with runtime table initialization so MIME lookups work consistently in tests and non-supervised contexts.
- Limit failures use quarantine-tagged reasons to keep promotion call sites deterministic and auditable.
- Direct-upload gating is explicitly separated from MIME/limit checks to preserve SEC-08 enforcement as a dedicated control point.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] ExMarcel ETS table unavailable during security tests**
- **Found during:** Task 3 (security rejection-path verification)
- **Issue:** ExMarcel lookups failed with missing ETS table errors when detection was called outside a started table wrapper process.
- **Fix:** Added `ensure_marcel_ready/0` in `Rindle.Security.Mime` to initialize `ExMarcel.TableWrapper` on demand before MIME lookups.
- **Files modified:** `lib/rindle/security/mime.ex`
- **Verification:** Re-ran `mix test test/rindle/security/upload_validation_test.exs` with all tests passing.
- **Committed in:** `c9c873a`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep; fix was required for stable MIME detection execution and preserved intended security behavior.

## Issues Encountered
- Task 3 tests initially failed due to ExMarcel table initialization assumptions; resolved with on-demand setup in MIME helper module.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Security requirement set SEC-01..SEC-08 now has executable primitives and focused test coverage.
- Upload/security consumers can call `validate_for_promotion/4` to enforce MIME, limits, and direct-upload verification gates in one flow.
- Ready for `01-06` storage/config plan completion and subsequent full Phase 1 verification.

## Verification Evidence
- `mix compile --warnings-as-errors` ✅
- `mix test --failed` ✅ (no pending failures)
- `mix test test/rindle/security/upload_validation_test.exs` ✅ (7 tests, 0 failures)
- `rg "def sanitize\\(filename\\)" lib/rindle/security/filename.ex` ✅ (1 match)
- `rg "max_pixels_exceeded" lib/rindle/security/upload_validation.ex` ✅ (1 match)

---
*Phase: 01-foundation*
*Completed: 2026-04-24*
