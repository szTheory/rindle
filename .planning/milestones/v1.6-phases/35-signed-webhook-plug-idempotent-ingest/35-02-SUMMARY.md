---
phase: 35-signed-webhook-plug-idempotent-ingest
plan: 02
subsystem: workers

tags:
  - oban
  - worker
  - idempotency
  - fsm
  - pubsub
  - telemetry
  - redaction
  - race-snooze
  - event-dispatch
  - normalize
  - upload-asset-created
  - end-to-end
  - webhook
  - hmac
  - replay-protection

# Dependency graph
requires:
  - phase: 33-streaming-provider-boundary
    provides: "ProviderAssetFSM allowlist with errored -> processing re-ingest edge; MediaProviderAsset schema with redact_id/1; provider_event typespec; @type provider_state vocabulary."
  - phase: 34-mux-rest-adapter-server-push-sync
    provides: "Rindle.Streaming.Provider.Mux.Event.normalize/1 generic clause; Mux.Webhooks.verify_header/4 SDK call site (used in Plug round-trip tests)."
  - phase: 35-signed-webhook-plug-idempotent-ingest (Plan 01, Wave 1)
    provides: "Rindle.Delivery.WebhookPlug + WebhookBodyReader (forward-references Rindle.Workers.IngestProviderWebhook with locked args + unique opts shape); dispatch_kind/1 allowlist on Rindle.Streaming.Provider.Mux."
  - phase: 35-signed-webhook-plug-idempotent-ingest (Plan 03, Wave 1)
    provides: "Rindle.Test.MuxWebhookFixtures.sign_header/3 (consumed by webhook_plug_test.exs end-to-end cases); webhook_video_upload_asset_created.json fixture (consumed by event_test.exs typed-branch case)."

provides:
  - "Rindle.Workers.IngestProviderWebhook — public Oban worker on :rindle_provider queue, max_attempts: 5, timeout 30_000ms, unique on Mux event UUID for 24h, race-snooze [5,15,45,90]s for missing rows, FSM-validate-then-update via Repo.update, two-topic PubSub broadcast (payload omits provider_asset_id), redacted-asset_id telemetry under [:rindle, :provider, :webhook, :processed | :ignored | :exception]."
  - "Rindle.Streaming.Provider.Mux.Event.normalize/1 typed branch for video.upload.asset_created (D-29, BEFORE the generic clause) — reads data.asset_id for provider_asset_id and data.id for upload_id; locks the silent-corruption fix Phase 37 depends on."
  - "Rindle.Streaming.Provider @type provider_event extended with optional :upload_id field (D-30, additive)."
  - "test/rindle/streaming/provider/mux/event_test.exs — 6 tests covering D-29 typed-branch contract + generic-clause regression + invalid-payload."
  - "test/rindle/workers/ingest_provider_webhook_test.exs — 14 tests covering full dispatch table, race-snooze curve, FSM rejection, idempotency, telemetry redaction, two-topic PubSub broadcast, payload contract, repo error path."
  - "test/rindle/delivery/webhook_plug_test.exs — 12 end-to-end cases: 202/200/400/405/500 paths, multi-secret rotation with secret_index telemetry, replay protection (timestamp 600s old -> 400), dispatch_kind drop -> 200 + no Oban work, end-to-end fixture flow into worker + PubSub."

