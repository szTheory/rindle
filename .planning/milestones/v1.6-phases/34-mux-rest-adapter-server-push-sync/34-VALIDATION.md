---
phase: 34
slug: mux-rest-adapter-server-push-sync
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-06
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) + Oban.Testing 2.22.1 + Mox 1.2 |
| **Config file** | `test/test_helper.exs` (verified — starts Repo, Sandbox, ExMarcel, adopter Repo, Oban with `testing: :manual`) |
| **Quick run command** | `mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_ingest_variant_test.exs test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1` |
| **Full suite command** | `mix test --max-failures 1` |
| **Estimated runtime** | ~30s (Phase 34 cassette suite) / ~3-5 min (full suite incl. existing) |

**Test exclusions:** `:integration, :minio, :contract, :adopter` excluded by default (verified `test_helper.exs:24-29`) — Phase 34 cassette tests run in default lane.

---

## Sampling Rate

- **After every task commit:** Run the file(s) touched by the task — e.g., a task that edits `mux_ingest_variant.ex` runs only `mix test test/rindle/workers/mux_ingest_variant_test.exs --max-failures 1`
- **After every plan wave:** Run the full Phase 34 test bundle (quick run command above) plus a smoke pass on `process_variant_test.exs` and `delivery_test.exs` to confirm no regressions
- **Before `/gsd-verify-work`:** Full suite green (`mix test --max-failures 1`) plus `mix dialyzer` (with PLT regen — `:mux` and `:jose` newly added) and `mix credo --strict`
- **Max feedback latency:** ~30s per quick task run; ~3-5 min for full suite

---

## Per-Task Verification Map

> Plans/tasks are not yet generated. The planner will populate this map. The map below seeds the requirement→test correspondence the planner must respect.

