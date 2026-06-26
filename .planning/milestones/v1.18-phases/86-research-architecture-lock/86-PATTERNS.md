# Phase 86: Research & Architecture Lock - Pattern Map

**Mapped:** 2026-06-11
**Files analyzed:** 7
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/admin_console_architecture.md` | documentation | request-response | `guides/secure_delivery.md` + `lib/rindle/live_view.ex` | role-match |
| `guides/admin_console_ia.md` | documentation | CRUD | `guides/user_flows.md` + `guides/operations.md` | exact |
| `guides/admin_console_motion.md` | documentation | event-driven | `brandbook/README.md` + `brandbook/tokens/tokens.css` | role-match |
| `guides/docker_demo_dx.md` | documentation | config/file-I/O | `guides/release_publish.md` + `docker/compose.cohort-demo.yml` | role-match |
| `guides/rindle_admin_css.md` | documentation | transform | `brandbook/README.md` + `brandbook/src/tokens-build.mjs` | exact |
| `guides/ui_principles.md` | documentation | config/process | `brandbook/README.md` + `examples/adoption_demo/AGENTS.md` | role-match |
| `AGENTS.md` | config | process | `AGENTS.md` | exact |

## Pattern Assignments

### `guides/admin_console_architecture.md` (documentation, request-response)

**Analog:** `guides/secure_delivery.md`, with implementation-source excerpts from `lib/rindle/live_view.ex`, `mix.exs`, `lib/rindle/config.ex`, and `examples/adoption_demo/lib/adoption_demo_web/router.ex`.

**Guide structure pattern** (`guides/secure_delivery.md` lines 1-20):

```markdown
# Secure Delivery

Rindle is **private-by-default**. A profile that does not opt into public
delivery serves every original and every variant via signed, time-limited
URLs.

This guide covers:

- The default private delivery posture
- How to configure signed URL TTL per profile
- How to opt a profile into public delivery (and when not to)
- How to attach an authorizer for fine-grained per-request checks
- The storage-adapter capability contract for signed URLs
- Threat-model notes on signed URLs
```

Copy this shape: strong posture statement first, then a short "This guide covers" list. For the admin console architecture doc, the opening should lock router macro, safe mount/auth ownership, optional dependencies, library-owned assets, CSP/socket options, and public API boundaries.

**Optional dependency pattern** (`mix.exs` lines 64-74):

```elixir
# LiveView integration (optional — Rindle.LiveView helpers are no-op without it)
{:phoenix_live_view, "~> 1.0", optional: true},

# Streaming providers (optional — Mux adapter only loads when these are present)
{:mux, "~> 3.2", optional: true},
{:jose, "~> 1.11", optional: true},

# GCS adapter (optional — Rindle.Storage.GCS only loads when these are present)
{:goth, "~> 1.4", optional: true},
{:finch, "~> 0.21", optional: true},
{:gcs_signed_url, "~> 0.4.6", optional: true},
```

**Compile gate pattern** (`lib/rindle/live_view.ex` lines 1-2, 64-70):

```elixir
if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.LiveView do
    require Logger

    alias Phoenix.LiveView.Upload
    alias Phoenix.PubSub
    alias Rindle.Config
    alias Rindle.Domain.MediaUploadSession
    alias Rindle.Upload.Broker
```

Document that future `Rindle.Admin.Router` and LiveView-backed admin modules must follow this `Code.ensure_loaded?/1` wrapping before any Phoenix aliases.

**Host router pattern** (`examples/adoption_demo/lib/adoption_demo_web/router.ex` lines 4-11, 18-29):

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {AdoptionDemoWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end

scope "/", AdoptionDemoWeb do
  pipe_through :browser

  live "/", DashboardLive, :index
  live "/members/:id", MemberLive, :show
  live "/lessons/:id", LessonLive, :show
  live "/posts/:id", PostLive, :show
  live "/upload", UploadLive, :index
  live "/media/:id", MediaLive, :show
  live "/ops", OpsLive, :index
  live "/account/:member_id/delete", AccountLive, :delete
end
```

