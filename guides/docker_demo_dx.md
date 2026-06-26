# Running the Cohort demo in Docker

**Who this is for:** you want to see Rindle working — uploads, transcoding, the admin
console — without installing Elixir, FFmpeg, and libvips on your machine, and **without it
fighting the other dockerized apps you already run**.

## Game plan (30 seconds)

```bash
./scripts/demo/up.sh        # build + start everything, prints your URLs
# ... poke around ...
./scripts/demo/down.sh      # stop
./scripts/demo/reset.sh     # stop + wipe db/storage (fresh seeds next start)
```

- **Ports never collide.** `up.sh` auto-picks free loopback ports, so it coexists with a
  native MinIO, sibling lib demos, or anything else already bound. You don't manage ports.
- **It prints the exact URLs** to copy-paste after launch (app, admin console, MinIO).
- **Rebuilds are fast.** Editing templates/CSS recompiles only the app, not the whole
  dependency graph.
- **Pretty hostnames, automatically.** If you already run a shared Traefik dev proxy on the
  `proxy` network, `up.sh` detects it and serves the demo at `http://cohort.localhost` — no
  flag. `COHORT_USE_TRAEFIK=0 ./scripts/demo/up.sh` opts back out to pure loopback.

That's the whole thing. The rest of this guide is for when you want to understand *why*, or
something doesn't come up.

---

## Quick start

From the **repository root** (requires Docker Desktop or Docker Engine + Compose):

```bash
./scripts/demo/up.sh
```

First build takes a few minutes (it installs FFmpeg/libvips and compiles deps once);
subsequent starts are fast. When it's ready, the launch output prints a copy-paste URL map:

```
app
http://localhost:4102
admin console
http://localhost:4102/admin/rindle
MinIO console
http://localhost:9001
```

If a default port was busy, the printed numbers reflect the **actual** ports chosen — trust
the output, not the defaults.

---

## Port conflicts & coexistence

You run several batteries-included lib demos at once. Here's how the demo stays out of their
way, from most to least automatic.

### 1. Automatic free-port selection (default — nothing to do)

`up.sh` checks each loopback port and rolls forward to the next free one:

| Service | Preferred | Picks next free if busy |
| --- | --- | --- |
| Cohort app | `4102` | `4103`, `4104`, … |
| MinIO API | `9000` | `9001`, … |
| MinIO console | `9001` | `9002`, … |

The chosen MinIO API port flows into both the published port *and* the browser-facing presigned
URLs (signed for `localhost:<port>` — see "Split-horizon S3 endpoint" below), so uploads and
image loads keep working at whatever port was picked. The printed URL map is always correct.

### 2. Pin a port yourself

Set any of these and `up.sh` uses your value verbatim (no auto-bump):

```bash
COHORT_DEMO_PORT=4212 COHORT_MINIO_PORT=9200 COHORT_MINIO_CONSOLE_PORT=9201 ./scripts/demo/up.sh
```

### 3. Run a second, fully separate stack

`COMPOSE_PROJECT_NAME` gives you isolated containers, networks, and volumes:

```bash
COMPOSE_PROJECT_NAME=rindle-cohort-alt ./scripts/demo/up.sh
```

### 4. Pretty hostnames via shared Traefik (automatic)

If you already run a shared Traefik dev proxy on the external `proxy` network (label-routing,
`exposedbydefault=false`, a `web` entrypoint on `:80`), **`up.sh` detects it and routes through
it automatically** — no flag needed:

```bash
./scripts/demo/up.sh                               # proxy present → http://cohort.localhost
COHORT_TRAEFIK_HOST=demo.localhost ./scripts/demo/up.sh   # custom host
COHORT_USE_TRAEFIK=0 ./scripts/demo/up.sh          # force pure loopback, ignore the proxy
COHORT_USE_TRAEFIK=1 ./scripts/demo/up.sh          # force on (warns if proxy is absent)
```

`COHORT_USE_TRAEFIK` is tri-state: **unset** = auto (on iff the `proxy` network exists),
`1` = force on, `0` = force off. When Traefik is active the launch output lists both the
`cohort.localhost` URL and the direct loopback URL. The app's loopback port stays published
either way, so a stopped proxy never locks you out; if the `proxy` network isn't present, auto
mode silently falls back to fixed ports (and `=1` warns).

