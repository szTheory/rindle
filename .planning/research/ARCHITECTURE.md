# Architecture Research

**Domain:** Phoenix/Elixir media lifecycle library
**Researched:** 2026-04-24
**Confidence:** HIGH (derived from PROJECT.md, reference implementations, and Elixir/OTP idioms)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Phoenix Host Application                       │
│  ┌─────────────────┐  ┌──────────────────────┐  ┌────────────────┐  │
│  │  LiveView Upload │  │  Controller Upload   │  │  Direct Upload │  │
│  │  (proxied)       │  │  (proxied)           │  │  (presigned)   │  │
│  └────────┬─────────┘  └──────────┬───────────┘  └───────┬────────┘  │
└───────────┼────────────────────────┼────────────────────────┼─────────┘
            │                        │                        │
┌───────────┴────────────────────────┴────────────────────────┴─────────┐
│                          Rindle Public API                             │
│  Rindle.upload/2   Rindle.attach/3   Rindle.url_for/2   Rindle.purge/2│
└───────────────────────────────────────────────────────────────────────┘
            │
┌───────────┴────────────────────────────────────────────────────────────┐
│                         Domain Core Layer                               │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ Upload       │  │ Asset        │  │ Variant      │  │ Delivery   │ │
│  │ Session FSM  │  │ FSM          │  │ FSM          │  │ Layer      │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘ │
│         │                 │                  │                │        │
│  ┌──────┴─────────────────┴──────────────────┴────────────────┴──────┐ │
│  │                    Rindle.Core (shared domain logic)               │ │
│  │  Profile DSL · Recipe Digest · MIME Detection · Key Generation     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
            │                         │                       │
┌───────────┴──────┐   ┌──────────────┴──────────┐  ┌────────┴──────────┐
│  Behaviour Layer │   │  Background Job Layer    │  │  Telemetry Layer  │
│                  │   │                          │  │                   │
│  Rindle.Storage  │   │  Oban Workers:           │  │  :telemetry       │
│  Rindle.Processor│   │  - ProcessVariantWorker  │  │  events (public   │
│  Rindle.Analyzer │   │  - PromoteAssetWorker    │  │  contract API)    │
│  Rindle.Scanner  │   │  - PurgeStorageWorker    │  │                   │
│  Rindle.Authorizer│  │  - CleanupOrphansWorker  │  │  [:rindle, :*]    │
└──────────────────┘   └──────────────────────────┘  └───────────────────┘
            │
┌───────────┴────────────────────────────────────────────────────────────┐
│                         Adapter Layer                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐   │
│  │ Rindle.Storage.  │  │ Rindle.Storage.  │  │ Rindle.Processor.  │   │
│  │ Local            │  │ S3               │  │ Vix (default)      │   │
│  └──────────────────┘  └──────────────────┘  └────────────────────┘   │
│  ┌──────────────────┐  ┌──────────────────┐                            │
│  │ Rindle.Storage.  │  │ Rindle.Processor.│  (opt-in, not in core)    │
│  │ GCS (future)     │  │ FFmpeg / Magick  │                            │
│  └──────────────────┘  └──────────────────┘                            │
└────────────────────────────────────────────────────────────────────────┘
            │
┌───────────┴────────────────────────────────────────────────────────────┐
│                    Data Layer (PostgreSQL via Ecto)                     │
│  media_assets  │  media_attachments  │  media_variants                 │
│  media_upload_sessions              │  media_processing_runs           │
└────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `Rindle` (public API) | Single entry point for host apps — upload, attach, url_for, purge | Thin facade delegating to domain modules |
| Upload Session FSM | Tracks direct upload lifecycle: initialized → signed → uploading → verified → completed | Ecto state machine on `media_upload_sessions` |
| Asset FSM | Tracks blob lifecycle: staged → validating → analyzing → promoting → available → ready/degraded/quarantined/deleted | Ecto state machine on `media_assets` |
| Variant FSM | Tracks per-named-variant state: planned → queued → processing → ready/stale/missing/failed/purged | Ecto state machine on `media_variants` |
| `Rindle.Profile` (DSL) | Compile-time recipe definition with digest computation for stale detection | `use Rindle.Profile` macro |
| `Rindle.Storage` behaviour | Capability-aware storage abstraction (presigned_put, delete, url) | Behaviour + adapter pattern |
| `Rindle.Processor` behaviour | Named variant generation against a recipe | Behaviour + Vix default |
| `Rindle.Analyzer` behaviour | Extracts metadata from raw bytes (dimensions, duration, MIME) | Behaviour with file/magic byte impl |
| `Rindle.Scanner` behaviour | Security scanning hook (AV, content policy) | Behaviour (no-op default) |
| `Rindle.Authorizer` behaviour | Delivery authorization for signed URLs | Behaviour (host app implements) |
| Oban workers | Durable async processing, purge, cleanup, promotion | Standard Oban `perform/1` callbacks |
| Telemetry layer | Emit structured events at asset/variant/upload/delivery/cleanup boundaries | `:telemetry.execute/3` with public-contract metadata |
| Mix tasks | Day-2 operations (cleanup, regenerate, verify, abort, backfill) | `mix rindle.*` tasks invoking core domain |

