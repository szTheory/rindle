# Phase 37: GCS Adapter Foundation - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 13 (7 new, 6 modified)
**Analogs found:** 13 / 13 (every file has a concrete in-tree analog)

<file_map>

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/storage/gcs.ex` (NEW) | behaviour adapter (public, hexdoc'd) | request-response | `lib/rindle/storage/s3.ex` | exact (5 callbacks, opts threading, config keying, return shapes) |
| `lib/rindle/storage/gcs/client.ex` (NEW) | hand-rolled HTTP client (`@moduledoc false`) | request-response (HTTP + streaming) | none in-tree (Bypass adopted now); structurally analogous to `lib/rindle/storage/s3.ex` `defp request/2` + `defp handle_head_response/1` | partial (no Finch user yet; Tesla pattern in `lib/rindle/streaming/provider/mux/*` exists but is rejected per locked candidate §3) |
| `lib/rindle/storage/gcs/signer.ex` (NEW) | V4 signing wrapper (`@moduledoc false`) | transform (local-only, no I/O) | `lib/rindle/storage/s3.ex:55-61` (`url/2` opts threading + `Rindle.Config.signed_url_ttl_seconds()` fallback) | role-match (S3 delegates to ExAws.S3.presigned_url; GCS wraps gcs_signed_url) |
| `test/rindle/storage/gcs_test.exs` (NEW) | credential-gated integration test | request-response (live bucket) | `test/rindle/storage/s3_test.exs:1-30, 117` | exact (env-var skip pattern, head-shape assertion, lifecycle round-trip) |
| `test/rindle/storage/gcs/client_test.exs` (NEW) | Bypass-driven unit test | request-response (loopback HTTP) | none in-tree (first Bypass user); pattern designed in RESEARCH §Pattern (Bypass-backed unit test for head/2) | no analog (greenfield Bypass adoption) |
| `test/rindle/storage/gcs/signer_test.exs` (NEW) | V4 signing unit test | transform | none in-tree; structurally analogous to any `Rindle.Storage.S3` URL-shape test | partial (no V4 canonical-string test exists yet) |
| `test/support/gcs_bypass_fixture.ex` (NEW, optional) | shared Bypass fixture module | test infra | none in-tree; recommended deferred per RESEARCH Q8 ("per-test setup; no shared module") | n/a (RESEARCH recommends NOT shipping) |
| `mix.exs` (MOD) | mix tooling: dialyzer + deps + hexdoc | config | `mix.exs:67-69` (mux/jose `optional: true` block); `mix.exs:22` (`plt_add_apps`); `mix.exs:158-163` (hexdoc adapter grouping) | exact |
| `lib/rindle/storage/capabilities.ex` (verify only) | capability registry | static | n/a — confirmation read; `:signed_url` and `:head` already in `@known` at lines 19-27 | n/a |
| `lib/rindle/ops/runtime_checks.ex` (MOD) | doctor health-check extension | request-response (probe) | `lib/rindle/ops/runtime_checks.ex:526-607` (`check_streaming_credentials/2`, `check_streaming_signing_key/2`) | exact (profile-aware short-circuit + `Code.ensure_loaded?` dep guard + ok_result/error_result return shape) |
| `test/rindle/storage/storage_adapter_test.exs` (MOD) | cross-adapter parity test | static | `test/rindle/storage/storage_adapter_test.exs:41-51, 77-83` (existing — needs additive GCS row) | exact (single-line addition pattern) |
| `.github/workflows/ci.yml` (MOD) | CI proof lane | event-driven (CI) | `.github/workflows/ci.yml:566-653` (`mux-soak` job) | exact (structural template; substitute label-gating for secret-gating) |
| `lib/rindle/error.ex` (verify only) | error vocabulary | static | n/a — confirmation read; CONTEXT D-05 says no Error module changes; atoms route through fallthrough at lines 334-336 | n/a |

</file_map>

<patterns>

## Pattern Assignments

### `lib/rindle/storage/gcs.ex` (behaviour adapter, request-response)

**Analog:** `lib/rindle/storage/s3.ex`

**Module header + `@behaviour` declaration** (lines 1-8, S3):

```elixir
defmodule Rindle.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter powered by ExAws.
  """

  @behaviour Rindle.Storage

  alias ExAws.S3
```

GCS mirror: `@moduledoc` describes the Goth/Finch/gcs_signed_url stack and points adopters to `guides/storage_gcs.md`. `alias Rindle.Storage.GCS.{Client, Signer}` replaces the `alias ExAws.S3` line.

**Config keying — `bucket(opts)` helper** (lines 173-178, S3 — mirror EXACTLY):

```elixir
defp bucket(opts) do
  case Keyword.get(opts, :bucket) || Application.get_env(:rindle, __MODULE__, [])[:bucket] do
    nil -> {:error, :missing_bucket}
    bucket -> {:ok, bucket}
  end
end
```

GCS mirror: copy this verbatim into `gcs.ex`. The opts-or-app-env precedence and `:missing_bucket` atom are locked invariants (D-05, D-08). `__MODULE__` resolves to `Rindle.Storage.GCS` automatically.

**`store/3` `with`-pipeline shape** (lines 11-24, S3):

```elixir
@impl true
def store(key, source_path, opts) do
  with {:ok, bucket} <- bucket(opts),
       {:ok, body} <- File.read(source_path),
       {:ok, response} <-
         request(S3.put_object(bucket, key, body, object_opts(opts)), opts) do
    {:ok, %{key: key, bucket: bucket, response: response}}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

GCS mirror: the `with`-pipeline shape is identical, but adds `ensure_goth_loaded()` step and delegates the upload to `Client.upload(bucket, key, source_path, content_type, content_disposition, opts)` (multipart streaming — see `gcs/client.ex` pattern below). Return shape `{:ok, %{key: key, bucket: bucket, response: response}}` is the locked parity contract.

**`head/2` + `handle_head_response/1` pattern** (lines 130-149, S3 — the parity-test target at `test/rindle/storage/s3_test.exs:117`):

```elixir
@impl true
def head(key, opts) do
  with {:ok, bucket} <- bucket(opts) do
    handle_head_response(request(S3.head_object(bucket, key), opts))
  end
end

defp handle_head_response({:ok, %{headers: headers}}) do
  normalized = Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end)

  {:ok,
   %{
     size: parse_size(Map.get(normalized, "content-length")),
     content_type: Map.get(normalized, "content-type")
   }}
end

defp handle_head_response({:error, %{status_code: 404}}), do: {:error, :not_found}
defp handle_head_response({:error, {:http_error, 404, _response}}), do: {:error, :not_found}
defp handle_head_response({:error, reason}), do: {:error, reason}
```

GCS deviation: GCS JSON API has NO HEAD verb — it uses `GET /storage/v1/b/$BUCKET/o/$KEY?alt=json` (default `alt=json`). The handler decodes the JSON body's `"size"` (string per GCS quirk — see `parse_size/1` below) and `"contentType"` fields, NOT HTTP response headers. The `{:error, :not_found}` clause for 404 is the exact parity contract — the parity assertion at `test/rindle/storage/s3_test.exs:117` (`assert {:ok, %{size: 20, content_type: "image/jpeg"}} = S3.head(key, opts)`) is the shape-locking test.

**`parse_size/1` (GCS-specific quirk: JSON `size` is a string)** (lines 154-163, S3 — copy verbatim):

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

GCS mirror: copy verbatim into `gcs/client.ex` (or `gcs.ex`). Catches both the GCS quirk (JSON `"size": "1024000"` is a string per RESEARCH Pitfall 3) AND defensive integer pass-through.

**`url/2` with `expires_in` fallback** (lines 55-61, S3 — D-04 LOCKED MIRROR):

```elixir
@impl true
def url(key, opts) do
  with {:ok, bucket} <- bucket(opts) do
    S3.presigned_url(s3_config(opts), :get, bucket, key,
      expires_in: Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())
    )
  end
end
```

GCS mirror: the `Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())` line copies verbatim. The S3 line returns whatever `S3.presigned_url/5` returns (already `{:ok, url} | {:error, _}` shape from ExAws). GCS deviation: `gcs_signed_url` `Client` mode returns a BARE `String.t()` (NOT `{:ok, _}`) — the wrapper MUST do `{:ok, GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: ttl)}` per RESEARCH Q3.

**`capabilities/0`** (line 152, S3 — exact contract for D-02 / GCS-02):

```elixir
@impl true
def capabilities, do: [:presigned_put, :head, :signed_url, :multipart_upload]
```

GCS mirror: `def capabilities, do: [:signed_url, :head]` — and NO MORE. Phase 39 (resumable atoms) re-writes this list. Phase 37 verifier asserts EXHAUSTIVELY (`==` not `in`) per RESEARCH Pitfall 6.

**Unsupported callbacks (multipart) — Local pattern** (lines 51-69, `lib/rindle/storage/local.ex`):

```elixir
@impl true
def initiate_multipart_upload(_key, _part_size, _opts) do
  {:error, {:upload_unsupported, :multipart_upload}}
end

@impl true
def presigned_upload_part(_key, _upload_id, _part_number, _expires_in, _opts) do
  {:error, {:upload_unsupported, :multipart_upload}}
end
```

GCS mirror: GCS Phase 37 implements the same 5 + multipart shape (the behaviour requires multipart callbacks be exported). Copy these `{:error, {:upload_unsupported, :multipart_upload}}` stubs verbatim into `gcs.ex`. (`presigned_put` likewise — GCS doesn't ship presigned PUT in Phase 37; resumable session is Phase 39's surface.)

**Optional-dep guard `ensure_goth_loaded/0`** (RESEARCH Pattern 1 + D-09):

```elixir
defp ensure_goth_loaded do
  if Code.ensure_loaded?(Goth), do: :ok, else: {:error, :goth_unconfigured}
end
```

Mirrors the in-tree streaming pattern at `runtime_checks.ex:536` (`not Code.ensure_loaded?(Mux.Video.Assets) -> error_result(...)`).

---

### `lib/rindle/storage/gcs/client.ex` (HTTP client, `@moduledoc false`)

**No exact in-tree analog** — Bypass is brand-new in this codebase (`mix.exs:92` declares it; nothing currently uses it). Tesla-coupled patterns in `lib/rindle/streaming/provider/mux/*` are EXPLICITLY REJECTED per locked candidate §3.

**Closest in-tree shape:** `lib/rindle/storage/s3.ex` `defp request/2` + `defp handle_head_response/1` — the request-then-pattern-match-tuple shape.

**`request` wrapper pattern** (lines 180-184, S3):

```elixir
defp request(operation, opts) do
  ExAws.request(operation, Keyword.get(opts, :aws_config, []))
rescue
  exception -> {:error, exception}
end
```

GCS mirror (designed pattern per RESEARCH §Code Examples + Pitfall 1):

```elixir
defp finch_request(req, opts) do
  Finch.request(req, finch_name(opts))
rescue
  exception -> {:error, exception}
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

The `try/rescue` shape mirrors S3's `defp request/2`. The `try/catch :exit` wrapper is GCS-specific (Pitfall 1: `Goth.fetch/1` raises `:exit, :noproc` on unstarted instance — NOT `{:error, _}`).

**`base_url` opt threading (Bypass discoverability)** — RESEARCH Pitfall 5:

```elixir
@default_base_url "https://storage.googleapis.com"

defp base_url(opts) do
  Keyword.get(opts, :base_url) ||
    Application.get_env(:rindle, Rindle.Storage.GCS, [])[:base_url] ||
    @default_base_url
end
```

This mirrors S3's `aws_config` opts threading (`s3.ex:181, 187`: `Keyword.get(opts, :aws_config, [])`). Bypass-backed tests pass `base_url: "http://localhost:#{bypass.port}"`. RESEARCH Open Question #3 says: keep it test-only / undocumented in public `@moduledoc`.

**Finch HEAD-equivalent** (RESEARCH §Code Examples — designed):

```elixir
url = "#{base_url(opts)}/storage/v1/b/#{bucket}/o/#{URI.encode(key, &URI.char_unreserved?/1)}"
{:ok, headers} = authed_headers(opts)
req = Finch.build(:get, url, [{"accept", "application/json"} | headers])

case finch_request(req, opts) do
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

The 200/404/4xx/5xx-fallthrough/network-exception ordering is identical to S3's `handle_head_response/1` (`s3.ex:136-149`); only the JSON-vs-XML/headers extraction differs.

**Finch streamed multipart POST for `store/3`** (RESEARCH §Code Examples — designed):

```elixir
boundary = "rindle_gcs_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
metadata_json = Jason.encode!(%{
  "name" => key,
  "contentType" => content_type,
  "contentDisposition" => content_disposition
})

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

url = "#{base_url(opts)}/upload/storage/v1/b/#{bucket}/o?uploadType=multipart"
{:ok, auth_headers} = authed_headers(opts)
headers = [
  {"content-type", "multipart/related; boundary=#{boundary}"} | auth_headers
]

req = Finch.build(:post, url, headers, {:stream, file_stream})
finch_request(req, opts)
```

GCS-specific deviations from S3:
- S3 uses `File.read/1` (full body in memory) at `s3.ex:17`. GCS uses `Stream.concat([..., File.stream!(source_path, [], 8192), ...])` to keep large files out of memory.
- S3 uses single PUT via `ExAws.S3.put_object`. GCS uses multipart POST `?uploadType=multipart` to set `contentType` AND `contentDisposition` atomically (D-03 lock — RESEARCH Q5).

**Finch streamed GET for `download/3`** (RESEARCH Q4 — designed):

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

S3 uses `ExAws.S3.download_file` (`s3.ex:33-42`) which streams via ExAws's runtime. GCS hand-rolls via `Finch.stream/4` — Pitfall: do NOT use `Finch.request/3` because it buffers the entire body (RESEARCH Open Question #2: 2GB videos exceed memory budget).

---

### `lib/rindle/storage/gcs/signer.ex` (V4 signing wrapper, `@moduledoc false`)

**Analog:** `lib/rindle/storage/s3.ex:55-61` (`url/2` shape) + `lib/rindle/storage/s3.ex:186-188` (`s3_config/1` opts threading).

**Signing-key dispatch (Pitfall 2 — `gcs_signed_url` Client expects PEM-private-key inside JSON map, NOT raw PEM):**

```elixir
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

No in-tree signing-key analog — Mux signing key (lines 24-26 of `runtime_checks.ex`) is single-shape PEM string. GCS's two-constructor surface forces explicit dispatch.

**TTL fallback** (mirror `s3.ex:55-61` — D-04 lock):

```elixir
defp ttl(opts), do: Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())
```

**`generate_v4` invocation (Client mode — RETURNS BARE STRING, NOT `{:ok, _}`)** — RESEARCH Q3 critical pitfall:

```elixir
def url(bucket, key, opts) do
  client = build_client(signing_key(opts))
  url = GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: ttl(opts))
  {:ok, url}
end
```

S3's `S3.presigned_url/5` returns `{:ok, url} | {:error, _}` directly. GCS Client mode does NOT — adapter MUST wrap in `{:ok, _}` for parity with the `Rindle.Storage.url/2` callback contract.

---

### `test/rindle/storage/gcs_test.exs` (credential-gated integration test)

**Analog:** `test/rindle/storage/s3_test.exs:1-30, 86-126`

**Module attribute env-var skip pattern** (lines 8-18, S3 — copy verbatim with GCS env vars):

```elixir
@minio_url System.get_env("RINDLE_MINIO_URL")
@minio_access_key System.get_env("RINDLE_MINIO_ACCESS_KEY")
@minio_secret_key System.get_env("RINDLE_MINIO_SECRET_KEY")
@minio_bucket System.get_env("RINDLE_MINIO_BUCKET")
@minio_region System.get_env("RINDLE_MINIO_REGION") || "us-east-1"
@minio_skip_reason (if Enum.any?(
                         [@minio_url, @minio_access_key, @minio_secret_key, @minio_bucket],
                         &is_nil/1
                       ) do
                      "Skipping MinIO-backed S3 adapter test because one or more RINDLE_MINIO_* environment variables are missing"
                    end)
```

GCS mirror: `@gcs_credentials System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")`; `@gcs_bucket System.get_env("RINDLE_GCS_BUCKET")`; `@gcs_skip_reason (if Enum.any?([@gcs_credentials, @gcs_bucket], &is_nil/1), do: "Skipping GCS adapter test because GOOGLE_APPLICATION_CREDENTIALS_JSON or RINDLE_GCS_BUCKET is missing")`. Tag with `@tag :gcs` per D-11.

**Missing-bucket assertion** (lines 20-27, S3 — copy verbatim shape):

```elixir
test "returns missing_bucket when no bucket is configured" do
  assert {:error, :missing_bucket} = S3.store("assets/a1.jpg", "/tmp/missing", [])
  assert {:error, :missing_bucket} = S3.delete("assets/a1.jpg", [])
  assert {:error, :missing_bucket} = S3.url("assets/a1.jpg", [])
  assert {:error, :missing_bucket} = S3.presigned_put("assets/a1.jpg", 60, [])
  assert {:error, :missing_bucket} = S3.download("assets/a1.jpg", "/tmp/out", [])
  assert {:error, :missing_bucket} = S3.head("assets/a1.jpg", [])
end
```

GCS mirror: same shape; drop `presigned_put` (not in GCS Phase 37 capabilities); add a parallel `goth_unconfigured` test exercising `Code.ensure_loaded?(Goth)` returning `false`.

**Head-shape parity assertion** (line 117, S3 — locked invariant per D-02):

```elixir
assert {:ok, %{size: 20, content_type: "image/jpeg"}} = S3.head(key, opts)
```

GCS mirror: same line — body bytes are exactly 20 chars (e.g., `"gcs-adapter-test-data"` from a fixture), content_type set via `store/3` opts. This is the exact assertion that proves Pitfall 3 (`size` JSON-string parse) is fixed.

**Round-trip lifecycle** (lines 86-126, S3 — adapt the lifecycle, drop multipart):

S3 lifecycle: `presigned_put → head → download → url → delete → not_found`. GCS Phase 37 lifecycle (no presigned_put in capabilities): `store → head (size+content_type parity) → url (signed_url returns 200) → download → delete → head returns :not_found`. The closing `assert {:error, :not_found} = S3.head(key, opts)` (line 125) is the idempotent-delete proof; mirror exactly.

---

### `test/rindle/storage/gcs/client_test.exs` (Bypass-driven unit test)

**No in-tree analog** — Phase 37 is the FIRST Bypass user. Pattern is designed in RESEARCH §Code Examples ("Bypass-backed unit test for `head/2`").

**Per-test setup pattern** (RESEARCH Q8 recommendation — NO shared fixture module):

```elixir
defmodule Rindle.Storage.GCS.ClientTest do
  use ExUnit.Case, async: true

  alias Rindle.Storage.GCS.Client

  setup do
    bypass = Bypass.open()
    on_exit(fn -> Bypass.shutdown(bypass) end)
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
end
```

Critical: ~12-15 tests of the form `(200/404/4xx/5xx) × (head, store, download, delete)` + edge cases (empty body, malformed JSON, network exception). Each test gets its own `setup` block (~3 LOC). Per RESEARCH Q8: do NOT preemptively design a shared module for Phase 37; let Phase 39's resumable callbacks surface real duplication if it exists.

---

### `test/rindle/storage/gcs/signer_test.exs` (V4 signing unit test — local-only)

**No in-tree analog** — designed.

**Pattern (no Bypass, no Finch — pure local string assertions):**

```elixir
defmodule Rindle.Storage.GCS.SignerTest do
  use ExUnit.Case, async: true
  alias Rindle.Storage.GCS.Signer

  @fixture_json %{
    "private_key" => "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
    "client_email" => "test@example.iam.gserviceaccount.com"
  }

  test "url/3 returns ok-tuple wrapping V4 signed URL with X-Goog-Signature query param" do
    opts = [signing_key: @fixture_json, expires_in: 600]
    assert {:ok, url} = Signer.url("my-bucket", "assets/foo.jpg", opts)
    assert String.contains?(url, "X-Goog-Algorithm=GOOG4-RSA-SHA256")
    assert String.contains?(url, "X-Goog-Signature=")
  end

  test "url/3 falls back to Rindle.Config.signed_url_ttl_seconds/0 when :expires_in absent" do
    opts = [signing_key: @fixture_json]
    assert {:ok, _url} = Signer.url("my-bucket", "assets/foo.jpg", opts)
    # additional assertion: ttl extracted matches Application.get_env default of 900
  end

  test "build_client/1 raises ArgumentError on raw PEM string (Pitfall 2)" do
    assert_raise ArgumentError, fn ->
      Signer.url("my-bucket", "k", signing_key: "-----BEGIN PRIVATE KEY-----\n...")
    end
  end
end
```

A test fixture key (real PEM, but throwaway) lives in `test/support/` and is NEVER a real production key. The test asserts the `{:ok, url}` wrapping (Pitfall 3 around Client-mode bare-string return) and the canonical-string contents (X-Goog-* query params).

---

### `mix.exs` (deps + dialyzer + hexdoc grouping)

**Analog:** `mix.exs:67-69` (mux/jose `optional: true` block) + `mix.exs:22` (dialyzer) + `mix.exs:158-163` (hexdoc).

**Optional-dep template** (lines 67-69, current):

```elixir
# Streaming providers (optional — Mux adapter only loads when these are present)
{:mux, "~> 3.2", optional: true},
{:jose, "~> 1.11", optional: true},
```

GCS mirror: append three new lines (D-06) following the same comment/`optional: true` discipline:

```elixir
# GCS adapter (optional — Rindle.Storage.GCS only loads when these are present)
{:goth, "~> 1.4", optional: true},
{:finch, "~> 0.21", optional: true},
{:gcs_signed_url, "~> 0.4.6", optional: true},
```

**Dialyzer `plt_add_apps`** (line 22, current):

```elixir
plt_add_apps: [:mix, :ex_unit, :mux, :jose],
```

GCS edit (D-07 + RESEARCH Q9 OVERRIDE — `:finch` IS NOT in the non-optional tree, MUST be added):

```elixir
plt_add_apps: [:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url],
```

**Critical:** CONTEXT D-07 says "Not `:finch` — already in tree". RESEARCH Q9 disproves this (finch is only present as Tesla's optional, not pulled by any Rindle dep). The PLAN MUST add `:finch` or dialyzer fails CI.

**Hexdoc adapter grouping** (lines 158-163, current):

```elixir
"Storage and Processor Adapters": [
  Rindle.Storage,
  Rindle.Storage.Local,
  Rindle.Storage.S3,
  Rindle.Processor.Image
],
```

GCS edit: insert `Rindle.Storage.GCS` between `Rindle.Storage.S3` and `Rindle.Processor.Image`. Do NOT include `Rindle.Storage.GCS.Client` or `.Signer` — both are `@moduledoc false` (D-01 lock). HexDocs filters `@moduledoc false` automatically; the grouping list is the public adapter surface.

---

### `lib/rindle/ops/runtime_checks.ex` (doctor extension, profile-aware)

**Analog:** `lib/rindle/ops/runtime_checks.ex:526-607` (`check_streaming_credentials/2` + `check_streaming_signing_key/2`).

**`streaming_profiles/1` filter helper** (lines 522-524 — direct mirror target):

```elixir
defp streaming_profiles(profiles) do
  Rindle.Capability.configured_streaming_profiles(profiles)
end
```

GCS mirror — designed pattern (RESEARCH Q6):

```elixir
defp gcs_profiles(profiles) do
  Enum.filter(profiles, fn profile ->
    profile.storage_adapter() == Rindle.Storage.GCS
  end)
end
```

The streaming version delegates to `Rindle.Capability.configured_streaming_profiles/1`; the GCS version filters directly on `profile.storage_adapter()` (defined at `lib/rindle/profile.ex:62`). If a similar `Rindle.Capability.configured_gcs_profiles/1` helper feels warranted, plan judgment.

**Three-branch `cond` template — `check_streaming_credentials/2`** (lines 526-563 — copy structure verbatim):

```elixir
defp check_streaming_credentials(profiles, env) do
  cond do
    streaming_profiles(profiles) == [] ->
      ok_result(
        "doctor.streaming_credentials",
        :streaming,
        "No streaming-enabled profiles discovered.",
        @streaming_credentials_fix
      )

    not Code.ensure_loaded?(Mux.Video.Assets) ->
      error_result(
        "doctor.streaming_credentials",
        :streaming,
        "Streaming-enabled profile detected but :mux dep is not loaded.",
        @streaming_dep_missing_fix
      )

    true ->
      case missing_streaming_credentials(env) do
        [] -> ok_result(...)
        missing -> error_result(...)
      end
  end
end
```

GCS mirror — three new functions (RESEARCH Q6):

| Function | id (string) | component | OK condition | Error condition |
|----------|------------|-----------|--------------|-----------------|
| `check_gcs_goth_running/2` | `"doctor.gcs_goth_running"` | `:gcs` | `Goth.fetch(name)` returns `{:ok, _}` | dep missing / `:noproc` (caught via `try/catch :exit`) / `{:error, _}` |
| `check_gcs_bucket_reachable/2` | `"doctor.gcs_bucket_reachable"` | `:gcs` | `GET /storage/v1/b/$BUCKET` returns 200 OR 403 (both prove bucket exists) | 404 / network error |
| `check_gcs_signing_key/2` | `"doctor.gcs_signing_key"` | `:gcs` | `GcsSignedUrl.Client.load_from_file/1` (or `.load/1`) returns valid client | rescue any exception → error_result |

Each function follows the same three-branch `cond`:
1. `gcs_profiles(profiles) == []` → silent OK (profile-aware short-circuit, prevents image-only S3 adopters seeing noise).
2. `not Code.ensure_loaded?(Goth)` (or `GcsSignedUrl.Client`) → error_result with `@gcs_dep_missing_fix`.
3. Real check.

**Splice location:** insert the three new check function-refs into the `checks` list at lines 67-81, after `check_streaming_smoke_ping`. Existing `Enum.sort_by(& &1.id)` at line 83 keeps doctor output stable. Final ordering becomes: `..., doctor.gcs_bucket_reachable, doctor.gcs_goth_running, doctor.gcs_signing_key, doctor.local_playback, ...`.

**Module-attribute fix-string template** (lines 16-36 — same posture for GCS):

```elixir
@gcs_dep_missing_fix ~s(Add {:goth, "~> 1.4", optional: true}, {:finch, "~> 0.21", optional: true}, and {:gcs_signed_url, "~> 0.4.6", optional: true} to your deps.)

@gcs_goth_fix """
Add {Goth, name: MyApp.Goth, source: {:service_account, creds}} to your supervision tree, then set config :rindle, Rindle.Storage.GCS, goth: MyApp.Goth.
"""

@gcs_bucket_fix """
Verify config :rindle, Rindle.Storage.GCS, bucket: "my-bucket" matches a bucket your service account can access.
"""

@gcs_signing_key_fix """
Verify the signing_key config is either a decoded service-account JSON map or an existing file path.
"""
```

Mirrors the `@streaming_*_fix` block at lines 16-36 — heredoc with one or two short lines, fix-oriented prose (NOT error-restating).

**Defensive `try/rescue` at signing-key parse** (lines 612-643 — exact pattern to follow for GCS):

```elixir
defp verify_signing_key_pem(value) do
  case JOSE.JWK.from_pem(value) do
    %JOSE.JWK{} -> ok_result(...)
    _other -> error_result(...)
  end
rescue
  exception ->
    error_result(
      "doctor.streaming_signing_key",
      :streaming,
      "RINDLE_MUX_SIGNING_PRIVATE_KEY parse raised: " <>
        inspect(exception.__struct__) <> " (malformed PEM).",
      @streaming_signing_key_fix
    )
end
```

GCS mirror for `check_gcs_signing_key/2`: identical rescue clause — emit `inspect(exception.__struct__)` (the error's MODULE NAME, NOT `Exception.message/1`) so PEM body never echoes into doctor output (Phase 36 WR-10 security invariant — extends naturally to GCS service-account JSON).

**Profile-discovery determinism** (line 83 — already in place; no change):

```elixir
|> Enum.sort_by(& &1.id)
```

Already does alphabetical sort on `:id`; new GCS check ids splice in stably without disturbing existing ordering.

---

### `test/rindle/storage/storage_adapter_test.exs` (cross-adapter parity test)

**Analog:** `test/rindle/storage/storage_adapter_test.exs:41-51, 77-83` (the file IS its own analog — additive single-line edits).

**Existing parity test** (lines 41-51 — designate as the diff target):

```elixir
test "both adapters implement the storage behaviour callbacks" do
  Code.ensure_loaded!(Local)
  Code.ensure_loaded!(S3)

  callbacks = Rindle.Storage.behaviour_info(:callbacks)

  for {name, arity} <- callbacks do
    assert function_exported?(Local, name, arity)
    assert function_exported?(S3, name, arity)
  end
end
```

Phase 37 minimum extension (RESEARCH Q10):

```elixir
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

**Truthful-capabilities assertion** (lines 77-83 — additive edit):

```elixir
test "capability lists are truthful for local and s3 adapters" do
  assert [:local, :presigned_put] == Local.capabilities()
  assert [:presigned_put, :head, :signed_url, :multipart_upload] == S3.capabilities()
  # ...
end
```

Phase 37 extension: rename test ("for all adapters") and add `assert [:signed_url, :head] == GCS.capabilities()` (note: same exhaustive `==` discipline per Pitfall 6). The membership-only check (`Enum.all?(GCS.capabilities(), &(&1 in Capabilities.known()))`) follows the existing per-adapter pattern.

---

### `.github/workflows/ci.yml` (gcs-soak job)

**Analog:** `.github/workflows/ci.yml:566-653` (`mux-soak` job).

**Header + secret-gating** (lines 566-570 — substitute label-gating for secret-gating):

```yaml
mux-soak:
  name: Mux Soak (real API)
  runs-on: ubuntu-latest
  needs: quality
  if: contains(github.event.pull_request.labels.*.name, 'streaming')
```

GCS mirror (D-10 + RESEARCH Q7):

```yaml
gcs-soak:
  name: GCS Soak (real bucket)
  runs-on: ubuntu-latest
  needs: quality
  if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}
```

**Critical:** The `if:` controls whether the job runs; the `env:` block (below) makes the secret available to the test process. Both required (RESEARCH Q7).

**Env block** (lines 571-593, mux-soak — adapt: drop Mux + MinIO; keep PG):

```yaml
env:
  MIX_ENV: test
  RINDLE_MUX_USE_REAL_API: "1"
  RINDLE_MUX_PASSTHROUGH_TAG: "rindle_soak"
  RINDLE_MUX_TOKEN_ID: ${{ secrets.RINDLE_MUX_TOKEN_ID }}
  RINDLE_MUX_TOKEN_SECRET: ${{ secrets.RINDLE_MUX_TOKEN_SECRET }}
  ...
  PGUSER: postgres
  PGPASSWORD: postgres
  PGHOST: localhost
  PGPORT: "5432"
  RINDLE_MINIO_URL: http://localhost:9000
  ...
```

GCS mirror — minimal env block (D-10):

```yaml
env:
  MIX_ENV: test
  GOOGLE_APPLICATION_CREDENTIALS_JSON: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON }}
  RINDLE_GCS_BUCKET: ${{ secrets.RINDLE_GCS_BUCKET }}
  PGUSER: postgres
  PGPASSWORD: postgres
  PGHOST: localhost
  PGPORT: "5432"
```

Drop Mux env vars (irrelevant). Drop MinIO env vars (Phase 37 doesn't talk to S3). Keep PG env vars (test_helper.exs runs migrations even on storage-only tests).

**Postgres service block** (lines 595-608 — copy verbatim):

```yaml
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
```

GCS mirror: copy verbatim. Required because `test_helper.exs` runs `Ecto.Adapters.SQL.Sandbox` checkout regardless of whether the test touches the DB.

**Steps block** (lines 610-653, mux-soak — drop MinIO setup, drop layer-3 cleanup):

```yaml
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
  - name: Start MinIO for soak proof
    run: |
      docker run -d --name rindle-minio ...
  ...
  - name: Run real-Mux soak proof
    run: bash scripts/install_smoke.sh mux
  - name: Always-cleanup leaked Mux soak assets (layer 3 belt-and-suspenders)
    if: always()
    run: bash scripts/mux_soak_cleanup.sh
```

GCS mirror — simplified step block:

```yaml
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
  - name: Run GCS integration tests
    run: mix test --only gcs
```

GCS deviations from mux-soak:
- NO MinIO container (not testing S3).
- NO `scripts/install_smoke.sh mux` script (Phase 37 doesn't have a soak script — test runner is plain `mix test --only gcs`).
- NO layer-3 cleanup script — RESEARCH Q7 says each test creates a unique key via `System.unique_integer/1` and cleans up at end of test (mirroring `s3_test.exs:30-82`). Phase 41 (RESUMABLE-14) revisits cleanup discipline if needed.

</patterns>

<analogs>

## Shared Patterns

### Auth/dep loading (Code.ensure_loaded? guard)

**Source:** `lib/rindle/ops/runtime_checks.ex:536` (in-tree) + RESEARCH §Pattern 1
**Apply to:** `lib/rindle/storage/gcs.ex` (every callback entry), `lib/rindle/ops/runtime_checks.ex` (every `check_gcs_*` function)

```elixir
defp ensure_goth_loaded do
  if Code.ensure_loaded?(Goth), do: :ok, else: {:error, :goth_unconfigured}
end
```

Shared across the adapter surface. Calls `Code.ensure_loaded?` once per request — cheap. Same `{:error, atom}` shape as the locked v1.6 streaming-deps pattern.

### Error-tuple shape (locked invariant — D-05)

**Source:** `lib/rindle/storage/s3.ex:173-178` (`bucket(opts)` and `:missing_bucket` atom) + `lib/rindle/error.ex:334-336` (generic fallthrough)
**Apply to:** Every error tuple emitted by `gcs.ex`, `gcs/client.ex`, `gcs/signer.ex`

| Atom | Shape | Where to emit |
|------|-------|---------------|
| `:missing_bucket` | `{:error, :missing_bucket}` | `gcs.ex` `defp bucket(opts)` |
| `:goth_unconfigured` | `{:error, :goth_unconfigured}` | `gcs.ex` `ensure_goth_loaded/0` + `gcs/client.ex` `fetch_token/1` |
| `:storage_object_missing` | `{:error, :storage_object_missing}` | reserved (NOT used in Phase 37 — Phase 41 verify-storage may use) |
| `:not_found` | `{:error, :not_found}` | `gcs/client.ex` head/4xx 404 branches |
| `{:gcs_http_error, %{status, body}}` | tagged-tuple with map | `gcs/client.ex` 4xx/5xx fallback |

These atoms route through `lib/rindle/error.ex:334-336` (`def message(%{action: action, reason: reason}), do: "could not #{action}: #{inspect(reason)}"`). NO Error module changes (D-05 lock). The map-shape `{:gcs_http_error, %{...}}` decomposes cleanly via `inspect/1` for end users.

### Auth header construction (do NOT log Authorization)

**Source:** `lib/rindle/ops/runtime_checks.ex` Phase 36 WR-10 (`inspect(exception.__struct__)` for PEM-redaction discipline)
**Apply to:** `lib/rindle/storage/gcs/client.ex` `authed_headers/1`

```elixir
{:ok, [{"authorization", "#{type} #{token}"}]}
```

OAuth tokens are bearer credentials. The shared invariant (security domain extension): NEVER include the `authorization` header value in `Logger.metadata/1`, `:telemetry.execute/3`, or `inspect/2` output. Phase 37 has no persisted struct (Phase 38's `media_upload_sessions.session_uri` does), so enforcement is code-review-only this phase. The pattern is mirrored from Phase 36's PEM-rescue at `runtime_checks.ex:632-642`.

### Profile-aware short-circuit (silent OK when profile-not-applicable)

**Source:** `lib/rindle/ops/runtime_checks.ex:528-534` (streaming-credentials short-circuit)
**Apply to:** All three new `check_gcs_*` functions

```elixir
streaming_profiles(profiles) == [] ->
  ok_result(
    "doctor.streaming_credentials",
    :streaming,
    "No streaming-enabled profiles discovered.",
    @streaming_credentials_fix
  )
```

GCS mirror: `gcs_profiles(profiles) == [] -> ok_result("doctor.gcs_<check>", :gcs, "No GCS-enabled profiles discovered.", @gcs_<check>_fix)`. Image-only S3 adopters see no new noise (D-13 lock).

### `ok_result` / `error_result` helper invocation (NEVER inline `%{...}` literals)

**Source:** `lib/rindle/ops/runtime_checks.ex:804-810`

```elixir
defp ok_result(id, component, summary, fix) do
  %{id: id, status: :ok, component: component, summary: summary, fix: fix}
end

defp error_result(id, component, summary, fix) do
  %{id: id, status: :error, component: component, summary: summary, fix: fix}
end
```

Apply to: every result emit in `check_gcs_goth_running/2`, `check_gcs_bucket_reachable/2`, `check_gcs_signing_key/2`. Use the helpers — never inline the map literal — so check_result shape stays canonical.

### Validation (no new schema in Phase 37)

**No applicable shared validation pattern.** Phase 37 doesn't take user input through Ecto changesets. Storage keys flow through `Rindle.Security.StorageKey.generate/3` (already locked v1.0); the adapter passes them opaquely to GCS. RESEARCH §Security Domain V5 confirms.

### Testing — credential-gated module attribute

**Source:** `test/rindle/storage/s3_test.exs:8-18` + `test/rindle/storage/storage_adapter_test.exs:7-19`
**Apply to:** `test/rindle/storage/gcs_test.exs`

```elixir
@minio_skip_reason (if Enum.any?([@minio_url, ...], &is_nil/1) do
                      "Skipping ... because one or more RINDLE_MINIO_* environment variables are missing"
                    end)

@tag :minio
@tag skip: @minio_skip_reason
```

GCS mirror: `@gcs_skip_reason` checks `[@gcs_credentials, @gcs_bucket]`; `@tag :gcs` + `@tag skip: @gcs_skip_reason`. Local runs without credentials skip cleanly; `mix test --only gcs` is the integration entry point (D-11).

</analogs>

## No Analog Found

| File | Role | Data Flow | Reason | Mitigation |
|------|------|-----------|--------|-----------|
| `lib/rindle/storage/gcs/client.ex` (Finch HTTP plumbing) | hand-rolled HTTP client | request-response | No existing in-tree Finch user; Tesla-coupled patterns in `lib/rindle/streaming/provider/mux/*` are explicitly REJECTED per locked candidate §3 | Use RESEARCH §Code Examples (Finch HEAD-equivalent, streamed multipart POST, streamed GET via `Finch.stream/4`) directly. Closest in-tree shape is `s3.ex defp request/2`'s `try/rescue` envelope. |
| `test/rindle/storage/gcs/client_test.exs` (Bypass-driven tests) | unit test | request-response | Bypass declared at `mix.exs:92` since v1.5 but no current test uses it; Phase 37 is first adopter | Use RESEARCH §Code Examples (Bypass-backed unit test for `head/2`) directly. Designed pattern; per-test `setup` block (RESEARCH Q8). |
| `test/rindle/storage/gcs/signer_test.exs` (V4 canonical-string tests) | unit test | transform | No V4 signing test exists; ExAws presigning is opaque-to-Rindle | Designed inline (see Pattern Assignments). Use throwaway PEM fixture; assert `X-Goog-Algorithm=GOOG4-RSA-SHA256` + `X-Goog-Signature=` query params. |
| `test/support/gcs_bypass_fixture.ex` (shared Bypass fixture) | test infra | n/a | RESEARCH Q8 explicitly recommends NOT shipping this in Phase 37 | DEFER to Phase 39 if duplication becomes painful. Phase 37 ships per-test setup blocks instead. |

## Metadata

**Analog search scope:**
- `lib/rindle/storage/` (s3.ex, local.ex, capabilities.ex, storage.ex)
- `lib/rindle/ops/runtime_checks.ex` (lines 1-110, 520-810)
- `lib/rindle/error.ex` (lines 320-340, fallthrough)
- `lib/rindle/config.ex` (signed_url_ttl_seconds/0)
- `lib/rindle/capability.ex` (configured_streaming_profiles/1)
- `lib/rindle/profile.ex` (storage_adapter/0)
- `test/rindle/storage/s3_test.exs`, `storage_adapter_test.exs`, `runtime_checks_test.exs`
- `mix.exs` (deps, dialyzer, hexdoc)
- `.github/workflows/ci.yml` (lines 560-655)

**Files scanned:** 14 source files + 3 test files + 2 config/CI files = 19 files

**Pattern extraction date:** 2026-05-07

## PATTERN MAPPING COMPLETE
