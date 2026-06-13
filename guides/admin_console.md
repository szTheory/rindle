# Admin Console

Rindle ships a **mountable, host-authenticated admin console** in the `rindle`
package — `Rindle.Admin.Router.rindle_admin/2`. It is the operator UI for the
media lifecycle: assets, upload sessions, variants/jobs, runtime health, and a
small set of destructive and repair actions. The console follows the
LiveDashboard / Oban Web pattern: you call one macro from an authenticated
router scope and it expands to direct LiveView routes inside a `live_session`.

> Adopters who do not want the console pay nothing. `phoenix_live_view` is an
> optional dependency; without it the console modules compile away cleanly and
> Rindle keeps its zero-cost posture. The console is the only new public surface
> in this milestone — it reuses existing lifecycle facade verbs and adds no new
> lifecycle semantics.

This guide covers:

- What the console is, and when to mount it
- The optional `phoenix_live_view` dependency
- Mounting with `Rindle.Admin.Router.rindle_admin/2`
- Authentication and the production refusal rule
- The eight console pages
- Operator actions (destructive UX, typed confirmation, reused facade verbs)
- Self-contained assets and CSP / socket options
- Optional-dependency compile-away behavior
- Trying it locally via the Cohort demo at `/admin/rindle`

## 1. What It Is, And When To Mount It

Rindle Admin is **host-authenticated and library-owned**. The host application
owns the browser pipeline, the auth pipeline, the LiveView `:on_mount` hooks,
the route scope, and the current-user / actor assigns. Rindle owns only the
console route expansion, the read query boundary, and the self-contained static
assets. There is no Rindle-managed login, no Rindle-owned session, and no
bypass of your existing authorization — the console is exactly as protected as
the router scope you mount it inside.

Mount it when you want an in-app operator view of Rindle's lifecycle state and a
guarded surface for owner erasure, variant regeneration, and lifecycle repair.
You do not need it for normal media flows; the public `Rindle` facade and the
`mix rindle.*` tasks remain the canonical programmatic and CLI surfaces.

## 2. Add The Optional Dependency

The console renders with Phoenix LiveView. Add `phoenix_live_view` to your host
application if it is not already present:

```elixir
# mix.exs
defp deps do
  [
    # ... your existing deps ...
    {:rindle, "~> 0.3"},
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```