## Recommended Project Structure

```
lib/
├── rindle.ex                    # Public facade API
├── rindle/
│   ├── profile.ex               # Profile DSL (use Rindle.Profile macro)
│   ├── recipe.ex                # Recipe struct + digest computation
│   │
│   ├── domain/
│   │   ├── asset.ex             # MediaAsset schema + FSM transitions
│   │   ├── attachment.ex        # MediaAttachment schema (polymorphic join)
│   │   ├── variant.ex           # MediaVariant schema + FSM transitions
│   │   ├── upload_session.ex    # UploadSession schema + FSM transitions
│   │   └── processing_run.ex    # ProcessingRun schema (audit log)
│   │
│   ├── core/
│   │   ├── mime.ex              # Magic-byte MIME detection (no client trust)
│   │   ├── key.ex               # Storage key generation (no user-controlled paths)
│   │   ├── validator.ex         # Allowlist validation (extension, MIME, size, pixels)
│   │   └── digest.ex            # Recipe digest computation (stable hash)
│   │
│   ├── upload/
│   │   ├── broker.ex            # Direct upload: sign → verify → attach
│   │   └── proxy.ex             # Phoenix-proxied upload path
│   │
│   ├── processing/
│   │   ├── pipeline.ex          # Variant generation orchestration
│   │   └── promote.ex           # Atomic promote (reload → verify → write)
│   │
│   ├── delivery/
│   │   ├── signer.ex            # Signed URL generation
│   │   └── public.ex            # Public delivery (explicit opt-in only)
│   │
│   ├── telemetry.ex             # Telemetry event emission (public contract)
│   │
│   ├── behaviours/
│   │   ├── storage.ex           # Rindle.Storage behaviour
│   │   ├── processor.ex         # Rindle.Processor behaviour
│   │   ├── analyzer.ex          # Rindle.Analyzer behaviour
│   │   ├── scanner.ex           # Rindle.Scanner behaviour
│   │   └── authorizer.ex        # Rindle.Authorizer behaviour
│   │
│   ├── storage/
│   │   ├── local.ex             # Local disk adapter
│   │   └── s3.ex                # S3-compatible adapter (presigned PUT)
│   │
│   ├── processor/
│   │   └── vix.ex               # Image/Vix (libvips) adapter (default)
│   │
│   ├── workers/
│   │   ├── process_variant.ex   # Oban worker: generate named variant
│   │   ├── promote_asset.ex     # Oban worker: promote staged → available
│   │   ├── purge_storage.ex     # Oban worker: async storage delete (idempotent)
│   │   └── cleanup_orphans.ex   # Oban worker: cron-driven orphan cleanup
│   │
│   └── phoenix/
│       ├── controller_helpers.ex # Controller upload helpers
│       ├── live_view_helpers.ex  # LiveView upload hooks
│       └── html.ex              # picture_tag/3, srcset helpers
│
priv/
└── repo/migrations/             # Ecto migrations for all Rindle tables

mix/
├── tasks/
│   ├── rindle.cleanup_orphans.ex
│   ├── rindle.regenerate_variants.ex
│   ├── rindle.verify_storage.ex
│   ├── rindle.abort_incomplete_uploads.ex
│   └── rindle.backfill_metadata.ex
│
test/
├── rindle/
│   ├── domain/                  # Unit tests for FSMs and schemas
│   ├── core/                    # Unit tests for MIME, validator, key, digest
│   ├── upload/                  # Integration tests for upload paths
│   ├── processing/              # Integration tests for variant pipeline
│   ├── storage/                 # Adapter tests against MinIO/LocalStack
│   └── workers/                 # Oban worker tests
└── support/
    ├── fixtures.ex
    └── storage_sandbox.ex       # Storage adapter test sandbox
```

