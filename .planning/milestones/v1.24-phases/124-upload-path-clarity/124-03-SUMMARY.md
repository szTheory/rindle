---
phase: 124-upload-path-clarity
plan: "03"
subsystem: upload
tags: [elixir, plug, tus, streaming, storage, termination, compiled-docs]
requires:
  - phase: 124-upload-path-clarity
    provides: hidden TusProtocol and TusCreation collaborators behind the visible TusPlug facade
provides:
  - Hidden TusStream owner for bounded PATCH drain, checksum, temporary-file cleanup, state codec, and adapter dispatch
  - Hidden TusTermination owner for polymorphic backing abort and bounded retry-marker construction
  - Compiled-doc proof that storage and termination mechanics remain internal
affects: [124-04, 124-05, upload-path-clarity, tus, storage-adapters]
tech-stack:
  added: []
  patterns: [visible Plug facade with hidden effect-domain collaborators, adapter-polymorphic bounded stream dispatch]
key-files:
  created: [lib/rindle/upload/tus_stream.ex, lib/rindle/upload/tus_termination.ex]
  modified: [lib/rindle/upload/tus_plug.ex, test/rindle/api_surface_boundary_test.exs]
key-decisions:
  - "TusPlug retains all protocol gates, repo updates, broadcasts, telemetry, completion convergence, and Plug response construction."
  - "TusStream and TusTermination receive resolved adapter/root inputs and never branch on adapter identity or re-resolve configuration."
patterns-established:
  - "Move cohesive storage or termination effects behind @moduledoc false/@doc false seams while leaving externally timed effects in the facade."
requirements-completed: [UPLOAD-01, SAFE-01]
coverage:
  - id: D1
    description: "PATCH retains bounded per-request streaming, temporary-file cleanup, adapter-polymorphic state dispatch, facade persistence, and completion sequencing through TusStream."
    requirement: UPLOAD-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/tus_local_backing_test.exs test/rindle/api_surface_boundary_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "DELETE retains auth-before-storage, backing-before-row ordering, bounded retry markers, and distinct backing/DB failure contracts through TusTermination."
    requirement: UPLOAD-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "TusStream and TusTermination callable seams are compiled-hidden while TusPlug remains visible."
    requirement: SAFE-01
    verification:
      - kind: other
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-08-23
status: complete
---

# Phase 124 Plan 03: Upload Path Clarity Summary

**TusStream and TusTermination now own bounded polymorphic storage and abort mechanics, with TusPlug retaining all externally observable ordering and responses.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-08-23T03:50:00Z
- **Completed:** 2026-08-23T03:58:00Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Moved the real PATCH drain loop, byte ceilings, checksum finalization, per-PATCH temporary-file lifecycle, persisted part-state codec, and adapter stream/completion calls to hidden `TusStream`.
- Kept PATCH persistence, broadcast-before-telemetry timing, Broker completion convergence, and all 204/5xx responses in `TusPlug`.
- Moved backing abort dispatch, safe warning logging, and exact bounded reaper marker construction to hidden `TusTermination` while preserving auth-before-storage and backing-before-row order.
- Added compiled-metadata coverage for all new hidden seams; no source-text snapshots were added.

## Task Commits

1. **Task 1: Move real bounded PATCH storage mechanics behind the ordered facade** — `6f4c123` (test), `84e7581` (feat)
2. **Task 2: Extract DELETE abort mechanics and retain the two failure contracts** — `69b5d1a` (test), `50315da` (feat)

## Files Created/Modified

- `lib/rindle/upload/tus_stream.ex` — hidden bounded PATCH storage and adapter dispatch mechanics.
- `lib/rindle/upload/tus_termination.ex` — hidden abort dispatch and retry-marker mechanics.
- `lib/rindle/upload/tus_plug.ex` — visible protocol façade retaining effects ordering and responses.
- `test/rindle/api_surface_boundary_test.exs` — compiled-doc boundary proof for hidden callable seams.

## Verification

- `MIX_ENV=test mix compile --force --warnings-as-errors` — passed.
- `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/tus_local_backing_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` — 65 tests, 0 failures.
- `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs --seed 0` — 41 tests, 0 failures.
- `bash scripts/maintainer/refactor_contract.sh` — 91 contract tests, 0 failures; no compile cycles.
- `git diff --quiet main...HEAD -- mix.exs mix.lock priv/repo/migrations .github/workflows lib/rindle/admin` — passed.
- S3/MinIO gate was not run locally: no MinIO/S3 environment variables were provisioned. Its authoritative `test/rindle/upload/tus_s3_integration_test.exs --include minio --seed 0` gate remains in final PR Integration/CI Summary verification.

## Decisions Made

- `TusStream` returns only adapter part state or an existing tagged error; `TusPlug` converts that state to a row update and controls later events and responses.
- `TusTermination` returns only abort attrs; `TusPlug` still owns authentication, authorization, aborted-row updates, cancellation broadcasts, and client status construction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed a facade-private call-option helper made unused by the PATCH extraction**
- **Found during:** Task 1
- **Issue:** Moving all adapter call construction to `TusStream` left `TusPlug.maybe_put_opt/3` unused, which would fail the required warnings-as-errors compile.
- **Fix:** Removed the obsolete private helper from `TusPlug`.
- **Files modified:** `lib/rindle/upload/tus_plug.ex`
- **Verification:** Forced warnings-as-errors compile passed.
- **Committed in:** `84e7581`

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** Required cleanup only; no behavior or public-surface change.

## Known Stubs

None.

## Issues Encountered

No local MinIO/S3 environment was available, so the environment-provisioned adapter proof remains a final CI authority as planned.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

PATCH and DELETE storage effects now have cohesive hidden owners without changing facade timing. The Broker-focused plans can proceed while retaining this same compiled-hidden collaborator boundary.

## Self-Check: PASSED

- All four planned source/proof files exist.
- Task commits `6f4c123`, `84e7581`, `69b5d1a`, and `50315da` exist.
