# Adoption demo — browser E2E lab

Minimal Phoenix host for **human-realistic** Rindle adoption proof. Complements ephemeral
`install_smoke.sh` generated apps and in-repo `canonical_app` tests — it is **not** a second
product or public API surface.

## Prerequisites

- Elixir 1.17+, OTP 27
- PostgreSQL (local or via `PGUSER` / `PGPASSWORD` / `PGHOST` / `PGPORT`)
- MinIO (start from repo root: `bash scripts/ensure_minio.sh`)
- FFmpeg ≥ 6.0 and libvips (same as main Rindle dev setup)
- Node 20+ (Playwright only)

## Quick start

From the **repository root**:

```bash
bash scripts/ensure_minio.sh
cd examples/adoption_demo
mix setup          # deps, vendor JS, ecto + rindle migrations, seeds
mix phx.server     # http://localhost:4102
```

Open the dashboard, pick a seeded user, and exercise `/upload` (presigned PUT + tus tabs),
`/media/:id`, `/ops`, and `/account/:user_id/delete`.

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
`ADOPTION_DEMO_BROWSER_PORT`).

## Proof matrix

See [`docs/adoption-proof-matrix.md`](docs/adoption-proof-matrix.md) for what each lane proves
and where. The matrix is drift-checked by `scripts/maintainer/check_adoption_proof_matrix.sh`.

## Charter

Sustaining adoption-evidence work — no demand-gated feature milestones. See
[`.planning/threads/adoption-evidence-lab.md`](../../.planning/threads/adoption-evidence-lab.md).
