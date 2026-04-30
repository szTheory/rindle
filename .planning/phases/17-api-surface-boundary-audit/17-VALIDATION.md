---
phase: 17
slug: api-surface-boundary-audit
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-30
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs -x` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/api_surface_boundary_test.exs test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs -x`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 17-01 | 1 | API-01, API-02, API-04 | T-17-01, T-17-03 | Wave 0 boundary harness encodes the locked allowlist/denylist and compatibility-shim expectations before implementation starts | unit | `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs -x` | ✅ planned | ⬜ pending |
| 17-01-02 | 17-01 | 1 | API-03 | T-17-02 | Wave 0 docs parity turns the facade-first onboarding story into an executable RED contract | smoke | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs -x` | ✅ existing+updated | ⬜ pending |
| 17-02-01 | 17-02 | 2 | API-04 | T-17-04, T-17-06 | Helper and security modules are hidden while public storage adapters stay visible per D-03 | unit | `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs -x` | ✅ via 17-01 | ⬜ pending |
| 17-02-02 | 17-02 | 2 | API-03, API-04 | T-17-05, T-17-06 | ExDoc groups reflect the layered public surface without exposing helper modules | docs | `mix docs --warnings-as-errors` | ✅ existing | ⬜ pending |
| 17-03-01 | 17-03 | 2 | API-04 | T-17-07, T-17-08 | Domain schema modules remain visible while FSM/stale-policy internals hide | unit | `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs -x` | ✅ via 17-01 | ⬜ pending |
| 17-03-02 | 17-03 | 2 | API-04 | T-17-07, T-17-08 | Generated docs prove “public schema, hidden invariant” across `Rindle.Domain.*` | unit + docs | `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs -x && mix docs --warnings-as-errors` | ✅ via 17-01 | ⬜ pending |
| 17-05-01 | 17-05 | 2 | API-04 | T-17-09 | `Rindle.Ops.*` disappears from docs while Mix tasks remain the supported operations entrypoint | unit | `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs -x` | ✅ via 17-01 | ⬜ pending |
| 17-05-02 | 17-05 | 2 | API-04 | T-17-10 | Internal pipeline workers hide while the two public maintenance workers remain visible | unit + docs | `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs -x && mix docs --warnings-as-errors` | ✅ via 17-01 | ⬜ pending |
| 17-04-01 | 17-04 | 3 | API-01, API-03 | T-17-10 | Preferred facade verification name lands with docs-only deprecation on the legacy shim and LiveView parity | unit | `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs test/rindle/live_view_test.exs -x` | ✅ via 17-01 | ⬜ pending |
| 17-04-02 | 17-04 | 3 | API-02, API-03, API-05 | T-17-11, T-17-12 | Hidden logging shim, facade-first docs, and the semver/boundary decision artifact all converge on the locked public surface | unit + docs + artifact | `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs -x && mix docs --warnings-as-errors && rg -n "Storage\\.Local|Storage\\.S3|verify_completion/2|verify_upload/2|0\\.1\\.x|v0\\.2\\.0" .planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md` | ✅ planned | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/api_surface_boundary_test.exs` — facade alias, doc visibility, and compatibility-shim assertions for API-01/API-02/API-04
- [ ] `test/install_smoke/docs_parity_test.exs` — update parity assertions for `verify_completion/2` and facade-first teaching
- [ ] `mix docs --warnings-as-errors` coverage in execution verification — docs output must become a required check for this phase
- [ ] API-05 is intentionally not a Wave 0 artifact. It is closed in Plan `17-04` by `.planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md` plus the `rg` verification above.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Review the generated API reference groups and confirm the layered IA matches the locked public surface | API-03, API-04 | ExDoc structure quality is partly editorial, not just binary visibility | Run `mix docs`, open the generated API reference, and verify modules are grouped into facade-first tiers with no internal namespaces exposed |
| Confirm the breaking-change decision artifact reconciles the `Storage.Local` / `Storage.S3` wording mismatch against the locked context | API-05 | This is a human judgment call about project intent and downstream clarity | Read the final Phase 17 decision artifact and confirm it explicitly states that D-03 overrides the older generic requirement wording |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING test references; API-05 is an end-of-phase artifact requirement, not a Wave 0 test gap
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