affects:
  - "35-04-runtime-status (Wave 2 sibling) — consumes worker telemetry [:rindle, :provider, :webhook, :exception kind: :race_snooze_exhausted | :invalid_transition] for the --provider-stuck filter."
  - "36-mux-onboarding (next phase) — Rindle.Profile.Presets.MuxWeb + mix rindle.doctor + guides/streaming_providers.md + generated-app mux-enabled CI lane will exercise the worker end-to-end."
  - "37-direct-creator-upload (optional pull-forward) — Phase 37 will REMOVE the no-op branches by promoting :upload_asset_created and :provider_asset_created to broadcast events; the typed branch in normalize/1 is the forward-compat lock."

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Race-snooze pattern (D-21) — first Rindle worker using {:snooze, n}: 5s/15s/45s/90s curve for data-visibility races (webhook arrives before sibling worker's Repo commit visible); cumulative ~155s budget, snoozes don't burn :attempt; on cancel, polling backstop reconciles."
    - "Dispatch-table-as-function-heads (D-27) — perform/1 is a thin entry that pattern-matches event_type via dispatch/3 function heads; each event type has its own clause; default clause handles unknown events as :ignored kind: :unknown_event."
    - "FSM-validate-then-update (mirrors mux_ingest_variant.ex:314-328) — ProviderAssetFSM.transition/3 returns :ok or {:error, {:invalid_transition, _, _}} BEFORE the changeset.update; FSM rejection -> {:cancel, _}; repo error -> {:error, _} so Oban retries with default backoff."
    - "Two-topic PubSub broadcast (D-31) keyed on MediaAsset.id — both topics rindle:provider_asset:#{asset.id} and rindle:asset:#{asset.id} keyed on the parent MediaAsset id (NEVER provider_asset_id). Payload contract (D-32) excludes provider_asset_id; only public playback_ids cross."
    - "Telemetry redaction at every emit site (security invariant 14) — emit/3 routes asset_id through MediaProviderAsset.redact_id/1 before metadata Map.merge with stage-specific kind. Test 14 asserts the redaction prefix '...' is present."
    - "Pattern-match precedence as forward-compat (D-29) — the typed video.upload.asset_created branch is positioned BEFORE the generic clause. If reversed, the generic branch would mis-attribute data.id (upload-id) to provider_asset_id (silent corruption surfacing only when Phase 37 enables direct uploads)."

key-files:
  created:
    - "lib/rindle/workers/ingest_provider_webhook.ex — public Oban worker (425 LOC)"
    - "test/rindle/streaming/provider/mux/event_test.exs — D-29 typed-branch tests (125 LOC, 6 tests)"
    - "test/rindle/workers/ingest_provider_webhook_test.exs — worker dispatch table + edge cases (503 LOC, 14 tests)"
    - "test/rindle/delivery/webhook_plug_test.exs — end-to-end Plug coverage (395 LOC, 12 tests)"
  modified:
    - "lib/rindle/streaming/provider/mux/event.ex — typed branch for video.upload.asset_created (D-29) inserted BEFORE generic clause; new normalize_type/1 clause -> :upload_asset_created"
    - "lib/rindle/streaming/provider.ex — @type provider_event extended with optional(:upload_id) => String.t() | nil (D-30, additive only)"
    - "lib/rindle/delivery/webhook_plug.ex — unique_opts states list now includes :available (Rule 1 fix; aligns with worker's unique_job_opts/0)"
    - ".planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md — logged 2 pre-existing Rindle.ApplicationTest failures unrelated to Plan 02"

key-decisions:
  - "D-18..D-26 implemented: queue :rindle_provider, max_attempts: 5, timeout 30_000ms, unique on event_id, race-snooze curve [5,15,45,90], FSM-validate-then-update, repo-error -> raise + retry, redacted-asset_id telemetry."
  - "D-27 dispatch table implemented verbatim (with one Rule 1 fix): ready/errored/deleted broadcast; created (uploading->processing) NO broadcast (Phase 37 reserved); upload.asset_created last_event_at bump only; unknown -> last_event_at + telemetry kind: :unknown_event."
  - "D-29 typed branch in Event.normalize/1 positioned BEFORE generic clause; reads data.asset_id for provider_asset_id and data.id for upload_id; lock test (Test 1 in event_test.exs) refutes the silent-corruption mis-attribution."
  - "D-30 @type provider_event additive extension: optional(:upload_id); preserves required-field set unchanged (CONTEXT.md D-30's 'sample required fields' was a transcription error per the read_first guidance — actual code preserved)."
  - "D-31..D-33 two-topic PubSub broadcast keyed on MediaAsset.id; payload omits provider_asset_id; only :provider_asset_ready/errored/deleted broadcast (created reserved for Phase 37)."
  - "Rule 1 fix: removed :playback_id (singular) from MediaProviderAsset changeset attrs — Phase 33 schema is :playback_ids (PLURAL) only; the plan's 'legacy single id' comment was outdated."
  - "Rule 1 fix: added :available to unique_opts states list in BOTH IngestProviderWebhook.unique_job_opts/0 AND WebhookPlug's inline unique_opts. Without :available, the dedup never fires for the most common re-delivery race (second webhook arrives before worker picks up the first job in :available state). Mirrors MuxIngestVariant's documented rationale at lib/rindle/workers/mux_ingest_variant.ex:206-209."

patterns-established:
  - "Worker race-snooze with cumulative budget — first Rindle use of {:snooze, n}; pattern documented in moduledoc so adopters distinguish data-visibility races (this worker) from computation retries (sibling workers)."
  - "PubSub payload contract enforced by test — refute Map.has_key?(payload, :provider_asset_id) is the explicit lock; topic key is the public MediaAsset.id, never the provider-internal id."
  - "Pattern-match ordering as the silent-corruption guard — typed branch BEFORE generic clause; lock-test (Test 1 in event_test.exs) refutes mis-attribution by asserting provider_asset_id != upload_id."
  - "End-to-end Plug test using signed_conn/5 helper — wraps MuxWebhookFixtures.sign_header/3 + pre-populates :raw_body assign for synthetic conns (D-37); avoids re-implementing the HMAC recipe in test (Plan 03 D-34 carryover)."

requirements-completed:
  - MUX-12
  - MUX-13

# Metrics
duration: ~12min
completed: 2026-05-06
---

# Phase 35 Plan 02: IngestProviderWebhook Worker + Event.normalize/1 Typed Branch + End-to-End Plug Tests Summary

**Public `Rindle.Workers.IngestProviderWebhook` Oban worker on `:rindle_provider` queue (idempotent on Mux event UUID, race-snoozes [5/15/45/90s] for missing rows, FSM-validate-then-update via `Repo.update`, two-topic PubSub broadcast with `provider_asset_id`-omitted payload, redacted-`asset_id` telemetry) + `Event.normalize/1` typed branch for `video.upload.asset_created` (locks D-29 silent-corruption fix forward-compat for Phase 37) + additive `:upload_id` field on `@type provider_event` + 32 new tests across 3 files exercising the full verify-and-enqueue loop end-to-end.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-07T02:43:00Z (approximate; first commit at 2026-05-07T02:45:40Z)
- **Completed:** 2026-05-07T02:56:49Z
- **Tasks:** 3 (1 auto, 1 TDD with RED + GREEN commits, 1 verification-only)
- **Files created:** 4 (worker .ex + 3 test .exs files)
- **Files modified:** 4 (event.ex, provider.ex, webhook_plug.ex, deferred-items.md)

## Accomplishments

- Shipped `Rindle.Workers.IngestProviderWebhook` — the first Rindle worker using Oban's `{:snooze, n}` semantic. Race-snooze handles the `media_provider_assets`-row visibility race that Phase 34 `MuxIngestVariant` introduced (a `video.asset.ready` webhook can arrive before the sibling worker's `Repo.update` committing the row is visible to this worker). Curve [5,15,45,90]s with `{:cancel, :provider_asset_row_missing}` after attempt 5; cumulative ~155s budget; snoozes do NOT consume `:attempt` (Oban semantics), preserving the budget for genuine errors.
- Implemented the locked dispatch table (D-27): `video.asset.ready` flips `*  -> ready` with `playback_ids` + cleared `last_sync_error` + `:provider_asset_ready` broadcast; `video.asset.errored` flips `* -> errored` with formatted `last_sync_error` + `:provider_asset_errored` broadcast; `video.asset.deleted` flips `* -> deleted` + `:provider_asset_deleted` broadcast; `video.asset.created` flips `:uploading -> :processing` with NO broadcast (Phase 37 reserved); `video.upload.asset_created` is a `last_event_at` bump only (Phase 37 forward-compat); unknown events bump `last_event_at` and emit `:ignored kind: :unknown_event` telemetry.
- Locked the silent-corruption fix (D-29): the new `Event.normalize/1` typed branch for `video.upload.asset_created` is positioned BEFORE the generic clause and reads `data.asset_id` for `provider_asset_id` (the asset id) and `data.id` for `upload_id` (the upload id). Without this, the generic clause would mis-attribute `data.id` to `provider_asset_id` — silent data corruption when Phase 37 enables direct-creator uploads. The lock-test (`event_test.exs:33-34`) explicitly refutes the mis-attribution: `refute evt.provider_asset_id == upload_id`.
- Two-topic PubSub broadcast pattern enforces security invariant 14: payload contract excludes `provider_asset_id` entirely (`refute Map.has_key?(payload, :provider_asset_id)` lock test in worker_test case 13). Topic keys (`rindle:provider_asset:#{asset.id}` and `rindle:asset:#{asset.id}`) are both keyed on the parent `MediaAsset.id`, never on `provider_asset_id`. Only the public-side `playback_ids` cross into payload — adopters' `Phoenix.LiveView` subscribers see only safe-to-render data.
- End-to-end Plug suite (12 cases) proves the verify-and-enqueue loop works with the locked HMAC + multi-secret rotation + replay-window contract: signed POST → 202 + Oban job → `Oban.drain_queue/1` drives the worker → row flips `:processing → :ready` → two-topic PubSub broadcast received with payload omitting `provider_asset_id`. Multi-secret rotation telemetry (`:secret_used` with `secret_index`) lets operators confirm rotation completed before retiring previous secrets. Replay attack (`timestamp: now - 600`) returns 400. `dispatch_kind` drops surface 200 + telemetry `kind: :dropped` + zero Oban work.