Use this only as local Phoenix route shape context. Phase 86 docs should say the console macro is mounted inside the host's authenticated scope and should not own the host browser/auth pipeline.

**Config source pattern** (`lib/rindle/config.ex` lines 9-12, 70-74):

```elixir
@spec repo() :: module()
def repo do
  Application.get_env(:rindle, :repo, Rindle.Repo)
end

defp profile_module?(module) when is_atom(module) do
  Code.ensure_loaded?(module) and
    function_exported?(module, :__rindle_profile__, 0) and
    function_exported?(module, :variants, 0)
end
```

Document that `Rindle.Admin.Queries` should read through existing config/repo patterns and guard module availability with `Code.ensure_loaded?/1` plus `function_exported?/3`.

### `guides/admin_console_ia.md` (documentation, CRUD)

**Analog:** `guides/user_flows.md` and `guides/operations.md`.

**Job-first navigation pattern** (`guides/user_flows.md` lines 37-63):

```markdown
## Find your job

Scan for the row that sounds like your sentence, then jump to the story or guide.

| When you want to… | You reach for… | Go deeper |
|---|---|---|
| Upload straight to storage, bytes never touching your server | `Rindle.initiate_upload/2` → `Rindle.Upload.Broker.sign_url/2` → `Rindle.verify_completion/2` | [Avatar in five calls](#story-1-avatar-in-five-calls) |
| Wire uploads into LiveView with live progress | `Rindle.LiveView.allow_upload/4` + `consume_uploaded_entries/3` + `subscribe/2` | [LiveView, reactively](#story-4-liveview-reactively) |
| See what's stuck and repair it | `Rindle.runtime_status/1`, `mix rindle.doctor`, the `mix rindle.*` ops tasks | [Operations](operations.html) |
```

Copy this task-first table shape for console surfaces: Home/Status, Assets, Upload Sessions, Variants/Jobs, Runtime/Doctor, Actions. Keep labels as operator jobs, not module names.

**Operator diagnostic split pattern** (`guides/operations.md` lines 30-48):

```markdown
## Runtime Diagnostics

The operator diagnostics split is explicit:

- `mix rindle.doctor` validates setup and drift. It checks prerequisite runtime
  and ownership conditions before you guess.
- `mix rindle.runtime_status` reports degraded or stuck work. It is a bounded,
  read-only status report for assets, variants, and upload sessions.
- The repair verbs perform change. Use `reprobe`, `requeue`, `regenerate`,
  `cleanup`, or `sweep` only after diagnostics point you at the right lane.

In short: doctor validates setup and drift, runtime status reports degraded or stuck work, and repair verbs perform change.
```

Use this as the console IA boundary: read/status screens first, repair/action surfaces second, destructive actions deliberately separated.

**Surface map pattern** (`guides/operations.md` lines 71-82):

```markdown
## Choosing The Right Lane

Use this quick map before reaching for a task or API:

| Symptom | Supported verb | Surface |
| ------- | -------------- | ------- |
| Probe-derived fields drifted or were persisted before better detection shipped | `reprobe` | `Rindle.reprobe/1` |
| One asset has failed or cancelled variants that should run again | `requeue` | `Rindle.requeue_variants/2` |
| Timed-out direct upload residue is piling up | `cleanup` | `mix rindle.abort_incomplete_uploads` then `mix rindle.cleanup_orphans` |
```

**Backing read-model pattern** (`lib/rindle/ops/runtime_status.ex` lines 36-58):

```elixir
@spec runtime_status(keyword() | map()) :: {:ok, report()} | {:error, term()}
def runtime_status(opts \\ []) do
  with {:ok, filters} <- normalize_filters(opts) do
    now = DateTime.utc_now()
    cutoff = older_than_cutoff(now, filters.older_than)

    runtime_checks = runtime_checks_report(filters, cutoff, now)
    variants = variant_report(filters, cutoff, now)
    upload_sessions = upload_session_report(filters, cutoff, now)
    provider_assets = provider_assets_report(filters, now)

    {:ok,
     %{
       generated_at: now,
       filters: filters,
       runtime_checks: runtime_checks,
       assets: asset_report(filters),
       variants: variants,
       upload_sessions: upload_sessions,
       provider_assets: provider_assets,
       recommendations:
         build_recommendations(runtime_checks, variants, upload_sessions, provider_assets)
     }}
```

