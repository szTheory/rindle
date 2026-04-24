# Requirements: Rindle

**Defined:** 2026-04-24
**Core Value:** Media, made durable — full media lifecycle after upload for Phoenix applications with production confidence

## v1 Requirements

### Schema & Data Model

- [x] **SCHEMA-01**: Database migration creates `media_assets` table with all required columns and indexes
- [x] **SCHEMA-02**: Database migration creates `media_attachments` table linking assets to application records via polymorphic association
- [x] **SCHEMA-03**: Database migration creates `media_variants` table with recipe name, digest, storage key, and state columns
- [x] **SCHEMA-04**: Database migration creates `media_upload_sessions` table tracking presigned PUT lifecycle
- [x] **SCHEMA-05**: Database migration creates `media_processing_runs` table recording Oban job outcomes per asset
- [x] **SCHEMA-06**: All tables have queryable state columns (not JSON blobs) so cleanup jobs and admin queries can filter by state
- [x] **SCHEMA-07**: Recipe digest column on `media_variants` allows detection of stale variants after profile changes
- [x] **SCHEMA-08**: Ecto schemas expose typed changesets for all tables with validations matching DB constraints

### Asset State Machine

- [x] **ASM-01**: Asset transitions `staged → validating` when upload is received and verification begins
- [x] **ASM-02**: Asset transitions `validating → analyzing` after MIME and size validation passes
- [x] **ASM-03**: Asset transitions `analyzing → promoting` after metadata extraction completes
- [x] **ASM-04**: Asset transitions `promoting → available` after attachment is written atomically
- [x] **ASM-05**: Asset transitions `available → processing` when variant generation begins
- [x] **ASM-06**: Asset transitions `processing → ready` when all required variants are generated successfully
- [x] **ASM-07**: Asset transitions to `degraded` when some but not all variants fail generation
- [x] **ASM-08**: Asset transitions to `quarantined` when MIME/magic-byte validation fails or scanner flags the file
- [x] **ASM-09**: Asset transitions to `deleted` after purge completes; record is retained for audit log
- [x] **ASM-10**: Invalid state transitions are rejected; no direct jump from `staged` to `ready`

### Variant State Machine

- [x] **VSM-01**: Variant is created in `planned` state when an asset is promoted and profile specifies the variant
- [x] **VSM-02**: Variant transitions `planned → queued` when Oban job is enqueued
- [x] **VSM-03**: Variant transitions `queued → processing` when Oban job begins execution
- [x] **VSM-04**: Variant transitions `processing → ready` when storage write succeeds and DB record is updated
- [x] **VSM-05**: Variant transitions to `failed` when processing errors exceed retry limit
- [x] **VSM-06**: Variant transitions to `stale` when asset profile's recipe digest changes after the variant was generated
- [x] **VSM-07**: Variant transitions to `missing` when storage reconciliation detects the object is absent
- [x] **VSM-08**: Variant transitions to `purged` after variant-level purge completes

### Upload Session State Machine

- [x] **USM-01**: Upload session is created in `initialized` state via `Rindle.initiate_upload/2`
- [x] **USM-02**: Session transitions `initialized → signed` when presigned PUT URL is generated and returned to client
- [x] **USM-03**: Session transitions `signed → uploading` when client begins PUT (optional — may stay `signed` until verification)
- [x] **USM-04**: Session transitions to `uploaded` when storage reports object exists at expected key
- [x] **USM-05**: Session transitions `uploaded → verifying` when server-side verification begins (MIME check, size check)
- [x] **USM-06**: Session transitions `verifying → completed` when verification passes and asset is promoted
- [x] **USM-07**: Session transitions to `aborted` when client cancels or server rejects the session
- [x] **USM-08**: Session transitions to `expired` when TTL elapses before completion
- [x] **USM-09**: Session transitions to `failed` when verification fails (MIME mismatch, size exceeded, scanner rejection)

### Core Behaviours

- [x] **BHV-01**: `Rindle.Storage` behaviour defines `store/3`, `delete/2`, `url/2`, `presigned_put/3`, and `capabilities/0` callbacks
- [x] **BHV-02**: `Rindle.Processor` behaviour defines `process/3` callback taking source path, variant spec, and destination path
- [x] **BHV-03**: `Rindle.Analyzer` behaviour defines `analyze/1` callback returning metadata map (dimensions, duration, colorspace, etc.)
- [x] **BHV-04**: `Rindle.Scanner` behaviour defines `scan/1` callback returning `:ok` or `{:quarantine, reason}`
- [x] **BHV-05**: `Rindle.Authorizer` behaviour defines `authorize/3` callback for delivery authorization decisions
- [x] **BHV-06**: All behaviours include `@callback` specs and are testable via mock implementations

