---
phase: 124
slug: upload-path-clarity
status: draft
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
| 124-TUS-BOUNDARY | Tus characterization / boundary plan | 1 | UPLOAD-01 | T-124-01 | hidden collaborators do not expand public API | contract | `mix test test/rindle/api_surface_boundary_test.exs --seed 0` | ✅ | ⬜ pending |
| 124-TUS-PROTOCOL | Tus protocol extraction plan | 1–2 | UPLOAD-01 | T-124-01, T-124-02, T-124-03 | auth, headers, offsets, checksums, and size gates precede storage/body effects | unit | `mix test test/rindle/upload/tus_plug_test.exs --seed 0` | ✅ | ⬜ pending |
| 124-TUS-STORAGE | Tus storage/termination plan | 2 | UPLOAD-01 | T-124-02, T-124-04 | Local/S3 adapter polymorphism and storage-before-state abort ordering remain intact | integration | `mix test test/rindle/upload/tus_local_backing_test.exs --seed 0` | ✅ | ⬜ pending |
| 124-BROKER-LIFECYCLE | Broker initiation/persistence plan | 2 | UPLOAD-02 | T-124-04 | capability gates, persisted strategy values, and compensation behavior remain intact | unit | `mix test test/rindle/upload/broker_test.exs --seed 0` | ✅ | ⬜ pending |
| 124-BROKER-COMPLETION | Broker completion plan | 2 | UPLOAD-02 | T-124-04 | transaction keys/order and post-commit telemetry/broadcasts remain intact | integration | `mix test test/rindle/upload/lifecycle_integration_test.exs --include integration --seed 0` | ✅ | ⬜ pending |
| 124-CROSS-ADAPTER | Phase integration plan | 3 | UPLOAD-01, UPLOAD-02 | T-124-01–04 | protocol, adapter, API, telemetry, error, schema, and release boundaries remain preserved | contract/integration | `bash scripts/maintainer/refactor_contract.sh` | ✅ | ⬜ pending |

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

**Approval:** approved 2026-08-22 for planning; task IDs must be reconciled to final PLAN.md ownership.
