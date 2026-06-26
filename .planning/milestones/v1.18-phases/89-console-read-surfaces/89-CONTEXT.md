# Phase 89: Console Read Surfaces - Context

**Gathered:** 2026-06-12 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 89 ships the mountable admin console read experience: the router macro and
host-auth integration contract, self-contained static asset serving, the six read
surfaces, live updates over existing Rindle PubSub topics, and the optional
LiveView compile-away proof.

This phase delivers ADMIN-01, ADMIN-02 package/serving completion, ADMIN-03,
ADMIN-05, and ADMIN-06. It does not implement destructive or repair action
flows, Cohort rebrand/expanded seeds/walkthrough, deterministic full console
E2E, screenshot polish loops, or docs/facade parity. Those remain scoped to
phases 90-93.
</domain>

<decisions>
## Implementation Decisions

### Mount And Auth Boundary

- **D-89-01:** Implement `Rindle.Admin.Router.rindle_admin/2` as the only new
  public console surface in Phase 89. The macro is mounted from a host router
  scope, expands to direct LiveView routes, and follows the locked
  LiveDashboard/Oban Web-style option shape.
- **D-89-02:** Host apps own browser pipeline, auth pipeline, and LiveView
  `:on_mount` checks. Rindle must refuse unsafe unauthenticated production
  mounts by default.
- **D-89-03:** Provide only a narrow development/test escape hatch for examples,
  CI, and preview apps. The planner may choose the exact option name, but the
  behavior must be unavailable as a production auth bypass and must not weaken
  the host-owned auth boundary.
- **D-89-04:** Preserve explicit mount options for `:on_mount`, route helper
  `:as`, `:home_path`, `:live_socket_path`, `:transport`, and
  `:csp_nonce_assign_key`. Apply host-provided CSP nonce assigns rather than
  generating Rindle-owned nonces.

### Optional LiveView Boundary

- **D-89-05:** Guard every Phoenix/LiveView-specific admin module with the
  existing `Code.ensure_loaded?/1` pattern before Phoenix or LiveView aliases
  expand.
- **D-89-06:** Add an ADMIN-06 proof that default/non-console installs compile
  without `phoenix_live_view`. This must be a real no-LiveView compile/package
  boundary check, not just a source grep.
- **D-89-07:** Do not make `phoenix_live_view` a required dependency and do not
  add a new runtime UI framework or registry dependency.

### Assets And Package Serving

- **D-89-08:** Move or copy the generated Phase 88 admin assets into
  `priv/static/rindle_admin` and serve them from the `:rindle` OTP app with a
  library-owned static asset route.
- **D-89-09:** The shipped console assets remain self-contained: generated
  `rindle-admin` CSS, any minimal console JS, logo/favicon assets, and no host
  Tailwind, daisyUI, esbuild, or asset-pipeline requirement.
- **D-89-10:** Add a package-file assertion in the same phase so Hex includes
  the `priv/static/rindle_admin` asset files. Local success without package
  inclusion is not sufficient for ADMIN-02.
- **D-89-11:** Continue treating `brandbook/tokens/tokens.json` and Phase 88
  generators as the design-system source of truth. Do not hand-edit generated
  CSS artifacts.

### Read Surfaces And Query Boundary

- **D-89-12:** Build the six top-level read surfaces exactly as locked:
  `Home/Status`, `Assets`, `Upload Sessions`, `Variants/Jobs`,
  `Runtime/Doctor`, and `Actions`.
- **D-89-13:** Keep Phase 89 read-only. The `Actions` surface may list or route
  toward future operations, but destructive execution, repair, regeneration,
  and quarantine write flows belong to Phase 90.
- **D-89-14:** Put console read composition in `Rindle.Admin.Queries`.
  `Rindle.Admin.Queries` may query domain schemas and compose existing read
  models such as `Rindle.Ops.RuntimeStatus` and `Rindle.Ops.RuntimeChecks`.
- **D-89-15:** Do not add admin convenience reads to `lib/rindle.ex`. The
  Phase 89 public API expansion is the mountable console boundary, not facade
  query helpers.
- **D-89-16:** Keep sensitive runtime output redacted where existing surfaces
  already do so, especially upload `session_uri` values and provider-internal
  IDs.

### Live Updates

- **D-89-17:** Reuse `Rindle.PubSub` and the existing topic grammar for
  `:asset`, `:variant`, and `:upload_session`; do not create a second realtime
  channel for the console.
- **D-89-18:** The codebase already broadcasts variant/asset and provider-asset
  events. Phase 89 should add or normalize upload-session broadcasts where
  lifecycle changes occur so the upload-session read surface can update live.
- **D-89-19:** Console LiveViews should subscribe to the minimum relevant topics
  for the visible page and refresh through `Rindle.Admin.Queries` rather than
  trusting PubSub payloads as the full data source.

### Cohort Boundary

