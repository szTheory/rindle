---
phase: 25
slug: rindle-processor-av
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-05
---

# Phase 25 — Validation Strategy

> Per-phase validation contract for Phase 25 execution. This file is the Nyquist gate artifact for AV-03-01 through AV-03-18.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Oban.Testing |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/processor/av_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors` |
| **Full phase command** | `mix test test/rindle/processor/av_test.exs test/rindle/processor/waveform_test.exs test/rindle/av/subprocess_test.exs test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs test/rindle/processor/av_runtime_guard_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/contracts/telemetry_contract_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/profile/validator_test.exs test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs test/rindle/backward_compat/v13_digest_snapshot_test.exs --warnings-as-errors --include adopter` |
| **Estimated runtime** | ~120-180 seconds for the full phase lane once all files exist |

---

## Sampling Rate

- After every task commit: run the task’s `<automated>` command verbatim.
- After every plan wave: run the cumulative phase lane for all plans completed so far.
- Before `/gsd-verify-work`: run the full phase command and `mix compile --warnings-as-errors`.
- Max feedback latency: <= 30 seconds per task-targeted command; <= 180 seconds for the full phase lane.

---

## Phase Requirements → Plan/Test Map

| Req ID | Plan | Requirement Proof | Automated Command | Evidence Type | Status |
|--------|------|-------------------|-------------------|---------------|--------|
| AV-03-01 | 25-01 | `Rindle.Processor.AV` public seam + `capabilities/0` + canonical normalization | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | unit/contract | ⬜ pending |
| AV-03-02 | 25-03 | Preset-led mp4/H.264/AAC transcode with real output | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | unit/integration | ⬜ pending |
| AV-03-03 | 25-03 | Explicit poster extraction with scene/I-frame fallback proof | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | unit/integration | ⬜ pending |
| AV-03-04 | 25-03 | Explicit opt-in strip generation | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | unit/integration | ⬜ pending |
| AV-03-05 | 25-04 | Named m4a/mp3 preset outputs | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | unit/integration | ⬜ pending |
| AV-03-06 | 25-04 | Loudnorm single-pass + `two_pass: true` branch | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | unit/integration | ⬜ pending |
| AV-03-07 | 25-04 | Narrow waveform contract `%{length, sample_rate, peaks}` | `mix test test/rindle/processor/waveform_test.exs test/rindle/profile/validator_test.exs --warnings-as-errors` | unit/contract | ⬜ pending |
| AV-03-08 | 25-02 | Idempotent `(asset_id, variant_name)` worker path | `mix test test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors` | worker/integration | ⬜ pending |
| AV-03-09 | 25-05 | Post-condition probe rejects truncated/mismatched outputs | `mix test test/rindle/workers/process_variant_test.exs test/rindle/processor/av_runtime_guard_test.exs --warnings-as-errors` | worker/guard | ⬜ pending |
| AV-03-10 | 25-02 | Atomic promote race guard before ready flip | `mix test test/rindle/workers/process_variant_test.exs --warnings-as-errors` | worker/integration | ⬜ pending |
| AV-03-11 | 25-02 | Dedicated `:rindle_media` queue + uniqueness + timeout | `mix test test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors` | worker/options | ⬜ pending |
| AV-03-12 | 25-02 | All tempfiles under `Rindle.tmp/<uuid>/` | `mix test test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors` | worker/filesystem | ⬜ pending |
| AV-03-13 | 25-05 | Hourly orphan sweeper plus orphan-count telemetry | `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs --warnings-as-errors` | ops/telemetry | ⬜ pending |
| AV-03-14 | 25-05 | Disk-space precheck at enqueue and start | `mix test test/rindle/workers/process_variant_test.exs test/rindle/processor/av_runtime_guard_test.exs --warnings-as-errors` | worker/guard | ⬜ pending |
| AV-03-15 | 25-05 | Boot-time warning + enqueue/start refusal on ephemeral runtimes | `mix test test/rindle/processor/av_runtime_guard_test.exs --warnings-as-errors` | boot/runtime guard | ⬜ pending |
| AV-03-16 | 25-06 | Telemetry triplet contract frozen | `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/api_surface_boundary_test.exs --warnings-as-errors` | contract | ⬜ pending |
| AV-03-17 | 25-06 | Variant-topic progress plus asset-topic roll-up, both rate-limited | `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors` | contract/worker | ⬜ pending |
| AV-03-18 | 25-06 | `Rindle.Profile.Presets.Web` and canonical adopter round-trip | `mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors --include adopter` | preset/adopter | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Automated Command | File Exists | Status |
|---------|------|------|--------------|-------------------|-------------|--------|
| 25-01-T1 | 25-01 | 1 | AV-03-01 | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-01-T2 | 25-01 | 1 | AV-03-01 | `mix test test/rindle/profile/validator_test.exs test/rindle/backward_compat/v13_digest_snapshot_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-02-T1 | 25-02 | 2 | AV-03-08, AV-03-11, AV-03-12 | `mix test test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-02-T2 | 25-02 | 2 | AV-03-10 | `mix test test/rindle/workers/process_variant_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-03-T1 | 25-03 | 2 | AV-03-02 | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-03-T2 | 25-03 | 2 | AV-03-03, AV-03-04 | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-04-T1 | 25-04 | 3 | AV-03-05, AV-03-06 | `mix test test/rindle/processor/av_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-04-T2 | 25-04 | 3 | AV-03-07 | `mix test test/rindle/processor/waveform_test.exs test/rindle/profile/validator_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-05-T1 | 25-05 | 4 | AV-03-09, AV-03-14, AV-03-15 | `mix test test/rindle/av/subprocess_test.exs test/rindle/workers/process_variant_test.exs test/rindle/processor/av_runtime_guard_test.exs --warnings-as-errors` | no — created by execution | ⬜ pending |
| 25-05-T2 | 25-05 | 4 | AV-03-13 | `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-06-T1 | 25-06 | 5 | AV-03-16, AV-03-17 | `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 25-06-T2 | 25-06 | 5 | AV-03-18 | `mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors --include adopter` | yes | ⬜ pending |

