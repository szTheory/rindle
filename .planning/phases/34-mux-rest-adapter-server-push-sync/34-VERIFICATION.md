---
phase: 34-mux-rest-adapter-server-push-sync
verified: 2026-05-06T00:00:00Z
status: human_needed
score: 5/5 must-haves verified; 8/8 requirement IDs SATISFIED
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: n/a
  gaps_closed: []
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Pre-ship review: BL-01 — orphaned Mux asset on stale-source rejection in MuxIngestVariant.persist_provider_processing/4"
    expected: "When the post-create freshness re-check (lib/rindle/workers/mux_ingest_variant.ex:313-318) detects drift AFTER Adapter.create_asset_with_retry_hint/3 already created the Mux asset, the worker returns {:cancel, _} but does NOT delete the Mux asset and the row stays in :uploading until the 7200s stuck threshold fires. This is qualitatively worse than the AV-03-10 pattern it mirrors because Mux assets are billed."
    why_human: "The phase must-have says atomic-promote 'aborts when recipe_digest or storage_key changed during ingest (mirrors AV-03-10)'; abort behavior IS present, so the must-have is technically met. But the design has a real billing/lifecycle leak. Decide: ship as-is and track in deferred-items.md, or hold for a compensating delete + revert before phase close."
  - test: "Pre-ship review: BL-02 — re-ingest from :errored state breaks FSM (silent failure)"
    expected: "maybe_skip_already_in_progress/4 (lib/rindle/workers/mux_ingest_variant.ex:269-282) lets :errored rows fall through to transition_uploading/4, but provider_asset_fsm.ex:14 only allows errored → processing|deleted (NOT errored → uploading). A re-enqueue against an :errored row burns max_attempts: 5 with {:error, {:invalid_transition, \"errored\", \"uploading\"}}. The test suite never exercises this path."
    why_human: "Phase 34 must-haves cover idempotent re-run for :uploading/:processing/:ready (which works) but do not require errored → uploading re-entry. The errored-path bug exists in the code but is not a must-have failure. Decide: accept and document, or fix before close."
  - test: "Pre-ship review: BL-03 — Event.extract_playback_ids/1 crashes on explicit null"
    expected: "lib/rindle/streaming/provider/mux/event.ex:44-52 calls Map.get(data, \"playback_ids\", []) which returns nil (NOT default) when the key is present with explicit null. Subsequent Enum.map(nil, _) raises Protocol.UndefinedError. Mux sends \"playback_ids\": null on video.asset.created webhooks (which fire before transcoding completes). When Phase 35 wires up the WebhookPlug this will 500 the callback."
    why_human: "Phase 34 ships verify_webhook/3 as a CALLBACK (must-have #2: 'implements every locked behaviour callback'); the call wiring lands in Phase 35. The callback is implemented and tests cover happy/error paths, so the must-have is met. But this is a known crash that Phase 35 will hit immediately. Decide: fix here in Phase 34 (small, low-risk patch) or defer to Phase 35 with a known-broken-path note."
  - test: "Pre-ship review: BL-04 — behaviour @callback get_asset/1 spec violation (atom vs string)"
    expected: "lib/rindle/streaming/provider.ex:67-75 declares state: provider_state() (atoms :pending|...|:errored). lib/rindle/streaming/provider/mux.ex:212-226 returns string states (\"processing\", \"ready\"). Downstream MuxSyncProviderAsset operates on strings (matches schema column type), but the contract is incoherent."
    why_human: "Phase 34 must-have #2 requires the adapter implement every locked callback. Functionally it does — every callsite already operates on strings (schema column is :string). The behaviour TYPE spec is wrong but no runtime path breaks. Dialyzer doesn't flag it because adopter callers haven't been written yet. Decide: align the behaviour spec to String.t() (cheaper) or convert at the adapter (more disruptive); either way needs explicit decision before adopter Phase 36."
  - test: "Visual/operational: Run end-to-end with real Mux test credentials"
    expected: "Mux-soak GitHub Actions lane (planned for Phase 36) drives a 720p sample to real Mux; row reaches :ready via real webhook; signed URL plays in a browser."
    why_human: "Phase 34 verification stops at Mox cassettes. Real Mux integration is Phase 36 territory. Confirm cassette parity reflects current Mux REST API by spot-checking docs."

