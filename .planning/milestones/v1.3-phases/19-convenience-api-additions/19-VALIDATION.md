---
phase: 19
slug: convenience-api-additions
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-01
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

Source: `.planning/phases/19-convenience-api-additions/19-RESEARCH.md` `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18 / OTP 27) — `mix test` |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `.doctor.exs` |
| **Quick run command** | `mix test test/rindle/convenience_api_test.exs` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Doctor gate** | `mix doctor --full --raise` |
| **Format gate** | `mix format --check-formatted` |
| **Estimated runtime** | ~3-5 seconds quick / ~25-40 seconds full |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/convenience_api_test.exs`
- **After every plan wave:** Run `mix test --warnings-as-errors` + `mix format --check-formatted` + `mix doctor --full --raise`
- **Before `/gsd-verify-work`:** Full suite + doctor + format must all be green
- **Max feedback latency:** ~5 seconds (quick) / ~40 seconds (wave gate)

---

## Per-Task Verification Map

> Task IDs are placeholders; the planner will assign final IDs in PLAN.md frontmatter. Use these mapping rows as the contract.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | API-09 / API-10 / API-11 | — | RED — assertions for the 8 helpers + `Rindle.Error` exist and FAIL on `master` (functions undefined) | unit (RED) | `mix test test/rindle/convenience_api_test.exs` (must FAIL on missing functions) | ❌ W0 | ⬜ pending |
| 19-01-02 | 01 | 1 | API-11 | — | `@public_modules` allowlist includes `Rindle.Error`; boundary test compiles | unit | `mix test test/rindle/api_surface_boundary_test.exs` | ✅ | ⬜ pending |
| 19-02-01 | 02 | 2 | API-09 | — | `Rindle.attachment_for/2,3` returns `MediaAttachment.t() \| nil` with `:asset` auto-preloaded; `:preload` opt replaces default | unit + integration | `mix test test/rindle/convenience_api_test.exs` (passes after impl) | ✅ | ⬜ pending |
| 19-02-02 | 02 | 2 | API-10 | — | `Rindle.ready_variants_for/1` filters `state == "ready"`, ordered by `:name`, accepts `%MediaAsset{}` or binary id | unit + integration | `mix test test/rindle/convenience_api_test.exs` | ✅ | ⬜ pending |
| 19-02-03 | 02 | 2 | API-11 | — | `Rindle.Error` exception with `:action`/`:reason`, `message/1` branches `:not_found`/`{:quarantine,_}`/fallback | unit | `mix test test/rindle/convenience_api_test.exs` (Error suite) | ✅ | ⬜ pending |
| 19-02-04 | 02 | 2 | API-11 | — | 5 bang variants raise correct exception classes per error tuple shape; success path returns unwrapped struct | unit + integration | `mix test test/rindle/convenience_api_test.exs` (Bangs suite) | ✅ | ⬜ pending |
| 19-02-05 | 02 | 2 | API-09 / API-10 / API-11 | — | All 8 functions + `Rindle.Error` have `@doc` + `@spec`; `mix doctor --full --raise` passes 100/100/100/95/95 | static analysis | `mix doctor --full --raise` | ✅ | ⬜ pending |
| 19-02-06 | 02 | 2 | API-09 / API-10 / API-11 | — | CHANGELOG entry summarising convenience helpers; mix.exs `groups_for_modules` exposes `Rindle.Error` | docs | `grep -q "Convenience helpers" CHANGELOG.md && grep -q "Rindle.Error" mix.exs` | ✅ | ⬜ pending |
| 19-02-07 | 02 | 2 | API-09 / API-10 / API-11 | — | Full suite + format + doctor all green; no warnings | meta | `mix format --check-formatted && mix test --warnings-as-errors && mix doctor --full --raise` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/convenience_api_test.exs` — RED-only failing tests for the 8 helpers + `Rindle.Error` (assertions described in `19-RESEARCH.md` Test Plan; test cases derived from CONTEXT.md D-23). Created in Plan 19-01.
- [ ] `test/rindle/api_surface_boundary_test.exs` — append `Rindle.Error` to `@public_modules` (line range from CONTEXT.md `<canonical_refs>`). Modified in Plan 19-01.

*Existing test infrastructure (`test/support/data_case.ex` Sandbox + `test/support/mocks.ex` `Rindle.StorageMock`) covers all other phase requirements — no new framework or fixtures needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ExDoc HTML rendering of `Rindle.Error` group | API-11 | `mix docs` HTML can only be visually confirmed; CI never opens the file | After Plan 19-02 lands, run `mix docs` and open `doc/Rindle.Error.html` — confirm module appears under the chosen `groups_for_modules` slot |

*All other phase behaviors have automated verification through the per-task map above.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`Rindle.attachment_for`, `Rindle.ready_variants_for`, `Rindle.Error`, 5 bangs)
- [ ] No watch-mode flags (no `--watch`, no IEx-only checks)
- [ ] Feedback latency < 40 seconds (full wave gate)
- [ ] `nyquist_compliant: true` set in frontmatter once planner finalises task IDs

**Approval:** pending — awaits PLAN.md task IDs in step 7.5
