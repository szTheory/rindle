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
| 86-01-01 | 01 | 1 | PRIN-01 | T-86-01 / T-86-02 / T-86-03 / T-86-04 | Architecture lock refuses unsafe unauthenticated production mount, preserves CSP/static-asset guidance, and keeps admin reads out of the public facade | docs/static + ExUnit | `test -f guides/admin_console_architecture.md && rg -F -q -- 'Rindle.Admin.Router.rindle_admin/2' guides/admin_console_architecture.md && rg -F -q -- 'Rindle.Admin.Queries' guides/admin_console_architecture.md && rg -F -q -- 'Code.ensure_loaded?/1' guides/admin_console_architecture.md && rg -F -q -- 'Plug.Static' guides/admin_console_architecture.md && rg -F -q -- ':csp_nonce_assign_key' guides/admin_console_architecture.md && rg -F -q -- ':live_socket_path' guides/admin_console_architecture.md && rg -F -q -- ':on_mount' guides/admin_console_architecture.md && rg -F -q -- 'unsafe unauthenticated mounts' guides/admin_console_architecture.md && rg -F -q -- 'dev/test-only escape-hatch policy' guides/admin_console_architecture.md && rg -F -q -- 'exact public option name is intentionally not locked' guides/admin_console_architecture.md && rg -F -q -- 'host Tailwind' guides/admin_console_architecture.md && rg -F -q -- 'convenience reads' guides/admin_console_architecture.md && rg -F -q -- ':as' guides/admin_console_architecture.md && rg -F -q -- ':home_path' guides/admin_console_architecture.md && rg -F -q -- 'default Rindle logo' guides/admin_console_architecture.md && rg -F -q -- 'host replacement' guides/admin_console_architecture.md && rg -F -q -- 'hiding of the logo' guides/admin_console_architecture.md && mix test test/rindle/api_surface_boundary_test.exs` | created by task | pending |
| 86-01-02 | 01 | 1 | PRIN-01 | T-86-03 / T-86-04 | IA separates read/status surfaces from destructive action surfaces and maps reads to `Rindle.Admin.Queries` | docs/static | `test -f guides/admin_console_ia.md && rg -F -q -- 'Home/Status' guides/admin_console_ia.md && rg -F -q -- 'Assets' guides/admin_console_ia.md && rg -F -q -- 'Upload Sessions' guides/admin_console_ia.md && rg -F -q -- 'Variants/Jobs' guides/admin_console_ia.md && rg -F -q -- 'Runtime/Doctor' guides/admin_console_ia.md && rg -F -q -- 'Actions' guides/admin_console_ia.md && rg -F -q -- 'Rindle Admin' guides/admin_console_ia.md && rg -F -q -- 'Rindle.Admin.Queries' guides/admin_console_ia.md && rg -F -q -- 'Rindle.Ops.RuntimeStatus' guides/admin_console_ia.md && rg -F -q -- 'decorative dashboard sprawl' guides/admin_console_ia.md && rg -F -q -- 'owner erasure' guides/admin_console_ia.md && rg -F -q -- 'batch erasure' guides/admin_console_ia.md && rg -F -q -- 'lifecycle repair' guides/admin_console_ia.md` | created by task | pending |
| 86-02-01 | 02 | 1 | PRIN-01 | T-86-05 / T-86-06 / T-86-08 | CSS lock uses token-generated BEM classes, mechanical contrast, and no third-party UI registry dependency for the shipped console | docs/static + Node | `test -f guides/rindle_admin_css.md && rg -F -q -- 'rindle-admin' guides/rindle_admin_css.md && rg -F -q -- 'BEM' guides/rindle_admin_css.md && rg -F -q -- 'brandbook/tokens/tokens.json' guides/rindle_admin_css.md && rg -F -q -- '--rindle-' guides/rindle_admin_css.md && rg -q -- 'data-theme="light\|dark\|auto"' guides/rindle_admin_css.md && rg -F -q -- 'prefers-color-scheme' guides/rindle_admin_css.md && rg -F -q -- 'Tailwind' guides/rindle_admin_css.md && rg -F -q -- 'daisyUI' guides/rindle_admin_css.md && rg -F -q -- 'status chip' guides/rindle_admin_css.md && rg -F -q -- 'color alone' guides/rindle_admin_css.md && rg -F -q -- '44px' guides/rindle_admin_css.md && rg -F -q -- 'Space Grotesk' guides/rindle_admin_css.md && rg -F -q -- 'Atkinson Hyperlegible' guides/rindle_admin_css.md && rg -F -q -- '#F7F4EA' guides/rindle_admin_css.md && rg -F -q -- '#123A35' guides/rindle_admin_css.md && rg -F -q -- '#C83232' guides/rindle_admin_css.md && rg -F -q -- '#6D5DD3' guides/rindle_admin_css.md && node brandbook/src/contrast.mjs` | created by task | pending |
| 86-02-02 | 02 | 1 | PRIN-01 | T-86-07 | Motion lock permits only operational motion, requires reduced-motion handling, and forbids decorative or non-state-backed animation | docs/static | `test -f guides/admin_console_motion.md && rg -F -q -- '--rindle-motion-press' guides/admin_console_motion.md && rg -F -q -- '120ms' guides/admin_console_motion.md && rg -F -q -- '--rindle-motion-popover' guides/admin_console_motion.md && rg -F -q -- '160ms' guides/admin_console_motion.md && rg -F -q -- '--rindle-motion-toast' guides/admin_console_motion.md && rg -F -q -- '200ms' guides/admin_console_motion.md && rg -F -q -- '--rindle-motion-transition' guides/admin_console_motion.md && rg -F -q -- '300ms' guides/admin_console_motion.md && rg -F -q -- '--rindle-motion-easing' guides/admin_console_motion.md && rg -F -q -- 'prefers-reduced-motion' guides/admin_console_motion.md && rg -F -q -- 'origin-aware' guides/admin_console_motion.md && rg -F -q -- 'decorative animation' guides/admin_console_motion.md && rg -F -q -- 'parallax' guides/admin_console_motion.md && rg -F -q -- 'infinite loops' guides/admin_console_motion.md && rg -F -q -- 'real PubSub' guides/admin_console_motion.md && rg -F -q -- 'destructive' guides/admin_console_motion.md` | created by task | pending |
| 86-03-01 | 03 | 1 | PRIN-01 | T-86-09 / T-86-10 | Docker DX lock avoids local port denial of service and keeps MinIO exposure local-only | docs/static | `test -f guides/docker_demo_dx.md && rg -F -q -- 'COMPOSE_PROJECT_NAME' guides/docker_demo_dx.md && rg -F -q -- 'COHORT_DEMO_PORT' guides/docker_demo_dx.md && rg -F -q -- '4102' guides/docker_demo_dx.md && rg -F -q -- 'COHORT_MINIO_PORT' guides/docker_demo_dx.md && rg -F -q -- '9000' guides/docker_demo_dx.md && rg -F -q -- 'COHORT_MINIO_CONSOLE_PORT' guides/docker_demo_dx.md && rg -F -q -- '9001' guides/docker_demo_dx.md && rg -F -q -- 'PHX_HOST=localhost' guides/docker_demo_dx.md && rg -F -q -- '/admin/rindle' guides/docker_demo_dx.md && rg -F -q -- 'mix deps.get' guides/docker_demo_dx.md && rg -F -q -- 'scripts/demo/up.sh' guides/docker_demo_dx.md && rg -F -q -- '4102:4102' guides/docker_demo_dx.md && rg -F -q -- '9000:9000' guides/docker_demo_dx.md && rg -F -q -- '9001:9001' guides/docker_demo_dx.md && rg -F -q -- 'MinIO console' guides/docker_demo_dx.md && rg -F -q -- 'Traefik' guides/docker_demo_dx.md && rg -F -q -- 'multi-host routing' guides/docker_demo_dx.md` | created by task | pending |
| 86-03-02 | 03 | 1 | PRIN-01 | T-86-11 | UI principles make design, accessibility, deterministic E2E, screenshots, motion, destructive-action, and escalation rules durable | docs/static | `test -f guides/ui_principles.md && rg -F -q -- 'Design-system values' guides/ui_principles.md && rg -F -q -- 'Visual and accessibility audit checklist' guides/ui_principles.md && rg -F -q -- 'Deterministic E2E rules' guides/ui_principles.md && rg -F -q -- 'Screenshot polish loop' guides/ui_principles.md && rg -F -q -- 'Motion constraints' guides/ui_principles.md && rg -F -q -- 'Security and destructive-action rules' guides/ui_principles.md && rg -F -q -- 'When to escalate' guides/ui_principles.md && rg -F -q -- 'brandbook/tokens/tokens.json' guides/ui_principles.md && rg -F -q -- 'brandbook/src/contrast.mjs' guides/ui_principles.md && rg -F -q -- 'rindle-admin' guides/ui_principles.md && rg -F -q -- 'BEM' guides/ui_principles.md && rg -q -- 'data-theme="light\|dark\|auto"' guides/ui_principles.md && rg -F -q -- 'prefers-color-scheme' guides/ui_principles.md && rg -F -q -- 'prefers-reduced-motion' guides/ui_principles.md && rg -F -q -- '44px' guides/ui_principles.md && rg -F -q -- 'Space Grotesk' guides/ui_principles.md && rg -F -q -- 'Atkinson Hyperlegible' guides/ui_principles.md && rg -F -q -- 'JetBrains Mono' guides/ui_principles.md && rg -F -q -- 'stable selectors' guides/ui_principles.md && rg -F -q -- 'seeded lifecycle state' guides/ui_principles.md && rg -F -q -- 'light/dark screenshot' guides/ui_principles.md && rg -F -q -- 'text-only assertions' guides/ui_principles.md && rg -F -q -- 'public API shape' guides/ui_principles.md && rg -F -q -- 'auth semantics' guides/ui_principles.md && rg -F -q -- 'dependency footprint' guides/ui_principles.md && rg -F -q -- 'destructive operations' guides/ui_principles.md && rg -F -q -- 'security/compliance boundary' guides/ui_principles.md && rg -F -q -- 'material recurring cost' guides/ui_principles.md && rg -F -q -- 'milestone scope' guides/ui_principles.md` | created by task | pending |
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
