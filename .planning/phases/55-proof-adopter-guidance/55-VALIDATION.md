---
phase: 55
slug: proof-adopter-guidance
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-26
validated: 2026-05-26
---

# Phase 55 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/owner_erasure_test.exs test/rindle/api_surface_boundary_test.exs test/install_smoke/docs_parity_test.exs --seed 0` |
| **Full suite command** | `mix test test/rindle/owner_erasure_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/workers/purge_storage_test.exs test/rindle/attach_detach_test.exs test/adopter/canonical_app/lifecycle_test.exs test/install_smoke/docs_parity_test.exs --seed 0` |
| **Estimated runtime** | ~45-90s depending on DB, Oban, and canonical adopter storage setup |

---

## Sampling Rate

- **After every task commit:** Run the narrowest task-scoped Mix command from the verification map.
- **After every plan wave:** Run `mix test test/rindle/owner_erasure_test.exs test/rindle/api_surface_boundary_test.exs test/install_smoke/docs_parity_test.exs --seed 0`.
- **Before `$gsd-verify-work`:** Run the full suite command and confirm adopter-lane owner-erasure proof plus docs parity stay green together.
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 55-01-01 | 01 | 1 | PROOF-03 | T-55-01, T-55-02 | Hermetic owner-erasure proof covers orphan purge, retained shared assets, and rerun stability through the real worker boundary. | integration | `mix test test/rindle/owner_erasure_test.exs --seed 0` | ✅ | ✅ green |
| 55-01-02 | 01 | 1 | PROOF-04 | T-55-03 | Canonical adopter lane exercises `preview_owner_erasure/2` and `erase_owner/2` as the supported account-deletion flow rather than `detach/3` loops. | adopter | `mix test test/adopter/canonical_app/lifecycle_test.exs --seed 0` | ✅ | ✅ green |
| 55-01-03 | 01 | 1 | PROOF-03, PROOF-04 | T-55-01, T-55-03 | Public-boundary proof stays aligned with the owner-erasure facade wording and exported surface while proof coverage expands. | unit | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/owner_erasure_test.exs --seed 0` | ✅ | ✅ green |
| 55-02-01 | 02 | 2 | TRUTH-02 | T-55-04, T-55-05 | `guides/user_flows.md` becomes the canonical executable owner-erasure story and stays honest about retained shared assets and async purge. | docs parity | `mix test test/install_smoke/docs_parity_test.exs --seed 0` | ✅ | ✅ green |
| 55-02-02 | 02 | 2 | TRUTH-02 | T-55-05, T-55-06 | Getting-started, operations, and active planning artifacts point to the supported owner-erasure surface while keeping `cleanup_orphans` maintenance-only. | docs / grep | `mix test test/install_smoke/docs_parity_test.exs --seed 0 && rg -n "owner/account erasure|preview_owner_erasure|erase_owner|cleanup_orphans" .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md guides/getting_started.md guides/operations.md guides/user_flows.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers ExUnit, Oban testing, adopter Repo sandboxing, and docs parity; no new framework install is required.
- [x] `test/adopter/canonical_app/lifecycle_test.exs` remains runnable in the current MinIO-backed canonical adopter environment before extending owner-erasure proof there.
- [x] If adopter-lane storage setup proves flaky locally, capture the exact blocker in the summary instead of weakening the plan’s proof requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Owner-erasure guide wording stays calm, exact, and clearly scoped to Rindle-managed associations rather than the adopter account row | TRUTH-02 | Support-truth quality and voice are editorial judgments, not purely mechanical assertions | Compare final `guides/user_flows.md`, `guides/getting_started.md`, and `guides/operations.md` against `55-CONTEXT.md`; confirm one canonical flow, thin pointer surfaces elsewhere, and no wording that implies Rindle deletes the adopter account row |

*If none: "All phase behaviors have automated verification."*

---

## Validation Sign-Off

- [x] All tasks have automated verification
- [x] Sampling continuity maintained
- [x] Wave 0 coverage complete
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-05-26
