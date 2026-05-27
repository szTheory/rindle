---
phase: 71
slug: ci-proof-honesty
status: draft
nyquist_compliant: false
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
| 71-01-01 | 01 | 1 | CI-01 | — | N/A | grep | `rg '## CI lane severity' RUNNING.md` | ✅ | ⬜ pending |
| 71-01-02 | 01 | 1 | CI-01 | — | N/A | unit | `mix test test/install_smoke/docs_parity_test.exs` | ✅ | ⬜ pending |
| 71-02-01 | 02 | 2 | CI-02 | — | N/A | grep | `! rg -A2 'package-consumer:' .github/workflows/ci.yml \| rg 'continue-on-error'` | ✅ | ⬜ pending |
| 71-02-02 | 02 | 2 | CI-02 | — | N/A | grep | `rg 'Phase 71 \\(CI proof honesty\\)' .github/workflows/ci.yml \| wc -l` ≥ 8 | ✅ | ⬜ pending |

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
