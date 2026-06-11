---
phase: 86
slug: research-architecture-lock
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-11
updated: 2026-06-11
---

# Phase 86 - Validation Strategy

Per-phase validation contract for the Research & Architecture Lock phase.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell source assertions with `test` and `rg`; ExUnit for public API boundary proof; Node for brand contrast proof |
| **Config file** | `mix.exs`, `brandbook/tokens/tokens.json`, `brandbook/src/contrast.mjs` |
| **Quick run command** | `mix test test/rindle/api_surface_boundary_test.exs` |
| **Full suite command** | `mix coveralls` |
| **Estimated runtime** | Targeted Phase 86 checks are expected to finish in under 60 seconds; `mix coveralls` is the release-train full-suite gate |

---

## Sampling Rate

- **After every task commit:** Run that task's `test -f` and `rg` source assertions from its PLAN.md `<verify>` block.
- **After every plan wave:** Run all Phase 86 task-level source assertions, plus `mix test test/rindle/api_surface_boundary_test.exs` and `node brandbook/src/contrast.mjs`.
- **Before `$gsd-verify-work`:** Run all task-level automated checks. Run `mix coveralls` if `mix.exs`, packaged docs metadata, implementation code, or release-train surfaces changed.
- **Max feedback latency:** Under 60 seconds for targeted Phase 86 checks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 86-01-01 | 01 | 1 | PRIN-01 | T-86-01 / T-86-02 / T-86-03 / T-86-04 | Architecture lock refuses unsafe unauthenticated production mount, preserves CSP/static-asset guidance, and keeps admin reads out of the public facade | docs/static + ExUnit | `test -f guides/admin_console_architecture.md && rg -n "(Rindle\\.Admin\\.Router\\.rindle_admin/2|Rindle\\.Admin\\.Queries|Code\\.ensure_loaded\\?|Plug\\.Static|:csp_nonce_assign_key|:live_socket_path|:on_mount|unsafe unauthenticated mounts|dev/test-only escape-hatch policy|:as|:home_path|default Rindle logo)" guides/admin_console_architecture.md && mix test test/rindle/api_surface_boundary_test.exs` | created by task | pending |
| 86-01-02 | 01 | 1 | PRIN-01 | T-86-03 / T-86-04 | IA separates read/status surfaces from destructive action surfaces and maps reads to `Rindle.Admin.Queries` | docs/static | `test -f guides/admin_console_ia.md && rg -n "(Home/Status|Assets|Upload Sessions|Variants/Jobs|Runtime/Doctor|Actions|Rindle Admin|Rindle\\.Admin\\.Queries|Rindle\\.Ops\\.RuntimeStatus|decorative dashboard sprawl|owner erasure|batch erasure|lifecycle repair)" guides/admin_console_ia.md` | created by task | pending |
| 86-02-01 | 02 | 1 | PRIN-01 | T-86-05 / T-86-06 / T-86-08 | CSS lock uses token-generated BEM classes, mechanical contrast, and no third-party UI registry dependency for the shipped console | docs/static + Node | `test -f guides/rindle_admin_css.md && rg -n "(rindle-admin|BEM|brandbook/tokens/tokens\\.json|--rindle-|data-theme=\"light\\|dark\\|auto\"|prefers-color-scheme|Tailwind|daisyUI|status chip|color alone|44px|Space Grotesk|Atkinson Hyperlegible|#F7F4EA|#123A35|#C83232|#6D5DD3)" guides/rindle_admin_css.md && node brandbook/src/contrast.mjs` | created by task | pending |
| 86-02-02 | 02 | 1 | PRIN-01 | T-86-07 | Motion lock permits only operational motion, requires reduced-motion handling, and forbids decorative or non-state-backed animation | docs/static | `test -f guides/admin_console_motion.md && rg -n "(--rindle-motion-press|120ms|--rindle-motion-popover|160ms|--rindle-motion-toast|200ms|--rindle-motion-transition|300ms|--rindle-motion-easing|prefers-reduced-motion|origin-aware|decorative animation|parallax|infinite loops|real PubSub|destructive)" guides/admin_console_motion.md` | created by task | pending |
| 86-03-01 | 03 | 1 | PRIN-01 | T-86-09 / T-86-10 | Docker DX lock avoids local port denial of service and keeps MinIO exposure local-only | docs/static | `test -f guides/docker_demo_dx.md && rg -n "(COMPOSE_PROJECT_NAME|COHORT_DEMO_PORT|4102|COHORT_MINIO_PORT|9000|COHORT_MINIO_CONSOLE_PORT|9001|PHX_HOST=localhost|/admin/rindle|mix deps.get|scripts/demo/up.sh|4102:4102|9000:9000|9001:9001|MinIO console|Traefik|multi-host routing)" guides/docker_demo_dx.md` | created by task | pending |
| 86-03-02 | 03 | 1 | PRIN-01 | T-86-11 | UI principles make design, accessibility, deterministic E2E, screenshots, motion, destructive-action, and escalation rules durable | docs/static | `test -f guides/ui_principles.md && rg -n "(Design-system values|Visual and accessibility audit checklist|Deterministic E2E rules|Screenshot polish loop|Motion constraints|Security and destructive-action rules|When to escalate|brandbook/tokens/tokens\\.json|brandbook/src/contrast\\.mjs|rindle-admin|BEM|data-theme=\"light\\|dark\\|auto\"|prefers-color-scheme|prefers-reduced-motion|44px|Space Grotesk|Atkinson Hyperlegible|JetBrains Mono|stable selectors|seeded lifecycle state|light/dark screenshot|text-only assertions|public API shape|auth semantics|dependency footprint|destructive operations|security/compliance boundary|material recurring cost|milestone scope)" guides/ui_principles.md` | created by task | pending |
| 86-03-03 | 03 | 1 | PRIN-01 | T-86-12 | `AGENTS.md` points future UI/admin-console agents at PRIN-01 guidance before UI, E2E, or polish work | docs/static | `test -f guides/ui_principles.md && rg -n "For UI/admin-console work, follow \\[guides/ui_principles\\.md\\]\\(guides/ui_principles\\.md\\)" AGENTS.md` | `AGENTS.md` exists; guide created by prior task | pending |

*Status values: pending, green, red, flaky.*

---

## Wave 0 Requirements

Existing infrastructure covers all Phase 86 requirements. No Wave 0 test scaffold, fixture file, or framework install is required because every planned task has an automated source assertion and the repo already has ExUnit plus Node validation scripts.

---

## Manual-Only Verifications

All Phase 86 behaviors have automated verification. No manual-only checks are required for this docs/architecture-lock phase.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify commands or direct task-level automated assertions.
- [x] Sampling continuity: no 3 consecutive tasks lack automated verification.
- [x] Wave 0 has no missing test references.
- [x] No watch-mode flags are used.
- [x] Targeted feedback latency is under 60 seconds.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** approved 2026-06-11
