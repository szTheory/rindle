---
phase: 01
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --failed` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30-90 seconds (phase-dependent) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --failed`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | SCHEMA-01..08 | T-01-01 | Tables/state columns/indexes are queryable and constrained | integration | `mix ecto.migrate && mix test` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | ASM/VSM/USM families | T-01-02 | Invalid transitions are rejected with no silent mutation | unit | `mix test test/rindle/domain` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | BHV/STOR families | T-01-03 | Adapter contracts return tagged tuples and capability truth | unit/integration | `mix test test/rindle/storage` | ❌ W0 | ⬜ pending |
| 01-04-01 | 04 | 2 | PROF/SEC/STALE | T-01-04 | MIME/extension/size/pixel checks gate quarantine and digest churn | unit | `mix test test/rindle/profile test/rindle/security` | ❌ W0 | ⬜ pending |
| 01-05-01 | 05 | 3 | CONF/ERR | T-01-05 | Config defaults + structured logging semantics stay stable | unit | `mix test test/rindle` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/domain/*_test.exs` — transition and schema contract suites
- [ ] `test/rindle/storage/*_test.exs` — storage behaviour conformance suite
- [ ] `test/rindle/profile/*_test.exs` — DSL compile-time and digest coverage
- [ ] `test/rindle/security/*_test.exs` — MIME/extension/size/pixel/key invariants
- [ ] `test/support/factories.ex` and fixture helpers — repeatable setup

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| S3 compatibility proof against MinIO endpoint | STOR-07 | External service wiring and credentials vary by environment | Start MinIO, configure env vars, run adapter integration test module and confirm pass/fail evidence in logs |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
