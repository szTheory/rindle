---
phase: 39
slug: resumable-adapter-behaviour-broker-wiring
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 39 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mox + Bypass |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/storage/gcs/client_test.exs test/rindle/storage/gcs_test.exs test/rindle/upload/broker_test.exs -x` |
| **Full suite command** | `mix test` |
| **GCS integration command** | `mix test test/rindle/storage/gcs_test.exs --only gcs -x` |
| **Estimated runtime** | ~45-75 seconds for targeted suite; live GCS lane depends on network and bucket state |

---

## Sampling Rate

- **After every task commit:** Run the touched file tests plus any directly coupled contract tests.
- **After every plan wave:** Run the quick run command above.
- **Before `$gsd-verify-work`:** Run `mix test`; if GCS secrets are available, also run `mix test test/rindle/storage/gcs_test.exs --only gcs -x`.
- **Max feedback latency:** under 90 seconds for non-live verification.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 39-01-01 | 01 | 1 | RESUMABLE-04 | T-39-01 / T-39-03 | `Rindle.Storage` exposes optional resumable callbacks with locked shapes and does not broaden broker trust semantics | contract | `mix test test/rindle/storage/storage_adapter_test.exs -x` | ✅ | ⬜ pending |
| 39-01-02 | 01 | 1 | RESUMABLE-07 | T-39-02 | Local and S3 stay non-resumable and fail with tagged unsupported errors | contract | `mix test test/rindle/storage/storage_adapter_test.exs -x` | ✅ | ⬜ pending |
| 39-02-01 | 02 | 2 | RESUMABLE-05 | T-39-04 / T-39-05 | GCS client initiation/status/cancel/verify follow official resumable protocol, map 308/404/410/errors correctly, and keep session URIs secret-safe | unit | `mix test test/rindle/storage/gcs/client_test.exs -x` | ✅ | ⬜ pending |
| 39-02-02 | 02 | 2 | RESUMABLE-05, RESUMABLE-08 | T-39-06 | `Rindle.Storage.GCS` advertises resumable capabilities honestly and delegates through the existing client path | unit | `mix test test/rindle/storage/gcs/client_test.exs test/rindle/storage/gcs_test.exs -x` | ✅ | ⬜ pending |
| 39-03-01 | 03 | 3 | RESUMABLE-06 | T-39-07 / T-39-08 | Broker initiation is remote-first, persist-after-storage, and compensates with `cancel_resumable_upload/3` on persist failure | integration | `mix test test/rindle/upload/broker_test.exs -x` | ✅ | ⬜ pending |
| 39-03-02 | 03 | 3 | RESUMABLE-06, RESUMABLE-07 | T-39-08 / T-39-09 | Broker status/cancel are capability-gated, observational by default, and `verify_completion/2` still trusts only `head/2` | integration | `mix test test/rindle/upload/broker_test.exs -x` | ✅ | ⬜ pending |
| 39-04-01 | 04 | 4 | RESUMABLE-08 | T-39-10 / T-39-11 / T-39-12 | Live GCS proof uses resumable `PUT` requests, converges through `verify_completion/2`, and leaves unsupported adapters explicitly unsupported | live integration | `mix test test/rindle/storage/gcs_test.exs --only gcs -x` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `test/rindle/storage/storage_adapter_test.exs` for optional-callback contract checks and explicit resumable unsupported assertions on Local/S3.
- [ ] Extend `test/rindle/storage/gcs/client_test.exs` with Bypass cases for resumable initiation, `308` status parsing, `404`, `410`, offset mismatch, and generic `{:gcs_http_error, _}` fallthrough.
- [ ] Extend `test/rindle/storage/gcs_test.exs` to flip GCS capability assertions to the shipped resumable list and to add the secret-gated live proof lane.
- [ ] Extend `test/rindle/upload/broker_test.exs` with resumable initiation/status/cancel, persist-compensation, non-resumable row rejection, and “do not call `verify_resumable_completion/3` from broker” coverage.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live GCS resumable proof against a real bucket | RESUMABLE-08 | Requires real credentials, network, and bucket state outside isolated unit tests | Set `GOOGLE_APPLICATION_CREDENTIALS_JSON` and `RINDLE_GCS_BUCKET`, run `mix test test/rindle/storage/gcs_test.exs --only gcs -x`, and confirm the proof uses resumable `PUT` uploads plus final `verify_completion/2` promotion |
| Region-pin advisory review | RESUMABLE-08 | Exact provider headers/metadata may vary by environment and are primarily an operator-observability concern | If region pin metadata is surfaced during live testing, confirm it is returned as non-fatal advisory data or telemetry and not as a returned broker error |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or a documented live/manual verification path
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing test expansions referenced by the plans
- [x] No watch-mode flags
- [x] Feedback latency is bounded for non-live checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