| Req ID | Behavior | Test Type | Automated Command | File Exists | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| MUX-01 | Optional dep wiring; PLT additions; `function_exported?(Rindle.Streaming.Provider.Mux, :create_asset, 3) == true` in test env | unit (smoke) | `mix test test/rindle/streaming/provider/mux/optional_dep_test.exs -x` | ❌ W0 | ⬜ pending |
| MUX-02 | Behaviour callbacks: `capabilities/0`, `create_asset/3`, `get_asset/1`, `delete_asset/1`, `signed_playback_url/3`, `verify_webhook/3` | unit (Mox-driven) | `mix test test/rindle/streaming/provider/mux/mux_test.exs -x` | ❌ W0 | ⬜ pending |
| MUX-03 | `MuxIngestVariant.perform/1` calls `Rindle.Streaming.Provider.Mux.Client.ClientMock.create_asset/2`, persists `provider_asset_id` + `playback_id`, advances FSM `pending → uploading → processing` | unit (Oban.Testing.perform_job/2 + Mox) | `mix test test/rindle/workers/mux_ingest_variant_test.exs -x` | ❌ W0 | ⬜ pending |
| MUX-04 | `streaming_url/3` returns Mux-signed JWT whose `exp` claim is `now + signed_url_ttl_seconds(profile)` (±5s); JWT verifies against test signing-public-key fixture | unit (cassette + JOSE verify) | `mix test test/rindle/streaming/provider/mux/signed_playback_url_test.exs -x` | ❌ W0 | ⬜ pending |
| MUX-05 | Re-running `MuxIngestVariant` with same `(asset_id, profile, variant_name)` yields the same `media_provider_assets` row, never a duplicate | unit (Oban.Testing) | `mix test test/rindle/workers/mux_ingest_variant_test.exs:idempotent -x` | ❌ W0 | ⬜ pending |
| MUX-06 | Atomic-promote: capture `expected_storage_key` + `expected_recipe_digest` at enqueue; mutate `storage_key`; next `perform/1` returns `{:cancel, {:stale_source, :asset_changed}}` and emits `[:rindle, :provider, :ingest, :exception]` with `kind: :cancelled` | unit (Oban.Testing + telemetry capture) | `mix test test/rindle/workers/mux_ingest_variant_test.exs:atomic_promote -x` | ❌ W0 | ⬜ pending |
| MUX-07 | `MuxSyncCoordinator` query returns `(processing, uploading)` rows older than 30s; fans out per-row jobs unique by `provider_asset_id`; per-row past `provider_stuck_threshold_seconds` transitions `:errored` and emits `[:rindle, :provider, :sync, :stuck]`; else `:resolved` | unit (Repo + Oban.Testing + telemetry) | `mix test test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs -x` | ❌ W0 | ⬜ pending |
| MUX-08 | Telemetry events emitted with documented schemas; `provider_asset_id` redacted to last-4-char tag (security invariant 14) | unit (`:telemetry.attach`) | `mix test test/rindle/streaming/provider/mux/telemetry_test.exs -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Cross-cutting parity test (MUX-08 + invariant 14):** A single ExUnit test attaches a telemetry handler, drives a 720p sample through `MuxIngestVariant` end-to-end (with a Mox `create_asset` cassette), and asserts that **every emitted telemetry event** has `metadata.asset_id` matching `~r/^\.\.\.[A-Za-z0-9]{4}$/` — never a raw 30+ char id. Highest-leverage parity test for security invariant 14.

---

## Wave 0 Requirements

All test files are NEW for Phase 34. Wave 0 (or first task in Wave 1) creates the test scaffolding before implementation tasks land:

- [ ] `test/rindle/streaming/provider/mux/optional_dep_test.exs` — covers MUX-01 (smoke + `function_exported?/3` assertion in test env)
- [ ] `test/rindle/streaming/provider/mux/mux_test.exs` — covers MUX-02 (capabilities, create/get/delete asset via Mox, webhook verify pure-function)
- [ ] `test/rindle/streaming/provider/mux/signed_playback_url_test.exs` — covers MUX-04 (JOSE-decodes the JWT; asserts `exp` claim within profile TTL)
- [ ] `test/rindle/streaming/provider/mux/telemetry_test.exs` — covers MUX-08 (`:telemetry.attach`; redaction parity)
- [ ] `test/rindle/workers/mux_ingest_variant_test.exs` — covers MUX-03, MUX-05, MUX-06 (worker contract, idempotent re-enqueue, atomic-promote)
- [ ] `test/rindle/workers/mux_sync_coordinator_test.exs` — covers MUX-07 (cron query + fan-out)
- [ ] `test/rindle/workers/mux_sync_provider_asset_test.exs` — covers MUX-07 (per-row sync + stuck transition)
- [ ] `test/support/mocks.ex` — extend with one line: `Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock, for: Rindle.Streaming.Provider.Mux.Client)`
- [ ] `test/fixtures/mux/asset_create_201.json` — captured Mux response (hand-derived per Open Question 3)
- [ ] `test/fixtures/mux/asset_get_processing.json`
- [ ] `test/fixtures/mux/asset_get_ready.json`
- [ ] `test/fixtures/mux/webhook_video_asset_ready.json`
- [ ] `test/fixtures/mux/webhook_video_asset_errored.json`
- [ ] `test/fixtures/mux/test_signing_private_key.pem` — generated via `openssl genrsa -out test_signing_private_key.pem 2048`; commit verbatim. Public half computed via JOSE.JWK at test runtime.

**Framework install:** Mox + Oban.Testing already pinned in `mix.exs` (`{:mox, "~> 1.2", only: :test}` and `{:oban, "~> 2.21"}`). No new test framework needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real Mux account upload smoke | MUX-03 (out-of-band) | Phase 34 ships cassette-only; soak lane (`mux-soak`) is Phase 36 / D-38 | Deferred to Phase 36 — Phase 34 test plan is automated end-to-end |

All Phase 34 in-scope behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s per quick run
- [ ] `nyquist_compliant: true` set in frontmatter
- [ ] Cross-cutting telemetry-redaction parity test asserted in MUX-08 file (security invariant 14)
- [ ] JOSE-decode `exp` claim assertion present in MUX-04 file (7-day default footgun guard)

**Approval:** pending
