# Rindle

## Current State

Milestone `v1.2 First Hex Publish` shipped on `2026-04-29`. Rindle now has a
proved Hex.pm publication path with protected release automation, a version
drift gate, post-publish public verification, a maintainer release runbook
with rollback/revert instructions, and Nyquist-compliant validation artifacts
for all milestone phases.

The release path is now a practiced, test-backed workflow that future releases
can reuse without rediscovering the mechanics.

## Next Milestone Goals

The highest-leverage next areas (to be confirmed in `/gsd-new-milestone`):

- **API ergonomics review (API-01):** public surface cleanup now that the
  publish path is exercised and adopter trust gaps are closed
- **GCS adapter (GCS-01):** resumable upload flow behind capability flags
- **tus/resumable protocol (TUS-01):** evaluate once release distribution is
  routine

## What This Is

Rindle is an open-source Phoenix/Ecto-native media lifecycle library for
Phoenix applications. It manages the full media lifecycle after upload: staged
objects, validation, analysis, media assets, attachments,
variants/derivatives, background processing, signed delivery, cleanup,
regeneration, and operational visibility. Rindle is not a file upload helper;
it is the durable lifecycle layer that helps Phoenix teams ship media features
with production confidence.

## Core Value

Media, made durable.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- Phase 1 — Foundation: schemas, FSMs, profile DSL, validation primitives, and
  local/S3 storage adapters shipped in v1.0.
- Phase 2 — Upload & Processing: proxied/direct upload flows, image
  processing, Oban workers, and atomic attach/purge behavior shipped in v1.0.
- Phase 3 — Delivery & Observability: signed delivery, telemetry contract, and
  responsive image helpers shipped in v1.0.
- Phase 4 — Day-2 Operations: cleanup, regeneration, storage verification,
  metadata backfill, and maintenance workers shipped in v1.0.
- Phase 5 — CI & 1.0 Readiness: CI lanes, adopter integration, release lane,
  and narrative guides shipped in v1.0.
- Phase 6 — Adopter Runtime Ownership: public runtime Repo resolution,
  adopter-only lifecycle proofs, and adopter-first Repo/Oban guidance verified
  in v1.1.
- Phase 7 — Multipart Uploads: multipart session persistence, cleanup, and real
  MinIO-backed completion/abort proofs verified in v1.1.
- Phase 8 — Storage Capability Confidence: shared capability vocabulary,
  MinIO-backed proof, and honest Cloudflare R2 compatibility guidance verified
  in v1.1.
- Phase 9 — Install & Release Confidence: generated-app package-consumer smoke,
  CI and release reuse, and executable install-doc parity proof verified in
  v1.1.
- ✓ First public `Hex.pm` publish path exercised from the real repository
  workflow — v1.2 (Phase 11)
- ✓ Release automation performs a protected real publish and fails safely before
  publication if package/docs/install gates drift — v1.2 (Phase 11)
- ✓ Maintainer can verify the published package from Hex.pm and follow a
  documented rollback path — v1.2 (Phase 12)
- ✓ Release requirement traceability metadata and runbook aligned with live
  workflow contract — v1.2 (Phase 13)
- ✓ Phases 10 and 11 VALIDATION artifacts completed to Nyquist-compliant state
  — v1.2 (Phase 14)

### Active

<!-- Next milestone requirements go here. -->

- [ ] Public API ergonomics reviewed after the publish path is proven so future
  surface-area growth does not calcify awkward release-era seams (API-01)

### Out of Scope

- Full HLS/DASH streaming platform, DRM, global adaptive video management —
  Rindle is a lifecycle library, not a media platform; these belong to provider
  adapters (Mux, Transloadit)
- Arbitrary unsigned dynamic transformation API — unsigned dynamic resizes are
  a DoS/cost vector; named presets and signed transforms only
- Built-in GPU/AI runtime requirements — AI processors are extension points
  backed by external providers, not core dependencies
- Office/PDF/SVG broad processing by default — requires hardened
  sandbox/container guidance that is not universally available
- "Cloud replacement" or managed CDN product positioning — Rindle is a
  library; CDN behavior is an adopter responsibility
- Full GCS adapter in v1.1 — capability design should remain ready for GCS, but
  the adapter and resumable flow stay deferred until after multipart/S3 support
- tus/resumable upload protocol in v1.1 — multipart is the nearer production
  need; tus remains a later adapter path
- FFmpeg/Membrane adapters in v1.1 — image-first remains the wedge; video/audio
  adapters follow once host-app/runtime boundaries are solid
- PDF preview adapter in v1.1 — still out-of-scope until sandboxing posture is
  documented
- Admin LiveView UI in v1.1 — operator workflows remain code/telemetry/task
  driven for now

## Context

**v1.1 result:** the adopter-owned runtime boundary is now real, multipart
uploads are additive on top of the existing trusted promotion flow, capability
claims are centralized and proved against MinIO, and a fresh Phoenix consumer
can install the built package and follow a docs path that is enforced by tests.

**v1.2 inflection point:** Rindle now looks like a publishable library, but the
first public `Hex.pm` release path has not yet been exercised for real.
Distribution, owner/auth setup, rollback posture, and future release routine
need one deliberate public cut before the next milestone shifts back to API or
upload-surface expansion.