deferred:
  - truth: "Live webhook verification (signed payloads → live FSM transition to :ready)"
    addressed_in: "Phase 35"
    evidence: "Phase 35 success criterion 2: 'Bypass-driven ExUnit posts a fixture video.asset.ready payload with a real HMAC signature against the Plug; Rindle.Workers.IngestProviderWebhook idempotently flips the matching media_provider_assets row to :ready'. Phase 34 must-have #3 explicitly says 'matching media_provider_assets row reaches :ready via simulated webhook (Phase 35 wires up the live verification)'."
  - truth: "WebhookPlug routing live HTTP requests to verify_webhook/3 callback"
    addressed_in: "Phase 35"
    evidence: "Phase 35 success criterion 1: 'Rindle.Delivery.WebhookPlug is a mountable provider-aware Plug that adopters mount via a documented forward declaration'. Phase 34 ships only the callback (verify_webhook/3) and the Event normalizer; wiring is Phase 35."
  - truth: "Adopter onboarding guide referencing the documented telemetry contract"
    addressed_in: "Phase 36"
    evidence: "Plan 04 SUMMARY notes: 'Phase 36 ships the canonical adopter-wiring guide.' Phase 34 documents the telemetry contract in @moduledoc as the single source of truth."
  - truth: "mux-soak GitHub Actions lane behind a MUX_TOKEN_ID secret (live integration)"
    addressed_in: "Phase 36"
    evidence: "Plan 01/04 SUMMARY: 'Phase 36 ships the mux-soak GitHub Actions lane behind a MUX_TOKEN_ID secret; Phase 34 stops at cassette-driven unit + integration smoke.'"
  - truth: "v1.7 cleanup: pre-existing Dialyzer pattern_match warnings in non-Phase-34 surface (process_variant.ex, promote_asset.ex, runtime_status.ex, html.ex)"
    addressed_in: "v1.7 stabilization plan (post-v1.6)"
    evidence: "Plan 04 SUMMARY documents 5 ignore entries in .dialyzer_ignore.exs; Phase 34 surface itself is dialyzer-clean with no ignores."
---

# Phase 34: Mux REST Adapter + Server-Push Sync — Verification Report

**Phase Goal:** First real adapter. Server pushes a finished mp4 to Mux from existing `Rindle.Processor.AV` output; durable provider state tracks Mux asset id + playback id; signed-playback URLs work.

