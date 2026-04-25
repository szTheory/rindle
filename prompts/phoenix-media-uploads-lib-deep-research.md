Phoenix/Ecto Media Uploads, Variants, and Processing Pipelines — Research + Domain Context

1. Working thesis

The real gap is not “file upload”. Phoenix and LiveView already cover the browser-to-server and browser-to-cloud upload path well: LiveView supports progress, client-side validation, cancellation, direct-to-server uploads, and external direct-to-cloud uploads via allow_upload/3 and an external entry writer.  ￼

The gap is the durable media lifecycle after upload:

upload session → staged object → validation → analysis → attach to Ecto data → promote to permanent storage → generate variants/derivatives/previews → serve securely → observe/retry/regenerate/cleanup over time.

Waffle covers a useful slice of this today: storage, versions, Ecto integration through waffle_ecto, and transformations via external executables such as ImageMagick or FFmpeg. But its default mental model is still closer to “versioned upload definition” than to a full media lifecycle system with persistent variant state, resumable direct uploads, background processing orchestration, admin UI, telemetry, cleanup, variant regeneration, security policy, and Day-2 operations. Waffle processes versions concurrently as independent Tasks with a default 15-second timeout, supports local and S3 storage by default, and transformations can call arbitrary system executables.  ￼

The opportunity is to build the Phoenix-native ActiveStorage/Shrine/Spatie/Cloudinary-inspired media layer for Elixir: Ecto-first, LiveView-friendly, Oban-native, Telemetry-rich, storage-provider-aware, and secure-by-default.

2. Scope recommendation: not image-only, but image-first

The library should be media-agnostic at the core and image-first in the first excellent release.

Images are the best v1 wedge because they are the most common product need, the Elixir ecosystem has a modern libvips-based path via Image/Vix, and image variants can deliver immediate value: avatars, thumbnails, gallery images, Open Graph images, responsive images, WebP/AVIF conversion, cropping, placeholders, and metadata extraction. The Image package is built on Vix/libvips and its docs describe an idiomatic Elixir API above Vix/libvips; its own benchmark note claims a simple resize is roughly 2–3x faster than Mogrify with about 5x less memory.  ￼

But the domain model should not assume “image”. It should assume media assets with analyzers, processors, representations, and delivery policies. Rails Active Storage explicitly handles image variants plus representations/previews for videos and PDFs, and it analyzes uploaded files asynchronously for metadata such as image dimensions and video duration/bitrate.  ￼

Audio/video should be supported as plugin-capable, async-heavy pipelines, not as a v1 promise to be a full Mux/Cloudinary replacement. FFmpeg/Membrane adapters can cover metadata, thumbnails, waveform extraction, audio normalization, basic transcode, and preview clips. Full adaptive video streaming, HLS/DASH ladders, DRM, captions at scale, and global delivery are better handled by provider adapters unless this library intentionally becomes a media platform. Membrane is a serious Elixir multimedia framework for streaming/processing, and its ecosystem includes FFmpeg-based transcoding plugins.  ￼

AI transformations should be first-class extension points, not core dependencies. Cloudinary and Transloadit already expose AI media capabilities such as generative image transformations, background removal, image generation, transcription, face detection, and text-to-speech; this is a strong signal that users will eventually expect AI media workflows, but also a signal that these should be provider-backed and cost-controlled.  ￼

Recommended framing:

v1:    image variants + generic attachments + metadata + secure delivery + Oban jobs
v1.x:  PDF/video/audio previews + FFmpeg/Membrane/provider adapters
v2:    richer workflows, media library/admin UI, AI processors, multi-step pipelines

3. Existing Elixir landscape

Phoenix / Plug / LiveView

Phoenix’s built-in upload story is good for request handling and LiveView UX. Standard Phoenix controller uploads use Plug.Upload; LiveView adds interactive uploads with progress, errors, cancellation, and direct-to-cloud options.  ￼

The missing layer is the reusable lifecycle abstraction. Community discussion reflects this: LiveView uploads are praised for drag-and-drop, progress, and cancellation, while still requiring boilerplate to process uploaded files into durable storage.  ￼

Waffle / Waffle.Ecto

Waffle remains the most important existing Elixir reference. It is flexible, integrates with Ecto through waffle_ecto, supports local/S3-style workflows, and allows processors to call any executable, including ImageMagick for images and FFmpeg for video stills.  ￼

The core tradeoff: Waffle is relatively simple and idiomatic for classic “upload + versions” use cases, but it does not appear to own the broader lifecycle: durable upload sessions, resumable uploads, variant records, state machines, cleanup workflows, admin surfaces, provider-specific direct-upload behavior, or Oban-backed processing as a primary abstraction. Its async version processing is Task-based with a default timeout, which is fine for small variants but not enough for heavy media pipelines.  ￼

Arc

Arc is historically important but should mostly be treated as legacy. Waffle originated from the Arc lineage, and community discussion has described Arc as no longer maintained while Waffle continued as the maintained successor. Arc’s own repository material includes migration guidance from Arc config/namespaces to Waffle.  ￼

Image / Vix / libvips

For images, the modern Elixir stack should prefer Image/Vix/libvips over shelling out to ImageMagick for the main happy path. Image provides a higher-level, idiomatic Elixir API over Vix, and libvips is well known for low memory usage and speed in image pipelines.  ￼

Still keep an adapter boundary. ImageMagick/Mogrify remains useful for edge formats and existing user expectations, but the default should avoid exposing users to arbitrary shell commands as the main API. Mogrify is an Elixir wrapper around ImageMagick’s command-line tools and requires ImageMagick to be installed.  ￼

