# Phase 87: Docker & Demo DX - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents. Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-11
**Phase:** 87-docker-demo-dx
**Mode:** assumptions
**Areas analyzed:** Compose Ports And Namespacing, Launch Wrapper, Dockerfile
Cache Shape, MinIO URL Boundary, Docs And Verification

## Assumptions Presented

### Compose Ports And Namespacing

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Use `COMPOSE_PROJECT_NAME` plus env-driven, loopback-bound host ports in `docker/compose.cohort-demo.yml`; keep internal Phoenix and MinIO ports unchanged. | Likely | `guides/docker_demo_dx.md`; `docker/compose.cohort-demo.yml`; `examples/adoption_demo/config/runtime.exs` |

### Launch Wrapper

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep `scripts/demo/up.sh` as the copy-paste entry point and enhance it to print the locked URL map for app, admin console, and MinIO console. | Confident | `guides/docker_demo_dx.md`; `scripts/demo/up.sh`; `examples/adoption_demo/README.md` |

### Dockerfile Cache Shape

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Reorder `docker/Dockerfile.cohort-demo` so dependency files are copied before app source and `mix deps.get` runs before the full repo copy; avoid adding a release build or split image in this phase. | Confident | `guides/docker_demo_dx.md`; `docker/Dockerfile.cohort-demo` |

### MinIO URL Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Preserve the split between container-internal MinIO access and host/browser-facing MinIO URLs because Cohort generates presigned URLs that the browser must reach. | Likely | `docker/compose.cohort-demo.yml`; `docker/cohort-demo-entrypoint.sh`; `examples/adoption_demo/config/runtime.exs`; `examples/adoption_demo/docs/adoption-proof-matrix.md` |

### Docs And Verification

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Update Docker quick-try docs and proof matrix alongside compose/script changes, and plan at least static verification such as `docker compose config` plus targeted script checks before attempting heavier container startup. | Likely | `examples/adoption_demo/README.md`; `examples/adoption_demo/docs/adoption-proof-matrix.md`; `RUNNING.md`; `guides/docker_demo_dx.md` |

## Corrections Made

No corrections - all assumptions confirmed.