### Structure Rationale

- **`rindle/domain/`:** All Ecto schemas and state machine transitions live here. These are the queryable records that make Day-2 operations possible.
- **`rindle/core/`:** Pure functions with no side effects — MIME detection, key generation, validation, digest. Easily unit-tested; no DB or storage dependency.
- **`rindle/behaviours/`:** Separated from adapters so the contract is clear and host apps can implement custom adapters without pulling in adapter dependencies.
- **`rindle/storage/` and `rindle/processor/`:** Concrete adapter implementations, each as optional dependencies at the library level.
- **`rindle/workers/`:** Oban workers are the only place where async processing happens. No `Task.async` or `GenServer` process pools invented.
- **`rindle/phoenix/`:** Phoenix integration helpers are optional — the library works without Phoenix, but these make the integration ergonomic.
- **`mix/tasks/`:** Day-2 operations as Mix tasks so they are scriptable, composable with shell pipelines, and runnable from CI.

## Architectural Patterns

### Pattern 1: Behaviour + Adapter (Storage / Processor)

**What:** Define a behaviour module declaring the contract, then ship one or more concrete adapters. Host apps configure which adapter to use.

**When to use:** Any I/O boundary where the host app needs to swap implementations (local vs. S3, Vix vs. FFmpeg).

**Trade-offs:** Adds one indirection layer; pays for itself when adopters need custom adapters or when testing with a stub.

**Example:**
```elixir
# Behaviour contract
defmodule Rindle.Storage do
  @type capability :: :presigned_put | :multipart_upload | :resumable_upload

  @callback capabilities() :: [capability()]
  @callback put(key :: String.t(), content :: iodata(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}
  @callback delete(key :: String.t()) :: :ok | {:error, term()}
  @callback presigned_put_url(key :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}
end

# Adapter
defmodule Rindle.Storage.Local do
  @behaviour Rindle.Storage

  @impl true
  def capabilities, do: [:presigned_put]  # simulated for dev parity

  @impl true
  def put(key, content, _opts) do
    path = Path.join(base_dir(), key)
    File.mkdir_p!(Path.dirname(path))
    File.write(path, content)
    {:ok, key}
  end
end
```

### Pattern 2: Ecto-backed State Machine (FSM)

**What:** Asset, variant, and upload session state is stored as a string column in PostgreSQL. Transitions are explicit function calls that validate the transition is legal before calling `Ecto.Changeset` and `Repo.update`.

**When to use:** Any lifecycle entity that needs queryable state — which is every core domain object in Rindle.

**Trade-offs:** No implicit transitions; all state changes are auditable and SQL-queryable. Slightly more verbose than a process-based FSM, but survives crashes and restarts.

**Example:**
```elixir
defmodule Rindle.Domain.Asset do
  use Ecto.Schema

  @valid_transitions %{
    "staged"     => ["validating"],
    "validating" => ["analyzing", "quarantined"],
    "analyzing"  => ["promoting"],
    "promoting"  => ["available"],
    "available"  => ["processing", "deleted"],
    "processing" => ["ready", "degraded", "failed"],
    "ready"      => ["processing", "deleted"],
    "degraded"   => ["processing", "deleted"],
    "quarantined"=> ["deleted"]
  }

  def transition(%__MODULE__{} = asset, to_state) do
    allowed = Map.get(@valid_transitions, asset.state, [])
    if to_state in allowed do
      asset
      |> Ecto.Changeset.change(state: to_state)
      |> Rindle.Repo.update()
    else
      {:error, {:invalid_transition, asset.state, to_state}}
    end
  end
end
```

### Pattern 3: Transactional Job Enqueueing (Oban + Ecto.Multi)

**What:** Enqueue Oban jobs inside the same database transaction as the state change that triggered them. If the transaction rolls back, the job is never enqueued.

**When to use:** Every async operation — variant generation, storage purge, promotion. This is how you avoid "job enqueued but state never changed" and "state changed but job lost" split-brain scenarios.

**Trade-offs:** Requires Oban (it IS required). No benefit if you're using a non-SQL job backend.

**Example:**
```elixir
def enqueue_variant_generation(asset, variant_name) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:variant, plan_variant_changeset(asset, variant_name))
  |> Oban.insert(:job, Rindle.Workers.ProcessVariant.new(%{
      asset_id: asset.id,
      variant_name: variant_name
    }))
  |> Rindle.Repo.transaction()
end
```

