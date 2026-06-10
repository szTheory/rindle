<p>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/szTheory/rindle/main/brandbook/assets/logo/rindle-logo-dark.svg">
    <img src="https://raw.githubusercontent.com/szTheory/rindle/main/brandbook/assets/logo/rindle-logo.svg" alt="rindle" height="84">
  </picture>
</p>

# Rindle

[![CI](https://github.com/szTheory/rindle/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/szTheory/rindle/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/rindle.svg)](https://hex.pm/packages/rindle)
[![Docs](https://img.shields.io/badge/hexdocs-latest-blue.svg)](https://hexdocs.pm/rindle)

**Media, made durable.**

Phoenix/Ecto-native media lifecycle library. Rindle owns the durable work that
happens after upload: session tracking, verification, asset state, variants,
background processing, signed delivery, and cleanup.

The first-tier adopter concepts are `Rindle` and `Rindle.Profile`: define a
profile once, then use the facade for upload lifecycle, attachments, and
delivery.

This file is the narrow quickstart. [Getting Started](getting_started.html)
is the canonical deep adopter guide for the same first-run path. That path is
validated in CI from generated Phoenix apps (image-only and AV-enabled install
smoke) before each Hex publish. Existing adopters upgrading from the pre-0.1.4
image-only shape should use [Upgrading](upgrading.html) instead of stretching
the greenfield quickstart into an upgrade runbook.

## Install

Add Rindle to your deps:

```elixir
def deps do
  [
    {:rindle, "~> 0.1"}
  ]
end
```

If you use the S3 adapter, also choose an ExAws HTTP client. `:hackney` is the
most-tested path in this repo:

```elixir
def deps do
  [
    {:rindle, "~> 0.1"},
    {:hackney, "~> 1.20"}
  ]
end
```

Run `mix deps.get`.

Each release is exercised from a generated Phoenix app in CI before it ships
to Hex. Adopters follow the same public setup contract described here and in
[Getting Started](getting_started.html).

For AV profiles, install `FFmpeg >= 6.0` before you touch background jobs, then
run `mix rindle.doctor`. The per-platform install/runtime matrix lives in
[Running](running.html).

For image variants, install **libvips** on the host before background image
processing jobs run (`libvips-dev` on Debian/Ubuntu, `vips` via Homebrew on
macOS). See [Running](running.html) for the install matrix.

## Runtime Ownership

Rindle persists through your adopter-owned Repo. Configure that explicitly:

```elixir
config :rindle, :repo, MyApp.Repo
```

Rindle also requires the default `Oban` path for background work. Adopters own
the Oban supervision tree, queue config, and default Oban Repo:

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

## Migrations

Run your host app migrations and the packaged Rindle migrations explicitly:

```elixir
rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")
host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])

{:ok, _, _} =
  Ecto.Migrator.with_repo(MyApp.Repo, fn repo ->
    for path <- [host_path, rindle_path] do
      Ecto.Migrator.run(repo, path, :up, all: true)
    end
  end)
```

Rindle does not ship a public `mix rindle.*` install task for migrations. The
public path is the docs snippet above.

## First Run: AV Quickstart

The locked onboarding path is:

1. `mix deps.get`
2. install `FFmpeg >= 6.0` from [Running](running.html)
3. declare one `kind: :video` variant plus the stock poster
4. run `mix rindle.doctor`
5. follow the normal facade-first upload lifecycle

The canonical deep guide expands the same path in
[Getting Started](getting_started.html). The stock onboarding story is
`Rindle.Profile.Presets.Web`: `web_720p` video output plus `poster` image
output. The equivalent explicit profile looks like this:

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

If you prefer the stock preset module directly, use
`Rindle.Profile.Presets.Web` with the same storage and upload constraints, then
verify the host with:

```bash
mix rindle.doctor
```

Once the runtime is healthy, the first-run path is still direct upload by
presigned PUT. Multipart upload is supported, but it is an advanced capability
and not the default onboarding story.

```elixir
{:ok, session} =
  Rindle.initiate_upload(MyApp.VideoProfile, filename: "clip.mp4")

{:ok, %{session: signed, presigned: presigned}} =
  Rindle.Upload.Broker.sign_url(session.id)

# your client PUTs bytes to presigned.url

{:ok, %{session: completed, asset: asset}} =
  Rindle.verify_completion(session.id)

{:ok, attachment} =
  Rindle.attach(asset.id, current_user, "hero_video")

{:ok, signed_url} =
  Rindle.url(MyApp.VideoProfile, asset.storage_key)
```

That keeps the first-run story on the facade while leaving
`Rindle.Upload.Broker.sign_url/1` as an advanced transport step.

## After First Run: Querying Attachments and Variants

Once an asset is attached, you'll typically render it from a Phoenix
controller or LiveView. Two helpers cover the common reads without writing
raw Ecto queries:

```elixir
# In MyAppWeb.UserController.show/2
def show(conn, _params) do
  user = conn.assigns.current_user

  {avatar, thumbs} =
    case Rindle.attachment_for(user, "avatar") do
      %{asset: asset} = attachment ->
        {attachment, Rindle.ready_variants_for(asset)}

      nil ->
        {nil, []}
    end
  # avatar is %Rindle.Domain.MediaAttachment{} | nil
  # thumbs is [] when no attachment exists

  render(conn, :show, avatar: avatar, thumbs: thumbs)
end
```

`Rindle.attachment_for/2` returns the most recent attachment for an
`(owner, slot)` pair (tie-broken by `inserted_at desc`) with `:asset`
preloaded. Pass `Rindle.attachment_for(user, "avatar", preload: [:asset, :variants])`
to override the preload list (REPLACE semantics, not merge).

`Rindle.ready_variants_for/1` accepts either a `%MediaAsset{}` struct or a
binary asset id and returns variants with `state == "ready"`, ordered by
`:name asc`. Pending or failed variants are filtered out.

### Bang Variants

Five bang variants are available for happy-path code that prefers
exceptions over `{:error, reason}` tuples. Each delegates to its non-bang
twin and raises `Rindle.Error` on generic failures:

```elixir
# Raises Rindle.Error{action: :attach, reason: :not_found} if the asset is missing.
attachment = Rindle.attach!(asset.id, current_user, "avatar")

# Raises Rindle.Error{action: :detach, reason: ...} on storage failure.
:ok = Rindle.detach!(current_user, "avatar")

# Raises Rindle.Error{action: :upload, reason: ...} on validation/storage failure.
asset = Rindle.upload!(MyApp.MediaProfile, %{
  path: "/tmp/photo.png",
  filename: "photo.png",
  byte_size: File.stat!("/tmp/photo.png").size
})

# Raises Rindle.Error{action: :url, reason: :delivery_unsupported} if the
# configured storage adapter does not advertise :signed_url capability.
signed = Rindle.url!(MyApp.MediaProfile, asset.storage_key)

# Raises Rindle.Error{action: :variant_url, reason: :variant_not_ready} if
# the named variant has not finished processing.
thumb_url = Rindle.variant_url!(MyApp.MediaProfile, asset, :thumb)
```

Bangs are intended for happy-path callers (controllers, scripts, tests).
For user-facing flows that must render validation errors, prefer the
non-bang twins (`Rindle.attach/4`, `Rindle.detach/3`, `Rindle.upload/3`,
`Rindle.url/3`, `Rindle.variant_url/4`) which return `{:ok, value}` /
`{:error, reason}` tuples.

## Streaming with Mux (optional)

For HLS streaming via signed playback URLs, opt a profile into a streaming provider:

```elixir
defmodule MyApp.Streaming do
  use Rindle.Profile.Presets.MuxWeb,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 524_288_000
end
```

End-to-end onboarding — signing keys, webhook plug, cron, local tunnel, secret rotation, and `mix rindle.doctor --streaming` — lives in [Streaming Providers](streaming_providers.html).

## Storage with GCS (optional)

GCS resumable upload is a shipped advanced path, not the canonical first-run
story. If you need `Rindle.Storage.GCS`, adopter-owned `MyApp.Goth` and
`MyApp.Finch` supervision, bucket CORS, and resumable session hygiene, validate
the runtime with `mix rindle.doctor` and use
[Storage (GCS)](storage_gcs.html).

## Next Reads

- [User Flows](user_flows.html): map your job to the right guide (start here when evaluating)
- [Upgrading](upgrading.html): existing-adopter upgrade runbook (pre-0.1.4 image-only → current)
- [Getting Started](getting_started.html): deep greenfield guide — Repo, Oban, migrations, profiles
- [Running](running.html): libvips and FFmpeg install matrix (macOS, Linux, Fly, Heroku, Render, CI)
- [Background Processing](background_processing.html): Oban queues and worker behavior
- [Storage Capabilities](storage_capabilities.html): adapter capability boundaries

## Documentation conventions

Every public `@callback` must be preceded by `@doc """..."""`. Use `@doc false` only for internal compatibility shims.

## License

MIT