phx_media_library

phx_media_library is important to watch. It already aims at associating media files with Ecto schemas, image conversions, responsive images, local/S3 backends, and is inspired by Spatie’s Laravel Media Library. It is very new and, based on the Hex metadata I found, still has tiny adoption: v0.6.0 was published March 31, 2026, with low download counts and zero dependants at the time of the listing.  ￼

This validates the opportunity but also means you should study its API carefully before building. The goal should not be “another small upload wrapper”; the goal should be a clearly superior architecture and DX.

Older/smaller upload packages

There are older packages such as artifact, upload, and uploader, but they appear either old, small, or focused on narrower storage/casting problems. For example, artifact is described as “file upload and on-the-fly processing for Elixir” but was published around ten years ago, while uploader focuses on finer control over Plug.Upload casting, filenames, and path strategies.  ￼

4. Lessons from other ecosystems

Rails Active Storage

Active Storage’s biggest lesson is that the framework-level primitive should model attachments, blobs, variants, analysis, previews, direct upload, and delivery, not just “file path in a column”. It analyzes files after upload through queued jobs, supports metadata extraction, and can represent images, videos, and PDFs.  ￼

Its lazy variant model is powerful: a requested representation can be processed on demand, uploaded, then redirected to the service URL. Rails also has a variant tracker so a requested representation usually does not require repeated remote-service lookups after it has been created.  ￼

Footgun: lazy processing can make first request slow and expensive. Active Storage’s Variant docs explicitly warn that generating a variant requires downloading the entire blob from storage and that variants should not be processed inline in templates.  ￼

Another footgun: destructive storage operations should not be hidden inside DB transactions/callbacks. Active Storage warns that purge initiates an HTTP connection and may be slow or blocked, so it should not be used inside a transaction or callback; use async purge instead.  ￼

Elixir design takeaways:

Use a persistent media_variants table, not only JSON metadata. Support lazy and eager generation, but make lazy generation signed/preset-only. Make purging, promotion, and heavy transforms asynchronous and idempotent. Never require a Phoenix template render to synchronously process a missing variant.

Shrine

Shrine’s evolution is one of the most valuable bodies of lessons. It replaced its older versions plugin with a more explicit derivatives plugin because the older design coupled processed files too tightly to the attachment flow, mixed processed files with originals, and made separate storage or post-promotion version creation awkward.  ￼

Shrine’s derivatives plugin stores processed files alongside the main file, gives them explicit names, and lets the application trigger derivative processing. Its derivation endpoint can dynamically process files on request, similar to on-demand variants.  ￼

Shrine’s backgrounding and persistence docs are especially relevant. Background promotion/deletion exists because promotion, deletion, derivatives, and remote storage can be slow. Its atomic_promote and atomic_persist patterns reload the record and verify that the attachment has not changed before writing, raising an attachment-changed error if another update won the race.  ￼

Shrine also documents two practical Day-2 truths: direct uploads reduce app-server workload but require CORS and staged storage semantics; cached/temp files are not automatically deleted and need lifecycle rules or cleanup jobs.  ￼

Elixir design takeaways:

Avoid a “versions embedded inside original upload definition” design. Model derivatives/variants as separate records with their own storage, state, recipe digest, retry policy, and errors. Add atomic attach/promote semantics from day one. Ship cleanup tasks in v1, not later.

Spatie Laravel Media Library

Spatie shows what a beloved developer-facing media library looks like: model associations, media collections, conversions, responsive images, filesystem integration, and optional UI components. Its docs position it as a way to associate files with Eloquent models while generating thumbnails and responsive images.  ￼

Spatie conversions are queued by default and can create derived versions for many formats, including images, PDFs, and videos, depending on installed tooling.  ￼

Its responsive image support is a major product lesson. It generates srcset/sizes, multiple size variations, and blurred placeholders to avoid layout flicker.  ￼

Spatie also treats regeneration as a first-class Day-2 operation. When conversion definitions change, old generated images are not automatically updated; the package provides commands for regenerating conversions, only missing files, specific conversions, and responsive images.  ￼

Elixir design takeaways:

The killer DX is not just variant(:thumb). It is responsive_image(:card), picture_tag, srcset, blurred placeholders, regeneration tasks, collections, ordering, custom properties, and admin tooling.

Cloudinary / imgproxy / URL-driven transformations

Cloudinary shows the power of URL-based transformations: developers can request derived assets through transformation URLs, generate variations on the fly, and deliver through CDN caching. But Cloudinary also meters transformations, so the economic model matters.  ￼

imgproxy’s key lesson is security: dynamic transformation URLs must be signed. Its docs explicitly warn that unsigned URLs can let attackers request many different resizes and create a denial-of-service/cost problem.  ￼

Elixir design takeaways:

Do not expose arbitrary transformation params by default. Use named presets/recipes and signed URLs. Let advanced users opt into dynamic transforms only with signatures, rate limits, allowlists, max pixel counts, and cache controls.

Uppy / tus / multipart uploads

Modern upload UX expects resumability and direct-to-storage support. Uppy’s tus docs emphasize that tus can resume very large uploads after tab closes or network loss, while Uppy’s S3 docs emphasize direct client-to-storage uploads, multipart upload for files over roughly 100 MiB, parallelism, and recovery of failed parts.  ￼

The tus protocol also has a concatenation extension for parallel chunk uploads, with the important rule that servers should not process partial uploads before final concatenation.  ￼