---

## Required Automated Commands

- `mix test test/rindle/processor/av_test.exs --warnings-as-errors`
- `mix test test/rindle/profile/validator_test.exs test/rindle/backward_compat/v13_digest_snapshot_test.exs --warnings-as-errors`
- `mix test test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors`
- `mix test test/rindle/processor/waveform_test.exs test/rindle/profile/validator_test.exs --warnings-as-errors`
- `mix test test/rindle/av/subprocess_test.exs test/rindle/workers/process_variant_test.exs test/rindle/processor/av_runtime_guard_test.exs --warnings-as-errors`
- `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs --warnings-as-errors`
- `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors`
- `mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors --include adopter`
- `mix compile --warnings-as-errors`

---

## Phase Gate Evidence

- `25-01` proves the public AV seam and digest normalization exist before worker or preset plans depend on them.
- `25-02` proves the durable worker invariants: dedicated queue, uniqueness, temp-root discipline, and atomic promote.
- `25-03` and `25-04` prove the concrete media outputs against real fixtures, not only command assembly.
- `25-05` proves the safety rails: subprocess cap seam, disk/runtime admission, boot-time ephemeral warning, output probe, and orphan-count telemetry.
- `25-06` proves the public operator/adopter surface: telemetry names, rate-limited progress on both variant and asset topics, stock preset module, and canonical adopter lifecycle.
- Final phase gate: the full phase command plus `mix compile --warnings-as-errors` must be green before execution can be marked complete.

---

## Validation Sign-Off

- [x] All plans 25-01 through 25-06 are mapped to automated verification.
- [x] AV-03-01 through AV-03-18 each have at least one explicit automated command.
- [x] Phase gate evidence includes worker, ops, contract, and adopter-level proof.
- [x] Warning-sensitive seams called out by the checker are now explicit in the validation contract: `test/rindle/av/subprocess_test.exs`, boot-time runtime warning, orphan-count telemetry, and asset-topic progress roll-up.
- [x] `nyquist_compliant: true` is set because every requirement has an execution-time verification target.

**Approval:** approved (planner revision sign-off — Phase 25 execution may proceed against this validation contract)
