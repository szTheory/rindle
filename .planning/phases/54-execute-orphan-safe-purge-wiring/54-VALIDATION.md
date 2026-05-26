---
phase: 54
slug: execute-orphan-safe-purge-wiring
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-26
validated: 2026-05-26
---

# Phase 54 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/owner_erasure_test.exs test/rindle/workers/purge_storage_test.exs test/rindle/attach_detach_test.exs` |
| **Full suite command** | `mix test test/rindle/owner_erasure_test.exs test/rindle/workers/purge_storage_test.exs test/rindle/attach_detach_test.exs test/rindle/upload/lifecycle_integration_test.exs test/adopter/canonical_app/lifecycle_test.exs` |
| **Estimated runtime** | ~30-60s depending on DB + Oban setup |

---

## Sampling Rate

- **After every task commit:** Run the narrowest task-scoped Mix command from the verification map.
- **After every plan wave:** Run `mix test test/rindle/owner_erasure_test.exs test/rindle/workers/purge_storage_test.exs test/rindle/attach_detach_test.exs`.
- **Before `$gsd-verify-work`:** Run the full suite command and confirm idempotent rerun coverage stays green.
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 54-01-01 | 01 | 1 | LIFE-02, LIFE-03 | T-54-01 | Preview/execute contract tests freeze the semantic buckets, `mode`, and retained-shared-asset reporting before implementation turns green. | unit | `mix test test/rindle/owner_erasure_test.exs --seed 0` | ✅ | ✅ green |
| 54-01-02 | 01 | 1 | LIFE-02, LIFE-03, LIFE-04 | T-54-01, T-54-02, T-54-03, T-54-04 | The shared internal planner and execute path recompute from live rows, delete owner attachments transactionally, and treat active-state purge conflicts as semantic success. | service | `mix test test/rindle/owner_erasure_test.exs --seed 0` | ✅ | ✅ green |
| 54-01-03 | 01 | 1 | LIFE-02, LIFE-03, LIFE-04 | T-54-01, T-54-03, T-54-04 | Public `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` exports match the frozen contract and return semantic reports rather than internal transaction data. | unit | `mix test test/rindle/owner_erasure_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` | ✅ | ✅ green |
| 54-02-01 | 02 | 1 | LIFE-03 | T-54-05 | Worker regressions prove the purge lane deletes genuinely orphaned assets and skips deletion when any surviving attachment still exists. | unit | `mix test test/rindle/workers/purge_storage_test.exs --seed 0` | ✅ | ✅ green |
| 54-02-02 | 02 | 1 | LIFE-03 | T-54-05, T-54-08 | `PurgeStorage` performs a live attachment re-check before any destructive delete and leaves bytes plus DB rows intact on the survivor path. | unit | `mix test test/rindle/workers/purge_storage_test.exs --seed 0` | ✅ | ✅ green |
| 54-02-03 | 02 | 1 | LIFE-02, LIFE-03 | T-54-08 | Existing `attach/4` and `detach/3` flows still enqueue purge work, and a shared asset survives when the hardened worker runs after one owner's detach/replace. | integration | `mix test test/rindle/attach_detach_test.exs test/rindle/workers/purge_storage_test.exs --seed 0` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/rindle/owner_erasure_test.exs` — new facade/report/idempotency coverage for preview + execute
- [x] `test/rindle/workers/purge_storage_test.exs` — extend existing worker tests to cover survivor-aware no-op behavior
- [x] `test/rindle/attach_detach_test.exs` — keep existing slot-scoped purge enqueue expectations aligned with the hardened worker semantics
- [x] Existing infrastructure covers DB, Oban, and storage-mock needs; no new test framework install is required

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Execute semantics are described honestly as "detach now, purge enqueued later" rather than immediate byte deletion | LIFE-02, LIFE-03 | Public wording accuracy is a support-truth judgment, not just a green test | Compare final `lib/rindle.ex` docs and any touched guide copy against `54-CONTEXT.md`; confirm no strings imply inline storage deletion or force-delete behavior |

---

## Validation Sign-Off

- [x] All tasks have automated verification
- [x] Sampling continuity maintained
- [x] Wave 0 coverage complete
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-05-26
