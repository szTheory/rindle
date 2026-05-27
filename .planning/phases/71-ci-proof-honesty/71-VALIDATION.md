---
phase: 71
slug: ci-proof-honesty
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 71 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/install_smoke/docs_parity_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds (docs parity only) |

---

## Sampling Rate

- **After every task commit:** Run task-specific grep commands from acceptance_criteria
- **After every plan wave:** Run `mix test test/install_smoke/docs_parity_test.exs`
- **Before `/gsd-verify-work`:** Docs parity test green; grep confirms COE removals
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 71-01-01 | 01 | 1 | CI-01 | — | N/A | grep | `rg '## CI lane severity' RUNNING.md` | ✅ | ✅ green |
| 71-01-02 | 01 | 1 | CI-01 | — | N/A | unit | `mix test test/install_smoke/docs_parity_test.exs` | ✅ | ✅ green |
| 71-02-01 | 02 | 2 | CI-02 | — | N/A | grep | `! rg -A2 'package-consumer:' .github/workflows/ci.yml \| rg 'continue-on-error'` | ✅ | ✅ green |
| 71-02-02 | 02 | 2 | CI-02 | — | N/A | grep | `test "$(rg 'Phase 71 \\(CI proof honesty\\)' .github/workflows/ci.yml \| wc -l \| tr -d ' ')" -ge 6` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No Wave 0 stubs needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Branch protection includes package-consumer/adopter | D-12 | GitHub settings out of repo | After merge, verify required checks in repo Settings → Branches |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-27

## Validation Audit

| Date | Action | Result |
|------|--------|--------|
| 2026-05-27 | Phase 77 metadata reconciliation | nyquist_compliant: true |
