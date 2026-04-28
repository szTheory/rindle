---
phase: 08
slug: storage-capability-confidence
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
revised: 2026-04-28
---

# Phase 08 — Validation Strategy

> Revised to close plan-checker blockers around CAP-02 lifecycle proof, CAP-03 provider-honesty verification, and Nyquist validation coverage.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + targeted `rg`/`mix docs` contract checks |
| **Config file** | `test/test_helper.exs`, `config/test.exs`, `mix.exs` |
| **Quick run command** | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/delivery_test.exs test/rindle/upload/broker_test.exs` |
| **Full phase command** | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/delivery_test.exs test/rindle/upload/broker_test.exs && mix test test/rindle/storage/s3_test.exs --include minio && mix test test/rindle/upload/lifecycle_integration_test.exs --include integration && mix test test/adopter/canonical_app/lifecycle_test.exs --include minio && mix docs` |
| **Estimated runtime** | ~10 seconds for Plan 01 seams, longer for MinIO-backed lanes plus docs generation |

---

## Sampling Rate

- **After every task commit:** Run the task-local command from the verification map below.
- **After every plan wave:** Run the full wave command for touched storage seams; Wave 1 must include the MinIO adapter, broker lifecycle, and adopter proof lanes.
- **Before `$gsd-verify-work`:** Run the full phase command.
- **Max feedback latency:** 90 seconds for unit/doc loops; longer only for MinIO-backed integration lanes.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|--------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | CAP-01, CAP-04 | T-08-01 | capability vocabulary is centralized and malformed adapter capability lists normalize safely | unit + contract | `mix test test/rindle/storage/storage_adapter_test.exs` | ✅ extend existing | ⬜ pending |
| 08-01-02 | 01 | 1 | CAP-01, CAP-04 | T-08-02, T-08-03 | upload and delivery gates route through one shared seam while preserving current tagged unsupported errors | unit + contract | `mix test test/rindle/delivery_test.exs test/rindle/upload/broker_test.exs` | ✅ extend existing | ⬜ pending |
| 08-02-01 | 02 | 1 | CAP-02 | T-08-04 | the shipped S3 adapter advertises both upload capabilities and satisfies them against real MinIO | adapter integration | `mix test test/rindle/storage/s3_test.exs --include minio` | ✅ extend existing | ⬜ pending |
| 08-02-02 | 02 | 1 | CAP-02 | T-08-05, T-08-06 | broker lifecycle and canonical adopter flows both prove presigned PUT and multipart under the same MinIO-backed capability contract | integration + adopter | `mix test test/rindle/upload/lifecycle_integration_test.exs --include integration && mix test test/adopter/canonical_app/lifecycle_test.exs --include minio` | ✅ extend existing | ⬜ pending |
| 08-03-01 | 03 | 2 | CAP-03, CAP-04 | T-08-08, T-08-09, T-08-10 | docs distinguish MinIO-backed proof from adopter-owned provider validation and describe additive future resumable semantics without overstating support | docs + static contract | `mix docs && rg -n "guides/storage_capabilities\\.md" mix.exs && rg -n "(Cloudflare R2|r2|resumable|upload_unsupported|delivery_unsupported|MinIO|compatibility target)" guides/storage_capabilities.md guides/profiles.md guides/secure_delivery.md` | ✅ create/extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ partial*

### Coverage of Phase Requirements

| Requirement | Covered By | Status |
|-------------|------------|--------|
| CAP-01 | 08-01-01, 08-01-02 | ✅ planned |
| CAP-02 | 08-02-01, 08-02-02 | ✅ planned |
| CAP-03 | 08-03-01 | ✅ planned |
| CAP-04 | 08-01-01, 08-01-02, 08-03-01 | ✅ planned |

---

## Wave 0 Requirements

Existing infrastructure covers all Phase 8 seams. MinIO remains the only automated real-provider dependency in repo CI for this phase; Cloudflare R2 is documented as an adopter-owned compatibility target rather than a separate in-repo proof lane.

---

## Validation Sign-Off

- [x] All planned tasks have automated verification coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all MISSING references.
- [x] No watch-mode flags.
- [x] Feedback latency target is defined.
- [x] `nyquist_compliant: true` set in frontmatter.
- [x] `wave_0_complete: true` set in frontmatter.

**Approval:** revised 2026-04-28
