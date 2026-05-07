---
phase: 37-gcs-adapter-foundation
reviewed: 2026-05-07T00:00:00Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - .github/workflows/ci.yml
  - lib/rindle/capability.ex
  - lib/rindle/ops/runtime_checks.ex
  - lib/rindle/storage/gcs.ex
  - lib/rindle/storage/gcs/client.ex
  - lib/rindle/storage/gcs/signer.ex
  - mix.exs
  - test/rindle/ops/runtime_checks_test.exs
  - test/rindle/storage/gcs/client_test.exs
  - test/rindle/storage/gcs/signer_test.exs
  - test/rindle/storage/gcs_test.exs
  - test/rindle/storage/storage_adapter_test.exs
  - test/support/gcs_signing_key_fixture.ex
findings:
  critical: 3
  warning: 7
  info: 4
  total: 14
status: issues_found
---

# Phase 37: Code Review Report

**Reviewed:** 2026-05-07
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 37 ships the GCS storage adapter foundation: a hand-rolled Finch + Jason JSON-API
client (`Rindle.Storage.GCS.Client`), a `gcs_signed_url` wrapper (`Rindle.Storage.GCS.Signer`),
the public adapter (`Rindle.Storage.GCS`) implementing the `Rindle.Storage` behaviour, three
new doctor checks (`doctor.gcs_goth_running`, `doctor.gcs_bucket_reachable`,
`doctor.gcs_signing_key`), a CI `gcs-soak` lane, and supporting fixtures.

Three classes of defect are blocking:

1. **`Rindle.Storage.GCS.Client.download/4` mishandles `Finch.stream/5`'s 3-tuple error
   shape.** The case expects `{:error, exception}` but the library returns
   `{:error, Exception.t(), acc}`. Network-error paths therefore raise `CaseClauseError`,
   which the outer `rescue` swallows into a generic exception — the error surface is
   lossy and the destination temp file is **leaked** because the post-error `File.rm/1`
   compensation never runs.
2. **`Rindle.Storage.GCS.url/2` raises `ArgumentError` on missing config**, violating the
   `Rindle.Storage` behaviour contract that requires `{:ok, _} | {:error, term()}`. Any
   adopter that calls `Rindle.url/3` for an asset on a profile that selects GCS but has no
   `signing_key` configured will see a crash propagated to their HTTP layer instead of a
   tagged error.
3. **GCS Client `fetch_token/1` collapses every Goth error to `:goth_unconfigured`**,
   masking real authentication failures (revoked credentials, IAM misconfig, network
   fault). Adopters who wired Goth correctly but have a transient Google OAuth error get
   a misleading "Goth is not configured" message.

The doctor changes, signer dispatch, and Bypass-mocked unit tests are solid. The
warnings below cover smaller correctness, contract-parity, and security-hardening gaps.

## Critical Issues

### CR-01: `download/4` does not handle `Finch.stream/5`'s 3-tuple error return; on stream error the destination file is leaked

**File:** `lib/rindle/storage/gcs/client.ex:111-150`

**Issue:**
`Finch.stream/5` is specced as `{:ok, acc} | {:error, Exception.t(), acc}` (see
`deps/finch/lib/finch.ex:392-393` and the public docstring). When the network fails
mid-stream, Finch returns the 3-tuple `{:error, exception, acc}`. The `case` in
`download/4` never matches this shape:

```elixir
case result do
  {:ok, {:ok, :ok}} -> {:ok, destination_path}
  {:ok, {:ok, :not_found}} -> ...
  {:ok, {:ok, {:gcs_http_error, status}}} -> ...
  {:ok, {:error, exception}} ->        # ← 2-tuple, never matches Finch.stream errors
    _ = File.rm(destination_path)
    {:error, exception}
  {:error, exception} -> {:error, exception}
end
```

A Finch network error therefore raises `CaseClauseError`, which is caught by the outer
`rescue exception -> {:error, exception}` (line 152-154). Two consequences:

