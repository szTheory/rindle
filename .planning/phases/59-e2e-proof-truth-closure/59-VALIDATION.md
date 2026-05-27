---
phase: 59
slug: e2e-proof-truth-closure
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 59 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (mix test) + install-smoke shell lane |
| **Config file** | `mix.exs` / test configuration already present |
| **Quick run command** | `mix test test/rindle/upload/tus_plug_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs` |
| **Full suite command** | `bash scripts/install_smoke.sh tus` |
| **Estimated runtime** | ~900 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/upload/tus_plug_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs`
- **After every plan wave:** Run `bash scripts/install_smoke.sh tus`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 900 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 59-01-01 | 01 | 1 | PROOF-01 | T-59-01-H1 | Generated-app harness runs explicit extension modes and emits machine-readable proof objects | integration | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` | ✅ | ⬜ pending |
| 59-01-02 | 01 | 1 | PROOF-01 | T-59-01-H2 | Helper report projection preserves failure breadcrumbs while exposing `extensions.*` keys | integration | `bash scripts/install_smoke.sh tus` | ✅ | ⬜ pending |
| 59-01-03 | 01 | 1 | PROOF-01 | T-59-01-H1,T-59-01-H2 | Smoke suite blocks merges when extension evidence is missing or inconsistent | integration | `bash -lc 'mix test test/install_smoke/generated_app_smoke_test.exs --include minio && rg -n "\"extensions\"|\"concatenation\"|\"creation_defer_length\"|\"checksum\"" tmp/install_smoke_tus_last_run.json'` | ✅ | ⬜ pending |
| 59-02-01 | 02 | 2 | TRUTH-01 | T-59-02-H1 | Guide states full extension support with explicit adopter knobs and no out-of-scope claims | docs | `bash -lc 'rg -n "creation|expiration|termination|checksum|creation-defer-length|concatenation" guides/resumable_uploads.md && rg -n "parallelUploads:\\s*2|uploadLengthDeferred:\\s*true" guides/resumable_uploads.md'` | ✅ | ⬜ pending |
| 59-02-02 | 02 | 2 | TRUTH-01 | T-59-02-H1 | Parity tests freeze literal extension tokens used in guide language | integration | `bash -lc 'mix test test/install_smoke/phoenix_tus_truth_parity_test.exs && mix test test/install_smoke/generated_app_smoke_test.exs --include minio'` | ✅ | ⬜ pending |
| 59-02-03 | 02 | 2 | TUS-01,TUS-02,TUS-03,TUS-04,PROOF-01,TRUTH-01 | T-59-02-H2 | Milestone closeout requires fresh command evidence and zero unresolved HIGH threats | e2e/docs | `bash -lc 'mix test test/rindle/upload/tus_plug_test.exs && mix test test/install_smoke/phoenix_tus_truth_parity_test.exs && mix test test/install_smoke/generated_app_smoke_test.exs --include minio && bash scripts/install_smoke.sh tus && rg -n "requirements:\\s*6/6|PROOF-01|TRUTH-01|TUS-01|TUS-02|TUS-03|TUS-04|unresolved_high_threats:\\s*0" .planning/milestones/v1.11-MILESTONE-AUDIT.md && rg -n "\"extensions\"|\"completion_surface\"|\"phoenix_state_sequence\"|\"tus_failure_phase\"" tmp/install_smoke_tus_last_run.json'` | ✅ | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

- All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 900s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