### Pattern 4: Atomic Promote (Reload + Verify Before Write)

**What:** Before a background worker writes variant output or promotes a staged asset, it reloads the record from DB and verifies the attachment FK hasn't changed. If the user replaced the upload between job start and job completion, the stale job aborts without overwriting the new upload.

**When to use:** Every async promotion/variant worker. Non-negotiable for correctness under concurrent replacement.

**Trade-offs:** Extra DB read per worker execution. The cost is negligible compared to the correctness guarantee.

**Example:**
```elixir
def perform(%Oban.Job{args: %{"asset_id" => id, "variant_name" => name}}) do
  asset = Rindle.Repo.get!(Rindle.Domain.Asset, id)
  variant = Rindle.Domain.Variant.get_planned!(asset, name)

  # Reload to verify attachment hasn't been replaced since job was enqueued
  current = Rindle.Repo.get!(Rindle.Domain.Asset, id)
  if current.attachment_key != asset.attachment_key do
    # Stale job — a new upload replaced this asset; discard silently
    :ok
  else
    generate_and_store_variant(current, variant)
  end
end
```

### Pattern 5: Async Purge (Detach in TX, Delete After Commit)

**What:** When purging an attachment, the DB detach (nulling the FK or soft-deleting the record) happens inside the transaction. The storage delete is enqueued as an Oban job only after the transaction commits successfully. Storage I/O never runs inside a DB transaction.

**When to use:** All purge operations. Putting storage I/O inside a transaction is how you get transaction timeouts from slow storage or orphaned storage objects from transaction rollback.

**Trade-offs:** Purge is eventually consistent (storage object lingers briefly after DB detach). This is acceptable — the object is inaccessible since no URL points to it after the DB change.

**Example:**
```elixir
def purge_attachment(asset) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:asset, detach_changeset(asset))
  |> Oban.insert(:purge_job, Rindle.Workers.PurgeStorage.new(%{key: asset.storage_key}))
  |> Rindle.Repo.transaction()
end
```

## Data Flow

### Direct Upload Flow

```
Client
  │── POST /uploads/initiate ──────────────────────────────────┐
  │                                                              ▼
  │                                                    Rindle.Upload.Broker
  │                                                    creates UploadSession(initialized)
  │                                                    calls storage.presigned_put_url/2
  │                                                    transitions session → signed
  │◄── {session_id, presigned_url} ────────────────────────────┘
  │
  │── PUT {presigned_url} ──────────────────────────────────────► Storage Provider
  │                                                                (S3 / R2 / GCS)
  │
  │── POST /uploads/complete ──────────────────────────────────┐
  │                                                              ▼
  │                                                    Rindle.Upload.Broker
  │                                                    transitions session → uploaded
  │                                                    calls MIME detection (magic bytes)
  │                                                    runs allowlist validation
  │                                                    transitions session → verifying
  │                                                    creates MediaAsset(staged)
  │                                                    transitions asset → validating
  │                                                    enqueues PromoteAssetWorker (in TX)
  │◄── {asset_id} ─────────────────────────────────────────────┘
  │
  │                          [Oban: PromoteAssetWorker]
  │                                    │
  │                          atomic promote (reload + verify)
  │                          transitions asset: analyzing → promoting → available
  │                          enqueues ProcessVariantWorker for each recipe variant (in TX)
```

### Variant Generation Flow

```
[Oban: ProcessVariantWorker]
        │
        ├── reload asset, verify attachment unchanged (atomic promote check)
        ├── transition variant: queued → processing
        ├── fetch source from storage (stream, do not buffer entire file if avoidable)
        ├── call Rindle.Processor.generate/3 (Vix by default)
        ├── put result to storage via Rindle.Storage.put/3
        ├── transition variant: processing → ready
        └── emit [:rindle, :variant, :ready] telemetry
```

### Signed Delivery Flow

```
Client
  │── GET /media/{signed_token} ──────────────────────────────┐
  │                                                             ▼
  │                                                   Rindle.Delivery.Signer
  │                                                   verifies token signature
  │                                                   calls Rindle.Authorizer.authorize/2
  │                                                   resolves variant URL from DB
  │                                                   generates presigned GET URL
  │◄── 302 redirect to presigned storage URL ──────────────────┘
```

### Telemetry Event Flow

