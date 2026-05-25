---
phase: 43
slug: s3-multipart-backing-minio-proof
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-23
validated: 2026-05-23
---

# Phase 43 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) + `Oban.Testing` (`testing: :inline`) + `Mox` (adapter unit-mocking) |
| **Config file** | `config/test.exs` (Repo + Oban); `test/test_helper.exs` (sandbox + tag exclusion) |
| **Quick run command** | `mix test test/rindle/storage/ test/rindle/upload/tus_plug_test.exs test/rindle/ops/upload_maintenance_test.exs` |
| **Full suite command** | `mix test` (excludes `:integration,:minio,:contract,:adopter` by default) |
| **MinIO proof command** | `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` |
| **Estimated runtime** | ~30s quick / ~2–5 min MinIO proof (≥ 1 GiB transfer) |

---

## Sampling Rate

- **After every task commit:** Run the relevant quick unit command (`-x` fail-fast) for the file touched.
- **After every plan wave:** Run `mix test test/rindle/storage/ test/rindle/upload/ test/rindle/ops/` (full non-MinIO tus surface).
- **Before `/gsd:verify-work`:** `mix test` green (default exclusions) AND the `@tag :minio` proof green in the CI integration lane.
- **Max feedback latency:** ~30 seconds (quick), MinIO proof gated to wave merge / phase gate only.

---

## Per-Task Verification Map

> Reconciled against the executed phase on 2026-05-23. Task IDs map to the delivering plan; statuses confirmed by a live `mix test` run (non-MinIO suite) + the orchestrator's live MinIO run (3/3, see VERIFICATION.md `minio_live_run`).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 43-02 | 43-02 (+06/07/08/12) | 2 | TUS-06 | — | `upload_part_stream/5` OPTIONAL callback; S3 buffers tail, UploadParts ≥ 5 MiB; ETag from headers; cross-node tail guard | unit | `mix test test/rindle/storage/s3_tus_test.exs` | ✅ | ✅ green (11 tests) |
| 43-05 | 43-05 (+10) | 4 | TUS-06 | — | S3 UploadPart round-trip via callback against MinIO (exercised by ≥ 1 GiB drop+resume) | integration | `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` | ✅ | ✅ green (live 3/3, gated `:minio`) |
| 43-02 | 43-02 (+04) | 2 | TUS-07 | — | `S3.capabilities/0` includes `:tus_upload`; Local yes, GCS no; `TusPlug.init/1` raises on adapter without it | unit | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/upload/tus_plug_test.exs` | ✅ | ✅ green |
| 43-04 | 43-04 (+09/11) | 3 | TUS-08 | — | Final PATCH → `complete_part_stream/4`/`complete_multipart_upload/4` → unchanged `verify_completion/2` lane | unit | `mix test test/rindle/upload/tus_plug_test.exs` | ✅ | ✅ green (28 tests) |
| — | 43-04 | 3 | TUS-08 | — | `verify_completion/2` byte-for-byte unchanged | review | `git diff broker.ex` shows no change to `verify_completion/2` | n/a | ✅ manual-only (see below) |
| 43-03 | 43-03 (+11) | 2 | TUS-09 | T-43 cost-leak | Reaper branches on `resumable_protocol`: tus → `abort_multipart_upload`; gcs_native → cancel; legacy unchanged; abort-failure retry marker | unit | `mix test test/rindle/ops/upload_maintenance_test.exs` | ✅ | ✅ green (44 tests) |
| 43-05 | 43-05 (+10) | 4 | TUS-09 | T-43 cost-leak | ≥ 1 GiB drop+resume completes; abandoned upload → `list_multipart_uploads` empty; DELETE zero-leak; post-reap tail removed | integration | `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` | ✅ | ✅ green (live 3/3, gated `:minio`) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/rindle/storage/s3_tus_test.exs` — TUS-06 tail-buffer logic + CR-04 cross-node guard (11 tests green). Delivered by 43-02, extended by 06/07/08/12.
- [x] `test/rindle/upload/tus_s3_integration_test.exs` — TUS-09 ≥ 1 GiB drop+resume + abort-leak assertion; `@moduletag :minio` (live 3/3). Delivered by 43-05, extended by 10.
- [x] Extend `test/rindle/storage/storage_adapter_test.exs` — asserts `:tus_upload in S3.capabilities()` (line 117), Local yes (line 112), GCS refute (line 125).
- [x] Extend `test/rindle/ops/upload_maintenance_test.exs` — asserts the tus branch (S3 multipart abort vs gcs_native cancel vs legacy) at lines 689–727 (44 tests green).
- [x] Extend `test/rindle/upload/tus_plug_test.exs` — `StorageMock` (`Mox`) PATCH→completion path proving adapter dispatch (28 tests green).
- [x] No framework install needed — ExUnit / Oban.Testing / Mox all present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `verify_completion/2` byte-for-byte unchanged | TUS-08 | Review gate, not executable | `git diff lib/rindle/upload/broker.ex` shows no change to the `verify_completion/2` function body |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-05-23 (retroactive audit — all automated requirements covered + green)

---

## Validation Audit 2026-05-23

Retroactive audit (State A) reconciling the draft validation contract against the executed phase.

| Metric | Count |
|--------|-------|
| Requirements audited | 4 (TUS-06, TUS-07, TUS-08, TUS-09) |
| Gaps found | 0 |
| Resolved | 0 (all already covered) |
| Escalated | 0 |
| Manual-only | 1 (TUS-08 `verify_completion/2` byte-for-byte review) |

**Method:** Cross-referenced each Wave-0 test against the filesystem (all 5 files present), confirmed requirement-targeting assertions via grep, and ran the non-MinIO quick suite live: `143 tests, 0 failures, 1 skipped (4 excluded)`. The MinIO integration lane (gated `:minio`) was run live 3/3 by the execute-phase orchestrator (VERIFICATION.md `minio_live_run`, 2026-05-23T13:55Z). No auditor spawn or gap-fill needed — the phase was already Nyquist-compliant.