Elixir design takeaways:

A great Phoenix library should provide a direct-upload broker abstraction, not force all bytes through Phoenix. Support “simple direct upload” first, then S3 multipart and tus as adapters. Store an upload session record and do not attach/process until completion is verified.

S3, R2, GCS provider realities

S3-compatible does not mean identical. Cloudflare R2 implements the S3 API with differences, supports presigned PUT-style direct uploads, and treats presigned URLs as bearer tokens that should have short expirations. R2 does not support POST multipart form uploads through presigned URLs.  ￼

Google Cloud Storage recommends resumable uploads for large files because they can resume after network failure, and its resumable upload flow begins with a POST that returns a session URI used for subsequent PUTs. That session URI acts like an auth token.  ￼

S3 multipart uploads have a cost footgun: uploaded parts are billed until the multipart upload is completed or aborted. AWS recommends lifecycle rules with AbortIncompleteMultipartUpload to minimize storage costs.  ￼

Elixir design takeaways:

The storage layer should have provider-specific capabilities, not just put/3 and url/2. Model capabilities like :presigned_put, :presigned_post, :multipart_upload, :resumable_upload, :head_object, :copy_object, :server_side_encryption, and :public_url.

Mux / Transloadit

Mux and Transloadit are the best references for asynchronous media workflow ergonomics. Mux direct upload returns an authenticated upload URL and upload ID; processing is asynchronous and apps are expected to handle webhooks as assets move from upload complete to video ready.  ￼

Transloadit’s language is also useful: reusable Templates, Assembly executions, Steps, Robots, conditional processing, result JSON, and webhooks that notify the app when processing ends.  ￼

Elixir design takeaways:

Borrow the terms “pipeline”, “step”, “execution”, “result”, and “webhook event”, but make them idiomatic Elixir structs and Ecto records. Heavy video/audio/AI should feel like “enqueue execution and observe state”, not “call a function and block”.

5. Personas and jobs-to-be-done

Persona 1: Phoenix product developer

They want to add avatars, product images, PDFs, private downloads, and gallery uploads quickly. They care about generator-quality docs, copy-paste LiveView examples, Ecto changesets, and predictable errors.

Jobs:

* Attach one file to a schema.
* Attach many files to a collection.
* Show upload progress.
* Validate type, size, dimensions, and duration.
* Render a thumbnail or responsive image.
* Use S3/R2/GCS without becoming a storage expert.

Persona 2: Senior application/platform developer

They need composable abstractions, predictable DB state, custom storage keys, multitenancy, background jobs, retries, migrations, and provider-specific escape hatches.

Jobs:

* Define media profiles per use case.
* Add custom analyzers/processors.
* Run processing asynchronously through Oban.
* Backfill metadata and regenerate variants after recipe changes.
* Move from local disk to S3/R2/GCS.
* Keep asset state correct under concurrent updates.

Persona 3: SRE / DevOps engineer

They care about cost, queues, worker saturation, temp object cleanup, storage growth, CDN/cache behavior, incident debugging, and safe rollouts.

Jobs:

* See processing failure rates, queue latency, object counts, storage bytes, and orphan counts.
* Limit CPU-heavy transforms.
* Retry or quarantine bad files.
* Abort incomplete multipart uploads.
* Run cleanup and verification tasks.
* Know whether a missing variant is a bug, a stale recipe, or expected lazy generation.

Oban is a natural fit here because it is SQL-backed, persistent, observable, and supports transactional job enqueueing with database changes. Its docs emphasize reliability, consistency, observability, historical job data, and avoiding lost/orphaned jobs after crashes.  ￼

Persona 4: Security/compliance engineer

They want strict validation, content sniffing, generated filenames, private storage, signed URLs, authorization, malware scanning hooks, audit trails, and sandboxed processors.

OWASP’s File Upload Cheat Sheet recommends allowlisted extensions, validating file type without trusting Content-Type, generated filenames, size limits, authz/authn, storage outside webroot or on a separate server, CSRF protection, antivirus/CDR where appropriate, and keeping processing libraries patched.  ￼

Persona 5: Admin/content operator

They need a media library UI: inspect uploads, see variants, replace assets, retry failures, crop images, find orphaned files, and understand why a media item is unavailable.

Jobs:

* Browse/search media by owner, filename, type, status, tags, size, date.
* Retry failed variants.
* Regenerate stale variants.
* Replace an asset while preserving references.
* Quarantine or delete unsafe files.
* See storage and usage.

Persona 6: Advanced media/AI developer

They want pipelines that can call FFmpeg, Membrane, Cloudinary, Transloadit, Mux, OpenAI/Whisper-like transcription, moderation APIs, or internal GPU services.

Jobs:

* Compose multi-step pipelines.
* Route work to provider/local processors.
* Persist input/output artifacts.
* Track cost, latency, provider IDs, and webhooks.
* Make AI outputs reviewable before publication.

6. Core domain language

This is the vocabulary I would use consistently in code, docs, events, telemetry, and schema names.

Primary nouns

Media Asset

The canonical domain object representing an uploaded file as the app understands it. It is the durable record for a logical file: content type, byte size, checksum, status, storage location, metadata, security state, and lifecycle timestamps.

Use Asset or MediaAsset, not Upload, once the file has landed. “Upload” is a process/session; “asset” is the thing.

Attachment

The association between an asset and an owner record.

Examples:

User avatar
Product gallery image
Article hero image
Invoice PDF
Message attachment

