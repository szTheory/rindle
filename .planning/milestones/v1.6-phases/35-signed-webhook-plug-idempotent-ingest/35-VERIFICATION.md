---
phase: 35-signed-webhook-plug-idempotent-ingest
verified: 2026-05-06T23:30:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
---

# Phase 35: Signed-Webhook Plug + Idempotent Ingest Verification Report

**Phase Goal:** Webhooks become the primary readiness signal — cryptographically verified, replay-protected, secret-rotation-aware, and Oban-deferred. Highest-fidelity phase: raw-body cache, multi-secret rotation, replay protection, and idempotency all land here.
**Verified:** 2026-05-06T23:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `Rindle.Delivery.WebhookPlug` is a mountable provider-aware Plug; `Rindle.Delivery.WebhookBodyReader` reads the raw body and bypasses `Plug.Parsers` JSON decoding | ✓ VERIFIED | `lib/rindle/delivery/webhook_plug.ex` (337 LOC, `@behaviour Plug`, `forward` doc in @moduledoc); `lib/rindle/delivery/webhook_body_reader.ex` (100 LOC, `def read_body/2` MFA, 1 MiB cap, `conn.assigns[:raw_body]` list-of-binaries cache) |
| 2 | Bypass-driven ExUnit posts a fixture `video.asset.ready` payload with a real HMAC signature; `IngestProviderWebhook` idempotently flips the row to `:ready`, persists `playback_ids`, broadcasts `:provider_asset_ready` PubSub | ✓ VERIFIED | `test/rindle/delivery/webhook_plug_test.exs` end-to-end test (line 348): signed POST → 202 + `Oban.drain_queue` → `reloaded.state == "ready"` + `reloaded.playback_ids == ["playback-id-test-fixture-1234"]` + two-topic PubSub broadcast received; 12 tests, 0 failures |
| 3 | Second identical post is a no-op (Oban `unique` on event UUID); replay with 600s-old timestamp returns 400 `provider_webhook_invalid`; signature mismatch returns same 400 | ✓ VERIFIED | Idempotency: `webhook_plug_test.exs` line 158 asserts `length(jobs) == 1` after two POSTs; unique states include `:available`. Replay: line 218 stale_ts = -600, asserts status 400 + `resp_body == "provider_webhook_invalid"`. Sig mismatch: line 234, status 400. Worker `unique_job_opts/0` keys on `:event_id`, `period: 86_400`. |
| 4 | Multi-secret rotation works: tries `:webhook_secrets` in order, first-match wins, metric records which secret index matched; tolerance is configurable (default 300s from config) | ✓ VERIFIED | `lib/rindle/delivery/webhook_plug.ex` `resolve_secrets/1` has 5 clauses for all 4 shapes (resolved at `call/2` time). `lib/rindle/streaming/provider/mux.ex` lines 283-308: `Enum.with_index()` + `Enum.find_value` loop; `:secret_used` telemetry emits `%{secret_index: index}`. Tests: `webhook_plug_test.exs` lines 180-205 assert `metadata.secret_index == 1` for both rotation directions. Tolerance reads from `config(:webhook_tolerance_seconds, 300)`. |
| 5 | Workers exceeding `max_attempts` leave the affected row in its last-known good state with `last_sync_error` populated; `mix rindle.runtime_status --provider-stuck` lists stuck/uploading rows older than the configured threshold | ✓ VERIFIED | Worker: `max_attempts: 5`; race-snooze exhaustion at attempt 5 → `{:cancel, :provider_asset_row_missing}` (row left in last state); `video.asset.errored` dispatch populates `last_sync_error`. Mix task: `--provider-stuck` parsed in `OptionParser`, `format_provider_findings/1` in correct position in `format_text_report/1`, `provider_assets_report/2` wired into `runtime_status/1`. 25 tests in runtime_status files pass. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/rindle/delivery/webhook_plug.ex` | Mountable `@behaviour Plug` with init/1 opts validation, call/2 verify-and-enqueue pipeline | ✓ VERIFIED | 337 LOC. `@behaviour Plug`, 2 `ArgumentError` raises in `init/1`, POST-only guard, 6 response codes (200/202/400/405/500/503), 4 secret resolver shapes, `WebhookBodyReader.raw_body/1` call, `dispatch_kind/1` call, `Oban.insert/1`, telemetry `:verified`/`:rejected` |
| `lib/rindle/delivery/webhook_body_reader.ex` | `read_body/2` MFA contract, `raw_body/1` accessor, 1 MiB cap, chunk loop | ✓ VERIFIED | 100 LOC. `@max_body_bytes 1_048_576`, `def read_body(conn, opts \\ [])`, `do_read_body/4` loop draining `{:more, _, conn}`, `def raw_body/1` with 3 clauses (single/multi/nil), public `@moduledoc` |
| `lib/rindle/workers/ingest_provider_webhook.ex` | Public Oban worker, idempotent on event UUID, race-snooze, FSM-validate-then-update, PubSub broadcast | ✓ VERIFIED | 425 LOC. `use Oban.Worker, queue: :rindle_provider, max_attempts: 5`, `@snooze_curve [5, 15, 45, 90]`, `unique_job_opts/0` with `:available`, dispatch table for 5 event types + default, `transition_and_broadcast/6`, `broadcast/2` two-topic, `emit/3` redacted telemetry |
| `lib/rindle/streaming/provider/mux.ex` | Dead case-fork removed, `dispatch_kind/1` added, provider-internal telemetry inside `verify_webhook/3` | ✓ VERIFIED | `grep -c "Mux-Signature" = 0`. `dispatch_kind/1` present with 5 `:dispatch` heads + DROP table + default `:drop`. 3 telemetry calls for `:secret_used` and `:rejected` (2 paths). |
| `lib/rindle/streaming/provider/mux/event.ex` | Typed branch for `video.upload.asset_created` BEFORE generic clause | ✓ VERIFIED | Lines 27-40: typed branch reads `data.asset_id` for `provider_asset_id` and `data.id` for `upload_id`; positioned before generic clause at line 42 |
| `lib/rindle/streaming/provider.ex` | `@type provider_event` extended with `optional(:upload_id)` | ✓ VERIFIED | `optional(:upload_id) => String.t() \| nil` confirmed in file |
| `lib/rindle/ops/runtime_status.ex` | `provider_assets_report/2`, `:provider_stuck` filter, `recommendation_for_class(:provider_stuck)`, `normalize_provider_stuck/1`, `MediaProviderAsset.redact_id/1` call | ✓ VERIFIED | All present: `@allowed_filter_keys` includes `:provider_stuck`, `provider_assets:` in `runtime_status/1` return, `provider_assets_report/2` defined, `redact_id` call at line 215, `recommendation_for_class(:provider_stuck)` at line 532, `normalize_provider_stuck/1` at lines 710-713 |
| `lib/mix/tasks/rindle.runtime_status.ex` | `--provider-stuck` flag, `format_provider_findings/1` helper, correct position in `format_text_report/1` | ✓ VERIFIED | `provider_stuck: :boolean` in OptionParser, `maybe_put(:provider_stuck, ...)`, `format_provider_findings/1` as `@doc false def` with 2 clauses, inserted after `format_section("upload_sessions", ...)` and before `format_recommendations(...)` |
| `test/rindle/delivery/webhook_body_reader_test.exs` | 7 unit tests covering all shapes | ✓ VERIFIED | 7 tests (small body, chunked drain, over-1MiB cap, exactly-1MiB, nil assign, single element, multi-chunk reversed join) — 0 failures |
| `test/rindle/delivery/webhook_plug_test.exs` | 12 end-to-end tests | ✓ VERIFIED | 12 tests covering happy path, idempotency, multi-secret rotation (2 cases), 6 rejection paths, dispatch_kind drop, end-to-end fixture flow — 0 failures |
| `test/rindle/workers/ingest_provider_webhook_test.exs` | 14 worker tests | ✓ VERIFIED | 14 tests — 0 failures |
| `test/rindle/streaming/provider/mux/event_test.exs` | 6 tests covering D-29 typed-branch | ✓ VERIFIED | 6 tests — 0 failures |
| `test/support/mux_webhook_fixtures.ex` | `sign_header/3` with `:timestamp` override, HMAC recipe | ✓ VERIFIED | `@moduledoc false`, `:crypto.mac(:hmac, :sha256, ...)`, `"t=#{timestamp},v1=#{signature}"` header format |
| `test/fixtures/mux/webhook_video_asset_deleted.json` | Sparse `{id, status: "deleted"}` fixture | ✓ VERIFIED | `data` keys = `['id', 'status']` only (verified by python3) |
| `test/fixtures/mux/webhook_video_upload_asset_created.json` | Distinct `data.id` (upload-id) vs `data.asset_id` (asset-id) | ✓ VERIFIED | `data.id != data.asset_id` confirmed |
| `test/rindle/ops/runtime_status_test.exs` | 9 new provider_assets test cases including redaction assertion | ✓ VERIFIED | `assert sample.provider_asset_id == "...dddd"` at line 209; `assert sample.provider_asset_id == "...zzzz"` at line 242; 25 total tests, 0 failures |
| `test/rindle/runtime_status_task_test.exs` | 6 new --provider-stuck test cases | ✓ VERIFIED | 9 total tests (3 pre-existing + 6 new), 0 failures; includes redaction assertion at line 79 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `webhook_plug.ex` | `Rindle.Streaming.Provider.Mux.verify_webhook/3` | `provider.verify_webhook(raw_body, headers, secrets)` in `safe_verify/4` | ✓ WIRED | Line 216; wrapped in try/rescue |
| `webhook_plug.ex` | `Rindle.Streaming.Provider.Mux.dispatch_kind/1` | `provider.dispatch_kind(event_type)` in `dispatch_event/3` | ✓ WIRED | Line 155 |
| `webhook_plug.ex` | `Rindle.Delivery.WebhookBodyReader.raw_body/1` | `Rindle.Delivery.WebhookBodyReader.raw_body(conn)` in `fetch_raw_body/1` | ✓ WIRED | Line 224 |
| `webhook_plug.ex` | `Oban.insert/1` | `Rindle.Workers.IngestProviderWebhook.new(args, unique: unique_opts) \|> Oban.insert()` | ✓ WIRED | Lines 188-190 |
| `lib/rindle/streaming/provider/mux.ex` | `:telemetry.execute/3` | `[:rindle, :provider, :mux, :webhook_attempt, :secret_used\|:rejected]` | ✓ WIRED | 3 telemetry calls at lines 287-292, 301-306, 312-316 |
| `runtime_status.ex provider_assets_report/2` | `MediaProviderAsset.redact_id/1` | `MediaProviderAsset.redact_id(row.provider_asset_id)` in `provider_asset_sample/2` | ✓ WIRED | Line 215 |
| `runtime_status.ex` | `Application.get_env(:rindle, Rindle.Streaming.Provider.Mux)` | `effective_provider_stuck_threshold/1` threshold default lookup | ✓ WIRED | Lines 173-175, reads `:provider_stuck_threshold_seconds` with 7200s fallback |
| `mix/tasks/rindle.runtime_status.ex` | `format_provider_findings/1` | Inserted after `format_section("upload_sessions", ...)` and before `format_recommendations(...)` | ✓ WIRED | Line 85 in `format_text_report/1` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `webhook_plug.ex` | `raw_body` | `WebhookBodyReader.raw_body(conn)` from `conn.assigns[:raw_body]` | Yes — populated by `read_body/2` MFA; fallback to `Plug.Conn.read_body/2` | ✓ FLOWING |
| `ingest_provider_webhook.ex` | `row` | `repo.get_by(MediaProviderAsset, provider_asset_id: ...)` | Yes — live DB query; race-snooze handles nil case | ✓ FLOWING |
| `runtime_status.ex provider_assets_report/2` | `rows` | `provider_assets_finding_rows_query/3 \|> Config.repo().all()` | Yes — Ecto query with `where state in ["uploading", "processing"] and updated_at < cutoff` | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Body reader 7 unit tests | `mix test test/rindle/delivery/webhook_body_reader_test.exs` | 7 tests, 0 failures | ✓ PASS |
| Signing helper 5 unit tests | `mix test test/rindle/test/mux_webhook_fixtures_test.exs` | 5 tests, 0 failures | ✓ PASS |
| Webhook Plug 12 end-to-end tests | `mix test test/rindle/delivery/webhook_plug_test.exs` | 12 tests, 0 failures | ✓ PASS |
| Worker 14 tests | `mix test test/rindle/workers/ingest_provider_webhook_test.exs` | 14 tests, 0 failures | ✓ PASS |
| Event 6 tests | `mix test test/rindle/streaming/provider/mux/event_test.exs` | 6 tests, 0 failures | ✓ PASS |
| Runtime status 25 tests | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs` | 25 tests, 0 failures | ✓ PASS |
| Compilation clean | `mix compile --warnings-as-errors` | exit 0 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MUX-09 | Plans 01, 03 | `WebhookPlug` mountable via `forward`; `WebhookBodyReader` bypasses `Plug.Parsers` | ✓ SATISFIED | `webhook_plug.ex` `@moduledoc` documents `forward` declaration; `webhook_body_reader.ex` `read_body/2` MFA; 7 body reader tests pass |
| MUX-10 | Plans 01, 03 | Signature verification via `Mux.Webhooks.verify_header/4` (HMAC-SHA256, 300s default) | ✓ SATISFIED | `mux.ex:285` calls `Mux.Webhooks.verify_header(raw_body, sig_header, secret, tolerance)`; `tolerance = config(:webhook_tolerance_seconds, 300)`; end-to-end signing tests use real HMAC via `MuxWebhookFixtures.sign_header/3` |
| MUX-11 | Plans 01, 03 | Multi-secret rotation, first-match wins, metric records secret index | ✓ SATISFIED | `mux.ex` `Enum.with_index()` + `Enum.find_value` loop; `[:rindle, :provider, :mux, :webhook_attempt, :secret_used]` with `%{secret_index: index}`; plug_test.exs asserts `metadata.secret_index == 1` |
| MUX-12 | Plans 01, 02 | `202 Accepted` on verified webhook; `400 provider_webhook_invalid` on sig/replay failures | ✓ SATISFIED | `webhook_plug.ex` returns 202 on enqueue, 400 with `"provider_webhook_invalid"` body on all rejection paths; replay attack test asserts 400; sig mismatch test asserts 400 |
| MUX-13 | Plans 01, 02 | `IngestProviderWebhook` idempotent under Oban `unique`; dispatches on event type; persists state/playback_ids/broadcasts; unknown events safe | ✓ SATISFIED | `unique_job_opts/0` keys on `:event_id`, `period: 86_400`, includes `:available`; dispatch table covers 5 event types + default; `idempotent re-delivery` test asserts `length(jobs) == 1`; end-to-end test asserts `state == "ready"` + `playback_ids` + PubSub broadcast without `provider_asset_id` |
| MUX-14 | Plan 04 | Workers leave row in last-known state with `last_sync_error`; `mix rindle.runtime_status --provider-stuck` lists stuck rows | ✓ SATISFIED | Worker: `last_sync_error` populated for errored dispatch; race-snooze exhaustion → `{:cancel, :provider_asset_row_missing}` (row untouched). Mix task: `--provider-stuck` flag, `provider_assets_report/2` queries `state in ["uploading", "processing"]` past threshold; 3-layer redaction enforcement verified |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/rindle/workers/ingest_provider_webhook.ex` | 97 | NOTE on unique_job_opts/0 — plan originally omitted `:available` from states | ℹ️ Info | Auto-fixed during execution (Rule 1); `:available` now present in both worker and plug unique_opts; idempotency test passes |

No placeholder returns, no TODO/FIXME blockers, no empty implementations. The `@compile {:no_warn_undefined, Rindle.Workers.IngestProviderWebhook}` directive in `webhook_plug.ex` is intentional (Plan 01 pre-references Plan 02's module) and resolved correctly once Plan 02 shipped.

### Human Verification Required

None. All behaviors are verifiable programmatically.

### Pre-existing Failures (Out of Scope)

Per `deferred-items.md` (documented before Phase 35 execution started), the following failures reproduce on the baseline commit `1768567` before any Phase 35 changes and are NOT Phase 35 regressions:

1. `test/rindle/application_test.exs:41` — `run_startup_checks warns when configured AV profiles boot on unsupported ephemeral runtimes` (adopter profile discovery leakage)
2. `test/rindle/application_test.exs:58` — `run_startup_checks stays quiet when configured profiles are image-only` (same root cause)
3. `test/rindle/probe/av_probe_test.exs:58` — `propagates ffprobe failures for invalid input` (order-sensitive)

These are pre-existing test isolation issues tracked for v1.7 polish. They do not affect Phase 35 goal verification.

### Gaps Summary

No gaps. All 5 success criteria are satisfied with observable code and passing tests.

---

_Verified: 2026-05-06T23:30:00Z_
_Verifier: Claude (gsd-verifier)_