**Verified:** 2026-05-06T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `mux ~> 3.2` and `jose ~> 1.11` ship as **optional** deps; adopters who don't enable streaming pay zero transitive cost; credential resolution lives entirely in `Application.get_env`. | VERIFIED | `mix.exs:68-69` declares both as `optional: true`. `lib/rindle/streaming/provider/mux.ex:351-355` reads via `Application.get_env(:rindle, __MODULE__, [])`. Every Mux-touching lib module wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do` (mux.ex, mux/http.ex, mux_ingest_variant.ex, mux_sync_coordinator.ex, mux_sync_provider_asset.ex). |
| 2 | `Rindle.Streaming.Provider.Mux` implements every locked behaviour callback; `Rindle.Workers.MuxIngestVariant` Oban worker pushes a Rindle-produced AV variant to Mux from server context using a private signed storage URL, persists `provider_asset_id` + `playback_id`, advances FSM `pending → uploading → processing`. | VERIFIED | mux.ex defines `capabilities/0`, `create_asset/3`, `get_asset/1`, `delete_asset/1`, `signed_playback_url/3`, `verify_webhook/3` with `@impl Rindle.Streaming.Provider`. mux_ingest_variant.ex:112 reads source via `Rindle.Delivery.url(profile_mod, variant.storage_key, expires_in: 1_800)`, calls `Adapter.create_asset_with_retry_hint/3` at line 361, persists PLURAL `playback_ids` at line 331, advances FSM via `transition_uploading/4` (line 284) then `:processing` (line 338). Test "ingests variant, persists provider_asset_id + playback_ids (PLURAL), advances FSM to :processing" PASSES. |
| 3 | Cassette-based ExUnit drives 720p sample through `MuxIngestVariant`; matching row reaches `:ready` via simulated webhook (Phase 35 wires live); `streaming_url/3` returns Mux-signed playback URL whose JWT verifies against fixture key (TTL respects `signed_url_ttl_seconds`, no hidden 7-day default). | VERIFIED | telemetry_test.exs end-to-end smoke "full pipeline: ingest variant, sync to ready, mint signed playback URL" PASSES — drives ingest via cassette, simulates ready via `MuxSyncProviderAsset`, mints URL via `Adapter.signed_playback_url/3`, asserts `assert_in_delta exp, before_unix + ttl, 5` (line 264) AND `refute exp > before_unix + 604_800` (line 266) AND `JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)` returns `{true, _, _}` (line 276). |
| 4 | `MuxIngestVariant` idempotent under Oban `unique` keyed on `(asset_id, profile, variant_name)`; re-running yields same row, never duplicate; atomic-promote on flip-to-`ready` aborts when `recipe_digest` or `storage_key` changed (mirrors AV-03-10). | VERIFIED | mux_ingest_variant.ex:194-201 `unique_job_opts/0` returns `keys: [:asset_id, :profile, :variant_name], states: [:available, :scheduled, :executing, :retryable, :completed], period: 86_400`. mux_ingest_variant.ex:222-231 (pre-create check) and :313-318 (post-create check) implement atomic-promote. Tests "Oban.unique semantics: enqueue with unique opts deduplicates at the JOB level", "atomic_promote: storage_key drift returns {:cancel, {:stale_source, :asset_changed}}", "atomic_promote: recipe_digest drift returns {:cancel, {:stale_source, :recipe_changed}}", "re-running perform on a row already in :processing yields :ok no-op (does not retry forbidden FSM edge)" all PASS. |
| 5 | `MuxSyncProviderAsset` defensively polls `processing`/`uploading` rows older than configured floor; transitions to `:errored` past stuck-threshold cap; provider ingest+sync emit telemetry `[:rindle, :provider, :ingest, :start | :stop | :exception]` and `[:rindle, :provider, :sync, :resolved | :stuck]` with documented schemas. | VERIFIED | mux_sync_coordinator.ex:85-93 query `where: r.state in ["processing", "uploading"] and r.updated_at < ^cutoff`. mux_sync_provider_asset.ex:74-78 `stuck?/1` checks `row.state in ["processing", "uploading"] and age > threshold`. mux_sync_provider_asset.ex:95-113 `mark_stuck/2` transitions to `:errored` with `last_sync_error: "stuck in :<state> past threshold"`. Telemetry events fire at mux_ingest_variant.ex:389 (ingest) and mux_sync_provider_asset.ex:194 (sync). Tests "transitions row from :processing to :ready on Mux ready response, persists PLURAL playback_ids, emits :resolved" and "transitions to :errored with reason :provider_asset_stuck past stuck threshold" PASS. Note: stored reason is the human-readable string `"stuck in :processing past threshold"`, not the atom `:provider_asset_stuck` — this matches the test assertion `updated.last_sync_error =~ "stuck in :processing"` and is a wording-level deviation from the must-have phrasing. The intent (mark `:errored` on stuck-threshold breach + emit `:stuck` telemetry) is satisfied. |

**Score:** 5/5 truths verified

