---
phase: 124
slug: upload-path-clarity
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-22
---

# Phase 124 — Validation Strategy

> Per-phase validation contract for a behavior-preserving tus and upload-broker decomposition.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Ecto SQL Sandbox, Mox, Oban Testing |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/broker_test.exs --seed 0` |
| **Full suite command** | `mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/broker_test.exs test/rindle/upload/tus_local_backing_test.exs test/rindle/upload/lifecycle_integration_test.exs --include integration --seed 0` |
| **Estimated runtime** | under 90 seconds locally; environment-provisioned S3 proof runs in CI |

## Sampling Rate

- **After every task commit:** Run the focused suite for the façade or collaborator changed.
- **After every plan wave:** Run the full phase suite and `bash scripts/maintainer/refactor_contract.sh`.
- **Before phase verification:** Run `mix ci`, the full phase suite, SAFE-01, and the exact scope audit.
- **Acceptance authority:** Required `CI Summary` on supported Elixir 1.17 / OTP 27 for the exact PR head.
- **Max feedback latency:** 90 seconds for task-local proof; full/CI gates may take longer.

## Per-Task Verification Map

| Task ID | Plan owner | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 124-01-T1 | Plan 124-01 Task 1 — creation tracer and compiled boundary | 1 | UPLOAD-01, UPLOAD-02 | T-124-01, T-124-03 | signed creation crosses the unchanged Broker boundary without expanding public API or leaking the URI | contract/unit | `mix test test/rindle/upload/tus_plug_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` | ✅ | ✅ green — plan receipt and current aggregate |
| 124-01-T2 | Plan 124-01 Task 2 — partial/final creation | 1 | UPLOAD-01 | T-124-01 | partial/final claims, token ordering, Broker concatenation, and responses remain exact | unit | `mix test test/rindle/upload/tus_plug_test.exs --seed 0` | ✅ | ✅ green — plan receipt and current aggregate |
| 124-02-T1 | Plan 124-02 Task 1 — token/HEAD protocol | 2 | UPLOAD-01 | T-124-01 | verify/load/authorize order and 404/401/410 vocabulary remain exact | unit | `mix test test/rindle/upload/tus_plug_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` | ✅ | ✅ green — plan receipt and current aggregate |
| 124-02-T2 | Plan 124-02 Task 2 — PATCH/creation parsing | 2 | UPLOAD-01 | T-124-02, T-124-03 | 415/409, length, checksum, and size gates precede storage/body effects | unit | `mix test test/rindle/upload/tus_plug_test.exs --seed 0` | ✅ | ✅ green — plan receipt and current aggregate |
| 124-03-T1 | Plan 124-03 Task 1 — PATCH storage | 3 | UPLOAD-01 | T-124-02, T-124-03 | bounded Local/S3 adapter-polymorphic stream state and completion order remain intact | unit/integration | `mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/tus_local_backing_test.exs --seed 0` | ✅ | ✅ green — local current aggregate; supported S3 receipt below |
| 124-03-T2 | Plan 124-03 Task 2 — DELETE termination | 3 | UPLOAD-01 | T-124-01, T-124-04 | auth-before-storage, storage-before-state, retry marker, and two failure contracts remain intact | unit | `mix test test/rindle/upload/tus_plug_test.exs --seed 0` | ✅ | ✅ green — plan receipt and current aggregate |
| 124-04-T1 | Plan 124-04 Task 1 — Broker seed/persistence | 4 | UPLOAD-02 | T-124-01, T-124-04 | capability gates, persisted strategy values, and adjacent compensation behavior remain intact | unit | `mix test test/rindle/upload/broker_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` | ✅ | ✅ green — plan receipt and current aggregate |
| 124-04-T2 | Plan 124-04 Task 2 — Broker validation | 4 | UPLOAD-02 | T-124-02, T-124-04 | guards, part normalization, status attrs, adapter calls, and public errors remain exact | unit | `mix test test/rindle/upload/broker_test.exs --seed 0` | ✅ | ✅ green — plan receipt and current aggregate |
| 124-05-T1 | Plan 124-05 Task 1 — Broker completion | 5 | UPLOAD-02 | T-124-02, T-124-04 | exact transaction keys/order and post-commit telemetry/broadcasts remain intact | unit/integration | `mix test test/rindle/upload/broker_test.exs test/rindle/upload/lifecycle_integration_test.exs --include integration --seed 0` | ✅ | ✅ green — plan receipt and current aggregate |
| 124-05-T2 | Plan 124-05 Task 2 — cross-adapter/phase authority | 5 | UPLOAD-01, UPLOAD-02, SAFE-01 | T-124-01–05 | protocol, Local/S3 adapter, API, telemetry, error, schema, scope, and release boundaries remain preserved | contract/integration/CI | `bash scripts/maintainer/refactor_contract.sh && mix ci && ./scripts/maintainer/repo_hygiene_check.sh` | ✅ | ✅ green — exact-head PR CI/S3 and final-gate receipts |

## Wave 0 Requirements

Existing infrastructure covers both phase requirements. Executors may add only objective behavior or
compiled-boundary assertions for an otherwise unguarded extraction seam; source-text/helper snapshots are
prohibited.

## Environment-Provisioned Verification

| Behavior | Requirement | Authority | Automated Command |
|----------|-------------|-----------|-------------------|
| S3 multipart resume, completion, DELETE, and reaper behavior | UPLOAD-01 | CI MinIO lane | `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio --seed 0` |
| Supported compiler/runtime and full merge topology | UPLOAD-01, UPLOAD-02 | PR CI | required `CI Summary` on Elixir 1.17 / OTP 27 for the exact head SHA |

## Threat References

- **T-124-01:** forged, expired, or unauthorized resumable URL reaches session/storage data.
- **T-124-02:** offset replay or invalid protocol input mutates storage or consumes a request body.
- **T-124-03:** oversized PATCH buffering creates a denial-of-service path.
- **T-124-04:** failed persistence or reordered termination/completion leaks backing data or emits success side effects early.

## Validation Sign-Off

- [x] Every requirement has focused automated proof and an exact phase gate.
- [x] Sampling continuity requires task-local proof after each extraction.
- [x] Existing fixtures cover Wave 0; no framework installation is needed.
- [x] No watch-mode flags are used.
- [x] Environment-only S3 and supported-toolchain checks have explicit CI authority.
- [x] `nyquist_compliant: true` is set in frontmatter.

## Validation Audit 2026-08-23

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Current-checkout receipt: `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/broker_test.exs test/rindle/upload/tus_local_backing_test.exs test/rindle/upload/lifecycle_integration_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/contracts/telemetry_contract_test.exs --include integration --seed 0` passed: **102 tests, 0 failures, 3 skipped (15 excluded)**. This covers each task-local behavioral suite plus the API and telemetry contracts.

The original exact-head final gate is recorded in `124-05-SUMMARY.md` and `124-VERIFICATION.md`: PR #86, SHA `00509807dadcd2b3f714f50d885c07689b1dd8ee`, Actions run `32619136517`, Integration `97144903971`, and CI Summary `97145910475` all passed on Elixir 1.17 / OTP 27. Later type-only corrections in `Broker` and `TusStream` have their own supported S3 receipt in Phase 126 (`32644554878`), while the current aggregate above remains green.

**Approval:** validated 2026-08-23; final PLAN.md task ownership reconciled to executed green proof.
