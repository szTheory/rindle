# Cohort — Rindle adoption demo

Course-and-community SaaS browser host for **human-realistic** Rindle adoption proof. Complements
ephemeral `install_smoke.sh` generated apps and in-repo `canonical_app` tests — it is **not** a
second product or public API surface.

## Quick try (Docker)

**Preview only** — spin up Postgres, MinIO, and the Cohort UI without installing Elixir, FFmpeg,
or libvips. From the **repository root** (requires Docker Desktop or Docker Engine + Compose):

```bash
./scripts/demo/up.sh        # build + start; prints your URLs
./scripts/demo/down.sh      # stop
./scripts/demo/reset.sh     # stop + wipe db/storage (fresh seeds next start)
```

`up.sh` auto-picks free loopback ports (so it coexists with a native MinIO or sibling lib
demos) and prints a copy-paste URL map — trust the printed numbers, e.g.:

```
app           http://localhost:4102
admin console http://localhost:4102/admin/rindle
MinIO console http://localhost:9001
```

Port conflicts, `COMPOSE_PROJECT_NAME` isolation, opt-in Traefik (`http://cohort.localhost`),
fast-rebuild layering, and "container exited 255" recovery are all covered in the full guide:
**[Running the Cohort demo in Docker](../../guides/docker_demo_dx.md)**.

## Hack on it (native)

For hot-reload development and Playwright E2E, use the native path.

### Prerequisites

- Elixir 1.17+, OTP 27
- PostgreSQL (local or via `PGUSER` / `PGPASSWORD` / `PGHOST` / `PGPORT`)
- MinIO (start from repo root: `bash scripts/ensure_minio.sh`)
- FFmpeg ≥ 6.0 and libvips (same as main Rindle dev setup)
- Node 20+ (Playwright only)

### Quick start

From the **repository root**:

```bash
bash scripts/ensure_minio.sh
cd examples/adoption_demo
mix setup          # deps, vendor JS, ecto + rindle migrations, Cohort seeds
mix phx.server     # http://localhost:4102
```

Open the Cohort dashboard — members (Maya, Alex, Jordan, Ops), lessons, community posts, upload
lab tabs (presigned PUT, tus, multipart, LiveView, AV, Mux cassette), and ops surfaces.

## Admin Console Walkthrough

After seeding the database (`mix run priv/repo/seeds.exs`) and starting the server, developers can visit `http://localhost:4102/admin/rindle` when using the default adoption demo browser port.

Here is what you can click around to see:
- The **Assets** list showing various lifecycle states (e.g. `quarantined`, `degraded`).
- The specific **Audio** and **Document** profiles.
- The **Upload Sessions** representing failures or stale uploads.

## Dependency on Rindle

Local dev uses a path dependency (`../..`). CI and tarball smoke use a built Hex package:

```bash
export RINDLE_DEMO_RINDLE_PATH=/path/to/rindle-0.1.9
mix deps.get && mix setup
```

## Browser E2E (Playwright)

With MinIO + Postgres running:

```bash
cd examples/adoption_demo
npm ci
npx playwright install chromium
npm run e2e
```

Playwright starts the Phoenix server in `MIX_ENV=test` on port **4102** (override with
`ADOPTION_DEMO_BROWSER_PORT`). CI uses `scripts/ci/adoption_demo_e2e.sh` with
`ADOPTION_DEMO_PRESEEDED=1`.

Target admin console behavior specs locally:

```bash
npx playwright test e2e/admin-console.spec.js e2e/admin-theme.spec.js e2e/admin-actions.spec.js
```

Capture the live admin screenshot matrix locally:

```bash
npx playwright test e2e/admin-screenshots.spec.js
```

Screenshots are written under the ignored
`examples/adoption_demo/test-results/admin-screenshots/` path.

## Proof matrix

See [`docs/adoption-proof-matrix.md`](docs/adoption-proof-matrix.md) for what each lane proves
and where. The matrix is drift-checked by `scripts/maintainer/check_adoption_proof_matrix.sh`.

## Charter

Sustaining adoption-evidence work — no demand-gated feature milestones. See
[`.planning/threads/adoption-evidence-lab.md`](../../.planning/threads/adoption-evidence-lab.md).
