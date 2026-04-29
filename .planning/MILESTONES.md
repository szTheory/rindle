# Milestones

## v1.2 First Hex Publish (Shipped: 2026-04-29)

**Phases completed:** 5 phases (10–14), 11 plans
**Files changed:** 60 (5,680 insertions / 1,550 deletions)
**Timeline:** 5 days (2026-04-24 → 2026-04-29)

**Key accomplishments:**

- Maintainer-facing Hex publish guidance shipped with ExDoc extras, explicit `0.1.0` versioning sequence and owner model, and an executable parity gate guarding release-doc contract drift.
- Shared release preflight script (`scripts/release_preflight.sh`) proves the shipped Hex artifact contents — tarball metadata, required/prohibited paths, install smoke, and docs warnings — before any live publish wiring is invoked.
- Protected live Hex.pm publish via scoped `HEX_API_KEY` in GitHub `release` environment with concurrency guard preventing overlapping publish runs.
- Version drift gate (`scripts/assert_version_match.sh`) fails the pipeline before publication if the Git tag does not match the `mix.exs` version.
- Automated CI dry-run publish job exercises the full version-check-plus-publish path on every commit so the release flow stays continuously validated outside the protected live lane.
- Fresh-runner `public_verify` job in the release workflow proves network Hex.pm resolution after every publish by clearing `HEX_API_KEY` and running `scripts/public_smoke.sh` against the tag-derived version.
- Maintainer release runbook covers first-publish, routine releases after `0.1.0`, and rollback/revert instructions locked to the live workflow by executable parity tests.
- Canonical `requirements-completed` frontmatter normalized across all release phase summaries so the strict three-source milestone audit can confirm RELEASE-04 through RELEASE-09 without manual override.
- Phase 10 and Phase 11 VALIDATION artifacts completed to Nyquist-compliant state (status: complete, wave_0_complete: true, all sign-offs checked, Approval: approved), clearing all v1.2 audit residue.

**Archive:**
- `.planning/milestones/v1.2-ROADMAP.md`
- `.planning/milestones/v1.2-REQUIREMENTS.md`
- `.planning/milestones/v1.2-MILESTONE-AUDIT.md`

---

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
