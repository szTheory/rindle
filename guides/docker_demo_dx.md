# Docker Demo DX

## TL;DR

- Use `COMPOSE_PROJECT_NAME` for project namespacing.
- Replace fixed host ports with env-driven defaults:
  `COHORT_DEMO_PORT=4102`, `COHORT_MINIO_PORT=9000`, and
  `COHORT_MINIO_CONSOLE_PORT=9001`.
- Keep internal Phoenix `PORT=4102` and `PHX_HOST=localhost`.
- Preserve the simple `scripts/demo/up.sh` wrapper.
- Fix Dockerfile cache ordering by copying dependency files before the full source tree.
- Do not add Traefik in Phase 87 unless a later recorded requirement needs multi-host
  routing.

Phase 86 locks the Docker/Cohort demo DX contract only. Phase 87 implements it.

## Compose Namespacing

`COMPOSE_PROJECT_NAME` is the project namespacing mechanism for the Cohort demo stack.
Phase 87 should allow maintainers to run sibling demos without container, network, or
volume name collisions.

Recommended usage:

```sh
COMPOSE_PROJECT_NAME=rindle-cohort ./scripts/demo/up.sh
```

The current top-level `name: cohort-demo` is a baseline, not the final contract. Phase 87
may keep a sane default, but environment override must be the documented path.

## Host Port Contract

Host ports are environment-driven:

| Service | Env var | Default | Internal port |
| --- | --- | --- | --- |
| Cohort app | `COHORT_DEMO_PORT` | `4102` | `4102` |
| MinIO API | `COHORT_MINIO_PORT` | `9000` | `9000` |
| MinIO console | `COHORT_MINIO_CONSOLE_PORT` | `9001` | `9001` |

Internal Phoenix remains:

```sh
PORT=4102
PHX_HOST=localhost
```

The current fixed-port baseline to replace is `"4102:4102"`, `"9000:9000"`, and
`"9001:9001"`.

## Launch URL Map

Phase 87 launch output should print a copy-pasteable URL map:

| Label | URL |
| --- | --- |
| `app` | `http://localhost:${COHORT_DEMO_PORT:-4102}` |
| `admin console` | `http://localhost:${COHORT_DEMO_PORT:-4102}/admin/rindle` |
| `MinIO console` | `http://localhost:${COHORT_MINIO_CONSOLE_PORT:-9001}` |

The labels are locked as `app`, `admin console`, and `MinIO console`.

## Dockerfile Cache Ordering

The current Dockerfile copies the full repo before `mix deps.get`, which invalidates the
dependency cache for routine source or style changes.

Phase 87 should copy dependency files first:

1. `mix.exs`
2. `mix.lock`
3. `examples/adoption_demo/mix.exs`
4. `examples/adoption_demo/mix.lock`

Then run `mix deps.get` before app source copy. After dependencies are cached, copy the
rest of the source and run the app build steps.

## Wrapper Contract

Preserve the simple `scripts/demo/up.sh` entry point. It should remain the maintainer's
copy-paste command for the Docker preview, even if it learns to print URLs or pass project
names.

## Exposure Boundary

The MinIO console is local-only developer tooling. Do not present the Docker preview as a
production deployment path, and do not document public MinIO console exposure.

The app URL can use localhost; published production topology is outside this phase.

## Traefik Decision

Reject Traefik for Phase 87. Traefik can help when a real multi-host routing requirement
exists, but this phase needs local port-conflict avoidance, cache-friendly builds, and a
URL map. Adding Traefik now would add another service, labels, ports, and failure modes
without a recorded need.

If a later recorded requirement needs multi-host routing, reopen the reverse-proxy decision
with that requirement in hand.

## Recovery And Footguns

- If port `4102` is busy, set `COHORT_DEMO_PORT` instead of editing the compose file.
- If port `9000` or `9001` is busy, set `COHORT_MINIO_PORT` or
  `COHORT_MINIO_CONSOLE_PORT`.
- If stale containers collide, change `COMPOSE_PROJECT_NAME` or run the matching compose
  down command for the old project.
- If dependency installs rerun on every source edit after Phase 87, the Dockerfile ordering
  regressed.

## Downstream Constraints

- Phase 87 updates compose ports and URL-map output.
- Phase 87 fixes Dockerfile layer cache ordering.
- Later UI/E2E phases rely on this preview being fast and conflict-free.
