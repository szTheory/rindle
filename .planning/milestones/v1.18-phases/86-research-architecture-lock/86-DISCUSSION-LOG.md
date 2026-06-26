# Phase 86: Research & Architecture Lock - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-11T15:13:31Z
**Phase:** 86-research-architecture-lock
**Mode:** assumptions
**Areas analyzed:** Mountable Console Packaging, Optional Dependency Boundary, Console IA And Query Boundary, Design System/CSS/Motion, Docker And Cohort Adoption Lab, Phase 86 Outputs

## Assumptions Presented

### Mountable Console Packaging

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Treat Rindle's console like a library-owned LiveDashboard/Oban Web-style surface: `Rindle.Admin.Router` imports a macro such as `rindle_admin "/rindle"`; host apps supply browser pipeline/auth and an `on_mount` hook; Rindle supplies self-contained assets and CSP nonce options. | Confident | `mix.exs`; `lib/rindle/live_view.ex`; `lib/rindle/application.ex`; `.planning/PROJECT.md`; `.planning/REQUIREMENTS.md`; Phoenix LiveDashboard router docs; Oban Web router docs |

**If wrong:** Phase 89 may choose a shape that fights Phoenix router conventions or leaks host asset-pipeline/Tailwind assumptions into adopters.

### Optional Dependency Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Do not add Phoenix/LiveView as required runtime dependencies for non-console users. Console modules should compile only when the required Phoenix modules are present, following existing optional-module patterns. | Confident | `mix.exs`; `lib/rindle/live_view.ex`; `lib/rindle/streaming/provider/mux.ex`; `lib/rindle/storage/gcs.ex`; `.planning/REQUIREMENTS.md` ADMIN-06 |

**If wrong:** v1.18 would violate the existing "adopters pay zero transitive cost unless enabled" posture and make the console feel like platform sprawl.

### Console IA And Query Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 86 research should define a task-first IA around actual Rindle operator jobs: home/status, assets, upload sessions, variants/jobs, doctor/runtime status, and action surfaces. Reads stay in `Rindle.Admin.Queries`, not the public facade. | Likely | `lib/rindle/domain/media_asset.ex`; `lib/rindle/domain/media_variant.ex`; `lib/rindle/domain/media_upload_session.ex`; `lib/rindle/ops/runtime_status.ex`; `lib/rindle/ops/lifecycle_repair.ex`; `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex`; GOV.UK navigation patterns; ADMIN-03/05 |

**If wrong:** The console may overfit to implementation objects instead of adopter/operator jobs, or expand the public API beyond the v1.18 boundary.

### Design System, CSS, And Motion

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Use a vanilla CSS `rindle-admin` layer generated from `brandbook/tokens/tokens.json`: BEM class names, CSS custom properties, `data-theme="light|dark|auto"`, token-gated status chips, and no Tailwind dependency. Motion should be operational and fast. | Confident | `brandbook/tokens/tokens.json`; `brandbook/src/tokens-build.mjs`; `brandbook/src/contrast.mjs`; `.planning/PROJECT.md`; Emil Kowalski motion articles |

**If wrong:** Phase 88 may either couple the library UI to a host build system or produce motion/visual polish that conflicts with a high-frequency operational console.

### Docker And Cohort Adoption Lab

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 87 should fix Docker before UI iteration: parameterize project name/ports/env, improve layer caching by copying dependency manifests before source, and print app/admin/MinIO URLs. Cohort remains the demo app. | Confident | `docker/compose.cohort-demo.yml`; `docker/Dockerfile.cohort-demo`; `scripts/demo/up.sh`; `examples/adoption_demo/e2e/`; `examples/adoption_demo/priv/repo/seeds.exs`; Docker Compose env docs |

**If wrong:** Later UI/E2E phases will waste time on rebuilds, sibling-project port conflicts, and brittle launch UX.

### Phase 86 Outputs

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 86 should not implement the console yet. It should produce locked ADR/research docs for packaging, IA, motion, Docker DX, CSS architecture, and PRIN-01 UI principles in `AGENTS.md`, so phases 87-93 can execute without reopening architecture. | Confident | `.planning/ROADMAP.md` Phase 86; `.planning/METHODOLOGY.md`; `AGENTS.md` |

**If wrong:** Phase 86 will blur into implementation and leave downstream agents without stable constraints.

## Corrections Made

No corrections - all assumptions confirmed by maintainer selection `1` ("Yes, proceed").

## External Research

- Phoenix LiveDashboard router macro precedent:
  https://phoenix-live-dashboard.hexdocs.pm/Phoenix.LiveDashboard.Router.html
- Oban Web router macro/options precedent:
  https://oban-web.hexdocs.pm/Oban.Web.Router.html
- Docker Compose project/env precedence:
  https://docs.docker.com/compose/how-tos/environment-variables/envvars/
- GOV.UK service navigation:
  https://design-system.service.gov.uk/components/service-navigation/
- GOV.UK step-by-step navigation:
  https://design-system.service.gov.uk/patterns/step-by-step-navigation/
- Emil Kowalski animation principles:
  https://emilkowal.ski/ui/great-animations
  https://emilkowal.ski/ui/7-practical-animation-tips