Use this to anchor IA claims in existing operator truth. Phase 86 should specify that future `Rindle.Admin.Queries` composes these read models and domain tables without adding facade convenience APIs.

### `guides/admin_console_motion.md` (documentation, event-driven)

**Analog:** `brandbook/README.md`, `brandbook/tokens/tokens.css`, and `lib/rindle/live_view.ex`.

**Token source-of-truth pattern** (`brandbook/README.md` lines 7-18):

```markdown
| Path | What |
|---|---|
| `tokens/tokens.json` | **Source of truth**: raw palette, semantic roles (light + dark), type scale, spacing, radii, focus, motion, and the WCAG contrast-pair declarations |
| `tokens/tokens.css` | Generated custom properties (`--rindle-*`) — never edit by hand |
| `src/` | Generation pipeline (Node, zero system deps beyond the repo's existing Playwright install) |
```

**Motion token pattern** (`brandbook/tokens/tokens.css` lines 114-125):

```css
/* borders, shadow, focus, motion */
--rindle-border-subtle: 1px solid #D9E0DA;
--rindle-border-strong: 1px solid #75847B;
--rindle-shadow-card: 0 1px 2px rgba(16, 20, 23, 0.06), 0 8px 24px rgba(16, 20, 23, 0.06);
--rindle-focus-width: 2px;
--rindle-focus-offset: 2px;
--rindle-motion-press: 120ms;
--rindle-motion-popover: 160ms;
--rindle-motion-toast: 200ms;
--rindle-motion-transition: 300ms;
--rindle-motion-diagram: 600ms;
--rindle-motion-easing: cubic-bezier(0.2, 0, 0, 1);
```

**Event feedback pattern** (`lib/rindle/live_view.ex` lines 37-44):

```elixir
def handle_info({:rindle_event, type, payload}, socket) do
  case type do
    :variant_started -> {:noreply, assign(socket, :variant_status, payload.state)}
    :variant_progress -> {:noreply, assign(socket, :variant_progress, payload.progress)}
    :variant_ready -> {:noreply, assign(socket, :variant_status, payload.state)}
    :variant_failed -> {:noreply, assign(socket, :variant_error, payload)}
    :variant_cancelled -> {:noreply, assign(socket, :variant_status, payload.state)}
  end
end
```

Use this event list to define operational motion: immediate press feedback, materialization of popovers/drawers/toasts, live status continuity, and no decorative animation.

### `guides/docker_demo_dx.md` (documentation, config/file-I/O)

**Analog:** `guides/release_publish.md`, with current Docker baseline from `docker/compose.cohort-demo.yml`, `docker/Dockerfile.cohort-demo`, and `scripts/demo/up.sh`.

**Runbook contract pattern** (`guides/release_publish.md` lines 3-16):

```markdown
## TL;DR

- Merge the Release Please PR on `main`.
- Wait for `ci.yml` to finish green on the exact release SHA.
- Let the `Release` workflow run `Run release preflight`, `Verify version alignment`, and `Check whether Hex.pm release already exists`.
- If the version is already live, recovery reruns skip publish and continue to public verification.
- Use `mix hex.publish --revert VERSION` for in-window rollback; use retire plus a fix release after the window.
```

Copy this runbook style: first a short operator checklist, then contracts, recovery, footguns, and architecture note.

**Current fixed-port baseline to call out** (`docker/compose.cohort-demo.yml` lines 1, 25-27, 72-79):

```yaml
name: cohort-demo

ports:
  - "9000:9000"
  - "9001:9001"

ports:
  - "4102:4102"
environment:
  MIX_ENV: prod
  COHORT_DEMO_DOCKER: "1"
  PHX_SERVER: "true"
  PORT: "4102"
  PHX_HOST: localhost
```

