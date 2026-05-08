# Phase 37: GCS Adapter Foundation - Research

**Researched:** 2026-05-07
**Domain:** Google Cloud Storage adapter implementation for `Rindle.Storage` behaviour
**Confidence:** HIGH

## Summary

Phase 37 lands `Rindle.Storage.GCS` as a real `Rindle.Storage` adapter against
a live GCS bucket. The work is pure adapter plumbing — no broker changes, no
DB changes, no resumable behaviour. The implementation hand-rolls a minimal
JSON-API HTTP client over `finch ~> 0.21` (rejecting the Tesla-coupled
`google_api_storage` SDK), authenticates via adopter-supervised `goth ~> 1.4`,
and signs delivery URLs through `gcs_signed_url ~> 0.4.6`'s V4 signing path.
All 14 decisions in CONTEXT.md (D-01..D-14) are locked. Three of them are
load-bearing for plan structure: D-01 (3-file split), D-08 (config keying),
D-13 (basic doctor checks ship in this phase, NOT Phase 41).

The phase ships **4 plans, one per requirement**, LOW risk, comparable in
scope to v1.6 Phase 33 (Mux adapter foundation). All external library APIs
are verified against hex.pm and HexDocs. The mux-soak workflow at
`.github/workflows/ci.yml:566-653` is a near-exact structural template for
the new `gcs-soak` lane (substitute `if: contains(...labels..., 'streaming')`
for `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}`, and the
MinIO bring-up steps drop entirely).

