---
phase: 93
slug: truth-docs-milestone-audit
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-13
---

# Phase 93 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This is a truth/docs/audit phase: validation = mechanically proving false phrases are GONE
> and truthful phrases are PRESENT on every public surface.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + grep/ripgrep for absence checks |
| **Config file** | `mix.exs` / `test/test_helper.exs`; parity tests under `test/install_smoke/` |
| **Quick run command** | `mix test test/install_smoke/docs_parity_test.exs` |
| **Full suite command** | `mix test` (plus `mix docs` to regenerate HexDocs and confirm the new guide renders) |
| **Estimated runtime** | ~10–30 seconds (parity file); full suite per project baseline |

Existing pattern: `test/install_smoke/docs_parity_test.exs` already uses `Code.fetch_docs/1` + `assert/refute doc =~`. Extend it (or add `admin_console_docs_parity_test.exs`) rather than hand-rolling.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/install_smoke/docs_parity_test.exs`
- **After every plan wave:** Run `mix test` + `mix docs` (confirm guide renders, no broken extras link)
- **Before `/gsd:verify-work`:** Full suite green AND repo-wide grep proving zero false phrases remain on public surfaces
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| facade-truth | 01 | 1 | TRUTH-07 | N/A | unit | `refute Code.fetch_docs(Rindle) doc =~ "admin UI"` (denial); `assert doc =~ "rindle_admin"` | ❌ W0 (extend parity test) | ⬜ pending |
| guides-truth | 01 | 1 | TRUTH-07 | N/A | unit | `refute File.read!("guides/operations.md") =~ "intentionally has no dashboard"` (+ troubleshooting) | ❌ W0 | ⬜ pending |
| user-flows-truth | 01 | 1 | TRUTH-07 | N/A | unit | `refute uf =~ "an admin UI"` and `refute uf =~ "Admin UI, force-delete"` | ❌ W0 | ⬜ pending |
| admin-console-guide | 02 | 2 | TRUTH-07 | N/A | unit | `assert File.exists?("guides/admin_console.md")`; `assert mix.exs extras includes it`; `assert guide =~ "rindle_admin"` | ❌ W0 | ⬜ pending |
| readme-console | 02 | 2 | TRUTH-07 | N/A | unit | `assert File.read!("README.md") =~ "Admin Console"` | ❌ W0 | ⬜ pending |
| jtbd-reversal | 01 | 1 | TRUTH-07 | N/A | grep | `! grep -q "admin UI" <T4 + row36>`; `grep -E "Against:.*v1\.18" .planning/JTBD-MAP.md` | ❌ W0 / manual | ⬜ pending |
| traceability | 03 | 3 | TRUTH-07 | N/A | grep | `grep -q "TRUTH-07.*Complete"`; no active req stuck "Planned" | ❌ W0 / manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `test/install_smoke/docs_parity_test.exs` (or add `admin_console_docs_parity_test.exs`) with the `refute`/`assert` truth assertions above — covers TRUTH-07 mechanically so false phrases can never reappear.
- [ ] `guides/admin_console.md` must be created before the "guide exists + in extras" assertion can pass.

*The parity test is the Nyquist lock: corrected phrases become CI-enforced.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| HexDocs landing reads truthfully (guide renders, Admin Console discoverable) | TRUTH-07 | Visual render check | Run `mix docs`, open `doc/admin_console.html` + index, confirm console is present and no "no admin UI" copy |
| Milestone-close status (`shipped` vs `tech_debt`) | TRUTH-07 | Depends on HUMAN-UAT sign-off for phases 90–92 | Confirm maintainer UAT sign-off state at plan/execute time; audit records `tech_debt` + follow-ups if unsigned |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (parity test extension + guide creation)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
