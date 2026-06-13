# Adoption proof matrix (`examples/adoption_demo`)

This matrix answers: **what is proven, where, and against what realism?**

Rindle splits adoption proof into **ephemeral package-consumer** lanes (merge-blocking), an
**in-repo adopter** lane, and this **persistent Cohort browser host** (merge-blocking CI for
all MinIO Playwright specs).

| Realism | Meaning here |
|---------|----------------|
| **Fake / MinIO** | S3-compatible local object storage; default for dev, test, and PR CI |
| **Live provider** | GCS / Mux — secret-gated, same posture as `install_smoke.sh gcs` / `mux` |

## Layering

| Layer | What | CI severity |
|-------|------|-------------|
| **A — Package consumer** | Generated Phoenix apps from Hex tarball; `priv/install_smoke/migrate.exs` + boot | Merge-blocking (`package-consumer`) |
| **B — Canonical adopter** | In-repo host wiring + smartphone fixtures | Merge-blocking (`adopter`) |
| **C — Adoption demo (Cohort)** | Checked-in host + Playwright browser journeys | Merge-blocking (`adoption-demo-e2e`) |

## Concern matrix

| Concern | Realism | Proof | Where | CI severity |
|---------|---------|-------|-------|-------------|
| Install / bootstrap | N/A | Generated app compile + host/Rindle migrations + boot | `generated_app_smoke_test.exs` (`host_migration_ran?`), `install_smoke.sh image` | Merge-blocking (`package-consumer`) |
| Image presigned PUT lifecycle | MinIO | initiate → sign → browser PUT → verify → attach | `e2e/image-upload.spec.js`, `install_smoke.sh image` | Demo + install-smoke: blocking |
| Tus resumable upload | MinIO | LiveView tus helper + TusPlug | `e2e/tus-resume.spec.js`, `install_smoke.sh tus` | Demo + install-smoke: blocking |
| Multipart upload | MinIO | Client multipart hook + complete | `e2e/multipart-upload.spec.js`, `canonical_app/lifecycle_test.exs` | Demo + adopter: blocking |
| LiveView server upload | MinIO | `allow_upload` + consume to post image | `e2e/liveview-upload.spec.js` | Demo: blocking |
| Video AV processing (browser) | MinIO + FFmpeg | Browser file pick → presigned PUT → variants | `e2e/video-upload.spec.js`, `install_smoke.sh video` | Demo + install-smoke: blocking |
| `picture_tag` / `video_tag` rendering | MinIO | Seeded Cohort member + lesson pages | `e2e/rendering.spec.js` | Demo: blocking |
| Replace / detach attachment | MinIO | attach replacement, detach slot | `e2e/replace-detach.spec.js`, `canonical_app/lifecycle_test.exs` | Demo + adopter: blocking |
| Operator doctor + runtime status | Host env | Mix task output on `/ops` | `e2e/ops-surfaces.spec.js`, `mix rindle.doctor` in install-smoke | Demo: blocking |
| Batch owner erasure preview | MinIO | Ops UI batch preview | `e2e/batch-erasure.spec.js`, `mix rindle.batch_owner_erasure` | Demo + proof: blocking |
| Owner erasure preview + execute | MinIO | preview `retained_shared_assets` + ops execute | `e2e/owner-erasure.spec.js`, `canonical_app/lifecycle_test.exs` | Demo + adopter: blocking |
| Admin console behavior | MinIO | Console navigation, seeded rows/details, error states, theme picker, and action flows | `e2e/admin-console.spec.js`, `e2e/admin-theme.spec.js`, `e2e/admin-actions.spec.js` | Merge-blocking (`adoption-demo-e2e`) |
| Admin screenshot polish | Host env + MinIO | Live admin light/dark screenshot matrix with asserted ignored PNG output | `e2e/admin-screenshots.spec.js`, `examples/adoption_demo/test-results/admin-screenshots/` | Merge-blocking (`adoption-demo-e2e`) |
| Mux streaming browser path | Cassette | MuxWeb upload tab + provider sync attempt | `e2e/mux-streaming.spec.js`, `install_smoke.sh mux` | Demo (cassette) + install-smoke: blocking |
| GCS resumable browser path | Live | Generated app + optional demo placeholder | `e2e/gcs-resumable.spec.js` (skip), `install_smoke.sh gcs`, `scripts/ci/adoption_demo_gcs_live.sh`, `package-consumer-gcs-live` | Live secret-gated |
| Docs / install parity | N/A | README + guides match generated smoke | `docs_parity_test.exs`, `check_adoption_proof_matrix.sh` | Merge-blocking (`proof`) |
| Local click-around preview | MinIO | Optional Docker preview with `docker/compose.cohort-demo.yml` and `scripts/demo/up.sh`: Postgres, MinIO, seeded Cohort UI, env-driven loopback ports, `COMPOSE_PROJECT_NAME` namespacing, and printed `app` / `admin console` / `MinIO console` URL labels | `docker/compose.cohort-demo.yml`, `scripts/demo/up.sh`, `examples/adoption_demo/README.md` | Optional / not CI-blocking |

## Drift gate

`scripts/maintainer/check_adoption_proof_matrix.sh` (run in `proof` job) asserts this file
mentions the core proof lanes and E2E spec filenames so gaps stay visible in review.

## Try the Cohort demo locally

**Docker (preview):** from repo root, run `./scripts/demo/up.sh`. The launch output prints
`app`, `admin console`, and `MinIO console` URLs; defaults include
`COHORT_DEMO_PORT=4102`, with `COHORT_MINIO_PORT` and `COHORT_MINIO_CONSOLE_PORT` available
for local port conflicts. Use `COMPOSE_PROJECT_NAME` for sibling stacks, and see
[`README.md`](../README.md) for override examples.

Static verification covers rendered compose config, shell syntax/lint, the `--print-urls`
URL-output check, Dockerfile source-order assertions, and
`scripts/maintainer/check_adoption_proof_matrix.sh`.

**Native (hack / E2E):**

```bash
bash scripts/ensure_minio.sh
cd examples/adoption_demo && mix setup && mix phx.server
```

Open the `app` URL from the launch output — dashboard shows members, lessons, posts, and
upload lab tabs.

See [`README.md`](../README.md) and [`guides/user_flows.md`](../../../guides/user_flows.md).
