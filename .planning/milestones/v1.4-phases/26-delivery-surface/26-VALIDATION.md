---
phase: 26
slug: delivery-surface
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-05
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for Phase 26 execution. This is the Nyquist gate artifact for AV-04-01 through AV-04-08.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mox and telemetry test handlers |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/delivery_test.exs test/rindle/delivery/local_plug_test.exs --warnings-as-errors` |
| **Full phase command** | `mix test test/rindle/delivery_test.exs test/rindle/delivery/local_plug_test.exs test/rindle/contracts/telemetry_contract_test.exs test/rindle/html_test.exs --warnings-as-errors --include contract` |
| **Estimated runtime** | ~30-60 seconds once all phase files exist |

---

## Sampling Rate

- After every task commit: run the task’s `<automated>` command verbatim.
- After every plan wave: run the cumulative phase lane for all completed plans.
- Before `/gsd-verify-work`: run the full phase command and `mix compile --warnings-as-errors`.
- Max feedback latency: <= 30 seconds per targeted command; <= 60 seconds for the full phase lane.

---

## Phase Requirements → Plan/Test Map

| Req ID | Plan | Requirement Proof | Automated Command | Evidence Type | Status |
|--------|------|-------------------|-------------------|---------------|--------|
| AV-04-01 | 26-01 | `streaming_url/3` wraps delivery resolution and returns `%{url, kind, mime}` without changing `url/3` | `mix test test/rindle/delivery_test.exs --warnings-as-errors` | unit/contract | ⬜ pending |
| AV-04-02 | 26-01 | Reserved `Rindle.Streaming.Provider` behaviour exists without runtime dispatch | `mix test test/rindle/delivery_test.exs --warnings-as-errors` | unit/api-surface | ⬜ pending |
| AV-04-03 | 26-02 | `LocalPlug` verifies signed token, serves single-range requests, and falls back to full-body on invalid/multi-range | `mix test test/rindle/delivery/local_plug_test.exs --warnings-as-errors` | integration/request | ⬜ pending |
| AV-04-04 | 26-02 | `LocalPlug.init/1` rejects non-local adapters at mount time | `mix test test/rindle/delivery/local_plug_test.exs --warnings-as-errors` | unit/request | ⬜ pending |
| AV-04-05 | 26-02, 26-03 | Dev-parity-only posture is present in moduledoc/docs and matches runtime behavior | `mix test test/rindle/delivery/local_plug_test.exs test/rindle/html_test.exs --warnings-as-errors` | doc parity/regression | ⬜ pending |
| AV-04-06 | 26-02, 26-03 | Streaming and range-request telemetry events are emitted, documented, and frozen in the contract lane | `mix test test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors --include contract` | contract | ⬜ pending |
| AV-04-07 | 26-03 | TTL guidance is documented while the profile DSL remains unchanged | `mix test test/rindle/delivery_test.exs test/rindle/html_test.exs --warnings-as-errors` | unit/doc parity | ⬜ pending |
| AV-04-08 | 26-01, 26-02, 26-03 | Redirect and local delivery share sanitized RFC 5987 `filename*=` behavior | `mix test test/rindle/delivery_test.exs test/rindle/delivery/local_plug_test.exs --warnings-as-errors` | unit/request | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Automated Command | File Exists | Status |
|---------|------|------|--------------|-------------------|-------------|--------|
| 26-01-T1 | 26-01 | 1 | AV-04-01, AV-04-02 | `mix test test/rindle/delivery_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 26-01-T2 | 26-01 | 1 | AV-04-08 | `mix test test/rindle/delivery_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 26-02-T1 | 26-02 | 2 | AV-04-03, AV-04-04 | `mix test test/rindle/delivery/local_plug_test.exs --warnings-as-errors` | no — created by execution | ⬜ pending |
| 26-02-T2 | 26-02 | 2 | AV-04-03, AV-04-05, AV-04-06, AV-04-08 | `mix test test/rindle/delivery/local_plug_test.exs --warnings-as-errors` | no — created by execution | ⬜ pending |
| 26-03-T1 | 26-03 | 3 | AV-04-06 | `mix test test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors --include contract` | yes | ⬜ pending |
| 26-03-T2 | 26-03 | 3 | AV-04-05, AV-04-07, AV-04-08 | `mix test test/rindle/delivery_test.exs test/rindle/html_test.exs --warnings-as-errors` | yes | ⬜ pending |

---

## Wave 0 Gaps

- [ ] `test/rindle/delivery/local_plug_test.exs` — request-level coverage for AV-04-03, AV-04-04, and local-delivery AV-04-08 assertions.
- [ ] `[:rindle, :delivery, :streaming, :resolved]` and `[:rindle, :delivery, :range_request]` contract entries in `test/rindle/contracts/telemetry_contract_test.exs`.
- [ ] `streaming_url/3` and RFC 5987 disposition assertions in `test/rindle/delivery_test.exs`.

---

## Required Automated Commands

- `mix test test/rindle/delivery_test.exs --warnings-as-errors`
- `mix test test/rindle/delivery/local_plug_test.exs --warnings-as-errors`
- `mix test test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors --include contract`
- `mix test test/rindle/delivery_test.exs test/rindle/html_test.exs --warnings-as-errors`
- `mix compile --warnings-as-errors`

---

## Phase Gate Evidence

- `26-01` proves the public playback seam is additive, preserves `url/3`, and reserves the provider namespace without runtime abstraction.
- `26-02` proves the local dev playback path is safe: signed token, root containment, single-range behavior, and shared content-disposition policy.
- `26-03` proves operator-facing closure: telemetry contracts are frozen and documented, TTL guidance stays docs-only, and image helper behavior does not churn.
- Final phase gate: the full phase command plus `mix compile --warnings-as-errors` must be green before execution can be marked complete.

---

## Validation Sign-Off

- [x] All plans 26-01 through 26-03 are mapped to automated verification.
- [x] AV-04-01 through AV-04-08 each have at least one explicit automated command.
- [x] Telemetry, local request handling, doc parity, and regression coverage all have a phase-gate lane.
- [x] `nyquist_compliant: true` is set because every requirement has an execution-time verification target.

**Approval:** approved (planner revision sign-off — Phase 26 execution may proceed against this validation contract)
