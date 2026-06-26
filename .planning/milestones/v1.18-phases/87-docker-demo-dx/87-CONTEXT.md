# Phase 87: Docker & Demo DX - Context

**Gathered:** 2026-06-11 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 87 makes the Cohort Docker demo stack fast and conflict-free before the
UI-heavy v1.18 phases iterate on it. It delivers the DX-01, DX-02, and DX-03
requirements: compose namespacing and env-driven ports, port-conflict guidance,
Dockerfile dependency-cache ordering, a dev iteration path where style/template
changes do not rebuild dependencies, and a launch flow that prints URLs for the
app, future admin console route, and MinIO console.

This phase does not implement the admin console, Cohort rebrand, audio/document
profiles, lifecycle-state seeds, deterministic console E2E, or docs/facade
parity. Those remain scoped to phases 88-93.
</domain>

<decisions>
## Implementation Decisions

### Compose Ports And Namespacing

- **D-87-01:** Use `COMPOSE_PROJECT_NAME` as the stack namespacing mechanism so
  maintainers can run sibling demos without container, network, or volume
  collisions.
- **D-87-02:** Replace fixed host port bindings with env-driven defaults:
  `COHORT_DEMO_PORT=4102`, `COHORT_MINIO_PORT=9000`, and
  `COHORT_MINIO_CONSOLE_PORT=9001`.
- **D-87-03:** Bind published app and MinIO ports to loopback. MinIO API and
  console are local developer tooling, not public preview surfaces.
- **D-87-04:** Keep container-internal ports stable: Phoenix still listens on
  `PORT=4102`, MinIO API stays `9000`, and MinIO console stays `9001`.

### Launch Wrapper

- **D-87-05:** Preserve `scripts/demo/up.sh` as the copy-paste Docker preview
  entry point.
- **D-87-06:** Enhance the launch path to print a copy-pasteable URL map with
  exactly these labels: `app`, `admin console`, and `MinIO console`.
- **D-87-07:** The URL map should resolve from the same env-driven host ports
  compose uses. The locked targets are `http://localhost:${COHORT_DEMO_PORT}`,
  `http://localhost:${COHORT_DEMO_PORT}/admin/rindle`, and
  `http://localhost:${COHORT_MINIO_CONSOLE_PORT}` with documented defaults.

### Dockerfile Cache Shape

- **D-87-08:** Reorder `docker/Dockerfile.cohort-demo` so dependency files are
  copied before app source and `mix deps.get` runs before the full repo copy.
- **D-87-09:** Keep Phase 87 to cache-friendly Docker preview improvements.
  Do not introduce a release build, split image, Traefik, or production-style
  deployment topology in this phase.
- **D-87-10:** The dependency-cache contract must cover routine source, style,
  and template edits without re-fetching Hex dependencies.

### MinIO URL Boundary

- **D-87-11:** Preserve the split between container-internal MinIO wiring and
  browser-facing presigned URL reachability. Service-to-service setup can use
  `http://minio:9000`, but URLs emitted to browsers must point at the published
  host MinIO API port.
- **D-87-12:** Keep the existing demo-preview-only credential posture and bucket
  name unless implementation discovers a concrete conflict with env-driven port
  support.

### Docs And Verification

- **D-87-13:** Update the Docker quick-try docs and adoption proof matrix when
  the compose/script contract changes.
- **D-87-14:** Verification should include at least static compose/script checks
  such as rendered `docker compose config`, plus targeted shell syntax or output
  checks for the launch wrappers. Attempt heavier container startup only where
  practical for the plan's risk level.

### the agent's Discretion

The maintainer confirmed the assumptions as presented. Routine helper names,
shell formatting, exact docs wording, and verification command selection can be
resolved by research/planning without returning to the maintainer unless they
change public API shape, security exposure, destructive behavior, recurring
cost, or milestone scope.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope And Prior Decisions

- `.planning/ROADMAP.md` - Phase 87 goal, dependencies, and success criteria.
- `.planning/REQUIREMENTS.md` - DX-01, DX-02, and DX-03 requirement wording.
- `.planning/PROJECT.md` - v1.18 milestone charter, decision-making contract,
  pause override, and scope boundaries.