**Coexistence contract** (so sibling demos don't fight one proxy): each demo joins the same
external `proxy` network, keeps its Traefik **router/service names unique**, and relies on
`exposedbydefault=false` so only labelled services route. MinIO is deliberately *not* proxied
— browser-facing presigned URLs embed `localhost:<port>` (see below), which the browser reaches
via the published host port directly, not the proxy.

---

## Split-horizon S3 endpoint (why images load on macOS)

MinIO has two callers with different network views, so the demo gives it two endpoints:

| Caller | Endpoint | Why |
| --- | --- | --- |
| App container (server-side store/probe/transcode) | `http://minio:9000` (`RINDLE_MINIO_URL`) | In-network compose DNS — always reachable from the app container on macOS, Windows, and Linux CI. |
| Your browser (presigned image + upload URLs) | `http://localhost:<published-port>` (`RINDLE_MINIO_PUBLIC_URL`) | The host can resolve `localhost`; it **cannot** resolve `host.docker.internal` (Docker injects that alias into *containers*, not the host). |

The app signs browser-facing presigned URLs for the public endpoint via the S3 adapter's
`:public_endpoint` config (`config :rindle, Rindle.Storage.S3, public_endpoint: [...]`), wired in
`config/runtime.exs` from `RINDLE_MINIO_PUBLIC_URL`. The S3 signature binds the `host` header, so
the signed host must be exactly what the browser requests — which is why a single shared endpoint
can't satisfy both sides, and why a broken image here means a presign-host mismatch, not a
corrupt/quarantined asset.

---

## When it doesn't come up

**Symptom: the page won't load and `docker ps` shows the app container exited (code 255).**

This is almost always a **dependency port collision** at startup: the bundled MinIO or
Postgres couldn't bind its port, its healthcheck never passed, and the app — which waits for
them — exited before Phoenix started. The classic case is a **native MinIO already holding
`:9000`**.

Diagnose and fix:

```bash
docker compose -f docker/compose.cohort-demo.yml logs        # read the failing service
lsof -nP -iTCP@127.0.0.1 -sTCP:LISTEN | grep -E '4102|9000|9001'   # what's holding the port
./scripts/demo/down.sh && ./scripts/demo/up.sh               # restart — auto-port-pick handles it
```

With automatic free-port selection, a fresh `up.sh` sidesteps the native-MinIO-on-9000
collision on its own. If you'd pinned a port to something busy, unpin it or choose a free one.

**Other recovery:**

- Stale containers from an old run colliding → `./scripts/demo/down.sh` (add `-v` via
  `reset.sh` to also wipe volumes), or use a fresh `COMPOSE_PROJECT_NAME`.
- Dependencies re-downloading/recompiling on every small edit → the Dockerfile layer order
  regressed (see below).

---

## Why rebuilds are fast (Dockerfile layering)

`docker/Dockerfile.cohort-demo` copies only `mix.exs`/`mix.lock` + `config/` first, then runs
`mix deps.get && mix deps.compile` in a **cached layer**, and only afterward copies the full
source. Because `.dockerignore` excludes `deps/` and `_build/`, copying the source can't clobber
those compiled artifacts. Net effect:

- Edit a template or stylesheet → only `mix compile` (app) re-runs. Hex deps are **not**
  re-downloaded or recompiled.
- Bump `mix.lock` → the dependency layer rebuilds (BuildKit cache mounts keep the Hex/Rebar
  download caches warm so it's still quick).
- Change the `rindle` library itself → `rindle` recompiles (expected — it's the lib under test).

`up.sh` exports `DOCKER_BUILDKIT=1` so the cache mounts engage.

---

## Security boundary

This is a **local preview**, not a deployment path. All ports bind to `127.0.0.1` (loopback),
the MinIO console is dev-only tooling, and the secret/credentials in the compose file are
throwaway placeholders. Don't expose any of it publicly.

---

## Reuse this setup in another lib

The same pattern (auto free ports, URL map, auto-detected Traefik, cached Dockerfile) is packaged as
a copy-pasteable template at [`docker/dx-template/`](../docker/dx-template/TEMPLATE.md) — see
its `TEMPLATE.md` for the rename checklist and the shared-Traefik contract.

---

## Native path (hot reload, Playwright E2E)

For hot-reload development, skip Docker and run natively — see
[`examples/adoption_demo/README.md`](../examples/adoption_demo/README.md).
