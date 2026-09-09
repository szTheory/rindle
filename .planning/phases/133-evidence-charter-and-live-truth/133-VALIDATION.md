---
phase: "133"
slug: "evidence-charter-and-live-truth"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-09"
---

# Phase 133 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus repository-native Bash truth-table scripts |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `bash scripts/ci/test_nightly_summary_gate.sh && bash scripts/ci/test_nightly_dialyzer.sh && bash scripts/ci/test_nightly_incident.sh` |
| **Full suite command** | `mix ci && bash scripts/maintainer/refactor_contract.sh && ./scripts/maintainer/automation_first_contract.sh` |
| **Estimated runtime** | ~180 seconds excluding live supported-cell Nightly evidence |

---

## Sampling Rate

- **After every task commit:** Run the focused Bash or ExUnit contract for the evidence owner changed by the task.
- **After every plan wave:** Run all Phase 133 focused contracts and the related existing install-smoke policy tests.
- **Before `$gsd-verify-work`:** Full suite, repository hygiene, and supported-cell fresh/restored Dialyzer evidence must be green.
- **Max feedback latency:** 180 seconds for local focused/full-suite feedback; live Nightly evidence is collected as an explicit phase gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 133-01-01 | 01 | 1 | EVID-01 | T-133-01 | Foreign or incomplete census evidence cannot pass | contract | `mix test test/install_smoke/evidence_census_test.exs` | ❌ W0 | ⬜ pending |
| 133-02-01 | 02 | 1 | EVID-02 | Stale PLTs cannot masquerade as valid restored evidence | shell/unit | `bash scripts/ci/test_nightly_dialyzer.sh` | ❌ W0 | ⬜ pending |
| 133-03-01 | 03 | 2 | EVID-03 | Unknown, cancelled, failed, or impermissibly skipped states fail closed | truth table | `bash scripts/ci/test_nightly_summary_gate.sh` | ❌ W0 | ⬜ pending |
| 133-04-01 | 04 | 2 | EVID-04 | Incident mutation is exact-run-bound and least-privileged | adapter/contract | `bash scripts/ci/test_nightly_incident.sh` | ❌ W0 | ⬜ pending |
| 133-05-01 | 05 | 3 | TRUTH-08 | Unmarked authoritative-state contradictions cannot pass parity checks | contract | `mix test test/install_smoke/live_truth_parity_test.exs test/install_smoke/package_metadata_test.exs test/install_smoke/generated_app_smoke_test.exs` | ❌ W0 / partial existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/install_smoke/evidence_census_test.exs` — exact-head census schema, deduplication, disposition, and mutation fixtures.
- [ ] `scripts/ci/test_nightly_dialyzer.sh` — fresh, restored, stale, corrupt, build-failure, and genuine-warning PLT fixtures.
- [ ] `scripts/ci/test_nightly_summary_gate.sh` — complete Nightly result/applicability truth table.
- [ ] `scripts/ci/test_nightly_incident.sh` — scheduled-only fake-`gh` open/update/close mutation tests.
- [ ] `test/install_smoke/nightly_policy_test.exs` — workflow topology, permissions, and evaluator wiring assertions.
- [ ] `test/install_smoke/live_truth_parity_test.exs` — version, lane severity, package-proof, and marked-history parity fixtures.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Live GitHub evidence is collected by exact-run-bound evidence collectors and does not satisfy a requirement by human observation alone.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s for local checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
