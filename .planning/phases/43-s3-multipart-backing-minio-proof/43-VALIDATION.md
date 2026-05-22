---
phase: 43
slug: s3-multipart-backing-minio-proof
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-23
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

> Planner refines task IDs in Wave 0. Requirement → behavior → command derived from RESEARCH.md §Validation Architecture.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | — | — | TUS-06 | — | `upload_part_stream/5` OPTIONAL callback; S3 buffers tail, UploadParts ≥ 5 MiB; ETag from headers | unit | `mix test test/rindle/storage/s3_tus_test.exs -x` | ❌ W0 | ⬜ pending |
| TBD | — | — | TUS-06 | — | S3 UploadPart round-trip via callback against MinIO | integration | `mix test test/rindle/storage/s3_test.exs --include minio` | ⚠️ extend | ⬜ pending |
| TBD | — | — | TUS-07 | — | `S3.capabilities/0` includes `:tus_upload`; `TusPlug.init/1` raises on adapter without it | unit | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/upload/tus_plug_test.exs` | ✅ extend | ⬜ pending |
| TBD | — | — | TUS-08 | — | Final PATCH → `complete_multipart_upload/4` → unchanged `verify_completion/2`; `PromoteAsset` enqueued | unit | `mix test test/rindle/upload/tus_plug_test.exs -x` | ✅ extend | ⬜ pending |
| TBD | — | — | TUS-08 | — | `verify_completion/2` byte-for-byte unchanged | review | `git diff broker.ex` shows no change to `verify_completion/2` | n/a | ⬜ pending |
| TBD | — | — | TUS-09 | T-43 cost-leak | Reaper branches on `resumable_protocol`: tus → `abort_multipart_upload`; gcs_native → cancel; legacy unchanged | unit | `mix test test/rindle/ops/upload_maintenance_test.exs -x` | ⚠️ extend | ⬜ pending |
| TBD | — | — | TUS-09 | T-43 cost-leak | ≥ 1 GiB drop+resume completes; abandoned upload → `list_multipart_uploads` empty | integration | `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/storage/s3_tus_test.exs` — TUS-06 tail-buffer logic (unit-test the 5 MiB slice/accumulate math via a pure buffering helper or fake `request`).
- [ ] `test/rindle/upload/tus_s3_integration_test.exs` — TUS-09 ≥ 1 GiB drop+resume + abort-leak assertion; `@tag :minio`.
- [ ] Extend `test/rindle/storage/storage_adapter_test.exs` — assert `:tus_upload in S3.capabilities()` (mirror the Local assertion from 42-01).
- [ ] Extend `test/rindle/ops/upload_maintenance_test.exs` — assert the tus branch (S3 multipart abort vs gcs_native cancel vs legacy).
- [ ] Extend `test/rindle/upload/tus_plug_test.exs` — S3-mock (`Mox`) PATCH→completion path proving adapter dispatch (no Local hard-wiring).
- [ ] No framework install needed — ExUnit / Oban.Testing / Mox all present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `verify_completion/2` byte-for-byte unchanged | TUS-08 | Review gate, not executable | `git diff lib/rindle/upload/broker.ex` shows no change to the `verify_completion/2` function body |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
