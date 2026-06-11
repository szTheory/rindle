# Phase 86: Research & Architecture Lock - Context

**Gathered:** 2026-06-11 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 86 locks the v1.18 architecture and design constraints before implementation
starts. It produces research-backed ADRs/docs for mountable console packaging,
console information architecture, restrained motion, Docker/demo DX, console CSS
architecture, and PRIN-01 UI principles.

This phase does not implement the admin console, Docker fixes, design system,
Cohort changes, E2E suite, or docs parity. Those remain scoped to phases 87-93.
</domain>

<decisions>
## Implementation Decisions

### Mountable Console Packaging

- **D-86-01:** Treat the admin console as a library-owned,
  LiveDashboard/Oban Web-style surface. Downstream design should converge on a
  router macro such as `Rindle.Admin.Router.rindle_admin/2`, mounted inside the
  host router's authenticated scope.
- **D-86-02:** Host apps own the browser pipeline, auth pipeline, and LiveView
  `on_mount` hook. Rindle should accept those hooks/options and refuse unsafe
  unauthenticated production mounting by default.
- **D-86-03:** Rindle owns the console assets. The console must ship
  self-contained, precompiled CSS/JS and must not require host Tailwind,
  esbuild, or asset-pipeline integration.
- **D-86-04:** Packaging research must cover CSP nonce options, socket path /
  transport options, route helper naming, logo/home path behavior, and
  optional-dependency matrix shape.

### Optional Dependency Boundary

- **D-86-05:** Preserve the current optional dependency posture. Non-console
  adopters must not pay a required LiveView/Phoenix dependency cost.
- **D-86-06:** Console modules that need Phoenix/LiveView should compile only
  when required modules are available, following the existing
  `Code.ensure_loaded?/1` pattern used by `Rindle.LiveView`, Mux provider
  modules, and GCS checks.
- **D-86-07:** ADMIN-06 is a hard requirement: when `phoenix_live_view` is
  absent, the console compiles away cleanly.

### Console IA And Query Boundary

- **D-86-08:** Research should define a task-first IA around actual Rindle
  operator jobs: home/status, assets, upload sessions, variants/jobs,
  doctor/runtime status, and action surfaces.
- **D-86-09:** Console reads belong in `Rindle.Admin.Queries`; they must not be
  promoted into the public `Rindle` facade as convenience APIs.
- **D-86-10:** Phase 86 should translate GOV.UK/GDS navigation patterns into
  Rindle's maintainer/operator context: clear service identity, obvious task
  grouping, ordered flows where order helps, and no decorative dashboard sprawl.

### Design System, CSS, And Motion

- **D-86-11:** Console CSS is a vanilla `rindle-admin` layer generated from
  `brandbook/tokens/tokens.json`, using BEM class names and CSS custom
  properties.
- **D-86-12:** Theme behavior is `data-theme="light|dark|auto"` plus
  `prefers-color-scheme`, consistent with the existing token generator.
- **D-86-13:** Status chips and operational state indicators must use token-gated
  color pairs and labels/icons; never rely on color alone.
- **D-86-14:** Motion is operational, fast, and restrained: use token durations,
  `prefers-reduced-motion`, origin-aware popovers/drawers, immediate action
  feedback, and no decorative animation.
- **D-86-15:** Cohort keeps its existing Tailwind/daisyUI momentum. The shipped
  library console does not inherit Cohort's frontend stack.

### Docker And Cohort Adoption Lab

- **D-86-16:** Phase 87 should fix Docker before UI-heavy phases iterate: project
  namespacing, env-driven ports, conflict guidance, better layer caching, and a
  launch URL map are prerequisites for efficient UI/E2E work.
- **D-86-17:** The current Dockerfile shape is a known DX issue: copying the
  whole repo before `mix deps.get` prevents useful dependency cache reuse.
- **D-86-18:** Cohort remains the demo domain. Later phases should extend it with
  Cohort branding, audio and document profiles, full lifecycle-state seeds,
  console mounting, and walkthrough/E2E evidence rather than replacing the demo.

### Phase 86 Outputs

- **D-86-19:** Phase 86 should produce locked research/ADR docs, not code
  implementation. Planning should split the research outputs so phases 87-93 can
  execute without reopening architecture.
- **D-86-20:** PRIN-01 should land as durable UI-principles guidance linked from
  `AGENTS.md`, covering design-system values, visual/a11y audit checklist,
  deterministic E2E rules, screenshot polish rules, and motion constraints.

### the agent's Discretion