## Task Commits

Each task was committed atomically. Task 2 follows TDD (RED → GREEN); Task 1 was straight implementation (additive typed branch + typespec extension + new test file); Task 3 is verification-of-existing-implementation since the WebhookPlug shipped in Plan 01 (per `tdd_execution` "fail-fast rule": when tests pass on the first run, the feature already exists — Task 3 documents the integrated flow against the worker that Task 2 just shipped).

1. **Task 1: Event.normalize/1 typed branch + provider_event :upload_id extension** — `78889bd` (feat)
2. **Task 2 RED: failing tests for IngestProviderWebhook worker** — `691f5f4` (test)
3. **Task 2 GREEN: implement IngestProviderWebhook worker** — `a79ee7d` (feat)
4. **Task 3: end-to-end WebhookPlug suite + format-driven event_test cleanup** — `226e47f` (test)

**Plan metadata commit:** to follow (this SUMMARY.md).

## Files Created/Modified

**Created:**
- `lib/rindle/workers/ingest_provider_webhook.ex` (425 LOC) — public Oban worker. `use Oban.Worker, queue: :rindle_provider, max_attempts: 5`; `timeout/1 -> 30_000`; `unique_job_opts/0` with `keys: [:event_id]`, `states: [:available, :scheduled, :executing, :retryable]`, `period: 86_400`; `perform/1` dispatches the locked event table; race-snooze curve `[5, 15, 45, 90]` with cancel at attempt 5; `transition_and_broadcast/6` shared helper for `:ready/:errored/:deleted`; `broadcast/2` two-topic with `provider_asset_id`-omitted payload; `emit/3` telemetry helper routes `asset_id` through `MediaProviderAsset.redact_id/1`; FSM rejection → `{:cancel, fsm_err}`; repo error → `{:error, _}` (Oban retries).
- `test/rindle/streaming/provider/mux/event_test.exs` (125 LOC, 6 tests) — D-29 typed-branch lock + generic-clause regression + invalid-payload.
- `test/rindle/workers/ingest_provider_webhook_test.exs` (503 LOC, 14 tests) — full dispatch table + race-snooze + FSM rejection + idempotency + telemetry redaction + payload contract + repo error.
- `test/rindle/delivery/webhook_plug_test.exs` (395 LOC, 12 tests) — happy path / idempotency / multi-secret rotation / 5 rejection paths / dispatch_kind drop / end-to-end fixture flow.