- `.planning/STATE.md` - current milestone position and Phase 87 readiness.
- `.planning/METHODOLOGY.md` - adopter-first, repo-truth, research-first, and
  least-surprise lenses.
- `.planning/phases/86-research-architecture-lock/86-CONTEXT.md` - D-86-16,
  D-86-17, and D-86-18 lock Docker/Cohort DX direction for Phase 87.

### Docker Demo Contract

- `guides/docker_demo_dx.md` - locked Phase 86 Docker DX contract for
  namespacing, env-driven ports, URL map labels, cache ordering, exposure
  boundary, and Traefik rejection.
- `docker/compose.cohort-demo.yml` - current compose stack and fixed-port
  baseline to replace.
- `docker/Dockerfile.cohort-demo` - current build-cache ordering to fix.
- `docker/cohort-demo-entrypoint.sh` - demo container boot sequence, database
  migration, seeds, and MinIO readiness behavior.
- `scripts/demo/up.sh` - primary Docker preview launch wrapper to preserve and
  enhance.
- `scripts/demo/down.sh` - stop wrapper that must continue to target the same
  compose project/file contract.
- `scripts/demo/reset.sh` - volume-reset wrapper that must continue to target
  the same compose project/file contract.

### Cohort Demo Runtime And Docs

- `examples/adoption_demo/config/runtime.exs` - Phoenix `PORT`, Docker preview
  flag, endpoint bind behavior, and MinIO URL parsing.
- `examples/adoption_demo/config/dev.exs` - native dev default port and local
  endpoint behavior.
- `examples/adoption_demo/config/test.exs` - Playwright/test port defaults and
  test runtime assumptions.
- `examples/adoption_demo/playwright.config.js` - browser E2E server port
  override precedent.
- `examples/adoption_demo/README.md` - Docker quick-try documentation to update.
- `examples/adoption_demo/docs/adoption-proof-matrix.md` - local click-around
  preview proof row and Docker URL claim to keep honest.
- `guides/admin_console_architecture.md` - future admin console mount path
  context for the URL map target.
- `RUNNING.md` - repo verification lanes and local/CI operating model.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `docker/compose.cohort-demo.yml` already defines Postgres, MinIO,
  `minio-init`, and the Cohort demo service; Phase 87 should modify this stack
  rather than introduce a parallel preview stack.
- `scripts/demo/up.sh`, `scripts/demo/down.sh`, and `scripts/demo/reset.sh`
  already provide the maintainer-facing wrapper surface.
- `docker/cohort-demo-entrypoint.sh` already waits for Postgres and MinIO,
  runs Ecto/Rindle migrations, seeds Cohort, and starts Phoenix.
- `examples/adoption_demo/config/runtime.exs` already centralizes Docker
  preview endpoint and MinIO runtime configuration.

### Established Patterns

- Cohort Docker preview is explicitly preview-only and optional; it is not a
  production deployment path.
- Rindle keeps adopter-facing claims honest across docs and proof surfaces, so
  Docker URL/port changes should update docs in the same phase.
- Internal service ports can remain stable while host bindings become
  env-driven. This minimizes changes to application config and container
  health checks.
- Phase 86 rejected Traefik for this scope; local port-conflict avoidance does
  not need a reverse proxy.

### Integration Points

- Compose published ports feed browser-visible URLs for the Cohort app and
  presigned MinIO uploads.
- `scripts/demo/up.sh` should derive its printed URLs from the same env vars
  compose consumes.
- `scripts/demo/down.sh` and `scripts/demo/reset.sh` must continue to address
  the same compose file and project namespace used by `up.sh`.
- Dockerfile cache changes must keep the local path dependency on the repo and
  the Cohort app's `mix assets.vendor` / `mix compile` build path intact.
</code_context>

<specifics>
## Specific Ideas

- Use the exact URL map labels locked in `guides/docker_demo_dx.md`: `app`,
  `admin console`, and `MinIO console`.
- Print the admin console URL even before the console is implemented so later
  phases have a stable launch affordance; the route target is
  `/admin/rindle`.
- Favor env-var guidance over editing compose files when a default port is
  busy.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within Phase 87 scope.

### Reviewed Todos (not folded)

No matching pending todos were found for Phase 87.
</deferred>

---

*Phase: 87-docker-demo-dx*
*Context gathered: 2026-06-11*