`phoenix_live_view` is optional from Rindle's perspective: the admin router and
LiveViews are guarded behind `Code.ensure_loaded?/1` on
`Phoenix.LiveView`, `Phoenix.Router`, and `Plug.Static`. If those are not
available, the admin modules are not defined and Rindle still compiles — see
[section 8](#8-optional-dependency-behavior).

## 3. Mount The Console

Call `Rindle.Admin.Router.rindle_admin/2` from an authenticated `scope` in your
host router. The macro expands to direct LiveView routes (not a `forward`-only
plug), so it must be called inside `scope`, after a `pipe_through` that applies
your browser and auth pipelines.

```elixir
# lib/my_app_web/router.ex
scope "/admin", MyAppWeb do
  pipe_through [:browser, :require_admin]

  rindle_admin "/rindle",
    on_mount: [MyAppWeb.AdminLiveAuth],
    as: :rindle_admin,
    home_path: "/admin",
    live_socket_path: "/live",
    transport: "websocket",
    csp_nonce_assign_key: %{
      img: :img_csp_nonce,
      style: :style_csp_nonce,
      script: :script_csp_nonce
    }
end
```

This mounts the console at `/admin/rindle`. The `:require_admin` plug and the
`MyAppWeb.AdminLiveAuth` `:on_mount` hook are yours — Rindle does not provide
them, and that is intentional.

## 4. Authentication And The Production Refusal Rule

The host owns auth. To make misconfiguration loud rather than silent, the macro
**refuses to mount an unguarded console in production**. A production mount must
supply one of:

- a non-empty `:on_mount` list (your LiveView session/auth verification), or
- an explicit `auth_guarded?: true` acknowledgement (you assert the surrounding
  pipeline already enforces auth).

If neither is present in `:prod`, the macro raises at compile time with a clear
message rather than booting an unauthenticated privileged console.

There is a dev/test escape hatch, `allow_unauthenticated?: true`, for examples,
CI fixtures, and local previews. It is **rejected in production** — passing it
in `:prod` raises. Treat it as a convenience for the Cohort demo and your own
local exploration, never as a deployment posture.

In short: do not deploy the console under a bare `pipe_through :browser` scope
with no `:on_mount` guard and no `auth_guarded?: true`. Production will not let
you.

## 5. Pages

The mount expands to eight routes, relative to the mount path (`/admin/rindle`
in the example above):

| Route | LiveView | Purpose |
| --- | --- | --- |
| `/` | `HomeLive` | Console home / lifecycle overview |
| `/assets` | `AssetsLive` (index) | Browse media assets |
| `/assets/:id` | `AssetsLive` (show) | Asset detail, variants, attachments |
| `/upload-sessions` | `UploadSessionsLive` (index) | Upload sessions list |
| `/upload-sessions/:id` | `UploadSessionsLive` (show) | Upload session detail |
| `/variants-jobs` | `VariantsJobsLive` | Variant state and job/processing context |
| `/runtime-doctor` | `RuntimeDoctorLive` | Runtime health / doctor surface |
| `/actions` | `ActionsLive` | Operator actions hub (see below) |

Live updates reuse `Rindle.PubSub` and the existing `:asset` / `:variant` /
`:upload_session` topics, so lifecycle changes reflect in the console without a
console-specific realtime channel. The reads behind these pages are composed
internally and are not part of the public `Rindle` facade — they are an
implementation detail of the console, not an adopter entrypoint.

## 6. Operator Actions

The `/actions` hub exposes a small set of guarded operations. Destructive
actions require a **typed confirmation** (you type an explicit token before the
action executes), and every action reuses an existing public facade or ops verb
— the console adds no new lifecycle semantics:

- **Owner erasure** — preview and execute single-owner erasure via the v1.10
  owner-erasure facade, gated behind a typed `ERASE type:id` confirmation.
- **Batch owner erasure** — typed `ERASE N OWNERS` confirmation, with
  per-owner partial-failure receipts.
- **Lifecycle repair** — `Rindle.reprobe/1` and `Rindle.requeue_variants/2`.
- **Variant regeneration** — re-derive variants through existing facade verbs.
- **Quarantine triage** — read-only review of quarantined/problem rows.

The console never invents a new deletion or lifecycle path. It is a UI over the
same supported surfaces you would call from code or `mix rindle.*` tasks.

## 7. Assets, CSP, And Socket Options

The console is **self-contained**: Rindle serves its own CSS and JavaScript from
the `:rindle` OTP app's `priv/static/rindle_admin/` directory through a small
static plug. There is **no host Tailwind, esbuild, or asset-pipeline
requirement** — you do not compile the library's styles. Only an allowlist of
files is served (`rindle-admin.css`, `rindle-admin.js`, `logo.svg`,
`favicon.svg`); `tokens.json` is explicitly denied.

For strict-CSP hosts, the mount keeps these options explicit:

| Option | Purpose |
| --- | --- |
| `:on_mount` | Host LiveView session/auth verification. |
| `:as` | Route-helper prefix (default `:rindle_admin`). |
| `:home_path` | Destination for the logo and Home link (default `"/"`). |
| `:live_socket_path` | Host LiveView socket path (default `"/live"`). |
| `:transport` | Socket transport (default `"websocket"`). |
| `:csp_nonce_assign_key` | Assign keys used to apply host CSP nonces to console assets. |
| `auth_guarded?` | Acknowledge host auth without an `:on_mount` list. |
| `allow_unauthenticated?` | Dev/test-only escape hatch; rejected in production. |

Rindle uses your CSP nonces via `:csp_nonce_assign_key` rather than inventing
its own nonce generator, so the console works inside a strict host CSP.

## 8. Optional-Dependency Behavior

`Rindle.Admin.Router` and the console LiveViews are wrapped in
`Code.ensure_loaded?/1` guards on `Phoenix.LiveView`, `Phoenix.Router`, and
`Plug.Static`. The practical effect:

| Install shape | Behavior |
| --- | --- |
| No `phoenix_live_view` | Admin modules are not defined; Rindle compiles normally. |
| With `phoenix_live_view` | `rindle_admin/2` and the console LiveViews are available. |

Non-console adopters keep the existing zero-cost posture — the console adds no
required runtime dependency.

## 9. Try It Locally (Cohort Demo)

The bundled Cohort adoption demo mounts the console so you can click around
before wiring your own auth. The demo router mounts it under an unauthenticated
preview scope:

```elixir
scope "/admin", CohortWeb do
  rindle_admin "/rindle", allow_unauthenticated?: true
end
```

That puts the console at **`/admin/rindle`** (demo port `4102`). The full
walkthrough — seeded assets, every lifecycle state, and the actions hub — lives
in `examples/adoption_demo/README.md`. Remember that `allow_unauthenticated?:
true` is a demo-only convenience: production requires real host auth as
described in [section 4](#4-authentication-and-the-production-refusal-rule).