```
Domain Operation (upload, promote, variant generate, deliver, cleanup)
        │
        ├── :telemetry.execute([:rindle, :asset, :promoted], %{duration: ...}, %{asset_id: ...})
        ├── :telemetry.execute([:rindle, :variant, :ready],  %{duration: ...}, %{variant_id: ...})
        ├── :telemetry.execute([:rindle, :upload, :completed], %{}, %{session_id: ...})
        └── :telemetry.execute([:rindle, :delivery, :signed], %{}, %{asset_id: ..., variant: ...})

Host App attaches handlers:
  :telemetry.attach("rindle-metrics", [:rindle, :asset, :promoted], &MyApp.Metrics.handle/4, nil)
```

## Key Data Flows

1. **Upload → Promote → Variants:** Upload session gates processing. Promotion only after magic-byte verification. Variant jobs only after promotion. Each transition is atomic.
2. **Replace Upload:** New upload creates new session/asset. Background workers for old asset detect attachment replacement via atomic promote check and abort cleanly.
3. **Stale Variant Detection:** Recipe digest stored at variant creation time. On each access or cron sweep, digest recomputed from profile; mismatch marks variant `stale` and enqueues regeneration.
4. **Signed Delivery:** No storage URL is returned without going through `Rindle.Authorizer`. Default is private-only; public delivery requires explicit `allow_public: true` in profile.

## DB Schema

```
media_upload_sessions
  id, state, storage_key, content_type, byte_size,
  presigned_url, presigned_expires_at, profile,
  inserted_at, updated_at, completed_at, expires_at

media_assets
  id, state, storage_key, content_type, byte_size,
  filename, metadata (jsonb — analysis results only),
  recipe_digest, profile,
  inserted_at, updated_at

media_attachments
  id, asset_id → media_assets,
  subject_type (polymorphic), subject_id,
  field_name, position,
  inserted_at, updated_at

media_variants
  id, asset_id → media_assets,
  name, state, storage_key, content_type, byte_size,
  recipe_digest, metadata (jsonb),
  inserted_at, updated_at

media_processing_runs
  id, asset_id → media_assets, variant_id → media_variants (nullable),
  worker, status, error, duration_ms,
  inserted_at, completed_at
```

**Index strategy:**
- `media_attachments(subject_type, subject_id, field_name)` — polymorphic lookup
- `media_variants(asset_id, name)` — unique; variant lookup by name
- `media_variants(state)` — cleanup and regeneration queries
- `media_upload_sessions(state, expires_at)` — expired session cleanup
- `media_assets(state)` — reconciliation and cleanup

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0–10k assets | Default config fine; local storage for dev; S3 for prod; single Oban queue |
| 10k–1M assets | Partition Oban queues by job type (`:rindle_process`, `:rindle_purge`, `:rindle_cleanup`); add DB indexes on cleanup queries; consider CDN in front of storage |
| 1M+ assets | Storage key sharding strategy (prefix by date or hash bucket); dedicated Oban node for media processing; telemetry aggregation into separate timeseries store |

### Scaling Priorities

1. **First bottleneck: variant processing throughput** — Oban concurrency settings for `process_variant` queue. Vix (libvips) is already memory-efficient; tune `:concurrency` before adding nodes.
2. **Second bottleneck: DB query performance on cleanup/reconciliation** — Add partial indexes on state columns. Consider archiving completed processing_runs.
3. **Third bottleneck: signed URL generation latency** — Cache presigned URLs with TTL slightly shorter than the presigned URL expiry.

## Anti-Patterns

### Anti-Pattern 1: Synchronous Variant Generation in Request Path

**What people do:** Generate image variants during the HTTP request that serves the upload confirmation, or (worse) during the request that first serves the image.

**Why it's wrong:** Variant generation with libvips is fast but not instant. Large images, many variants, or concurrent uploads will blow request timeouts. Active Storage's lazy redirect pattern exists specifically because early Rails users burned themselves doing this.

**Do this instead:** Enqueue `ProcessVariantWorker` transactionally on promotion. Serve a placeholder or omit the variant URL until state is `ready`. Design UI to handle missing variants gracefully.

### Anti-Pattern 2: Storage I/O Inside Ecto Transactions

**What people do:** Call `Storage.put/2` or `Storage.delete/2` inside an `Ecto.Multi` or `Repo.transaction` block.

**Why it's wrong:** Storage I/O can be slow (network), fail independently of the DB, or succeed when the DB transaction rolls back — leaving orphaned objects. Active Storage had this bug in early versions.

**Do this instead:** Always use the async purge pattern: detach in transaction, enqueue `PurgeStorageWorker` via `Oban.insert` in the same `Ecto.Multi`. Storage side effects happen only after the transaction commits.