**Current cache-hostile Dockerfile baseline** (`docker/Dockerfile.cohort-demo` lines 14-26):

```dockerfile
WORKDIR /app

COPY . /app

WORKDIR /app/examples/adoption_demo

ENV MIX_ENV=prod

RUN mix local.hex --force \
  && mix local.rebar --force \
  && mix deps.get \
  && mix assets.vendor \
  && mix compile
```

**Launch wrapper baseline** (`scripts/demo/up.sh` lines 1-6):

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec docker compose -f "${repo_root}/docker/compose.cohort-demo.yml" up --build "$@"
```

The doc should lock env-driven ports, project namespacing, conflict guidance, better layer caching, URL map output, and no Traefik unless later demand creates a real multi-host routing need.

### `guides/rindle_admin_css.md` (documentation, transform)

**Analog:** `brandbook/README.md`, `brandbook/src/tokens-build.mjs`, `brandbook/src/contrast.mjs`, and `brandbook/tokens/tokens.css`.

**Generation command pattern** (`brandbook/README.md` lines 19-30):

````markdown
## Regenerating assets

```sh
cd brandbook/src
npm install               # opentype.js only
node tokens-build.mjs     # tokens.json -> tokens.css (with parity check)
node contrast.mjs         # WCAG AA gate over all declared pairs (exits 1 on failure)
node logo.mjs             # final logo SVGs from the locked geometry
node render-derived.mjs   # favicon-16/32.png + avatar-512.png (Playwright)
magick ../assets/logo/favicon-32.png ../assets/logo/favicon-16.png ../assets/logo/favicon.ico
node check.mjs            # constraint + size-budget gates (exits 1 on violation)
```
````

Use the same command-first structure for future `rindle-admin` CSS generation and validation.

**CSS transform pattern** (`brandbook/src/tokens-build.mjs` lines 18-24, 34-41, 44-56):

```javascript
let css = `/* generated by brandbook/src/tokens-build.mjs from tokens.json - do not edit by hand */

:root {
`;
for (const [k, v] of Object.entries(raw)) css += `  --rindle-${k}: ${v};\n`;
css += '\n  /* semantic roles (light) */\n';
for (const [k, v] of Object.entries(T.color.semantic.light)) css += `  --rindle-${k}: ${deref(v)};\n`;

css += '\n  /* borders, shadow, focus, motion */\n';
for (const [k, v] of Object.entries(T.border)) if (typeof v === 'string') css += `  --rindle-border-${k}: ${deref(v)};\n`;
css += `  --rindle-shadow-card: ${T.shadow.card};\n`;
css += `  --rindle-focus-width: ${T.focus.width};\n  --rindle-focus-offset: ${T.focus.offset};\n`;
for (const [k, v] of Object.entries(T.motion)) {
  if (k === 'rules') continue;
  css += `  --rindle-motion-${k}: ${v};\n`;
}

/* dark mode: opt-in via [data-theme="dark"], or automatic via media query on
   [data-theme="auto"] scopes */
[data-theme="dark"] {
`;
for (const [k, v] of Object.entries(T.color.semantic.dark)) css += `  --rindle-${k}: ${deref(v)};\n`;
css += `}