### Profile / Recipe DSL

- [x] **PROF-01**: `use Rindle.Profile` macro compiles profile configuration at application startup
- [x] **PROF-02**: Profile DSL accepts allowlist for MIME types, file extensions, max byte size, and max pixel count
- [x] **PROF-03**: Profile DSL accepts named variant definitions with processor options (resize mode, dimensions, format, quality)
- [x] **PROF-04**: Invalid profile configuration (unknown processor option, contradictory settings) raises a compile-time error
- [x] **PROF-05**: Recipe digest is computed as a stable hash of variant spec options so digest changes when recipe changes
- [x] **PROF-06**: Profile exposes `variants/0` returning a list of variant specs for use by processing workers
- [x] **PROF-07**: Profile exposes `validate_upload/1` returning `{:ok, metadata}` or `{:error, reason}` against configured allowlists

### Validation & Security

- [x] **SEC-01**: Magic-byte MIME detection is performed on every upload using file header bytes, never trusting client `Content-Type`
- [x] **SEC-02**: MIME type is validated against profile allowlist after magic-byte detection; rejection transitions asset to `quarantined`
- [x] **SEC-03**: File extension is validated against profile allowlist; mismatch between extension and detected MIME is rejected
- [x] **SEC-04**: File size is validated against profile `max_bytes` limit before processing proceeds
- [x] **SEC-05**: Pixel count (width × height) is validated against profile limit to prevent decompression bomb variants
- [x] **SEC-06**: Storage keys are generated by Rindle (UUID-based or hash-based); no user-controlled path component is accepted
- [x] **SEC-07**: Filenames submitted by clients are sanitized before storage; sanitized name is stored separately from storage key
- [x] **SEC-08**: Direct upload assets are not promoted until server-side verification confirms object exists and passes validation

### Storage Adapters

- [x] **STOR-01**: Local disk adapter implements all `Rindle.Storage` callbacks and passes the behaviour's test suite
- [x] **STOR-02**: S3-compatible adapter implements all `Rindle.Storage` callbacks including presigned PUT URL generation
- [x] **STOR-03**: S3 adapter `capabilities/0` returns `[:presigned_put]`; does not advertise unsupported operations
- [x] **STOR-04**: Local disk adapter `capabilities/0` returns `[:local]`; does not generate presigned URLs
- [x] **STOR-05**: Adapter selection is configured per profile, not globally, allowing multiple backends in one application
- [x] **STOR-06**: Storage errors are returned as tagged tuples `{:error, reason}`, never raised silently inside DB transactions
- [x] **STOR-07**: S3 adapter is tested against a real S3-compatible endpoint (MinIO) in CI integration lane

### Upload Paths

- [ ] **UPLD-01**: Phoenix-proxied upload accepts multipart form data and streams to storage without loading full file into memory
- [ ] **UPLD-02**: Phoenix-proxied upload returns asset ID on success for subsequent attach call
- [ ] **UPLD-03**: Direct upload broker `initiate_session/2` creates upload session record and returns presigned PUT URL
- [ ] **UPLD-04**: Direct upload broker `verify_completion/1` checks object exists at signed key, runs validation, transitions session
- [ ] **UPLD-05**: Direct upload broker `attach/2` promotes asset and links to application record after successful verification
- [ ] **UPLD-06**: LiveView helper provides `allow_upload` integration for Phoenix LiveView upload flow
- [ ] **UPLD-07**: Controller helper provides plug/action helpers for standard controller upload flow

### Image Processing

- [ ] **PROC-01**: Image/Vix (libvips) processor implements `Rindle.Processor` behaviour
- [ ] **PROC-02**: Processor supports resize operations: `:fit`, `:fill`, `:crop` modes with width/height dimensions
- [ ] **PROC-03**: Processor supports output format conversion: JPEG, PNG, WebP, AVIF
- [ ] **PROC-04**: Processor supports quality setting per variant spec
- [ ] **PROC-05**: Processor accepts named variant from profile spec and returns path to processed file
- [ ] **PROC-06**: Processor errors are returned as `{:error, reason}` and trigger variant `failed` transition after retries exhausted
- [ ] **PROC-07**: ImageMagick and FFmpeg are not dependencies; they are documented as opt-in adapter paths

### Background Processing