An asset may be attached to one owner, many owners, or zero owners depending on policy. The attachment owns context: owner schema/id, slot/collection name, ordering, caption, alt text, and per-use custom metadata.

Blob / Object

The physical stored object in local disk, S3, R2, GCS, etc. “Blob” or “Object” is storage-level language. It should not be confused with the logical media asset.

Original / Source

The canonical uploaded object before transformations. For destructive workflows, keep the original unless an explicit policy says otherwise.

Variant

A derived file produced from an original asset using a named recipe.

Examples:

:thumb
:card
:retina
:webp_1024
:admin_preview

Use this mainly for images.

Derivative

A more generic term for a generated output from a source asset. Shrine’s newer language uses derivatives to avoid the limitations of older “versions” thinking.  ￼

Use this when the output may be image, video, audio, text, JSON, caption file, transcript, or AI result.

Representation

A displayable form of an asset, especially when the source is not directly displayable.

Examples:

PDF page preview image
Video thumbnail
Audio waveform image
DOCX rendered preview

Rails Active Storage uses “representation” language for representable blobs such as images, videos, and PDFs.  ￼

Preview

A lightweight representation intended for UI display. Usually lower quality, smaller, and safe to generate eagerly.

Conversion

A transformation that changes format or encoding.

Examples:

JPEG → WebP
PNG → AVIF
MOV → MP4
WAV → MP3
PDF page → PNG

Transcode

Audio/video-specific conversion, usually involving codec/container/bitrate changes.

Pipeline

A declarative workflow of one or more processing steps.

Examples:

analyze → validate_dimensions → generate_thumb → generate_responsive_set
probe_video → extract_thumbnail → transcode_preview → store_playback_metadata
scan → OCR → classify → attach_json_metadata

Step

One unit of work inside a pipeline.

Processor

The implementation that performs a step.

Examples:

Image/Vix processor
FFmpeg processor
Membrane pipeline processor
Cloudinary processor
Transloadit processor
AI moderation processor

Analyzer / Probe

Reads metadata without necessarily producing a new file.

Examples:

image width/height
EXIF orientation
video duration/codec/bitrate
audio duration/sample rate
PDF page count
magic-byte MIME detection

Validator

Enforces policy before an asset becomes available.

Examples:

max bytes
allowed MIME
allowed extension
magic-byte match
max pixels
max duration
min dimensions
reject animated GIF
reject SVG
tenant storage quota

Policy

A reusable ruleset for validation, storage, processing, access, cleanup, and retention.

Profile / Preset / Recipe

A named, versioned declaration of what should happen for a class of media.

Example:

AvatarImage
ProductGalleryImage
PrivateDocument
CourseVideo
PodcastEpisode

The recipe should be hashable. Store recipe_digest on variants so the system can detect stale outputs after code changes.

Upload Session

A temporary record representing an in-progress upload. It may hold provider IDs, signed URL metadata, content-length constraints, expected checksum, client metadata, expiration, and owner intent.

Direct Upload

Client uploads bytes directly to storage or a provider instead of proxying them through Phoenix.

Multipart Upload

S3-style upload of one logical object in multiple parts. Good for large files, but requires completion/abort cleanup because uploaded parts may accrue storage costs.  ￼

Resumable Upload

Upload protocol/session that can continue after interruption. tus and GCS resumable uploads are examples.  ￼

Staged Object / Cache Object

An uploaded object that is not yet attached/promoted. It may be temporary and subject to cleanup.

Permanent Object

An object promoted to durable application storage.

Storage Backend

The adapter: local disk, S3, R2, GCS, Azure, Cloudinary, Mux, Transloadit, etc.

Storage Key / Path Strategy

The deterministic or generated path/key for objects.

Delivery

How the asset is served: public URL, signed URL, proxy, redirect, CDN URL, controller download, or provider playback URL.

Signer

Component that signs upload URLs, download URLs, or transformation URLs.

Access Policy

Rules deciding who can read, write, transform, delete, or regenerate.

Scanner

Security processor such as antivirus, malware scanning, content disarm/reconstruction, moderation, or custom compliance checks.

Quarantine

A state/location for assets that uploaded successfully but failed security or policy checks.

Processing Run / Execution

A persisted attempt to execute a pipeline or step. Includes status, attempt count, logs, started/completed timestamps, error reason, and processor metadata.

Webhook Event

An external callback from Mux, Transloadit, Cloudinary, S3, or another provider.

Tombstone

A DB record or state indicating an asset was deleted while preserving audit/history.

Orphan

A staged object, asset, variant, or physical object that has no valid owner/reference and should be cleaned up or investigated.

Variant Registry / Manifest

The list of expected variants for a profile, including names, recipes, digests, output format, and generation mode.

Important distinctions

Do not collapse these concepts:

Upload Session != Asset
Asset != Attachment
Asset != Blob/Object
Variant != Attachment
Variant Recipe != Variant File
Analyzer != Validator
Processor != Pipeline
Preview != Original
Quarantine != Failed
Deleted != Detached

These distinctions are what make the library robust under retries, direct uploads, async processing, and Day-2 maintenance.

7. Verbs: domain actions

Use clear verbs in public APIs, internal modules, telemetry, and docs.

Upload/session verbs

initiate_upload
sign_upload
reserve_key
stage
receive
complete_upload
verify_upload
abort_upload
expire_upload

Asset lifecycle verbs

create_asset
ingest
validate
analyze
scan
promote
attach
detach
replace
quarantine
reject
mark_available
mark_degraded
purge
tombstone
restore

Processing verbs

