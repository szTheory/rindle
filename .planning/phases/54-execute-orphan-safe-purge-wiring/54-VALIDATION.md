---
phase: 54
slug: execute-orphan-safe-purge-wiring
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-26
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
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 54-01-01 | 01 | 1 | LIFE-02 | T-54-01-01 | Preview and execute share one semantic owner-erasure plan/report shape rooted in live attachment rows. | unit | `mix test test/rindle/owner_erasure_test.exs --only preview_contract` | ❌ W0 | ⬜ pending |
| 54-01-02 | 01 | 1 | LIFE-02, LIFE-04 | T-54-01-02 | `Rindle.erase_owner/2` detaches all owner rows transactionally, returns `{:ok, report}`, and reruns return a stable no-op report. | integration | `mix test test/rindle/owner_erasure_test.exs --only execute_contract` | ❌ W0 | ⬜ pending |
| 54-02-01 | 02 | 1 | LIFE-03 | T-54-02-01 | Shared assets with surviving attachments are retained and reported instead of purged. | integration | `mix test test/rindle/owner_erasure_test.exs --only retained_shared_assets` | ❌ W0 | ⬜ pending |
| 54-02-02 | 02 | 1 | LIFE-03, LIFE-04 | T-54-02-02 | Purge enqueue conflicts are treated as semantic skips/already-queued results, not hard failures. | unit | `mix test test/rindle/owner_erasure_test.exs --only purge_conflict` | ❌ W0 | ⬜ pending |
| 54-03-01 | 03 | 2 | LIFE-03 | T-54-03-01 | `PurgeStorage` re-checks live attachments before deleting variants, source objects, or asset rows. | unit | `mix test test/rindle/workers/purge_storage_test.exs` | ✅ | ⬜ pending |
| 54-03-02 | 03 | 2 | LIFE-02, LIFE-03 | T-54-03-02 | Existing `attach/4` and `detach/3` flows remain safe under the hardened worker boundary. | integration | `mix test test/rindle/attach_detach_test.exs test/rindle/upload/lifecycle_integration_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/owner_erasure_test.exs` — new facade/report/idempotency coverage for preview + execute
- [ ] `test/rindle/workers/purge_storage_test.exs` — extend existing worker tests to cover survivor-aware no-op behavior
- [ ] `test/rindle/attach_detach_test.exs` — keep existing slot-scoped purge enqueue expectations aligned with the hardened worker semantics
- [ ] Existing infrastructure covers DB, Oban, and storage-mock needs; no new test framework install is required

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Execute semantics are described honestly as "detach now, purge enqueued later" rather than immediate byte deletion | LIFE-02, LIFE-03 | Public wording accuracy is a support-truth judgment, not just a green test | Compare final `lib/rindle.ex` docs and any touched guide copy against `54-CONTEXT.md`; confirm no strings imply inline storage deletion or force-delete behavior |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
