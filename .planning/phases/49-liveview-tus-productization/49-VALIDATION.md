---
phase: 49
slug: liveview-tus-productization
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-25
---

# Phase 49 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run the narrowest task-scoped command from the verification map. Default quick loop: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 49-01-01 | 01 | 1 | PHX-02 | T-49-01-01 | `allow_tus_upload/4` keeps required `:path` and `:secret_key_base`, resolves optional `:actor`, and preserves the `consume_uploaded_entries/3` verification lane. | unit | `mix test test/rindle/live_view_test.exs` | ✅ | ⬜ pending |
| 49-01-02 | 01 | 1 | PHX-03 | T-49-01-02 | The canonical `RindleTus` contract reuses signed `upload_url`, performs resume discovery, and resumes from prior uploads without inventing alternate offset truth. | docs parity | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` | ✅ | ⬜ pending |
| 49-02-01 | 02 | 2 | PHX-04 | T-49-02-03 | Guide and examples distinguish `uploading`, `verifying`, and `ready`, and do not present `100%` as asset readiness. | docs parity | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/install_smoke/phoenix_tus_truth_parity_test.exs` — add explicit parity assertions for `uploadUrl: entry.meta.upload_url`, `findPreviousUploads()`, and `resumeFromPreviousUpload(...)`
- [ ] `test/install_smoke/phoenix_tus_truth_parity_test.exs` — add explicit parity assertions for the `uploading` / `verifying` / `ready` vocabulary
- [ ] `test/rindle/live_view_test.exs` — add targeted coverage that a 1-arity `:actor` function is accepted and resolved from the socket if planning chooses to freeze that behavior directly

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | N/A | All currently known Phase 49 behaviors can be frozen with ExUnit and docs parity checks. | N/A |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
