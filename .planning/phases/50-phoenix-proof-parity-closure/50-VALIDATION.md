---
phase: 50
slug: phoenix-proof-parity-closure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-25
---

# Phase 50 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` |
| **Full suite command** | `bash scripts/install_smoke.sh tus` |
| **Estimated runtime** | ~20s quick loop; install-smoke lane is slower |

---

## Sampling Rate

- **After every task commit:** Run the narrowest task-scoped command from the
  verification map.
- **After every plan wave:** Run `bash scripts/install_smoke.sh tus`
- **Before `$gsd-verify-work`:** Fresh `bash scripts/install_smoke.sh tus`
  evidence plus updated machine-readable tus report fields must be green.
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 50-01-01 | 01 | 1 | PROOF-01 | T-50-01-01 | Generated app exercises `allow_tus_upload/4` and emits canonical `RindleTus` helper metadata before browser transfer begins. | integration | `RINDLE_INSTALL_SMOKE_PROFILE=tus mix test test/install_smoke/generated_app_smoke_test.exs --include minio` | ✅ | ⬜ pending |
| 50-01-02 | 01 | 1 | PROOF-01 | T-50-01-02 | Generated app records honest `uploading` / `verifying` / `ready` or `error` state transitions and still converges through `consume_uploaded_entries/3` / `verify_completion/2`. | integration | `RINDLE_INSTALL_SMOKE_PROFILE=tus mix test test/install_smoke/generated_app_smoke_test.exs --include minio` | ✅ | ⬜ pending |
| 50-02-01 | 02 | 2 | PROOF-02 | T-50-02-01 | Fast parity test freezes guide/helper/proof-report alignment for canonical Phoenix strings and report keys. | docs parity | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` | ✅ | ⬜ pending |
| 50-02-02 | 02 | 2 | PROOF-02 | T-50-02-02 | Local helper tests keep the `RindleTus` metadata and completion-lane contract aligned with the generated-app proof. | unit | `mix test test/rindle/live_view_test.exs` | ✅ | ⬜ pending |
| 50-02-03 | 02 | 2 | PROOF-01, PROOF-02 | T-50-02-03 | Final package-consumer proof remains green under the documented Phoenix path, with persisted JSON breadcrumbs for auditability. | integration | `bash scripts/install_smoke.sh tus` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/install_smoke/generated_app_smoke_test.exs` — add explicit Phoenix-path assertions instead of only raw tus transport assertions
- [ ] `test/install_smoke/support/generated_app_helper.ex` — persist Phoenix-facing machine-readable proof fields and state progression
- [ ] `test/install_smoke/phoenix_tus_truth_parity_test.exs` — add explicit parity assertions for proof-report keys and honest state semantics
- [ ] `test/rindle/live_view_test.exs` — confirm any helper metadata strings or completion-lane markers mirrored by the generated-app proof remain locally frozen

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The chosen generated-app proof shape stays narrow and does not widen the public Phoenix surface | PROOF-01 | Scope discipline is an architectural judgment, not just a command exit code | Compare the final changed files against `50-CONTEXT.md`; confirm the proof extends existing seams without adding new public Phoenix abstractions or whole-template snapshots |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s for the quick loop
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

