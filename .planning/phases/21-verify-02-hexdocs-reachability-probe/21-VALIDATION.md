---
phase: 21
slug: verify-02-hexdocs-reachability-probe
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-01
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `21-RESEARCH.md` and `21-01-PLAN.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit install-smoke parity tests + workflow snippet assertions |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs` |
| **Full suite command** | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs` |
| **Estimated runtime** | ~5-10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs`
- **After every plan wave:** Run the same combined install-smoke suite
- **Before `/gsd-verify-work`:** The combined install-smoke suite must be green, with the workflow/runbook contract and retry posture assertions passing
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | VERIFY-02 | T-21-01 / T-21-04 | `public_verify` probes `https://hexdocs.pm/rindle/$VERSION` with redirect-following GET semantics, bounded 5-minute / 15-second retries, and a terminal failure message on timeout | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs` | ✅ | ⬜ pending |
| 21-01-02 | 01 | 1 | VERIFY-02 | T-21-03 | `guides/release_publish.md` mirrors the workflow step name and probe command contract so release documentation cannot drift from shipped behavior | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs` | ✅ | ⬜ pending |
| 21-01-03 | 01 | 1 | VERIFY-02 | T-21-02 / T-21-03 | Combined install-smoke suite fails if the probe is removed, renamed, rewired, or its retry cadence drifts from the planned release gate | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or existing test coverage
- [x] Sampling continuity: no task lacks an automated verification path
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
