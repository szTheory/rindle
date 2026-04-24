# Stack Research

**Domain:** Elixir/Phoenix media lifecycle library
**Researched:** 2026-04-24
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Elixir | ~> 1.15 | Language runtime | Pattern matching, supervisors, binary handling all essential for media pipelines; 1.15 is stable LTS floor |
| Ecto SQL | ~> 3.11 | Database layer + migrations | Normalized asset/variant/attachment schema requires queryable tables; Ecto changesets enforce state machine transitions safely |
| Postgrex | ~> 0.18 | PostgreSQL driver | PostgreSQL is the required DB; advisory locks, RETURNING clauses, and FOR UPDATE SKIP LOCKED (used by Oban) all needed |
| Oban | ~> 2.21 | Background job processing | SQL-backed, persistent, transactional enqueueing; supports enqueueing jobs inside DB transactions so asset state and job are committed atomically; required, not optional |
| image (libvips/Vix) | ~> 0.65 | Image processing | 2–3× faster than Mogrify, ~5× less memory; NIF-based, multi-threaded, pipelined; avoids shell-out risk present in ImageMagick/FFmpeg; current stable: v0.65.0 (released 2026-04-09) |
| Jason | ~> 1.4 | JSON encoding/decoding | Fastest Elixir JSON library; needed for storage adapter HTTP responses, telemetry metadata serialization |
| NimbleOptions | ~> 1.1 | Profile/DSL validation | Compile-time and runtime option schema validation; ideal for `use Rindle.Profile` DSL to catch misconfigured profiles at compile time |
| Telemetry | ~> 1.2 | Observability instrumentation | The standard Elixir observability primitive; event names are public API contracts — operators build dashboards against these |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ex_aws_s3 | ~> 2.5 | S3-compatible storage adapter | Required for any S3/R2/MinIO/Spaces storage backend; presigned PUT URL generation for direct uploads; current: v2.5.9 (2025-12-09) |
| ex_aws | ~> 2.5 | ExAws core HTTP + auth | Underpins ex_aws_s3; handles AWS Signature V4, request retry, HTTP client abstraction |
| ex_marcel | ~> 0.2 | Magic-byte MIME detection | Port of Rails Marcel; inspects file binary signatures rather than trusting client Content-Type; current: v0.2.0 (2025-10-27). Alternative: `file_type` (pure pattern matching, ~256 bytes read) — use ex_marcel for breadth, file_type for minimal deps |
| Mox | ~> 1.2 | Behaviour mocking in tests | Allows storage/processor/analyzer behaviour mocks without hitting real I/O in unit tests; works via Elixir behaviours |
| Bypass | ~> 2.1 | HTTP server stub in tests | Fakes S3/storage HTTP endpoints in integration tests without hitting real cloud |
| ExMachina | ~> 2.7 | Test data factories | Generates realistic Ecto fixture data for asset/variant/attachment schemas |
| ex_doc | ~> 0.34 | Documentation generation | Hexdocs publishing; guides, module docs, and changelogs |
| Credo | ~> 1.7 | Static analysis / style | Enforces consistent Elixir style; part of the required CI quality lane |
| Dialyxir | ~> 1.4 | Type analysis (Dialyzer) | Catches type errors in behaviour implementations and adapter contracts; required CI gate |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| MinIO (Docker) | Local S3-compatible storage for integration tests | Use `minio/minio` Docker image; configure CI integration lane; `MINIO_ROOT_USER` + `MINIO_ROOT_PASSWORD` env vars |
| LocalStack (alternative) | AWS service emulation including S3 | Heavier than MinIO; prefer MinIO unless needing multi-service AWS emulation |
| mix format | Code formatter | Elixir built-in; enforce via CI with `mix format --check-formatted` |
| ExUnit | Test framework | Elixir built-in; no additional dependency |

## Installation