- [ ] **BG-01**: Eager variant generation is implemented as an Oban worker enqueued transactionally with asset promotion
- [ ] **BG-02**: Oban worker retries failed variants up to configured max attempts before transitioning to `failed`
- [ ] **BG-03**: Oban worker marks variant `processing` before starting and `ready` or `failed` after completion
- [ ] **BG-04**: Oban cron worker runs scheduled cleanup of expired upload sessions on a configurable schedule
- [ ] **BG-05**: Oban cron worker runs scheduled cleanup of orphaned staged objects on a configurable schedule
- [ ] **BG-06**: All Oban workers are idempotent: re-running a completed job does not corrupt state
- [ ] **BG-07**: Oban is a required dependency; no alternative job runner is supported

### Attach / Promote / Purge

- [ ] **ATT-01**: `Rindle.attach/3` reloads the attachment record inside the transaction to detect concurrent replacement
- [ ] **ATT-02**: `Rindle.attach/3` aborts and returns `{:error, :replaced}` if attachment has changed since job was enqueued
- [ ] **ATT-03**: `Rindle.detach/2` removes attachment record in a DB transaction and enqueues async storage delete after commit
- [ ] **ATT-04**: Storage delete worker is idempotent: if object is already absent, worker completes successfully without error
- [ ] **ATT-05**: Purge path records deletion outcome in `media_processing_runs` for audit visibility

### Delivery

- [ ] **DELV-01**: `Rindle.url/2` returns a signed URL for private assets by default
- [ ] **DELV-02**: Signed URLs include expiry; default TTL is configurable per profile
- [ ] **DELV-03**: Profiles with `public: true` opt-in allow `Rindle.url/2` to return unsigned public URLs
- [ ] **DELV-04**: `Rindle.url/2` raises if called on a private-profile asset without a signed URL capability adapter
- [ ] **DELV-05**: Variant URLs are generated per named variant; fallback to original if variant is not `ready`
- [ ] **DELV-06**: `Rindle.Authorizer` callback is invoked before URL generation when configured on a profile

### Telemetry

- [ ] **TEL-01**: `[:rindle, :upload, :start]` and `[:rindle, :upload, :stop]` events are emitted for all upload paths
- [ ] **TEL-02**: `[:rindle, :asset, :state_change]` event is emitted on every asset state transition with `from` and `to` measurements
- [ ] **TEL-03**: `[:rindle, :variant, :state_change]` event is emitted on every variant state transition
- [ ] **TEL-04**: `[:rindle, :delivery, :signed]` event is emitted when a signed URL is generated
- [ ] **TEL-05**: `[:rindle, :cleanup, :run]` event is emitted when a cleanup worker executes with count of affected records
- [ ] **TEL-06**: All telemetry events include `profile` and `adapter` metadata fields
- [ ] **TEL-07**: Telemetry event names and metadata field names are documented as public API; changes require major version bump
- [ ] **TEL-08**: Telemetry measurements are numeric (duration in native units, byte counts, record counts); no string measurements

### Day-2 Mix Tasks

- [ ] **OPS-01**: `mix rindle.cleanup_orphans` deletes expired upload sessions and their staged storage objects
- [ ] **OPS-02**: `mix rindle.cleanup_orphans` accepts `--dry-run` flag that logs affected records without deleting
- [ ] **OPS-03**: `mix rindle.regenerate_variants` enqueues Oban jobs for all `stale` or `missing` variants matching given profile/name filters
- [ ] **OPS-04**: `mix rindle.regenerate_variants` accepts `--profile` and `--variant` flags for targeted regeneration
- [ ] **OPS-05**: `mix rindle.verify_storage` reconciles `media_variants` DB records against actual storage objects and marks missing variants as `missing`
- [ ] **OPS-06**: `mix rindle.verify_storage` outputs a summary report: total checked, missing, present, errors
- [ ] **OPS-07**: `mix rindle.abort_incomplete_uploads` aborts upload sessions in `signed` or `uploading` state past their TTL to prevent storage cost leaks
- [ ] **OPS-08**: `mix rindle.backfill_metadata` re-runs `Rindle.Analyzer` on existing assets and updates stored metadata
- [ ] **OPS-09**: All Mix tasks exit with non-zero status code when errors occur, enabling CI/script integration

### Stale Variant Detection

- [x] **STALE-01**: When a profile's variant spec changes, recipe digest changes and all existing variants for that spec transition to `stale`
- [x] **STALE-02**: `Rindle.url/2` for a `stale` variant returns the existing URL with a configurable staleness behavior (serve stale or fallback to original)
- [x] **STALE-03**: `mix rindle.regenerate_variants --stale` targets only stale variants for regeneration

