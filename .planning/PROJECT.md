# Rindle

## Current State

Milestone v1.0 is shipped and archived, and Phase 6 of v1.1 is now complete.
Rindle now covers the core post-upload media lifecycle for Phoenix
applications, plus an adopter-owned runtime Repo boundary that no longer leaks
`Rindle.Repo` through public runtime paths.

The remaining v1.1 work should build on that trust win rather than backtrack on
it: multipart uploads, capability honesty across providers, and package-consumer
install proof are still the highest-leverage gaps.

## Current Milestone: v1.1 Adopter Hardening

**Goal:** turn Rindle from a promising library into an adopter-safe and
cloud-realistic package by making host-app ownership real at runtime, closing
the highest-leverage upload capability gaps, and proving installation from the
outside in.

**Target features:**
- Config-driven adopter-owned Repo resolution in all consumer runtime paths
- S3 multipart upload support and cleanup for larger production workloads
- Capability-verified provider compatibility for MinIO and Cloudflare R2
- Package/install smoke proof plus docs aligned to the canonical adopter path

## Next Milestone Goals

- Convert the adopter-repo-first architecture from a documented principle into
  an enforced runtime contract.
- Expand direct-upload support beyond simple presigned PUT so larger SaaS media
  workloads have a credible path on day one.
- Prove that storage capability negotiation works against real providers and
  fails explicitly when a backend cannot honor a requested flow.
- Tighten the install/adoption loop so a fresh Phoenix app can consume the
  package without repo-internal assumptions leaking through.

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

### Active

- [ ] Adopter-owned Repo resolution is configurable and enforced in public
  runtime paths
- [ ] Large direct uploads have a first-class multipart workflow on supported
  S3-compatible backends
- [ ] Storage capability negotiation is verified against real providers and
  unsupported flows fail loudly
- [ ] Fresh-package installation and canonical adopter docs prove a clean path
  from dependency add to production-shaped integration

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

**v1.0 result:** Rindle now has a credible core lifecycle, but the canonical
adopter lane still documents a runtime leak: public paths in `lib/rindle.ex`
hard-code `Rindle.Repo`, which contradicts the adopter-repo-first stance.
This is the clearest architectural trust gap surfaced by the repo itself.

**Adopter trust signal:** CI, docs, and telemetry matter, but a SaaS team will
still hesitate if the host app cannot truly own its Repo/runtime boundary, if
larger direct uploads have no first-class story, or if provider differences are
handled implicitly rather than through explicit capabilities.

**Storage provider reality:** S3-compatible does not mean identical.
Cloudflare R2 and MinIO need verification around presigned and multipart flows;
GCS requires a distinct resumable model. Capability negotiation must stay
precise so Rindle does not over-promise backend support.

**Installability reality:** README is intentionally thin today, while the real
adoption path lives in the guides and canonical adopter test. v1.1 should make
package-consumer success more explicit by proving install and integration from a
fresh adopter perspective.

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
| Capability-driven storage negotiation is the contract boundary | Backend support differs materially across S3-compatible providers and future GCS/resumable flows | — Pending |
| Multipart uploads belong in v1.1, not v1.0 | Presigned PUT was enough for the first release, but larger production workloads need a better direct-upload path | — Pending |
| Install proof should be package-consumer-first | A passing repo CI lane is not the same as a fresh Phoenix adopter succeeding from the published artifact | — Pending |

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
*Last updated: 2026-04-28 after Phase 6 completion*
