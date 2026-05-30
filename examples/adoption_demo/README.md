# Cohort — Rindle adoption demo

Course-and-community SaaS browser host for **human-realistic** Rindle adoption proof. Complements
ephemeral `install_smoke.sh` generated apps and in-repo `canonical_app` tests — it is **not** a
second product or public API surface.

## Quick try (Docker)

**Preview only** — spin up Postgres, MinIO, and the Cohort UI without installing Elixir, FFmpeg,
or libvips on your machine. First build may take a few minutes.

From the **repository root** (requires Docker Desktop or Docker Engine + Compose):

```bash
./scripts/demo/up.sh
# → http://localhost:4102
```

Stop and remove containers:

```bash
./scripts/demo/down.sh
```

Wipe database and object storage (fresh seeds on next start):

```bash
./scripts/demo/reset.sh
```

Equivalent compose command:

```bash
docker compose -f docker/compose.cohort-demo.yml up --build
```

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

## Proof matrix

See [`docs/adoption-proof-matrix.md`](docs/adoption-proof-matrix.md) for what each lane proves
and where. The matrix is drift-checked by `scripts/maintainer/check_adoption_proof_matrix.sh`.

## Charter

Sustaining adoption-evidence work — no demand-gated feature milestones. See
[`.planning/threads/adoption-evidence-lab.md`](../../.planning/threads/adoption-evidence-lab.md).
