# Rindle

**Media, made durable.**

Phoenix/Ecto-native media lifecycle library. Rindle owns the durable work that
happens after upload: session tracking, verification, asset state, variants,
background processing, signed delivery, and cleanup.

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
alias Rindle.Upload.Broker

{:ok, session} =
  Broker.initiate_session(MyApp.MediaProfile, filename: "photo.png")

{:ok, %{session: signed, presigned: presigned}} =
  Broker.sign_url(session.id)

# your client PUTs bytes to presigned.url

{:ok, %{session: completed, asset: asset}} =
  Broker.verify_completion(session.id)

{:ok, signed_url} =
  Rindle.Delivery.url(MyApp.MediaProfile, asset.storage_key)
```

That is the same public path proven by the built-artifact install smoke and the
canonical adopter lifecycle test.

## Next Reads

- [`guides/getting_started.md`](guides/getting_started.md): canonical deep
  adopter guide for Repo ownership, Oban ownership, migrations, profile setup,
  and the same presigned PUT lifecycle
- [`guides/background_processing.md`](guides/background_processing.md): default
  Oban ownership and queue details
- [`guides/storage_capabilities.md`](guides/storage_capabilities.md): capability
  boundaries, including multipart as an advanced path

## License

MIT