plan
enqueue
process
transform
derive
generate
materialize
transcode
extract
render
optimize
normalize
watermark
crop
resize
convert
regenerate
backfill
retry
cancel

Delivery verbs

authorize
sign_url
public_url
private_url
proxy
redirect
stream
download
serve

Maintenance verbs

reconcile
verify_storage
cleanup_orphans
abort_incomplete_uploads
migrate_storage
mirror
repair
reindex
recompute_metadata
mark_stale

8. State machines

Upload session states

initialized
signed
uploading
uploaded
verifying
completed
aborted
expired
failed

Asset states

staged
validating
rejected
quarantined
analyzing
promoting
available
processing
ready
degraded
detached
purging
deleted

Recommended semantics:

* available: original is safely stored and can be downloaded if authorized.
* processing: some required derivatives are still running.
* ready: required derivatives are complete.
* degraded: original is available, but one or more required derivatives failed.
* quarantined: bytes exist, but access is blocked pending security review.
* deleted: logical tombstone; physical purge may still be async.

Variant/derivative states

planned
queued
processing
ready
stale
missing
failed
purging
purged

Recommended semantics:

* stale: recipe digest no longer matches current profile.
* missing: DB expects it, storage does not have it.
* failed: processing attempted and failed.
* planned: known from manifest but not yet materialized.

Processing run states

scheduled
running
succeeded
failed
retrying
cancelled
dead

Oban already gives a strong model for persisted background execution, so your library should avoid inventing a generic job runner. Integrate deeply with Oban and emit your own media-domain events around it. Oban emits Telemetry events for job start/stop/exception and includes useful measurements such as duration, memory, queue time, and reductions.  ￼

9. Events and telemetry language

Phoenix apps already come with Telemetry conventions, and Phoenix-generated apps include Telemetry supervision/metrics setup. A great library should plug into that instead of inventing a separate observability story.  ￼

Recommended Telemetry event names:

[:media, :upload, :initiated]
[:media, :upload, :signed]
[:media, :upload, :completed]
[:media, :upload, :aborted]
[:media, :upload, :expired]
[:media, :asset, :created]
[:media, :asset, :validated]
[:media, :asset, :rejected]
[:media, :asset, :analyzed]
[:media, :asset, :attached]
[:media, :asset, :detached]
[:media, :asset, :promoted]
[:media, :asset, :quarantined]
[:media, :asset, :purged]
[:media, :variant, :requested]
[:media, :variant, :enqueued]
[:media, :variant, :started]
[:media, :variant, :succeeded]
[:media, :variant, :failed]
[:media, :variant, :stale]
[:media, :variant, :purged]
[:media, :delivery, :authorized]
[:media, :delivery, :denied]
[:media, :delivery, :signed_url_created]
[:media, :cleanup, :orphan_detected]
[:media, :cleanup, :orphan_purged]
[:media, :cleanup, :incomplete_upload_aborted]

Suggested event metadata:

%{
  asset_id: binary(),
  attachment_id: binary() | nil,
  variant_id: binary() | nil,
  owner_schema: module() | nil,
  owner_id: term() | nil,
  tenant_id: term() | nil,
  profile: atom(),
  storage: atom(),
  bucket: String.t() | nil,
  key: String.t() | nil,
  content_type: String.t() | nil,
  media_kind: :image | :video | :audio | :document | :archive | :other,
  byte_size: non_neg_integer() | nil,
  processor: atom() | nil,
  recipe_digest: String.t() | nil,
  status: atom(),
  error_kind: atom() | nil
}

Suggested measurements:

%{
  duration: native_time(),
  byte_size: non_neg_integer(),
  output_byte_size: non_neg_integer(),
  queue_time: native_time(),
  retries: non_neg_integer(),
  variants_count: non_neg_integer()
}

SRE-facing metrics to expose in examples:

upload.completed.count
upload.failed.count
upload.bytes
asset.validation.failed.count by reason
asset.quarantined.count
variant.queue_time
variant.duration
variant.failed.count by processor/profile
variant.cache_hit.count
variant.cache_miss.count
storage.bytes by backend/bucket/tenant
cleanup.orphans.count
cleanup.purged.bytes
delivery.denied.count

10. Proposed architecture

Package boundaries

A strong architecture would avoid forcing every user to pull in every dependency.

media_core
  Domain structs, behaviours, Ecto schemas, storage behaviour, policies, recipes.
media_ecto
  Migrations, changeset helpers, attachment associations, query helpers.
media_phoenix
  Plug controllers, LiveView helpers, components, verified route helpers, signed delivery.
media_oban
  Workers, queues, retries, cron cleanup, processing orchestration.
media_image
  Image/Vix/libvips processors, responsive image generation, placeholders.
media_ffmpeg
  FFmpeg/FFmpex-based metadata, thumbnails, audio/video transforms.
media_membrane
  Advanced streaming/transcoding pipelines for users already in Membrane world.
media_s3
  S3-compatible storage, presigned PUT/POST/multipart, lifecycle helpers.
media_r2
  R2-specific storage and direct-upload behavior.
media_gcs
  GCS signed URLs and resumable upload behavior.
media_admin
  Phoenix LiveDashboard page or standalone LiveView admin UI.
media_ai
  Optional provider-backed AI processors.

Core behaviours

