# Admin Console Architecture

Rindle Admin is a **host-authenticated, library-owned** console. The host app owns the
browser pipeline, auth pipeline, and LiveView `:on_mount` hook; Rindle owns the console
routes, query boundary, and self-contained static assets.

This guide covers:

- The recommended `Rindle.Admin.Router.rindle_admin/2` router macro shape
- Safe mounting, auth ownership, and the production refusal rule
- Library-owned static assets served with `Plug.Static`
- CSP nonce, LiveView socket, transport, route-helper, logo, and home-path options
- Optional `phoenix_live_view` dependency safety
- The `Rindle.Admin.Queries` read boundary

Phase 86 locks architecture only. Console modules, assets, routes, and CI matrix proof
are implemented in later phases.

## Router Macro

Downstream implementation should expose the mount surface as
`Rindle.Admin.Router.rindle_admin/2`, following Phoenix LiveDashboard and Oban Web prior
art: a host calls the macro from an authenticated router scope, and the macro expands to
direct LiveView routes rather than a `forward`-only plug.

```elixir
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

The recommended public shape is `Rindle.Admin.Router.rindle_admin/2`. Exact internal
module layout remains a Phase 89 implementation decision.

## Safe Mount Contract

The host app owns:

- browser pipeline selection
- auth pipeline selection
- LiveView `:on_mount` session/user checks
- route scope placement
- actor/current-user assigns

Rindle must refuse unsafe unauthenticated mounts in production by default. Unsafe
unauthenticated mounts are any production mount where the host has not supplied an auth
pipeline or equivalent `:on_mount` guard acknowledgement.

Development and test need a narrow dev/test-only escape-hatch policy for examples,
preview apps, and CI proofs. The exact public option name is intentionally not locked in
Phase 86 because that name is part of the auth/security API shape and belongs to Phase 89.

Do not mount the console under a plain `pipe_through :browser` production scope unless
the host has an explicit, reviewed auth mechanism.

## Route Options

The router macro should reserve these option concepts:

| Option | Purpose |
| --- | --- |
| `:on_mount` | Host-owned LiveView session/auth verification. |
| `:as` | LiveDashboard/Oban-style route-helper prefix. |
| `:home_path` | Destination for the default Rindle logo and Home link. |
| `:live_socket_path` | Host socket path when it differs from `/live`. |
| `:transport` | Host transport override when needed. |
| `:csp_nonce_assign_key` | Assign keys used to apply CSP nonces to console assets. |

Logo behavior is locked at the option-category level. The default Rindle logo links to
`:home_path`; host replacement or hiding of the logo is allowed as an implementation-phase
option category. Exact logo option names remain deferred to Phase 89.

## Static Assets

Rindle owns the console CSS and JavaScript. The shipped console must not require host Tailwind,
host esbuild, or host asset-pipeline integration.

Future implementation should serve namespaced files from the `:rindle` OTP app with
`Plug.Static`, for example:

```elixir
plug Plug.Static,
  at: "/rindle-admin/assets",
  from: {:rindle, "priv/static/rindle_admin"},
  only: ~w(rindle-admin.css rindle-admin.js logo.svg favicon.svg)
```

The host provides routing, auth, and socket integration. The host does not compile the
library console styles.

## CSP And Socket Boundary

The console must work in strict host CSP environments. The mount contract therefore keeps
`:csp_nonce_assign_key` explicit and uses host-provided nonce assigns rather than inventing
a Rindle nonce generator.

`:live_socket_path` and `:transport` stay explicit because host apps can customize
LiveView socket paths and transports. Phase 89 should mirror the prior-art option style
rather than hard-code a single socket assumption.

## Optional Dependency Matrix

`phoenix_live_view` remains optional. Non-console adopters must keep the current zero-cost
posture.

| Install shape | Expected behavior |
| --- | --- |
| Default install without `phoenix_live_view` | Rindle compiles; admin modules compile away cleanly. |
| Install with `phoenix_live_view` | `Rindle.Admin.Router.rindle_admin/2` and console LiveViews compile. |
| Cohort host with LiveView | Demo can mount the console inside host auth routes. |
| CI no-LiveView proof | ADMIN-06 proves no unguarded Phoenix/LiveView aliases leak. |

Any module that aliases Phoenix or LiveView APIs must live behind `Code.ensure_loaded?/1`
gates before Phoenix/LiveView aliases are expanded. The existing `Rindle.LiveView` pattern
is the source pattern.

## Admin Read Boundary

Console reads belong in `Rindle.Admin.Queries`. They should compose existing domain,
runtime, and repair truth over the configured repo, including `Rindle.Ops.RuntimeStatus`.

Do not promote admin convenience reads to `lib/rindle.ex`. The only new public surface
permitted by the v1.18 charter is the mountable console boundary; read helpers stay behind
`Rindle.Admin.Queries`.

## What Not To Build In Phase 86

- No console LiveView modules
- No asset-serving plug
- No generated CSS or JavaScript
- No public `Rindle` facade convenience reads
- No exact dev/test escape-hatch option name
- No logo option names beyond the replacement/hiding category

## Downstream Constraints

- Phase 89 implements the macro, safe mount check, asset serving, CSP/socket options, and
  optional dependency matrix.
- Phase 89 keeps reads in `Rindle.Admin.Queries`.
- Phase 90 action screens call existing facade/ops capabilities; they do not add new
  lifecycle semantics.
- Phase 93 updates public docs/facade truth after the console actually ships.