@media (prefers-color-scheme: dark) {
  [data-theme="auto"] {
`;
```

**Contrast gate pattern** (`brandbook/src/contrast.mjs` lines 26-42):

```javascript
let failures = 0;
const rows = [];
for (const p of T.contrast_pairs) {
  const fg = raw[p.fg], bg = raw[p.bg];
  if (!fg || !bg) {
    rows.push(`?? ${p.fg} on ${p.bg}: unknown token`);
    failures++;
    continue;
  }
  const r = ratio(fg, bg);
  const ok = r >= p.min;
  if (!ok) failures++;
  rows.push(`${ok ? 'PASS' : 'FAIL'}  ${r.toFixed(2).padStart(6)} >= ${p.min}  ${p.fg} on ${p.bg}  (${p.context})`);
}
console.log(rows.join('\n'));
console.log(`\n${T.contrast_pairs.length - failures}/${T.contrast_pairs.length} pairs pass`);
if (failures) process.exit(1);
```

**Theme output pattern** (`brandbook/tokens/tokens.css` lines 128-156):

```css
/* dark mode: opt-in via [data-theme="dark"], or automatic via media query on
   [data-theme="auto"] scopes */
[data-theme="dark"] {
  --rindle-surface: #0E1316;
  --rindle-surface-raised: #161E23;
  --rindle-surface-sunken: #101417;
  --rindle-text: #F1F7F3;
}

@media (prefers-color-scheme: dark) {
  [data-theme="auto"] {
    --rindle-surface: #0E1316;
```

The CSS ADR should lock vanilla `rindle-admin` CSS, BEM class names, CSS custom properties, `data-theme="light|dark|auto"`, status chips with text/icon/color pairs, and no host Tailwind/esbuild requirement.

### `guides/ui_principles.md` (documentation, config/process)

**Analog:** `brandbook/README.md`, `examples/adoption_demo/AGENTS.md`, and `guides/operations.md`.

**Hard-rules pattern** (`brandbook/README.md` lines 35-44):

```markdown
## Hard rules (enforced by `src/check.mjs` + `src/contrast.mjs`)

- No background/container shapes on any mark; no `<text>` elements (type is outlined);
  no embedded rasters or external references in SVGs.
- The primary lockup never carries the tagline (`rindle-logo-subtitle.svg` is the only
  variant that does).
- Every declared color pair meets WCAG AA (4.5:1 text, 3:1 non-text). Rindle Green and
  Rind Lime are accent-only on light surfaces. Focus rings: Deep Current on light,
  Rindle Green on dark.
- `brandbook/` total ≤ 1.5 MB; SVGs ≤ 8 KB (subtitle/sheet ≤ 16 KB).
```

Copy this style for PRIN-01: clear, enforceable UI rules tied to scripts, screenshots, E2E determinism, a11y, design tokens, motion constraints, and polish checks.

**LiveView testing/process pattern** (`examples/adoption_demo/AGENTS.md` lines 344-352):

```markdown
### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
```

For `guides/ui_principles.md`, adapt this into deterministic E2E/screenshot guidance: stable selectors, explicit states, seeded data, no text-only assertions where stateful selectors are better, and screenshot polish loop before completion.

**Escalation pattern** (`guides/operations.md` lines 353-369):

```markdown
## When to Escalate

The Mix tasks handle routine maintenance. The following situations are
not what these tasks are for, and need direct database / storage
intervention:

- A `quarantined` asset that legitimately needs to be unquarantined
  (manual DB update; document the audit trail).
- A `failed` variant whose underlying source is corrupt — fix the source, then
  use `Rindle.requeue_variants/2` for that asset or `mix rindle.regenerate_variants`
  if the issue is broad preset/profile drift.
```

Use this for "when UI work must stop and escalate" cases: public API shape, auth semantics, dependency footprint, destructive actions, and milestone scope.

### `AGENTS.md` (config, process)

**Analog:** `AGENTS.md`.

**Existing repo workflow pattern** (`AGENTS.md` lines 46-59):

```markdown
## Repository workflow

**Contributors:** follow [`guides/release_publish.md`](guides/release_publish.md) and [`RUNNING.md`](RUNNING.md) for CI lanes and release gates. When **`.planning/`** is present, it holds milestone context for maintainers.

**Automated coding agents:** honor the constraints in this file; keep edits focused, run the checks **RUNNING.md** names for your change, and update **`.planning/PROJECT.md`** when you intentionally change product scope or shipped claims.

Agents should default to the repo's **green-main release train** posture:

- keep `main` green on merge-blocking CI jobs (Quality/coveralls, Integration, Proof, Package Consumer, Adopter)
- prefer **PR-first** execution for serious milestone or feature-depth work (see [`.planning/DEVELOPMENT-TRAIN.md`](.planning/DEVELOPMENT-TRAIN.md))
- avoid speculative milestone reopening during `demand-gated-pause` unless LIFE-06 or STREAM-10 signal exists
- when the release train is idle and there is no approved work item, say so plainly instead of inventing work (**silence on the wire** — see [`.planning/RELEASE-TRAIN.md`](.planning/RELEASE-TRAIN.md))
```

Add the UI-principles link in this section, near the existing `guides/release_publish.md` and `RUNNING.md` guidance. Keep the update scoped to a link and one sentence; do not rewrite model-routing notes.

## Shared Patterns

### Documentation Tone And Structure

**Source:** `guides/user_flows.md`, `guides/operations.md`, `guides/secure_delivery.md`
**Apply to:** All six new `guides/*.md` files

- Open with the decision/posture, not a history lesson.
- Use task/job tables when the reader is choosing a path.
- Keep canonical implementation details linked to source modules instead of duplicating mutable contracts.
- Include "what not to do" and escalation boundaries where drift is likely.

### Optional Dependency Boundary

**Source:** `mix.exs` lines 64-74; `lib/rindle/live_view.ex` lines 1-2; `lib/rindle/config.ex` lines 70-74
**Apply to:** `guides/admin_console_architecture.md`, `guides/ui_principles.md`

```elixir
if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.LiveView do
```

Console docs must require compile gates for Phoenix/LiveView references and preserve non-console adopter dependency cost.

### Admin Read Boundary

**Source:** `lib/rindle/ops/runtime_status.ex` lines 36-58; `guides/operations.md` lines 30-48
**Apply to:** `guides/admin_console_architecture.md`, `guides/admin_console_ia.md`

Reads should be documented as future `Rindle.Admin.Queries` over existing ops/domain truth. Do not plan public facade convenience APIs for console reads.

### Token And Contrast Governance

**Source:** `brandbook/README.md` lines 7-18, 35-44; `brandbook/src/tokens-build.mjs` lines 18-59; `brandbook/src/contrast.mjs` lines 26-42
**Apply to:** `guides/rindle_admin_css.md`, `guides/admin_console_motion.md`, `guides/ui_principles.md`

Token JSON is source of truth, generated CSS is an artifact, and contrast is mechanically gated. Docs should avoid hard-coded one-off values except as examples copied from generated output.

### Docker DX Baseline

**Source:** `docker/compose.cohort-demo.yml` lines 1, 25-27, 72-79; `docker/Dockerfile.cohort-demo` lines 14-26; `scripts/demo/up.sh` lines 1-6
**Apply to:** `guides/docker_demo_dx.md`

The doc should name current fixed ports and whole-repo-before-deps copy order as the baseline to replace in Phase 87, while preserving the simple wrapper-script entry point.

### ExDoc And Package Awareness

**Source:** `mix.exs` lines 121-148, 237-244
**Apply to:** Planner decisions around whether Phase 86 docs are public HexDocs extras now or only repo guides until Phase 93

```elixir
extras: [
  "README.md",
  "RUNNING.md",
  "guides/user_flows.md",
  ...
  "guides/release_publish.md"
],
groups_for_extras: [
  Guides: ~r/guides\/(?!release_publish).*\.md$/,
  Maintainer: ~r/guides\/release_publish\.md$/
],
files: ~w(lib priv/repo/migrations mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)
```

Research leaves exact public-doc exposure as an open planner choice. If `mix.exs` extras are changed, use the existing extras/grouping pattern.

## No Analog Found

All planned files have usable analogs. No file should rely only on external research patterns.

## Metadata

**Analog search scope:** `guides/`, `brandbook/`, `lib/rindle/`, `lib/mix/tasks/`, `docker/`, `scripts/demo/`, `examples/adoption_demo/`, `AGENTS.md`, `mix.exs`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`

**Files scanned:** 80+ paths via `rg --files`, `find`, and targeted `rg`

**Pattern extraction date:** 2026-06-11

**Project skill context:** `.codex/skills/gsd-milestone-next-step/SKILL.md` was read. It reinforces the adopter-first Phoenix/Elixir OSS-library lens, but no extra rule files were needed for this pattern map.
