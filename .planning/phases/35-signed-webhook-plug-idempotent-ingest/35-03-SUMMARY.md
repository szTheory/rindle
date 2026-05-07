---
phase: 35-signed-webhook-plug-idempotent-ingest
plan: 03
subsystem: testing

tags:
  - test-helpers
  - fixtures
  - hmac
  - signing
  - replay-attacks
  - mux-webhooks
  - test-infrastructure

# Dependency graph
requires:
  - phase: 34-mux-rest-adapter-server-push-sync
    provides: "Mux.Webhooks.verify_header/4 SDK call site (used in helper round-trip test); webhook_video_asset_{ready,errored,created}.json placeholder fixtures."
provides:
  - "Rindle.Test.MuxWebhookFixtures.sign_header/3 — HMAC signing helper with :timestamp override (centralizes the recipe)."
  - "test/fixtures/mux/webhook_video_asset_deleted.json — sparse {id, status: deleted} fixture (D-36)."
  - "test/fixtures/mux/webhook_video_upload_asset_created.json — typed-branch fixture with distinct data.id (upload-id) and data.asset_id (asset-id) for D-29."
  - "Realistic 36-char Mux-style asset IDs in webhook_video_asset_{ready,errored,created}.json (replaces AbCd1234 placeholder)."
  - "Replaced two handrolled :crypto.mac/4 + Base.encode16 blocks in mux_test.exs with single sign_header/3 calls (HMAC recipe lives in one place)."
affects:
  - "35-02 (Wave 2) — IngestProviderWebhook worker tests will consume MuxWebhookFixtures.sign_header/3 for end-to-end Plug tests AND webhook_video_upload_asset_created.json for the D-29 typed-branch event_test.exs case."
  - "Phase 36 — may promote MuxWebhookFixtures from @moduledoc false to documented test helper if adopters need it."

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Centralized HMAC signing recipe — keep the byte-accurate :crypto.mac(:hmac, :sha256, ...) → Base.encode16(case: :lower) algorithm in exactly one place (Rindle.Test.MuxWebhookFixtures), not duplicated across test files."
    - "Test helper as :timestamp-override wrapper around SDK helpers — when an SDK helper hardcodes a value useful in production but unhelpful for security tests, wrap it with an opt-keyword override."
    - "Realistic fixture IDs — use 36-char Mux-style suffixes (rdy/err/crt/del/upl) per fixture so test debugging doesn't blur which fixture loaded."

key-files:
  created:
    - "test/support/mux_webhook_fixtures.ex — HMAC test signing helper."
    - "test/rindle/test/mux_webhook_fixtures_test.exs — 5 unit tests proving SDK byte-accuracy + replay rejection."
    - "test/fixtures/mux/webhook_video_asset_deleted.json — sparse deletion fixture."
    - "test/fixtures/mux/webhook_video_upload_asset_created.json — D-29 typed-branch fixture."
    - ".planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md — pre-existing format drift in unrelated lib/ files (out of scope)."
  modified:
    - "test/fixtures/mux/webhook_video_asset_ready.json — realistic asset id (rdy suffix)."
    - "test/fixtures/mux/webhook_video_asset_errored.json — realistic asset id (err suffix)."
    - "test/fixtures/mux/webhook_video_asset_created.json — realistic asset id (crt suffix)."
    - "test/rindle/streaming/provider/mux/mux_test.exs — add MuxWebhookFixtures alias; replace two handrolled HMAC blocks (lines ~174-181 and ~232-241) with single sign_header/3 calls; update two BL-03 assertions to match the new asset id in the created fixture."

key-decisions:
  - "sign_header/3 module is @moduledoc false (Claude's discretion per CONTEXT.md): test-only surface; Phase 36 may promote if adopters need to pre-sign webhook fixtures in their own tests."
  - "Replaced BOTH handrolled HMAC blocks in mux_test.exs (the plan called out 174-181 explicitly; 232-241 in BL-03 is the same recipe and same Rule 1 'one place' rationale)."
  - "Updated two BL-03 assertions in mux_test.exs (lines 206, 248) to match the new asset id in webhook_video_asset_created.json — direct downstream consequence of the fixture ID swap, bundled into the Task 2 commit."
  - "Per-fixture suffix scheme on the realistic asset IDs (rdy/err/crt/del/upl) makes test traceability obvious without cross-referencing constants."

