# Rindle

## What This Is

Rindle is an open-source Phoenix/Ecto-native media lifecycle library for Phoenix applications. It manages the full media lifecycle after upload: staged objects, validation, analysis, media assets, attachments, variants/derivatives, background processing, signed delivery, cleanup, regeneration, and operational visibility. Rindle is not a file upload helper — it is the durable lifecycle layer that helps Phoenix teams ship media features with production confidence.

## Core Value

Media, made durable.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- Phase 2 — Upload & Processing: direct upload broker, proxied uploads, image processing, Oban workers, attachment replacement, and LiveView helpers are implemented and verified.

### Active

**M1 — Domain Core + Storage Foundation**
- [ ] Ecto migrations and schemas for `media_assets`, `media_attachments`, `media_variants`, `media_upload_sessions`, `media_processing_runs`
- [ ] Core behaviours: `Rindle.Storage`, `Rindle.Processor`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Authorizer`
- [ ] Profile/recipe DSL (`use Rindle.Profile`) with compile-time validation
- [ ] Recipe digest computation (stable hash so stale variants are detectable)
- [ ] Local disk storage adapter
- [ ] S3-compatible storage adapter with presigned PUT direct upload
- [ ] Asset state machine: `staged → validating → analyzing → promoting → available → processing → ready / degraded / quarantined / deleted`
- [ ] Variant state machine: `planned → queued → processing → ready / stale / missing / failed / purged`
- [ ] Upload session state machine: `initialized → signed → uploading → uploaded → verifying → completed / aborted / expired / failed`
- [ ] Magic-byte MIME detection (never trust client Content-Type alone)
- [ ] Filename sanitization and generated storage keys (no user-controlled paths)
- [ ] Allowlist-based validation: extensions, MIME types, byte size, pixel count limits

**M2 — Upload Paths + Processing**
- [x] Phoenix-proxied upload path (controller + LiveView helpers)
- [x] Direct upload broker: initiate session → sign URL → verify completion → attach
- [x] Image/Vix (libvips) processor for named image variants
- [x] Eager variant generation via Oban workers
- [x] Signed lazy variant generation (opt-in, signed, bounded)
- [x] Atomic attach/promote: reload record, verify attachment unchanged before writing
- [x] Idempotent purge: detach in DB transaction, enqueue async storage delete

**M3 — Delivery + Observability**
- [ ] Signed URL delivery (private-by-default)
- [ ] Safe public delivery opt-in per profile
- [ ] Telemetry events with public-contract naming: `[:rindle, :upload, :*]`, `[:rindle, :asset, :*]`, `[:rindle, :variant, :*]`, `[:rindle, :delivery, :*]`, `[:rindle, :cleanup, :*]`
- [ ] Telemetry metadata and measurements schemas (public contract)
- [ ] Responsive image helper (`picture_tag/3`, srcset, placeholder)

**M4 — Day-2 Operations**
- [x] `mix rindle.cleanup_orphans` — expired sessions, detached staged objects
- [x] `mix rindle.regenerate_variants` — stale/missing variants by profile/name
- [x] `mix rindle.verify_storage` — reconcile DB records against storage
- [x] `mix rindle.abort_incomplete_uploads` — multipart cost leak prevention
- [x] `mix rindle.backfill_metadata` — re-analyze existing assets
- [x] Oban cron workers for scheduled cleanup
- [x] `stale` variant detection when recipe digest changes

**M5 — Quality, Docs, CI**
- [ ] CI quality lane: format, compile warnings-as-errors, tests, Credo, Dialyzer
- [ ] CI contract lane: docs contracts, workflow/release config validation
- [ ] CI integration lane: storage (MinIO/LocalStack) + DB + processing path
- [ ] CI adopter lane: canonical host integration proof (at least one verified integration)
- [ ] CI release lane: release automation, dry-run publish, post-publish parity check
- [ ] Getting started guide (copy-pasteable, Phoenix-workflow-first)
- [ ] Core concepts / lifecycle guide
- [ ] Profile and recipe definitions guide
- [ ] Secure delivery guide
- [ ] Background processing guide
- [ ] Operations and cleanup guide
- [ ] Failure modes and troubleshooting guide

### Out of Scope

- Full HLS/DASH streaming platform, DRM, global adaptive video management — Rindle is a lifecycle library, not a media platform; these belong to provider adapters (Mux, Transloadit)
- Arbitrary unsigned dynamic transformation API — unsigned dynamic resizes are a DoS/cost vector; named presets and signed transforms only
- Built-in GPU/AI runtime requirements — AI processors are extension points backed by external providers, not core dependencies
- Office/PDF/SVG broad processing by default — requires hardened sandboxing that is not universally available; explicit opt-in with documented container/sandbox guidance
- "Cloud replacement" or managed CDN product positioning — Rindle is a library; CDN behavior is an adopter responsibility
- tus/resumable upload protocol in v1 — direct presigned PUT is sufficient for v1; tus and GCS resumable are v1.x adapters
- S3 multipart upload in v1 — presigned PUT covers the primary case; multipart is v1.x
- FFmpeg/Membrane adapters in v1 — image-first; video/audio adapters follow as plugins
- PDF preview adapter in v1 — out-of-scope until sandboxing posture is documented
- Admin LiveView UI in v1 — LiveDashboard page or minimal read-only admin is a stretch goal; full admin UI is v2

## Context

**Ecosystem gap:** Phoenix and LiveView have excellent upload UX (progress, cancellation, direct external uploads), but no framework-level durable media lifecycle layer. Waffle covers storage + versions + Ecto casting but lacks persistent variant state, resumable direct uploads, Oban-native processing, admin UI, cleanup, stale detection, and telemetry. `phx_media_library` (v0.6.0, published March 2026) is the nearest emerging competitor — study its API before finalizing public APIs.

**Reference implementations:**
- Rails Active Storage: attachment/blob/variant/analysis model; lazy variants with redirection; async purge pattern; warn against sync processing in templates
- Shrine: derivatives as separate records with recipe names; atomic promote pattern; backgrounding + cleanup as first-class concerns
- Spatie Media Library: conversion regeneration as Day-2 command; responsive image srcset; beloved DX through opinionated defaults
- imgproxy: signed dynamic transform URLs as a security requirement, not a feature
- Mux/Transloadit: async media workflow ergonomics; upload session → webhook → state transition model

**Image processing:** Image/Vix (libvips) is the default for image variants — roughly 2–3× faster than Mogrify, ~5× less memory. ImageMagick and FFmpeg require explicit opt-in with documented sandbox/container guidance due to their security history (ImageTragick, hostile-input risks in FFmpeg).

**Storage provider reality:** S3-compatible ≠ identical. Cloudflare R2 does not support presigned POST multipart form uploads. GCS uses a POST-then-PUT resumable upload flow. Storage adapters must expose capabilities (`:presigned_put`, `:multipart_upload`, `:resumable_upload`, etc.) rather than pretending all backends are the same.

**Brand name status:** "rindle" is amber — used by an npm streams utility and older project management products. Use `rindle` as the Elixir package name; consider `rindle_media` as the fallback repo/package namespace. Confirm GitHub org and Hex availability before launch.

**Security invariants (must hold in all implementations):**
1. Never trust client MIME/filename — enforce magic-byte sniffing and allowlists
2. Do not attach/process direct uploads until completion is verified
3. Do not allow unbounded variant explosion — named presets only by default
4. Storage side effects are not hidden inside DB transactions
5. Purge paths are async, idempotent, and auditable
6. Concurrent replacement races resolve safely (atomic promote pattern)
7. Missing/stale/failed variant states are visible, queryable, and actionable

## Constraints

- **Tech stack**: Elixir/Phoenix/Ecto — no non-Elixir runtimes in core; all adapters are optional dependencies
- **Processing default**: Image/Vix (libvips) for images; no ImageMagick or FFmpeg in core — they are opt-in adapters requiring explicit sandbox guidance
- **Background jobs**: Oban is the required job backend — do not invent a parallel job runner
- **Telemetry**: Telemetry event names and metadata shapes are public API contracts — breaking them requires a major version bump
- **Security defaults**: private storage and signed delivery are the default; public URLs require explicit profile opt-in
- **Dynamic transforms**: named recipes by default; dynamic transforms require signing + rate limits + pixel bounds — never exposed unsigned
- **DB schema**: normalized tables for assets, attachments, variants, upload sessions, processing runs — no JSON-column-only variant storage; admins, SREs, and cleanup jobs need queryable state
- **CI**: quality gates, contract lane, integration lane, and adopter lane must exist before any release candidate
- **Docs posture**: practical, copy-pasteable, production-aware; no hype language, no "magic" framing; peer-to-peer maintainer tone

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Media-agnostic core, image-first implementation | Images are the highest-leverage v1 wedge; core domain model must not assume image so video/audio slots in cleanly | — Pending |
| Variants are first-class DB records, not hidden filenames | Queryable state enables admin UI, retries, stale detection, cleanup, and reporting; JSON-only breaks Day-2 operations | — Pending |
| Oban as required job backend (not optional) | Oban is SQL-backed, persistent, observable, and supports transactional job enqueueing; inventing a parallel runner creates divergence risk | — Pending |
| Telemetry naming and metadata are public contracts | Operators build dashboards and alerts against these; breaking them silently is an incident | — Pending |
| Image/Vix (libvips) as default image processor | 2–3× faster, ~5× less memory than Mogrify; avoids shell-out security risk in default path | — Pending |
| Named presets only by default; dynamic transforms opt-in and signed | Unsigned dynamic transforms are a DoS/cost vector (imgproxy lesson); escape hatch exists but is not the default | — Pending |
| Async purge: detach in DB transaction, enqueue storage delete after commit | Storage I/O inside a DB transaction can fail after state is committed, or slow/block the transaction (Active Storage lesson) | — Pending |
| Atomic promote: reload + verify before writing | Prevents stale background job from overwriting a newer attachment when user replaces an upload mid-processing (Shrine lesson) | — Pending |
| Day-2 operations are v1 scope, not deferred | Cleanup, regeneration, verification, and reconciliation are what make a library production-ready; deferring them is how libraries stay "upload wrappers" | — Pending |
| CI adopter lane required before release candidate | At least one canonical host/adopter integration must be continuously verified; docs-only integration claims are not sufficient | — Pending |
| Repo ownership is adopter-first (`repo: MyApp.Repo`), not library-owned | Matches idiomatic Ecto library architecture (Oban-style), avoids split pool/config ownership and multi-tenant surprises | ✓ Good |
| Runtime DB config stays in adopter app (`runtime.exs`), not in Rindle dependency | Library-level runtime secret management is surprising and brittle; host app is source of truth for credentials and deploy config | ✓ Good |
| `Rindle.Repo` is test/dev harness only, not a consumer runtime dependency | Keeps local library development practical while preserving adopter-owned runtime boundaries | ✓ Good |
| Rindle ships Oban workers but does not start/supervise Oban itself | Queue topology and reliability settings belong to the host app; avoids hidden runtime ownership | ✓ Good |
| Decision policy is left-shifted: auto-decide low/medium impact, escalate only high impact | Maximizes execution speed while preserving user control over irreversible API/security/scope calls | ✓ Good |

---
*Last updated: 2026-04-26 after Phase 4 day-2-operations completion*
