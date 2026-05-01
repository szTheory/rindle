# Rindle

**Media, made durable.**

Phoenix/Ecto-native media lifecycle library. Rindle owns the durable work that
happens after upload: session tracking, verification, asset state, variants,
background processing, signed delivery, and cleanup.

The first-tier adopter concepts are `Rindle` and `Rindle.Profile`: define a
profile once, then use the facade for upload lifecycle, attachments, and
delivery.

`README.md` is the narrow quickstart. [`guides/getting_started.md`](guides/getting_started.md)
is the canonical deep adopter guide for the same first-run path.

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

Run your host app migrations and the packaged Rindle migrations explicitly. The
consumer smoke lane proves this `Application.app_dir/2` path from a generated
Phoenix app:

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

Rindle does not ship a public `mix rindle.*` install task for this in v1.1.
The public path is the docs snippet above; the repo-private automation lives in
the install smoke harness.

## First Run: Presigned PUT

The first-run path is direct upload by presigned PUT. Multipart upload is
supported, but it is an advanced capability and not the default onboarding
story.

```elixir
defmodule MyApp.MediaProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/png", "image/jpeg"],
    max_bytes: 10_485_760
end

{:ok, session} =
  Rindle.initiate_upload(MyApp.MediaProfile, filename: "photo.png")

{:ok, %{session: signed, presigned: presigned}} =
  Rindle.Upload.Broker.sign_url(session.id)

# your client PUTs bytes to presigned.url

{:ok, %{session: completed, asset: asset}} =
  Rindle.verify_completion(session.id)

{:ok, attachment} =
  Rindle.attach(asset.id, current_user, "avatar")

{:ok, signed_url} =
  Rindle.url(MyApp.MediaProfile, asset.storage_key)
```

That keeps the first-run story on the facade while leaving
`Rindle.Upload.Broker.sign_url/1` as an advanced transport step. The same
public path is proven by the built-artifact install smoke and the canonical
adopter lifecycle test.

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

## Next Reads

- [`guides/getting_started.md`](guides/getting_started.md): canonical deep
  adopter guide for Repo ownership, Oban ownership, migrations, profile setup,
  and the same presigned PUT lifecycle
- [`guides/background_processing.md`](guides/background_processing.md): default
  Oban ownership and queue details
- [`guides/storage_capabilities.md`](guides/storage_capabilities.md): capability
  boundaries, including multipart as an advanced path

## GSD Hygiene

For local GSD cleanup, run `mix gsd.clean`. It removes known transient outputs,
prunes stale worktree metadata, and reports any remaining `.planning/` dirt
without deleting tracked planning artifacts.

Use the GSD workflows for the tracked planning lifecycle:

- `$gsd-complete-milestone` when a milestone is actually done
- `$gsd-cleanup` to archive completed milestone phase directories
- `$gsd-pr-branch` to prepare a review branch without `.planning/` commits

## Documentation conventions

Every public `@callback` must be preceded by `@doc """..."""`. Use `@doc false` only for internal compatibility shims.

## License

MIT