patterns-established:
  - "Test helper layout — test/support/<feature>.ex with @moduledoc false; corresponding test at test/rindle/test/<feature>_test.exs to lock the contract."
  - "SDK round-trip test — helper produces a header, SDK Mux.Webhooks.verify_header/4 verifies it, prove byte-accuracy without re-implementing the verifier in test."
  - "Replay-attack test — sign with timestamp: now - 600, verify with tolerance: 300, assert {:error, _}. Pattern Plan 35-02 will reuse for end-to-end Plug tests."

requirements-completed:
  - MUX-09
  - MUX-10
  - MUX-11
  - MUX-12
  - MUX-13

# Metrics
duration: 6min
completed: 2026-05-07
---

# Phase 35 Plan 03: Mux Webhook Test Fixtures + Signing Helper Summary

**Centralizes the Mux HMAC test-signing recipe in `Rindle.Test.MuxWebhookFixtures.sign_header/3` (with `:timestamp` override for replay-attack tests), adds 2 new fixtures (`webhook_video_asset_deleted.json` sparse + `webhook_video_upload_asset_created.json` D-29 typed-branch), upgrades 3 existing fixtures to realistic 36-char Mux-style asset IDs, and removes both handrolled `:crypto.mac/4` blocks from `mux_test.exs`.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-05-07T02:24:43Z
- **Completed:** 2026-05-07T02:30:58Z
- **Tasks:** 3
- **Files modified:** 8 (2 helper-related new, 5 fixtures, 1 test file edit) + 1 deferred-items.md

## Accomplishments

- `Rindle.Test.MuxWebhookFixtures.sign_header/3` ships with byte-accurate SDK compatibility (verified by round-tripping through `Mux.Webhooks.verify_header/4`) and a `:timestamp` override that makes replay-attack tests possible.
- 5 unit tests in `test/rindle/test/mux_webhook_fixtures_test.exs` lock the helper contract: header shape, override, SDK round-trip, replay rejection, per-secret variance.
- `webhook_video_asset_deleted.json` (sparse `{id, status: "deleted"}`) and `webhook_video_upload_asset_created.json` (distinct `data.id` upload-id vs `data.asset_id` asset-id, exercising D-29) are committed so Plan 02 can consume them in Wave 2.
- 3 pre-existing webhook fixtures upgraded from the placeholder `AbCd1234EfGh5678IjKl9012MnOp3456QrSt` to realistic 36-char Mux-style IDs with per-fixture suffixes (`rdy`, `err`, `crt`).
- HMAC recipe is now in exactly one place — both handrolled `:crypto.mac(:hmac, :sha256, ...)` blocks in `mux_test.exs` are replaced with single calls to `MuxWebhookFixtures.sign_header/3`.
- 18/18 tests in `mux_test.exs` pass; 5/5 helper unit tests pass; 43/43 streaming tests pass overall — no regressions introduced by the fixture ID swap.

## Task Commits

Each task was committed atomically. Task 1 follows TDD (RED → GREEN; no refactor needed):

1. **Task 1 RED: failing helper test** — `3ccb664` (test)
2. **Task 1 GREEN: implement sign_header/3** — `a564596` (feat)
3. **Task 2: new fixtures + realistic IDs + downstream assertion sync** — `9cc374e` (feat)
4. **Task 3: replace handrolled HMAC** — `c84e51b` (refactor)

**Plan metadata commit:** to follow (this SUMMARY).

## Files Created/Modified

**Created:**
- `test/support/mux_webhook_fixtures.ex` — `Rindle.Test.MuxWebhookFixtures.sign_header/3` HMAC signing helper (`@moduledoc false`).
- `test/rindle/test/mux_webhook_fixtures_test.exs` — 5 unit tests covering header format, `:timestamp` override, SDK byte-accuracy, replay rejection, per-secret variance.
- `test/fixtures/mux/webhook_video_asset_deleted.json` — sparse deletion fixture.
- `test/fixtures/mux/webhook_video_upload_asset_created.json` — D-29 typed-branch fixture (data.id != data.asset_id).
- `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` — logs unrelated `mix format --check-formatted` drift in `lib/rindle/ops/lifecycle_repair.ex` and `lib/rindle/processor/av/video.ex` (out of Plan 03 scope).

