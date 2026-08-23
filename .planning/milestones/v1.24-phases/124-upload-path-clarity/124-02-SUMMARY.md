---
phase: 124-upload-path-clarity
plan: "02"
subsystem: upload
tags: [elixir, plug, tus, protocol, hmac, compiled-docs]
requires:
  - phase: 124-upload-path-clarity
    provides: hidden TusCreation collaborator and visible TusPlug facade boundary
provides:
  - Hidden TusProtocol owner for signed-token, header parsing, normalization, and status vocabulary mechanics
  - Facade-preserved token-to-session-to-authorizer and PATCH gate ordering
  - Compiled-doc and behavior proof for hidden protocol seams and deferred PATCH rejection
affects: [124-03, upload-path-clarity, tus, resumable-upload]
tech-stack:
  added: []
  patterns: [visible Plug facade with hidden protocol collaborator, facade-owned persistence and response construction]
key-files:
  created: [lib/rindle/upload/tus_protocol.ex]
  modified: [lib/rindle/upload/tus_plug.ex, test/rindle/upload/tus_plug_test.exs, test/rindle/api_surface_boundary_test.exs]
key-decisions:
  - "TusProtocol receives only Plug header/path input plus explicit resolved secret or limits; it never loads sessions, authorizes actors, persists, streams, or sends responses."
  - "TusPlug retains its ordered request pipeline and rejects a deferred-length header on PATCH before a row update or stream begins."
patterns-established:
  - "Hidden collaborator seams use @moduledoc false and @doc false while public facades retain their compiled docs."
requirements-completed: [UPLOAD-01, SAFE-01]
coverage:
  - id: D1
    description: "Tus token verification, HEAD vocabulary, and authoritative offset stay behind the visible Plug facade with unchanged statuses and headers."
    requirement: UPLOAD-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/api_surface_boundary_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "PATCH content-type, offset, deferred-length, checksum, and max-size gates retain pre-stream and pre-persistence behavior."
    requirement: UPLOAD-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "TusProtocol and all callable seams are compiled-hidden while TusPlug remains visible."
    requirement: SAFE-01
    verification:
      - kind: other
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-08-23
status: complete
---

# Phase 124 Plan 02: Upload Path Clarity Summary

**TusProtocol now centrally owns tus token, header parsing, normalization, and status vocabulary while TusPlug retains request ordering, authorization, persistence, streaming, and HTTP responses.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-08-23T03:34:00Z
- **Completed:** 2026-08-23T03:47:49Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Extracted HMAC token verification, expiry validation, HEAD metadata, response-status mapping, and location/date formatting to hidden TusProtocol seams.
- Routed POST and PATCH parsing through TusProtocol while retaining the facade's token → session → authorizer → content type → offset → persistence → checksum → stream sequence.
- Added compiled-doc proof for the full hidden collaborator surface and behavior proof that a PATCH cannot substitute `Upload-Defer-Length` for its required `Upload-Length`.

## Task Commits

1. **Task 1: Extract token and HEAD protocol mechanics without weakening authorization order** — `70f5be4` (test), `7af6e89` (feat)
2. **Task 2: Extract ordered PATCH and creation parsing vocabulary** — `b58d323` (test), `db54d98` (fix)

## Files Created/Modified

- `lib/rindle/upload/tus_protocol.ex` — hidden token, parsing, normalization, status, date, and location mechanics.
- `lib/rindle/upload/tus_plug.ex` — visible facade delegates protocol mechanics but retains ordering, mutation, streaming, and responses.
- `test/rindle/upload/tus_plug_test.exs` — deferred PATCH gate regression proof.
- `test/rindle/api_surface_boundary_test.exs` — compiled visibility proof for every callable TusProtocol seam.

## Verification

- `MIX_ENV=test mix compile --force --warnings-as-errors` — passed.
- `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` — 62 tests, 0 failures.
- `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs --seed 0` — 41 tests, 0 failures.
- `bash scripts/maintainer/refactor_contract.sh` — 89 contract tests, 0 failures; no cycles found.
- `git diff --quiet main...HEAD -- mix.exs mix.lock priv/repo/migrations .github/workflows lib/rindle/admin` — passed.

## Decisions Made

- TusProtocol accepts only request/header input and explicitly supplied values, keeping all session lookup, authorizer invocation, persistence, storage, and final response construction in TusPlug.
- The facade preserves the original PATCH-only length rule by accepting only an integer result from its protocol parser before persisting a deferred session length.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved the PATCH-only deferred-length rejection after parser extraction**
- **Found during:** Task 2
- **Issue:** Reusing the creation parser allowed `Upload-Defer-Length: 1` on a deferred PATCH to reach integer persistence.
- **Fix:** Added a behavior regression test and made TusPlug reject the parser's deferred result before persistence or streaming.
- **Files modified:** `lib/rindle/upload/tus_plug.ex`, `test/rindle/upload/tus_plug_test.exs`
- **Verification:** Focused TusPlug suite and SAFE-01 passed.
- **Committed in:** `b58d323`, `db54d98`

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** Required behavior preservation with no public API or protocol expansion.

## Known Stubs

None.

## Issues Encountered

The new behavior test caught the parser-boundary regression before it could change the PATCH response contract.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Tus protocol vocabulary is now independently readable behind the facade. PATCH streaming/storage and DELETE termination extractions can preserve the same explicit facade-owned effect ordering.

## Self-Check: PASSED

- `lib/rindle/upload/tus_protocol.ex` exists.
- Task commits `70f5be4`, `7af6e89`, `b58d323`, and `db54d98` exist.