### Cross-cutting truth (security invariant 14)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| C1 | Every `[:rindle, :provider, :ingest, _]` and `[:rindle, :provider, :sync, _]` event carries `metadata.asset_id` matching `~r/^\.\.\.[A-Za-z0-9]{4}$/` (redacted last-4 tag) — never raw 30+ char `provider_asset_id`. | VERIFIED | telemetry_test.exs cross-cutting parity test "every Phase 34 telemetry event redacts asset_id (no raw provider_asset_id leaks)" attaches handler to all five events, drives ingest+sync, asserts `asset_id == nil or asset_id =~ @redacted_id_regex` AND `refute asset_id =~ @raw_id_regex` for every captured event. PASSES. Also verified at workers — both ingest worker (line 383) and sync worker (line 200) flow `provider_asset_id` through `MediaProviderAsset.redact_id/1` before placing it in metadata. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `mix.exs` | Optional `:mux ~> 3.2` and `:jose ~> 1.11` deps; PLT add_apps includes both | VERIFIED | Lines 68-69 declare optional deps; line 22 has `plt_add_apps: [:mix, :ex_unit, :mux, :jose]`. |
| `lib/rindle/domain/media_provider_asset.ex` | Public `redact_id/1` callable from telemetry emit sites | VERIFIED | Lines 88-95 expose `def redact_id/1` (3 clauses); Inspect impl at line 119-129 delegates to public function. |
| `lib/rindle/streaming/provider/mux.ex` | Reference adapter with PLURAL Mux REST keys and explicit `:expiration` | VERIFIED | 357 lines. Optional-dep guard at line 3. `capabilities/0` returns `[:signed_playback, :webhook_ingest, :server_push_ingest]`. `build_create_params/2` at line 200 emits PLURAL `"inputs"` and `"playback_policies"`. `signed_playback_url/3` at line 261 passes `expiration: ttl` explicitly to `Mux.Token.sign_playback_id/2`. `verify_webhook/3` at line 272 loops secrets via `Enum.find_value`. |
| `lib/rindle/streaming/provider/mux/client.ex` | Internal Mox-mockable HTTP client behaviour | VERIFIED | Pure-Elixir behaviour with three callbacks (`create_asset/1`, `get_asset/1`, `delete_asset/1`). NOT wrapped in optional-dep guard (per Pitfall 4). |
| `lib/rindle/streaming/provider/mux/http.ex` | Real Mux SDK delegate; `Mux.Base.new/2` per call | VERIFIED | Optional-dep guard at line 1; `build_client/0` reads creds via `Application.get_env`. Normalizes 3-tuple SDK return to 2-tuple behaviour shape. |
| `lib/rindle/streaming/provider/mux/event.ex` | Pure-Elixir webhook event normalizer | VERIFIED (with caveat — see BL-03 in Human Verification) | Pure Elixir, no SDK refs (Pitfall 4). Maps Mux event JSON to Phase 33 `provider_event` shape. **Defect:** `extract_playback_ids/1` at line 44 will raise on explicit null `playback_ids` (BL-03). |
| `lib/rindle/workers/mux_ingest_variant.ex` | Server-push ingest worker (`:rindle_provider`, max_attempts: 5) | VERIFIED | 392 lines. Optional-dep guard at line 3. `use Oban.Worker, queue: :rindle_provider, max_attempts: 5` at line 80. Atomic-promote pattern mirrors `process_variant.ex:244-275`. Two-layer idempotency via `unique_job_opts/0` and `maybe_skip_already_in_progress/4`. 429 `Retry-After` translates to `{:snooze, retry_after}`. Telemetry redacts via `MediaProviderAsset.redact_id/1`. |
| `lib/rindle/workers/mux_sync_coordinator.ex` | Cron-driven coordinator (max_attempts: 1) | VERIFIED | 121 lines. Optional-dep guard at line 3. `use Oban.Worker, queue: :rindle_provider, max_attempts: 1` at line 69. Query at lines 85-93 selects stuck rows. Per-row unique constraint via `period: 60, keys: [:provider_asset_id]` at line 100 (Pitfall 6 mitigation). |
| `lib/rindle/workers/mux_sync_provider_asset.ex` | Per-row defensive sync (max_attempts: 3) | VERIFIED | 213 lines. Optional-dep guard at line 3. `use Oban.Worker, queue: :rindle_provider, max_attempts: 3` at line 44. `stuck?/1` predicate at line 74. PLURAL `playback_ids` write at line 171. FSM `transition/3` always called with MAP context. Telemetry redacts. |
| `test/support/mocks.ex` | `ClientMock` registration for downstream worker tests | VERIFIED | Line 7 registers `Rindle.Streaming.Provider.Mux.ClientMock`. |
| `test/fixtures/mux/test_signing_private_key.pem` | RSA-2048 signing key fixture | VERIFIED | File exists, valid PEM (used by signed_playback_url_test.exs and telemetry_test.exs). |
| `test/fixtures/mux/asset_create_201.json` etc. | 5 hand-derived JSON cassettes | VERIFIED | All 5 fixtures present (`asset_create_201.json`, `asset_get_processing.json`, `asset_get_ready.json`, `webhook_video_asset_ready.json`, `webhook_video_asset_errored.json`). |
| `test/rindle/streaming/provider/mux/*.exs` | Adapter test suite | VERIFIED | 4 test files: `optional_dep_test.exs`, `mux_test.exs`, `signed_playback_url_test.exs`, `telemetry_test.exs`. |
| `test/rindle/workers/mux_*_test.exs` | Worker test suites | VERIFIED | 3 test files: `mux_ingest_variant_test.exs` (9 tests), `mux_sync_coordinator_test.exs` (4 tests), `mux_sync_provider_asset_test.exs` (6 tests). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `lib/rindle/streaming/provider/mux.ex` | `lib/rindle/streaming/provider/mux/client.ex` | configurable `:http_client` config | WIRED | Line 348 `def http_client` reads from config with `Rindle.Streaming.Provider.Mux.HTTP` default. ClientMock can be injected per test. |
| `lib/rindle/streaming/provider/mux.ex` | `Mux.Token.sign_playback_id/2` | explicit `:expiration` keyword from `Rindle.Delivery.signed_url_ttl_seconds/1` | WIRED | Lines 257-264. Test signed_playback_url_test.exs:52 asserts `assert_in_delta exp, before_unix + ttl, 5`; line 56 asserts `refute exp > before_unix + 604_800`. |
| `lib/rindle/workers/mux_ingest_variant.ex` | `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3` | adapter-internal API; PLURAL keys NOT duplicated in worker | WIRED | Line 361. Confirmed via `grep -v '^[[:space:]]*#' | grep -c '"playback_policies"'` returning 0. |
| `lib/rindle/workers/mux_ingest_variant.ex` | `Rindle.Domain.MediaProviderAsset.redact_id/1` | telemetry redaction at every emit | WIRED | Line 383 in `base_metadata/3`. |
| `lib/rindle/workers/mux_sync_provider_asset.ex` | `Rindle.Streaming.Provider.Mux.get_asset/1` | per-row sync delegate | WIRED | Line 122. |
| `lib/rindle/workers/mux_sync_coordinator.ex` | `Rindle.Workers.MuxSyncProviderAsset` | `Oban.insert/2` with `unique: [period: 60, keys: [:provider_asset_id]]` | WIRED | Lines 97-102. |
| `lib/rindle/workers/mux_sync_provider_asset.ex` | `Rindle.Domain.MediaProviderAsset.redact_id/1` | telemetry redaction at every emit | WIRED | Line 200. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `mux_ingest_variant.ex` | `mux_response.playback_ids` | `Adapter.create_asset_with_retry_hint/3` (mux.ex:163) which calls `http_client().create_asset/1` | Yes — adapter returns PLURAL list extracted from Mux response via `extract_playback_id_strings/1` (mux.ex:313) | FLOWING |
| `mux_sync_provider_asset.ex` | `live_state, pids` | `adapter.get_asset(row.provider_asset_id)` (line 122) which routes through ClientMock in tests, real HTTP otherwise | Yes — adapter returns shaped `{:ok, %{state: _, playback_ids: _, raw: _}}` | FLOWING |
| `mux_sync_coordinator.ex` | `provider_asset_ids` | Direct Ecto query against `media_provider_assets` (lines 85-93) | Yes — real DB query, not static | FLOWING |
| `mux.ex signed_playback_url/3` | `jwt` | `Mux.Token.sign_playback_id(playback_id, expiration: ttl, ...)` (line 258) | Yes — real JOSE-signed JWT verifiable against test public key | FLOWING |
| `event.ex extract_playback_ids/1` | `data["playback_ids"]` | webhook payload | PARTIAL — works for missing key (default []) and list values; **crashes on explicit null** (BL-03) | STATIC (defective) — see Human Verification BL-03 |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Phase 34 test bundle (44 tests) | `mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_ingest_variant_test.exs test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs` | 44 tests, 0 failures | PASS |
| Strict compile | `mix compile --warnings-as-errors` | exit 0 | PASS |
| Optional-dep guards present | `grep -l "if Code.ensure_loaded?(Mux.Video.Assets) do" lib/rindle/streaming/provider/mux.ex lib/rindle/streaming/provider/mux/http.ex lib/rindle/workers/mux_ingest_variant.ex lib/rindle/workers/mux_sync_coordinator.ex lib/rindle/workers/mux_sync_provider_asset.ex` | 5 files | PASS |
| Optional-dep guard NOT on pure-Elixir behaviour/event | inspect `client.ex`, `event.ex` | confirmed unguarded (Pitfall 4) | PASS |
| Public `redact_id/1` exists | `grep -c "def redact_id" lib/rindle/domain/media_provider_asset.ex` | 3 clauses | PASS |
| ClientMock registered | `grep -c "Rindle.Streaming.Provider.Mux.ClientMock" test/support/mocks.ex` | 1 | PASS |
| `verify_webhook/3` callback shape | `grep -n "def verify_webhook" lib/rindle/streaming/provider/mux.ex` | line 272, accepts `secrets :: [String.t()]` | PASS |
| Atomic-promote race | `grep -c ":stale_source" lib/rindle/workers/mux_ingest_variant.ex` | 5 (asset/recipe × 2 check sites + cancel handler) | PASS |
| 429 Retry-After → snooze | `grep -c ":snooze" lib/rindle/workers/mux_ingest_variant.ex` | 2 | PASS |
| `expires_in: 1_800` (30 min) | `grep -n "expires_in: 1_800" lib/rindle/workers/mux_ingest_variant.ex` | line 112 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| MUX-01 | 34-01 | Optional `:mux`/`:jose` deps; zero transitive cost | SATISFIED | mix.exs:68-69 + plt_add_apps:22 |
| MUX-02 | 34-01 | Adapter implements every locked callback; creds via Application.get_env | SATISFIED | mux.ex implements 6 callbacks with `@impl Rindle.Streaming.Provider`; config reads via `Application.get_env(:rindle, __MODULE__, [])` |
| MUX-03 | 34-02 | `MuxIngestVariant` worker pushes variant via signed URL, persists IDs, advances FSM | SATISFIED | mux_ingest_variant.ex:96 perform/1; happy-path test PASSES |
| MUX-04 | 34-01 | Signed HLS URLs respect `signed_url_ttl_seconds` profile policy (no 7-day default) | SATISFIED | mux.ex:255-264; signed_playback_url_test.exs asserts `refute exp > before_unix + 604_800` |
| MUX-05 | 34-02 | Idempotent under Oban `unique` keyed on `(asset_id, profile, variant_name)` | SATISFIED | unique_job_opts/0 + perform-level skip; both tests PASS. (Plan adds `:available` to states list to handle the most-common dedup case — documented deviation from plan-locked list.) |
| MUX-06 | 34-02 | Atomic-promote on flip-to-ready aborts on storage_key/recipe_digest drift | SATISFIED | check_freshness/3 + persist_provider_processing/4 cond branches; both drift tests PASS |
| MUX-07 | 34-03 | `MuxSyncProviderAsset` polls + transitions to errored past stuck threshold | SATISFIED | mux_sync_coordinator.ex + mux_sync_provider_asset.ex; stuck-threshold test PASSES. Note: reason stored as `last_sync_error: "stuck in :<state> past threshold"` rather than literal atom `:provider_asset_stuck`. Functional intent met. |
| MUX-08 | 34-03/04 | Provider ingest+sync emit telemetry with documented schemas | SATISFIED | 5 events fire (ingest start/stop/exception, sync resolved/stuck); cross-cutting redaction parity test enforces security invariant 14 phase-wide; @moduledoc documents schemas on adapter + workers |

