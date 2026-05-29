# Adoption proof matrix (`examples/adoption_demo`)

This matrix answers: **what is proven, where, and against what realism?**

Rindle splits adoption proof into **ephemeral package-consumer** lanes (merge-blocking), an
**in-repo adopter** lane, and this **persistent browser host** (merge-blocking CI for all
demo Playwright specs).

| Realism | Meaning here |
|---------|----------------|
| **Fake / MinIO** | S3-compatible local object storage; default for dev, test, and PR CI |
| **Live provider** | GCS / Mux — secret-gated, same posture as `install_smoke.sh gcs` / `mux` |

## Layering

| Layer | What | CI severity |
|-------|------|-------------|
| **A — Package consumer** | Generated Phoenix apps from Hex tarball; ExUnit lifecycle per profile | Merge-blocking (`package-consumer`) |
| **B — Canonical adopter** | In-repo host wiring + smartphone fixtures | Merge-blocking (`adopter`) |
| **C — Adoption demo** | Checked-in host + Playwright browser journeys | Merge-blocking (`adoption-demo-e2e`) |

## Concern matrix

| Concern | Realism | Proof | Where | CI severity |
|---------|---------|-------|-------|-------------|
| Image presigned PUT lifecycle | MinIO | initiate → sign → browser PUT → verify → attach | `e2e/image-upload.spec.js`, `install_smoke.sh image` | Demo + install-smoke: blocking |
| Tus resumable upload | MinIO | LiveView tus helper + TusPlug | `e2e/tus-resume.spec.js`, `install_smoke.sh tus` | Demo + install-smoke: blocking |
| Video AV processing | MinIO + FFmpeg | web preset variants + delivery | `e2e/video-upload.spec.js`, `install_smoke.sh video` | Demo + install-smoke: blocking |
| Replace / detach attachment | MinIO | attach replacement, detach slot | `e2e/replace-detach.spec.js`, `canonical_app/lifecycle_test.exs` | Demo + adopter: blocking |
| Operator doctor + runtime status | Host env | Mix task output on `/ops` | `e2e/ops-surfaces.spec.js`, `mix rindle.doctor` in install-smoke | Demo: blocking |
| Owner erasure preview + execute | MinIO | preview/execute on `/account/:id/delete` | `e2e/owner-erasure.spec.js`, `canonical_app/lifecycle_test.exs` | Demo + adopter: blocking |
| Docs / install parity | N/A | README + guides match generated smoke | `docs_parity_test.exs`, `check_docs_links.sh` | Merge-blocking (`proof`) |
| Mux streaming browser path | Cassette / live | Generated app smoke only | `install_smoke.sh mux` | Structural blocking; live secret-gated |
| GCS resumable browser path | Live | Generated app structural + optional live | `install_smoke.sh gcs`, `package-consumer-gcs-live` | Structural blocking; live secret-gated |

## Drift gate

`scripts/maintainer/check_adoption_proof_matrix.sh` (run in `proof` job) asserts this file
mentions the core proof lanes and E2E spec filenames so gaps stay visible in review.

## Try the demo locally

```bash
bash scripts/ensure_minio.sh
cd examples/adoption_demo && mix setup && mix phx.server
```

See [`README.md`](../README.md) and [`guides/user_flows.md`](../../../guides/user_flows.md).
