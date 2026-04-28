# Milestones

## v1.1 Adopter Hardening (Shipped: 2026-04-28)

**Phases completed:** 4 phases, 12 plans, 23 tasks

**Key accomplishments:**

- Configured adopter repo resolution now drives the public facade seam while preserving the in-repo `Rindle.Repo` harness default.
- Direct-upload broker flows, canonical adopter lifecycle coverage, and proxied `Rindle.upload/3` now execute against the configured adopter repo instead of relying on shared `Rindle.Repo` leakage.
- Public guides now teach adopter-owned repo configuration, default-Oban scope, and troubleshooting queries that match the Phase 6 runtime proofs.
- Multipart upload sessions now persist broker-owned authority, expose public multipart APIs, and complete through the existing verification lane with explicit capability errors on unsupported adapters
- Upload maintenance now resolves through the adopter-owned runtime repo and aborts expired multipart uploads before deleting session rows, preserving retry state on remote failures
- Real MinIO-backed multipart uploads now prove adapter completion, broker integration, adopter promotion, and abandoned-upload cleanup through Rindle's existing verification and maintenance lanes
- Shared storage capability vocabulary with stable tagged delivery/upload failures and reserved resumable atoms
- The shipped S3 adapter, broker lifecycle, and canonical adopter lane now prove the same MinIO-backed upload capability contract for both presigned PUT and multipart uploads
- Canonical storage capability guide plus explicit Cloudflare R2 compatibility boundaries
- Fresh `mix phx.new` install smoke for the built Rindle artifact, with explicit host plus library migrations and a shared runner for presigned PUT verification
- PR CI now proves package-consumer installability from the built artifact, while release reuses the same smoke helper and keeps the deeper tarball and dry-run gates
- README and getting-started docs now teach the exact smoke-proven presigned PUT install path, and RELEASE-03 is enforced by an executable ExUnit parity gate

---
