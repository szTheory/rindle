---
phase: 23
slug: av-foundations
status: retroactive
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-05
---

# Phase 23 — Validation Strategy

> Retroactive validation artifact recorded after execution so milestone audit can discover the phase's actual verification posture.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mix task checks |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/av test/rindle/security/argv_test.exs test/rindle/doctor_test.exs --warnings-as-errors` |
| **Full phase command** | `mix test test/rindle/av test/rindle/security/argv_test.exs test/rindle/doctor_test.exs test/rindle/processor/ffmpeg_test.exs test/rindle/ops/orphan_reaper_test.exs --warnings-as-errors` |
| **Estimated runtime** | ~30-90 seconds |

## Phase Requirements → Proof Map

| Req ID | Proof | Automated Command | Status |
|--------|-------|-------------------|--------|
| AV-01-01, AV-01-09 | Capability vocabulary and report lane | `mix test test/rindle/av/capability_test.exs --warnings-as-errors` | ✅ green |
| AV-01-03, AV-01-05, AV-01-08 | Probe and doctor gate | `mix test test/rindle/av/probe_test.exs test/rindle/doctor_test.exs --warnings-as-errors` | ✅ green |
| AV-01-06, AV-01-07, AV-01-10 | Subprocess seam, whitelist, four-cap enforcement | `mix test test/rindle/av/subprocess_test.exs test/rindle/processor/ffmpeg_test.exs --warnings-as-errors` | ✅ green |
| AV-01-02, AV-01-04 | Processor/profile seam compatibility | `mix test test/rindle/processor/ffmpeg_test.exs test/rindle/doctor_test.exs --warnings-as-errors` | ✅ green |

## Validation Sign-Off

- [x] All phase requirements have an automated proof lane.
- [x] Validation coverage is sufficient for milestone audit discovery.
- [x] `nyquist_compliant: true`