**Modified:**
- `lib/rindle/streaming/provider/mux/event.ex` — added typed branch for `video.upload.asset_created` BEFORE the generic clause; reads `data.asset_id` for `provider_asset_id` and `data.id` for `upload_id`; new `normalize_type("video.upload.asset_created") -> :upload_asset_created` clause. Updated `@doc` to document the silent-corruption rationale.
- `lib/rindle/streaming/provider.ex` — extended `@type provider_event` with `optional(:upload_id) => String.t() | nil` (D-30); updated `@typedoc` to note the new optional field's Phase 35/37 lineage.
- `lib/rindle/delivery/webhook_plug.ex` — added `:available` to the inline `unique_opts` states list (mirrors `Rindle.Workers.IngestProviderWebhook.unique_job_opts/0`); added an inline comment explaining why `:available` MUST be in the list.
- `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` — appended an entry documenting 2 pre-existing `Rindle.ApplicationTest` failures (out of Plan 02 scope).

## Decisions Made

- **D-30 transcription preserved code's actual required-field set** (per the plan's explicit `read_first` instruction). CONTEXT.md D-30's "sample required fields" list was a transcription artifact; the real Phase 33 typespec at `lib/rindle/streaming/provider.ex:52-59` had different required fields than the sample. Honored the read_first guidance: extended with `optional(:upload_id)` only; required fields untouched.
- **Task 3 TDD interpretation**: the plan declared Task 3 `tdd="true"` but the underlying `Rindle.Delivery.WebhookPlug` shipped in Plan 01. Per the `tdd_execution` "fail-fast rule": when RED tests pass on the first run, the feature may already exist — investigate. Confirmed Plan 01's plug + Plan 03's signing helper + Plan 02's worker (just landed in Task 2 GREEN) collectively make all 12 cases pass. Task 3's atomic commit is therefore a `test(...)` commit (not a separate test/feat pair) — the integrated flow is the contract being locked, not a new feature.
- **Worker is public, not optional-dep-guarded.** Per 35-PATTERNS.md the worker references no Mux SDK symbols at compile time — only `Phoenix.PubSub`, `Rindle.Domain.{MediaProviderAsset, ProviderAssetFSM}`, and `Rindle.Config.repo()` — so `if Code.ensure_loaded?(...)` wrapping is unnecessary and would break adopters who configure webhook ingest before fully wiring the Mux SDK.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed singular `:playback_id` from MediaProviderAsset changeset attrs.**
- **Found during:** Task 2 GREEN (first test run failed with `KeyError, key :playback_id not found`).
- **Issue:** The plan's `<action>` block prescribed `attrs = %{state: "ready", playback_ids: playback_ids, playback_id: List.first(playback_ids), ...}`. The Phase 33 `MediaProviderAsset` schema (`lib/rindle/domain/media_provider_asset.ex:49`) defines only `field :playback_ids, {:array, :string}` — there is no singular `:playback_id` column. The plan's `<read_first>` interfaces excerpt also showed only `playback_ids`. The plan's "legacy single id" comment in the `From lib/rindle/domain/media_provider_asset.ex` interface block was outdated.
- **Fix:** Removed `playback_id: List.first(playback_ids)` from the `:ready` dispatch attrs; the worker test asserts only on `playback_ids` (plural).
- **Files modified:** `lib/rindle/workers/ingest_provider_webhook.ex`, `test/rindle/workers/ingest_provider_webhook_test.exs` (one assertion line removed).
- **Verification:** Worker test 2 (`video.asset.ready: flips :processing -> :ready ...`) passes; row.playback_ids verified `["pb-id-1", "pb-id-2"]`.
- **Committed in:** `a79ee7d` (Task 2 GREEN).

