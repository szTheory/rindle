# Demo Docker DX template

A copy-pasteable Docker setup for a Phoenix lib demo that **coexists with sibling lib
demos** (no port juggling), **rebuilds fast** (style edits don't recompile deps), prints a
**copy-paste URL map**, and offers **opt-in Traefik** hostnames. Extracted from Rindle's
Cohort demo (`docker/compose.cohort-demo.yml`, `docker/Dockerfile.cohort-demo`,
`scripts/demo/`). See the user-facing guide: `guides/docker_demo_dx.md`.

## What's here

| File | Copy to | Purpose |
|------|---------|---------|
| `Dockerfile.__app__` | `docker/Dockerfile.<app>` | Cached layering (deps compiled before source copy) |
| `compose.__app__.yml` | `docker/compose.<app>.yml` | app + Postgres + MinIO, loopback ports, env defaults |
| `compose.__app__.traefik.yml` | `docker/compose.<app>.traefik.yml` | opt-in `proxy`-network overlay |
| `scripts/up.sh` `down.sh` `reset.sh` | `scripts/demo/` | launcher with free-port detection + URL map + Traefik opt-in |

## Rename checklist

Replace these tokens throughout (pick values for your lib):

| Token | Meaning | Example |
|-------|---------|---------|
| `__APP__` | lowercase project + Traefik hostname base | `cohort` |
| `__APP_ENV__` | uppercase env-var prefix | `COHORT` |
| `__APP_PORT__` | preferred app port | `4102` |
| `__MINIO_PORT__` | preferred MinIO API port | `9000` |
| `__MINIO_CONSOLE_PORT__` | preferred MinIO console port | `9001` |
| `__DOCKERFILE__` | dockerfile path used by compose | `docker/Dockerfile.cohort-demo` |
| `__DEMO_ENTRYPOINT__` | entrypoint script copied into the image | `docker/cohort-demo-entrypoint.sh` |

One-shot (from repo root, after copying + renaming files):

```bash
grep -rl '__APP__\|__APP_ENV__\|__APP_PORT__\|__MINIO' docker scripts/demo \
  | xargs sed -i '' \
    -e 's/__APP_ENV__/COHORT/g' -e 's/__APP__/cohort/g' \
    -e 's/__APP_PORT__/4102/g' -e 's/__MINIO_PORT__/9000/g' -e 's/__MINIO_CONSOLE_PORT__/9001/g'
# (GNU sed: drop the '' after -i)
```

After renaming, the env vars become `COHORT_PORT`, `COHORT_MINIO_PORT`,
`COHORT_MINIO_CONSOLE_PORT`, `COHORT_USE_TRAEFIK`, `COHORT_TRAEFIK_HOST`. `chmod +x` the scripts.

## Contracts to preserve (these are the value)

**1. Layer caching.** Keep the order: copy `mix.exs`/`mix.lock` + `config/` → `mix deps.get
&& mix deps.compile` (in one cached `RUN`) → `COPY . .` → `mix compile`. Your
`.dockerignore` MUST exclude `**/deps` and `**/_build` so the source copy can't clobber
compiled artifacts. Only mount the *download* caches (`/root/.hex`, rebar) — **never**
`/root/.mix` (the installed Hex/Rebar archives must persist into the image, or later layers'
`mix` can't resolve deps).

**2. Pin the image to your real toolchain.** Match `FROM hexpm/elixir:<elixir>-erlang-<otp>`
to what developers actually run (`.tool-versions`). A stale pin can pass prod builds but
break dev builds that use newer-Elixir syntax (Rindle hit exactly this: a 1.17 pin vs 1.19
regex syntax in `dev.exs`).

**3. Loopback + auto-free-port.** Publish every host port as `127.0.0.1:${VAR:-default}:...`.
`up.sh` auto-bumps off busy ports, and the chosen MinIO/S3 port flows into the presigned-URL
host so browser uploads keep working.

**4. Shared-Traefik coexistence.** The overlay joins the external `proxy` network and adds a
`Host(...)` router with **project-unique** router/service names. Rely on the proxy's
`exposedbydefault=false`. Keep the loopback port published too (proxy down ≠ locked out).
Do **not** route object storage through Traefik (presigned URLs use the published port).

**5. Admin/privileged UIs: previews are NOT prod.** If your demo mounts a privileged admin
UI unauthenticated for click-around, run the **preview as a dev/preview build**, never prod
(`MIX_ENV=dev` in the Dockerfile + compose). Hard-block unauthenticated privileged consoles
in prod and document the adopter-correct pattern (host auth via pipeline/`on_mount`). This
mirrors the Elixir/ecosystem norm (LiveDashboard, Oban Web, Rails web-console): gate by
environment, never by a runtime override that can ship enabled. See Rindle's
`examples/adoption_demo/lib/adoption_demo_web/router.ex` for the preview-vs-prod contrast.

**6. Security boundary.** Loopback-only, throwaway credentials, dev-only MinIO console.
Never present the preview as a deployment path.