- **D-89-20:** Use tests and minimal host/demo support as needed to prove the
  mount contract, but leave Cohort rebrand, audio/document media expansion,
  full lifecycle-state seeds, click-around walkthrough, and demo polish to
  Phase 91.
- **D-89-21:** If Cohort needs a small router mount hook to prove Phase 89, keep
  it narrow and avoid turning this phase into DEMO-01..03 implementation.

### the agent's Discretion

The maintainer confirmed the assumptions as presented. Routine internal module
layout, helper naming, test file naming, LiveView template decomposition, and
exact read-model formatting can be resolved by research/planning as long as the
decisions above are preserved.

Escalate before proceeding only if implementation would change public API shape
beyond the router macro and narrow dev/test escape hatch, weaken auth semantics,
make LiveView or UI tooling required for non-console adopters, add destructive
semantics, expose sensitive runtime IDs/URLs, or reshape milestone scope.

### Folded Todos

No matching pending todos were found for Phase 89.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope And Prior Decisions

- `.planning/ROADMAP.md` - Phase 89 goal, dependencies, requirements, and
  success criteria.
- `.planning/REQUIREMENTS.md` - ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-05,
  ADMIN-06, and v1.18 out-of-scope boundaries.
- `.planning/PROJECT.md` - v1.18 charter, decision-making contract, support
  truth, and high-blast-radius escalation rules.
- `.planning/STATE.md` - current milestone position and Phase 88 completion
  context.
- `.planning/METHODOLOGY.md` - adopter-first, repo-truth, research-first,
  narrow-then-escalate, least-surprise, and durable planning memory lenses.
- `.planning/phases/86-research-architecture-lock/86-CONTEXT.md` - D-86-01
  through D-86-10 and D-86-19 lock mount, auth, assets, optional dependency,
  IA, and query boundaries.
- `.planning/phases/86-research-architecture-lock/86-RESEARCH.md` - prior-art
  research for LiveDashboard/Oban Web/Phoenix LiveView router shape, CSP,
  optional deps, and auth pitfalls.
- `.planning/phases/88-admin-design-system-ui-kit/88-CONTEXT.md` - Phase 88
  design-system decisions and Phase 89 asset-serving ownership.
- `.planning/phases/88-admin-design-system-ui-kit/88-SECURITY.md` - verified
  Phase 88 security boundary before consuming generated CSS/gallery assets.

### Admin Architecture And UI Contracts

- `guides/admin_console_architecture.md` - router macro, safe mount, static
  assets, CSP/socket options, optional dependency matrix, and
  `Rindle.Admin.Queries` boundary.
- `guides/admin_console_ia.md` - six top-level surfaces, operator jobs,
  diagnostics-before-actions model, and read/action split.
- `guides/rindle_admin_css.md` - generated CSS architecture, BEM selectors,
  theme contract, status-chip requirements, and dependency prohibitions.
- `guides/admin_design_system.md` - Phase 88 operating contract, package
  boundary, asset-generation commands, and Phase 89 `priv/static/rindle_admin`
  ownership.
- `guides/ui_principles.md` - UI/accessibility/security rules for console,
  Cohort, E2E, and screenshot work.

### Library Runtime And Query Inputs

- `mix.exs` - optional dependency posture, ExDoc grouping, package files, and
  existing `priv` inclusion.
- `lib/rindle/live_view.ex` - existing optional LiveView compile gate and
  PubSub topic helper pattern.
- `lib/rindle/application.ex` - `Rindle.PubSub` supervision.
- `lib/rindle/config.ex` - repo/profile/app-env patterns for query modules.
- `lib/rindle/domain/media_asset.ex` - asset lifecycle states and schema fields.
- `lib/rindle/domain/media_attachment.ex` - attachment context for asset detail.
- `lib/rindle/domain/media_variant.ex` - variant lifecycle states and schema
  fields.
- `lib/rindle/domain/media_upload_session.ex` - upload-session lifecycle states,
  resumable fields, and `session_uri` redaction.
- `lib/rindle/domain/media_processing_run.ex` - processing-run context for job
  activity where useful.
- `lib/rindle/domain/media_provider_asset.ex` - provider-side state and
  provider ID redaction.
- `lib/rindle/ops/runtime_status.ex` - bounded runtime read model for assets,
  variants, upload sessions, provider assets, and recommendations.
- `lib/rindle/ops/runtime_checks.ex` - doctor/runtime prerequisite checks.
- `lib/mix/tasks/rindle.doctor.ex` - existing operator doctor wrapper.
- `lib/mix/tasks/rindle.runtime_status.ex` - text/JSON runtime-status wrapper
  and output ordering.
- `lib/rindle/workers/process_variant.ex` - variant/asset PubSub broadcast
  precedent.
- `lib/rindle/workers/ingest_provider_webhook.ex` - provider-asset/asset PubSub
  broadcast and provider-ID redaction precedent.

