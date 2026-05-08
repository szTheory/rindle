# Storage with GCS Resumable Uploads

`Rindle.Storage.GCS` is the shipped advanced path for adopters who need Google
Cloud Storage and resumable browser uploads. Keep the canonical first run on
presigned PUT. Reach for this guide when you need GCS-specific runtime wiring,
larger-file retry tolerance, or GCS-native resumable session semantics.

Rindle owns the durable lifecycle around the upload session. You still own the
browser or client integration, the service-account custody, bucket policy, CORS
surface, Goth/Finch supervision, and the host application's storage profile.

This guide covers:

- when to choose GCS resumable uploads in Rindle
- adopter-owned runtime wiring with `MyApp.Goth` and `MyApp.Finch`
- bucket and profile configuration for `Rindle.Storage.GCS`
- the required `gsutil cors set` posture for browser resumable uploads
- `mix rindle.doctor` expectations and the common failure classes
- secret hygiene for `session_uri`, logging, and at-rest encryption
- operational footguns such as one-week session expiry and region pinning

## 1. Why And When To Use GCS Resumable Uploads

Use GCS resumable uploads when all of these are true:

- your profile stores media in Google Cloud Storage
- your clients upload directly from the browser or mobile app
- you want chunked retries without restarting a large upload from byte zero

Stay on the canonical presigned PUT path when you only need the narrowest
first-run contract. Resumable upload is shipped, but it is intentionally not
the default onboarding lane.

Rindle does not turn GCS resumable upload into a universal adapter guarantee.
`Rindle.Storage.GCS` advertises the resumable capabilities. Other adapters may
honestly advertise them later, or not at all.

## 2. Add The Optional Dependencies

Enable the optional GCS deps in your host application:

```elixir
def deps do
  [
    {:rindle, "~> 0.1"},
    {:goth, "~> 1.4"},
    {:finch, "~> 0.21"}
  ]
end
```

Run:

```bash
mix deps.get
```

## 3. Supervise `MyApp.Goth` And `MyApp.Finch`

Rindle does not start Goth or Finch for you. Adopters own both processes.

Runtime config:

```elixir
# config/runtime.exs
gcs_credentials =
  System.fetch_env!("GOOGLE_APPLICATION_CREDENTIALS_JSON")
  |> Jason.decode!()

config :goth, json: gcs_credentials

config :rindle, Rindle.Storage.GCS,
  bucket: System.fetch_env!("RINDLE_GCS_BUCKET"),
  goth: MyApp.Goth,
  finch: MyApp.Finch,
  signing_key: gcs_credentials,
  signed_url_ttl: 3600,
  region_hint: System.get_env("RINDLE_GCS_REGION", "us-central1")
```

`signing_key` should usually be the decoded service-account JSON map shown
above. If you prefer a raw PEM private key, Rindle also accepts that shape, but
you must configure `client_email:` separately. File-path loading is not part of
the runtime contract; decode JSON at boot and pass the resulting map instead.

Application supervision:

```elixir
children = [
  MyApp.Repo,
  {Oban, Application.fetch_env!(:my_app, Oban)},
  {Finch, name: MyApp.Finch},
  {Goth, name: MyApp.Goth}
]
```

`MyApp.Goth` must be running so Rindle can fetch access tokens for bucket and
object API calls. `MyApp.Finch` must be running so those calls can execute.

## 4. Configure The Bucket And Profile

The adapter-owned config belongs under `config :rindle, Rindle.Storage.GCS`.
Your profile still chooses the storage backend explicitly:

```elixir
defmodule MyApp.VideoProfile do
  use Rindle.Profile.Presets.Web,
    storage: Rindle.Storage.GCS,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 524_288_000
end
```

An explicit profile shape also works:

```elixir
defmodule MyApp.VideoProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.GCS,
    variants: [
      web_720p: [kind: :video, preset: :web_720p],
      poster: [kind: :image, preset: :video_poster_scene]
    ],
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 524_288_000
end
```

Bucket posture:

- create a dedicated bucket for the app or environment
- keep object lifecycle and retention rules adopter-owned
- prefer a bucket region that matches your app or worker region
- keep the service-account key limited to the bucket permissions you actually need

`region_hint` is an operator hint, not a magic router. Region pinning is normal
for GCS. Cross-region traffic is a real latency and cost concern, so keep your
app nodes, background workers, and bucket as close together as your deployment
allows.

## 5. Allow Browser Resumable Upload CORS

Browser resumable uploads need bucket CORS that matches GCS's resumable flow.
At minimum, allow your app origins, `PUT`, `PATCH`, `Content-Range`, and
`x-goog-resumable`.

Create a `cors.json` file:

```json
[
  {
    "origin": ["https://app.example.com", "http://localhost:4000"],
    "method": ["GET", "HEAD", "PUT", "PATCH"],
    "responseHeader": [
      "Content-Type",
      "Content-Range",
      "x-goog-resumable",
      "x-goog-upload-status"
    ],
    "maxAgeSeconds": 3600
  }
]
```

Apply it with `gsutil cors set`:

```bash
gsutil cors set cors.json gs://$RINDLE_GCS_BUCKET
```

That `gsutil cors set` step is required for browser-origin resumable traffic.
If your uploads stall after the session is created, missing CORS is the first
thing to check.

## 6. Resumable Session Lifecycle Notes

Rindle's GCS resumable path depends on the session URI returned by Google.

- `PATCH` advances the upload by byte range.
- `PUT` may appear in surrounding client or object flows, so keep it allowed in
  browser CORS even if your resumable client primarily uses `PATCH`.
- `Content-Range` carries chunk progress.
- `x-goog-resumable` is part of the session creation/request surface.

The most important security rule is simple: `session URI is a bearer credential`.
Anyone holding it can continue that upload until Google expires it or the upload
is finalized.

Google's resumable session URI lifetime is not indefinite. Treat it as expiring
within one week. Build client UX and cleanup posture around that constraint
instead of assuming a durable multi-week resume contract.

## 7. Run `mix rindle.doctor`

After wiring the profile, bucket, Goth, Finch, and signing key, run:

```bash
mix rindle.doctor
```

For a healthy GCS resumable setup, doctor should confirm the GCS runtime seam
instead of surfacing configuration blockers. The important failure classes are:

- `doctor.gcs_goth_running`: `MyApp.Goth` is missing from supervision or named incorrectly
- `doctor.gcs_bucket_reachable`: the configured bucket does not exist, is misspelled, or the service account cannot reach it
- `doctor.gcs_signing_key`: the configured signing key is absent or malformed
- resumable CORS warning: your server config looks healthy, but browser uploads may still fail if bucket CORS omits app origins, `PATCH`, `PUT`, `Content-Range`, or `x-goog-resumable`

Use doctor before debugging lifecycle calls. If doctor is red, fix that first.

## 8. Security: `session_uri`, Logs, And At-Rest Storage

`session_uri` is not debug metadata. It is secret-grade runtime data.

### Log Redaction

As a defense-in-depth measure, add a logger translator that scrubs
`session_uri` before crash or report formatting:

```elixir
Logger.add_translator(fn
  min_level, level, kind, message ->
    case message do
      {report, metadata} when is_list(metadata) ->
        filtered =
          Keyword.update(metadata, :session_uri, nil, fn _value -> "[REDACTED]" end)

        Logger.Translator.translate(min_level, level, kind, {report, filtered})

      other ->
        Logger.Translator.translate(min_level, level, kind, other)
    end
end)
```

If you normalize Logger metadata earlier in your pipeline, an equivalent filter
is fine as long as raw session URIs never leave the BEAM in logs, crash reports,
telemetry attachments, or support dumps.

### At-Rest Protection With `cloak_ecto`

If you persist resumable session metadata in your app tables and want the
`session_uri` encrypted at rest, a `cloak_ecto` field is the straightforward
path:

```elixir
defmodule MyApp.Vault do
  use Cloak.Vault, otp_app: :my_app
end

defmodule MyApp.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: MyApp.Vault
end

schema "media_upload_sessions" do
  field :session_uri, MyApp.Encrypted.Binary
end
```

`cloak_ecto` is optional, but it is a strong fit when your incident model says
database readers should not automatically gain resumable-session custody.

## 9. Cost And Region Posture

Keep the bucket in the same region as the app or nearby workers when possible.
Resumable upload does not remove egress and latency tradeoffs.

- region pinning is normal for GCS
- cross-region verification or processing increases latency
- cross-region traffic can increase storage and network cost
- a multi-region bucket can be valid, but it is an explicit cost tradeoff, not a default win

Treat this as an operator decision you make up front, not something Rindle can
solve after rollout.

## 10. Common Operator Mistakes

- Starting `Rindle.Storage.GCS` in a profile without supervising `MyApp.Goth`
  and `MyApp.Finch`
- Assuming resumable upload is the default onboarding path and skipping the
  canonical presigned PUT first run
- Applying bucket CORS without `PATCH`, `PUT`, `Content-Range`, or
  `x-goog-resumable`
- Printing `session_uri` in logs or support output
- Assuming the resumable session URI remains valid forever instead of expiring
  within one week
- Running the app in one region and the bucket in another without accepting the
  cost and latency posture

## 11. Related Guides

- [`storage_capabilities.md`](storage_capabilities.md) for the adapter-honest capability matrix
- [`troubleshooting.md`](troubleshooting.md) for the broader recovery and diagnostics guide
- [`getting_started.md`](getting_started.md) for the canonical first-run path that stays on presigned PUT