The maintainer confirmed the assumptions as presented. Routine naming, file
layout, and internal helper decisions can be recommended by research/planning
without returning to the maintainer unless they affect public API shape,
security/auth semantics, destructive operations, dependency footprint, or
milestone scope.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` - current v1.18 phase scope and Phase 86 success criteria.
- `.planning/REQUIREMENTS.md` - ADMIN-01..06, DS-01..03, DEMO-01..03, E2E-01..02,
  DX-01..03, PRIN-01, TRUTH-07.
- `.planning/PROJECT.md` - durable charter, v1.18 locked decisions, security
  invariants, and scope boundaries.
- `.planning/METHODOLOGY.md` - adopter-first, repo-truth, research-first, and
  least-surprise lenses.
- `AGENTS.md` - repo workflow and future home/link target for PRIN-01 guidance.
- `RUNNING.md` - required verification lanes and local/CI operating model.
- `mix.exs` - optional dependency posture, ExDoc grouping, package files.
- `lib/rindle.ex` - current facade boundary and docs parity target for TRUTH-07.
- `lib/rindle/live_view.ex` - existing optional LiveView integration, PubSub
  helper topics, and `Code.ensure_loaded?/1` pattern.
- `lib/rindle/application.ex` - `Rindle.PubSub` supervision.
- `lib/rindle/config.ex` - repo/profile/app-env patterns.
- `lib/rindle/domain/media_asset.ex` - asset lifecycle states.
- `lib/rindle/domain/media_variant.ex` - variant lifecycle states.
- `lib/rindle/domain/media_upload_session.ex` - upload session lifecycle states.
- `lib/rindle/domain/asset_fsm.ex` - asset transition/telemetry behavior.
- `lib/rindle/domain/variant_fsm.ex` - variant transition/telemetry behavior.
- `lib/rindle/domain/upload_session_fsm.ex` - upload-session transition behavior.
- `lib/rindle/ops/runtime_status.ex` - existing runtime-status read model.
- `lib/rindle/ops/lifecycle_repair.ex` - existing repair action model.
- `lib/mix/tasks/rindle.doctor.ex` - existing doctor/operator surface.
- `lib/mix/tasks/rindle.runtime_status.ex` - existing runtime-status operator surface.
- `docker/compose.cohort-demo.yml` - current demo compose stack and fixed-port
  problem.
- `docker/Dockerfile.cohort-demo` - current build-cache problem.
- `scripts/demo/up.sh` - current launch wrapper.
- `docker/cohort-demo-entrypoint.sh` - current demo boot sequence.
- `brandbook/tokens/tokens.json` - design-token source of truth.
- `brandbook/src/tokens-build.mjs` - generated CSS custom property pipeline.
- `brandbook/src/contrast.mjs` - WCAG contrast gate pattern.
- `brandbook/tokens/tokens.css` - generated token output.
- `examples/adoption_demo/AGENTS.md` - Phoenix/LiveView conventions for Cohort.
- `examples/adoption_demo/lib/adoption_demo_web/router.ex` - current demo routes
  and tus mount.
- `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` - current
  operator proof surface.
- `examples/adoption_demo/lib/adoption_demo/media.ex` - Cohort/Rindle integration.
- `examples/adoption_demo/lib/adoption_demo/rindle_profile.ex` - current image,
  video, and Mux demo profiles.
- `examples/adoption_demo/priv/repo/seeds.exs` - current seed coverage.
- `examples/adoption_demo/e2e/` - existing Playwright adoption proof suite.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Rindle.LiveView` already provides optional LiveView helpers, upload completion
  verification, and PubSub subscription helpers for `:asset`, `:variant`,
  `:provider_asset`, and `:upload_session`.
- `Rindle.Application` already starts `Rindle.PubSub`, so live console updates
  can reuse existing topics rather than adding a second realtime channel.
- `Rindle.Ops.RuntimeStatus`, `Rindle.Ops.LifecycleRepair`, `Rindle.Internal.OwnerErasure`,
  and the `rindle.*` mix tasks are the operator domain sources for console read
  and action surfaces.
- `brandbook/tokens/tokens.json` plus `tokens-build.mjs` and `contrast.mjs`
  provide the design-system generation and contrast-gate precedent.
- Cohort already has a Phoenix LiveView app, demo domain, MinIO-backed Docker
  preview, and Playwright E2E harness.

### Established Patterns

- Optional integrations are guarded with `Code.ensure_loaded?/1` and
  `function_exported?/3`; console planning should reuse that posture.
- Rindle keeps adopter-facing truth in guides/docs/tests and avoids overclaiming
  optional capabilities.
- Public facade expansion is treated as high-blast-radius. v1.18 explicitly
  permits a mountable console as the only new public surface; operational
  queries remain isolated.
- CSS for shipped library UI must be host-independent. Cohort can keep its app
  stack, but the console cannot require the host to run Tailwind.

### Integration Points

- Router macro and LiveView mount options connect to host `router.ex` scopes.
- Console reads connect to `Rindle.Admin.Queries` over host repo/config patterns.
- Live updates connect through `Rindle.PubSub` and existing event topics.
- Destructive console actions must call existing facade/ops surfaces, especially
  owner erasure and batch erasure, with typed confirmation and collateral preview
  handled in UI.
- Docker DX connects through `docker/compose.cohort-demo.yml`,
  `docker/Dockerfile.cohort-demo`, and `scripts/demo/up.sh`.
</code_context>

<specifics>
## Specific Ideas

External research applied during assumptions analysis:

- Phoenix LiveDashboard router macro precedent:
  https://phoenix-live-dashboard.hexdocs.pm/Phoenix.LiveDashboard.Router.html
- Oban Web router macro, `on_mount`, socket/transport, and CSP nonce precedent:
  https://oban-web.hexdocs.pm/Oban.Web.Router.html
- Docker Compose project/env precedence:
  https://docs.docker.com/compose/how-tos/environment-variables/envvars/
- GOV.UK service navigation pattern:
  https://design-system.service.gov.uk/components/service-navigation/
- GOV.UK step-by-step navigation pattern:
  https://design-system.service.gov.uk/patterns/step-by-step-navigation/
- Emil Kowalski motion guidance:
  https://emilkowal.ski/ui/great-animations
  https://emilkowal.ski/ui/7-practical-animation-tips

No additional maintainer-specific ideas were introduced during confirmation.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within Phase 86 scope.

### Reviewed Todos (not folded)

No matching pending todos were found for Phase 86.
</deferred>
