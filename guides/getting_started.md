# Getting Started with Rindle

Rindle is a Phoenix/Ecto-native media lifecycle library. It manages the work
that happens after upload: durable upload sessions, verification, asset state,
variants, signed delivery, and day-2 cleanup.

This is the canonical deep adopter guide for the same first-run path shown in
[`README.md`](../README.md). The lifecycle calls below are the same public path
the repo proves in `test/adopter/canonical_app/lifecycle_test.exs` and the
built-artifact install smoke from Phase 9.

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

> **System dependency:** the default image processor (Image/Vix) needs
> `libvips` installed. On Debian/Ubuntu: `apt install libvips-dev`. On macOS:
> `brew install vips`.

## 2. Configure Adopter-Owned Runtime Boundaries

Rindle persists runtime state through your app's Repo. Configure that
explicitly:

```elixir
config :rindle, :repo, MyApp.Repo
```

That is the adopter contract for public runtime paths such as `Rindle.attach/4`,
`Rindle.detach/3`, `Rindle.upload/3`, and the direct-upload broker.

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
inside the package. The package-consumer smoke lane proves the explicit
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

Rindle does not add a public `mix rindle.*` install task in Phase 9. The
public install path is this docs snippet; the repo-private helper that automates
it exists only inside the smoke harness.

If your app uses binary IDs globally, keep your Repo migration defaults aligned
with your host app conventions before running the shared path.

## 4. Define A Profile

A `Rindle.Profile` declares storage, variants, and upload constraints for a
family of media:

```elixir
defmodule MyApp.MediaProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/png", "image/jpeg"],
    max_bytes: 10_485_760
end
```

The Profile DSL validates options at compile time so invalid configuration
fails before runtime upload flows begin.

## 5. First-Run Upload Lifecycle

The first-run path is presigned PUT. It is the narrowest direct-upload contract
Rindle proves from the built artifact:

```elixir
alias Rindle.Upload.Broker

{:ok, session} =
  Broker.initiate_session(MyApp.MediaProfile, filename: "photo.png")

{:ok, %{session: signed, presigned: presigned}} =
  Broker.sign_url(session.id)

# your client PUTs the file bytes to presigned.url

{:ok, %{session: completed, asset: asset}} =
  Broker.verify_completion(session.id)

{:ok, signed_url} =
  Rindle.Delivery.url(MyApp.MediaProfile, asset.storage_key)
```

The parity gate for this guide and `README.md` asserts the canonical lifecycle
calls above: `Broker.initiate_session`, `Broker.sign_url`,
`Broker.verify_completion`, and `Rindle.Delivery.url`.

Multipart upload is available, but it belongs in the advanced lane after the
presigned PUT path is working. See
[`storage_capabilities.md`](storage_capabilities.md) for the capability contract
and proof boundaries.

If you prefer a proxied/server-side upload, the same adopter-owned Repo
contract applies:

```elixir
{:ok, asset} =
  Rindle.upload(MyApp.MediaProfile, %{
    path: "/tmp/photo.png",
    filename: "photo.png",
    byte_size: File.stat!("/tmp/photo.png").size
  })
```

## 6. What Happens After Verification

After `Broker.verify_completion/1` returns, Rindle enqueues background work in
Oban:

1. `Rindle.Workers.PromoteAsset` advances the asset through validation,
   analysis, and promotion.
2. `Rindle.Workers.ProcessVariant` runs for each declared variant.
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

## Next Reads

- [`../README.md`](../README.md): quickstart version of this path
- [`background_processing.md`](background_processing.md): default Oban ownership
  and worker behavior
- [`storage_capabilities.md`](storage_capabilities.md): presigned PUT vs.
  multipart capability boundaries
- [`secure_delivery.md`](secure_delivery.md): signed delivery contract
- [`operations.md`](operations.md): day-2 maintenance tasks
