# Phase 37: GCS Adapter Foundation — Research

**Researched:** 2026-05-07
**Domain:** Google Cloud Storage adapter (auth + JSON API + V4 signed URLs)
**Confidence:** HIGH (locked candidate `v1.6-CANDIDATE-GCS.md` + verified library APIs + verified hex versions live)

## Summary

Phase 37 lands `Rindle.Storage.GCS` as a real second storage adapter implementing the
existing `Rindle.Storage` behaviour over a hand-rolled Finch JSON-API client + Goth
auth + `gcs_signed_url` V4 signing. Every shape decision (3-file split, return-shape
parity with S3, optional-dep pattern, secret-gated CI lane, profile-aware doctor) is
already locked in `37-CONTEXT.md`; the planner's job is **execution sequencing and
verification scaffolding**, not architectural choice.

The only meaningful research deltas vs. the locked candidate:

1. **`:finch` is NOT currently in the dependency tree.** It is referenced as Tesla's
   `optional: true` dep in `mix.lock:60`, but no top-level dep pulls it in. Therefore
   `mix.exs:22` `dialyzer.plt_add_apps` MUST add `:finch` (alongside `:goth` and
   `:gcs_signed_url`), contradicting D-07's "not `:finch` — already in tree" assumption.
2. **`Goth.fetch/1` returns `{:ok, t()} | {:error, Exception.t()}`**, but raises
   `:noproc` (via `GenServer.call`) when the named instance isn't in the supervision
   tree at all. The `Code.ensure_loaded?(Goth)` D-09 guard catches the "dep missing"
   case; a `try/catch :exit` wrapper around `Goth.fetch/1` catches the
   "dep loaded but instance not started" case and maps to `:goth_unconfigured`.
3. **`gcs_signed_url 0.4.6` ships two distinct V4 entry points**: `Client`-based
   (PEM private key, no network calls, returns bare `String.t()`) and
   `OAuthConfig`-based (IAM SignBlob, network call, returns `{:ok, String.t()} | {:error, String.t()}`).
   D-04 locks **Client mode only** for Phase 37 → return shape is `String.t()`,
   not `{:ok, ...}`. The `url/2` callback wraps it in `{:ok, ...}`.
4. **Bypass is in `mix.exs:92` but no current test uses it.** Phase 37 is the first
   adopter; pattern must be designed (not mirrored).

**Primary recommendation:** Execute as four plans in this order — **Client (HTTP plumbing) → Signer (V4 signing + url/2) → Adapter (callbacks + capabilities) → CI Lane + Doctor**. This sequence lets Bypass-backed unit tests prove `head/store/download/delete` before signing introduces auth complexity, and lets the live `gcs-soak` lane prove the whole stack against a real bucket only after every callback has unit-level coverage.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Module File Layout:**