**2. [Rule 1 - Bug] Added `:available` to `unique_opts` states list in BOTH the worker's `unique_job_opts/0` AND WebhookPlug's inline `unique_opts`.**
- **Found during:** Task 2 GREEN (idempotency test failed: `Expected truthy, got false` on `assert returned.conflict?`).
- **Issue:** The plan's locked `unique_job_opts/0` at D-20 was `states: [:scheduled, :executing, :retryable]`. In `testing: :manual` mode (and in production for the most common re-delivery race), Oban inserts newly-enqueued jobs in `:available` state FIRST. Without `:available` in the states list, the second `Oban.insert/1` of a duplicate job does NOT trip the unique constraint — it inserts a second row, so `assert returned.conflict?` (and the production "second identical post is no-op" success criterion) fails. This is the same fix `Rindle.Workers.MuxIngestVariant` applied at Phase 34 with documented rationale at `lib/rindle/workers/mux_ingest_variant.ex:206-209` ("Includes :available in states because Oban inserts newly-enqueued jobs in :available state by default — without it the unique constraint never fires").
- **Fix:** Added `:available` to BOTH the worker's `unique_job_opts/0` and to `Rindle.Delivery.WebhookPlug`'s inline `unique_opts` (so the Plug's `Oban.insert/1` and a hypothetical caller-built `Oban.Job.changeset` use the same idempotency key). Both states lists now read `[:available, :scheduled, :executing, :retryable]`.
- **Files modified:** `lib/rindle/workers/ingest_provider_webhook.ex` (function + docstring), `lib/rindle/delivery/webhook_plug.ex` (inline unique_opts + comment).
- **Verification:** Worker test 1 (`Oban unique on event_id deduplicates re-delivery`) passes; webhook_plug_test.exs case 2 (`idempotent re-delivery`) passes — `length(jobs) == 1` after two POSTs.
- **Committed in:** `a79ee7d` (Task 2 GREEN).

**3. [Rule 3 - Blocking] Bootstrap `mix deps.get` to populate `deps/` directory.**
- **Found during:** Task 1 verification (first `mix compile` failed because the worktree had no `deps/` populated).
- **Issue:** Worktree spawned without `deps/` — Plan 03 ran into the same one-time bootstrap requirement.
- **Fix:** Ran `mix deps.get` followed by `mix compile`; subsequent runs were clean.
- **Files modified:** None (regenerated `mix.lock` would not be modified; `deps/` is gitignored).
- **Verification:** `mix compile --warnings-as-errors --force` exits 0; all subsequent test runs pass.
- **Not committed** (one-time worktree bootstrap, not a code change).

**4. [Rule 3 - Blocking, OUT OF SCOPE] Logged 2 pre-existing `Rindle.ApplicationTest` failures to deferred-items.md.**
- **Found during:** Task 2 GREEN full-suite verification.
- **Issue:** `test run_startup_checks warns when configured AV profiles boot on unsupported ephemeral runtimes` and `test run_startup_checks stays quiet when configured profiles are image-only` fail because `Rindle.Config.profile_modules/0` discovers `Rindle.Adopter.CanonicalApp.VideoProfile` (an adopter test profile) in addition to the test-local AV profile, so `affected_profiles` is `[adopter, test_local]` instead of the expected `[test_local]`.
- **Verification:** `git stash` of Plan 02 changes confirmed both failures reproduce on the base branch (commit `72a515a`) before any Plan 02 code is applied — pre-existing test isolation issue, NOT introduced by Plan 02.
- **Fix:** Out of scope per execute-plan scope boundary. Logged to `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` for v1.6/v1.7 polish (scope `Rindle.Application.run_startup_checks/1` to test-supplied profile lists, or filter discovery to a configured allowlist in test envs).
- **Files modified:** `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` (appended new entry).
- **Committed in:** `a79ee7d` (Task 2 GREEN).

**5. [Rule 1 - Style] Applied `mix format` to two new test files.**
- **Found during:** Task 3 verification (post-write `mix format --check-formatted` flagged indentation drift in 2 places: a multi-line attribute string in `webhook_plug_test.exs` and a long pattern-match assertion in `event_test.exs`).
- **Issue:** Hand-written formatting differed from `.formatter.exs` defaults.
- **Fix:** Ran `mix format` on both files. No logic changes; re-indent only.
- **Files modified:** `test/rindle/streaming/provider/mux/event_test.exs`, `test/rindle/delivery/webhook_plug_test.exs`.
- **Verification:** `mix format --check-formatted` on the Plan 02 file set exits 0; all 32 Plan 02 tests still pass post-format.
- **Committed in:** `226e47f` (Task 3 commit).

---

**Total deviations:** 5 (2 Rule 1 bugs in plan-prescribed code, 1 Rule 3 worktree bootstrap, 1 Rule 3 out-of-scope logging, 1 Rule 1 style/format). All within scope for the work commit; the out-of-scope item is logged not fixed.

**Impact on plan:** The two Rule 1 bugs (`:playback_id` and `:available` state) were necessary corrections — without them, the worker would `KeyError` on every `:ready` dispatch and idempotency would silently break. Both have direct, documented prior-art rationale (Phase 33 schema; Phase 34's `MuxIngestVariant.unique_job_opts/0` docstring). The remaining items are bookkeeping (bootstrap + format + scope-boundary logging). No scope creep.

## Issues Encountered

- **Worktree bootstrap.** First `mix compile` failed because `deps/` was not pre-populated. Resolved with `mix deps.get`. Plan 03 hit the same issue.
- **Acceptance-criteria literal-match nuance.** The plan's Task 3 acceptance criterion required `grep -c 'MuxWebhookFixtures.sign_header' test/rindle/delivery/webhook_plug_test.exs` to return `>= 5`. My implementation uses a `signed_conn/5` helper that wraps `MuxWebhookFixtures.sign_header/3` (called once at line 70) and is invoked by 10 separate test cases — same coverage, DRYer code, but the literal grep returns 1 instead of 5. The functional intent (multiple cases exercise the helper) is satisfied: `grep -c 'signed_conn(' test/rindle/delivery/webhook_plug_test.exs` returns 11. Documenting here for plan-checker awareness; not a deviation that needs reverting.

## User Setup Required

None — Plan 02 is purely library code. Adopters in v1.6 will need `RINDLE_MUX_WEBHOOK_SECRETS` set, but the documented onboarding lives in Phase 36 (`Rindle.Profile.Presets.MuxWeb`, `mix rindle.doctor` streaming validation, `guides/streaming_providers.md`).

## Next Phase Readiness

Wave 2 of Phase 35 is complete with this plan. **Plan 35-04 (`mix rindle.runtime_status --provider-stuck` filter)** runs in parallel in the same wave and consumes Plan 02's worker telemetry shape:

- `[:rindle, :provider, :webhook, :exception kind: :race_snooze_exhausted]` — surfaces rows that hit the race-snooze ceiling without finding a matching `media_provider_assets` row (operators investigate via the `--provider-stuck` filter).
- `[:rindle, :provider, :webhook, :exception kind: :invalid_transition]` — surfaces rows where the FSM rejected a webhook-driven state change (e.g. `:deleted -> :ready`); polling backstop reconciles.

Phase 36 (Mux onboarding + DX) is unblocked and can now exercise the worker end-to-end via the `mux-enabled` package-consumer CI lane — `mix rindle.doctor` will boot-probe the worker module and `guides/streaming_providers.md` will document the `forward "/webhooks/rindle/mux", Rindle.Delivery.WebhookPlug` snippet that drives this worker.

Phase 37 (optional pull-forward — direct creator upload) inherits the typed branch in `Event.normalize/1` and the `:upload_id` field on `@type provider_event` as forward-compat. Phase 37's work narrows to: (a) implement `Rindle.Streaming.Provider.Mux.create_direct_upload/2`; (b) promote `:upload_asset_created` and `:provider_asset_created` from no-op to broadcast events. Phase 35's typed-branch lock-test prevents the silent-corruption regression that would otherwise surface only when Phase 37 ships.

No blockers.

## Self-Check

Verifying claims before returning.

**Files exist:**
- `lib/rindle/workers/ingest_provider_webhook.ex`: FOUND
- `test/rindle/streaming/provider/mux/event_test.exs`: FOUND
- `test/rindle/workers/ingest_provider_webhook_test.exs`: FOUND
- `test/rindle/delivery/webhook_plug_test.exs`: FOUND
- `lib/rindle/streaming/provider/mux/event.ex` (modified): FOUND
- `lib/rindle/streaming/provider.ex` (modified): FOUND
- `lib/rindle/delivery/webhook_plug.ex` (modified): FOUND
- `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` (modified): FOUND

**Commits exist:**
- `78889bd` (Task 1, feat): FOUND
- `691f5f4` (Task 2 RED, test): FOUND
- `a79ee7d` (Task 2 GREEN, feat): FOUND
- `226e47f` (Task 3, test): FOUND

**Test counts (locked acceptance criteria):**
- `event_test.exs`: 6 tests (>= 2 D-29 typed-branch tests required by plan acceptance)
- `ingest_provider_webhook_test.exs`: 14 tests (== 14 required by plan acceptance)
- `webhook_plug_test.exs`: 12 tests (== 12 required by plan acceptance)
- Combined Plan 02 suite: 32/32 passing in `mix test test/rindle/streaming/provider/mux/event_test.exs test/rindle/workers/ingest_provider_webhook_test.exs test/rindle/delivery/webhook_plug_test.exs`

## Self-Check: PASSED

---
*Phase: 35-signed-webhook-plug-idempotent-ingest*
*Plan: 02 (Wave 2)*
*Completed: 2026-05-06*