### Generated Assets And Demo Context

- `brandbook/tokens/tokens.json` - design-token source of truth.
- `brandbook/tokens/rindle-admin.css` - generated admin CSS artifact to move or
  copy into package-owned static assets.
- `brandbook/src/admin-design-system-data.mjs` - allowed themes, surfaces,
  statuses, components, motion tokens, and contrast pairs.
- `brandbook/src/admin-css-build.mjs` - generated CSS builder and parity check.
- `brandbook/src/admin-contrast.mjs` - console-specific WCAG contrast gate.
- `brandbook/src/admin-gallery.mjs` - static gallery markup/reference patterns.
- `brandbook/src/admin-gallery-check.mjs` - browser checks, selector contracts,
  and screenshot review harness.
- `examples/adoption_demo/lib/adoption_demo_web/router.ex` - current Cohort
  routes and future narrow mount hook location if needed.
- `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` - existing
  demo operator surface precedent, not the shipped admin console.
- `examples/adoption_demo/playwright.config.js` - existing browser test harness
  precedent.
- `RUNNING.md` - required verification lanes and local/CI operating model.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Rindle.LiveView` already demonstrates the optional dependency gate and exposes
  PubSub topic helpers for `:asset`, `:variant`, `:provider_asset`, and
  `:upload_session`.
- `Rindle.Application` already starts `Rindle.PubSub`; Phase 89 should reuse it.
- `Rindle.Ops.RuntimeStatus` already returns bounded counts, findings, provider
  asset summaries, upload-session summaries, and recommendations suitable for
  home/status, variants/jobs, upload sessions, and runtime surfaces.
- `Rindle.Ops.RuntimeChecks` and `Mix.Tasks.Rindle.Doctor` already provide the
  doctor/runtime check source for read-only console presentation.
- Domain schemas already expose first-class state vocabularies for assets,
  variants, upload sessions, provider assets, attachments, and processing runs.
- Phase 88 produced generated admin CSS, status/theme/component contracts,
  browser gallery checks, and contrast gates ready to be packaged and consumed.

### Established Patterns

- Optional integrations are guarded with `Code.ensure_loaded?/1` and should not
  leak required Phoenix/LiveView aliases into default installs.
- Public facade expansion is high blast radius. v1.18 permits the mountable
  console surface, while admin reads remain in `Rindle.Admin.Queries`.
- Rindle keeps sensitive upload/provider internals redacted in operator output.
  Console surfaces must preserve this, especially `session_uri` and raw
  provider asset IDs.
- Generated artifacts are source-derived and should not be hand-edited.
- The shipped library console is vanilla, namespaced, self-contained UI; Cohort
  may keep Tailwind/daisyUI, but the package console cannot depend on host
  frontend tooling.
- UI navigation stays task-first and operational, not decorative dashboard
  sprawl.

### Integration Points

- `Rindle.Admin.Router.rindle_admin/2` connects to host router scopes,
  LiveView `on_mount`, socket path, transport, CSP nonce assigns, route helper
  naming, and home/logo behavior.
- Static assets connect through a package-owned path under
  `priv/static/rindle_admin` and a `Plug.Static` route served from `:rindle`.
- `Rindle.Admin.Queries` connects to `Rindle.Config.repo/0`, domain schemas,
  `Rindle.Ops.RuntimeStatus`, and `Rindle.Ops.RuntimeChecks`.
- Live updates connect through `Rindle.PubSub` topics and then refresh visible
  query data.
- Cohort may receive a narrow mount hook later, but the broader Cohort adoption
  evidence work remains Phase 91.
</code_context>

<specifics>
## Specific Ideas

- Use `Rindle Admin` as the service identity in page titles, nav labels, empty
  states, and error states.
- Keep the Docker-preview admin URL target stable at `/admin/rindle`.
- Keep selectors stable and namespaced with `data-rindle-admin-*` attributes so
  Phase 92 deterministic E2E and screenshot work can build on Phase 89.
- Treat upload-session PubSub as the most likely implementation gap: the topic
  helper exists, but source search found no upload-session lifecycle
  broadcaster yet.
- Prefer query refresh on PubSub receipt over storing full mutable UI truth in
  event payloads.
</specifics>

<deferred>
## Deferred Ideas

- Console ops actions, destructive flows, typed confirmations, receipts,
  lifecycle repair, regeneration, and quarantine write behavior remain Phase 90.
- Cohort rebrand, audio/document profiles, full lifecycle-state seeds, console
  walkthrough, and adoption-demo click-around evidence remain Phase 91.
- Deterministic full-console E2E and all-screens light/dark screenshot polish
  remain Phase 92.
- Docs/facade parity for the scope reversal remains Phase 93.

### Reviewed Todos (not folded)

No matching pending todos were found for Phase 89.
</deferred>

---

*Phase: 89-console-read-surfaces*
*Context gathered: 2026-06-12*
