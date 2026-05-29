# Adoption Evidence Lab — sustaining charter

Date: 2026-05-28
Status: shipped (sustaining; no public API)
Scope: repo-local maintainer adoption signal — **not** a feature milestone

## Goal

Runnable demo host + browser E2E + proof matrix so adoption friction surfaces as
failing tests or matrix gaps instead of tribal knowledge. Complements existing
ephemeral `GeneratedAppHelper` install smoke and merge-blocking `package-consumer` CI.

## Non-goals

- LIFE-06 / STREAM-10 feature work
- Hex-published demo app or platform UI
- Replacing install-smoke / package-consumer lanes

## user_flows.md → E2E mapping

| user_flows row | Demo surface | Playwright spec | CI severity |
|----------------|--------------|-----------------|-------------|
| Presigned PUT avatar | `/upload` image tab | `e2e/image-upload.spec.ts` | merge-blocking |
| Tus resume (S3) | `/upload` tus tab | `e2e/tus-resume.spec.ts` | merge-blocking |
| Attach / replace / detach | `/media/:id` | `e2e/replace-detach.spec.ts` | merge-blocking |
| AV video + variants | `/upload` video tab | `e2e/video-upload.spec.ts` | merge-blocking |
| Operator doctor / runtime_status | `/ops` | `e2e/ops-surfaces.spec.ts` | merge-blocking |
| Owner erasure | `/account/delete` | `e2e/owner-erasure.spec.ts` | merge-blocking |
| GCS resumable | — | — | secret-gated (install smoke only) |
| Mux streaming | — | — | cassette / secret-gated |

## Existing lanes (unchanged)

- `scripts/install_smoke.sh` profiles → `package-consumer` CI job
- `test/adopter/canonical_app/lifecycle_test.exs` → `adopter` CI job
- `test/install_smoke/docs_parity_test.exs` → `proof` CI job

## Success

- `cd examples/adoption_demo && mix ecto.setup && mix phx.server` → browser journeys in <10 min
- Playwright CI artifacts on failure
- `examples/adoption_demo/docs/adoption-proof-matrix.md` is drift-checked
