---
phase: 91
slug: cohort-demo-evolution
status: pending
nyquist_compliant: true
wave_0_complete: true
---

# Phase 91 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via `mix test`; direct `mix` tasks for Cohort demo app |
| **Config file** | `examples/adoption_demo/mix.exs` |
| **Quick run command** | `cd examples/adoption_demo && mix compile && mix run priv/repo/seeds.exs` |
| **Full suite command** | N/A (Demo app validation is structural/behavioral rather than unit tested) |
| **Estimated runtime** | ~5-10 seconds for compiling and running seeds |

---

## Sampling Rate

- **After every task commit:** Run the specified automated verification command for the task.
- **After every plan wave:** Ensure the demo app compiles and seeds run successfully.
- **Max feedback latency:** ~10 seconds locally for automated demo validation.

---

## Requirement Coverage Map

| Requirement | Status | Automated Evidence | Test File |
|-------------|--------|--------------------|-----------|
| DEMO-01 | COVERED | Verify new logo exists and layouts compile | `examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex` |
| DEMO-02 | COVERED | Verify seeded records via `mix run priv/repo/seeds.exs` execution | `examples/adoption_demo/priv/repo/seeds.exs` |
| DEMO-03 | COVERED | Verify admin router compiles and documentation exists | `examples/adoption_demo/lib/adoption_demo_web/router.ex` |

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 91-01-T1 | 91-01 | 1 | DEMO-01 | T-91-01 | Logos are self-contained SVGs | File existence | `ls examples/adoption_demo/priv/static/images/logo_opt* \| wc -l \| grep -q "3"` | Yes | pending |
| 91-01-T2 | 91-01 | 1 | DEMO-01 | T-91-01 | Manual logo selection | Checkpoint | N/A | N/A | pending |
| 91-01-T3 | 91-01 | 1 | DEMO-01 | T-91-01 | Selected logo integrated securely | Compilation | `cd examples/adoption_demo && mix compile` | Yes | pending |
| 91-02-T1 | 91-02 | 1 | DEMO-02 | T-91-02 | Profiles defined statically | Compilation | `cd examples/adoption_demo && mix compile` | Yes | pending |
| 91-02-T2 | 91-02 | 1 | DEMO-02 | T-91-02 | Seeds insert directly | Script execution | `cd examples/adoption_demo && mix run priv/repo/seeds.exs` | Yes | pending |
| 91-03-T1 | 91-03 | 1 | DEMO-03 | T-91-03 | Admin console explicitly isolated via browser scope | Compilation | `cd examples/adoption_demo && mix compile` | Yes | pending |
| 91-03-T2 | 91-03 | 1 | DEMO-03 | T-91-03 | Walkthrough added to README | Grep | `grep -c "Admin Console Walkthrough" examples/adoption_demo/README.md` | Yes | pending |

*Status: pending, green, red, flaky*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions | Status |
|----------|-------------|------------|-------------------|--------|
| Logo selection | DEMO-01 | Aesthetic decision required by human | View generated SVG logos and select the preferred brand asset. | pending |
| Visual verification of demo app | DEMO-01, DEMO-02, DEMO-03 | Visual layout and walkthrough flow validation | Run `mix phx.server` in `examples/adoption_demo` and view the console. | pending |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or a recorded manual checkpoint.
- [x] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] No watch-mode flags in verification commands.
- [x] `nyquist_compliant: true` set in frontmatter after validation implementation.
