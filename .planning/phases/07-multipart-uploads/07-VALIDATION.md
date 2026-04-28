---
phase: 7
slug: multipart-uploads
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Oban testing + Ecto SQL Sandbox |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/rindle/upload/broker_test.exs test/rindle/storage/s3_test.exs test/rindle/ops/upload_maintenance_test.exs test/rindle/workers/maintenance_workers_test.exs` |
| **Full suite command** | `mix test` plus `mix test test/adopter/canonical_app/lifecycle_test.exs --include minio` when validating real multipart storage flows |
| **Estimated runtime** | ~30 seconds for targeted seam checks on a warm build; longer when MinIO-backed adopter proof is included |

---

## Sampling Rate

- **After every task commit:** Run the quick command for broker/storage/maintenance seams touched by the task
- **After every plan wave:** Run `mix test` and add the MinIO adopter command for any wave that changes multipart storage behavior
- **Before `$gsd-verify-work`:** Full suite plus the multipart-specific MinIO adopter proof must be green
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|--------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 7-XX-01 | pending | pending | MULT-01, MULT-04 | T-07-01 | Multipart initiation and part-signing are capability-gated and return tagged unsupported errors on adapters without multipart support | unit + contract | `mix test test/rindle/upload/broker_test.exs test/rindle/storage/storage_adapter_test.exs` | ✅ extend existing | ⬜ pending |
| 7-XX-02 | pending | pending | MULT-01, MULT-02 | T-07-02 | S3 adapter wraps initiate/upload-part/complete/abort primitives and generates signed UploadPart URLs without proxying bytes through Phoenix | unit | `mix test test/rindle/storage/s3_test.exs` | ✅ extend existing | ⬜ pending |
| 7-XX-03 | pending | pending | MULT-02 | T-07-03 | Completing multipart upload re-enters the existing verification/promotion lane and only promotes after storage metadata verification | unit + integration | `mix test test/rindle/upload/broker_test.exs test/rindle/upload/lifecycle_integration_test.exs` | ✅ extend existing | ⬜ pending |
| 7-XX-04 | pending | pending | MULT-03 | T-07-04 | Timed-out multipart sessions expire on the runtime repo seam and remote abort failures retain enough authority for retry | unit + worker | `mix test test/rindle/ops/upload_maintenance_test.exs test/rindle/workers/maintenance_workers_test.exs` | ✅ extend existing | ⬜ pending |
| 7-XX-05 | pending | pending | MULT-01, MULT-02, MULT-03 | T-07-02, T-07-03, T-07-04 | Canonical adopter proof performs a real MinIO-backed multipart happy path and a cleanup/abort path without falling back to `Rindle.Repo` | adopter integration | `mix test test/adopter/canonical_app/lifecycle_test.exs --include minio` | ✅ extend existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] Extend `test/rindle/upload/broker_test.exs` with multipart capability gating, part-signing, manifest persistence, and completion cases
- [ ] Extend `test/rindle/storage/s3_test.exs` with multipart initiate/complete/abort/list wrapper coverage and signed UploadPart URL assertions
- [ ] Extend `test/rindle/ops/upload_maintenance_test.exs` with runtime-repo seam assertions plus multipart abort and retry semantics
- [ ] Extend `test/rindle/workers/maintenance_workers_test.exs` so worker coverage includes multipart abandonment paths
- [ ] Extend `test/rindle/upload/lifecycle_integration_test.exs` for broker-level multipart verification flow
- [ ] Extend `test/adopter/canonical_app/lifecycle_test.exs` with a real MinIO multipart happy path and abandoned-upload cleanup proof

*Existing infrastructure covers the framework and sandbox setup; Wave 0 here is test-surface expansion, not framework installation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Multipart flow works against a real S3-compatible endpoint from a fresh shell session | MULT-02, MULT-03 | Automated adopter proof should cover this, but one manual confirmation is useful if MinIO or Docker drift causes environment-specific failures | Start the local MinIO test dependency, run `mix test test/adopter/canonical_app/lifecycle_test.exs --include minio`, then manually inspect the test log to confirm initiate -> upload parts -> complete -> verify -> promote and abandoned-upload abort behavior |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify steps or explicit Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all multipart broker/storage/maintenance/adopter seams
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
