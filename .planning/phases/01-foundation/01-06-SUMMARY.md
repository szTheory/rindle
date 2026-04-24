---
phase: 01-foundation
plan: "06"
subsystem: storage
tags: [storage-adapters, s3, local-disk, configuration, conformance-tests]

requires:
  - phase: 01-foundation
    provides: behavior callbacks, profile DSL storage selection, and security primitives from plans 01-02/01-03/01-05
provides:
  - Local and S3 storage adapters implementing the `Rindle.Storage` contract with truthful capabilities
  - Profile-driven adapter dispatch through `Rindle.storage_adapter_for/1` and tagged tuple wrappers
  - Foundation config accessors and defaults for queue name plus signed/upload TTL values
  - Adapter conformance tests, profile dispatch tests, and a MinIO-gated S3 integration hook
affects: [phase-2-upload-processing, delivery-url-generation, ci-integration-lane]

tech-stack:
  added: [ex_aws, ex_aws_s3, bypass, ex_machina]
  patterns: [profile-scoped-adapter-resolution, tagged-storage-boundary-errors, env-gated-integration-hook]

key-files:
  created:
    - config/config.exs
    - lib/rindle/config.ex
    - lib/rindle/storage/local.ex
    - lib/rindle/storage/s3.ex
    - test/rindle/storage/storage_adapter_test.exs
    - test/rindle/config/config_test.exs
  modified:
    - mix.exs
    - mix.lock
    - lib/rindle.ex

key-decisions:
  - "Storage adapter resolution remains profile-scoped (`profile.storage_adapter/0`) rather than application-global."
  - "Storage boundary helpers normalize all adapter responses to tagged tuples and reject malformed adapter outputs."
  - "S3 integration evidence is captured with a MinIO-tagged test that skips with explicit guidance when env vars are absent."

patterns-established:
  - "Adapter Truth Pattern: capability declarations (`[:local]`, `[:presigned_put]`) are hardcoded and asserted in tests."
  - "Config Access Pattern: queue and TTL defaults are centralized in `config :rindle` and exposed through `Rindle.Config` accessors."

requirements-completed:
  - STOR-01
  - STOR-02
  - STOR-03
  - STOR-04
  - STOR-05
  - STOR-06
  - STOR-07
  - CONF-01
  - CONF-03
  - CONF-04
  - CONF-05
  - ERR-01
  - ERR-02

duration: 5 min
completed: 2026-04-24
---

# Phase 01 Plan 06: Storage Adapter Foundation Summary

**Rindle now ships profile-scoped Local/S3 storage adapters, centralized queue/TTL defaults, and conformance tests (including a MinIO hook) that lock the storage/error contract for downstream upload and processing work.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-24T17:50:37Z
- **Completed:** 2026-04-24T17:56:27Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments
- Aligned dependency baseline to Oban/Image current targets and added S3/test adapter dependencies.
- Added `Rindle.Config` plus `config :rindle` defaults for queue and TTL values used by storage and signed URL flows.
- Implemented `Rindle.Storage.Local` and `Rindle.Storage.S3` with truthful capabilities and tagged tuple semantics.
- Extended `Rindle` facade with profile-based adapter resolution and structured storage-failure logging metadata.
- Added adapter conformance/config tests with MinIO-gated integration hook to provide STOR-07 verification entrypoint.

## Task Commits

Each task was committed atomically:

1. **Task 1: Align Phase 1 dependency baseline and foundation config defaults** - `835f9b6` (chore)
2. **Task 2: Implement Local and S3 storage adapters with truthful capabilities and tagged error tuples** - `5bdd798` (feat)
3. **Task 3: Add adapter conformance tests and MinIO integration hook for STOR-07 evidence** - `d61f9f0` (test)

**Plan metadata:** pending docs commit for this summary

## Files Created/Modified
- `mix.exs` - Updated Phase 1 dependency baseline for storage and test harness support.
- `mix.lock` - Locked new adapter/test dependency graph from `mix deps.get`.
- `config/config.exs` - Added queue and TTL defaults under `config :rindle`.
- `lib/rindle/config.ex` - Added runtime accessors for queue name and TTL defaults.
- `lib/rindle/storage/local.ex` - Added local filesystem adapter implementing `Rindle.Storage`.
- `lib/rindle/storage/s3.ex` - Added S3 adapter with ExAws-backed store/delete/url/presigned operations.
- `lib/rindle.ex` - Added profile-scoped adapter invocation helpers and storage failure logging.
- `test/rindle/storage/storage_adapter_test.exs` - Added adapter callback/capability/dispatch tests plus MinIO integration hook.
- `test/rindle/config/config_test.exs` - Added config default and override behavior tests.

## Decisions Made
- Keep Local adapter deterministic URLs as `file://` references to generated storage paths for predictable local behavior.
- Use `Rindle.store_variant/4` as the dedicated path that logs `rindle.storage.variant_processing_failed` with required metadata.
- Model MinIO integration as an opt-in tagged test so local CI/dev loops stay deterministic without mandatory external services.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dynamic MinIO skip implemented through invalid setup callback return**
- **Found during:** Task 3 (test verification run)
- **Issue:** ExUnit setup callback attempted to return `{:skip, ...}`, which is not a valid setup return shape.
- **Fix:** Switched to `@tag skip:` with env-derived reason while retaining `@tag :minio` for targeted execution.
- **Files modified:** `test/rindle/storage/storage_adapter_test.exs`
- **Verification:** Re-ran `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/config/config_test.exs` (8 tests, 0 failures, 1 skipped).
- **Committed in:** `d61f9f0`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope change; fix stabilized the intended MinIO-gated conformance evidence path.

## Issues Encountered
- Initial adapter conformance assertion on callback exports failed until adapter modules were explicitly loaded in test setup logic.
- MinIO integration test needed compile-time skip tagging rather than runtime setup returns for explicit skip messaging.

## User Setup Required

None - no external service configuration is required to run the default test suite.

## Next Phase Readiness
- Phase 1 storage/config/error contract requirements in this plan are implemented with automated verification coverage.
- Phase 1 now has all six plan summaries in place; roadmap/requirements tracking can advance to Phase 2 planning/execution.
- The MinIO-tagged integration hook is ready for CI lane activation when storage integration infrastructure is introduced.

## Verification Evidence
- `mix deps.get` ✅
- `mix compile --warnings-as-errors` ✅
- `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/config/config_test.exs` ✅ (8 tests, 0 failures, 1 skipped)
- `rg "config :rindle, :signed_url_ttl_seconds, 900" config/config.exs` ✅ (1 match)
- Task acceptance checks via `rg` for all required adapter/config/test markers ✅

---
*Phase: 01-foundation*
*Completed: 2026-04-24*
