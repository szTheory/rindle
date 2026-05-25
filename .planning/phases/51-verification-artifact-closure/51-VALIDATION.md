---
phase: 51
slug: verification-artifact-closure
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
---

# Phase 51 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix plus repo-local shell/grep checks |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` |
| **Full suite command** | `bash scripts/install_smoke.sh tus` only when the Phase 50 proof-surface diff gate triggers or the quick freshness command fails/inconclusive |
| **Estimated runtime** | ~20s quick loop; heavy proof lane is materially slower |

---

## Sampling Rate

- **After every task commit:** Run the narrowest task-scoped command from the map below.
- **After every plan wave:** Reuse the quick run command unless the Phase 50 proof-surface diff requires the heavy lane or the quick freshness command failed/inconclusive.
- **Before `$gsd-verify-work`:** All drafted verification reports must pass their grep/file-existence checks, and the quick loop must be green. If the Phase 50 diff gate triggers, or if the quick freshness command failed/inconclusive, `bash scripts/install_smoke.sh tus` must also be green.
- **Max feedback latency:** 90 seconds for the quick loop

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 51-01-01 | 01 | 1 | PHX-01, TRUTH-01 | T-51-01-01 | Phase 48 retrospective verification is certified against a fresh current-tree parity/helper run instead of stale prose. | integration | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` | ✅ | ⬜ pending |
| 51-01-02 | 01 | 1 | PHX-01, TRUTH-01 | T-51-01-02 | `48-VERIFICATION.md` exists with standard frontmatter, explicit evidence, and a roadmap success-criteria table. | doc traceability | `test -f .planning/phases/48-phoenix-dx-contract-truth-audit/48-VERIFICATION.md && rg -n 'requirements_verified: \\[PHX-01, TRUTH-01\\]|## Goal Achievement — ROADMAP Success Criteria|48-01-SUMMARY.md|48-02-SUMMARY.md|48-UAT.md|48-VALIDATION.md' .planning/phases/48-phoenix-dx-contract-truth-audit/48-VERIFICATION.md` | ✅ | ⬜ pending |
| 51-02-01 | 02 | 2 | PHX-02, PHX-03, PHX-04 | T-51-02-01 | `49-VERIFICATION.md` restores requirement traceability using shipped summaries, parity evidence, and validation rows. | doc traceability | `test -f .planning/phases/49-liveview-tus-productization/49-VERIFICATION.md && rg -n 'requirements_verified: \\[PHX-02, PHX-03, PHX-04\\]|## Goal Achievement — ROADMAP Success Criteria|49-01-SUMMARY.md|49-02-SUMMARY.md|49-VALIDATION.md|phoenix_tus_truth_parity_test.exs|live_view_test.exs' .planning/phases/49-liveview-tus-productization/49-VERIFICATION.md` | ✅ | ⬜ pending |
| 51-02-02 | 02 | 2 | PROOF-01, PROOF-02 | T-51-02-02 | `50-VERIFICATION.md` cites safe machine-readable proof fields and records whether the persisted-JSON branch or fresh heavy-rerun branch was used. | doc traceability | `test -f .planning/phases/50-phoenix-proof-parity-closure/50-VERIFICATION.md && rg -n 'requirements_verified: \\[PROOF-01, PROOF-02\\]|## Goal Achievement — ROADMAP Success Criteria|## Reconciliation Note|phoenix_helper_uploader|completion_surface|phoenix_state_sequence|50-01-SUMMARY.md|50-02-SUMMARY.md|50-VALIDATION.md|persisted JSON branch|fresh bash scripts/install_smoke.sh tus rerun branch' .planning/phases/50-phoenix-proof-parity-closure/50-VERIFICATION.md && ! rg -n 'phoenix_helper_upload_url|upload_url:' .planning/phases/50-phoenix-proof-parity-closure/50-VERIFICATION.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase 51 does not drift into Phase 52 traceability reconciliation work | All | Scope discipline is an architectural judgment, not just a command exit code | Compare the final changed files against `51-CONTEXT.md` and `ROADMAP.md`; confirm only `48/49/50-VERIFICATION.md` are added and no `REQUIREMENTS.md` or `49-VALIDATION.md` reconciliation edits are introduced. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90s for the quick loop
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-25