defmodule Media.Storage do
  @callback put(source, key, opts) :: {:ok, object} | {:error, reason}
  @callback copy(source_key, dest_key, opts) :: {:ok, object} | {:error, reason}
  @callback delete(key, opts) :: :ok | {:error, reason}
  @callback exists?(key, opts) :: boolean()
  @callback head(key, opts) :: {:ok, metadata} | {:error, reason}
  @callback public_url(key, opts) :: {:ok, url} | {:error, reason}
  @callback signed_url(key, opts) :: {:ok, url} | {:error, reason}
  @callback capabilities() :: MapSet.t(atom())
end
defmodule Media.Processor do
  @callback process(input, recipe, context) ::
              {:ok, [Media.Output.t()]} | {:error, Media.Error.t()}
end
defmodule Media.Analyzer do
  @callback analyze(input, context) ::
              {:ok, map()} | {:error, Media.Error.t()}
end
defmodule Media.Scanner do
  @callback scan(input, context) ::
              :ok | {:quarantine, reason} | {:reject, reason}
end
defmodule Media.Authorizer do
  @callback authorize(user, action, asset_or_attachment, context) ::
              :ok | {:error, :unauthorized}
end

Ecto data model

Use real tables for observability, correctness, and Day-2 operations.

media_assets
  id
  tenant_id
  status
  media_kind
  content_type
  detected_content_type
  extension
  byte_size
  checksum_sha256
  original_filename
  sanitized_filename
  storage
  bucket
  key
  metadata jsonb
  security_status
  profile
  inserted_at
  updated_at
  deleted_at
media_attachments
  id
  asset_id
  owner_schema
  owner_id
  name
  collection
  position
  alt_text
  caption
  custom_metadata jsonb
  inserted_at
  updated_at
media_variants
  id
  asset_id
  name
  status
  recipe_digest
  recipe jsonb
  storage
  bucket
  key
  content_type
  byte_size
  width
  height
  duration_ms
  metadata jsonb
  error_kind
  error_message
  generated_at
  inserted_at
  updated_at
media_upload_sessions
  id
  status
  tenant_id
  profile
  expected_content_type
  expected_byte_size
  expected_checksum
  storage
  bucket
  key
  provider_upload_id
  provider_metadata jsonb
  expires_at
  completed_at
  inserted_at
  updated_at
media_processing_runs
  id
  asset_id
  variant_id
  upload_session_id
  kind
  processor
  status
  attempt
  idempotency_key
  input jsonb
  output jsonb
  error_kind
  error_message
  started_at
  completed_at
  inserted_at
  updated_at

Why not just store variant info in one JSON column? Because admins, SREs, retries, cleanup jobs, stale variant detection, per-variant failures, dashboards, and migrations all need queryable state.

Recipe/profile DSL

The public API should feel Elixir-native: explicit modules, compile-time validation where useful, runtime structs where necessary.

Example:

defmodule MyApp.Media.Avatar do
  use Media.Profile
  accepts :image,
    extensions: ~w(.jpg .jpeg .png .webp),
    content_types: ~w(image/jpeg image/png image/webp),
    max_bytes: 8 * 1024 * 1024,
    min_dimensions: {128, 128},
    max_pixels: 20_000_000
  storage :private_uploads
  delivery :signed, expires_in: {15, :minutes}
  analyze with: MediaImage.Analyzers.Basic
  scan with: MyApp.Media.Scanners.ClamAV, mode: :async
  variants do
    image :thumb,
      width: 160,
      height: 160,
      fit: :cover,
      format: :webp,
      quality: 82,
      mode: :eager
    image :profile,
      width: 512,
      height: 512,
      fit: :cover,
      format: :webp,
      quality: 86,
      mode: :eager
    image :original_web,
      width: 2048,
      fit: :inside,
      format: :webp,
      quality: 88,
      mode: :lazy
  end
end

For video:

defmodule MyApp.Media.CourseVideo do
  use Media.Profile
  accepts :video,
    content_types: ~w(video/mp4 video/quicktime video/webm),
    max_bytes: 2 * 1024 * 1024 * 1024,
    max_duration: {:minutes, 90}
  storage :video_originals
  delivery :private
  analyze with: MediaFFmpeg.Analyzers.FFprobe
  derivatives do
    preview_image :poster,
      at: {:percent, 10},
      width: 1280,
      format: :jpg,
      mode: :eager
    video :preview_clip,
      duration: {:seconds, 10},
      format: :mp4,
      mode: :async
  end
end

For AI:

defmodule MyApp.Media.ProductImage do
  use Media.Profile
  accepts :image, max_bytes: 15 * 1024 * 1024
  variants do
    image :card, width: 800, height: 800, fit: :cover, format: :webp
  end
  ai do
    metadata :alt_text, with: MyApp.AI.AltText, mode: :review_required
    moderation :safety, with: MyApp.AI.ImageModeration, mode: :blocking
    image :background_removed, with: MyApp.AI.BackgroundRemoval, mode: :manual
  end
end

11. Public API shape

Attach from a standard Phoenix upload

{:ok, asset} =
  Media.attach(upload,
    owner: user,
    name: :avatar,
    profile: MyApp.Media.Avatar
  )

Direct upload flow

{:ok, session} =
  Media.initiate_upload(
    profile: MyApp.Media.Avatar,
    owner: user,
    filename: "me.jpg",
    content_type: "image/jpeg",
    byte_size: 1_234_567
  )
{:ok, signed} = Media.sign_upload(session)
# client uploads directly
{:ok, asset} =
  Media.complete_upload(session,
    owner: user,
    attach_as: :avatar
  )

Render URLs

Media.url(asset)
Media.url(asset, variant: :thumb)
Media.signed_url(asset, expires_in: {10, :minutes})
Media.picture_tag(asset, :card, alt: "Product photo")