### Responsive Image Helper

- [ ] **VIEW-01**: `Rindle.HTML.picture_tag/3` renders a `<picture>` element with `<source>` elements per named variant
- [ ] **VIEW-02**: `picture_tag/3` generates `srcset` attribute from variant URLs when multiple size variants are configured
- [ ] **VIEW-03**: `picture_tag/3` accepts placeholder option for low-quality image placeholder (LQIP) `src` attribute
- [ ] **VIEW-04**: `picture_tag/3` accepts standard HTML attributes (alt, class, loading, etc.) passed through to the `<img>` element

### Configuration

- [x] **CONF-01**: Rindle is configured via `config :rindle` in application config; no runtime config file required
- [x] **CONF-02**: Storage adapter is selected per profile via `storage: MyAdapter` option in profile definition
- [x] **CONF-03**: Oban queue name for Rindle workers is configurable; defaults to `:rindle`
- [x] **CONF-04**: Default signed URL TTL is configurable globally with per-profile override
- [x] **CONF-05**: Upload session TTL is configurable; defaults to a documented value

### Error Handling & Logging

- [x] **ERR-01**: All public API functions return tagged tuples `{:ok, result}` or `{:error, reason}`; no bare raises in public API
- [x] **ERR-02**: Storage failures during variant processing are logged with asset ID, variant name, and error reason at `:error` level
- [x] **ERR-03**: State transition failures log the attempted transition, current state, and reason at `:warning` level
- [x] **ERR-04**: Upload session expiry events are logged at `:info` level with session ID and elapsed time
- [x] **ERR-05**: Quarantine events are logged at `:warning` level with asset ID, detected MIME, and rejection reason

### CI Quality Gates

- [ ] **CI-01**: CI quality lane runs `mix format --check-formatted` and fails on formatting violations
- [ ] **CI-02**: CI quality lane compiles with `--warnings-as-errors` and fails on any compiler warning
- [ ] **CI-03**: CI quality lane runs `mix test` with coverage and fails below configured threshold
- [ ] **CI-04**: CI quality lane runs Credo and fails on any issue at configured strictness level
- [ ] **CI-05**: CI quality lane runs Dialyzer and fails on any type error
- [ ] **CI-06**: CI contract lane validates telemetry event names and metadata schemas match documented public contract
- [ ] **CI-07**: CI integration lane runs upload, processing, delivery, and cleanup paths against real MinIO + PostgreSQL
- [ ] **CI-08**: CI adopter lane runs at least one canonical host integration and verifies end-to-end media lifecycle
- [ ] **CI-09**: CI release lane includes dry-run Hex publish and post-publish parity check before any release candidate

### Documentation

- [ ] **DOC-01**: Getting started guide is copy-pasteable and demonstrates full upload → variant → delivery flow in Phoenix
- [ ] **DOC-02**: Core concepts guide explains asset/variant/session lifecycle with state diagrams
- [ ] **DOC-03**: Profile and recipe definitions guide documents all DSL options with working examples
- [ ] **DOC-04**: Secure delivery guide explains private-by-default posture, signed URL TTL, and public opt-in
- [ ] **DOC-05**: Background processing guide explains Oban worker setup, queue configuration, and retry behavior
- [ ] **DOC-06**: Operations and cleanup guide documents all Mix tasks with flags and example output
- [ ] **DOC-07**: Failure modes and troubleshooting guide covers quarantine, missing variants, stale detection, and session expiry
- [ ] **DOC-08**: All public modules have `@moduledoc` and all public functions have `@doc` with at least one example

## v2 Requirements

### Resumable Upload (tus protocol)

- **RTUS-01**: tus upload server adapter implements `Rindle.Storage` resumable upload capability
- **RTUS-02**: Upload sessions support resume from last byte after connection drop
- **RTUS-03**: tus adapter capability flag `:resumable_upload` is advertised via `capabilities/0`

### S3 Multipart Upload

- **S3MP-01**: S3 adapter supports multipart upload initiation, part upload, and completion
- **S3MP-02**: `mix rindle.abort_incomplete_uploads` aborts in-progress S3 multipart uploads to prevent storage cost leaks
- **S3MP-03**: S3 adapter advertises `:multipart_upload` capability when multipart is configured

### Additional Storage Adapters

