---
phase: 27
slug: html-helpers-liveview-integration
status: retroactive
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-05
---

# Phase 27 — Validation Strategy

> Retroactive validation artifact recorded after execution so milestone audit can discover the phase's actual verification posture.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + contract tests |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/html_test.exs test/rindle/live_view_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors` |
| **Full phase command** | `mix test test/rindle/html_test.exs test/rindle/live_view_test.exs test/rindle/workers/process_variant_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/error_test.exs test/rindle/delivery_test.exs test/rindle/delivery/local_plug_test.exs --warnings-as-errors` |
| **Estimated runtime** | ~30-90 seconds |

## Phase Requirements → Proof Map

| Req ID | Proof | Automated Command | Status |
|--------|-------|-------------------|--------|
| AV-05-01, AV-05-02, AV-05-03 | HTML AV helper surface | `mix test test/rindle/html_test.exs test/rindle/api_surface_boundary_test.exs --warnings-as-errors` | ✅ green |
| AV-05-04, AV-05-05 | LiveView subscription and public event contract | `mix test test/rindle/live_view_test.exs test/rindle/workers/process_variant_test.exs test/rindle/api_surface_boundary_test.exs --warnings-as-errors` | ✅ green |
| AV-05-06 | Asset-scoped cancellation contract | `mix test test/rindle/workers/process_variant_test.exs test/rindle/api_surface_boundary_test.exs --warnings-as-errors` | ✅ green |
| AV-05-07 | Locked AV error vocabulary | `mix test test/rindle/error_test.exs test/rindle/delivery_test.exs test/rindle/delivery/local_plug_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors` | ✅ green |

## Validation Sign-Off

- [x] All phase requirements have an automated proof lane.
- [x] Validation coverage is sufficient for milestone audit discovery.
- [x] `nyquist_compliant: true`