Regenerate and repair

Media.mark_stale(MyApp.Media.Avatar, variant: :thumb)
Media.regenerate_variants(
  profile: MyApp.Media.Avatar,
  only: [:thumb],
  mode: :missing_or_stale
)
Media.cleanup_orphans(older_than: {24, :hours})
Media.verify_storage(profile: MyApp.Media.Avatar)

12. Security requirements

Security should be a headline feature, not an appendix.

Minimum default posture:

deny unknown file types
allowlist extensions and MIME types
sniff magic bytes
generate storage filenames
never trust user filename for paths
enforce byte-size limits before and after upload
enforce image pixel-count limits
enforce video/audio duration limits
strip dangerous metadata by default where possible
serve private files through signed URLs or authorized proxy
make processors sandboxable
make SVG/PDF/office/archive handling opt-in
support scanner hooks
log audit events

OWASP specifically recommends allowlisting extensions, validating file type without trusting Content-Type, changing filenames to application-generated values, setting filename length/size limits, applying authorization, storing outside webroot or on separate infrastructure, using AV/CDR where applicable, keeping libraries updated, and protecting upload forms from CSRF.  ￼

ImageMagick and FFmpeg deserve special caution. ImageMagick has a long security history around untrusted inputs, with ImageTragick being the classic example of remote code execution risks in user-submitted image processing; ImageMagick itself documents the security-vs-convenience tradeoff and supports restrictive security policies.  ￼

FFmpeg is powerful but should be treated as hostile-input native code. FFmpeg’s own security page has historically emphasized that many issues can be exploitable when remote files are processed, and sandboxing guidance commonly recommends isolating FFmpeg with restricted filesystem, network, syscalls, CPU, and memory.  ￼

Practical default: use libvips for standard image transforms; keep ImageMagick/Ghostscript/PDF/SVG/video processors behind explicit opt-in and document container/sandbox examples.

13. Correctness requirements and footguns to avoid

Race: user replaces an upload while background job runs

Shrine’s atomic_promote pattern is the model: reload the record, verify the attachment still matches, then write. If it changed, stop rather than overwriting the new attachment with an old job result.  ￼

Elixir design:

processing run has asset_id + attachment_version + recipe_digest
job reloads attachment
job verifies asset/attachment still current
job writes variant with unique(asset_id, variant_name, recipe_digest)
job becomes no-op if stale

Lazy variant DoS

Do not let attackers create unbounded variants. imgproxy’s docs explicitly warn that unsigned dynamic resizing can be abused to request many different resizes.  ￼

Elixir design:

default: named variants only
advanced: signed dynamic transforms
required: max dimensions, max pixels, max output bytes, rate limits

Direct upload orphans

Direct upload improves scalability, but staged uploads will be abandoned. Shrine explicitly notes cache/temp files are not automatically deleted and need cleanup or storage lifecycle rules.  ￼

Elixir design:

media_upload_sessions.expires_at
cleanup job deletes expired staged objects
admin dashboard shows orphan count
storage lifecycle docs for S3/R2/GCS

Multipart cost leak

S3 multipart uploads must be completed or aborted; otherwise uploaded parts may keep accruing cost. AWS recommends lifecycle rules for incomplete multipart uploads.  ￼

Elixir design:

storage adapter exposes abort_incomplete_multipart_uploads/1 when possible
docs include bucket lifecycle setup
telemetry includes incomplete upload cleanup counts

Processing inside HTTP requests

Heavy processing during request/response causes timeouts, bad UX, and unreliable failure semantics. Active Storage warns not to process variants inline in templates because it requires downloading the whole blob.  ￼

Elixir design:

small sync transformations only for explicitly safe local cases
default eager variants run via Oban
lazy variants enqueue/redirect/poll instead of blocking indefinitely

Purging inside DB transactions

Storage deletion is remote I/O and may fail after DB state changes. Active Storage warns against purge inside transactions/callbacks.  ￼

Elixir design:

detach in DB transaction
enqueue purge job after commit
make purge idempotent
preserve tombstone/audit record

14. Tradeoff matrix

Eager vs lazy variants

Eager is best for required UI assets: avatars, thumbnails, card images. It gives predictable user experience and failure visibility.

Lazy is best for long-tail sizes or admin-only outputs. It saves compute/storage but needs signatures, rate limits, cache controls, and a good first-request UX.

Recommended default: eager for required variants, signed lazy for optional variants.

Direct-to-storage vs Phoenix-proxied upload

Phoenix-proxied is simple, easy to validate early, and good for small files.

Direct-to-storage reduces app-server bandwidth/CPU and is better for large files, but shifts validation later and introduces CORS, signed URLs, staged objects, completion verification, and cleanup.

Recommended default: support both; docs should recommend direct upload for large files and Phoenix-proxied for small/simple apps.

JSON metadata vs normalized tables

JSON only is faster to implement and flexible.

Normalized tables support admin UI, retries, stale detection, cleanup, reporting, and robust migrations.

Recommended default: normalized core tables with metadata JSONB for extensibility.

libvips/NIF vs CLI processors

libvips via Image/Vix is fast and memory-efficient for common image operations.  ￼

CLI processors such as FFmpeg/ImageMagick offer broad capabilities and process isolation but create installation, sandboxing, timeout, stdout/stderr, and portability issues.

Recommended default: libvips for images; CLI/provider adapters behind behaviours for advanced media.

Built-in storage vs provider adapters

