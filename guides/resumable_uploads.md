# Resumable Uploads

Rindle ships a tus 1.0 upload edge via `Rindle.Upload.TusPlug`. This guide
covers the adopter-owned wiring: endpoint mount, client configuration,
capability checks, and the constraints you must keep in mind when resuming
uploads against Local or S3-backed storage.

This guide covers:

- When to use tus instead of presigned PUT or GCS-native resumable upload
- Mounting `Rindle.Upload.TusPlug` in Phoenix or plain Plug
- Required endpoint and parser setup
- CORS headers for browser clients
- `tus-js-client` and `@uppy/tus` client settings
- Optional same-user resume authorization
- Doctor checks and capability honesty
- Security checklist and no-silent-downgrade rules

## 1. When To Use Tus

Use tus when the browser must upload directly to your app over a resumable HTTP
protocol and the storage adapter advertises `:tus_upload`.

- For the canonical first-run path, presigned PUT is still the narrowest upload flow.
- For GCS-native resumable sessions, prefer `Rindle.initiate_resumable_session/2`.
- For browser clients that need one upload URL plus `HEAD`/`PATCH` resume, use `Rindle.Upload.TusPlug`.

Tus is capability-gated. Mounting `TusPlug` against an adapter that does not
advertise `:tus_upload` raises at init time. This no-silent-downgrade contract
means there is no silent fallback to another upload strategy.

## 2. Mount `TusPlug`

Mount the plug under your own auth pipeline. Rindle does not add a Phoenix
dependency or a hidden auth layer:

```elixir
# lib/my_app_web/router.ex
forward "/uploads/tus", Rindle.Upload.TusPlug,
  profile: MyApp.VideoProfile,
  secret_key_base:
    Application.compile_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base]
```

The same plug can be mounted in a plain `Plug.Router`:

```elixir
forward "/uploads/tus",
  to: Rindle.Upload.TusPlug,
  init_opts: [profile: MyApp.VideoProfile, secret_key_base: secret]
```

If you want `mix rindle.doctor` to validate that a profile you mount here has
the required storage capability, register it explicitly:

```elixir
config :rindle, :tus_profiles, [MyApp.VideoProfile]
```

Doctor does not inspect Phoenix routes. It only checks configured tus profiles
against adapter capabilities.

## 3. Endpoint And Parser Setup

`TusPlug` expects the raw `application/offset+octet-stream` request body to
reach the plug unchanged. In Phoenix, keep `Plug.Parsers` configured to pass
that content type through:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["application/offset+octet-stream", "*/*"],
  json_decoder: Phoenix.json_library()
```

The signed tus `Location` URL is opaque. Treat it as a bearer credential and
reuse it byte-for-byte. Do not rebuild or append path segments client-side.

## 4. Browser CORS

Expose the headers tus clients need to read:

```elixir
config :cors_plug,
  expose: [
    "Upload-Offset",
    "Location",
    "Upload-Length",
    "Tus-Resumable",
    "Upload-Expires"
  ]
```

If your browser clients send custom auth headers, keep those in your normal
CORS allowlist as well.

## 5. Client Configuration

### `tus-js-client`

```javascript
import * as tus from "tus-js-client"

const upload = new tus.Upload(file, {
  endpoint: "/uploads/tus",
  metadata: {
    filename: file.name,
    filetype: file.type
  },
  retryDelays: [0, 1000, 3000, 5000],
  parallelUploads: 1,
  removeFingerprintOnSuccess: true
})

const previousUploads = await upload.findPreviousUploads()
if (previousUploads.length > 0) {
  upload.resumeFromPreviousUpload(previousUploads[0])
}

upload.start()
```

### `@uppy/tus`

```javascript
uppy.use(Tus, {
  endpoint: "/uploads/tus",
  parallelUploads: 1
})
```

`parallelUploads: 1` is the supported posture for the Rindle tus edge. The
client should `HEAD` for `Upload-Offset` and let the library resume from the
server-reported offset. For modern `@uppy/tus`, resume and fingerprint cleanup
are automatic, so do not add `removeFingerprintOnSuccess`.

## 6. Optional Resume Authorization

By default, possession of a valid signed tus URL is enough to resume the
upload. If you need same-user enforcement, configure a resume authorizer:

```elixir
config :rindle, :tus_resume_authorizer, MyApp.TusAuth
```

```elixir
defmodule MyApp.TusAuth do
  @behaviour Rindle.TusResumeAuthorizer

  @impl true
  def authorize(actor, :resume, %{token_actor: token_actor}) do
    if actor == token_actor, do: :ok, else: :reject
  end
end
```

The hook runs after URL signature verification and session lookup, but before
any body or storage I/O on `HEAD`, `PATCH`, or `DELETE`.

## 7. Security Checklist

- Mount `TusPlug` only behind your own auth pipeline.
- Keep the signed `Location` URL secret; it is a bearer credential.
- Treat the returned `Location` as opaque and reuse it byte-for-byte.
- If you use `tus-js-client`, keep `removeFingerprintOnSuccess: true` so
  completed uploads do not reuse stale fingerprint entries.
- Do not mount tus for profiles whose adapters do not advertise `:tus_upload`.
- For S3-backed tus uploads, keep sticky-session or single-node routing in
  place. Mid-upload tail state is node-local and cross-node resume fails loudly.

## 8. No-Silent-Downgrade Contract

Rindle does not degrade from tus to presigned PUT or multipart automatically.
If the adapter lacks `:tus_upload`, `TusPlug.init/1` raises. If `mix rindle.doctor`
sees a configured tus profile without that capability, it reports the mismatch
explicitly.