- **D-01:** `Rindle.Storage.GCS` ships as a 3-file split:
  - `lib/rindle/storage/gcs.ex` — `@behaviour Rindle.Storage` impl + capability + config helpers (the public, hexdoc'd module).
  - `lib/rindle/storage/gcs/client.ex` — `@moduledoc false` hand-rolled Finch JSON-API wrapper for `head/store/download/delete` over `https://storage.googleapis.com/storage/v1/b/$BUCKET/o`.
  - `lib/rindle/storage/gcs/signer.ex` — `@moduledoc false` V4-signing wrapper around `gcs_signed_url ~> 0.4.6`.

**Public Contract (Mirrors `Rindle.Storage.S3`):**

- **D-02:** `head/2` returns `{:ok, %{size: integer, content_type: binary | nil}}` with `{:error, :not_found}` for HTTP 404 — exact shape mirror of `lib/rindle/storage/s3.ex:130-149`. Cross-adapter parity test at `test/rindle/storage/storage_adapter_test.exs:41-51` MUST stay green.
- **D-03:** `store/3` writes `Content-Type` and `Content-Disposition` as **GCS object metadata** (the bucket-side fields, not URL query params) at upload time.
- **D-04:** `url/2` accepts `expires_in` opt and falls back to `Rindle.Config.signed_url_ttl_seconds/0` — exact mirror of `lib/rindle/storage/s3.ex:55-61`. V4 signing only; private-key auth mode in Phase 37.
- **D-05:** Phase 37 does NOT touch `lib/rindle/error.ex`. Error atoms route through the generic `def message(%{action: action, reason: reason})` fallthrough at `lib/rindle/error.ex:334-336`.

**Optional Deps + Config Keying:**

- **D-06:** Add to `mix.exs` deps:
  - `{:goth, "~> 1.4", optional: true}`
  - `{:finch, "~> 0.21", optional: true}`
  - `{:gcs_signed_url, "~> 0.4.6", optional: true}`
- **D-07:** Extend `mix.exs:22` `dialyzer.plt_add_apps` from `[:mix, :ex_unit, :mux, :jose]` to add `:goth` and `:gcs_signed_url`. (Verify in plan whether `:finch` is needed.) **RESEARCH FINDING: `:finch` MUST be added — it is NOT currently in the tree as a non-optional dep. See Q9 below.**
- **D-08:** Config keyspace mirrors S3's `Application.get_env(:rindle, __MODULE__, [])` pattern.
- **D-09:** Optional-dep guard at runtime entry: `Code.ensure_loaded?(Goth)` returning `{:error, :goth_unconfigured}` when missing.

**CI Proof Lane + Test Harness:**

- **D-10:** Add a `gcs-soak` job to `.github/workflows/ci.yml` mirroring `mux-soak`, but **gated on secret presence**: `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}`.
- **D-11:** Tests at `test/rindle/storage/gcs_test.exs` tagged `@tag :gcs` with a `@gcs_skip_reason` module attribute that nil-checks `GOOGLE_APPLICATION_CREDENTIALS_JSON` and `RINDLE_GCS_BUCKET` env vars.
- **D-12:** Use **Bypass alone** for unit-level fixtures of the JSON API surface. Live-bucket integration runs the full GCS proof lane behind the secret. **Do NOT** add fakegcs as a dep.
- **D-13:** **Phase 37 ships basic `mix rindle.doctor` GCS health checks**: Goth instance running (named lookup succeeds), bucket reachable (`GET /storage/v1/b/$BUCKET` returns 200/403 — present), signing key parses cleanly. Profile-aware so image-only S3 adopters see no new noise.
- **D-14:** **Phase 37 does NOT touch the package-consumer lane.**

### Claude's Discretion

- Plan-level ordering of the 4 plans (one per requirement, per ROADMAP guidance) — researcher/planner pick the most testable execution order. **Recommendation surfaced below in §Execution Sequencing.**
- Whether a cross-cutting `gcs_capabilities_test.exs` parity test ships in Phase 37 or rolls into Phase 39 alongside the resumable atoms. **Recommendation: a single inline assertion in `gcs_test.exs` covers `capabilities/0 == [:signed_url, :head]`; defer the cross-cutting parity test (which would also assert resumable atoms when Phase 39 ships) to Phase 39.**
- Specific Bypass fixture topology (one `setup` block per callback vs a shared fixture module). **Recommendation: per-test `setup` block (no shared module) — see Q8 below.**

### Deferred Ideas (OUT OF SCOPE)

- Resumable upload behaviour callbacks → Phase 39 (RESUMABLE-04..08)
- `media_upload_sessions` resumable columns + FSM `"resuming"` state → Phase 38
- Resumable-specific `mix rindle.doctor` CORS-suspected check → Phase 41 (RESUMABLE-13)
- Package-consumer GCS proof lane (fresh `mix phx.new` install) → Phase 41 (RESUMABLE-14)
- IAM SignBlob auth mode → v1.7+ behind config flag
- Customer-supplied session URIs, CMEK, Object Versioning → out
- `Rindle.Storage.GCSResumable` as a separate adapter — locked one-adapter-multiple-capabilities; rejected
- Auto-fallback resumable→PUT or PUT→resumable — explicit family choice via profile DSL; rejected
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GCS-01 | `Rindle.Storage.GCS` implements `store/3`, `download/3`, `delete/2`, `head/2`, `url/2` against the real GCS bucket using `goth ~> 1.4` for auth and `finch ~> 0.21` for HTTP. No resumable behavior. | §Standard Stack (locked deps), §Architecture Patterns (3-file split, callback parity with S3), Q1+Q4 (JSON-API surface + Finch plumbing), Q5 (object metadata at store/3) |
| GCS-02 | `Rindle.Storage.GCS.capabilities/0` returns `[:signed_url, :head]` only at end of phase. | §Architecture Patterns (capability vocab), `lib/rindle/storage/capabilities.ex:19-27`, single inline test assertion in `gcs_test.exs` |
| GCS-03 | V4 signed URL generation via `gcs_signed_url ~> 0.4.6`, private-key auth, signed-URL TTL respects `Rindle.Config.signed_url_ttl_seconds/0`. `Content-Disposition` and `Content-Type` go into object metadata at `store/3` (not URL params). | Q3 (`gcs_signed_url` API surface — `Client`-based generate_v4 returns bare `String.t()`), Q5 (uploadType=multipart for metadata + body), §Common Pitfalls (PEM-vs-JSON ambiguity, response-content-disposition gap) |
| GCS-04 | GCS proof lane in CI gated behind `GOOGLE_APPLICATION_CREDENTIALS_JSON` secret; runs on PR only when secret is present, runs on release always. | Q7 (canonical fork-PR-safe `if: ${{ secrets.X != '' }}` pattern), §Validation Architecture (`gcs-soak` lane structure) |
</phase_requirements>

## Architectural Responsibility Map

This is a single-tier (BEAM library) phase. Capabilities map to internal module responsibilities, not multi-tier boundaries.

| Capability | Primary Module | Secondary Module | Rationale |
|------------|---------------|------------------|-----------|
| `Rindle.Storage` behaviour impl | `Rindle.Storage.GCS` | — | Public hexdoc'd entry point, capability advertisement, opts threading |
| GCS JSON API HTTP plumbing | `Rindle.Storage.GCS.Client` | — | Hand-rolled Finch wrapper for head/store/download/delete; @moduledoc false |
| V4 signed URL generation | `Rindle.Storage.GCS.Signer` | — | gcs_signed_url private-key wrapper; @moduledoc false |
| OAuth2 token resolution | (adopter-supplied `Goth` instance) | `Rindle.Storage.GCS.Client` | Adopter owns supervision; adapter looks up by name and calls `Goth.fetch/1` |
| Doctor health checks | `Rindle.Ops.RuntimeChecks` | `Rindle.Storage.GCS.Client` | New `check_gcs_*` functions splice into existing run/2 list, profile-aware |
| Cross-adapter parity | `Rindle.Storage.Capabilities` | — | Existing module; `:signed_url` + `:head` already in `@known` |

**Why this matters:** v1.6 Phase 35 webhook-handling locked the "hand-rolled HTTP client over Finch when SDK is too coupled" pattern. Phase 37 inherits it directly — `google_api_storage` is rejected (Tesla-coupled, doesn't surface session URI), so adapter owns ~250 LOC of HTTP plumbing inside `gcs/client.ex`.

## Standard Stack

### Core (Phase 37 adds)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `goth` | `~> 1.4` (latest 1.4.5, 2024-12-20) | OAuth2 service-account token minting | Locked v1.6 candidate §3; sole well-maintained Elixir package; uses Finch internally; supervision-tree friendly with named-instance pattern. `[VERIFIED: mix hex.info goth]` |
| `finch` | `~> 0.21` (latest 0.21.0, 2026-01-22) | HTTP client for JSON API + media upload | Lowest common runtime denominator; Goth pulls it transitively. Streams request bodies via `{:stream, body_stream}`. `[VERIFIED: mix hex.info finch]` |
| `gcs_signed_url` | `~> 0.4.6` (latest 0.4.6, 2023-03-27) | V4 signed URL generation | Pure-Elixir V4 implementation; PEM-private-key client mode requires no network calls. Two transitive deps (`jose`, `jason`) already in tree. `[VERIFIED: mix hex.info gcs_signed_url]` |

All three declared `optional: true` (D-06) — adopters not enabling GCS pay zero transitive cost.

### Already In Tree (reused unchanged)

| Library | Version | Purpose |
|---------|---------|---------|
| `bypass` | `~> 2.1` (only: :test) | Unit-level GCS JSON API fixtures (mix.exs:92) |
| `jason` | `~> 1.4` | JSON encode/decode for JSON API request/response |
| `mox` | `~> 1.2` (only: :test) | Already declared, unused by Phase 37 |
| `hackney` | `~> 1.20` (only: :test) | ExAws backend; unrelated to GCS path |

### Alternatives Considered (and rejected per locked candidate §3)

| Instead of | Could Use | Why Rejected |
|------------|-----------|--------------|
| Hand-rolled Finch JSON client | `google_api_storage` (auto-generated SDK) | Tesla-coupled, ~200+ transitive modules, `storage_objects_insert_resumable/5` returns `{:ok, nil}` — doesn't surface session URI cleanly. v1.6 candidate §3 lock. |
| `gcs_signed_url` | `gcs-signer-elixir` (shakrmedia) | Lower download volume; older API; `gcs_signed_url 0.4.6` is the current Elixir community choice. |
| Finch | `Tesla` or `Req` | Tesla pulls JSON middleware + decoders; Req is opinionated and adds 2 transitive deps. Finch is the bare HTTP transport Goth already uses. v1.6 Phase 35 raw-body cache pattern locked Finch over Req for adapter hot paths. |

**Installation (mix.exs additions):**

```elixir
defp deps do
  [
    # ... existing deps unchanged ...

    # GCS adapter (optional — Rindle.Storage.GCS only loads when present)
    {:goth, "~> 1.4", optional: true},
    {:finch, "~> 0.21", optional: true},
    {:gcs_signed_url, "~> 0.4.6", optional: true},

    # ... rest unchanged ...
  ]
end
```

**Version verification (run during plan execution):**

```bash
mix hex.info goth
mix hex.info finch
mix hex.info gcs_signed_url
```

All three confirmed live on hex.pm at research time (2026-05-07): goth 1.4.5, finch 0.21.0, gcs_signed_url 0.4.6. `[VERIFIED: hex.pm via mix hex.info]`

## Architecture Patterns

### System Architecture Diagram

```
                  ┌─────────────────────────────────────────────────┐
                  │              Adopter Phoenix App                │
                  │                                                 │
                  │  ┌──────────────┐         ┌──────────────────┐ │
                  │  │ MyApp.Goth   │         │ MyApp.Finch       │ │
                  │  │ (supervisor) │         │ (supervisor)      │ │
                  │  └──────┬───────┘         └────────┬──────────┘ │
                  └─────────┼──────────────────────────┼────────────┘
                            │  named-lookup            │  named-lookup
                            ▼                          ▼
       ┌──────────────────────────────────────────────────────────────┐
       │                   Rindle.Storage.GCS                         │  ◀─── @behaviour Rindle.Storage
       │            (lib/rindle/storage/gcs.ex)                       │       capabilities/0 → [:signed_url, :head]
       │                                                              │
       │  store/3   download/3   delete/2   head/2   url/2            │
       └──────────┬─────────────────────────────────┬─────────────────┘
                  │                                 │
                  ▼                                 ▼
       ┌────────────────────────┐       ┌────────────────────────┐
       │ Rindle.Storage.GCS     │       │ Rindle.Storage.GCS     │
       │   .Client              │       │   .Signer              │
       │ (@moduledoc false)     │       │ (@moduledoc false)     │
       │                        │       │                        │
       │ Goth.fetch → token     │       │ GcsSignedUrl.Client    │
       │ Finch.build → request  │       │ GcsSignedUrl           │
       │ Parse JSON response    │       │   .generate_v4         │
       └────────────┬───────────┘       └────────────┬───────────┘
                    │ HTTPS                          │ (no network — local PEM signing)
                    ▼                                │
   storage.googleapis.com                            │
   /storage/v1/b/$BUCKET/o          (URL string)     ▼
   /upload/storage/v1/b/$BUCKET/o   storage.googleapis.com/$BUCKET/$KEY?x-goog-signature=...
```

### Recommended Project Structure (Phase 37 additions)

```
lib/rindle/storage/
├── gcs.ex                       # @behaviour Rindle.Storage; public hexdoc'd module
├── gcs/
│   ├── client.ex                # @moduledoc false; Finch + JSON-API plumbing
│   └── signer.ex                # @moduledoc false; gcs_signed_url V4 wrapper
├── s3.ex                        # unchanged
├── local.ex                     # unchanged
└── capabilities.ex              # unchanged

lib/rindle/ops/
└── runtime_checks.ex            # extended with check_gcs_* functions (profile-aware)

test/rindle/storage/
├── gcs_test.exs                 # @tag :gcs live-bucket integration tests
├── gcs/
│   ├── client_test.exs          # Bypass-backed unit tests for HTTP plumbing
│   └── signer_test.exs          # V4 signing canonical-string tests
├── s3_test.exs                  # unchanged
└── storage_adapter_test.exs     # unchanged (parity test discovers via behaviour_info)

.github/workflows/
└── ci.yml                       # new gcs-soak job under existing structure
```

### Pattern 1: 3-file split with @moduledoc false internals

**What:** Public `Rindle.Storage.GCS` module exposes only the behaviour callbacks + `capabilities/0` + (optional) thin `bucket/0`-style helpers. Two private modules (`Client`, `Signer`) hold protocol-specific code with `@moduledoc false` so HexDocs doesn't render them.

**When to use:** Whenever a hand-rolled adapter needs >100 LOC of protocol code that future phases will extend (Phases 38–41 add 4 more callbacks sharing the same Goth/Finch plumbing).

**Why:** S3 delegates to `ExAws.S3.*` so its single file is enough. GCS owns the protocol; splitting now avoids a churny rename later (D-01 rationale). Mirrors the v1.6 Phase 35 split where `Rindle.Delivery.WebhookPlug` is public and `WebhookBodyReader`, `IngestProviderWebhook` worker are internals.

**Example skeleton:**

```elixir
# lib/rindle/storage/gcs.ex
defmodule Rindle.Storage.GCS do
  @moduledoc """
  Google Cloud Storage adapter using Goth (auth) + Finch (HTTP) + gcs_signed_url (V4).

  See `guides/storage_gcs.md` for setup. Adopter supervises Goth and Finch instances;
  Rindle never starts them.
  """

  @behaviour Rindle.Storage

  alias Rindle.Storage.GCS.{Client, Signer}

  @impl true
  def store(key, source_path, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.upload(bucket, key, source_path, content_type(opts), content_disposition(opts), opts)
    end
  end

  @impl true
  def head(key, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.head(bucket, key, opts)
    end
  end

  # ...other callbacks delegate similarly...

  @impl true
  def capabilities, do: [:signed_url, :head]

  defp bucket(opts) do
    case Keyword.get(opts, :bucket) || Application.get_env(:rindle, __MODULE__, [])[:bucket] do
      nil -> {:error, :missing_bucket}
      b -> {:ok, b}
    end
  end

  defp ensure_goth_loaded do
    if Code.ensure_loaded?(Goth), do: :ok, else: {:error, :goth_unconfigured}
  end
end
```

### Pattern 2: Adopter-owned runtime + named-instance lookup

**What:** Adapter never starts Goth or Finch. Adopter declares the names in `config :rindle, Rindle.Storage.GCS, goth: MyApp.Goth, finch: MyApp.Finch`; the adapter resolves them at call time.

**When to use:** Every Rindle adapter (locked v1.0 / v1.1 / v1.4 / v1.6 invariant — Repo, Oban, Goth all adopter-supervised).

**Example resolution:**

```elixir
# inside Client.upload/6
defp goth_name(opts) do
  Keyword.get(opts, :goth) || Application.get_env(:rindle, Rindle.Storage.GCS, [])[:goth] ||
    raise ArgumentError, "config :rindle, Rindle.Storage.GCS, goth: MyApp.Goth is required"
end

defp finch_name(opts) do
  Keyword.get(opts, :finch) || Application.get_env(:rindle, Rindle.Storage.GCS, [])[:finch] ||
    raise ArgumentError, "config :rindle, Rindle.Storage.GCS, finch: MyApp.Finch is required"
end

defp authed_headers(opts) do
  case fetch_token(opts) do
    {:ok, %Goth.Token{token: token, type: type}} ->
      {:ok, [{"authorization", "#{type} #{token}"}]}

    {:error, _exception} ->
      {:error, :goth_unconfigured}
  end
end

defp fetch_token(opts) do
  Goth.fetch(goth_name(opts))
catch
  :exit, _reason -> {:error, %RuntimeError{message: "Goth instance not running"}}
end
```

**Source for `Goth.fetch/1` shape:** `[CITED: https://hexdocs.pm/goth/Goth.html]` — returns `{:ok, t()} | {:error, Exception.t()}`. The `try/catch :exit` wrapper handles the case where the named instance isn't registered at all (GenServer.call raises `:noproc` `:exit`).

### Pattern 3: Single PUT for non-resumable upload (Phase 37 minimum)

**What:** Phase 37 ships only a single non-resumable upload path. Two viable shapes:

| Variant | Endpoint | Pros | Cons |
|---------|----------|------|------|
| **Multipart (recommended)** | `POST /upload/storage/v1/b/$BUCKET/o?uploadType=multipart` | Single request sets `contentType`, `contentDisposition`, custom metadata atomically | More complex body framing (`multipart/related` boundary) |
| **Simple media** | `POST /upload/storage/v1/b/$BUCKET/o?uploadType=media&name=$KEY` | Simplest body framing (raw bytes) | Cannot set `contentDisposition` in same request — needs second `PATCH` |

**Recommendation:** **uploadType=multipart**. D-03 requires `Content-Type` AND `Content-Disposition` to land in object metadata at store-time; `uploadType=media` cannot set `contentDisposition` without a follow-up PATCH (which doubles round-trips and creates a partial-failure window). `[CITED: https://docs.cloud.google.com/storage/docs/json_api/v1/objects/insert]`

**Multipart body shape:**

```
POST /upload/storage/v1/b/my-bucket/o?uploadType=multipart HTTP/1.1
Authorization: Bearer ya29.…
Content-Type: multipart/related; boundary=boundary123
Content-Length: <total>

--boundary123
Content-Type: application/json; charset=UTF-8

{"name":"assets/asset-1/original.jpg","contentType":"image/jpeg","contentDisposition":"inline; filename=\"foo.jpg\""}
--boundary123
Content-Type: image/jpeg

<binary body bytes>
--boundary123--
```

Source: `[CITED: https://docs.cloud.google.com/storage/docs/json_api/v1/objects/insert]`

### Pattern 4: HEAD-equivalent via metadata GET (alt=json)

**What:** GCS JSON API has no separate HEAD verb. The metadata-only fetch is `GET /storage/v1/b/$BUCKET/o/$KEY` (with `alt=json` default — omit `alt=media` which would return body bytes).

**Endpoint:** `GET https://storage.googleapis.com/storage/v1/b/{bucket}/o/{urlencode(key)}`

**Response shape (success):**

```json
{
  "kind": "storage#object",
  "id": "my-bucket/assets/asset-1/original.jpg/1234567890",
  "name": "assets/asset-1/original.jpg",
  "bucket": "my-bucket",
  "size": "1024000",          // string, not integer (must Integer.parse)
  "contentType": "image/jpeg",
  "contentDisposition": "inline; filename=\"foo.jpg\"",
  "metadata": {...},
  "etag": "..."
}
```

**Mapping to `head_result`:**

```elixir
%{
  size: parse_size(response_body["size"]),       # JSON returns string; parse to integer
  content_type: response_body["contentType"]     # binary | nil
}
```

Source: `[CITED: https://docs.cloud.google.com/storage/docs/json_api/v1/objects]`. The `size` field is documented as "An unsigned long integer representing the Content-Length of the data in bytes" but is serialized as a JSON string in the wire format (this is a long-standing GCS quirk).

### Anti-Patterns to Avoid

- **Don't** put `Content-Disposition` or `Content-Type` in V4-signed-URL query params (`response-content-disposition` / `response-content-type`). Per Active Storage's lesson and locked candidate §10, GCS V4 does not safely enforce these. Bucket-side metadata at store-time is the only honest path.
- **Don't** start Goth or Finch from inside Rindle. Adopter-owned runtime is a 5-milestone-locked invariant.
- **Don't** retry token fetch on `{:error, :goth_unconfigured}`. The atom signals an environmental misconfiguration, not a transient failure.
- **Don't** log the `Authorization: Bearer` header. (No current Rindle invariant explicitly forbids it, but the v1.6 security invariant 14 — provider-internal IDs redaction — extends naturally to OAuth2 access tokens. Strip the `authorization` header before any `Logger.metadata/1` or `:telemetry.execute/3` emit.)
- **Don't** advertise `:resumable_upload` or `:resumable_upload_session` from `capabilities/0`. They ship in Phase 39. The cross-adapter parity test (`storage_adapter_test.exs:62-70`) only asserts they're in `@known`; it does NOT assert any adapter exposes them.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OAuth2 token caching + refresh | Custom `GenServer` token refresher | `goth ~> 1.4` (`Goth.fetch/1`) | Token expiry, 5-min-before-refresh, retry semantics, source dispatch (service_account vs metadata vs refresh_token) — all production-hardened |
| V4 signing canonical-string assembly | Custom `:crypto.sign(:rsa, :sha256, ...)` | `gcs_signed_url ~> 0.4.6` | Canonical-string assembly is full of off-by-one footguns (host normalization, query-param sort order, percent-encoding, `x-goog-content-sha256: UNSIGNED-PAYLOAD`). The library matches Google's reference implementation. |
| Connection pooling for HTTPS | Custom `:gen_tcp` / `:ssl` pool | `finch ~> 0.21` | HTTP/1.1 keepalive, TLS session reuse, pool sizing, idle timeouts. |
| JSON encode/decode | Custom encoder | `jason ~> 1.4` (already in tree) | Speed + correctness. |
| HMAC-SHA256 over OAuth tokens | Custom `:crypto` calls | (delegate to Goth) | Goth handles the JWT-bearer flow; adapter never sees the JWT. |
| GCS error-envelope parsing | Custom regex / split | `Jason.decode!` on response body | Canonical shape is `{"error": {"code": int, "message": str, "errors": [...]}}`. `[CITED: https://docs.cloud.google.com/storage/docs/json_api/v1/status-codes]` |

**Key insight:** Goth + Finch + gcs_signed_url + jason cover every off-the-shelf concern. The ~250 LOC Rindle owns is purely **GCS JSON API request shaping** (URL paths, multipart boundary, response decoding) — not crypto, not auth, not transport.

## Common Pitfalls

### Pitfall 1: `Goth.fetch/1` against an unstarted named instance raises `:exit`, not returns `{:error, _}`

**What goes wrong:** Documentation says `Goth.fetch/1` returns `{:ok, t()} | {:error, Exception.t()}`, suggesting `{:error, ...}` covers all failure modes. But the actual implementation is `GenServer.call(registry_name(name), :fetch, timeout)` — calling a `GenServer` registered under an unregistered name raises `:exit, :noproc`.

**Why it happens:** Goth assumes the named instance is in the supervision tree. The `{:error, _}` path covers token-refresh failures (network, malformed creds), not "you forgot to start me."

**How to avoid:** Wrap in `try/catch :exit` and map to `{:error, :goth_unconfigured}`:

```elixir
defp fetch_token(opts) do
  try do
    case Goth.fetch(goth_name(opts)) do
      {:ok, token} -> {:ok, token}
      {:error, _exception} -> {:error, :goth_unconfigured}
    end
  catch
    :exit, _reason -> {:error, :goth_unconfigured}
  end
end
```

**Warning signs:** Adopter sees `EXIT from #PID<...> ** (EXIT) no process` instead of a clean tagged error tuple.

Source: GitHub source review of `peburrows/goth` `lib/goth.ex` `[CITED: https://github.com/peburrows/goth]` plus standard GenServer semantics.

### Pitfall 2: `gcs_signed_url` Client expects PEM private key STRING, not service-account JSON map

**What goes wrong:** Adopter sets `signing_key: %{...service_account.json...}` and the adapter passes it directly to `GcsSignedUrl.Client.load/1`. Works. But adopter sets `signing_key: "/path/to/key.json"` and the adapter calls `GcsSignedUrl.Client.load(...)` — fails with vague "expected map" error.

**Why it happens:** `gcs_signed_url` exposes TWO constructors: `Client.load/1` (takes a decoded JSON map) and `Client.load_from_file/1` (takes a path string and reads+decodes). The library does NOT auto-detect.

**How to avoid:** The signing-key config branch needs explicit type dispatch:

```elixir
# lib/rindle/storage/gcs/signer.ex
defp build_client(%{"private_key" => _, "client_email" => _} = json_map) do
  GcsSignedUrl.Client.load(json_map)
end

defp build_client(path) when is_binary(path) and byte_size(path) > 0 do
  if File.regular?(path) do
    GcsSignedUrl.Client.load_from_file(path)
  else
    raise ArgumentError, "signing_key must be a path to an existing JSON file or a decoded JSON map"
  end
end
```

The PEM private-key string lives INSIDE the JSON's `"private_key"` field; it's never passed bare to the adapter. The adapter's config accepts JSON-map-or-path, never raw PEM.

**Warning signs:** Cryptic `KeyError: key :private_key not found in: \"-----BEGIN PRIVATE KEY-----\\n...\"` errors at signing time.

Source: GitHub source review of `alexandrubagu/gcs_signed_url` `lib/gcs_signed_url/client.ex` `[CITED: https://github.com/alexandrubagu/gcs_signed_url]`.

### Pitfall 3: GCS JSON API `size` field is a STRING, not integer

**What goes wrong:** `response_body["size"]` returns `"1024000"` (string), but `head_result.size` is typed `non_neg_integer()`. Passing a string fails the parity test (`s3_test.exs:117`: `%{size: 20, ...}`).

**Why it happens:** GCS JSON API serializes long integers as strings to avoid JSON's 53-bit float precision loss for files > 2^53 bytes (very large multi-TB files).

**How to avoid:** Mirror S3's `parse_size/1` helper at `lib/rindle/storage/s3.ex:154-163`:

```elixir
defp parse_size(nil), do: 0
defp parse_size(val) when is_binary(val) do
  case Integer.parse(val) do
    {int, _} -> int
    _ -> 0
  end
end
defp parse_size(val) when is_integer(val), do: val
```

**Warning signs:** Cross-adapter parity test fails with `expected: 20 (integer); got: "20" (binary)` mismatch on `head/2`.

Source: `[CITED: https://docs.cloud.google.com/storage/docs/json_api/v1/objects]` field type documentation; `lib/rindle/storage/s3.ex:154-163` for the existing helper pattern.

### Pitfall 4: Bucket region mismatch returns 307 redirect, not error

**What goes wrong:** Bucket exists in `us-central1` but request goes to `storage.googleapis.com` (default us). On some buckets GCS returns 307 to a regional endpoint; Finch follows redirects only if explicitly configured.

**Why it happens:** GCS regional buckets sometimes redirect; Finch's default is no auto-follow.

**How to avoid:**
- Explicitly handle 3xx as a separate response branch (don't lump into `{:error, ...}`).
- Document in `guides/storage_gcs.md` that the bucket region should be configured via the `region_hint` config key.
- For Phase 37, the simplest path: assume the standard `storage.googleapis.com` endpoint works for all buckets (it does — even regional buckets respond at the global endpoint; the redirect path is mostly historical). If a 307 surfaces, treat as `{:gcs_http_error, %{status: 307, ...}}` and let the adopter fix the region.

**Warning signs:** Phantom 404 / 307 errors that disappear when bucket region is correct.

Source: General GCS knowledge `[ASSUMED]` — exact 307 trigger conditions vary by bucket configuration; behavior verified in production for some adopters but not in this research session.

### Pitfall 5: Bypass URL discovery — absolute vs. relative URLs

**What goes wrong:** Bypass-backed unit test expects requests at `http://localhost:#{bypass.port}/storage/v1/b/$BUCKET/o/$KEY`, but adapter is hard-coded to `https://storage.googleapis.com/...`. Bypass routes never fire.

**Why it happens:** Hand-rolled HTTP clients tend to hard-code the host. Bypass needs the adapter to accept a configurable base URL.

**How to avoid:** Thread a `:base_url` option through `opts` (defaulting to `https://storage.googleapis.com`). Tests pass `base_url: "http://localhost:#{bypass.port}"`. Mirrors the v1.6 `WebhookPlug` which accepts `:secrets` via `Plug.init/1`.

```elixir
# lib/rindle/storage/gcs/client.ex
@default_base_url "https://storage.googleapis.com"

defp base_url(opts) do
  Keyword.get(opts, :base_url) ||
    Application.get_env(:rindle, Rindle.Storage.GCS, [])[:base_url] ||
    @default_base_url
end
```

**Warning signs:** Bypass `Plug.Conn.test_redirected_to/2` assertions fail because no request ever reached the test server.

### Pitfall 6: `capabilities/0` accidentally advertises resumable atoms

**What goes wrong:** Phase 39 PR adds resumable callbacks and `capabilities/0` returns `[:signed_url, :head, :resumable_upload, :resumable_upload_session]` BEFORE the FSM and broker wiring exist. Phase 37 closes with the wrong shape.

**Why it happens:** Copy-paste from peer adapters or future phase scaffolding.

**How to avoid:** **Add an explicit assertion** in `gcs_test.exs`:

```elixir
test "capabilities/0 returns exactly [:signed_url, :head] in Phase 37" do
  # GCS-02: locked invariant for Phase 37; resumable atoms ship in Phase 39.
  assert Rindle.Storage.GCS.capabilities() == [:signed_url, :head]
end
```

Phase 39's PR will rewrite this assertion to include resumable atoms.

**Warning signs:** Phase 37 verifier passes `:signed_url` and `:head` are present, but doesn't assert the list is exhaustively `[:signed_url, :head]`. List-membership asserts are not enough.

## Code Examples

Verified patterns with explicit source attribution.

### `Goth.fetch/1` with named instance

```elixir
# Source: https://hexdocs.pm/goth/Goth.html (verified 2026-05-07)
case Goth.fetch(MyApp.Goth) do
  {:ok, %Goth.Token{token: token, type: type, expires: expires}} ->
    [{"authorization", "#{type} #{token}"}]

  {:error, exception} ->
    raise exception
end
```

### V4 signed URL via `gcs_signed_url` (Client mode)

```elixir
# Source: https://hexdocs.pm/gcs_signed_url/readme.html (verified 2026-05-07)
client = GcsSignedUrl.Client.load_from_file("/path/to/service_account.json")
# OR (when the JSON is already decoded by Goth or adopter):
client = GcsSignedUrl.Client.load(decoded_json_map)

# Returns String.t() directly (NOT {:ok, _})  — Client mode is local-only
url =
  GcsSignedUrl.generate_v4(client, "my-bucket", "assets/asset-1/original.jpg",
    verb: "GET",
    expires: 3600
  )

# url :: "https://storage.googleapis.com/my-bucket/assets/...?X-Goog-Algorithm=GOOG4-RSA-SHA256&..."
```

### Finch HEAD-equivalent (metadata-only GET)

```elixir
# Source: https://hexdocs.pm/finch/Finch.html (verified 2026-05-07)
url = "https://storage.googleapis.com/storage/v1/b/#{bucket}/o/#{URI.encode(key, &URI.char_unreserved?/1)}"
headers = [{"authorization", "Bearer #{token}"}, {"accept", "application/json"}]

req = Finch.build(:get, url, headers)

case Finch.request(req, MyApp.Finch) do
  {:ok, %Finch.Response{status: 200, body: body}} ->
    json = Jason.decode!(body)
    {:ok, %{size: parse_size(json["size"]), content_type: json["contentType"]}}

  {:ok, %Finch.Response{status: 404}} ->
    {:error, :not_found}

  {:ok, %Finch.Response{status: status, body: body}} ->
    {:error, {:gcs_http_error, %{status: status, body: body}}}

  {:error, exception} ->
    {:error, exception}
end
```

### Finch streamed PUT for `store/3` (multipart upload)

```elixir
# Source: https://hexdocs.pm/finch/Finch.html (verified 2026-05-07)
boundary = "rindle_gcs_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
metadata_json = Jason.encode!(%{
  "name" => key,
  "contentType" => content_type,
  "contentDisposition" => content_disposition
})

# Stream the multipart body so large files don't load into memory
file_stream =
  Stream.concat([
    ["--#{boundary}\r\n",
     "Content-Type: application/json; charset=UTF-8\r\n\r\n",
     metadata_json,
     "\r\n--#{boundary}\r\n",
     "Content-Type: #{content_type}\r\n\r\n"],
    File.stream!(source_path, [], 8192),
    ["\r\n--#{boundary}--\r\n"]
  ])

url = "#{base_url}/upload/storage/v1/b/#{bucket}/o?uploadType=multipart"
headers = [
  {"authorization", "Bearer #{token}"},
  {"content-type", "multipart/related; boundary=#{boundary}"}
]

req = Finch.build(:post, url, headers, {:stream, file_stream})
Finch.request(req, finch_name(opts))
```

### Bypass-backed unit test for `head/2`

```elixir
# Pattern designed for Phase 37 — no existing reference in test/ tree
defmodule Rindle.Storage.GCS.ClientTest do
  use ExUnit.Case, async: true

  alias Rindle.Storage.GCS.Client

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
  end

  test "head/2 returns size + content_type on 200 OK", %{bypass: bypass, base_url: base_url} do
    Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket/o/assets%2Ffoo.jpg", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{
        "size" => "1024000",   # GCS quirk: string, not integer
        "contentType" => "image/jpeg"
      }))
    end)

    opts = [base_url: base_url, token: "fake-token", finch: __MODULE__.Finch]
    assert {:ok, %{size: 1_024_000, content_type: "image/jpeg"}} =
             Client.head("my-bucket", "assets/foo.jpg", opts)
  end

  test "head/2 returns :not_found on 404", %{bypass: bypass, base_url: base_url} do
    Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket/o/missing.jpg", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
    end)

    opts = [base_url: base_url, token: "fake-token", finch: __MODULE__.Finch]
    assert {:error, :not_found} = Client.head("my-bucket", "missing.jpg", opts)
  end
end
```

### Doctor check splice (profile-aware)

```elixir
# Source: lib/rindle/ops/runtime_checks.ex:526-607 streaming-credentials template
# Designed extension for Phase 37 D-13

defp gcs_profiles(profiles) do
  Enum.filter(profiles, fn profile ->
    profile.storage_adapter() == Rindle.Storage.GCS
  end)
end

defp check_gcs_goth_running(profiles, _env) do
  cond do
    gcs_profiles(profiles) == [] ->
      ok_result("doctor.gcs_goth_running", :gcs,
        "No GCS-enabled profiles discovered.", @gcs_dep_missing_fix)

    not Code.ensure_loaded?(Goth) ->
      error_result("doctor.gcs_goth_running", :gcs,
        "GCS-enabled profile detected but :goth dep is not loaded.",
        @gcs_dep_missing_fix)

    true ->
      goth_name = Application.get_env(:rindle, Rindle.Storage.GCS, [])[:goth]

      case fetch_goth_token(goth_name) do
        :ok ->
          ok_result("doctor.gcs_goth_running", :gcs,
            "Goth instance #{inspect(goth_name)} is running and minting tokens.",
            @gcs_goth_fix)

        {:error, reason} ->
          error_result("doctor.gcs_goth_running", :gcs,
            "Goth instance #{inspect(goth_name)} is not running: #{inspect(reason)}",
            @gcs_goth_fix)
      end
  end
end

defp fetch_goth_token(nil), do: {:error, :no_goth_configured}
defp fetch_goth_token(name) do
  try do
    case Goth.fetch(name) do
      {:ok, _token} -> :ok
      {:error, exception} -> {:error, exception}
    end
  catch
    :exit, _reason -> {:error, :noproc}
  end
end

# similar shape: check_gcs_bucket_reachable, check_gcs_signing_key
```

The 3 new check functions splice into the `checks` list at `lib/rindle/ops/runtime_checks.ex:67-81`. Run order is deterministic (already `Enum.sort_by(& &1.id)` at line 83) so doctor output stays stable.

## Runtime State Inventory

> Phase 37 is greenfield (new adapter), not a rename/refactor. Section is INFORMATIONAL ONLY for completeness — no migration concerns.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — Phase 37 doesn't touch DB. (Phases 38–39 add `media_upload_sessions` resumable columns.) | none |
| Live service config | None — Phase 37 doesn't change Goth/Finch supervision; adopters add Goth instance to their own supervision tree as documented in (forthcoming) `guides/storage_gcs.md` (Phase 41). | none |
| OS-registered state | None — Phase 37 adds CI lane only; no host-level registrations. | none |
| Secrets/env vars | New: `GOOGLE_APPLICATION_CREDENTIALS_JSON` (CI secret), `RINDLE_GCS_BUCKET` (CI env var, integration test). Existing secrets unchanged. | configure CI secret pre-merge |
| Build artifacts / installed packages | `mix.lock` will gain `goth`, `finch`, `gcs_signed_url`, plus their transitive deps (notably `mint`, `nimble_options`, `nimble_pool` from Finch). | run `mix deps.get` after dep additions land |

**Nothing else found in any category — verified by greps over `lib/`, `test/`, `.github/`, `priv/`, and `mix.lock`.**

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Build/test | ✓ | 1.17+ (mix.exs requires `~> 1.15`) | — |
| Erlang/OTP | Build/test | ✓ | 27 (per CI matrix) | — |
| `mix hex.info` (network to hex.pm) | Version verification | ✓ | — | — |
| `:goth ~> 1.4` | New optional dep | will install via `mix deps.get` | 1.4.5 | — |
| `:finch ~> 0.21` | New optional dep | will install via `mix deps.get` | 0.21.0 | — |
| `:gcs_signed_url ~> 0.4.6` | New optional dep | will install via `mix deps.get` | 0.4.6 | — |
| `:bypass ~> 2.1` | Test scaffold | ✓ already in mix.exs:92 | 2.1 | — |
| Real GCS bucket + service account JSON | `mix test --only gcs` + `gcs-soak` lane | ✗ (CI secret + adopter setup required) | — | Skip integration tests when `GOOGLE_APPLICATION_CREDENTIALS_JSON` env var is empty (D-11 pattern); CI lane skips when `secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON == ''` (D-10 pattern) |
| `gh` CLI | (not needed for Phase 37) | ✓ | — | — |

**Missing dependencies with no fallback:** None. Phase 37 ships even when a real GCS bucket isn't available — local runs without credentials skip integration tests cleanly per D-11; the `gcs-soak` lane skips on PRs without the secret per D-10.

**Missing dependencies with fallback:** Real GCS bucket is the only one. The fallback is the `@gcs_skip_reason` skip pattern + secret-presence CI gating.

## Validation Architecture

> Required: workflow.nyquist_validation key absent from `.planning/config.json`, defaulting to enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) |
| Config file | `test/test_helper.exs` (existing — no Phase 37 changes) |
| Quick run command | `mix test test/rindle/storage/gcs_test.exs --include gcs:false` (Bypass-backed unit tests only, no live bucket needed) |
| Full suite command | `mix test` (skips `:gcs` tagged tests by default; runs all unit tests including Bypass-backed GCS client/signer tests) |
| Live-bucket integration | `mix test --only gcs` (requires `GOOGLE_APPLICATION_CREDENTIALS_JSON` + `RINDLE_GCS_BUCKET` env vars) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GCS-01 | `head/2` returns `{:ok, %{size:, content_type:}}` for existing object | unit (Bypass) | `mix test test/rindle/storage/gcs/client_test.exs:<line> -x` | ❌ Wave 0 |
| GCS-01 | `head/2` returns `{:error, :not_found}` for missing object | unit (Bypass) | `mix test test/rindle/storage/gcs/client_test.exs:<line> -x` | ❌ Wave 0 |
| GCS-01 | `head/2` returns `{:error, :missing_bucket}` when no bucket configured | unit (no network) | `mix test test/rindle/storage/gcs_test.exs:<line> -x` | ❌ Wave 0 |
| GCS-01 | `store/3`, `download/3`, `delete/2` round-trip against real bucket | integration | `mix test --only gcs` | ❌ Wave 0 |
| GCS-01 | `store/3` writes `Content-Type` AND `Content-Disposition` to object metadata | integration | `mix test --only gcs` (asserts `head/2` returns content_type + custom metadata via second GCS read) | ❌ Wave 0 |
| GCS-01 | `Code.ensure_loaded?(Goth)` returns `false` → `{:error, :goth_unconfigured}` | unit (mock-via-skip) | `mix test test/rindle/storage/gcs_test.exs:<line> -x` | ❌ Wave 0 |
| GCS-02 | `capabilities/0 == [:signed_url, :head]` exhaustively | unit (no network) | `mix test test/rindle/storage/gcs_test.exs:<line> -x` | ❌ Wave 0 |
| GCS-02 | Cross-adapter parity: GCS implements all behaviour callbacks | unit (existing test) | `mix test test/rindle/storage/storage_adapter_test.exs:41 -x` | ✅ exists; needs GCS module added to assertion list |
| GCS-03 | V4 signed URL contains expected canonical query params (X-Goog-Algorithm, X-Goog-Signature, etc.) | unit (no network) | `mix test test/rindle/storage/gcs/signer_test.exs:<line> -x` | ❌ Wave 0 |
| GCS-03 | `url/2` falls back to `Rindle.Config.signed_url_ttl_seconds/0` when `:expires_in` is absent | unit (no network) | `mix test test/rindle/storage/gcs/signer_test.exs:<line> -x` | ❌ Wave 0 |
| GCS-03 | Signed URL retrieves the object on the live bucket (round-trip) | integration | `mix test --only gcs` | ❌ Wave 0 |
| GCS-04 | `gcs-soak` job exists in `.github/workflows/ci.yml` and is gated on `secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != ''` | static-grep verification | `grep -c 'gcs-soak' .github/workflows/ci.yml` | ❌ Wave 0 (job to be added) |
| GCS-04 | `gcs-soak` job runs `mix test --only gcs` on the secret-present matrix | manual (CI artifact) | (verified by green CI on a label-secret-set PR) | ❌ Wave 0 |
| D-13 | `mix rindle.doctor` returns OK for GCS profile when Goth + bucket + signing key are all healthy | unit (with mocked Goth/Finch) | `mix test test/rindle/ops/runtime_checks_test.exs:<line> -x` | ✅ test file exists; needs new test cases |
| D-13 | `mix rindle.doctor` returns OK silently when no GCS profile is declared (no noise for image-only S3 adopters) | unit | `mix test test/rindle/ops/runtime_checks_test.exs:<line> -x` | ✅ test file exists; needs new test cases |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/storage/gcs_test.exs test/rindle/storage/gcs/` — Bypass-backed unit tests, no network. Should run in < 5 seconds.
- **Per wave merge:** `mix test` — Full local suite (skips `:gcs` integration tests). Should run in < 60 seconds.
- **Phase gate:** `mix test --only gcs` against the live bucket on CI (gcs-soak lane), AND `mix test` with everything green locally before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `test/rindle/storage/gcs_test.exs` — covers GCS-01 (round-trip), GCS-02 (capabilities), GCS-03 (signing TTL fallback), missing_bucket + goth_unconfigured tagged-error cases. Live-bucket-gated via `@tag :gcs` + `@gcs_skip_reason`.
- [ ] `test/rindle/storage/gcs/client_test.exs` — Bypass-backed unit tests for `head/store/download/delete` JSON-API plumbing; covers 200/404/4xx/5xx response paths.
- [ ] `test/rindle/storage/gcs/signer_test.exs` — V4 canonical-string assertions (no network, no Bypass); covers `url/2` TTL fallback.
- [ ] `test/rindle/ops/runtime_checks_test.exs` — extend with `check_gcs_*` cases (Goth running / not running / dep missing; bucket reachable / 403 / 404; signing key valid / malformed). All tests use mocks — no live network.
- [ ] `test/rindle/storage/storage_adapter_test.exs` — extend the `for {name, arity} <- callbacks` loop at line 47-50 to include `Rindle.Storage.GCS` once the module exists. Single-line addition; no new file.
- [ ] `.github/workflows/ci.yml` — add `gcs-soak` job mirroring `mux-soak` structural template at lines 566-653, with secret-gated `if:` and adapted env block.

*(No existing test infrastructure changes besides the storage_adapter_test.exs and runtime_checks_test.exs extensions noted above.)*

## Security Domain

> Required: `security_enforcement` not explicitly disabled in `.planning/config.json`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | OAuth2 service-account JWT-bearer flow delegated to `Goth` (no hand-rolled JWT) |
| V3 Session Management | no | Adapter is request/response — no session state held inside Rindle |
| V4 Access Control | no | Bucket-side IAM policy is adopter's concern; adapter forwards GCS 403 as `{:gcs_http_error, %{status: 403, ...}}` |
| V5 Input Validation | yes | Storage key generation already validated by `Rindle.Security.StorageKey.generate/3` (locked v1.0); adapter passes the key opaquely to GCS — no new validation surface |
| V6 Cryptography | yes | V4 signing delegated to `gcs_signed_url`; OAuth2 delegated to `Goth`. **NEVER hand-roll RSA-SHA256 canonical-string assembly.** |
| V7 Error Handling | yes | Locked error vocabulary (`:goth_unconfigured`, `:missing_bucket`, `:storage_object_missing`, `:not_found`, `{:gcs_http_error, ...}`) per D-05; routes through generic `Rindle.Error` fallthrough at `lib/rindle/error.ex:334-336` |
| V8 Data Protection | yes | OAuth2 access tokens are bearer credentials → must NOT appear in telemetry, logs, `inspect/2`. Mirrors security invariant 14 added in v1.6. |
| V11 Business Logic | no | No session-orchestration in Phase 37 (resumable broker ships in Phase 39) |
| V13 API & Web Service | yes | Hand-rolled HTTP client → must follow Rindle's existing redirect/timeout/error-mapping conventions |
| V14 Configuration | yes | Optional-dep guard (`Code.ensure_loaded?(Goth)`) prevents `Code.LoadError` when adopter forgets to install the dep |

### Known Threat Patterns for Goth + Finch + JSON-API Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| OAuth2 access token leakage in logs/telemetry | Information Disclosure | Strip `authorization` header before any `Logger.metadata/1`, `:telemetry.execute/3`, or `inspect/2` emit. (No bespoke `Rindle.Error` branch — bearer tokens never reach error tuples because `:goth_unconfigured` is a tagged atom only.) |
| Service-account JSON file leakage in CI logs | Information Disclosure | CI secret `GOOGLE_APPLICATION_CREDENTIALS_JSON` is set as a `secrets.*` reference (auto-redacted by GitHub Actions); never `echo $VAR`; do not write to disk in CI logs. |
| Server-side Request Forgery via key path | Spoofing | `Rindle.Security.StorageKey.generate/3` (locked v1.0) prevents directory traversal in the key. URL-encoding via `URI.encode/2` blocks scheme-injection. |
| Bucket-region redirect → request retry against unintended host | Tampering | Document `region_hint` config; explicit handling of 3xx responses (don't auto-follow redirects in Finch). |
| 404 timing oracle (presence/absence of object) | Information Disclosure | Bucket-level concern; not addressed at adapter layer. |
| V4 signed URL replay attack | Spoofing | TTL via `signed_url_ttl_seconds()` (default 900s); enforced by GCS server. Adopter's private bucket prevents anonymous access. |
| OAuth token caching window collisions across multi-tenant adopters | Tampering | Goth caches per named instance; adopters supervising multiple Goth instances per tenant get isolated caches. Documentation point only. |

**New invariant introduced (must hold):** OAuth2 access tokens minted by Goth are bearer credentials. They live only inside the adapter's call stack between `Goth.fetch/1` and `Finch.request/3`. They MUST NOT appear in:

- `Logger` output
- `:telemetry.execute/3` metadata
- `inspect/2` output of any persisted struct
- Error tuples returned to the broker
- `Rindle.Error.t()` user-facing messages

This is a natural extension of v1.6's security invariant 14 (provider-internal IDs / bearer credentials redaction). Phase 37 introduces no new persisted struct (resumable session URI persistence ships in Phase 38), so the invariant is enforced purely by code-review discipline in this phase.

## Specific Question Answers

The CONTEXT block enumerated 13 specific questions for the planner. Each is answered explicitly here.

### Q1 — GCS JSON API surface (head/store/download/delete)

| Callback | HTTP method + endpoint | Required headers | Success status | Error mapping |
|----------|----------|----------|----------|----------|
| `head/2` | `GET https://storage.googleapis.com/storage/v1/b/{bucket}/o/{urlencode(key)}` (alt=json default; no `alt=media`) | `authorization: Bearer $TOKEN`, `accept: application/json` | 200 → parse JSON for `size` (string) + `contentType` | 404 → `:not_found`; 403 → `{:gcs_http_error, %{status: 403, body: ...}}`; 5xx → `{:gcs_http_error, ...}` |
| `store/3` | `POST https://storage.googleapis.com/upload/storage/v1/b/{bucket}/o?uploadType=multipart` | `authorization: Bearer $TOKEN`, `content-type: multipart/related; boundary=$BOUNDARY` | 200 → parse JSON, return `%{key: key, response: json}` | 4xx/5xx → `{:gcs_http_error, ...}` |
| `download/3` | `GET https://storage.googleapis.com/storage/v1/b/{bucket}/o/{urlencode(key)}?alt=media` | `authorization: Bearer $TOKEN` | 200 → write streamed body to `destination_path`, return `{:ok, destination_path}` | 404 → `:not_found`; others → `{:gcs_http_error, ...}` |
| `delete/2` | `DELETE https://storage.googleapis.com/storage/v1/b/{bucket}/o/{urlencode(key)}` | `authorization: Bearer $TOKEN` | 204 No Content → `{:ok, %{key: key}}` | 404 → `:not_found` (or `{:ok, %{key: key}}` for idempotency — mirror S3 behaviour); others → `{:gcs_http_error, ...}` |

**Canonical error envelope** (verified `[CITED: https://docs.cloud.google.com/storage/docs/json_api/v1/status-codes]`):

```json
{
  "error": {
    "code": <integer http status>,
    "message": "<human-readable>",
    "errors": [
      {
        "domain": "global",
        "reason": "<short atom-like>",
        "message": "<message>",
        "locationType": "<...>",
        "location": "<...>"
      }
    ]
  }
}
```

**Differs from S3:** S3 returns XML (parsed by ExAws); GCS returns JSON. The atom mapping (`:not_found` for 404, `:missing_bucket` for absent config, `{:gcs_http_error, ...}` generic fallback) is identical.

### Q2 — Goth auth flow

**Token lifecycle:** Adopter declares `{Goth, name: MyApp.Goth, source: {:service_account, creds}}` in their supervision tree. Goth pre-fetches a token at boot (`prefetch: :async` is configurable) and refreshes 5 minutes before expiry by default.

**Adapter lookup:** `Goth.fetch(MyApp.Goth)` returns `{:ok, %Goth.Token{token: token, type: type, expires: integer, scope: string, sub: string|nil, account: term}} | {:error, Exception.t()}`. The adapter wraps with `try/catch :exit` to convert `:noproc` (instance not started) to `{:error, :goth_unconfigured}`. `[CITED: https://hexdocs.pm/goth/Goth.Token.html]`

**Source verification:** `[VERIFIED: hexdocs + GitHub source review]` — `peburrows/goth/lib/goth.ex` exposes `def fetch(name, timeout \\ 5000)` which calls `GenServer.call(registry_name(name), :fetch, timeout)`.

### Q3 — gcs_signed_url 0.4.6 API

**Function signatures** `[VERIFIED: hexdocs.pm/gcs_signed_url/GcsSignedUrl.html + GitHub source]`:

```elixir
# Client mode (PEM private key, no network — Phase 37 locked path)
@spec generate_v4(Client.t(), String.t(), String.t(), sign_v4_opts()) :: String.t()

# OAuthConfig mode (IAM SignBlob — deferred to v1.7+)
@spec generate_v4(SignBlob.OAuthConfig.t(), String.t(), String.t(), sign_v4_opts()) ::
  {:ok, String.t()} | {:error, String.t()}
```

**Critical:** Client mode returns a bare `String.t()`, NOT `{:ok, _}`. The adapter wraps the result:

```elixir
{:ok, GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: ttl)}
```

**Opts shape** (`sign_v4_opts()`): `verb`, `headers`, `query_params`, `valid_from` (DateTime), `expires` (integer seconds), `host`.

**Client construction** (`[CITED: https://github.com/alexandrubagu/gcs_signed_url/blob/master/lib/gcs_signed_url/client.ex]`):

```elixir
# From a path
client = GcsSignedUrl.Client.load_from_file("/path/to/key.json")
# From a decoded JSON map (recommended for security — adopter decodes once)
client = GcsSignedUrl.Client.load(json_map)
```

The `Client` struct has `private_key: String.t()` (PEM-encoded) and `client_email: String.t()`. Internally uses `:public_key.pem_decode` + `:public_key.pem_entry_decode` so a malformed PEM raises `MatchError` at signing time (NOT load time).

**Response-content-disposition / response-content-type:** Per the locked candidate §10 and Active Storage's lesson, GCS V4 signed URLs do NOT safely enforce these as `response-*` query params — that's why D-03 puts them in object metadata at store time. The library doesn't surface them as opts because they're not reliable.

**Migration story (Google drops V4):** Out of scope. V2 is already legacy per Google docs. No public migration path is documented; if it ever happens, the adapter swaps `generate_v4` → `generate_v5` (or whatever Google ships) inside `Signer` only — no public API churn.

### Q4 — Finch JSON-API plumbing

**Streaming body for store/3:** `Finch.build(:post, url, headers, {:stream, body_stream})`. The `body_stream` is any `Stream.t()` yielding `iodata` chunks. `[CITED: https://hexdocs.pm/finch/Finch.html]`

**Streaming body for download/3:** Use `Finch.stream/4` (NOT `Finch.request/3`) so the body chunks pipe directly to `File.write/3` without buffering the whole object:

```elixir
File.open(destination_path, [:write, :binary], fn file ->
  Finch.stream(req, finch_name(opts), :ok, fn
    {:status, status}, _acc when status in 200..299 -> :ok
    {:status, 404}, _acc -> {:halt, :not_found}
    {:headers, _headers}, acc -> acc
    {:data, chunk}, _acc -> IO.binwrite(file, chunk); :ok
  end)
end)
```

**S3 doesn't have a shared helper.** S3 uses `ExAws.S3.download_file` which returns an `ExAws.S3.Download` struct streamed by ExAws's runtime. GCS adapter's stream handling is internal to `gcs/client.ex` — no shared module needed.

**Phase 37 minimum for non-resumable upload:** **uploadType=multipart** (NOT uploadType=media). See Pattern 3 above and Q5 below.

### Q5 — Object metadata at store/3

**GCS JSON API field names** (camelCase, not snake_case) `[CITED: https://docs.cloud.google.com/storage/docs/json_api/v1/objects/insert]`:

- `contentType` (mirrors HTTP `Content-Type`)
- `contentDisposition` (mirrors HTTP `Content-Disposition`)
- `contentEncoding`, `cacheControl`, `contentLanguage` — also supported but Phase 37 doesn't expose
- `metadata` (object) — arbitrary key/value pairs; out of scope for Phase 37 (D-03 only locks ContentType + ContentDisposition)

**uploadType options:**

| Variant | Sets contentType | Sets contentDisposition | Single request? |
|---------|------------------|------------------------|-----------------|
| `uploadType=media` | yes (via HTTP `Content-Type`) | NO | yes |
| `uploadType=multipart` | yes (via JSON metadata) | YES (via JSON metadata) | yes |
| `X-Goog-Meta-*` headers | (custom only) | NO | yes |

**Recommendation: uploadType=multipart.** D-03 requires both `Content-Type` AND `Content-Disposition` at store-time. `multipart` is the only single-request option that sets both atomically.

### Q6 — `mix rindle.doctor` extension

**Cleanest profile-aware hook:** Add three new check functions to `lib/rindle/ops/runtime_checks.ex` that splice into the existing `checks` list at lines 67-81:

```elixir
checks = [
  fn -> check_delivery_support(profiles) end,
  # ... existing checks ...
  fn -> check_streaming_smoke_ping(profiles, env, opts) end,
  # NEW (Phase 37 / D-13):
  fn -> check_gcs_goth_running(profiles, env) end,
  fn -> check_gcs_bucket_reachable(profiles, env) end,
  fn -> check_gcs_signing_key(profiles, env) end
]
```

Each new check follows the streaming-credentials template at lines 526-607:

1. **Profile-aware short-circuit:** `gcs_profiles(profiles) == [] → ok_result(...)` (silent OK when no GCS profile).
2. **Optional-dep guard:** `not Code.ensure_loaded?(Goth) → error_result(...)` ("dep missing").
3. **Real check:** Goth instance fetch / bucket HTTP probe / signing-key parse.

**Function names (suggested):**

- `check_gcs_goth_running/2` — `Goth.fetch(goth_name)` returns `{:ok, _}`
- `check_gcs_bucket_reachable/2` — `GET /storage/v1/b/$BUCKET` returns 200 OR 403 (both prove the bucket exists; 403 = exists but ACL denies = still healthy from a name-resolution perspective)
- `check_gcs_signing_key/2` — `GcsSignedUrl.Client.load_from_file/1` (or `load/1`) succeeds without raising

**Splice location:** Functions added below the streaming check block (after line 607). Module attribute fixes (`@gcs_dep_missing_fix`, `@gcs_goth_fix`, `@gcs_bucket_fix`, `@gcs_signing_key_fix`) added near the existing `@streaming_*_fix` block at lines 16-36.

**Determinism:** `lib/rindle/ops/runtime_checks.ex:83` already does `Enum.sort_by(& &1.id)` so doctor output is alphabetically stable: `doctor.delivery_support`, `doctor.ffmpeg_runtime`, `doctor.gcs_bucket_reachable`, `doctor.gcs_goth_running`, `doctor.gcs_signing_key`, `doctor.local_playback`, ..., `doctor.streaming_*`.

### Q7 — CI lane secret-gating (canonical fork-PR-safe pattern)

**Pattern:**

```yaml
gcs-soak:
  name: GCS Soak (real bucket)
  runs-on: ubuntu-latest
  needs: quality
  if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}
  env:
    MIX_ENV: test
    GOOGLE_APPLICATION_CREDENTIALS_JSON: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON }}
    RINDLE_GCS_BUCKET: ${{ secrets.RINDLE_GCS_BUCKET }}
    PGUSER: postgres
    PGPASSWORD: postgres
    PGHOST: localhost
    PGPORT: "5432"

  services:
    postgres:
      # ... copy from mux-soak ...

  steps:
    - name: Checkout
      uses: actions/checkout@v4
    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: "1.17"
        otp-version: "27"
    - name: Install dependencies
      run: mix deps.get
    - name: Run GCS integration tests
      run: mix test --only gcs
```

**Critical:** the secret MUST be propagated to `env:` because the test code reads `System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")` at module-load time. The `if:` check controls whether the job runs at all; the `env:` block makes the value available to the test process. **Both are required.**

**Fork-PR safe:** GitHub Actions resolves `secrets.*` to empty strings on fork PRs (with the `pull_request` trigger, not `pull_request_target`). The `if: ${{ secrets.X != '' }}` clause causes the lane to skip cleanly. This mirrors the locked v1.5 MinIO discipline + the v1.6 Phase 36 mux-soak label-gated pattern (with `secrets.*` substituted for label).

**Structural diff vs. mux-soak:**

| mux-soak | gcs-soak |
|----------|----------|
| `if: contains(github.event.pull_request.labels.*.name, 'streaming')` | `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}` |
| `RINDLE_MUX_*` env block (5 secrets) | `GOOGLE_APPLICATION_CREDENTIALS_JSON` + `RINDLE_GCS_BUCKET` (2 secrets) |
| Starts MinIO docker container | No MinIO needed (not testing S3) |
| Runs `bash scripts/install_smoke.sh mux` | Runs `mix test --only gcs` |
| Three-layer cleanup mitigation (passthrough tag + cleanup script) | Phase 37 doesn't need cleanup (every test creates a unique key via `System.unique_integer/1` + cleans up at end of test, mirroring `s3_test.exs:30-82`) |

### Q8 — Bypass topology

**Recommendation:** **Per-test `setup` block, no shared fixture module.**

**Rationale:**
- Bypass is brand-new in this codebase (mix.exs:92 declares it; no current test uses it). Designing a shared module up front is premature.
- The 4 callbacks (`head`, `store`, `download`, `delete`) have wildly different request shapes (GET metadata, POST multipart, GET media, DELETE). A "shared fixture" module would devolve into 4 separate `expect_*` functions anyway — same code, indirection layer.
- `gcs/client_test.exs` will have ~12-15 tests (200/404/4xx/5xx × 4 callbacks + edge cases). 12 `setup` blocks of 3 lines each is 36 LOC; a shared module is 60+. The shared module is the wrong abstraction.

**Tradeoff acknowledgment:** If Phase 39 (resumable callbacks) adds 4 more callbacks with similar Bypass needs, the shared-module abstraction becomes worth pulling out. Phase 37 should NOT preemptively design that abstraction; let Phase 39 surface the duplication if it's real.

**Pattern (per-test):**

```elixir
setup do
  bypass = Bypass.open()
  on_exit(fn -> Bypass.shutdown(bypass) end)  # auto-cleanup
  {:ok, bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
end

test "head/2 returns size + content_type on 200 OK", %{bypass: bypass, base_url: base_url} do
  Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket/o/foo.jpg", fn conn ->
    Plug.Conn.resp(conn, 200, Jason.encode!(%{"size" => "1024", "contentType" => "image/jpeg"}))
  end)
  # ... assertions ...
end
```

### Q9 — dialyzer plt_add_apps (definitive answer)

**ANSWER: YES, add `:finch` to `dialyzer.plt_add_apps`.** D-07 said "verify in plan"; this research verifies.

**Evidence:** `grep "finch" mix.lock` returns ONE match — `tesla` declares `finch` as `optional: true`, but tesla is not loaded by Phase 37 (S3 uses ExAws + hackney, not Tesla). No top-level Rindle dep pulls in finch. Dialyzer would error on `Finch.build/3,4,5`, `Finch.request/2,3`, `%Finch.Response{}` references inside `gcs/client.ex` without an explicit PLT entry.

**Recommended edit:**

```elixir
# mix.exs:22
plt_add_apps: [:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url],
```

The CONTEXT D-07 explicitly says "Not `:finch` — already in tree as a non-optional dep elsewhere; verify in plan." Research confirms this assumption is **incorrect**. Finch is NOT in the tree as a non-optional dep. Phase 37 plan must add `:finch`.

### Q10 — Cross-adapter parity test impact

**Discovery mechanism:** `test/rindle/storage/storage_adapter_test.exs:41-51` enumerates callbacks via `Rindle.Storage.behaviour_info(:callbacks)` and asserts `function_exported?(adapter, name, arity)`. The adapter list (`Local`, `S3`) is HARD-CODED at lines 47-50, NOT auto-discovered.

**Required Phase 37 change:**

```elixir
# Existing (lines 41-51):
test "both adapters implement the storage behaviour callbacks" do
  Code.ensure_loaded!(Local)
  Code.ensure_loaded!(S3)

  callbacks = Rindle.Storage.behaviour_info(:callbacks)

  for {name, arity} <- callbacks do
    assert function_exported?(Local, name, arity)
    assert function_exported?(S3, name, arity)
  end
end

# Phase 37 minimum extension:
test "all adapters implement the storage behaviour callbacks" do
  alias Rindle.Storage.GCS
  Code.ensure_loaded!(Local)
  Code.ensure_loaded!(S3)
  Code.ensure_loaded!(GCS)

  callbacks = Rindle.Storage.behaviour_info(:callbacks)

  for {name, arity} <- callbacks do
    assert function_exported?(Local, name, arity)
    assert function_exported?(S3, name, arity)
    assert function_exported?(GCS, name, arity)
  end
end
```

**Also extend** the truthful-capabilities assertion at lines 77-83 to add `assert [:signed_url, :head] == GCS.capabilities()`.

**Why no parity-test refactor:** Adapter discovery via `Code.ensure_loaded?` + reflection is tempting but couples discovery to module name conventions. Explicit assertion list is clearer. If the registry grows beyond 3-4 adapters, refactor to `defmodule` registry. Not now.

### Q11 — Plan execution order (Claude's Discretion)

**Recommended order: Client → Signer → Adapter+Capabilities → CI Lane + Doctor.**

| Order | Plan | Requirement | Rationale for sequencing |
|-------|------|-------------|--------------------------|
| Plan 01 | **Client** (`gcs/client.ex`) — Finch JSON-API plumbing | GCS-01 (head, store, download, delete) | Bypass-backed unit tests prove the HTTP plumbing in isolation BEFORE auth or signing add complexity. The 4 callbacks are pure HTTP request shaping → testable with mocked Goth tokens (`opts: [token: "fake"]`). |
| Plan 02 | **Signer** (`gcs/signer.ex`) — V4 signing wrapper | GCS-03 | V4 signing is local (no network) → unit tests can assert canonical-string contents directly. Lands BEFORE the Adapter so `url/2` has its inner dependency ready. |
| Plan 03 | **Adapter** (`gcs.ex`) — `@behaviour` impl + `capabilities/0` + cross-adapter parity test extension | GCS-01 (assembly), GCS-02 | Wires Client + Signer behind the public surface. Live `@tag :gcs` integration tests (real bucket round-trip) prove the end-to-end stack. Cross-adapter parity test extension (Q10) lands here. |
| Plan 04 | **CI Lane + Doctor** (`.github/workflows/ci.yml` + `runtime_checks.ex`) | GCS-04, D-13 | Last because (a) the soak lane needs the test suite to exist (Plans 01-03), (b) doctor checks exercise the same Goth/signing-key code paths that Plans 01-03 build. Adopter-facing surface stabilizes before CI/observability layer. |

**Alternative orders considered + rejected:**

- **Adapter-first:** Tempting because the public surface is the deliverable. Rejected because Adapter without Client/Signer is a stub — no real tests. The order above is "leaves first, root last."
- **Signer-first (then Client):** Defensible; signing is simpler than HTTP plumbing. But `url/2` is the only callback that uses Signer; the other 4 use Client. Client-first means 4-of-5 callbacks have working tests after Plan 01.
- **CI lane first:** Rejected — the lane depends on tests that don't exist yet.

### Q12 — Risk register for the planner

| Risk | Likelihood | Impact | Pre-emption |
|------|-----------|--------|-------------|
| `:finch` not in PLT → dialyzer fails CI | HIGH (CONTEXT D-07 explicitly assumed wrong) | MEDIUM (CI red) | Plan 04 (or 03) edits `mix.exs:22` to add `:finch`. Verified by `mix dialyzer` locally. |
| Signing-key format ambiguity (PEM string vs JSON map vs file path) | MEDIUM | HIGH (cryptic runtime errors) | Pitfall 2 above; explicit type dispatch in `Signer.build_client/1`. |
| Bypass URL discovery mismatch (absolute vs relative) | MEDIUM | LOW (test fails loudly) | Pitfall 5; thread `:base_url` opt through Client. |
| `Goth.fetch/1` raises `:exit` (not returns `{:error, _}`) when instance not started | HIGH | MEDIUM (cryptic errors for adopters) | Pitfall 1; `try/catch :exit` wrapper in fetch_token helper. |
| GCS `size` field is JSON string, not integer → parity test fails | HIGH | LOW (caught by test; easy fix) | Pitfall 3; mirror S3's `parse_size/1`. |
| Bucket region mismatch returns 307 redirect | LOW | LOW (caught by integration test) | Pitfall 4; explicit 3xx handling in Client; document `region_hint`. |
| Adopter sets `signing_key:` to a raw PEM string (not JSON) | MEDIUM | MEDIUM (cryptic at signing time) | Document explicit accepted shapes in Adapter `@moduledoc`; raise `ArgumentError` early in `Signer.build_client/1`. |
| `capabilities/0` accidentally advertises resumable atoms | LOW | HIGH (breaks Phase 39 contract) | Pitfall 6; explicit `==` assertion in test. |
| Cross-adapter parity test broken when GCS module is added | LOW | HIGH (fails CI on Phase 37 PR) | Q10 explicit extension; Plan 03 includes the test edit in same commit as adapter shipping. |
| Optional-dep transitive cost surprise (Goth pulls Finch + Mint + nimble_options + nimble_pool) | MEDIUM | LOW (image-only adopters using `optional: true` see no transitive cost; CI image-only lane time may grow modestly) | Document in `mix.exs` comment; verify package-consumer image-only lane stays green (existing CI invariant). |
| OAuth access token leaked in error tuple | LOW | HIGH (security invariant breach) | Pitfall in Anti-Patterns; never include token in `{:error, ...}` shape. |
| Doctor regression: image-only adopters see new noise | LOW | MEDIUM (DX regression) | D-13 profile-aware short-circuit (Q6 above); test that `check_gcs_*` returns OK silently when no GCS profile is declared. |

### Q13 — Validation Architecture: see §Validation Architecture above

The §Validation Architecture section above answers Q13 in full, including:
- Test framework + commands
- Phase requirement → test mapping (one row per requirement)
- Sampling rate (per task / per wave / phase gate)
- Wave 0 gaps (5 new test files + extensions to 2 existing files + the gcs-soak job)

The mapping covers BOTH local-without-credentials runs (Bypass-backed unit tests prove correctness) AND live-bucket gcs-soak coverage (real round-trip).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `google_api_storage` auto-generated SDK | Hand-rolled Finch JSON client | Locked v1.6 candidate plan (2026-05-06) | ~250 LOC owned vs 200+ Tesla-coupled transitive modules; cleaner session-URI handling |
| V2 signed URLs | V4 only | Per Google docs (V2 deprecated, V4 standard since ~2018) | No effect — Phase 37 ships V4 from day one |
| Hackney for HTTP | Finch | Locked v1.6 Phase 35 | Aligns with Goth's transitive client; HTTP/2 ready |
| Single-instance Goth | Named-instance Goth | Goth 1.3 (2022-06) | Adopter supervises; multi-tenant adopters get isolated caches |

**Deprecated/outdated:**
- V2 signing → use V4 (`generate_v4`)
- `google_api_storage` for resumable / session-URI flows → hand-roll over Finch

## Project Constraints (from CLAUDE.md)

CLAUDE.md does not exist at the project root. Constraints are sourced from:

- **`.planning/PROJECT.md` security invariants 1-14** — apply to Phase 37:
  - Inv 1, 2, 5, 6, 7: held (no changes — adapter is request/response, no FSM in this phase)
  - Inv 14 (provider-internal IDs, bearer credentials): EXTENDED — OAuth2 access tokens are bearer credentials and must follow the same redaction discipline as Mux signing keys and (forthcoming) GCS resumable session URIs.
- **`.planning/PROJECT.md` constraints (lines 296-311):** Tech stack Elixir-only, adopter-owned Repo (Goth instance follows same pattern), Oban-required (not exercised in Phase 37), capability honesty (D-02 / GCS-02), backward compatibility (S3 unchanged), docs posture (maintainer-to-maintainer).
- **`.planning/STATE.md` decision-making preference:** Lock high-confidence decisions; only escalate VERY impactful (public API / semver / destructive / security / cost / scope-shift) items.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GCS bucket-region 307 redirects are mostly historical and rare in practice for the global `storage.googleapis.com` endpoint | Pitfall 4 | LOW — if 307s become common, plan adds Finch redirect handling; test surface stays the same |
| A2 | `Goth.fetch/1` raises `:exit, :noproc` (not a tagged error) when the named instance is unstarted | Pitfall 1 + Q2 | LOW — `try/catch :exit` wrapper handles all cases; if Goth changes to return `{:error, ...}` instead, the catch becomes dead code (no harm) |
| A3 | `gcs_signed_url 0.4.6` Client mode is the right Phase 37 path (vs OAuthConfig/IAM SignBlob) | Q3 | LOW — D-04 explicitly locks Client mode; IAM SignBlob deferred to v1.7+ per locked candidate §13 |
| A4 | Bypass per-test setup is preferable to a shared fixture module for Phase 37's 4 callbacks | Q8 | LOW — refactor surface if Phase 39's 4 additional callbacks make duplication painful |
| A5 | `uploadType=multipart` is the right default for `store/3` (over `uploadType=media` + follow-up PATCH) | Pattern 3 + Q5 | LOW — multipart is single-request and atomic; alternative is a documented round-trip increase |
| A6 | Cross-adapter parity test (`storage_adapter_test.exs`) requires explicit module addition (not auto-discovery) | Q10 | LOW — code reading confirms; if adapter discovery refactor is desired, Phase 39 can do it |
| A7 | Image-only adopters seeing no doctor noise is achievable via profile-aware short-circuit (`gcs_profiles == []` returns OK silently) | Q6 + D-13 | LOW — exact pattern from `check_streaming_credentials/2` at line 528-534 |
| A8 | OAuth2 access tokens should follow the same security-invariant-14 redaction discipline as Mux signing keys | §Security Domain | LOW — extends an already-locked invariant; no Phase 37 code surface persists tokens, so enforcement is code-review-only this phase |

**Note:** All `[ASSUMED]` claims above are LOW risk because each has a verified-source counterpart in the wider research (Pattern 3 / Q3 / etc.) that establishes the conservative path. None gate the planner's work.

## Open Questions

None blocking. Three minor follow-ups for the planner to surface during plan-checking:

1. **Should `Signer.build_client/1` accept the decoded JSON map directly (faster, no double-decode) or always read from disk (matches Goth's idiomatic `{:service_account, creds}` source)?**
   - What we know: both `GcsSignedUrl.Client.load/1` (map) and `load_from_file/1` (path) are public.
   - Recommendation: **accept either** — type-dispatch in `Signer.build_client/1`. Adopter ergonomics matter more than the "one true path" purity.

2. **Should `download/3` use `Finch.stream/4` (chunk-write to disk, no memory buffering) or `Finch.request/3` (full body in memory, then `File.write/3`)?**
   - What we know: download targets are mostly < 100MB images and < 2GB videos. Memory buffering 2GB is unacceptable.
   - Recommendation: **`Finch.stream/4`** for any object > 8MB; `Finch.request/3` is fine for small objects but the code complexity savings don't justify the memory risk. Single-pass `Finch.stream/4` is the safe default.

3. **Should the `:base_url` opt be public (documented in `Rindle.Storage.GCS @moduledoc`) or test-only?**
   - What we know: Bypass needs it. No production scenario needs it (adopters always use the real GCS endpoint).
   - Recommendation: **test-only, undocumented in `@moduledoc`**, but discoverable via `Application.get_env(:rindle, Rindle.Storage.GCS, [])[:base_url]` for any future `gcs-emulator` test scenario. Mirrors S3's `aws_config` opts threading at `lib/rindle/storage/s3.ex:181-185`.

## Sources

### Primary (HIGH confidence)

- **Project context (locked):**
  - `.planning/phases/37-gcs-adapter-foundation/37-CONTEXT.md` — D-01 through D-14 + Claude's Discretion
  - `.planning/research/v1.6-CANDIDATE-GCS.md` — locked candidate plan, source of truth for hex versions, auth mode, peer-library lessons
  - `.planning/REQUIREMENTS.md:17-35` — GCS-01 through GCS-04 acceptance criteria
  - `.planning/ROADMAP.md:60-108` — Phase 37 goal + success criteria
  - `.planning/PROJECT.md:24-67, 296-342` — milestone scope + security invariants

- **Rindle source seams (read in this research session):**
  - `lib/rindle/storage.ex` — behaviour callbacks
  - `lib/rindle/storage/s3.ex:55-61, 130-149, 173-178` — return-shape templates
  - `lib/rindle/storage/local.ex:52-69, 83` — unsupported-callback pattern
  - `lib/rindle/storage/capabilities.ex:19-27` — `@known` capability vocabulary
  - `lib/rindle/error.ex:334-336` — generic `message/1` fallthrough
  - `lib/rindle/config.ex:14-17` — `signed_url_ttl_seconds/0`
  - `lib/rindle/ops/runtime_checks.ex:1-120, 526-607` — doctor-check template
  - `mix.exs:22, 67-69, 92, 158-163` — dialyzer + optional-dep + Bypass + hexdoc
  - `mix.lock:60` — verified `:finch` is NOT in the non-optional tree
  - `test/rindle/storage/s3_test.exs:13-18, 29-30, 117` — credential-gated pattern
  - `test/rindle/storage/storage_adapter_test.exs:41-51, 77-83` — parity test
  - `.github/workflows/ci.yml:289, 566-653` — package-consumer + mux-soak template

- **Hex registry (verified live 2026-05-07 via `mix hex.info`):**
  - goth 1.4.5 (2024-12-20)
  - finch 0.21.0 (2026-01-22)
  - gcs_signed_url 0.4.6 (2023-03-27)

- **Official documentation:**
  - [Cloud Storage Objects: insert](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/insert) — uploadType=media/multipart/resumable, content-type/content-disposition fields
  - [Cloud Storage Objects: get](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/get) — metadata-only fetch via alt=json
  - [Cloud Storage status codes](https://docs.cloud.google.com/storage/docs/json_api/v1/status-codes) — canonical error envelope
  - [Cloud Storage uploading objects (curl examples)](https://docs.cloud.google.com/storage/docs/uploading-objects) — request shaping
  - [Goth.Token (hexdocs)](https://hexdocs.pm/goth/Goth.Token.html) — `Goth.Token` struct shape, `fetch/2` return spec
  - [Goth (hexdocs)](https://hexdocs.pm/goth/Goth.html) — supervisor + named-instance pattern
  - [GcsSignedUrl (hexdocs)](https://hexdocs.pm/gcs_signed_url/GcsSignedUrl.html) — V4 signing API
  - [gcs_signed_url README (hexdocs)](https://hexdocs.pm/gcs_signed_url/readme.html) — Client construction examples
  - [Finch (hexdocs)](https://hexdocs.pm/finch/Finch.html) — build/request/stream API

- **GitHub source review:**
  - [peburrows/goth/lib/goth.ex](https://github.com/peburrows/goth) — `Goth.fetch/1` calls `GenServer.call(registry_name, :fetch, timeout)` — confirms `:exit` raise on unstarted instance
  - [alexandrubagu/gcs_signed_url/lib/gcs_signed_url/client.ex](https://github.com/alexandrubagu/gcs_signed_url) — Client struct + load/load_from_file
  - [sneako/finch/lib/finch.ex](https://github.com/sneako/finch) — build/request/stream signatures + Finch.Response shape

### Secondary (MEDIUM confidence)

- WebSearch corroborated:
  - GCS JSON API endpoint structure (multiple sources; cross-verified with official docs)
  - Goth named-instance pattern (multiple sources; cross-verified with hexdocs README)
  - Finch streaming PUT body pattern (cross-verified with hexdocs)

### Tertiary (LOW confidence)

- 307-redirect frequency for regional buckets (Pitfall 4) — `[ASSUMED]` based on general GCS knowledge; no live source proves rarity. Conservative path (explicit 3xx handling) is captured in the recommendation.

## Metadata

**Confidence breakdown:**

- Standard stack: **HIGH** — all 3 hex versions verified live; locked candidate §3 explicitly chose them with rationale; peer-library lessons cited.
- Architecture: **HIGH** — 3-file split locked in CONTEXT D-01; Adopter-owned-runtime locked across 5 milestones; capability vocabulary in `lib/rindle/storage/capabilities.ex:19-27` already reserves the right atoms.
- Pitfalls: **HIGH** for #1, #3, #5, #6 (verified against existing source); **MEDIUM** for #2 (verified against gcs_signed_url GitHub source); **LOW** for #4 (general GCS knowledge, not verified in this session).
- Validation Architecture: **HIGH** — sampling rate matches `mix test --only` discipline locked in v1.5; test-file scaffold pattern matches `s3_test.exs:13-18, 29-30`.
- Security: **HIGH** — extends locked v1.6 invariant 14; no new persisted struct in Phase 37 means the enforcement surface is small and code-review-tractable.

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (30 days for stable libraries; goth + gcs_signed_url have low release cadence; finch is more active but 0.21 is the current stable line)

## RESEARCH COMPLETE