### Anti-Pattern 3: Trusting Client-Provided MIME/Filename

**What people do:** Use `conn.params["content_type"]` or the `Content-Type` header from the upload for MIME classification.

**Why it's wrong:** Clients lie. A malicious actor can upload an executable or SVG-with-script with `Content-Type: image/jpeg`. This is the vector for stored XSS and malware hosting.

**Do this instead:** Always run magic-byte detection (`Rindle.Core.Mime.detect/1`) after the upload is received and before promotion. Allowlist strictly: if detected MIME is not in the profile's `allowed_types`, quarantine and reject.

### Anti-Pattern 4: Unbounded Dynamic Transforms

**What people do:** Accept arbitrary `width` and `height` query parameters and generate on-the-fly variants for each combination.

**Why it's wrong:** Attackers flood unique dimension combinations, exhausting storage and CPU. imgproxy exists specifically because this pattern destroyed naive image servers.

**Do this instead:** Named presets only by default. If dynamic transforms are needed (e.g., responsive width ladder), they must be signed with a secret, bounded by a max pixel count, and rate-limited. Expose this as an opt-in profile flag with required signing config.

### Anti-Pattern 5: JSON-Only Variant Storage

**What people do:** Store variant metadata as a JSON column on the parent asset (`metadata->>'variants'`).

**Why it's wrong:** Can't query "all assets with stale variants"; can't retry failed variants in bulk; can't run cleanup queries; can't build admin UI. JSON columns are for unstructured analysis metadata, not lifecycle state.

**Do this instead:** `media_variants` as a first-class normalized table. Every variant is a queryable row with its own state, digest, and timestamps.

### Anti-Pattern 6: Optional Oban (DIY Job Backend)

**What people do:** Make Oban optional and add a fallback using `Task.Supervisor` or `GenServer`-based queues.

**Why it's wrong:** Crash the node during a Task — job is lost. No visibility into queue depth, failed jobs, or retry state. Diverges maintainer effort into two code paths. Oban is battle-tested for exactly this domain.

**Do this instead:** Oban is a hard dependency. It's the most widely used Elixir job backend and handles persistence, retries, observability, and transactional enqueueing. Document this clearly in the getting-started guide.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| AWS S3 | Presigned PUT URL (no server proxy for large files) | Use ExAws or Req with AWS SigV4 |
| Cloudflare R2 | Presigned PUT only — no presigned POST multipart | Adapter must declare capabilities; host apps must not assume multipart |
| GCS | POST-then-PUT resumable upload (v1.x); presigned PUT for v1 | Capabilities API prevents misuse |
| Oban | Transactional job enqueueing via `Oban.insert` in `Ecto.Multi` | Required dependency; no fallback |
| Phoenix LiveView | `allow_upload/3` + `consume_uploaded_entries/3` integration | `Rindle.Phoenix.LiveViewHelpers` provides hooks |
| `:telemetry` | Emit events at all lifecycle boundaries | Host apps attach handlers; naming is public contract |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Domain FSM ↔ Oban workers | Transactional Oban job insert; workers reload state via Repo | Workers never assume in-memory state from caller |
| Storage adapter ↔ Domain | Called only outside DB transactions; return `{:ok, key}` or `{:error, reason}` | No callbacks into domain from adapters |
| Processor adapter ↔ Workers | Stateless call: `Processor.generate(source_binary, recipe, opts)` → `{:ok, output_binary}` | Processors are pure I/O functions |
| Telemetry ↔ Host app | One-way: Rindle emits, host app attaches handlers | Host app cannot break Rindle by attaching bad handlers |
| Profile DSL ↔ Core | Compile-time validation; digest computed at macro expansion time | Invalid profiles fail at `mix compile`, not at runtime |

## Sources

- PROJECT.md — Rindle requirements, decisions, and constraints (primary source)
- Active Storage architecture: attachment/blob separation, async purge pattern, lazy variant redirect
- Shrine documentation: atomic promote pattern, derivatives as first-class records
- Spatie Media Library: Day-2 regeneration commands, responsive srcset
- imgproxy design: signed dynamic transforms as security requirement
- Oban documentation: transactional job enqueueing, queue configuration
- Elixir/OTP idioms: behaviour + adapter pattern, Ecto.Multi composability

---
*Architecture research for: Rindle (Phoenix/Elixir media lifecycle library)*
*Researched: 2026-04-24*
