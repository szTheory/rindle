---
phase: 124-upload-path-clarity
plan: "01"
subsystem: upload
tags: [elixir, plug, tus, hmac, upload-session, compiled-docs]
requires:
  - phase: 123-runtime-operations-decomposition
    provides: stable facade-plus-hidden-collaborator extraction precedent
provides:
  - Hidden TusCreation owner for tus session initiation, signing, and redacting URI persistence
  - Hidden concatenation owner preserving ordered token validation and Broker completion
  - Compiled-doc boundary proof for hidden creation seams and visible facades
affects: [124-02, upload-path-clarity, tus, broker]
tech-stack:
  added: []
  patterns: [visible Plug facade with hidden cohesive mechanics collaborator, compiled-doc boundary proof]
key-files:
  created: [lib/rindle/upload/tus_creation.ex]
  modified: [lib/rindle/upload/tus_plug.ex, test/rindle/api_surface_boundary_test.exs]
key-decisions:
  - "TusPlug retains protocol dispatch and Plug.Conn response construction; TusCreation owns broker initiation, claims, signing, redacting persistence, and final concatenation mechanics."
  - "The collaborator remains compiled-hidden with @moduledoc false and @doc false callable seams, while TusPlug and Broker remain visible."
patterns-established:
  - "Pass resolved base path, profile, actor, secret, content type, length, and options into hidden tus mechanics rather than passing Plug.Conn."
requirements-completed: [UPLOAD-01, UPLOAD-02, SAFE-01]
coverage:
  - id: D1
    description: "Normal tus POST and public creation retain the signed 201 response, persisted redacting session URI, and protocol headers through TusCreation."
    requirement: UPLOAD-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/api_surface_boundary_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Partial and final concatenation retain ordered signed-token validation and the Broker completion lane behind TusCreation."
    requirement: UPLOAD-02
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "TusCreation and both callable seams are compiled-hidden while TusPlug and Broker remain visible."
    requirement: SAFE-01
    verification:
      - kind: unit
        ref: "test/rindle/api_surface_boundary_test.exs#tus creation mechanics stay hidden behind the visible Plug and Broker facades"
        status: pass
      - kind: other
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-08-23
status: complete
---

# Phase 124 Plan 01: Upload Path Clarity Summary

**A hidden TusCreation collaborator now owns tus session creation, HMAC URL signing, redacting persistence, and final concatenation while the public Plug and Broker contracts remain unchanged.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-23T03:34:00Z
- **Completed:** 2026-08-23T03:41:11Z
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Routed normal POST creation and `Rindle.initiate_tus_upload/2` through the hidden mechanics owner without changing response construction, claims, expiry, or redacting session URI persistence.
- Moved partial/final concatenation token parsing, ordered validation, Broker invocation, signing, and persistence into the same collaborator.
- Added compiled-doc proof that TusCreation and both callable seams are hidden while TusPlug and Broker remain visible.

## Task Commits

1. **Task 1: Trace one normal POST through hidden creation mechanics** — `857d7c1` (test), `c4c9604` (feat)
2. **Task 2: Complete partial and final concatenation ownership** — `0b66373` (test), `d1150f7` (feat)

## Files Created/Modified

- `lib/rindle/upload/tus_creation.ex` — hidden cohesive owner for broker initiation, signed claims, URI persistence, and concatenation.
- `lib/rindle/upload/tus_plug.ex` — stable Plug facade delegates creation mechanics while retaining dispatch and HTTP responses.
- `test/rindle/api_surface_boundary_test.exs` — compiled metadata proof for module and seam visibility.

## Verification

- `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` — 60 tests, 0 failures.
- `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs --seed 0` — 40 tests, 0 failures.
- `bash scripts/maintainer/refactor_contract.sh` — 88 contract tests, 0 failures; no cycles found.
- `MIX_ENV=test mix compile --force --warnings-as-errors` — passed.
- `git diff --quiet main...HEAD -- mix.exs mix.lock priv/repo/migrations .github/workflows lib/rindle/admin` — passed.

## Decisions Made

- TusPlug remains the public protocol facade and constructs all HTTP responses; TusCreation takes only resolved inputs and never receives Plug.Conn.
- Broker remains the lifecycle/persistence boundary; TusCreation calls its existing public initiation and concatenation APIs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed facade-private signing helpers made unused by the concatenation extraction**
- **Found during:** Task 2
- **Issue:** The warnings-as-errors compile reported the obsolete `maybe_put_content_type/2` and `join_upload_url/2` helpers in TusPlug.
- **Fix:** Removed the duplicate private helpers after their mechanics moved to TusCreation.
- **Files modified:** `lib/rindle/upload/tus_plug.ex`
- **Verification:** Forced warnings-as-errors compile passed.
- **Committed in:** `d1150f7`

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** Required cleanup after the planned extraction; no behavioral or public-surface expansion.

## Known Stubs

None.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Tus creation and concatenation mechanics now have a single hidden owner. Later upload-path plans can use the same facade-plus-hidden-collaborator boundary without changing tus wire or Broker contracts.

## Self-Check: PASSED

- `lib/rindle/upload/tus_creation.ex` exists.
- Task commits `857d7c1`, `c4c9604`, `0b66373`, and `d1150f7` exist.