1. The error surfaces as a `CaseClauseError` carrying `{:ok, {:error, %Mint.TransportError{...}, :ok}}` rather than the real `Mint.TransportError`. Adopters that pattern-match on transport errors lose the distinction.
2. **The `File.rm/1` compensation never runs**, leaving an empty (or partially-written) destination file on disk. The cleanup branches at lines 137, 141, 145 only fire when `File.open` returned `{:ok, _}` — once `CaseClauseError` is raised, control jumps directly to `rescue` at 152 and `destination_path` is left behind.

This is also untested: `download/4`'s test suite (`test/rindle/storage/gcs/client_test.exs:147-169`) covers 200 + 404 only; neither stream-time `Bypass.down/1` nor a deliberate transport error is asserted.

**Fix:**
Match the actual `Finch.stream/5` shape and centralize cleanup so every error path runs `File.rm/1`:

```elixir
result =
  File.open(destination_path, [:write, :binary], fn file ->
    Finch.stream(req, finch, :ok, fn ... end)
  end)

case result do
  {:ok, {:ok, :ok}} ->
    {:ok, destination_path}

  {:ok, {:ok, :not_found}} ->
    _ = File.rm(destination_path)
    {:error, :not_found}

  {:ok, {:ok, {:gcs_http_error, status}}} ->
    _ = File.rm(destination_path)
    {:error, {:gcs_http_error, %{status: status, body: ""}}}

  # Finch.stream/5 spec: {:error, Exception.t(), acc}
  {:ok, {:error, exception, _acc}} ->
    _ = File.rm(destination_path)
    {:error, exception}

  {:error, exception} ->
    _ = File.rm(destination_path)
    {:error, exception}
end
```

Add a Bypass test that exercises `Bypass.down/1` mid-stream and asserts the destination
file is removed.

---

### CR-02: `Rindle.Storage.GCS.url/2` raises `ArgumentError` on missing config — violates the `Rindle.Storage.url/2` callback contract

**File:** `lib/rindle/storage/gcs.ex:66-71`, `lib/rindle/storage/gcs/signer.ex:84-90`

**Issue:**
`Rindle.Storage` callback contract (`lib/rindle/storage.ex:108-109`):

```elixir
@callback url(key :: String.t(), opts :: keyword()) ::
            {:ok, url_result()} | {:error, term()}
```