```elixir
# mix.exs — runtime dependencies
defp deps do
  [
    # Core
    {:ecto_sql, "~> 3.11"},
    {:postgrex, "~> 0.18"},
    {:jason, "~> 1.4"},
    {:nimble_options, "~> 1.1"},

    # Background processing (required, not optional)
    {:oban, "~> 2.21"},

    # Image processing (default adapter — libvips via NIF)
    {:image, "~> 0.65"},

    # Storage (S3-compatible adapter)
    {:ex_aws_s3, "~> 2.5"},
    {:ex_aws, "~> 2.5"},

    # MIME detection (magic-byte sniffing)
    {:ex_marcel, "~> 0.2"},

    # Observability
    {:telemetry, "~> 1.2"},

    # Dev/Test
    {:mox, "~> 1.2", only: :test},
    {:bypass, "~> 2.1", only: :test},
    {:ex_machina, "~> 2.7", only: :test},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:ex_doc, "~> 0.34", only: :dev, runtime: false},
  ]
end
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| image (libvips/Vix) | Mogrify (ImageMagick) | Only if adopter explicitly opts in with documented container/sandbox guidance; ImageMagick has a history of CVEs (ImageTragick); never in core |
| image (libvips/Vix) | FFmpeg | Video/audio processing adapters in v1.x; not in v1 core; requires sandbox guidance |
| ex_marcel | file_type | If minimizing dependencies is the top priority; file_type has fewer format signatures but zero external deps and ~256-byte reads |
| ex_aws_s3 | waffle_gcs / custom GCS | For GCS-specific adapter (POST-then-PUT resumable flow); storage adapter capability flags must differ from S3 |
| Oban | Broadway / GenStage | Never for this project; Oban's SQL-backed persistence and transactional enqueueing are critical for the asset state machine |
| Ecto state machines (explicit) | Machinery / Exsm | State machine libraries add abstraction over something Ecto changesets handle well; explicit transition functions with `cast` + `validate_inclusion` are clearer and more auditable for a lifecycle library |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Mogrify (ImageMagick) | Shell-out to ImageMagick; CVE history (ImageTragick); slower, higher memory; blocks the BEAM scheduler during processing | image (libvips/Vix) |
| FFmpeg (in core) | Hostile-input risk documented by security researchers; requires sandboxing/container isolation; not universally available | Opt-in v1.x adapter with explicit docs |
| Waffle | No persistent variant state; no Oban integration; no upload session model; no cleanup commands; lacks the lifecycle durability this project exists to provide | Rindle itself |
| Arc (predecessor to Waffle) | Unmaintained; superseded by Waffle which itself lacks lifecycle durability | Rindle itself |
| Custom job runner | Inventing a parallel background job system introduces divergence, loses Oban's transactional enqueueing, and splits the operational story | Oban |
| Unsigned dynamic transform endpoints | DoS/cost vector; unbounded variant explosion; imgproxy lesson | Named presets + signed dynamic transforms only |
| JSON-only variant storage | Breaks queryability; cleanup jobs, admin UIs, SREs need queryable state per variant | Normalized `media_variants` table with Ecto schema |

## Stack Patterns by Variant

**Storage adapters (local disk vs. S3-compatible):**
- Local disk adapter: pure Elixir `File.*` operations; no additional deps; for dev/test and simple deployments
- S3/R2/MinIO adapter: ex_aws_s3 + ex_aws; expose capability flags (`:presigned_put`, `:multipart_upload`, `:resumable_upload`) — do not assume all backends are identical
- Cloudflare R2: does not support presigned POST multipart form uploads — capability flag must exclude `:multipart_upload`
- GCS: POST-then-PUT resumable flow — distinct adapter required for v1.x

**Image processing pipeline:**
- Default: image (libvips/Vix) — NIF-based, in-process, no shell-out
- Opt-in: ImageMagick via Mogrify — requires explicit adopter opt-in and documented sandbox guidance
- Future: FFmpeg/Membrane for video/audio — v1.x plugin architecture

**State machine implementation:**
- Do not use a state machine library; implement explicit transition functions using Ecto changesets
- Pattern: `def transition_to_analyzing(asset, attrs)` → `changeset |> put_change(:state, "analyzing") |> validate_inclusion(:state, @valid_states)`
- Transition functions are the public API; they are testable, auditable, and don't require an additional dependency

**MIME detection pipeline:**
- Step 1: Read file header bytes (ex_marcel / file_type)
- Step 2: Cross-reference against allowlist (extensions, MIME types configured in profile)
- Step 3: Reject if client Content-Type differs from detected type
- Never trust client-provided Content-Type as the sole signal

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| oban ~> 2.21 | ecto_sql ~> 3.11, postgrex ~> 0.18 | Oban 2.x requires Ecto SQL 3.x; no compatibility issues |
| image ~> 0.65 | Elixir ~> 1.14 | Requires libvips to be installed on the system; CI must install libvips (apt: `libvips-dev`, brew: `vips`) |
| ex_aws_s3 ~> 2.5 | ex_aws ~> 2.5 | Must pin both; ex_aws_s3 does not bundle ex_aws |
| ex_marcel ~> 0.2 | No Elixir version constraints noted | Pure Elixir port of Marcel; no native deps |
| nimble_options ~> 1.1 | Elixir ~> 1.13 | Profile DSL compile-time validation; no conflicts with core deps |

## Notes on Current mix.exs

The current `mix.exs` has slightly older pins than latest stable:
- `oban: "~> 2.18"` → latest is 2.21.1; update to `~> 2.21`
- `image: "~> 0.54"` → latest is 0.65.0; update to `~> 0.65`

Missing from current mix.exs (need to add):
- `ex_aws_s3` + `ex_aws` (S3 storage adapter)
- `ex_marcel` (magic-byte MIME detection)
- `mox`, `bypass`, `ex_machina` (test infrastructure)

## Sources

- [hex.pm/packages/image](https://hex.pm/packages/image) — confirmed v0.65.0, libvips/Vix NIF-based, Apache-2.0
- [hex.pm/packages/oban](https://hex.pm/packages/oban) — confirmed v2.21.1, PostgreSQL + SQLite3 + MySQL support
- [hex.pm/packages/ex_aws_s3](https://hex.pm/packages/ex_aws_s3) — confirmed v2.5.9, S3-compatible adapter
- [hex.pm/packages/ex_marcel](https://hex.pm/packages/ex_marcel) — confirmed v0.2.0, Marcel port, magic-byte MIME detection
- [Elixir Forum: MIME type detection by magic numbers](https://elixirforum.com/t/mime-type-detection-by-magic-numbers/213) — ex_marcel vs file_type comparison
- [AppSignal Blog: Building State Machines in Elixir with Ecto](https://blog.appsignal.com/2020/07/14/building-state-machines-in-elixir-with-ecto.html) — rationale for explicit Ecto transitions over state machine libraries

---
*Stack research for: Rindle — Phoenix/Ecto-native media lifecycle library*
*Researched: 2026-04-24*
