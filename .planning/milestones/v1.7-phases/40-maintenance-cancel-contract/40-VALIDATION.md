---
phase: 40
slug: maintenance-cancel-contract
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 40 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mox + Bypass + Oban.Testing |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/ops/upload_maintenance_test.exs test/rindle/workers/maintenance_workers_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs test/rindle/storage/gcs/client_test.exs -x` |
| **Full suite command** | `mix test` |
| **GCS integration command** | `mix test test/rindle/upload/broker_test.exs --only gcs -x` |
| **Estimated runtime** | ~60-90 seconds for the targeted suite; live GCS lane depends on network, credentials, and bucket state |

---

## Sampling Rate

- **After every task commit:** Run the touched-file tests plus directly coupled contract tests from the quick run command above.
- **After every plan wave:** Run the full quick run command above.
- **Before `$gsd-verify-work`:** Run `mix test`; if GCS secrets are available, also run `mix test test/rindle/upload/broker_test.exs --only gcs -x`.
- **Max feedback latency:** under 90 seconds for local verification; live GCS proof is explicitly secret-gated.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 40-01-01 | 01 | 1 | RESUMABLE-09, RESUMABLE-10 | T-40-01 / T-40-02 / T-40-04 | Timed-out resumable rows are cancelled only from the abort lane; `404`/`410` idempotent outcomes clear `session_uri`; bounded `failure_reason` values hide provider detail | unit + protocol | `mix test test/rindle/ops/upload_maintenance_test.exs test/rindle/storage/gcs/client_test.exs -x` | ✅ | ⬜ pending |
| 40-01-02 | 01 | 1 | RESUMABLE-10 | T-40-03 | Abort worker emits worker-only telemetry and fails when `abort_errors > 0` so Oban retries engage | worker | `mix test test/rindle/workers/maintenance_workers_test.exs test/rindle/ops/upload_maintenance_test.exs -x` | ✅ | ⬜ pending |
| 40-02-01 | 02 | 2 | RESUMABLE-10 | T-40-05 / T-40-07 | Cleanup deletes resumable rows only when the local proof marker is present and never issues remote cancel | unit | `mix test test/rindle/ops/upload_maintenance_test.exs -x` | ✅ | ⬜ pending |
| 40-02-02 | 02 | 2 | RESUMABLE-10 | T-40-06 / T-40-07 | Cleanup worker/task surface proof-missing skips as additive drift without leaking `session_uri` or failing successful local-only cleanup | worker | `mix test test/rindle/workers/maintenance_workers_test.exs test/rindle/ops/upload_maintenance_test.exs -x` | ✅ | ⬜ pending |
| 40-03-01 | 03 | 3 | RESUMABLE-11 | T-40-08 / T-40-09 | `runtime_status` adds the three locked resumable counters under `upload_sessions` and keeps recommendations on the existing maintenance lane | unit | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs -x` | ✅ | ⬜ pending |
| 40-03-02 | 03 | 3 | RESUMABLE-10, RESUMABLE-11 | T-40-10 / T-40-11 | Secret-gated live GCS proof exercises initiate -> cancel -> runtime_status -> cleanup and initiate -> expire -> runtime_status -> cleanup without exposing session URIs | live integration | `mix test test/rindle/upload/broker_test.exs --only gcs -x` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/rindle/ops/upload_maintenance_test.exs` already exists and is the main seam for resumable abort, failure-taxonomy, and proof-gated cleanup coverage.
- [x] `test/rindle/workers/maintenance_workers_test.exs` already exists and is the worker retry/telemetry seam for both maintenance workers.
- [x] `test/rindle/ops/runtime_status_test.exs` and `test/rindle/runtime_status_task_test.exs` already exist for counter and formatter assertions.
- [x] `test/rindle/upload/broker_test.exs` already exists and is the correct secret-gated live GCS harness to extend for maintenance proof.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live GCS maintenance proof against a real bucket | RESUMABLE-10, RESUMABLE-11 | Requires real credentials, network, and bucket state outside isolated local tests | Set `GOOGLE_APPLICATION_CREDENTIALS_JSON` and `RINDLE_GCS_BUCKET`, run `mix test test/rindle/upload/broker_test.exs --only gcs -x`, and confirm both maintenance scenarios surface runtime-status visibility before cleanup |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify steps or a documented live/manual verification path
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all referenced verification seams
- [x] No watch-mode flags
- [x] Feedback latency is bounded for non-live checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
