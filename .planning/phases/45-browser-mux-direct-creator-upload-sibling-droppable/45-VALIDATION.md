---
phase: 45
slug: browser-mux-direct-creator-upload-sibling-droppable
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-24
---

# Phase 45 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix LiveView test helpers + Oban.Testing + Mox |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/streaming/provider/mux/mux_test.exs test/rindle/workers/ingest_provider_webhook_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~60-120 seconds for the quick loop |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/streaming/provider/mux/mux_test.exs test/rindle/workers/ingest_provider_webhook_test.exs`
- **After every plan wave:** Run the plan-local tests plus `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 45-01-01 | 01 | 1 | MUX-20 | T-45-01 | Mux direct-upload request includes `cors_origin`, `playback_policies`, passthrough, and returns `%{upload_url, upload_id, provider_asset_id: nil}` | unit | `mix test test/rindle/streaming/provider/mux/mux_test.exs` | ✅ | ⬜ pending |
| 45-01-02 | 01 | 1 | MUX-20 | T-45-02 | `:direct_creator_upload` capability is advertised only by Mux and passthrough correlation is redacted on the schema layer | unit | `mix test test/rindle/streaming/provider/mux/mux_test.exs test/rindle/streaming/capabilities_test.exs` | ✅ | ⬜ pending |
| 45-02-01 | 02 | 2 | MUX-22 | T-45-03 | `Rindle.Streaming.create_direct_upload/2` creates a pending provider row, stamps passthrough, and returns only `%{upload_url, asset_id}` | integration | `mix test test/rindle/streaming/create_direct_upload_test.exs` | ❌ W0 | ⬜ pending |
| 45-02-02 | 02 | 2 | MUX-21 | T-45-04 | `video.upload.asset_created` links by passthrough, stamps `provider_asset_id`, transitions to `processing`, and broadcasts `:provider_asset_created` | integration | `mix test test/rindle/workers/ingest_provider_webhook_test.exs` | ✅ | ⬜ pending |
| 45-02-03 | 02 | 2 | MUX-21 | T-45-05 | Ready-event follow-up still drives the existing `:provider_asset_ready` path after the linker runs | integration | `mix test test/rindle/workers/ingest_provider_webhook_test.exs test/rindle/delivery/streaming_dispatch_test.exs` | ✅ | ⬜ pending |
| 45-03-01 | 03 | 3 | MUX-23 | T-45-06 | `MuxDirectUploadWeb` locks `ingest_mode: :direct_creator_upload` without mutating `MuxWeb` | unit | `mix test test/rindle/profile/presets/mux_direct_upload_web_test.exs` | ❌ W0 | ⬜ pending |
| 45-03-02 | 03 | 3 | MUX-23 | T-45-07 | `Rindle.LiveView.allow_direct_upload/4` uses the external-upload path without exposing raw Mux ids or `upload_url` outside the immediate handoff | integration | `mix test test/rindle/live_view_direct_upload_test.exs` | ❌ W0 | ⬜ pending |
| 45-03-03 | 03 | 3 | MUX-23 | T-45-08 | Guide and examples document controller baseline plus LiveView convenience path, and the provider-event flow proves both `:provider_asset_created` and `:provider_asset_ready` | integration | `mix test test/rindle/streaming/direct_upload_flow_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing Mux adapter, webhook worker, LiveView, preset, and delivery test infrastructure already exists.
- [ ] `test/rindle/streaming/create_direct_upload_test.exs` — public streaming entrypoint contract
- [ ] `test/rindle/profile/presets/mux_direct_upload_web_test.exs` — sibling preset contract
- [ ] `test/rindle/live_view_direct_upload_test.exs` — external-upload helper contract
- [ ] `test/rindle/streaming/direct_upload_flow_test.exs` — create -> upload asset created -> ready event flow

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Browser copy and visible state labels match `45-UI-SPEC.md` exactly | MUX-23 | UI copy hierarchy is partly documentation and adopter example posture, not just core behavior | Review `guides/streaming_providers.md` and helper examples for the locked strings and controller-first hierarchy |
| Public examples never expose raw `upload_id`, `provider_asset_id`, or persisted `upload_url` | MUX-20, MUX-22, MUX-23 | Secret leakage can happen in docs/snippets even when runtime code is correct | Grep docs and examples for `upload_id`, `provider_asset_id`, and raw upload URL handling before verification |

---

## Validation Sign-Off

- [x] All planned behaviors have automated verification or explicit Wave 0 tests
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all new test-file references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
