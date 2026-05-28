# Getting Started with Rindle

Rindle is a Phoenix/Ecto-native media lifecycle library. It manages the work
that happens after upload: durable upload sessions, verification, asset state,
variants, signed delivery, and day-2 cleanup.

The first-tier adopter concepts are `Rindle` and `Rindle.Profile`: define a
profile once, then stay on the facade for the common upload, attach, and
delivery path.

This is the canonical deep adopter guide for the same first-run path shown in
[`README.md`](../README.md). The lifecycle calls below are the same public path
the repo proves in `test/adopter/canonical_app/lifecycle_test.exs` and the
Phase 29 package-consumer proof matrix. That matrix exercises a generated
Phoenix app from installed artifacts in two lanes: image-only and AV-enabled.
The built-artifact proof runs before publish, and the published-artifact proof
reuses the same generated-app posture against the released Hex package.
If you are upgrading an existing adopter from the pre-v1.4 image-only shape,
stop here and use the dedicated runbook in [`upgrading.md`](upgrading.md).

## 1. Add Dependencies

Add Rindle to your deps:

```elixir
def deps do
  [
    {:rindle, "~> 0.1"}
  ]
end
```

If you use `Rindle.Storage.S3`, also choose an ExAws HTTP client. `:hackney`
is the most-tested path in this repo:

```elixir
def deps do
  [
    {:rindle, "~> 0.1"},
    {:hackney, "~> 1.20"}
  ]
end
```

Run `mix deps.get`.

Phase 29 keeps two outside-in package-consumer truths aligned:

1. image-only adopters can install Rindle into a generated app and complete
   upload, processing, and signed delivery from the installed artifact
2. AV-enabled adopters can install Rindle into a generated app and prove probe,
   transcode, poster generation, local playback-ready output, and signed
   delivery from the installed artifact

Those are maintainer proof lanes, but they intentionally exercise the same
public docs snippets and facade calls adopters use in a real host app.

Before background jobs run, install the host tools your profiles need:

1. **Image variants:** install **libvips** on the host (`libvips-dev` on
   Debian/Ubuntu, `vips` via Homebrew on macOS). Image-only adopters need
   libvips only.
2. **AV variants:** also install `FFmpeg >= 6.0` for the target platform.

The first AV onboarding path is explicit:

1. `mix deps.get`
2. install libvips and `FFmpeg >= 6.0` for the target platform
3. define one `kind: :video` variant plus `poster`
4. run `mix rindle.doctor`
5. then let the stock facade lifecycle process the upload

Use [`../RUNNING.md`](../RUNNING.md) for the per-platform libvips and FFmpeg
install surface: macOS/Homebrew, Ubuntu or Debian/apt, Alpine/apk, Fly.io
Dockerfile, Heroku Aptfile, Render Dockerfile, and GitHub Actions via
`FedericoCarboni/setup-ffmpeg`.

## 2. Configure Adopter-Owned Runtime Boundaries

Rindle persists runtime state through your adopter-owned Repo. Configure that
explicitly:

```elixir
config :rindle, :repo, MyApp.Repo
```

That is the adopter contract for public runtime paths such as
`Rindle.initiate_upload/2`, `Rindle.verify_completion/2`, `Rindle.attach/4`,
`Rindle.detach/3`, `Rindle.upload/3`, and `Rindle.url/3`.

Rindle also requires the default `Oban` path for background work. Adopters own
Oban supervision, queue config, and the default Oban Repo:

```elixir
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [
    rindle_promote: 5,
    rindle_process: 10,
    rindle_purge: 2,
    rindle_maintenance: 1
  ]
```

Then start Oban in your application:

```elixir
children = [
  MyApp.Repo,
  {Oban, Application.fetch_env!(:my_app, Oban)}
]
```

Named-instance or custom `:oban_name` routing is not the v1.1 contract. The
shipped path is the default `Oban` module.

## 3. Run Host-App And Rindle Migrations Explicitly

Your app owns its own migrations, and Rindle ships a second migration path
inside the package. The package-consumer generated-app proof proves the explicit
`Application.app_dir(:rindle, "priv/repo/migrations")` handoff below:

```elixir
Application.ensure_all_started(:rindle)
{:ok, _pid} = MyApp.Repo.start_link()

host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")

unless File.dir?(rindle_path) do
  raise "Rindle migration path missing: #{rindle_path}"
end

{:ok, _, _} =
  Ecto.Migrator.with_repo(MyApp.Repo, fn repo ->
    for path <- [host_path, rindle_path] do
      Ecto.Migrator.run(repo, path, :up, all: true)
    end
  end)
```