**Reference implementations:**
- Rails Active Storage: attachment/blob ownership patterns, redirect-style
  delivery, and background purge lessons
- Shrine: host-app ownership, atomic promotion, and derivatives as first-class
  records
- Spatie Media Library: strong "day-two" ergonomics and opinionated DX
- imgproxy: capability- and signature-driven delivery constraints

**Security invariants (must hold in all implementations):**
1. Never trust client MIME/filename; enforce magic-byte sniffing and allowlists
2. Do not attach/process direct uploads until completion is verified
3. Do not allow unbounded variant explosion; named presets only by default
4. Storage side effects are not hidden inside DB transactions
5. Purge paths are async, idempotent, and auditable
6. Concurrent replacement races resolve safely
7. Missing/stale/failed variant states are visible, queryable, and actionable

## Constraints

- **Tech stack**: Elixir/Phoenix/Ecto only in core; no non-Elixir runtime in
  the library
- **Repo ownership**: adopter apps own the runtime Repo and DB credentials; the
  library may keep `Rindle.Repo` only as a local test/dev harness
- **Background jobs**: Oban remains the required job backend; multipart flows
  and cleanup must integrate with Oban rather than invent a parallel runner
- **Security defaults**: private delivery remains the default; multipart support
  must preserve the same verification and allowlist guarantees as presigned PUT
- **Capability honesty**: adapters must advertise only what they truly support;
  unsupported flows must fail as tagged errors, not degraded surprises
- **Backward compatibility**: existing presigned PUT flows stay supported;
  multipart is additive and must not break current adopters
- **Docs posture**: practical, copy-pasteable, production-aware, and
  maintainer-to-maintainer in tone

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Media-agnostic core, image-first implementation | Images are the highest-leverage wedge; core domain model must not assume image so video/audio can slot in later | ✓ Good |
| Variants are first-class DB records, not hidden filenames | Queryable state enables admin, retries, stale detection, cleanup, and reporting | ✓ Good |
| Oban as required job backend | Oban is SQL-backed, persistent, observable, and supports transactional enqueueing | ✓ Good |
| Telemetry naming and metadata are public contracts | Operators will build dashboards and alerts against these; silent breakage is unacceptable | ✓ Good |
| Named presets only by default; dynamic transforms opt-in and signed | Unsigned dynamic transforms are a DoS/cost vector | ✓ Good |
| Async purge after DB commit | Storage I/O inside DB transactions is a consistency and latency trap | ✓ Good |
| Repo ownership is adopter-first (`repo: MyApp.Repo`), not library-owned | Matches idiomatic Ecto library architecture and avoids split ownership | ✓ Good |
| `Rindle.Repo` is test/dev harness only, not a consumer runtime dependency | Keeps library development practical while preserving adopter-owned runtime boundaries | ✓ Validated in Phase 6 |
| Capability-driven storage negotiation is the contract boundary | Backend support differs materially across S3-compatible providers and future GCS/resumable flows | ✓ Validated in Phase 8 |
| Multipart uploads belong in v1.1, not v1.0 | Presigned PUT was enough for the first release, but larger production workloads need a better direct-upload path | ✓ Validated in Phase 7 |
| Install proof should be package-consumer-first | A passing repo CI lane is not the same as a fresh Phoenix adopter succeeding from the published artifact | ✓ Validated in Phase 9 |
| First public Hex publish should be scoped narrowly and exercised before broader API cleanup | The release path is the remaining trust gap and should become routine before new surface-area bets | ✓ Validated in Phases 10–14 |

## Historical Snapshot

<details>
<summary>v1.2 First Hex Publish (Phases 10–14) — SHIPPED 2026-04-29</summary>

Milestone v1.2 proved Rindle's first real `Hex.pm` publication path end to end.
Delivered: shared release preflight, protected live publish with scoped
credentials, version drift gate, automated CI dry-run publish, post-publish
public verification job, maintainer release runbook with rollback/revert, and
Nyquist-compliant validation artifacts for all milestone phases.

Full artifacts live in:

- [.planning/milestones/v1.2-ROADMAP.md](.planning/milestones/v1.2-ROADMAP.md)
- [.planning/milestones/v1.2-REQUIREMENTS.md](.planning/milestones/v1.2-REQUIREMENTS.md)
- [.planning/milestones/v1.2-MILESTONE-AUDIT.md](.planning/milestones/v1.2-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.1 Adopter Hardening (Phases 6–9) — SHIPPED 2026-04-28</summary>

The `v1.1` milestone focused on adopter runtime ownership, multipart
upload support, capability honesty across MinIO and Cloudflare R2, and
package-consumer install proof from the built artifact.

Full artifacts live in:

- [.planning/milestones/v1.1-ROADMAP.md](.planning/milestones/v1.1-ROADMAP.md)
- [.planning/milestones/v1.1-REQUIREMENTS.md](.planning/milestones/v1.1-REQUIREMENTS.md)
- [.planning/milestones/v1.1-MILESTONE-AUDIT.md](.planning/milestones/v1.1-MILESTONE-AUDIT.md)

</details>

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? Move to Out of Scope with reason
2. Requirements validated? Move to Validated with phase reference
3. New requirements emerged? Add to Active
4. Decisions to log? Add to Key Decisions
5. "What This Is" still accurate? Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check; still the right priority?
3. Audit Out of Scope; reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-29 after v1.2 milestone completion*