**Primary recommendation:** Implement the 5 callbacks in dependency order —
`url/2` (signing only, no HTTP), then `head/2` (single GET), then `delete/2`
(single DELETE), then `download/3` (GET with `alt=media` body streamed to a
file), then `store/3` (multipart upload — the most complex). Wire Bypass
fixtures per-callback in test setup blocks; reserve the live-bucket lane for
end-to-end coverage of the same 5 verbs against `storage.googleapis.com`.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 — Module file layout (3-file split):**
- `lib/rindle/storage/gcs.ex` — `@behaviour Rindle.Storage` impl + capability
  + config helpers (the public, hexdoc'd module).
- `lib/rindle/storage/gcs/client.ex` — `@moduledoc false` hand-rolled Finch
  JSON-API wrapper for `head/store/download/delete` over
  `https://storage.googleapis.com/storage/v1/b/$BUCKET/o`.
- `lib/rindle/storage/gcs/signer.ex` — `@moduledoc false` V4-signing wrapper
  around `gcs_signed_url ~> 0.4.6`.
- **Why split** (vs S3's single file): S3 delegates to `ExAws.S3.*` and owns
  no protocol code. GCS hand-rolls ~250 LOC over Finch, and Phases 38–41 add
  4 more callbacks (`initiate_resumable_upload/3`, `resumable_upload_status/3`,
  `cancel_resumable_upload/3`, `verify_resumable_completion/3`) sharing the
  same auth/HTTP plumbing. Splitting now avoids a churny rename later.

**D-02 — `head/2` return shape:** `{:ok, %{size: integer, content_type: binary | nil}}`
with `{:error, :not_found}` for HTTP 404 — exact shape mirror of
`lib/rindle/storage/s3.ex:130-149` and the parity assertion at
`test/rindle/storage/s3_test.exs:117`. Cross-adapter parity test at
`test/rindle/storage/storage_adapter_test.exs:41-51` MUST stay green.

**D-03 — `store/3` writes Content-Type and Content-Disposition as GCS object
metadata** (the bucket-side fields, not URL query params) at upload time.
Active Storage lesson: GCS V4 signed URLs do NOT safely enforce
`response-content-disposition` / `response-content-type`, so disposition/type
lives in object metadata.

**D-04 — `url/2` accepts `expires_in` opt** and falls back to
`Rindle.Config.signed_url_ttl_seconds/0` — exact mirror of
`lib/rindle/storage/s3.ex:55-61`. V4 signing only (V2 is legacy per Google
docs); private-key auth mode in Phase 37 (IAM SignBlob deferred to v1.7+).

**D-05 — Phase 37 does NOT touch `lib/rindle/error.ex`.** Error atoms
(`:goth_unconfigured`, `:missing_bucket`, `:storage_object_missing`,
`{:gcs_http_error, %{status, body}}`) route through the generic
`def message(%{action: action, reason: reason})` fallthrough at
`lib/rindle/error.ex:334-336`.

**D-06 — Optional deps in `mix.exs deps/0`:**
- `{:goth, "~> 1.4", optional: true}`
- `{:finch, "~> 0.21", optional: true}` (already transitive via Goth, but
  declared explicitly with `optional: true` for hex-tooling honesty)
- `{:gcs_signed_url, "~> 0.4.6", optional: true}`
- Adopters who don't enable GCS pay zero transitive cost.

**D-07 — Extend `mix.exs:22` `dialyzer.plt_add_apps`** from
`[:mix, :ex_unit, :mux, :jose]` to add `:goth` and `:gcs_signed_url`.
NOTE: planner must verify whether `:finch` needs to be added — the CONTEXT
states "already in tree as a non-optional dep elsewhere," but verification
shows finch is NOT yet in the dep tree (see "Open Questions" below).

**D-08 — Config keying** mirrors S3's `Application.get_env(:rindle, __MODULE__, [])`
pattern:
```
config :rindle, Rindle.Storage.GCS,
  bucket: "my-bucket",
  goth: MyApp.Goth,
  finch: MyApp.Finch,
  signing_key: %{...},  # service-account JSON (decoded map) or PEM
  signed_url_ttl: 3600,
  region_hint: "us-central1"
```
Rindle does NOT start Goth or Finch — adopter owns the runtime.

**D-09 — Optional-dep guard at runtime entry:** `Code.ensure_loaded?(Goth)`
returning `{:error, :goth_unconfigured}` when missing — mirrors
`lib/rindle/ops/runtime_checks.ex:536`.

**D-10 — `gcs-soak` job in `.github/workflows/ci.yml`** mirroring `mux-soak`
shape, but gated on secret presence:
```yaml
if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}
```
Fork-PR safe: forks resolve secret to `''` and lane skips cleanly.

**D-11 — Tests at `test/rindle/storage/gcs_test.exs`** tagged `@tag :gcs`
with module-attribute env-var nil-check — exact pattern from
`test/rindle/storage/s3_test.exs:13-18, 29-30`.

**D-12 — Use Bypass alone** for unit-level fixtures of the JSON API surface.
Live-bucket integration runs the full GCS proof lane behind the secret.
Do NOT add fakegcs as a dep.

**D-13 — Phase 37 ships basic `mix rindle.doctor` GCS health checks:**
- Goth instance running (named lookup succeeds)
- Bucket reachable (`GET /storage/v1/b/$BUCKET` returns 200/403/404 — distinguishes present/absent/forbidden)
- Signing key parses cleanly (via `GcsSignedUrl.Client.load/1`)
- Profile-aware: fires only when an adopter profile declares `storage: Rindle.Storage.GCS`
- Resumable-specific CORS-suspected branch STAYS deferred to Phase 41.

**D-14 — Phase 37 does NOT touch the package-consumer lane**
(`.github/workflows/ci.yml:289`). That's RESUMABLE-14 / Phase 41.

### Claude's Discretion

- Plan-level ordering of the 4 plans (one per requirement, per ROADMAP guidance).
- Whether a cross-cutting `gcs_capabilities_test.exs` parity test ships in
  Phase 37 or rolls into Phase 39 alongside the resumable atoms.
- Specific Bypass fixture topology (one `setup` block per callback vs a shared
  fixture module).

### Deferred Ideas (OUT OF SCOPE)

- Resumable-specific `mix rindle.doctor` CORS-suspected check → Phase 41.
- Package-consumer GCS proof lane (fresh `mix phx.new` install) → Phase 41.
- Resumable upload behaviour callbacks → Phase 39.
- `media_upload_sessions` resumable columns + FSM `"resuming"` state → Phase 38.
- IAM SignBlob auth mode → v1.7+ behind config flag.
- Customer-supplied session URIs, CMEK, Object Versioning → out.
- `Rindle.Storage.GCSResumable` as separate adapter — rejected.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GCS-01 | `Rindle.Storage.GCS` implements `store/3`, `download/3`, `delete/2`, `head/2`, `url/2` against real GCS via `goth ~> 1.4` + `finch ~> 0.21`. No resumable. | "Standard Stack", "Architecture Patterns", "Implementation Details by Subsystem" §1-§5 |
| GCS-02 | `Rindle.Storage.GCS.capabilities/0` returns `[:signed_url, :head]` only. Resumable atoms NOT advertised. | "Public API Shape" `capabilities/0`; "Code Examples" parity-test snippet |
| GCS-03 | V4 signed URL via `gcs_signed_url ~> 0.4.6` private-key mode; TTL respects `Rindle.Config.signed_url_ttl_seconds/0`. Content-Disposition / Content-Type as object metadata at `store/3`. | "Implementation Details" §3 (V4 signing); "Don't Hand-Roll" #4 |
| GCS-04 | `gcs-soak` lane in CI gated behind `GOOGLE_APPLICATION_CREDENTIALS_JSON` secret; PR runs only with secret, release always. Fork-PR safe. | "Implementation Details" §5 (mux-soak clone discipline); "Code Examples" full gcs-soak YAML skeleton |

---

## Standard Stack

### Core (locked)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `goth` | `~> 1.4` (1.4.5, 2024-12-20) | Service-account OAuth2 token caching for Google APIs | Industry-standard Elixir Goth library; named-instance pattern fits adopter-owned-runtime posture; auto-refreshes 300s before expiry |
| `finch` | `~> 0.21` (0.21.0, 2026-01-22) | HTTP client for JSON API hot path | Lowest-common-denominator Elixir HTTP; Goth already pulls it in; no Tesla coupling; supports streaming bodies |
| `gcs_signed_url` | `~> 0.4.6` (0.4.6, 2023-03-27) | V4 signed URL generation | Two transitive deps already in tree (`jose`, `jason`); private-key + IAM SignBlob modes; only mature Elixir GCS signing library |

`[VERIFIED: hex.pm via mix hex.info]` — All three versions confirmed live on
hex.pm 2026-05-07.

### Supporting (already in tree)

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| `jose` | `~> 1.11` | PEM key parsing (transitive via `gcs_signed_url`) | Already optional dep for v1.6 Mux streaming |
| `jason` | `~> 1.4` | Service-account JSON decoding + GCS error envelope parsing | Already required dep |
| `bypass` | `~> 2.1` | Test-only HTTP fixture for unit tests | Already declared in `mix.exs:92` (test only); no new dep needed |

### Alternatives Considered

| Instead of | Could Use | Tradeoff (and why rejected) |
|------------|-----------|------|
| `finch` | `tesla` | Tesla pulls 2+ transitive deps and adds adapter indirection; opinionated middleware stack. **Rejected:** locked candidate §3; `google_api_storage` is Tesla-coupled and pulls 200+ modules. |
| `finch` | `req` | Excellent test harness; 2 transitive deps; opinionated. Acceptable for tests but not adapter hot path. **Rejected for adapter:** locked candidate §3. |
| `finch` (hand-rolled) | `google_api_storage 0.46.1` | Auto-generated, Tesla-coupled, exposes `storage_objects_insert_resumable/5` returning `{:ok, nil}` (doesn't surface session URI). **Rejected** per CONTEXT D-01 / locked candidate §3. |
| `gcs_signed_url` private-key | IAM SignBlob (service-account-impersonation) | GKE/Cloud Run pattern. **Deferred to v1.7+ behind config flag** per CONTEXT Deferred §IAM SignBlob. |
| Bypass | `fakegcs` | Adds new test dep. **Rejected per D-12;** Bypass + live bucket is the established Rindle pattern (S3 uses Bypass + MinIO). |

**Installation diff for `mix.exs:50` `defp deps`:**

```elixir
# Streaming providers (optional — Mux adapter only loads when these are present)
{:mux, "~> 3.2", optional: true},
{:jose, "~> 1.11", optional: true},

# GCS storage adapter (optional — Phase 37, only loads when adopter opts in)
{:goth, "~> 1.4", optional: true},
{:finch, "~> 0.21", optional: true},
{:gcs_signed_url, "~> 0.4.6", optional: true},
```

**Version verification record (live `mix hex.info` 2026-05-07):**
- `goth 1.4.5` — published 2024-12-20, all-time downloads 12.8M `[VERIFIED: hex.pm]`
- `finch 0.21.0` — published 2026-01-22, all-time downloads 55.0M `[VERIFIED: hex.pm]`
- `gcs_signed_url 0.4.6` — published 2023-03-27, all-time downloads 805K `[VERIFIED: hex.pm]`

---

## Architecture Patterns

### System Architecture Diagram

```
+------------------------------------------------------------+
|              Adopter App Supervision Tree                  |
|                                                            |
|  {Goth, name: MyApp.Goth, source: {:service_account,...}} |
|  {Finch, name: MyApp.Finch}                                |
+------------------------------------------------------------+
            | (named lookup via config :rindle, Rindle.Storage.GCS)
            v
+------------------------------------------------------------+
|        lib/rindle/storage/gcs.ex (PUBLIC, hexdoc'd)        |
|                                                            |
|  @behaviour Rindle.Storage                                 |
|  store/3    --> Client.upload_multipart (POST /upload/...) |
|  download/3 --> Client.download_media   (GET ?alt=media)   |
|  delete/2   --> Client.delete_object    (DELETE)           |
|  head/2     --> Client.head_object      (GET ?alt=json)    |
|  url/2      --> Signer.sign_v4         (gcs_signed_url)    |
|                                                            |
|  capabilities/0 -> [:signed_url, :head]   # GCS-02         |
+------------------------------------------------------------+
            |
   +--------+--------+
   v                 v
+-----------------+ +-----------------+
| gcs/client.ex   | | gcs/signer.ex   |
| @moduledoc false| | @moduledoc false|
| - Goth.fetch/1  | | - Client.load/1 |
| - Finch.build/4 | | - generate_v4/4 |
| - Finch.req/2   | |                 |
| - multipart body| |                 |
| - error decode  | |                 |
+-----------------+ +-----------------+
   |                 |
   +--------+--------+
            v
  https://storage.googleapis.com/{storage,upload/storage}/v1/b/$BUCKET
  (Authorization: Bearer <Goth token>)
```

**Component responsibilities:**

| File | Responsibility | Visibility |
|------|----------------|------------|
| `lib/rindle/storage/gcs.ex` | `@behaviour Rindle.Storage` impl, `capabilities/0`, config-key resolution (`bucket/1`, `goth_name/1`, `finch_name/1`), opts threading | Public, hexdoc'd |
| `lib/rindle/storage/gcs/client.ex` | Token fetch, request building, multipart marshalling, response parsing, error envelope decoding | Internal (`@moduledoc false`) |
| `lib/rindle/storage/gcs/signer.ex` | V4 signing via `gcs_signed_url`; PEM/JSON-map credential normalization | Internal (`@moduledoc false`) |

### Recommended Project Structure

```
lib/rindle/storage/
├── gcs.ex              # Public adapter
├── gcs/
│   ├── client.ex       # Hand-rolled Finch JSON API wrapper
│   └── signer.ex       # V4 signing wrapper

test/rindle/storage/
├── gcs_test.exs        # @tag :gcs (live bucket, env-gated)
├── gcs/
│   ├── client_test.exs # Bypass-mocked unit tests for 4 REST verbs
│   └── signer_test.exs # V4 signing unit tests (no HTTP)

guides/                  # Note: storage_gcs.md ships in Phase 41, NOT here
.github/workflows/ci.yml # Add gcs-soak job after mux-soak block (line 654)
```

### Pattern 1: Adopter-Owned Runtime, Adapter Looks Up By Name

**What:** Goth and Finch processes are started by the adopter's supervision
tree; the adapter resolves the named instance from `Application.get_env`.

**When to use:** Any adapter that wraps a long-running supervised process the
adopter is also likely to use elsewhere (Goth for any GCP API; Finch for any
HTTP client).

**Example (mirror of v1.6 Mux Phase 33-36):**
```elixir
# Source: lib/rindle/storage/s3.ex:173-178 (config keying mirror target)
defp goth_name(opts) do
  Keyword.get(opts, :goth) ||
    Application.get_env(:rindle, __MODULE__, [])[:goth] ||
    {:error, :goth_unconfigured}
end
```

### Pattern 2: Optional-Dep Guard via `Code.ensure_loaded?`

**What:** Returns clean `{:error, atom}` tuple instead of `Code.LoadError`
when adopter hasn't installed the optional dep.

**When to use:** First operation inside any callback that depends on an
optional-only library.

**Example (locked v1.6 Phase 36 template):**
```elixir
# Source: lib/rindle/ops/runtime_checks.ex:536
not Code.ensure_loaded?(Mux.Video.Assets) ->
  error_result(...)

# Phase 37 analog:
def store(key, source, opts) do
  if Code.ensure_loaded?(Goth) do
    do_store(key, source, opts)
  else
    {:error, :goth_unconfigured}
  end
end
```

### Pattern 3: Credential-Gated Integration Test Module Attribute

**What:** Module attribute resolves env vars at compile time; `@tag skip:`
expression skips cleanly when credentials absent.

**When to use:** Every adapter integration test that hits a real cloud
endpoint.

**Example (locked v1.1 MinIO, v1.6 Mux):**
```elixir
# Source: test/rindle/storage/s3_test.exs:13-18
@gcs_creds System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")
@gcs_bucket System.get_env("RINDLE_GCS_BUCKET")
@gcs_skip_reason (if Enum.any?([@gcs_creds, @gcs_bucket], &is_nil/1) do
                    "Skipping :gcs test because GOOGLE_APPLICATION_CREDENTIALS_JSON or RINDLE_GCS_BUCKET is missing"
                  end)

@tag :gcs
@tag skip: @gcs_skip_reason
test "..." do ... end
```

### Pattern 4: Secret-Gated CI Proof Lane (mux-soak Mirror)

**What:** Workflow `if:` clause checks secret presence; PR-from-fork
resolves secret to `''` and lane skips. Release lane (push to main / tag)
always runs.

**When to use:** Any soak/integration lane that costs real cloud quota.

**Example:**
```yaml
gcs-soak:
  name: GCS Soak (real bucket)
  if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}
  # ... rest of mux-soak structure verbatim minus MinIO/Mux env vars
```

### Anti-Patterns to Avoid

- **Starting Goth/Finch from the adapter:** breaks adopter-owned-runtime
  invariant; causes "two Goth processes" duplication when adopter also runs
  Goth for other GCP APIs.
- **Using the Tesla-coupled `google_api_storage` SDK:** pulls 200+ modules
  transitively; doesn't surface session URI cleanly per locked candidate §3.
- **Putting `Content-Disposition` / `Content-Type` in signed-URL query params
  (`response-content-disposition`, `response-content-type`):** Active Storage
  CVE-adjacent lesson; GCS V4 signed URLs don't safely enforce these.
- **Hand-rolling JWT signing:** `gcs_signed_url` exists; security-sensitive.
- **Logging the GCS Authorization header (`Bearer <token>`) or the raw
  signing key:** invariant from CONTEXT security review; mirrors
  `lib/rindle/ops/runtime_checks.ex:632-636`.

---

## Public API Shape (per callback)

All shapes mirror `lib/rindle/storage/s3.ex` exactly so the cross-adapter
parity test at `test/rindle/storage/storage_adapter_test.exs:41-51` stays
green without modification.

### `store/3`

```elixir
@spec store(key :: String.t(), source :: Path.t(), opts :: keyword()) ::
        {:ok, %{key: String.t(), bucket: String.t(), generation: String.t()}}
        | {:error, :missing_bucket}
        | {:error, :goth_unconfigured}
        | {:error, {:gcs_http_error, %{status: integer(), body: term()}}}
        | {:error, term()}  # File.read errors etc.
```

**Behaviour:**
1. Read source file via `File.read/1` (mirror `s3.ex:17`).
2. POST to `https://storage.googleapis.com/upload/storage/v1/b/$BUCKET/o?uploadType=multipart`
   with multipart body (metadata part + media part).
3. Metadata part contains `{"name": key, "contentType": ..., "contentDisposition": ...}`
   — D-03 invariant.
4. Authorization: `Bearer <Goth.fetch! token>`.
5. On 200, parse JSON response, return `{:ok, %{key: key, bucket: bucket, generation: gen}}`.

### `download/3`

```elixir
@spec download(key :: String.t(), destination :: Path.t(), opts :: keyword()) ::
        {:ok, Path.t()}
        | {:error, :missing_bucket}
        | {:error, :goth_unconfigured}
        | {:error, :not_found}                        # 404 -> atom
        | {:error, {:gcs_http_error, %{status, body}}}
```

**Behaviour:**
1. `File.mkdir_p(Path.dirname(destination))` (mirror `s3.ex:34`).
2. GET `https://storage.googleapis.com/storage/v1/b/$BUCKET/o/$ENCODED_OBJECT?alt=media`.
3. Stream response body to `destination` (Finch supports streamed receive
   via `Finch.stream/4` if needed, or load-and-write for simple cases).
4. Return `{:ok, destination}`.

### `delete/2`

```elixir
@spec delete(key :: String.t(), opts :: keyword()) ::
        {:ok, %{key: String.t()}}
        | {:error, :missing_bucket}
        | {:error, :goth_unconfigured}
        | {:error, :not_found}
        | {:error, {:gcs_http_error, %{status, body}}}
```

**Behaviour:**
1. DELETE `https://storage.googleapis.com/storage/v1/b/$BUCKET/o/$ENCODED_OBJECT`.
2. 204 No Content -> `{:ok, %{key: key}}` (mirror `local.ex:33-37`).
3. 404 -> `{:error, :not_found}` (idempotent-success contract per
   `lib/rindle/storage.ex:96` "Deleting a non-existent key is adapter-defined").

### `head/2`

```elixir
@spec head(key :: String.t(), opts :: keyword()) ::
        {:ok, %{size: non_neg_integer(), content_type: String.t() | nil}}
        | {:error, :missing_bucket}
        | {:error, :goth_unconfigured}
        | {:error, :not_found}
        | {:error, {:gcs_http_error, %{status, body}}}
```

**Behaviour:**
1. GET `https://storage.googleapis.com/storage/v1/b/$BUCKET/o/$ENCODED_OBJECT?alt=json`
   (returns the **metadata** JSON resource — NOT an HTTP HEAD verb against
   the JSON API; the JSON API's metadata-fetch endpoint uses GET).
2. Parse `size` (string -> integer), `contentType` from JSON body.
3. Mirror exact return shape from `s3.ex:140-145` so parity assertion at
   `test/rindle/storage/s3_test.exs:117` (`{:ok, %{size: 20, content_type: "image/jpeg"}}`)
   passes against GCS too.

### `url/2`

```elixir
@spec url(key :: String.t(), opts :: keyword()) ::
        {:ok, String.t()}
        | {:error, :missing_bucket}
        | {:error, :signing_key_unconfigured}
```

**Behaviour:**
1. Look up `expires_in` from opts; fall back to
   `Rindle.Config.signed_url_ttl_seconds/0` (mirror `s3.ex:55-61`).
2. Build `GcsSignedUrl.Client` from `signing_key` config (decoded JSON map
   or PEM string).
3. Call `GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: ttl)`.
4. Return `{:ok, signed_url_string}`.

### `capabilities/0`

```elixir
@spec capabilities() :: [Rindle.Storage.capability()]
def capabilities, do: [:signed_url, :head]
```

**Phase 37 invariant (GCS-02):** `:resumable_upload` and
`:resumable_upload_session` MUST NOT appear. Add a unit test that asserts
exact equality (`assert Rindle.Storage.GCS.capabilities() == [:signed_url, :head]`)
to enforce ordering and prevent accidental Phase 39 leakage.

### Unsupported callbacks (return tagged tuples)

The 5 multipart/presigned callbacks NOT in the GCS-01 scope must return
`{:error, {:upload_unsupported, :multipart_upload}}` or
`{:error, {:upload_unsupported, :presigned_put}}` per the
`lib/rindle/storage/local.ex:52-69` pattern:

```elixir
@impl true
def presigned_put(_, _, _), do: {:error, {:upload_unsupported, :presigned_put}}

@impl true
def initiate_multipart_upload(_, _, _), do: {:error, {:upload_unsupported, :multipart_upload}}

@impl true
def presigned_upload_part(_, _, _, _, _), do: {:error, {:upload_unsupported, :multipart_upload}}

@impl true
def complete_multipart_upload(_, _, _, _), do: {:error, {:upload_unsupported, :multipart_upload}}

@impl true
def abort_multipart_upload(_, _, _), do: {:error, {:upload_unsupported, :multipart_upload}}
```

This satisfies the parity test at
`test/rindle/storage/storage_adapter_test.exs:41-51` (every callback exists
on the adapter at the right arity) without advertising capabilities the
adapter doesn't support.

---

## Implementation Details by Subsystem

### Section 1: Goth Token Fetch and Authorization Threading

**API surface (verified):**
- `Goth.fetch(name, timeout \\ 5000)` -> `{:ok, %Goth.Token{}}` | `{:error, exception}`
  `[CITED: hexdocs.pm/goth/Goth.html]`
- `Goth.fetch!(name, timeout \\ 5000)` — raises on error.
- `%Goth.Token{token: String.t(), type: String.t(), expires: integer, scope: String.t(), sub: String.t() | nil, account: term()}`
  `[CITED: hexdocs.pm/goth/Goth.Token.html]`
- Header construction: `"Authorization: <type> <token>"` (e.g.
  `"Authorization: Bearer ya29.a0AfH6SMBx..."`).
- Token cache auto-refreshes 300s before expiry; adapter does not need to
  handle refresh logic explicitly.

**Adapter usage shape:**
```elixir
# lib/rindle/storage/gcs/client.ex
defp authorized_headers(goth_name) do
  case Goth.fetch(goth_name) do
    {:ok, %Goth.Token{type: type, token: token}} ->
      {:ok, [{"authorization", "#{type} #{token}"}]}

    {:error, _reason} ->
      {:error, :goth_unconfigured}
  end
end
```

**Error-shape note:** `Goth.fetch/1` raises `ArgumentError` if no Goth
process is registered under `name` (e.g. `MyApp.Goth` not started). The
adapter should rescue this into `{:error, :goth_unconfigured}` to give
adopters a clean error tuple. `[ASSUMED]` — Goth docs don't enumerate the
exact exception type; planner should verify with a unit test.

### Section 2: Finch JSON API Request Shapes

All JSON API calls use the base host `https://storage.googleapis.com`. The
**upload endpoint is different** from the rest:

| Verb | Operation | Endpoint | Notes |
|------|-----------|----------|-------|
| GET (metadata) | `head/2` | `/storage/v1/b/$BUCKET/o/$ENCODED_OBJECT?alt=json` | Returns object resource JSON (size, contentType, md5Hash, generation) `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/objects/get]` |
| GET (media) | `download/3` | `/storage/v1/b/$BUCKET/o/$ENCODED_OBJECT?alt=media` | Returns raw bytes `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/objects/get]` |
| DELETE | `delete/2` | `/storage/v1/b/$BUCKET/o/$ENCODED_OBJECT` | 204 No Content on success `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/objects/delete]` |
| POST | `store/3` (multipart upload) | `/upload/storage/v1/b/$BUCKET/o?uploadType=multipart` | Different host path prefix (`/upload/...`); body is multipart/related `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/objects/insert]` |
| GET (bucket) | doctor check | `/storage/v1/b/$BUCKET` | 200 reachable, 403 forbidden, 404 not found |

**Object name URL encoding (CRITICAL):** Per Google docs, object names with
slashes MUST be percent-encoded — slash becomes `%2F` in the URL path
component. `URI.encode/1` is NOT sufficient (it leaves `/` alone); use
`URI.encode/2` with a custom safe-char predicate that excludes `/`, OR use
`:uri_string.quote/1` (OTP 25+):
```elixir
defp encode_object(key) do
  :uri_string.quote(key)  # OTP 25+; encodes / as %2F
end
```
`[ASSUMED — planner must verify]` — the exact OTP version semantics. See
A2 in Assumptions Log.

**Finch usage idiom (verified):**
```elixir
# Source: hexdocs.pm/finch/Finch.html
Finch.build(:get, url, headers, body)
|> Finch.request(MyApp.Finch, opts)
# => {:ok, %Finch.Response{status: 200, headers: [...], body: "..."}}
# or  {:error, %Mint.TransportError{...}}
```

**Multipart-upload body structure (verified for `store/3`):**

Per `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/objects/insert]`:

```
Content-Type: multipart/related; boundary=<RANDOM_BOUNDARY>

--<RANDOM_BOUNDARY>
Content-Type: application/json; charset=UTF-8

{"name": "path/to/object", "contentType": "image/jpeg", "contentDisposition": "inline; filename=\"x.jpg\""}

--<RANDOM_BOUNDARY>
Content-Type: image/jpeg

<binary bytes>
--<RANDOM_BOUNDARY>--
```

**Boundary marshalling rules:**
- Boundary string must NOT appear in either body part. Generate random
  enough (`:crypto.strong_rand_bytes(16) |> Base.url_encode64()`).
- `--` prefix on each boundary line, `--` suffix on the final terminator.
- CRLF line endings per RFC 2046.

**GCS error envelope (verified):**

`[CITED: docs.cloud.google.com/storage/docs/json_api/v1/status-codes]`

```json
{
  "error": {
    "code": 404,
    "message": "Not Found",
    "errors": [
      {"domain": "global", "reason": "notFound", "message": "Not Found"}
    ]
  }
}
```

**Error mapping (locked):**
- HTTP 404 + `error.errors[0].reason == "notFound"` -> `{:error, :not_found}`
- HTTP 403 -> `{:error, {:gcs_http_error, %{status: 403, body: parsed_body}}}`
- HTTP 5xx -> `{:error, {:gcs_http_error, %{status: 5xx, body: parsed_body}}}`
- Other 4xx -> `{:error, {:gcs_http_error, %{status: 4xx, body: parsed_body}}}`
- Network failure -> `{:error, %Mint.TransportError{}}` (let Finch's exception bubble up wrapped)

The `body` field in `{:gcs_http_error, %{status, body}}` should be
`Jason.decode/1`'d JSON map when content-type is `application/json`,
falling back to the raw binary otherwise.

### Section 3: V4 Signing via gcs_signed_url 0.4.6

**API surface (verified live source 2026-05-07):**

`GcsSignedUrl.Client.load/1` `[VERIFIED: github.com/alexandrubagu/gcs_signed_url/blob/main/lib/gcs_signed_url/client.ex]`:
- Accepts a decoded service-account JSON map: `%{"private_key" => pem, "client_email" => email}` (string keys)
- OR a file path string (which it `File.read!` + `Jason.decode!`s).
- Returns `%GcsSignedUrl.Client{private_key: pem, client_email: email}`.
- Does NOT validate PEM at construction time; validation happens at signing time via `:public_key.pem_decode/1`.

`GcsSignedUrl.generate_v4(client, bucket, filename, opts)` `[CITED: hexdocs.pm/gcs_signed_url/GcsSignedUrl.html]`:
- `client`: `%GcsSignedUrl.Client{}` (returns bare URL string) OR
  `%GcsSignedUrl.SignBlob.OAuthConfig{}` (returns `{:ok, url}` | `{:error, reason}`).
- `bucket`: bucket name string.
- `filename`: object key string.
- `opts`:
  - `verb: "GET" | "PUT"` (HTTP method)
  - `expires: integer` (TTL in seconds)
  - `headers: keyword` (additional headers signed into URL)
  - `query_params: keyword`
  - `valid_from: DateTime`
  - `host: String.t()` (custom host)

**Phase 37 call shape (private-key mode, locked):**
```elixir
# lib/rindle/storage/gcs/signer.ex
@spec sign_v4(client :: GcsSignedUrl.Client.t(), bucket :: String.t(),
              key :: String.t(), expires_in :: pos_integer()) :: {:ok, String.t()}
def sign_v4(client, bucket, key, expires_in) do
  url = GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: expires_in)
  {:ok, url}
end
```

**Credential normalization (`signing_key:` config can be map OR PEM):**
```elixir
defp build_client(%{} = service_account_json), do: GcsSignedUrl.Client.load(service_account_json)
defp build_client(pem) when is_binary(pem) do
  # If raw PEM (not full JSON), adopter must also configure :client_email
  %GcsSignedUrl.Client{private_key: pem, client_email: client_email_from_config()}
end
```

**Don't-enforce-via-URL invariant (D-03):** Phase 37 `url/2` MUST NOT
forward `response-content-disposition` or `response-content-type` query
params into the signed URL. Disposition/type live in object metadata at
`store/3` only (set via the multipart metadata JSON's `contentDisposition`
and `contentType` fields).

### Section 4: Bypass Fixture Topology

**Status:** Bypass is declared in `mix.exs:92` (`{:bypass, "~> 2.1", only: :test}`)
but NOT currently used anywhere in the test suite. Phase 37 introduces the
first Bypass usage. `[VERIFIED: grep -r Bypass lib/ test/]`

**Recommended topology (planner discretion per CONTEXT):** One `setup` block
per test file (`gcs/client_test.exs`), with helper macros for the four REST
verbs. This keeps tests close to the assertions they make. Shared fixture
modules add indirection that hurts read-time clarity in a 4-verb adapter.

**Fixture pattern (Bypass canonical idiom):**
```elixir
# test/rindle/storage/gcs/client_test.exs
defmodule Rindle.Storage.GCS.ClientTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    {:ok, bypass: bypass, base_url: base_url}
  end

  test "head_object/3 returns parsed metadata on 200", %{bypass: bypass, base_url: url} do
    Bypass.expect(bypass, "GET", "/storage/v1/b/test-bucket/o/foo%2Fbar.jpg", fn conn ->
      assert {"alt", "json"} in conn.query_params
      Plug.Conn.resp(conn, 200, ~s({"size":"1024","contentType":"image/jpeg"}))
    end)

    assert {:ok, %{size: 1024, content_type: "image/jpeg"}} =
             Client.head_object("foo/bar.jpg", base_url: url, bucket: "test-bucket", goth_token: "fake")
  end

  test "head_object/3 returns :not_found on 404", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/storage/v1/b/test-bucket/o/missing.jpg", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
    end)

    assert {:error, :not_found} = Client.head_object("missing.jpg", ...)
  end
end
```

**Multipart-upload body assertion (most complex test):**
```elixir
Bypass.expect(bypass, "POST", "/upload/storage/v1/b/test-bucket/o", fn conn ->
  assert {"uploadType", "multipart"} in conn.query_params

  # Read raw body (Bypass uses Plug.Conn — raw_body via :body_reader hack)
  {:ok, body, conn} = Plug.Conn.read_body(conn, length: 10_000_000)

  # Parse boundary from content-type header
  ["multipart/related; boundary=" <> boundary] =
    Plug.Conn.get_req_header(conn, "content-type")

  # Assert metadata part contains contentDisposition
  assert body =~ "contentDisposition"
  assert body =~ "image/jpeg"

  Plug.Conn.resp(conn, 200, ~s({"name":"foo.jpg","bucket":"test-bucket","generation":"123"}))
end)
```

**Bypass URL injection:** The `gcs.ex` adapter must accept a `base_url:`
opt that defaults to `"https://storage.googleapis.com"` so tests can swap
in `bypass.port`-derived URLs without monkey-patching the module. This is
standard Bypass discipline.

**Forbidden patterns:**
- Do NOT use `Bypass.stub/4` for assertion-bearing tests (it doesn't
  fail-fast on missing requests). Use `Bypass.expect/4` everywhere.
- Do NOT share one Bypass instance across `async: true` tests in different
  files (port collisions). Per-test setup is safe.

### Section 5: mux-soak Workflow Clone Discipline

**Source template:** `.github/workflows/ci.yml:566-653` `[VERIFIED: file read 2026-05-07]`

**Field-by-field spec for the new `gcs-soak` job:**

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
      image: postgres:16-alpine
      ports:
        - 5432:5432
      env:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
        POSTGRES_DB: rindle_test
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: "1.17"
        otp-version: "27"

    - name: Install libvips
      run: sudo apt-get install -y libvips-dev

    - name: Install dependencies
      run: mix deps.get

    - name: Run real-GCS soak proof
      run: mix test --only gcs
```

**Field-by-field deviations from `mux-soak`:**

| Field | mux-soak | gcs-soak | Why differ |
|-------|----------|----------|-----------|
| Trigger gate | `if: contains(github.event.pull_request.labels.*.name, 'streaming')` | `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}` | GCS-04 explicitly requires secret-presence gating, not label gating. Fork-PR safety: forks resolve secret to `''` and lane skips. |
| `RINDLE_MUX_*` env vars | All 5 Mux-specific secrets | Drop entirely | Different adapter |
| Mux `RINDLE_MUX_PASSTHROUGH_TAG` | `"rindle_soak"` for cleanup tagging | N/A | GCS objects can be cleaned by key prefix without server-side tagging |
| `RINDLE_MINIO_*` env vars | All 5 MinIO env vars | Drop entirely | GCS doesn't need MinIO bring-up |
| MinIO Docker bring-up + bucket creation steps (lines 626-646) | Required for Mux's broker-flow tests that go through MinIO storage | Drop entirely | GCS soak hits live Google bucket |
| Test command | `bash scripts/install_smoke.sh mux` | `mix test --only gcs` | Phase 37 is unit-level adapter coverage; package-consumer fresh-Phoenix install lane is Phase 41 |
| Cleanup step | `bash scripts/mux_soak_cleanup.sh` (Mux assets cost money) | None for Phase 37; ephemeral test objects are deleted by the test's `delete/2` call | If desired, planner can add `gcs_soak_cleanup.sh` to delete leftover `gcs-soak/*` keys; not strictly required |
| Matrix | None (single elixir 1.17/otp 27 line) | Same — single matrix row | Mirrors mux-soak exactly |

**Insertion point in `ci.yml`:** After line 653 (end of mux-soak), before
the next job. Don't reorder existing jobs.

**Fork-PR safety verification:** `pull_request` trigger (NOT
`pull_request_target`) means GitHub redacts secrets to empty string for
fork PRs. The `if:` check on `secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != ''`
short-circuits the entire job. This mirrors the v1.6 Phase 36 mux-soak
discipline. `[CITED: PROJECT.md key-decisions row "Generated-app mux-soak lane is label-gated"]`

### Section 6: Cross-Adapter Parity Test Obligations

**Source:** `test/rindle/storage/storage_adapter_test.exs:41-83` `[VERIFIED: file read 2026-05-07]`

**What GCS must export to pass without parity-test changes:**

The existing parity test (lines 41-51) iterates `Rindle.Storage.behaviour_info(:callbacks)`
and asserts `function_exported?/3` on `Local` and `S3`. To extend to GCS,
the planner has two options:

1. **Add GCS to the existing iteration** (lines 41-51):
   ```elixir
   for {name, arity} <- callbacks do
     assert function_exported?(Local, name, arity)
     assert function_exported?(S3, name, arity)
     assert function_exported?(Rindle.Storage.GCS, name, arity)
   end
   ```

2. **Add a new GCS-specific `capability` test alongside lines 77-83** (CLAUDE'S DISCRETION per CONTEXT):
   ```elixir
   test "GCS adapter capability list is truthful" do
     assert [:signed_url, :head] == Rindle.Storage.GCS.capabilities()
     assert Enum.all?(Rindle.Storage.GCS.capabilities(), &(&1 in Capabilities.known()))
   end
   ```

**Required exports (all 11 callbacks from the behaviour at `lib/rindle/storage.ex:67-198`):**

| Callback | Arity | Phase 37 implementation |
|----------|-------|------------------------|
| `store/3` | 3 | Real (multipart upload) |
| `download/3` | 3 | Real (GET ?alt=media) |
| `delete/2` | 2 | Real (DELETE) |
| `url/2` | 2 | Real (V4 signed) |
| `presigned_put/3` | 3 | Stub: `{:error, {:upload_unsupported, :presigned_put}}` |
| `initiate_multipart_upload/3` | 3 | Stub: `{:error, {:upload_unsupported, :multipart_upload}}` |
| `presigned_upload_part/5` | 5 | Stub: same |
| `complete_multipart_upload/4` | 4 | Stub: same |
| `abort_multipart_upload/3` | 3 | Stub: same |
| `head/2` | 2 | Real (GET ?alt=json) |
| `capabilities/0` | 0 | `[:signed_url, :head]` |

**Capability-list contract assertion (GCS-02 invariant):** Phase 37 MUST
add a unit test that pins the exact capability list. This catches Phase 39's
accidental early advertisement:
```elixir
test "GCS adapter advertises only signed_url and head in Phase 37" do
  assert Rindle.Storage.GCS.capabilities() == [:signed_url, :head]
  refute :resumable_upload in Rindle.Storage.GCS.capabilities()
  refute :resumable_upload_session in Rindle.Storage.GCS.capabilities()
end
```

### Section 7: mix rindle.doctor GCS Health Checks (D-13)

**Source template:** `lib/rindle/ops/runtime_checks.ex:526-643` `[VERIFIED: file read 2026-05-07]`

**Profile-aware discovery helper** (mirror `Rindle.Capability.configured_streaming_profiles/1`
at `lib/rindle/capability.ex:98-104`):

```elixir
@spec configured_gcs_profiles([module()]) :: [module()]
def configured_gcs_profiles(profiles) do
  for profile <- profiles,
      profile.storage() == Rindle.Storage.GCS do
    profile
  end
end
```

**Three new doctor checks** (Phase 37 ships, Phase 41 layers CORS check):

#### Check 1: `doctor.gcs_goth_running`

```elixir
defp check_gcs_goth_running(profiles, env) do
  cond do
    configured_gcs_profiles(profiles) == [] ->
      ok_result("doctor.gcs_goth_running", :gcs,
        "No GCS-enabled profiles discovered.", @gcs_goth_fix)

    not Code.ensure_loaded?(Goth) ->
      error_result("doctor.gcs_goth_running", :gcs,
        "GCS-enabled profile detected but :goth dep is not loaded.",
        @gcs_dep_missing_fix)

    true ->
      goth_name = configured_goth_name()  # from config :rindle, Rindle.Storage.GCS
      case Process.whereis(goth_name) do
        nil ->
          error_result("doctor.gcs_goth_running", :gcs,
            "Goth process #{inspect(goth_name)} is not running.",
            @gcs_goth_fix)
        pid when is_pid(pid) ->
          ok_result("doctor.gcs_goth_running", :gcs,
            "Goth process #{inspect(goth_name)} is alive.",
            @gcs_goth_fix)
      end
  end
end
```

#### Check 2: `doctor.gcs_bucket_reachable`

```elixir
defp check_gcs_bucket_reachable(profiles, _env) do
  # Skip if no GCS profile, no Goth dep, or no bucket configured
  # Issue GET /storage/v1/b/$BUCKET with 5s timeout
  # 200 -> ok (bucket exists)
  # 403 -> ok with note ("forbidden — bucket exists, IAM may need adjustment")
  # 404 -> error ("bucket not found")
  # network -> error
end
```

This check uses `Goth.fetch/1` to acquire a token, then a single Finch GET
to `https://storage.googleapis.com/storage/v1/b/$BUCKET`. 403 is treated as
"reachable" because the bucket exists but the IAM grant might just be
read-restricted — distinguishing this from `404 not found` is the diagnostic
value.

#### Check 3: `doctor.gcs_signing_key`

Mirror `verify_signing_key_pem/1` at `lib/rindle/ops/runtime_checks.ex:612-643`:

```elixir
defp check_gcs_signing_key(profiles, _env) do
  # Skip if no GCS profile or no :gcs_signed_url dep
  # Read config :rindle, Rindle.Storage.GCS, :signing_key
  # If map: try GcsSignedUrl.Client.load(map) — must return %GcsSignedUrl.Client{}
  # If string (PEM): parse via :public_key.pem_decode/1, check non-empty
  # On exception, surface struct name only (NOT message — could leak PEM)
end
```

**Critical invariant** from `runtime_checks.ex:632-636`: rescue clause must
report `inspect(exception.__struct__)` only, NOT `Exception.message/1` —
the message could echo PEM content into doctor output, which then ends up
in CI logs.

**Profile-awareness:** All three checks gate on
`configured_gcs_profiles(profiles) == []`, returning `ok_result` with
"No GCS-enabled profiles discovered." This is the v1.6 Mux template
(`runtime_checks.ex:528-534`). Image-only S3 adopters see no new noise.

**Wiring:** Add three new `fn -> check_gcs_*/2 end` entries to the `checks`
list in `Rindle.Ops.RuntimeChecks.run/2` (around `runtime_checks.ex:67-81`).

### Section 8: mix.exs Declarations Diff

**Three diffs in `mix.exs`:**

#### Diff 1: `dialyzer.plt_add_apps` (line 22)

```elixir
# Before:
plt_add_apps: [:mix, :ex_unit, :mux, :jose],

# After:
plt_add_apps: [:mix, :ex_unit, :mux, :jose, :goth, :gcs_signed_url],
```

**Open question on `:finch`:** CONTEXT D-07 states finch is "already in tree
as a non-optional dep elsewhere." Verification (`mix deps.tree | grep finch`)
shows finch is NOT in the tree currently. Once `:goth` is added, finch
arrives transitively as a runtime dep. Whether finch needs to be in
`plt_add_apps` depends on whether the adapter calls Finch APIs that have
their own typespecs needing PLT inclusion. **Recommendation:** add `:finch`
to `plt_add_apps` defensively; it's cheap and correct. Planner should make
this decision in the GCS-01 plan.

#### Diff 2: `deps/0` (after line 69)

```elixir
# Insert after the existing optional streaming deps block:
{:mux, "~> 3.2", optional: true},
{:jose, "~> 1.11", optional: true},

# GCS storage adapter (optional — Phase 37; only loads when adopter opts in)
{:goth, "~> 1.4", optional: true},
{:finch, "~> 0.21", optional: true},
{:gcs_signed_url, "~> 0.4.6", optional: true},
```

#### Diff 3: hexdoc grouping (lines 158-163)

```elixir
"Storage and Processor Adapters": [
  Rindle.Storage,
  Rindle.Storage.Local,
  Rindle.Storage.S3,
  Rindle.Storage.GCS,        # ADD; alphabetical placement after S3 is fine
  Rindle.Processor.Image
],
```

**`gcs/client.ex` and `gcs/signer.ex` MUST stay `@moduledoc false`** so they
don't appear in hexdoc. This is the locked v1.6 Phase 35 pattern (raw-body
cache and webhook signature verification helpers are `@moduledoc false`).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JWT signing for V4 signed URLs | Custom JWT/RSA-SHA256 | `gcs_signed_url ~> 0.4.6` | Security-sensitive crypto; getting V4 canonical-request hashing wrong silently produces invalid URLs |
| GCP OAuth2 token refresh | Custom token-cache GenServer | `goth ~> 1.4` | Goth handles refresh-300s-before-expiry, retry-on-401, metadata-server discovery, refresh-token rotation — non-trivial state machine |
| GCS JSON API client | `google_api_storage 0.46.1` | Hand-rolled Finch wrapper | Tesla-coupled; pulls 200+ modules; `storage_objects_insert_resumable/5` returns `{:ok, nil}` (no session URI). Per locked candidate §3 |
| Content-Disposition / Content-Type enforcement | Append `response-content-disposition`/`response-content-type` to signed URL | Set as object metadata at `store/3` (`contentDisposition`, `contentType` JSON fields) | Active Storage CVE-adjacent lesson; GCS V4 signed URLs do NOT safely enforce these query params |
| HTTP client | Tesla / Req in adapter hot path | Finch | Tesla adds opinionated middleware + transitive deps; Req adds 2+ deps. Finch is minimal and is what Goth already pulls in. Req is fine for tests. |
| Goth/Finch supervision | Add `Rindle.Application` children | Adopter starts them in their app's supervision tree | Locked v1.4/v1.6 invariant: adopter owns runtime. Same posture as Repo, Oban, Goth from v1.6 Mux work |
| Multipart MIME body builder | Custom string concatenation with manual boundary handling | Hand-rolled is acceptable here (~30 lines) — but reuse a helper for tests | Multipart marshalling is shallow; pulling in `multipart` library would be overkill. The risk is forgetting CRLF or terminator `--`. Test it specifically. |
| Object name URL encoding | `URI.encode/1` (leaves `/` alone) | Use `:uri_string.quote/1` (OTP 25+) or `URI.encode/2` with custom safe-char predicate that excludes `/` | GCS requires `/` encoded as `%2F` in object name URL path component |
| Custom error envelope | Bespoke parsing | `Jason.decode/1` on `body` when `content-type: application/json` | GCS error envelope is stable JSON with consistent shape per `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/status-codes]` |

**Key insight:** Every "don't hand-roll" item above is a place where the
adapter would silently produce broken behavior if rolled custom. V4 signing
gets the canonical-request hash wrong -> URLs return 403 with no clear reason.
Token refresh wrong -> 401s under load. Multipart boundary wrong -> GCS
returns 400 with Google-specific error code that's hard to debug.

---

## Common Pitfalls

### Pitfall 1: Object name URL encoding leaves `/` unencoded

**What goes wrong:** `Rindle.upload/3` writes object key `"assets/123/original.jpg"`.
Adapter does `URI.encode("assets/123/original.jpg")` -> no change. GET request
goes to `/storage/v1/b/bucket/o/assets/123/original.jpg` — GCS interprets
this as a path with two `/` separators in the object name and returns 404.

**Why it happens:** Elixir's `URI.encode/1` defaults to RFC 3986 path
encoding which considers `/` a reserved char to preserve. GCS JSON API
requires the object name to be a single path segment, so `/` must be
percent-encoded.

**How to avoid:** Use `:uri_string.quote/1` or define a helper that escapes
`/` explicitly. Add a unit test for keys containing slashes.

**Warning signs:** 404 errors from `head/2` for keys you just stored;
mismatched object names in `Bypass.expect/4` URL parameters.

### Pitfall 2: Region hint isn't enforceable from JSON API

**What goes wrong:** Adopter sets `region_hint: "us-central1"` in config.
Phase 37 surfaces it as informational metadata only. Adopter writes a test
expecting the adapter to reject objects stored in the wrong region — test
fails because the JSON API doesn't expose region in the response shape.

**Why it happens:** GCS region is a bucket-level property, not an object-
level one. The JSON API's object metadata response contains `bucket` and
`generation` but not `location`. Region pinning is enforced at bucket
creation in GCP console, not at adapter layer.

**How to avoid:** Document `region_hint` as adopter-facing telemetry/
diagnostic info only, not as a runtime guard. Phase 39 may use it for
resumable initiation telemetry warnings (`:region_pinned_initiation`).

### Pitfall 3: Fork-PR secret resolves to empty string, lane silently skips

**What goes wrong:** Adopter forks the repo, opens PR. Their fork doesn't
have `GOOGLE_APPLICATION_CREDENTIALS_JSON` configured. The `gcs-soak` lane's
`if:` resolves the secret to `''` and the lane skips. PR shows "no required
checks failed" but GCS coverage is silent.

**Why it happens:** GitHub's `pull_request` trigger redacts secrets to empty
string for fork PRs (this is the desired behavior — you don't want secrets
exposed to fork code). The lane skip is intentional.

**How to avoid:** Make `gcs-soak` non-required in branch protection rules.
The release lane (push to main / tag) always has the secret available, so
release-time coverage is the gate. Document this in `guides/release_publish.md`
or planner's verification notes.

**Warning signs:** PR opened from a fork shows "GCS Soak (real bucket) —
Skipped" in the checks UI.

### Pitfall 4: Parity-test obligations creep into Phase 37 incorrectly

**What goes wrong:** Planner adds resumable callbacks to the parity test in
Phase 37, expecting Phase 39 to fill them in. Phase 39 advertises the
capability list change; Phase 37 ships with `function_exported?(GCS, :initiate_resumable_upload, 3)`
asserted false but the test passes because the assertion was forgotten.

**Why it happens:** The behaviour at `lib/rindle/storage.ex:198` doesn't
yet declare `@optional_callbacks :initiate_resumable_upload` etc.; Phase 39
adds those. Phase 37 cannot reference resumable callbacks at all without
breaking the behaviour contract.

**How to avoid:** Phase 37 parity test iterates ONLY over the existing 11
callbacks at `lib/rindle/storage.ex`. Phase 39 adds the 4 resumable
callbacks AND the parity-test assertions in the same plan.

### Pitfall 5: Hexdoc inadvertently exposes `gcs/client.ex` or `gcs/signer.ex`

**What goes wrong:** Planner adds `Rindle.Storage.GCS.Client` to the hexdoc
"Storage and Processor Adapters" group. ExDoc generates a public-looking
page for the internal Finch wrapper. Adopters see it in search results and
build dependencies on `Rindle.Storage.GCS.Client.head_object/3`. Phase 39
refactors `Client` to support resumable, breaking the assumed-public API.

**Why it happens:** ExDoc respects `@moduledoc false` to hide modules — but
ONLY if the module isn't explicitly listed in `groups_for_modules`. Adding
the internal modules to a group makes them visible.

**How to avoid:** ONLY `Rindle.Storage.GCS` in the hexdoc group. `gcs/client.ex`
and `gcs/signer.ex` get `@moduledoc false` and are NOT listed in `mix.exs:158-163`.

### Pitfall 6: Goth instance not running raises `ArgumentError`, not returns error tuple

**What goes wrong:** Adopter forgets `{Goth, name: MyApp.Goth, source: ...}`
in supervision tree. Adapter calls `Goth.fetch(MyApp.Goth)` and crashes
with `ArgumentError` (no process registered with that name). User sees a
crash dump instead of a clean `{:error, :goth_unconfigured}` tuple.

**Why it happens:** Goth's `fetch/1` calls `GenServer.call/2` on a registered
name; if no process has that name, GenServer raises immediately. This is
NOT the same as the `Code.ensure_loaded?` path (which checks if the module
is compiled at all).

**How to avoid:** Two-tier guard:
1. `Code.ensure_loaded?(Goth)` checks compile-time presence (gives
   `:goth_unconfigured` if `:goth` dep not added).
2. `try/rescue ArgumentError` around `Goth.fetch/1` (gives
   `:goth_unconfigured` if process not running).

Both paths return the same atom for adopter clarity.

**Warning signs:** Doctor check passes (Goth is loaded) but adapter calls
crash at runtime with `ArgumentError`.

### Pitfall 7: Multipart-upload boundary collides with file content

**What goes wrong:** Adapter generates boundary `"abc123"`. Source file
contains the literal string `"abc123"` somewhere. GCS parses the multipart
body and finds the boundary inside the media part — request fails with 400
"Invalid multipart body" or, worse, succeeds but with truncated content.

**Why it happens:** Multipart MIME requires the boundary to never appear
in any part body. With long enough random boundaries, collision is
astronomically unlikely, but a 6-char boundary in test fixtures can collide.

**How to avoid:** Use `:crypto.strong_rand_bytes(16) |> Base.url_encode64()` —
22-char URL-safe random boundary. Document the discipline.

### Pitfall 8: Live-bucket test leaks objects when adapter delete fails

**What goes wrong:** Test creates object, asserts on `head/2` result, then
calls `delete/2` for cleanup. Assertion fails before delete runs. Object
stays in bucket forever. Repeated CI runs accumulate orphans.

**Why it happens:** ExUnit doesn't have an automatic cleanup hook unless
the test wires `on_exit/1`.

**How to avoid:** Always wrap object creation in `on_exit/1` cleanup:
```elixir
test "head/2 returns size" do
  key = "gcs-soak/#{System.unique_integer([:positive])}.bin"
  on_exit(fn -> Rindle.Storage.GCS.delete(key, opts()) end)

  Rindle.Storage.GCS.store(key, source_path, opts())
  assert {:ok, %{size: _}} = Rindle.Storage.GCS.head(key, opts())
end
```

Optionally, add a key-prefix cleanup script (`scripts/gcs_soak_cleanup.sh`)
that lists and deletes all `gcs-soak/*` keys older than 1 hour, run via
`if: always()` step in the workflow (mirrors `mux_soak_cleanup.sh`).

---

## Code Examples

### Goth.fetch / Finch.build call shape

```elixir
# lib/rindle/storage/gcs/client.ex
defmodule Rindle.Storage.GCS.Client do
  @moduledoc false

  @base_url "https://storage.googleapis.com"

  def head_object(key, opts) do
    with {:ok, bucket} <- fetch_bucket(opts),
         {:ok, headers} <- authorized_headers(opts) do
      url = "#{base_url(opts)}/storage/v1/b/#{bucket}/o/#{encode_object(key)}?alt=json"

      :get
      |> Finch.build(url, headers)
      |> Finch.request(finch_name(opts))
      |> handle_metadata_response()
    end
  end

  defp authorized_headers(opts) do
    goth_name = goth_name(opts)

    try do
      case Goth.fetch(goth_name) do
        {:ok, %Goth.Token{type: type, token: token}} ->
          {:ok, [{"authorization", "#{type} #{token}"}]}

        {:error, _reason} ->
          {:error, :goth_unconfigured}
      end
    rescue
      ArgumentError -> {:error, :goth_unconfigured}
    end
  end

  defp handle_metadata_response({:ok, %Finch.Response{status: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"size" => size_str, "contentType" => ct}} ->
        {:ok, %{size: String.to_integer(size_str), content_type: ct}}

      {:ok, %{"size" => size_str}} ->
        {:ok, %{size: String.to_integer(size_str), content_type: nil}}

      {:error, _reason} ->
        {:error, {:gcs_http_error, %{status: 200, body: body}}}
    end
  end

  defp handle_metadata_response({:ok, %Finch.Response{status: 404}}) do
    {:error, :not_found}
  end

  defp handle_metadata_response({:ok, %Finch.Response{status: status, body: body}}) do
    parsed = case Jason.decode(body) do
      {:ok, json} -> json
      _ -> body
    end
    {:error, {:gcs_http_error, %{status: status, body: parsed}}}
  end

  defp handle_metadata_response({:error, exception}) do
    {:error, exception}
  end

  defp encode_object(key), do: :uri_string.quote(key)
end
```

### gcs_signed_url V4 call shape

```elixir
# lib/rindle/storage/gcs/signer.ex
defmodule Rindle.Storage.GCS.Signer do
  @moduledoc false

  @spec sign_v4(GcsSignedUrl.Client.t(), bucket :: String.t(),
                key :: String.t(), expires_in :: pos_integer()) :: {:ok, String.t()}
  def sign_v4(client, bucket, key, expires_in) do
    url = GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: expires_in)
    {:ok, url}
  end

  @spec build_client(map() | String.t()) :: {:ok, GcsSignedUrl.Client.t()} | {:error, atom()}
  def build_client(%{"private_key" => _, "client_email" => _} = service_account_json) do
    {:ok, GcsSignedUrl.Client.load(service_account_json)}
  end

  def build_client(_), do: {:error, :signing_key_unconfigured}
end
```

### Bypass.expect block (canonical 4-verb fixture)

```elixir
defmodule Rindle.Storage.GCS.ClientTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    {:ok, finch_pid} = Finch.start_link(name: __MODULE__.Finch)

    on_exit(fn -> Process.exit(finch_pid, :normal) end)

    {:ok,
     bypass: bypass,
     base_url: base_url,
     opts: [
       base_url: base_url,
       bucket: "test-bucket",
       finch: __MODULE__.Finch,
       goth_token: "fake-token-for-testing"
     ]}
  end

  describe "head_object/2" do
    test "returns size + content_type on 200", %{bypass: bypass, opts: opts} do
      Bypass.expect(bypass, "GET", "/storage/v1/b/test-bucket/o/foo.jpg", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["alt"] == "json"
        Plug.Conn.resp(conn, 200, ~s({"size":"1024","contentType":"image/jpeg"}))
      end)

      assert {:ok, %{size: 1024, content_type: "image/jpeg"}} =
               Rindle.Storage.GCS.Client.head_object("foo.jpg", opts)
    end

    test "returns :not_found on 404", %{bypass: bypass, opts: opts} do
      Bypass.expect(bypass, "GET", "/storage/v1/b/test-bucket/o/missing.jpg", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
      end)

      assert {:error, :not_found} =
               Rindle.Storage.GCS.Client.head_object("missing.jpg", opts)
    end

    test "returns gcs_http_error on 403", %{bypass: bypass, opts: opts} do
      Bypass.expect(bypass, "GET", "/storage/v1/b/test-bucket/o/forbidden.jpg", fn conn ->
        Plug.Conn.resp(conn, 403, ~s({"error":{"code":403,"message":"Forbidden"}}))
      end)

      assert {:error, {:gcs_http_error, %{status: 403, body: %{"error" => _}}}} =
               Rindle.Storage.GCS.Client.head_object("forbidden.jpg", opts)
    end
  end
end
```

### mux-soak field-by-field clone (full gcs-soak block)

```yaml
# Insert after line 653 (end of mux-soak block) in .github/workflows/ci.yml

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
        image: postgres:16-alpine
        ports:
          - 5432:5432
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: rindle_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.17"
          otp-version: "27"

      - name: Install libvips
        run: sudo apt-get install -y libvips-dev

      - name: Install dependencies
        run: mix deps.get

      - name: Run real-GCS soak proof
        run: mix test --only gcs
```

---

## Project Constraints (from CLAUDE.md)

`./CLAUDE.md` does not exist in this repository (verified via `Read` tool —
"File does not exist"). All project conventions are inherited from
`.planning/PROJECT.md` (constraints section at lines 296-311) and the
existing source patterns in `lib/`.

Constraints inherited from PROJECT.md:

- **Tech stack:** Elixir/Phoenix/Ecto only in core; no non-Elixir runtime in
  the library. Phase 37 satisfies — Goth/Finch/gcs_signed_url are
  pure-Elixir.
- **Repo ownership:** adopter apps own the runtime Repo. Not relevant
  to Phase 37 (no DB changes).
- **Background jobs:** Oban remains the required job backend. Not
  relevant to Phase 37 (no Oban work).
- **Security defaults:** private delivery remains the default. Phase 37
  signed URLs are private by default; no public-bucket assumption.
- **Capability honesty:** adapters advertise only what they truly support.
  GCS-02 invariant; capability list is exactly `[:signed_url, :head]`.
- **Backward compatibility:** existing presigned PUT flows stay supported.
  Phase 37 is purely additive; S3 and Local adapters untouched.
- **Docs posture:** practical, copy-pasteable, production-aware,
  maintainer-to-maintainer. `guides/storage_gcs.md` defers to Phase 41,
  but in-module docs in `gcs.ex` should follow this tone.

Security invariant 14 (PROJECT.md line 340): "Provider-internal IDs (Mux
asset_id, upload IDs, session URIs) redact to last-4-char tag in telemetry,
logs, and Inspect output." Phase 37 has NO session URIs (resumable is
Phase 39); GCS object generation IDs are not bearer credentials and don't
need redaction. The Goth `Bearer <token>` Authorization header MUST NEVER
be logged — that IS a bearer credential.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (OTP-bundled) + ExUnit `@tag` filter |
| Config file | `test/test_helper.exs` (already exists; tag exclusions configured there if needed) |
| Quick run command | `mix test test/rindle/storage/gcs_test.exs` |
| Full suite command | `mix test` (excludes `:gcs` and `:minio` tags by default; CI lanes opt in) |
| Soak command | `mix test --only gcs` (live bucket, runs in `gcs-soak` lane) |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GCS-01 | `store/3` round-trips bytes via multipart upload | unit (Bypass) | `mix test test/rindle/storage/gcs/client_test.exs:test_store_round_trip -x` | Wave 0 |
| GCS-01 | `download/3` writes bytes to destination | unit (Bypass) | `mix test test/rindle/storage/gcs/client_test.exs:test_download -x` | Wave 0 |
| GCS-01 | `delete/2` returns idempotent on missing | unit (Bypass) | `mix test test/rindle/storage/gcs/client_test.exs:test_delete -x` | Wave 0 |
| GCS-01 | `head/2` returns size + content_type | unit (Bypass) | `mix test test/rindle/storage/gcs/client_test.exs:test_head -x` | Wave 0 |
| GCS-01 | All 5 callbacks against live bucket | integration (proof) | `mix test --only gcs` (gcs-soak lane) | Wave 0 |
| GCS-02 | `capabilities/0 == [:signed_url, :head]` | unit (capability) | `mix test test/rindle/storage/gcs_test.exs:test_capabilities -x` | Wave 0 |
| GCS-02 | Cross-adapter parity (all 11 callbacks exported) | parity | `mix test test/rindle/storage/storage_adapter_test.exs:41 -x` | exists; extend |
| GCS-03 | V4 signed URL generation | unit (signer) | `mix test test/rindle/storage/gcs/signer_test.exs -x` | Wave 0 |
| GCS-03 | TTL fallback to `Rindle.Config.signed_url_ttl_seconds/0` | unit | `mix test test/rindle/storage/gcs_test.exs:test_url_ttl_fallback -x` | Wave 0 |
| GCS-03 | Content-Disposition / Content-Type written as object metadata at `store/3` | unit (Bypass; assert on multipart body) | `mix test test/rindle/storage/gcs/client_test.exs:test_store_metadata_fields -x` | Wave 0 |
| GCS-04 | `gcs-soak` job exists, secret-gated | structural (parity check on workflow YAML) | `grep -q "gcs-soak" .github/workflows/ci.yml && grep -q "GOOGLE_APPLICATION_CREDENTIALS_JSON" .github/workflows/ci.yml` | Wave 0 (workflow file edit) |
| GCS-04 | Live-bucket integration runs against secret | proof | `gcs-soak` lane runs `mix test --only gcs` against real bucket | Wave 0 |
| Doctor (D-13) | `doctor.gcs_goth_running` profile-aware | unit | `mix test test/rindle/ops/runtime_checks_test.exs:test_check_gcs_goth_running -x` | Wave 0 |
| Doctor (D-13) | `doctor.gcs_bucket_reachable` 200/403/404 distinction | unit (Bypass) | `mix test test/rindle/ops/runtime_checks_test.exs:test_check_gcs_bucket_reachable -x` | Wave 0 |
| Doctor (D-13) | `doctor.gcs_signing_key` parses map and PEM | unit | `mix test test/rindle/ops/runtime_checks_test.exs:test_check_gcs_signing_key -x` | Wave 0 |
| Doctor (D-13) | All three checks return ok when no GCS profile | unit | `mix test test/rindle/ops/runtime_checks_test.exs:test_doctor_no_gcs_profile -x` | Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/storage/gcs_test.exs test/rindle/storage/gcs/`
- **Per wave merge:** `mix test` (excludes `:gcs` tag; runs Bypass-only unit tests)
- **Phase gate:** Full suite green + `gcs-soak` lane green on a release branch (PR carrying the secret env, or a release tag)

### 8 Nyquist Validation Dimensions

| Dimension | Phase 37 Coverage | Files |
|-----------|------------------|-------|
| **Unit** | Per-callback unit tests against Bypass | `test/rindle/storage/gcs/client_test.exs`, `signer_test.exs` |
| **Integration** | Bypass-mocked end-to-end (multi-callback flows) | `test/rindle/storage/gcs_test.exs` (no `@tag :gcs`) |
| **Proof** | Live bucket via `gcs-soak` lane | `test/rindle/storage/gcs_test.exs` (`@tag :gcs`) |
| **Parity** | Cross-adapter exports + capability shape | `test/rindle/storage/storage_adapter_test.exs:41-83` (extend) |
| **Capability** | `capabilities/0` snapshot test pinning `[:signed_url, :head]` | `test/rindle/storage/gcs_test.exs` |
| **Error-path** | Google error envelope mapping (404 -> `:not_found`, 403/5xx -> `{:gcs_http_error, _}`, no Goth -> `:goth_unconfigured`) | `test/rindle/storage/gcs/client_test.exs` |
| **Config** | `Application.get_env(:rindle, Rindle.Storage.GCS, [])[:bucket]` resolution + `:missing_bucket` error | `test/rindle/storage/gcs_test.exs` |
| **Doctor** | `mix rindle.doctor` profile-aware GCS checks | `test/rindle/ops/runtime_checks_test.exs` |

### Wave 0 Gaps

- [ ] `test/rindle/storage/gcs_test.exs` — covers GCS-01, GCS-02, GCS-03 (adapter-level integration via Bypass + live `@tag :gcs` flag)
- [ ] `test/rindle/storage/gcs/client_test.exs` — covers GCS-01 (4 REST verbs against Bypass)
- [ ] `test/rindle/storage/gcs/signer_test.exs` — covers GCS-03 (V4 signing, no HTTP)
- [ ] `test/rindle/storage/storage_adapter_test.exs` — extension to cover GCS in existing parity iteration (lines 41-51, 77-83)
- [ ] `test/rindle/ops/runtime_checks_test.exs` — extension for 3 new doctor checks (file likely exists; verify and extend)
- [ ] No new test framework install — ExUnit + Bypass + Mox already in tree

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `goth ~> 1.4` for OAuth2 service-account; never hand-roll |
| V3 Session Management | n/a | Stateless adapter; no sessions |
| V4 Access Control | yes | Adopter-side IAM grants on the bucket; adapter never bypasses |
| V5 Input Validation | yes | Object name URL encoding; `:missing_bucket` guard; multipart boundary collision-resistance |
| V6 Cryptography | yes | `gcs_signed_url ~> 0.4.6` for V4 RSA-SHA256 signing — never hand-roll |
| V7 Error Handling | yes | Don't leak signing key PEM in exception messages; rescue clause inspects struct name only (mirrors `runtime_checks.ex:632-636`) |
| V9 Communications | yes | TLS via Finch (default); enforce HTTPS in `@base_url` constant |
| V10 Malicious Code | n/a | No code execution from user input |
| V11 Business Logic | yes | Adapter does NOT perform authorization (per `lib/rindle/storage.ex:104-106`); adopter checks before calling `url/2` |
| V13 API & Web Service | yes | JSON API client; `:gcs_http_error` envelope handling |
| V14 Configuration | yes | Optional-dep guard; `Code.ensure_loaded?` pattern; named-instance lookup |

### Known Threat Patterns for GCS Adapter

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Bearer token leakage in logs | I (Information Disclosure) | NEVER include `Authorization` header in error tuples or log statements; `{:gcs_http_error, %{body: ...}}` only carries response body, not request headers |
| Signing key PEM leakage in doctor output | I (Information Disclosure) | Doctor's signing-key check rescues exceptions and reports `inspect(exception.__struct__)` only — never `Exception.message/1`. Locked pattern from `runtime_checks.ex:632-636` |
| Object name path traversal | T (Tampering) / E (Elevation of Privilege) | `Rindle.Security.StorageKey.generate/3` (already in tree per `lib/rindle/security/storage_key.ex`) prevents `..` and absolute paths in keys before they reach adapter |
| URL encoding bypass (`/` not encoded) | T (Tampering) | Encode object names with `:uri_string.quote/1` or equivalent; unit-test keys with slashes, leading dots, special chars |
| Signed URL forwarded `response-content-disposition` enabling content-injection | T (Tampering) | Disposition lives in object metadata at `store/3`, NOT URL params (D-03 invariant; Active Storage CVE-adjacent lesson) |
| Token reuse across adopters in multi-tenant doctor smoke ping | I (Information Disclosure) | Doctor checks gate on `configured_gcs_profiles(profiles)` — image-only S3 adopters never trigger Goth fetch |
| `Code.LoadError` crash leaking install state | D (Denial of Service / poor UX) | `Code.ensure_loaded?(Goth)` first; `try/rescue ArgumentError` around Goth fetch — both return `:goth_unconfigured` cleanly |
| Multipart-boundary collision causing GCS to misparse body | T (Tampering) | 22-char URL-safe random boundary via `:crypto.strong_rand_bytes(16) |> Base.url_encode64()` — astronomical collision-resistance |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Goth.fetch/1` raises `ArgumentError` (specifically) when the named process is not registered | Section 1, Pitfall 6 | Adapter rescue clause catches wrong exception type; user sees crash dump instead of `:goth_unconfigured`. Planner verifies with a unit test that doesn't start Goth. |
| A2 | Object name URL encoding requires `/` -> `%2F` (i.e., `:uri_string.quote/1` or equivalent) | Section 2, Pitfall 1, "Don't Hand-Roll" | If GCS accepts un-encoded `/`, redundant encoding still works. If it requires encoding and we omit, all multi-segment keys 404. Verify with one Bypass test using a key like `"a/b/c.jpg"`. |
| A3 | `Code.LoadError` is the right exception class for missing optional dep, not `UndefinedFunctionError` | Section 1, "Architecture Patterns" Pattern 2 | The `Code.ensure_loaded?(Goth)` guard prevents EITHER error path from being reached. Pattern is locked in v1.6 Phase 36. |
| A4 | `:finch` should be added to `mix.exs:22 plt_add_apps` despite CONTEXT D-07 saying "already in tree as a non-optional dep elsewhere" | Section 8, "Open Questions" | If CONTEXT statement was correct and `:finch` is already there transitively, adding it is a no-op. Verification (`mix deps.tree`) shows `:finch` is NOT in the tree, so D-07's claim is incorrect. **Recommend adding it defensively.** |
| A5 | The GCS doctor "bucket reachable" check should use a single `GET /storage/v1/b/$BUCKET` and distinguish 200/403/404 | Section 7 | If 403 means something subtler (e.g., specific role missing), planner may want to add per-error fix-text. Phase 37 ships the basic 3-status distinction; Phase 41 can layer detail. |
| A6 | `:public_key.pem_decode/1` accepts PEM strings without a trailing newline | Section 7 | Standard OTP API; well-tested. Planner can verify with a one-line `iex` repro. |
| A7 | `URI.encode/1` does NOT encode `/` (so we need a different helper) | Section 2, Pitfall 1 | Verified in IEx: `URI.encode("a/b") == "a/b"` (no encoding of `/`). HIGH confidence — standard Elixir library behavior documented in `URI` module docs. |

**Confirmation requirement:** None of these assumptions are decision-blocking
for the planner. Each can be verified with a single `iex` session or unit
test during plan execution. Recommend the plans include verification steps
in their first task.

---

## Open Questions (RESOLVED)

1. **Is `:finch` already a transitive non-optional dep?** — **RESOLVED 2026-05-07.**
   - Verified: `mix deps.tree | grep finch` returns empty; `mix.lock:60`
     shows `:finch` only as Tesla's `optional: true` ref. CONTEXT D-07's
     "already in tree as a non-optional dep elsewhere" is wrong.
   - **Resolution:** Plan 01 adds `{:finch, "~> 0.21", optional: true}` to
     `mix.exs` deps AND adds `:finch` to `plt_add_apps`. Plans cite
     Pitfall-numbering "Q9 / A4" for this override.

2. **Which Goth fetch variant: `Goth.fetch/1` or `Goth.fetch!/1`?** — **RESOLVED 2026-05-07.**
   - **Resolution:** Use `Goth.fetch/1` (return-tuple). The adapter
     translates `nil` / `{:error, _}` → `{:error, :goth_unconfigured}`.
     CRITICAL — see Pitfall 6: when the named Goth instance is NOT in the
     supervision tree, `Goth.fetch/1` raises `ArgumentError` (NOT `:exit,
     :noproc`). Plans MUST `rescue ArgumentError` (defense-in-depth: also
     `catch :exit, _` is fine but ArgumentError is the documented path).

3. **Should `download/3` stream to disk or load entire body to memory?** — **RESOLVED 2026-05-07.**
   - **Resolution:** Phase 37 ships load-to-memory via `Finch.request/3`
     (simpler; Phase 37 adopters use the image-only local-file ingest
     path). `Finch.stream/4` deferred to Phase 38–39 resumable work where
     large-file paths matter. TODO-comment in `gcs/client.ex` flags the
     follow-up.

4. **Does `Bypass` work with `async: true` ExUnit cases?** — **RESOLVED 2026-05-07.**
   - **Resolution:** Plan 01 ships `gcs/client_test.exs` with `async:
     false` (conservative). Each `Bypass.open()` allocates a fresh port,
     and the existing rindle test suite has no Bypass adopter — this is
     the first. If subsequent phases prove `async: true` is safe across
     N suite runs, flip to `async: true` then.

5. **Should the `signing_key` config support a file path string in
   addition to map and PEM?** — **RESOLVED 2026-05-07 (LOCKED).**
   - **Resolution:** Phase 37 supports **decoded JSON map (preferred)
     and PEM string only**. File-path loading is adopter responsibility
     (decode at app boot via `Jason.decode!(File.read!(...))`, pass the
     map). Plans MUST raise `ArgumentError` for file-path input — file
     might not exist at runtime, security ergonomics differ between
     deploy environments, and CONTEXT D-08's literal config example
     comment reads "service-account JSON or PEM" (no file path). This
     resolution OVERRIDES any earlier plan that accepted file paths via
     `GcsSignedUrl.Client.load_from_file/1`.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| V2 signing for GCS signed URLs | V4 signing only | 2018 (Google deprecation) | V4 is required; `gcs_signed_url ~> 0.4.6` defaults to V4 |
| `google_api_storage` Tesla SDK | Hand-rolled Finch JSON API client | Locked v1.6 candidate (2026-05-06) | 200+ module reduction; clean session URI surfacing for Phase 38–39 |
| `Companion`-style server-side proxy uploads | Direct browser->GCS via signed URL or resumable session | Active Storage / Uppy modern pattern | Browser uploads bytes directly; server never proxies |
| Custom JWT signing per app | `gcs_signed_url` library | 2020 (library mature) | Security-sensitive crypto delegated to vetted library |

**Deprecated/outdated:**
- `Goth 1.3.x` — superseded by `1.4.x` (current 1.4.5); only `~> 1.4` constraint accepted.
- `Finch 0.20.x` — superseded by `0.21.0` (2026-01-22); use `~> 0.21`.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All | yes | 1.17+ | — |
| Erlang/OTP | All | yes | 27+ | — |
| `mix hex.info goth` | Plan execution | yes | 1.4.5 | — |
| `mix hex.info finch` | Plan execution | yes | 0.21.0 | — |
| `mix hex.info gcs_signed_url` | Plan execution | yes | 0.4.6 | — |
| Live GCS bucket | `gcs-soak` lane only | no (no local credentials) | — | Skip live tests; Bypass coverage stands alone for Phase 37 verification |
| `gh` CLI | Source code lookups | yes | (verified via `gh api` calls during research) | WebFetch fallback |

**Missing dependencies with no fallback:** None. Phase 37 plans can execute
without a live GCS bucket — the secret-gated `gcs-soak` lane handles
proof-against-real-bucket as a separate concern.

**Missing dependencies with fallback:** Live GCS bucket -> Bypass + secret-
gated CI lane covers it.

---

## Sources

### Primary (HIGH confidence)

- `[VERIFIED: hex.pm via mix hex.info]` `goth 1.4.5` (2024-12-20),
  `finch 0.21.0` (2026-01-22), `gcs_signed_url 0.4.6` (2023-03-27).
- `[VERIFIED: gh api repos/alexandrubagu/gcs_signed_url/contents/lib/gcs_signed_url/client.ex]`
  `GcsSignedUrl.Client.load/1` source — confirms map shape requires string
  keys `"private_key"` and `"client_email"`.
- `[CITED: hexdocs.pm/goth/Goth.html]` `Goth.fetch/1` API,
  `Goth.start_link/1` child_spec, supported credential sources.
- `[CITED: hexdocs.pm/goth/Goth.Token.html]` `%Goth.Token{}` struct fields
  (`token`, `type`, `expires`, `scope`, `sub`, `account`).
- `[CITED: hexdocs.pm/finch/Finch.html]` `Finch.build/5`, `Finch.request/3`,
  `%Finch.Response{}` shape.
- `[CITED: hexdocs.pm/gcs_signed_url/GcsSignedUrl.html]`
  `GcsSignedUrl.generate_v4/4` API and opts.
- `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/objects/insert]`
  Multipart upload endpoint, body structure, metadata JSON shape.
- `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/objects/get]`
  GET object endpoint, `alt=json` vs `alt=media`, metadata response fields.
- `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/objects/delete]`
  DELETE endpoint and 204 success.
- `[CITED: docs.cloud.google.com/storage/docs/json_api/v1/status-codes]`
  Standard error envelope `{ "error": { "code", "message", "errors" } }`.
- Source files (read 2026-05-07): `lib/rindle/storage.ex`,
  `lib/rindle/storage/s3.ex`, `lib/rindle/storage/local.ex`,
  `lib/rindle/storage/capabilities.ex`, `lib/rindle/error.ex`,
  `lib/rindle/config.ex`, `lib/rindle/ops/runtime_checks.ex`,
  `lib/rindle/capability.ex`, `mix.exs`, `.github/workflows/ci.yml`,
  `test/rindle/storage/s3_test.exs`,
  `test/rindle/storage/storage_adapter_test.exs`.
- `[VERIFIED: file read]` Phase 37 CONTEXT.md (full 14-decision lock),
  REQUIREMENTS.md (GCS-01..04 acceptance criteria),
  `.planning/research/v1.6-CANDIDATE-GCS.md` (locked candidate plan),
  PROJECT.md (constraints + key decisions), ROADMAP.md (phase 37 success
  criteria).

### Secondary (MEDIUM confidence)

- Multi-source agreement on `Goth.fetch` returning `{:ok, %Goth.Token{}}`
  (HexDocs + example code in CONTEXT D-09 reference).
- GCS object-name URL encoding rule (`/` -> `%2F`) cross-referenced in
  Google's "Encoding URI path parts" guide and Stack Overflow
  community-verified examples; HexDocs for `:uri_string.quote/1` (OTP 25+).

### Tertiary (LOW confidence — verify at plan time)

- A1 (Goth `ArgumentError` raise behavior) — verify with isolated unit test.
- A2 (object name URL encoding requirement) — verify with live-bucket Bypass
  fixture using `"a/b/c.jpg"` style key.
- A4 (`:finch` not in tree) — `mix deps.tree` output 2026-05-07 confirms
  finch absent; CONTEXT D-07 contradiction noted.

---

## Metadata

**Confidence breakdown:**

- **Standard stack:** HIGH — every version verified against hex.pm 2026-05-07; library API surfaces verified against HexDocs and source code.
- **Architecture:** HIGH — patterns mirror locked v1.6 streaming adapter discipline (`Mux.Video.Assets` `Code.ensure_loaded?` guard, named-instance lookup, optional-dep declaration); 3-file split rationale anchored to anticipated Phase 38-41 callbacks.
- **Public API shape:** HIGH — exact mirror of `lib/rindle/storage/s3.ex` callbacks; parity test is the enforcing oracle.
- **Implementation details (Goth/Finch/gcs_signed_url):** HIGH for API surfaces (verified); MEDIUM-HIGH for error edge cases (Goth's `ArgumentError` is `[ASSUMED]` — verify at plan time).
- **mux-soak clone discipline:** HIGH — workflow file read directly; field-by-field deviation table built from line-by-line comparison.
- **Cross-adapter parity:** HIGH — existing test asserted to extend to GCS without restructuring.
- **Doctor checks:** HIGH for structure (mirror `runtime_checks.ex:526-643`); MEDIUM for the bucket-reachable-403-distinction phrasing (per A5, planner may refine).
- **mix.exs declarations:** HIGH for shape; MEDIUM for `:finch` plt_add_apps (per A4 — CONTEXT D-07 has a verifiable inaccuracy; recommend adding defensively).
- **Pitfalls:** HIGH — every pitfall sourced from a real-world failure mode in peer libs (Active Storage, Shrine, Uppy, django-storages) or the Rindle codebase pattern guard.

**Research date:** 2026-05-07

**Valid until:** 2026-06-07 (30 days; library APIs are stable, GCS JSON API
is stable, but newer Finch/Goth releases may land in this window).