A generic storage behaviour is necessary, but provider-specific capability detection is what makes the UX excellent. R2, S3, and GCS differ in direct-upload and resumable semantics, so the library should expose capabilities instead of pretending every backend is the same.  ￼

15. What would make this “the ultimate lib”

Day 0: discovery and install

The README should make the value obvious in 60 seconds:

mix phx.gen.media
mix ecto.migrate

Then:

has_one_media :avatar, MyApp.Media.Avatar
has_many_media :photos, MyApp.Media.ProductPhoto

And a LiveView example that uploads, validates, attaches, and renders a thumbnail.

Day 1: productive app development

Must-have features:

Ecto associations and changeset helpers
LiveView upload components
direct upload broker for S3/R2/GCS
local dev storage
test storage
Image/Vix variants
responsive images
signed URLs
Oban processing
Telemetry events
clear validation errors
copy-paste docs

Day 2: operations

This is where most libraries are weak. Ship these early:

mix media.cleanup_orphans
mix media.regenerate_variants
mix media.verify_storage
mix media.backfill_metadata
mix media.migrate_storage
mix media.abort_incomplete_uploads
mix media.audit

Admin UI:

asset search
owner lookup
variant status
processing run logs
retry failed
regenerate stale
quarantine/release
delete/purge
storage usage summary
orphan browser

Advanced use cases

multitenant storage policies
per-profile queues
custom path strategies
custom analyzers
custom processors
provider offload
webhook ingestion
AI metadata/transform steps
access-control callbacks
CDN URL rewriting
audit log integration

16. Documentation plan

Docs should be recipe-driven, not just API reference.

Essential guides:

Getting started with local storage
Phoenix controller upload
Phoenix LiveView upload
Direct upload to S3
Direct upload to Cloudflare R2
Direct/resumable upload to GCS
Private downloads with signed URLs
Avatars and thumbnails
Product gallery with ordering
Responsive images and placeholders
PDF previews
Video thumbnail extraction
Background processing with Oban
Security hardening checklist
Storage lifecycle cleanup
Regenerating variants after recipe changes
Migrating from Waffle/Arc
Testing uploads
Writing a custom storage adapter
Writing a custom processor
Writing a custom analyzer
Admin UI setup
Telemetry and metrics

Release engineering should be polished. Release Please is a good fit for changelog/version/release PR automation because it parses Conventional Commits and creates release PRs, but it does not publish packages by itself; Hex publishing still needs a separate CI step.  ￼

17. Test and CI strategy

The spec suite should prove lifecycle correctness, not just function outputs.

Unit tests

profile DSL validation
recipe digest stability
storage key generation
filename sanitization
MIME/extension validation
magic-byte detection
policy decisions
signed URL expiration
variant manifest diffing
state transitions

Integration tests

local storage end-to-end
S3-compatible storage via MinIO or LocalStack
direct upload sign → upload → complete
Oban processing
variant generation
cleanup expired staged uploads
purge job idempotency

Security tests

spoofed extension
spoofed Content-Type
path traversal filename
oversized upload
oversized image dimensions
decompression-bomb-style image fixture
animated image policy
SVG rejection by default
expired signed upload
unauthorized download
dynamic transform signature failure

Media correctness tests

golden image dimensions
format conversion
EXIF orientation handling
transparent PNG behavior
animated GIF policy
video probe fixture
thumbnail extraction fixture
audio duration fixture

Failure/retry tests

processor timeout
storage put failure
storage delete failure
job retry
stale job no-op
concurrent attachment replacement
missing object reconciliation
variant record exists but object missing

18. MVP feature cut

A strong v1 should be narrow but complete.

Include in v1

Ecto schema + migrations for assets/attachments/variants/upload sessions
local storage
S3-compatible storage with presigned PUT
Cloudflare R2 docs/adapter behavior
Phoenix controller + LiveView examples
Image/Vix processor
named variants
responsive image helper
Oban workers
Telemetry events
signed delivery URLs
validation policies
magic-byte detection adapter
cleanup expired upload sessions
regenerate variants task
basic admin LiveView or LiveDashboard page

Include soon after v1

GCS resumable upload adapter
S3 multipart upload adapter
PDF preview adapter
FFmpeg thumbnail/audio/video probe adapter
provider webhooks
storage migration/mirroring
AI metadata processors

Avoid in v1

full HLS/DASH streaming platform
arbitrary unauthenticated dynamic transforms
built-in GPU/AI runtime
office document conversion by default
SVG/PDF processing without sandbox docs
global CDN product ambitions

19. One-sentence product positioning

A Phoenix/Ecto-native media lifecycle library for uploads, attachments, variants, previews, background processing, secure delivery, observability, and Day-2 operations.

Or more developer-facing:

ActiveStorage/Shrine/Spatie-style media management for Phoenix, built on Ecto, LiveView, Oban, Telemetry, and modern image/video processing adapters.

20. Design principles to keep the project from becoming a mess

Media-agnostic core, image-first implementation.
Profiles are explicit modules, not global magic.
Variants are records, not hidden filenames.
Recipes are versioned and digestible.
Processing is idempotent.
Storage I/O is not hidden inside DB transactions.
Direct uploads are sessions, not blind presigned URLs.
Security defaults are strict.
Dynamic transforms are signed or disabled.
Day-2 tasks are first-class.
Telemetry is part of the public contract.
Adapters expose capabilities.
Admin UI is not an afterthought.
Docs teach real Phoenix workflows.

The winning library will be the one that feels boringly reliable in production while still feeling delightful in the first 15 minutes.