**Modified:**
- `test/fixtures/mux/webhook_video_asset_ready.json` — `00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKrdy017A`.
- `test/fixtures/mux/webhook_video_asset_errored.json` — `00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKerr017A`.
- `test/fixtures/mux/webhook_video_asset_created.json` — `00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKcrt017A`.
- `test/rindle/streaming/provider/mux/mux_test.exs` — add `alias Rindle.Test.MuxWebhookFixtures`; replace two handrolled `:crypto.mac(:hmac, :sha256, secret, signed_payload) |> Base.encode16(case: :lower)` blocks with single `MuxWebhookFixtures.sign_header(body, secret)` calls; update two BL-03 assertions (lines 206, 248) to match the new asset id in the `created` fixture.

## Decisions Made

- **Both HMAC blocks replaced (not just lines 174-181).** The plan called out one block; a second handrolled HMAC at lines 232-241 (BL-03 describe block) used the identical recipe. Per Rule 1 "keep recipe in one place" rationale (D-34), replaced both. Plan acceptance criteria still satisfied — both pre-replacement blocks are gone (`grep ':crypto.mac(:hmac, :sha256, secret, signed_payload)' mux_test.exs` returns 0).
- **Two BL-03 assertions in `mux_test.exs` updated to match the new asset id.** Lines 206 and 248 asserted `evt.provider_asset_id == "AbCd1234..."` while loading `webhook_video_asset_created.json` — once the fixture's asset id is realistic Mux-style, the assertion must be updated to match. Bundled into the Task 2 commit so the fixture change and its consequent assertion change are atomic.
- **Comment trimmed in helper module** to keep the `:crypto.mac(:hmac, :sha256, ...)` literal pattern present exactly once (1 occurrence of the literal call, not 2 — was 2 because the doc-comment also mentioned the recipe verbatim). Acceptance criterion `grep -c ':crypto.mac(:hmac, :sha256' returns 1` honored.
- **`@moduledoc false`** chosen for the helper module per CONTEXT.md "Claude's discretion" guidance for test-only support code (D-46-adjacent). Phase 36 may promote if external adopters need to pre-sign their own webhook fixtures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated 2 BL-03 assertions in `mux_test.exs` to match the new asset id in `webhook_video_asset_created.json`.**
- **Found during:** Task 2 (fixture realistic-ID swap).
- **Issue:** `mux_test.exs:206` and `mux_test.exs:248` asserted `evt.provider_asset_id == "AbCd1234EfGh5678IjKl9012MnOp3456QrSt"` while reading the `created` fixture; updating the fixture without updating these assertions would have broken the BL-03 regression tests.
- **Fix:** Replaced both literal asset id strings with the new fixture id `00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKcrt017A`.
- **Files modified:** `test/rindle/streaming/provider/mux/mux_test.exs` (2 string-literal updates).
- **Verification:** `mix test test/rindle/streaming/provider/mux/mux_test.exs` — 18 tests, 0 failures.
- **Committed in:** `9cc374e` (Task 2 commit).

**2. [Rule 1 - Bug] Replaced second handrolled HMAC block (`mux_test.exs:232-241`) in addition to the plan-called-out 174-181.**
- **Found during:** Task 3 (HMAC handrolled block replacement).
- **Issue:** The plan called out the HMAC block at lines 174-181 explicitly; a second identical handrolled block lived in the BL-03 describe block at lines 232-241. Per the plan's own D-34 rationale ("keep the recipe in one place"), leaving the second block would defeat the centralization goal.
- **Fix:** Replaced both blocks with single `MuxWebhookFixtures.sign_header(body, secret)` calls.
- **Files modified:** `test/rindle/streaming/provider/mux/mux_test.exs`.
- **Verification:** `grep -c ':crypto.mac(:hmac, :sha256, secret, signed_payload)' test/rindle/streaming/provider/mux/mux_test.exs` returns 0; all 18 mux_test.exs tests pass.
- **Committed in:** `c84e51b` (Task 3 commit).