- **STOR-EXT-01**: Google Cloud Storage adapter implements `Rindle.Storage` with POST-then-PUT resumable flow
- **STOR-EXT-02**: Cloudflare R2 adapter documents presigned POST multipart limitation and capability flags accordingly

### Video Processing

- **VIDEO-01**: FFmpeg adapter implements `Rindle.Processor` for video transcoding variants
- **VIDEO-02**: FFmpeg adapter requires explicit opt-in and documented container/sandbox guidance
- **VIDEO-03**: Video asset analysis extracts duration, resolution, codec, and bitrate metadata

### Signed Lazy Variant Generation

- **LAZY-01**: Profiles can opt into lazy variant generation with signed request URLs
- **LAZY-02**: Lazy variant request URL includes pixel bound limits enforced server-side
- **LAZY-03**: Lazy variant generation rate-limits per asset to prevent variant explosion

### LiveDashboard Integration

- **DASH-01**: Rindle LiveDashboard page shows asset state distribution, variant generation rates, and cleanup stats
- **DASH-02**: LiveDashboard page is read-only and requires no additional configuration beyond including the page

### Audio Processing

- **AUDIO-01**: Membrane/FFmpeg audio adapter implements `Rindle.Processor` for audio transcoding variants
- **AUDIO-02**: Audio analysis extracts duration, sample rate, channels, and codec metadata

## Out of Scope

| Feature | Reason |
|---------|--------|
| HLS/DASH streaming platform | Media platform territory; Mux/Transloadit adapters are the path, not Rindle core |
| DRM / global adaptive video management | Provider-level concern, not a library lifecycle concern |
| Unsigned dynamic transform API | DoS/cost vector; named presets and signed transforms are the secure alternative |
| JSON-only variant storage | Breaks queryability needed for Day-2 operations, cleanup, and stale detection |
| Synchronous processing in web requests | Blocks request, no retry, no observability; Oban workers always |
| ImageMagick in core dependencies | Security history (ImageTragick); opt-in adapter with sandbox guidance only |
| FFmpeg in core dependencies | Hostile-input DoS risk; opt-in adapter with sandbox guidance only |
| tus/resumable upload in v1 | Presigned PUT covers 95%+ of cases; tus is v1.x adapter |
| S3 multipart upload in v1 | Presigned PUT is sufficient for v1; multipart is v1.x |
| Admin LiveView UI in v1 | Too opinionated, increases surface area; v2 scope |
| PDF/Office/SVG processing by default | Requires hardened sandboxing not universally available; explicit opt-in only |
| Built-in GPU/AI runtime | Runtime dependency in core = hard install; AI adapters are extension points |
| Built-in CDN management | Library responsibility ends at storage; CDN is adopter infrastructure |
| Alternative job runner to Oban | Oban is required; inventing a parallel runner creates divergence risk |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCHEMA-01 through SCHEMA-08 | M1 | Complete (01-01) |
| ASM-01 through ASM-10 | M1 | Complete (01-04) |
| VSM-01 through VSM-08 | M1 | Complete (01-04) |
| USM-01 through USM-09 | M1 | Complete (01-04) |
| BHV-01 through BHV-06 | M1 | Complete (01-02) |
| PROF-01 through PROF-07 | M1 | Complete (01-03) |
| SEC-01 through SEC-08 | M1 | Complete (01-05) |
| STOR-01 through STOR-07 | M1 | Complete (01-06) |
| STALE-01 through STALE-03 | M1 | Complete (STALE-01 in 01-03, STALE-02/03 in 01-04) |
| UPLD-01 through UPLD-07 | M2 | Pending |
| PROC-01 through PROC-07 | M2 | Pending |
| BG-01 through BG-07 | M2 | Pending |
| ATT-01 through ATT-05 | M2 | Pending |
| DELV-01 through DELV-06 | M3 | Pending |
| TEL-01 through TEL-08 | M3 | Pending |
| VIEW-01 through VIEW-04 | M3 | Pending |
| OPS-01 through OPS-09 | M4 | Pending |
| CONF-01 through CONF-05 | M1 | Complete (CONF-02 in 01-03; CONF-01/03/04/05 in 01-06) |
| ERR-01 through ERR-05 | M1 | Complete (ERR-03/04/05 in 01-04; ERR-01/02 in 01-06) |
| CI-01 through CI-09 | M5 | Pending |
| DOC-01 through DOC-08 | M5 | Pending |

**Coverage:**
- v1 requirements: 107 total
- Mapped to phases: 107
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-24*
*Last updated: 2026-04-24 after Phase 01-06 storage adapters, config contracts, and adapter conformance coverage*