`GCS.url/2` skips `ensure_goth_loaded/0` (correct — V4 client mode doesn't need Goth)
but provides no equivalent guard for missing `signing_key`. The call therefore reaches
`Signer.signing_key/1` (line 84-90), which **raises** `ArgumentError`:

```elixir
defp signing_key(opts) do
  Keyword.get(opts, :signing_key) ||
    Application.get_env(:rindle, Rindle.Storage.GCS, [])[:signing_key] ||
    raise ArgumentError, "Rindle.Storage.GCS signing_key is not configured. ..."
end
```

This crashes the caller's process (typically a Plug request) instead of returning
`{:error, :missing_signing_key}` per the behaviour. Compare with the same module's
`store/3`, `download/3`, `delete/2`, `head/2`, which all return `{:error, :missing_bucket}`
or `{:error, :goth_unconfigured}` for missing config.

The same defect exists for `:client_email` (Signer line 51-56) and the unsupported
`:signing_key` shapes (Signer line 73-78). Each adopter misconfiguration is a contract
violation.

**Fix:**
Convert `Signer` raises to `{:error, _}` returns and have `GCS.url/2` propagate them:

```elixir
# lib/rindle/storage/gcs/signer.ex
def url(bucket, key, opts) do
  with {:ok, signing_key} <- fetch_signing_key(opts),
       {:ok, client} <- build_client(signing_key) do
    expires = ttl(opts)
    signed_url = GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: expires)
    {:ok, signed_url}
  end
end

defp fetch_signing_key(opts) do
  case Keyword.get(opts, :signing_key) ||
         Application.get_env(:rindle, Rindle.Storage.GCS, [])[:signing_key] do
    nil -> {:error, :missing_signing_key}
    key -> {:ok, key}
  end
end

defp build_client(%{"private_key" => _, "client_email" => _} = json_map),
  do: {:ok, GcsSignedUrl.Client.load(json_map)}

defp build_client(pem) when is_binary(pem) ... # return {:ok, _} or {:error, _}
defp build_client(_other), do: {:error, :invalid_signing_key}
```

The `signer_test.exs:97-104` `assert_raise ArgumentError` cases should be rewritten to
`assert {:error, _} = Signer.url(...)`.

---

### CR-03: `GCS.Client.fetch_token/1` collapses every Goth error to `:goth_unconfigured`, masking real auth failures

**File:** `lib/rindle/storage/gcs/client.ex:237-254`

**Issue:**

```elixir
defp fetch_token(opts) do
  name = goth_name(opts)
  if Code.ensure_loaded?(Goth) do
    try do
      case Goth.fetch(name) do
        {:ok, token} -> {:ok, %{token: token.token, type: token.type}}
        {:error, _exception} -> {:error, :goth_unconfigured}    # ← collapses everything
      end
    rescue
      ArgumentError -> {:error, :goth_unconfigured}
    catch
      :exit, _reason -> {:error, :goth_unconfigured}
    end
  else
    {:error, :goth_unconfigured}
  end
end
```

The pattern `{:error, _exception} -> {:error, :goth_unconfigured}` is wrong: `Goth.fetch/1`
returns `{:error, exception}` for runtime auth failures (revoked service account, network
fault, JWT signing error, IAM denial). Conflating them with `:goth_unconfigured` is
misleading — adopters who configured Goth correctly will see "Goth is not configured" and
re-check config that is fine, when the real fault is at Google.

The companion code in `runtime_checks.ex:891-908` (`fetch_gcs_goth_token/1`) gets this
right by preserving struct names: `{:error, exception} when is_struct(exception) ->
{:error, exception.__struct__}`. The Client should match that shape.

This also breaks the documented `head/3` typespec at line 19-23, which advertises
`:goth_unconfigured` as the Goth-related error atom but says nothing about real auth
failures being indistinguishable.

**Fix:**

```elixir
case Goth.fetch(name) do
  {:ok, token} ->
    {:ok, %{token: token.token, type: token.type}}

  {:error, exception} when is_struct(exception) ->
    {:error, {:goth_fetch_failed, exception.__struct__}}

  {:error, reason} ->
    {:error, {:goth_fetch_failed, reason}}
end
```

Update `head/3`/`store/4`/`download/4`/`delete/3` typespecs to advertise
`{:goth_fetch_failed, term()}`. Update tests to assert the new tuple where Goth itself
fails (not just where the supervisor name is unstarted).

## Warnings

### WR-01: `gcs_test.exs` reads `GOOGLE_APPLICATION_CREDENTIALS_JSON` at compile time — env vars set after compile silently skip the test

**File:** `test/rindle/storage/gcs_test.exs:6-10`

**Issue:**

```elixir
@gcs_credentials System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")
@gcs_bucket System.get_env("RINDLE_GCS_BUCKET")
@gcs_skip_reason (if Enum.any?([@gcs_credentials, @gcs_bucket], &is_nil/1) do ... end)
```

Module attributes are evaluated at **compile** time, not at test run time. Two failure
modes:

1. **`_build` cache hit:** GitHub Actions' `_build` cache is restored on every run; if a
   previous run compiled this test module without env vars set, the cached BEAM still
   has `@gcs_skip_reason` baked to the skip string. The new run will skip silently even
   though credentials are present. This silently disables the gcs-soak proof for
   the live-bucket lane — the very check the soak job was added to enforce.
2. **Local dev:** `mix compile && export GOOGLE_APPLICATION_CREDENTIALS_JSON=... && mix test`
   skips. Adopters / contributors can only run the test if env vars are exported
   *before* the first compile.

Compare with `streaming_credentials` checks in `runtime_checks.ex:599-606`, which read
env at runtime via `Map.get(env, ...)`.

**Fix:**
Read env at test runtime, not module-attribute time:

```elixir
describe "live bucket round-trip ..." do
  @tag :gcs
  setup do
    creds = System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")
    bucket = System.get_env("RINDLE_GCS_BUCKET")

    if is_nil(creds) or is_nil(bucket) do
      :ok = ExUnit.configure(exclude: [...])  # or use {:skip, "..."}
      {:skip, "Skipping GCS adapter test because ... env var is missing"}
    else
      {:ok, creds: creds, bucket: bucket}
    end
  end
end
```

Or use `ExUnit.Case`'s test-level `skip:` with a `setup_all` callback that reads env at
runtime.

---

### WR-02: GCS Client `download/4` writes to disk before authorizing the HTTP response

**File:** `lib/rindle/storage/gcs/client.ex:104-130`

**Issue:**
`File.open(destination_path, [:write, :binary], ...)` opens (and **truncates**) the
destination file before the streaming callback receives the HTTP `:status` event. If the
status is 404 or `:gcs_http_error`, the file at `destination_path` has already been
truncated to zero bytes. The `File.rm/1` cleanup at lines 137 and 141 removes the empty
file, but if the cleanup fails (permissions, race with another writer) the caller sees
the operation "completed" with a zero-byte file at the destination they passed in — even
though the operation returned `{:error, _}`.

The window also creates an information-leak: an attacker who can read the temp directory
can observe that a download was attempted (zero-byte file appears, then disappears), and
on permission error the file persists.

The `:write` mode on `File.open/3` should be `:exclusive` (fail if exists) to avoid
clobbering an unrelated existing file at the destination — a defense-in-depth that
matches `Finch.stream/5`'s example in `deps/finch/lib/finch.ex:374-375`
(`File.open!(path, [:write, :exclusive])`).

**Fix:**
Buffer the response in a temp file and atomically `rename/2` only on the 2xx success
path. Or write to `<destination_path>.tmp`, rename on success, delete on error:

```elixir
tmp_path = destination_path <> ".part"

result =
  File.open(tmp_path, [:write, :binary, :exclusive], fn file ->
    Finch.stream(req, finch, :ok, ...)
  end)

case result do
  {:ok, {:ok, :ok}} ->
    case File.rename(tmp_path, destination_path) do
      :ok -> {:ok, destination_path}
      {:error, reason} -> _ = File.rm(tmp_path); {:error, reason}
    end
  ...
end
```

---

### WR-03: GCS Client `head/3` calls `Jason.decode!/1` — a malformed 200 body crashes the request handler

**File:** `lib/rindle/storage/gcs/client.ex:31-32, 86`

**Issue:**

```elixir
{:ok, %Finch.Response{status: 200, body: body}} ->
  json = Jason.decode!(body)            # ← raises Jason.DecodeError on malformed JSON
  {:ok, %{size: parse_size(json["size"]), content_type: json["contentType"]}}
```

The same pattern in `store/4` line 86: `{:ok, %{... response: Jason.decode!(body)}}`.

If GCS returns a 200 with a truncated body, an HTML proxy error page, or any non-JSON
content (e.g., a misconfigured load balancer in front of `storage.googleapis.com`), the
adapter raises `Jason.DecodeError` instead of returning `{:error, :malformed_response}`.
The exception is not rescued in either function (the `rescue` in `download/4` line 152
does NOT cover `head/3` or `store/4`).

This is also a security finding-adjacent issue: the `Jason.DecodeError` struct's
`:data` field carries the offending bytes, which could leak into a Plug error page when
the unhandled exception bubbles up.

**Fix:**
Use `Jason.decode/1` (returns `{:ok, _} | {:error, _}`):

```elixir
{:ok, %Finch.Response{status: 200, body: body}} ->
  case Jason.decode(body) do
    {:ok, json} ->
      {:ok, %{size: parse_size(json["size"]), content_type: json["contentType"]}}
    {:error, _} ->
      {:error, {:gcs_http_error, %{status: 200, body: "<malformed JSON>"}}}
  end
```

Same treatment for `store/4` line 86.

---

### WR-04: `Signer.url/3` does not handle `gcs_signed_url` library errors — wraps a possibly-error return as `{:ok, _}`

**File:** `lib/rindle/storage/gcs/signer.ex:20-30`

**Issue:**
The moduledoc states "Client mode returns a BARE String.t() (RESEARCH Q3)." and the code
unconditionally wraps:

```elixir
signed_url = GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: expires)
{:ok, signed_url}
```

If a future `gcs_signed_url` version changes its return shape (e.g., to `{:ok, url} |
{:error, _}`), or if `generate_v4/4` raises (for malformed keys, clock skew, expires < 0,
expires > 7 days — V4 hard limit), the wrapper either:
- Returns `{:ok, {:ok, url}}` (broken contract — caller pattern-matches `{:ok, url}` and
  gets a tuple), or
- Crashes the caller (CR-02 same root cause).

The dep is pinned to `~> 0.4.6` which protects against minor version drift, but a 0.4.7
patch could still tweak the surface.

**Fix:**
Defensively handle both shapes plus exception-rescue:

```elixir
def url(bucket, key, opts) do
  with {:ok, client} <- build_client(signing_key(opts)) do
    expires = ttl(opts)

    case GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: expires) do
      url when is_binary(url) -> {:ok, url}
      {:ok, url} when is_binary(url) -> {:ok, url}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_signer_return, other}}
    end
  end
rescue
  exception -> {:error, exception}
end
```

---

### WR-05: GCS Client `head/3` and `delete/3` do not cap response body sizes — large GCS error bodies are read into memory and echoed in `:gcs_http_error`

**File:** `lib/rindle/storage/gcs/client.ex:37-38, 173-174`

**Issue:**

```elixir
{:ok, %Finch.Response{status: status, body: body}} ->
  {:error, {:gcs_http_error, %{status: status, body: body}}}
```

`Finch.request/2` buffers the entire response body in memory. A misconfigured GCS-shaped
endpoint (the `:base_url` opt is a public seam — any Bypass test or future adapter hook
can redirect it) could return an arbitrarily large body. The full body is then placed
into the `{:gcs_http_error, %{body: body}}` error tuple and propagated up the call stack,
likely into Logger output and/or the `Rindle.Error` context.

This is also a leak vector: an attacker who controls the upstream response (via a
compromised `:base_url` or DNS hijack) can flood the adopter's logs with gigabytes of
attacker-controlled bytes.

**Fix:**
Truncate the body before placing it in the error tuple:

```elixir
defp truncate_body(body, max \\ 1024) when is_binary(body) do
  if byte_size(body) > max do
    binary_part(body, 0, max) <> "...<truncated>"
  else
    body
  end
end

# At each error site:
{:error, {:gcs_http_error, %{status: status, body: truncate_body(body)}}}
```

Apply to `head/3`, `store/4`, `delete/3`. Same treatment in
`runtime_checks.ex:do_probe/4` if the response body is ever included in the error
(currently it is not — that path is fine).

---

### WR-06: `runtime_checks.ex:probe_gcs_bucket/4` and `do_probe/4` are public functions with `@doc false` — exposed in the dialyzer surface despite the comment

**File:** `lib/rindle/ops/runtime_checks.ex:996-1039`

**Issue:**
The module declares `@moduledoc false` (line 2), but `probe_gcs_bucket/4` and
`do_probe/4` are `def` (not `defp`) with `@doc false` annotations. The comment block at
lines 992-995 explains: "Public (def) so Bypass-mocked unit tests can exercise it
directly. `@doc false` marks it as not part of the documented public API."

This is a fragile pattern:

1. `@doc false` only hides the function from `mix docs` output. Dialyzer, `function_exported?/3`, and `:erlang.exports/1` all still see them. Rindle.Ops.RuntimeChecks is `@moduledoc false`, but a future refactor that removes the moduledoc-false (e.g., extracting GCS doctor into its own module) would re-expose these as public API.
2. Tests at `test/rindle/ops/runtime_checks_test.exs:558-611` directly call `RuntimeChecks.do_probe/4`, coupling the test suite to internal HTTP plumbing. Any refactor of `do_probe/4`'s signature (e.g., adding telemetry context) breaks these tests for a non-behavioral reason.

The cleaner pattern (as suggested by Mox/Bypass best practices) is to inject the HTTP
client as an option:

**Fix:**
Either keep `def` but add a runtime check that the function is only called from tests:

```elixir
def do_probe(bucket, finch_name, goth_name, opts \\ []) do
  if Mix.env() != :test do
    raise "do_probe/4 is a test-only seam; do not call from production code"
  end
  ...
end
```

Or refactor: pass an `:http_client` opt to `check_gcs_bucket_reachable/2` (default to a
private `do_probe`), and have tests provide a mock client. This decouples tests from
Bypass-specific URL patching.

If the current shape is intentional (it appears to be — a deliberate decision per
"BLOCKER 2 — D-13 LOCK"), at minimum tighten the dialyzer warning so a future change
doesn't accidentally widen the public surface.

---

### WR-07: GCS `do_probe/4` HTTP probe does not pass timeout — a slow `storage.googleapis.com` blocks `mix rindle.doctor` indefinitely

**File:** `lib/rindle/ops/runtime_checks.ex:1021-1039`

**Issue:**

```elixir
def do_probe(bucket, finch_name, goth_name, opts \\ []) do
  base_url = Keyword.get(opts, :base_url, "https://storage.googleapis.com")
  ...
  with {:ok, token} <- probe_token(goth_name, opts),
       req = Finch.build(:get, url, [{"Authorization", "Bearer " <> token}]),
       {:ok, %Finch.Response{status: status}} <- Finch.request(req, finch_name) do
```

`Finch.request/3` defaults to 15s receive timeout AND 5s pool timeout, but the streaming
smoke ping (`run_smoke_ping_with_timeout/0` lines 757-835) uses a 5s wall-clock ceiling
via `Task.yield`/`Task.shutdown` for exactly this reason — the comment at line 753-756
says "Hard 5s wall-clock ceiling via Task.yield + Task.shutdown(:brutal_kill)
(RESEARCH 'Don't hand-roll' — defer to OTP)."

The GCS probe inherits no such ceiling. If `storage.googleapis.com` is slow or
unreachable, `mix rindle.doctor` hangs for the Finch default (~15-30s combined). That
violates the same UX promise the streaming check encodes. A doctor command that hangs
on a network probe is worse than a doctor command that emits an error.

**Fix:**
Pass an explicit `receive_timeout: 5000` to `Finch.request/3`, OR wrap the probe in the
same `Task.yield/Task.shutdown` envelope used at line 758-778:

```elixir
{:ok, %Finch.Response{status: status}} <-
  Finch.request(req, finch_name, receive_timeout: 5_000, pool_timeout: 1_000) do
```

Mirror the comment: "Hard 5s wall-clock ceiling via Finch's `:receive_timeout` —
RESEARCH 'Don't hand-roll'."

---

### WR-08: `inject_credentials/1` and Signer `signing_key/1` race on `:signing_key` — opt vs. app env precedence is asymmetric

**File:** `lib/rindle/storage/gcs.ex:137-145`, `lib/rindle/storage/gcs/signer.ex:84-90`

**Issue:**
The adapter uses `Keyword.put_new_lazy/3` to thread app env into opts:

```elixir
defp inject_credentials(opts) do
  app_env = Application.get_env(:rindle, __MODULE__, [])
  opts
  |> Keyword.put_new_lazy(:finch, fn -> app_env[:finch] end)
  |> Keyword.put_new_lazy(:goth, fn -> app_env[:goth] end)
  |> Keyword.put_new_lazy(:signing_key, fn -> app_env[:signing_key] end)
  |> Keyword.put_new_lazy(:base_url, fn -> app_env[:base_url] end)
end
```

This means: per-call opts win, fall back to app env. **But** `Signer.signing_key/1` then
re-reads app env independently:

```elixir
defp signing_key(opts) do
  Keyword.get(opts, :signing_key) ||
    Application.get_env(:rindle, Rindle.Storage.GCS, [])[:signing_key] ||
    raise ArgumentError, ...
end
```

If a caller passes `signing_key: nil` explicitly (e.g., from a config-driven path that
intentionally clears the value), `inject_credentials` does nothing (the key is already
present, just nil), and `Signer.signing_key` falls through to app env — opposite of what
"explicit nil = unset" usually means. A test that passes `[signing_key: nil]` will
unexpectedly succeed if app env has a key configured.

**Fix:**
Either:
1. Use `Keyword.put_new/3` semantics consistently (the current `put_new_lazy` is fine — the issue is the redundant app-env read in Signer). Remove the app-env fallback in `Signer.signing_key/1` and rely on `inject_credentials` having already filled it in. Single source of truth.
2. Or normalize: `signing_key(opts)` should reject explicit nil with `{:error, :missing_signing_key}`.

Same pattern affects `:goth` (`gcs/client.ex:256-261`) and `:finch` (`client.ex:205-209`).

## Info

### IN-01: `runtime_checks.ex` `verify_gcs_signing_key/1` `String.starts_with?` PEM detection is fragile

**File:** `lib/rindle/ops/runtime_checks.ex:1109-1117`

**Issue:**
The branch `String.starts_with?(path, "-----BEGIN ")` rejects raw PEM strings. But adopters
who have a CR/LF-prefixed PEM (e.g., copy-pasted from a Windows clipboard, or with a
leading BOM) will fail this check and fall through to `File.regular?(path)` — which is
false — and emit a misleading "path does not exist" error.

**Fix:**
Trim leading whitespace before the check:

```elixir
trimmed = String.trim_leading(path)
cond do
  String.starts_with?(trimmed, "-----BEGIN ") -> ...
  ...
end
```

---

### IN-02: `Capability.signed_playback_configured?/0` reads only `:signing_key_id` and `:signing_private_key` — does not validate the key parses

**File:** `lib/rindle/capability.ex:83-88`

**Issue:**
The function returns `true` if the two keys are binaries, regardless of whether the
private key is valid PEM. The doctor check (`runtime_checks.ex:608-676`) does parse the
PEM, but `Rindle.Capability.report/0` is documented as a public seam for ops/doctor
consumers and is asymmetric with the doctor row.

This is a presentation-only issue: a downstream consumer that uses `report().streaming.signed_playback_configured?`
without also running the full doctor will see "configured" for a malformed key. Document
the limitation or rename to `signed_playback_present?`.

**Fix (doc-only):**

```elixir
@doc """
Returns `true` when both `:signing_key_id` and `:signing_private_key` are
**present and binary**. Does NOT validate that the private key parses as a
JOSE.JWK — for the parse check, run `mix rindle.doctor`'s
`doctor.streaming_signing_key` row.
"""
```

---

### IN-03: `gcs_signing_key_fixture.ex` includes ~20 lines of commented-out fallback code

**File:** `test/support/gcs_signing_key_fixture.ex:62-84`

**Issue:**
Lines 62-84 are a large commented-out `defp generate_pem_pkcs8` + helpers, marked
"[FALLBACK] PKCS#8 wrap. Only swap `generate_pem/0` to call this version if
`GcsSignedUrl.Client.load/1` raises `MatchError` on the PKCS#1 PEM produced by the
primary path."

If the primary path works (and the test suite is green), this dead code adds maintenance
burden — future refactors must read and consider it. If it doesn't work, the comment
above is misleading.

**Fix:**
Remove the commented block. If a future `MatchError` is observed, recover from git
history. The comment-as-documentation pattern can be retained as a one-liner comment
referencing the commit SHA.

---

### IN-04: Mix.exs `dialyzer.plt_add_apps` includes `gcs_signed_url` but the dep is optional — non-GCS adopters' PLT builds emit warnings

**File:** `mix.exs:22`

**Issue:**

```elixir
plt_add_apps: [:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url],
```

All six optional deps are added to the PLT. For an adopter that does NOT have
`:gcs_signed_url` in their compiled deps (because they're not using the GCS adapter),
`mix dialyzer --plt` will emit a warning about the unknown app. The warning is not a
build failure but adds noise.

The current Rindle CI lane DOES install all optional deps, so this is invisible there.
But when published as a hex package, downstream PLT builds in adopter projects may
complain.

**Fix:**
Filter the list at PLT-build time:

```elixir
plt_add_apps: dialyzer_optional_apps(),

defp dialyzer_optional_apps do
  base = [:mix, :ex_unit]
  optional = [:mux, :jose, :goth, :finch, :gcs_signed_url]
  base ++ Enum.filter(optional, &Code.ensure_loaded?/1)
end
```

---

_Reviewed: 2026-05-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