**3. [Rule 3 - Blocking] Pre-existing `mix format --check-formatted` drift in unrelated `lib/` files surfaced during verification.**
- **Found during:** Task 3 verification (`mix format --check-formatted` exit 1).
- **Issue:** `lib/rindle/ops/lifecycle_repair.ex` and `lib/rindle/processor/av/video.ex` (and possibly more) report formatting drift on `main` (commit 1768567 base) — NOT introduced by Plan 03.
- **Fix:** Out of scope per execute-plan scope boundary. Logged to `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` and confirmed Plan 03's own files (`test/support/mux_webhook_fixtures.ex`, `test/rindle/test/mux_webhook_fixtures_test.exs`, `test/rindle/streaming/provider/mux/mux_test.exs`, all 5 fixture JSONs) all pass `mix format --check-formatted` cleanly when run scoped to those paths.
- **Files modified:** `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` (new tracking file).
- **Verification:** `mix format --check-formatted test/support/mux_webhook_fixtures.ex test/rindle/test/mux_webhook_fixtures_test.exs test/rindle/streaming/provider/mux/mux_test.exs` exit 0.
- **Committed in:** Will land with this SUMMARY.md commit.

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs that were direct downstream consequences of plan-prescribed changes, 1 Rule 3 out-of-scope discovery deferred).
**Impact on plan:** All three are necessary for plan-prescribed work to verify cleanly. No scope creep; the BL-03 assertion update and second HMAC block replacement are direct consequences of the plan's own D-34/D-36 directives. The format drift is pre-existing and tracked for v1.7 polish.

## Issues Encountered

- `event_test.exs` referenced in plan `<verify>` block does not exist yet — Plan 02 (Wave 2) creates it. Plan 03 cannot verify against it. Confirmed expected behavior: `event_test.exs` is part of Plan 02's contract; Plan 03's contract is satisfied by `mux_webhook_fixtures_test.exs` + `mux_test.exs` passing.

## User Setup Required

None — Plan 03 is purely test infrastructure (helper module + fixtures + test refactor). No external services, no env vars, no dashboard config.

## Next Phase Readiness

**Wave 2 (Plan 02 — IngestProviderWebhook worker + Event.normalize/1 typed branch):** ready to consume both deliverables.
- `Rindle.Test.MuxWebhookFixtures.sign_header/3` available via `alias Rindle.Test.MuxWebhookFixtures` in any `:test`-env file (test/support is wired into elixirc_paths).
- `webhook_video_upload_asset_created.json` ready for the D-29 typed-branch event_test.exs case (`evt.provider_asset_id == data.asset_id`, `evt.upload_id == data.id`).
- `webhook_video_asset_deleted.json` ready for the sparse-data deletion test case in event_test.exs.
- Replay-attack test pattern (`timestamp: now - 600` + verify with `tolerance: 300` → `{:error, _}`) is locked in helper test 4 — Plan 02's end-to-end Plug tests can reuse it.

No blockers.

## Self-Check: PASSED

All 7 created/modified files exist on disk:
- `test/support/mux_webhook_fixtures.ex` — FOUND
- `test/rindle/test/mux_webhook_fixtures_test.exs` — FOUND
- `test/fixtures/mux/webhook_video_asset_deleted.json` — FOUND
- `test/fixtures/mux/webhook_video_upload_asset_created.json` — FOUND
- `test/fixtures/mux/webhook_video_asset_ready.json` — FOUND
- `test/fixtures/mux/webhook_video_asset_errored.json` — FOUND
- `test/fixtures/mux/webhook_video_asset_created.json` — FOUND

All 4 task commits present in `git log --oneline --all`:
- `3ccb664` (test, RED)
- `a564596` (feat, GREEN)
- `9cc374e` (feat, fixtures + assertion sync)
- `c84e51b` (refactor, HMAC swap)

`mux_test.exs` BL-03 assertions updated:
- 2 occurrences of the new asset id `00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKcrt017A`.

---
*Phase: 35-signed-webhook-plug-idempotent-ingest*
*Plan: 03 (Wave 1)*
*Completed: 2026-05-07*
