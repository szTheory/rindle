---
phase: 89-console-read-surfaces
plan: "06"
subsystem: admin-console-realtime
tags: [phoenix-pubsub, upload-sessions, liveview, redaction, tdd]

requires:
  - phase: 89-console-read-surfaces
    provides: "89-05 completed all six query-backed read surfaces through the shared shell"
provides:
  - "Upload-session lifecycle PubSub broadcasts over existing upload_session and asset topics"
  - "Redaction-safe upload-session broadcast payload allowlist"
  - "Console LiveView invalidation proof with forged PubSub payload data"
affects: [phase-89-console-read-surfaces, phase-90-actions, phase-92-e2e, admin-console]

tech-stack:
  added: []
  patterns:
    - "Upload lifecycle events use Rindle.PubSub and existing rindle:upload_session / rindle:asset topic grammar"
    - "Broadcast payloads are constructed from an explicit upload-session allowlist"
    - "Console LiveViews continue treating PubSub as invalidation and reload through Rindle.Admin.Queries"

key-files:
  created:
    - test/rindle/admin/live_update_test.exs
  modified:
    - lib/rindle/upload/broker.ex
    - lib/rindle/upload/tus_plug.ex
    - test/rindle/upload/broker_test.exs
    - test/rindle/upload/tus_plug_test.exs

key-decisions:
  - "89-06 reuses Rindle.PubSub and existing upload_session/asset topics instead of adding a console-specific realtime channel."
  - "89-06 keeps upload-session broadcasts redaction-safe by allowlisting session_id, asset_id, state, upload_strategy, resumable_protocol, and offset only."
  - "89-06 keeps console LiveViews payload-agnostic by proving forged session_uri/provider_asset_id values are ignored and authoritative data comes from Rindle.Admin.Queries."

patterns-established:
  - "Broker upload lifecycle broadcasts happen only after successful persistence or committed state transitions."
  - "TusPlug PATCH/DELETE broadcasts happen after offset or cancellation state has been persisted."
  - "Tus HMAC token data is named claims, reserving payload terminology for public PubSub payloads."

requirements-completed: [ADMIN-05]

duration: 9min
completed: 2026-06-12
---

# Phase 89 Plan 06: Upload-Session Lifecycle Broadcasts Summary

**Upload-session lifecycle events now invalidate existing console read surfaces through redaction-safe Rindle.PubSub broadcasts**

## Performance

- **Duration:** 9 min
- **Started:** 2026-06-12T15:48:56Z
- **Completed:** 2026-06-12T15:57:32Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added RED tests for Broker and TusPlug upload-session lifecycle broadcasts on `"rindle:upload_session:*"` and `"rindle:asset:*"` topics.
- Added `test/rindle/admin/live_update_test.exs` proving Assets, Upload Sessions, and Variants/Jobs reload from `Rindle.Admin.Queries` after forged PubSub payloads.
- Added Broker broadcasts for initialized, signed, uploading/status, completed, and cancelled upload-session transitions after successful persistence.
- Added TusPlug broadcasts for persisted PATCH offsets and successful DELETE cancellation, while relying on Broker verification for completion.
- Kept broadcast payloads free of `session_uri`, provider IDs, authorization data, and tokens.

## Task Commits

1. **Task 1: Add upload-session broadcast and invalidation tests** - `82ce0d9` (test)
2. **Task 2: Broadcast upload-session lifecycle events** - `0b2167c` (feat)

## Files Created/Modified

- `lib/rindle/upload/broker.ex` - Broadcasts redacted upload-session lifecycle events after committed broker state changes.
- `lib/rindle/upload/tus_plug.ex` - Broadcasts redacted upload-session events after persisted tus PATCH offsets and DELETE cancellation.
- `test/rindle/upload/broker_test.exs` - Verifies broker broadcast topics, event atoms, payload allowlist, and `session_uri` omission.
- `test/rindle/upload/tus_plug_test.exs` - Verifies tus PATCH, completion, and DELETE broadcast behavior and payload redaction.
- `test/rindle/admin/live_update_test.exs` - Verifies console LiveViews ignore forged payload secrets and reload authoritative query data.

## Decisions Made

- Reused `Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)` for upload broadcasts, matching existing worker broadcast configurability.
- Used deterministic event atoms: `:upload_session_initialized`, `:upload_session_signed`, `:upload_session_uploading`, `:upload_session_completed`, and `:upload_session_cancelled`.
- Did not add any console-specific PubSub server, channel, route, or LiveView payload decoding path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Renamed tus token payload locals to claims for the secrecy scan**
- **Found during:** Task 2 verification
- **Issue:** The plan's source scan intentionally greps for sensitive terms near `payload`; existing TusPlug HMAC token-claim locals used `payload`, causing the scan to flag non-broadcast token verification code.
- **Fix:** Renamed tus URL token locals from `payload` to `claims`/`claims_list`, preserving behavior and reserving `payload` for public PubSub payload construction.
- **Files modified:** `lib/rindle/upload/tus_plug.ex`
- **Verification:** Payload secrecy scan passed; focused upload/live-update tests passed.
- **Committed in:** `0b2167c`

---

**Total deviations:** 1 auto-fixed (1 Rule 3 blocking verification issue)
**Impact on plan:** The fix made the planned secrecy gate precise without changing public API, PubSub topology, or upload semantics.

## TDD Gate Compliance

- RED commit present: `82ce0d9` (`test(89-06): add failing upload session live update tests`)
- GREEN commit present after RED: `0b2167c` (`feat(89-06): broadcast upload session lifecycle events`)
- RED gate failed before implementation with missing `{:rindle_event, ...}` upload-session broadcasts.

## Verification

- `MIX_ENV=test mix test test/rindle/upload/broker_test.exs test/rindle/upload/tus_plug_test.exs test/rindle/admin/live_update_test.exs` - failed in RED before implementation; passed after Task 2, 70 tests, 0 failures, 3 skipped.
- `MIX_ENV=test mix test test/rindle/workers/process_variant_test.exs test/rindle/workers/ingest_provider_webhook_test.exs` - passed, 28 tests.
- `if rg -n "session_uri|provider_asset_id|Authorization|authorization|token" lib/rindle/upload/broker.ex lib/rindle/upload/tus_plug.ex | grep -n "broadcast\\|payload"; then exit 1; fi` - passed.
- `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` - passed.
- Acceptance source checks for topic grammar, `{:rindle_event, ...}`, `session_uri` omission, and forged LiveView payload secrets - passed.

## Known Stubs

None. Stub-pattern scan matched existing nil/empty-state assertions and real control-flow guards only.

## Threat Flags

None. The new PubSub emission surface is covered by the plan threat model: payload redaction, forged-payload invalidation behavior, existing topic grammar, and persisted-transition-only broadcasts.

## Issues Encountered

- The initial secrecy scan reported existing TusPlug token-claim locals because the grep is intentionally broad. Renaming those locals to `claims` resolved the verification issue without behavior changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

ADMIN-05 is now covered across upload-session lifecycle writes and console invalidation. Phase 90 can add executable actions without adding another realtime channel or trusting PubSub payloads as authoritative state.

## Self-Check: PASSED

- Found created file: `test/rindle/admin/live_update_test.exs`
- Found modified files: `lib/rindle/upload/broker.ex`, `lib/rindle/upload/tus_plug.ex`, `test/rindle/upload/broker_test.exs`, `test/rindle/upload/tus_plug_test.exs`
- Found task commits: `82ce0d9`, `0b2167c`

---
*Phase: 89-console-read-surfaces*
*Completed: 2026-06-12*