Rindle does not add a public `mix rindle.*` install task in Phase 29. The
public install path is this docs snippet; the repo-private helper that automates
it exists only inside the package-consumer smoke harness.

If your app uses binary IDs globally, keep your Repo migration defaults aligned
with your host app conventions before running the shared path.

## 4. Define The Canonical AV Profile

Phase 29 locks the public AV story to the stock `web_720p` plus `poster`
surface. `Rindle.Profile.Presets.Web` is the canonical helper, and its explicit
equivalent looks like this:

```elixir
defmodule MyApp.VideoProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [
      web_720p: [kind: :video, preset: :web_720p],
      poster: [kind: :image, preset: :video_poster_scene]
    ],
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 250_000_000
end
```

If you want the stock preset module directly, this is the same public shape:

```elixir
defmodule MyApp.VideoProfile do
  use Rindle.Profile.Presets.Web,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 250_000_000
end
```

The Profile DSL validates options at compile time so invalid configuration
fails before runtime upload flows begin. Before you enqueue any AV work, verify
the runtime:

```bash
mix rindle.doctor
```

`mix rindle.doctor` should be the last setup step before you touch background
jobs or chase variant failures.

## 5. First-Run Upload Lifecycle

The first-run path is presigned PUT. It is the narrowest direct-upload contract
Rindle proves from the built artifact, the published artifact, and the
source-of-truth adopter test:

```elixir
{:ok, session} =
  Rindle.initiate_upload(MyApp.VideoProfile, filename: "clip.mp4")

{:ok, %{session: signed, presigned: presigned}} =
  Rindle.Upload.Broker.sign_url(session.id)

# your client PUTs the file bytes to presigned.url

{:ok, %{session: completed, asset: asset}} =
  Rindle.verify_completion(session.id)

{:ok, attachment} =
  Rindle.attach(asset.id, current_user, "hero_video")

{:ok, signed_url} =
  Rindle.url(MyApp.VideoProfile, asset.storage_key)
```

The parity gate for this guide and `README.md` asserts the canonical lifecycle
calls above: `Rindle.initiate_upload`, `Rindle.verify_completion`,
`Rindle.attach`, and `Rindle.url`.

`Rindle.Upload.Broker.sign_url/1` stays available for the presign transport
step, but it is reference material rather than the first concept adopters
should learn.

Multipart upload is available, but it belongs in the advanced lane after the
presigned PUT path is working. See
[`storage_capabilities.md`](storage_capabilities.md) for the capability contract
and proof boundaries.

If you prefer a proxied/server-side upload, the same adopter-owned Repo
contract applies:

```elixir
{:ok, asset} =
  Rindle.upload(MyApp.VideoProfile, %{
    path: "/tmp/clip.mp4",
    filename: "clip.mp4",
    byte_size: File.stat!("/tmp/clip.mp4").size
  })
```

The proof matrix keeps this guide disciplined:

- built-artifact proof validates the generated app before publish
- published-artifact proof re-runs the same generated-app posture against a
  released Hex version
- existing-adopter upgrade procedure lives in [`upgrading.md`](upgrading.md)
- maintainer-only release orchestration stays in
  [`release_publish.md`](release_publish.md), not here

For account deletion / owner erasure, keep this guide thin and jump to the
canonical flow in [`user_flows.md`](user_flows.md). That guide is where the
supported `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` story
now lives. For batch (multi-owner) erasure, see the **Batch owner erasure**
subsection in [`user_flows.md`](user_flows.md).

## 6. What Happens After Verification

After `Rindle.verify_completion/1` returns, Rindle enqueues background work in
Oban:

1. An internal promote worker advances the asset through validation,
   analysis, and promotion.
2. Internal variant-processing jobs run for each declared variant.
3. Variants move to `ready` when processing completes.

See [`background_processing.md`](background_processing.md) for queue ownership,
worker details, retry posture, and telemetry.

## 7. Attach To Your Domain Record

Associate a verified asset with one of your own records:

```elixir
{:ok, attachment} = Rindle.attach(asset.id, current_user, "avatar")
```

Detach later with:

```elixir
:ok = Rindle.detach(current_user, "avatar")
```

Detach is async by design: the DB change commits first, then an Oban purge job
removes storage objects after commit.

## 8. Querying Attachments and Variants

Once an attachment exists, the most common adopter operation is rendering
the asset (and its ready variants) from a controller or LiveView template.
Rindle ships two read helpers so you don't write raw Ecto queries inside
Phoenix view code:

```elixir
{avatar, thumbs} =
  case Rindle.attachment_for(current_user, "avatar") do
    %{asset: asset} = attachment ->
      {attachment, Rindle.ready_variants_for(asset)}

    nil ->
      {nil, []}
  end
# avatar is %Rindle.Domain.MediaAttachment{} | nil
# thumbs is [] when no attachment exists yet

avatar_with_variants =
  Rindle.attachment_for(current_user, "avatar", preload: [:asset, :variants])
# The :preload option REPLACES the default [:asset] preload list rather
# than merging — declare every association you want preloaded.
```

`Rindle.attachment_for/2,3` resolves the most recent attachment for an
`(owner, slot)` pair, tie-broken by `inserted_at desc`. The owner can be
any Ecto schema struct your application defines; the `slot` is the same
string you passed to `Rindle.attach/4`.

`Rindle.ready_variants_for/1` accepts either a `%Rindle.Domain.MediaAsset{}`
struct or a binary asset id. Pending, processing, and failed variants are
filtered out — the helper exists precisely to make "render the variants
that are safe to display" a one-liner.

Both helpers go through `Rindle.repo()` so they inherit the same Repo
ownership posture documented earlier in this guide.

## 9. Bang Variants

For happy-path callers that prefer exceptions over `{:error, reason}`
tuples, Rindle ships five bang variants of the lifecycle functions. Each
delegates to its non-bang twin and raises `Rindle.Error` on generic
failures (or, for `upload!/3`, `detach!/3`, `url!/3`, and
`variant_url!/4`, raises `Ecto.InvalidChangesetError` on changeset
failures from the non-bang twin):

```elixir
attachment = Rindle.attach!(asset.id, current_user, "avatar")
# Raises Rindle.Error{action: :attach, reason: :not_found} if asset missing.

:ok = Rindle.detach!(current_user, "avatar")
# Raises Rindle.Error{action: :detach, reason: ...} on storage failure.

asset =
  Rindle.upload!(MyApp.MediaProfile, %{
    path: "/tmp/photo.png",
    filename: "photo.png",
    byte_size: File.stat!("/tmp/photo.png").size
  })
# Raises Rindle.Error{action: :upload, reason: ...} on validation/storage error.

signed = Rindle.url!(MyApp.MediaProfile, asset.storage_key)
# Raises Rindle.Error{action: :url, reason: :delivery_unsupported} if the
# storage adapter does not advertise the :signed_url capability.

thumb_url = Rindle.variant_url!(MyApp.MediaProfile, asset, :thumb)
# Raises Rindle.Error{action: :variant_url, reason: :variant_not_ready}
# if the variant has not finished processing.
```

Use bangs in scripts, tests, Mix tasks, and controller actions where you
want failures to escalate to the supervisor. For user-facing forms where
validation errors must render inline, keep using the non-bang twins
(`Rindle.attach/4`, `Rindle.detach/3`, `Rindle.upload/3`, `Rindle.url/3`,
`Rindle.variant_url/4`) and pattern-match on `{:ok, value}` /
`{:error, reason}`.

`Rindle.Error` is a documented public exception with `:action` (atom) and
`:reason` (term) fields — pattern-match on `:action` to distinguish which
bang raised:

```elixir
try do
  Rindle.url!(MyApp.MediaProfile, key)
rescue
  e in Rindle.Error ->
    Logger.warn("Rindle url! failed: action=#{e.action} reason=#{inspect(e.reason)}")
    nil
end
```

## 10. Streaming with Mux (optional)

For HLS streaming via signed playback URLs, opt a profile into a streaming provider:

```elixir
defmodule MyApp.Streaming do
  use Rindle.Profile.Presets.MuxWeb,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 524_288_000
end
```

End-to-end onboarding — signing keys, webhook plug, cron, local tunnel, secret rotation, and `mix rindle.doctor --streaming` — lives in [`streaming_providers.md`](streaming_providers.md).

## 11. Storage with GCS (optional)

GCS resumable upload is an advanced path after the canonical presigned PUT
first run is already healthy. If your profile uses `Rindle.Storage.GCS`, wire
adopter-owned `MyApp.Goth`, `MyApp.Finch`, bucket CORS, and the signing key,
then run `mix rindle.doctor` and follow [`storage_gcs.md`](storage_gcs.md).

## Next Reads

- [`../README.md`](../README.md): quickstart version of this path
- [`../RUNNING.md`](../RUNNING.md): FFmpeg install/runtime matrix for the
  supported adopter and CI platforms
- [`background_processing.md`](background_processing.md): default Oban ownership
  and worker behavior
- [`storage_capabilities.md`](storage_capabilities.md): presigned PUT vs.
  multipart capability boundaries
- [`secure_delivery.md`](secure_delivery.md): signed delivery contract
- [`operations.md`](operations.md): day-2 maintenance tasks
