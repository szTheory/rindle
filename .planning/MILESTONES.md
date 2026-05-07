# Milestones

## v1.6 Provider Boundary + Mux (Shipped: 2026-05-07)

**Phases completed:** 4 phases (33-36), 15 plans
**Files changed:** 144 (42,665 insertions / 188 deletions)
**Timeline:** ~22 hours (2026-05-06 → 2026-05-07)
**Requirements validated:** 28/32 (STREAM-01..09 + MUX-01..19); MUX-20..23 deferred to v1.7 (Phase 37 not pulled forward)

**Key accomplishments:**

- Promoted `Rindle.Streaming.Provider` from a v1.4-reserved 2-callback seam to a runtime contract with locked `@callback` signatures (capability query, asset CRUD, signed playback URL, webhook verify, optional direct-creator-upload), with closed `Rindle.Streaming.Capabilities` vocabulary, profile DSL `:streaming` key validated through NimbleOptions, 8-branch `Rindle.Delivery.streaming_url/3` dispatch tree, and 5 additive locked error atoms with byte-frozen parity test (Phase 33, STREAM-01..09).

- Shipped `Rindle.Streaming.Provider.Mux` reference adapter with all 6 callback implementations and `mux ~> 3.2` + `jose ~> 1.11` as **optional deps** (zero transitive cost for non-streaming adopters); `Rindle.Workers.MuxIngestVariant` server-push ingest worker (atomic-promote race protection, two-layer Oban-unique idempotency, 429 Retry-After snooze, compensating Mux delete on drift); explicit JOSE-signed JWT TTL respecting profile policy (defeats Mux SDK's 7-day default footgun); `MuxSyncCoordinator` + `MuxSyncProviderAsset` defensive-poll workers with stuck-threshold transition; cross-cutting telemetry redaction parity test enforcing security invariant 14 (Phase 34, MUX-01..08).

- Mountable `Rindle.Delivery.WebhookPlug` with raw-body cache pattern (`WebhookBodyReader`, 1 MiB cap, list-of-binaries assigns shape, `Plug.Parsers` JSON bypass), HMAC-SHA256 verify via `Mux.Webhooks.verify_header/4`, configurable 60–900s replay window, multi-secret rotation with `secret_index` telemetry; `Rindle.Workers.IngestProviderWebhook` Oban worker idempotent on Mux event UUID, race-snooze on row-missing, two-topic PubSub broadcast with provider-id redaction; typed `video.upload.asset_created` branch (locks D-29 forward-compat for Phase 37); `mix rindle.runtime_status --provider-stuck` operator-visibility extension (Phase 35, MUX-09..14).

- Public adopter onboarding for Mux: `Rindle.Profile.Presets.MuxWeb` ships alongside `Rindle.Profile.Presets.Web` with `:streaming` opt-in + `:signed` named playback policy; `mix rindle.doctor --streaming` adds 4 PASS/FAIL streaming checks (token id/secret, signing key, webhook secrets, 5s smoke ping to `Mux.Video.Assets.list/1`) emitting env-var names only, never values; `guides/streaming_providers.md` (341 lines, 11 sections) documents env vars, signing-key creation, secret rotation, raw-body wiring, ngrok-tunnel guidance; README + getting-started gain `Streaming with Mux (optional)` subsections (≤15 lines each) without displacing image/AV first-run path (Phase 36, MUX-15..17, MUX-19).

- Generated-app `mux-enabled` package-consumer proof harness — cassette lane runs every PR (Mox-on-`:http_client`, zero secrets); label-gated `mux-soak` sibling job runs against real Mux on `streaming`-labelled PRs only, fork-PR-safe via no-credential branch; three-layer asset-leak mitigation (try/after + `if: always()` + idempotent cleanup with last-4 redaction); `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` validates JWT-signed HLS URL through `JOSE.JWT.verify_strict/3` against committed test signing key (Phase 36, MUX-18).

- Locked v1.7+ adapter scope: GCS resumable adapter (5 phases, ~13 days, locked plan in `.planning/research/v1.6-CANDIDATE-GCS.md`) and tus protocol (5 phases, ~13–15 days, locked plan in `.planning/research/v1.6-CANDIDATE-TUS.md`) preserved as research-locked candidate scope. Phase 37 (browser→Mux direct creator upload, MUX-20..23) deferred to v1.7 since milestone budget held without pulling forward.

**Known deferred items at close:** 5 Phase 36 UAT scenarios (CI-only by design — cassette PR run, mux-soak real-Mux, HexDocs publish wire, fork-secret boundary, generated-app cassette test); ~25 Warning + Info findings across Phases 34/35 routed to v1.7 polish via `/gsd-code-review --fix`. **Phase 36's 3 BLOCKER + 10 WARNING review findings (CR-01/02/03 + WR-01..WR-10) were resolved pre-close** in commits `8b291c1`–`c901124`; REVIEW.md `status: fixes_applied`. (See STATE.md `## Deferred Items`.)

**Archive:**
- `.planning/milestones/v1.6-ROADMAP.md`
- `.planning/milestones/v1.6-REQUIREMENTS.md`

---

## v1.5 Adopter Hardening & Lifecycle Repair (Shipped: 2026-05-06)

**Phases completed:** 4 phases (29-32), 14 plans
**Timeline:** 2 days (2026-05-05 → 2026-05-06)

**Key accomplishments:**

- Proved the real package-consumer happy path for both image-only and
  AV-enabled adopters from shipped artifacts rather than only from the repo.

- Added explicit repair surfaces for reprobe, targeted requeue, dry-run-first
  sweep, and truthful regeneration guidance.

- Rebuilt runtime diagnostics around deterministic `mix rindle.doctor` checks,
  bounded `mix rindle.runtime_status` reporting, and additive repair/runtime
  telemetry.

- Proved the upgrade path from pre-v1.4 image-only installs into the current
  AV-aware lifecycle and locked the recovery story into docs and CI.

- Preserved future breadth work as deferred candidate scope: GCS, provider
  adapters, and tus remain out of milestone close until explicitly selected.

**Archive:**

- `.planning/milestones/v1.5-ROADMAP.md`
- `.planning/milestones/v1.5-REQUIREMENTS.md`
- `.planning/milestones/v1.5-MILESTONE-AUDIT.md`

---

## v1.4 Video & Audio Wedge (Shipped: 2026-05-05)

**Phases completed:** 6 phases (23-28), 27 plans
**Files changed:** 131 (17,189 insertions / 209 deletions)
**Timeline:** 4 days (2026-05-02 → 2026-05-05)

**Key accomplishments:**

- Shipped the AV foundation seam: capability vocabulary, guarded FFmpeg/FFprobe subprocess execution, boot probing, and `mix rindle.doctor`.
- Extended the domain model and profile DSL for `:image`, `:video`, `:audio`, and `:waveform` without breaking existing image-only adopters.
- Added `Rindle.Processor.AV` with preset-led video/audio outputs, poster extraction, waveform generation, deterministic worker behavior, and runtime/output guards.
- Added the delivery surface for playback with `Rindle.Delivery.streaming_url/3`, local range-aware dev parity, RFC 5987 download filenames, and frozen delivery telemetry.
- Shipped Phoenix-facing `video_tag/3` and `audio_tag/3`, public LiveView progress/cancellation contracts, and the locked AV error vocabulary.
- Locked the public AV onboarding story with install docs, profile-aware doctor CI gates, smartphone-source adopter proof, and AV hygiene checks.

**Archive:**

- `.planning/milestones/v1.4-ROADMAP.md`
- `.planning/milestones/v1.4-REQUIREMENTS.md`
- `.planning/milestones/v1.4-MILESTONE-AUDIT.md`

---

## v1.3 Live Publish & API Ergonomics (Shipped: 2026-05-02)

**Phases completed:** 8 phases (15-22), 21 plans

**Key accomplishments:**

- Preflight validation script `scripts/release_preflight.sh` to locally unpack and inspect the hex release candidate for structural compliance.
- Complete first-party HTTP probe for `hexdocs.pm/rindle` reachability in the release workflow, closing the observability gap post-publish.
- Explicit `Rindle.Error` struct with typed reason tracking and deterministic behavior across constraints, variants, and attachments.
- Added `@doc` and `@spec` coverage enforced via `mix doctor --raise` to guarantee coverage and catch regressions in CI.
- Introduced ergonomic `attachment_for/2`, `ready_variants_for/1` and matching `!` bang variants for all public facade functions.
- Tightened `Dialyzer` struct resolution, enforcing deterministic test setup before code executes without compilation faults.
- Fixed residual `LiveView` correctness issues (consume callback duplicates and nil-derefs on fresh attachments).
- Completed retrospective metadata closure, ensuring goal-backward traceability for all Phase 15 and 16 requirements.

**Archive:**

- `.planning/milestones/v1.3-ROADMAP.md`
- `.planning/milestones/v1.3-REQUIREMENTS.md`
- `.planning/milestones/v1.3-MILESTONE-AUDIT.md`

---

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
