---
phase: 06
slug: adopter-runtime-ownership
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
revised: 2026-04-28
---

# Phase 06 — Validation Strategy

> Reconstructed from executed Phase 6 plans and summaries, then audited against live test and grep evidence on 2026-04-28.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + targeted `rg` contract checks |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/rindle/config/config_test.exs test/rindle/upload/broker_test.exs` |
| **Full suite command** | `mix test test/rindle/config/config_test.exs && mix test test/rindle/upload/broker_test.exs && mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs && mix test test/rindle/upload/lifecycle_integration_test.exs:183` |
| **Estimated runtime** | ~5 seconds for the focused Phase 6 proof lane |

---

## Sampling Rate

- **After every task commit:** Run the task-local `mix test ...` command from the verification map below.
- **After every plan wave:** Run the full suite command plus the matching `rg` leak/doc contract checks for that wave.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 5 seconds for Phase 6's focused proof lane.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|--------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | ADOPT-01 | — | `Rindle.Config.repo/0` honors adopter override and default fallback | unit | `mix test test/rindle/config/config_test.exs` | ✅ | ✅ green |
| 06-01-02 | 01 | 1 | ADOPT-01, ADOPT-02 | T-06-01-01, T-06-01-02 | facade entrypoints resolve one runtime Repo seam and avoid direct `Rindle.Repo` persistence calls | unit + static contract | `mix test test/rindle/config/config_test.exs && ! rg -n "Rindle\\.Repo\\.(transaction|get!|get|insert!?|update!?|delete!?|all|one|preload)" lib/rindle.ex` | ✅ | ✅ green |
| 06-02-01 | 02 | 2 | ADOPT-02, ADOPT-03, ADOPT-04 | T-06-02-01 | broker persistence paths use the configured Repo seam and broker docs stop teaching `Rindle.Repo` | unit + static contract | `mix test test/rindle/upload/broker_test.exs && ! rg -n "Requires Rindle\\.Repo|alias Rindle\\.Repo" lib/rindle/upload/broker.ex` | ✅ | ✅ green |
| 06-02-02 | 02 | 2 | ADOPT-02, ADOPT-03, ADOPT-04 | T-06-02-02, T-06-02-03 | canonical adopter lane and proxied upload lane both pass against adopter Repo ownership with default-Oban scope explicit | integration | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs && mix test test/rindle/upload/lifecycle_integration_test.exs:183 && rg -n "Application\\.put_env\\(:rindle, :repo, Rindle\\.Adopter\\.CanonicalApp\\.Repo\\)|use Oban\\.Testing, repo: Rindle\\.Adopter\\.CanonicalApp\\.Repo|Rindle\\.upload\\(" test/adopter/canonical_app/lifecycle_test.exs test/rindle/upload/lifecycle_integration_test.exs && ! rg -n "TODO\\(adopter-repo\\)" test/adopter/canonical_app/lifecycle_test.exs && rg -n "sandbox_repo" test/support/data_case.ex` | ✅ | ✅ green |
| 06-03-01 | 03 | 3 | ADOPT-04 | T-06-03-01 | setup and troubleshooting guides teach adopter-owned Repo configuration instead of `Rindle.Repo` | docs + static contract | `rg -n "config :rindle, :repo, MyApp\\.Repo" guides/getting_started.md guides/troubleshooting.md && rg -n "MyApp\\.Repo\\.(get!|get_by!|all)" guides/troubleshooting.md && rg -n "Broker\\.initiate_session|Rindle\\.attach|Rindle\\.detach" guides/getting_started.md && ! rg -n "Rindle\\.Repo" guides/getting_started.md guides/troubleshooting.md` | ✅ | ✅ green |
| 06-03-02 | 03 | 3 | ADOPT-04 | T-06-03-02 | background-processing guide states default-Oban support and named-instance deferral precisely | docs + adopter proof | `rg -n "default Oban|named-instance|named instance|:oban_name|adopters own Oban supervision|adopters own.*queue config|default Oban Repo" guides/background_processing.md && mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs` | ✅ | ✅ green |

*Status: ✅ green · ⚠️ partial · ❌ missing*

### Coverage of Phase Requirements

| Requirement | Covered By | Status |
|-------------|------------|--------|
| ADOPT-01 | 06-01-01, 06-01-02 | ✅ covered |
| ADOPT-02 | 06-01-02, 06-02-01, 06-02-02 | ✅ covered |
| ADOPT-03 | 06-02-01, 06-02-02 | ✅ covered |
| ADOPT-04 | 06-02-01, 06-02-02, 06-03-01, 06-03-02 | ✅ covered |

---

## Wave 0 Requirements

Existing infrastructure covers all Phase 6 requirements.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Audit 2026-04-28

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Notes:
- `workflow.nyquist_validation` is absent from project config, but the GSD defaults document that absence as enabled-by-default; this audit proceeded on that basis.
- Live audit evidence confirmed the focused Phase 6 proof lane still passes:
  - `mix test test/rindle/config/config_test.exs`
  - `mix test test/rindle/upload/broker_test.exs`
  - `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs`
  - `mix test test/rindle/upload/lifecycle_integration_test.exs:183`

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all MISSING references.
- [x] No watch-mode flags.
- [x] Feedback latency < 5s for the focused Phase 6 proof lane.
- [x] `nyquist_compliant: true` set in frontmatter.
- [x] `wave_0_complete: true` set in frontmatter.

**Approval:** approved 2026-04-28