All 8 MUX-0X requirement IDs SATISFIED. No orphaned requirements (REQUIREMENTS.md table maps MUX-01..08 to Phase 34, all are claimed by Phase 34 plans 01-04).

### Anti-Patterns Found

Anti-patterns scanned across all Phase 34 modified files (mix.exs, lib/rindle/streaming/provider/mux*.ex, lib/rindle/workers/mux_*.ex, lib/rindle/domain/media_provider_asset.ex, test/support/mocks.ex, test/fixtures/mux/*, test/rindle/streaming/provider/mux/*.exs, test/rindle/workers/mux_*_test.exs, .dialyzer_ignore.exs).

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/rindle/streaming/provider/mux/event.ex` | 44-52 | `Map.get(data, "playback_ids", [])` returns nil on explicit null; subsequent `Enum.map(nil, _)` raises | Warning (BL-03) | Will crash `verify_webhook/3` on legitimate Mux webhook payloads (e.g., `video.asset.created`); Phase 35 wires the live plug, where this surfaces. Tests do not cover null payload. |
| `lib/rindle/workers/mux_ingest_variant.ex` | 277-281 | Comment claims FSM rejection is "safe" for `:errored` state; in fact `errored → uploading` is forbidden, so `:errored` re-perform burns max_attempts: 5 | Warning (BL-02) | Real defect on re-ingest of errored rows; not covered by tests. |
| `lib/rindle/workers/mux_ingest_variant.ex` | 302-349 | `persist_provider_processing/4` post-create freshness re-check returns `{:cancel, _}` without deleting the just-created Mux asset OR reverting row state | Warning (BL-01) | Mux billing/lifecycle leak; row stuck in `:uploading` until 7200s threshold. |
| `lib/rindle/streaming/provider.ex` (Phase 33) and `lib/rindle/streaming/provider/mux.ex` | spec vs impl | Behaviour `@callback get_asset` declares `state: provider_state()` (atoms) but adapter returns strings | Warning (BL-04) | Type contract incoherent; functional path works because schema column is `:string` and downstream operates on strings. |
| `lib/rindle/streaming/provider/mux.ex` | 298-304 | `fetch_sig_header/1` hardcodes 2 header casings; HTTP headers are case-insensitive | Warning (WR-02) | Adopters using different casings get false `:provider_webhook_invalid`. |
| `lib/rindle/streaming/provider/mux/http.ex` | 49-52 | `Keyword.fetch!(cfg, :token_id|:token_secret)` raises on missing config | Warning (WR-01) | Misconfiguration surfaces as KeyError mid-request, not clean `{:error, _}`. |
| `lib/rindle/workers/mux_sync_provider_asset.ex` | 159-161 | `:resolved` no-op path emits `age_ms` reflecting "time since last actual change" not "time since last sync" | Warning (WR-03) | Telemetry semantics inconsistent with `:stuck` event. |
| `lib/rindle/workers/mux_sync_provider_asset.ex` | 148-150 | `{:error, reason}` from `get_asset/1` does not write `last_sync_error` | Warning (WR-06) | After max_attempts: 3 exhausts, no operator breadcrumb. |
| `lib/rindle/workers/mux_sync_coordinator.ex` | 85-94 | Coordinator scan unbounded + unordered (no LIMIT, no ORDER BY) | Warning (WR-07) | Documented as out-of-scope in @moduledoc; Pitfall 6 acknowledged. |
| `lib/rindle/workers/mux_sync_coordinator.ex` | 95-104 | `Enum.count(&match?({:ok, _}, &1))` silently swallows `Oban.insert` failures | Warning (WR-08) | Operator log line under-reports failures. |
| `lib/rindle/workers/mux_ingest_variant.ex` | 163-175 | `:exception` event metadata adds raw `reason` term (not whitelisted/redacted) | Warning (WR-09) | If reason is a struct or string containing the asset id, redaction discipline bypassed at telemetry boundary. |

No INFO-severity items rise to blocker level. Three INFO items in REVIEW.md (`IN-01` Unix-string `created_at`, `IN-02` Application.put_env mutation pattern, `IN-03` playback_id URL escaping) are documented in the code review but do not block phase shipping.

**No raw `provider_asset_id` leaks found in any telemetry emit site.** The cross-cutting parity test enforces this phase-wide.

### Human Verification Required

Five items require pre-ship human review. None of them invalidate the explicit Phase 34 must-haves (which are 5/5 VERIFIED). They warrant pre-ship attention before phase close — see frontmatter `human_verification:` for full disposition. Summary:

1. **BL-01 (orphaned Mux asset on stale rejection)** — billing/lifecycle leak; design choice to fix here or defer to deferred-items.md.
2. **BL-02 (re-ingest from `:errored` breaks FSM)** — silent retry burn; not covered by tests; design choice on re-entry semantics.
3. **BL-03 (Event.extract_playback_ids/1 crashes on explicit null)** — small low-risk patch; will hit Phase 35 immediately if not fixed.
4. **BL-04 (behaviour @callback type spec violation)** — atom vs string mismatch; align spec to String.t() (cheaper) or convert at adapter (more disruptive).
5. **Live Mux integration** — Phase 36 territory (mux-soak GitHub Actions lane); confirm Mox cassettes still match real Mux REST API.

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|--------------|----------|
| 1 | Live webhook verification (signed payloads → live FSM transition to `:ready`) | Phase 35 | Phase 35 SC#2: HMAC-signed payload via WebhookPlug → `IngestProviderWebhook` → row to `:ready`. Phase 34 must-have #3 explicitly defers live verification. |
| 2 | WebhookPlug routing live HTTP requests to `verify_webhook/3` callback | Phase 35 | Phase 35 SC#1: mountable Plug with `forward` declaration. |
| 3 | Adopter onboarding guide referencing telemetry contract | Phase 36 | Plan SUMMARY notes: "Phase 36 ships the canonical adopter-wiring guide." |
| 4 | mux-soak GitHub Actions lane (live Mux integration) | Phase 36 | Plan SUMMARY: "Phase 34 stops at cassette-driven unit + integration smoke." |
| 5 | v1.7 cleanup of pre-existing Dialyzer pattern_match warnings | v1.7 stabilization | 5 ignore entries in `.dialyzer_ignore.exs`; Phase 34 surface itself is dialyzer-clean. |

### Gaps Summary

**No must-have gaps.** All 5 Phase 34 success criteria are functionally implemented and verified by passing tests (44/44 in the Phase 34 bundle). All 8 MUX-0X requirement IDs are claimed by Phase 34 plans and SATISFIED.

**Code review concerns surfaced as `human_needed` rather than `gaps_found`:** The 4 BLOCKER items in 34-REVIEW.md (BL-01..BL-04) are real defects that warrant pre-ship review, but they do not contradict the explicit must-have wording. They sit in edge cases (stale-source rollback, `:errored` re-entry, null webhook payloads, type-spec atom-vs-string) that the must-haves do not enumerate. Per the verifier's instructions for this phase ("16 code review findings should inform your assessment but do NOT auto-fail"), these route to human decision before phase close.

**Wording deviation noted (not failure):** Must-have #5 says "transitions to `:errored` with reason `:provider_asset_stuck`"; the actual implementation stores `last_sync_error: "stuck in :<state> past threshold"`. The functional intent (mark errored on stuck threshold + emit `:stuck` telemetry) is satisfied; the exact reason atom is not used. This was treated as wording-level rather than failure.

---

_Verified: 2026-05-06T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
