# Getting Started with Rindle

Rindle is a Phoenix/Ecto-native media lifecycle library. It manages everything
that happens *after* a file is uploaded: durable session state, validation,
analysis, variant generation, signed delivery, and day-2 operations.

This guide walks you from `mix new` to a working upload → process → deliver
loop. The four-step lifecycle shown below is the **same code path** the
adopter integration test exercises end-to-end against MinIO and PostgreSQL —
drift between this snippet and `test/adopter/canonical_app/lifecycle_test.exs`
is a CI failure (per Phase 5 decision D-16, enforced by the adopter lane's
drift-gate step).

## Installation

Add Rindle to your `mix.exs` deps:

```elixir
def deps do
  [
    {:rindle, "~> 0.1"}
  ]
end
```

Pick an HTTP client for ExAws if you plan to use the S3 storage adapter
(Rindle ships ExAws as a dependency but does not pin an HTTP client):

```elixir
{:hackney, "~> 1.20"}   # most-tested ExAws backend
# OR
{:req, "~> 0.4"}        # if your app already uses Req
# OR
{:finch, "~> 0.18"}     # paired with :ex_aws_finch
```

Run `mix deps.get` and `mix ecto.migrate` to install Rindle's schemas.

> **System dependency:** the default image processor (Image/Vix) needs
> `libvips` installed. On Debian/Ubuntu: `apt install libvips-dev`. On
> macOS with Homebrew: `brew install vips`.

## Configure Runtime Ownership

Rindle persists runtime state through **your** Ecto repo. Configure that
explicitly in your app so `Rindle.attach/4`, `Rindle.detach/3`,
`Rindle.upload/3`, and the direct-upload broker all transact through
`MyApp.Repo` instead of assuming a library-owned runtime repo:

```elixir
# config/config.exs (or runtime.exs)
config :rindle, :repo, MyApp.Repo
```

That matches the Phase 6 adopter proof: the canonical direct-upload lane and
the dedicated proxied-upload proof both override `:rindle, :repo` to an
adopter-owned repo before calling the public API.

## Define a Profile

A `Rindle.Profile` declares how a particular family of media is handled —
which storage adapter to use, what variants to generate, what the upload
constraints are:

```elixir
defmodule MyApp.MediaProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/png", "image/jpeg"],
    max_bytes: 10_485_760
end
```

The Profile DSL validates options at compile time, so an invalid configuration
fails fast before runtime upload flows execute. See [Profiles](profiles.html)
for the full reference.

## The Upload Lifecycle

The canonical flow has four steps. Each step exercises a specific public
function on `Rindle.Upload.Broker` or `Rindle.Delivery`:

```elixir
# 1. Initiate a session — creates a server-side row in the `staged` state.
{:ok, session} =
  Rindle.Upload.Broker.initiate_session(MyApp.MediaProfile, filename: "photo.png")

# 2. Request a presigned PUT URL — client uploads directly to storage.
{:ok, %{session: signed, presigned: %{url: upload_url}}} =
  Rindle.Upload.Broker.sign_url(session.id)

# ── your client (browser / mobile / curl) PUTs the file bytes to upload_url ──

# 3. Verify the upload — promotes the asset, enqueues variant jobs.
{:ok, %{session: completed, asset: asset}} =
  Rindle.Upload.Broker.verify_completion(session.id)

# 4. Deliver — request a signed URL for the original or any variant.
{:ok, signed_url} =
  Rindle.Delivery.url(MyApp.MediaProfile, asset.storage_key)
```

This is the **exact** code path exercised by the adopter integration test in
`test/adopter/canonical_app/lifecycle_test.exs`. The `Broker.initiate_session`,
`Broker.verify_completion`, and `Rindle.Delivery.url` calls above are the three
canonical entry points the adopter lane's drift-gate greps for.

If you prefer a server-side or proxied upload path, the same runtime Repo
contract applies there too:

```elixir
{:ok, asset} =
  Rindle.upload(MyApp.MediaProfile, %{
    path: "/tmp/photo.png",
    filename: "photo.png",
    byte_size: File.stat!("/tmp/photo.png").size
  })
```

That is the flow proved in `test/rindle/upload/lifecycle_integration_test.exs`
under the adopter-repo override added in Plan 06-02.

## What Happens Behind the Scenes

After `verify_completion/2` returns, several things are happening asynchronously
in Oban workers (you do not need to invoke them manually):

1. `Rindle.Workers.PromoteAsset` advances the asset through
   `validating → analyzing → promoting → available` — analyzers extract MIME,
   dimensions, and other metadata from the bytes in storage.
2. `Rindle.Workers.ProcessVariant` is enqueued for each variant declared on
   the profile (the `thumb` in the example above) and runs the configured
   processor (Image/Vix by default) to derive the variant from the original.
3. Variants land in the `ready` state when their processing job completes.

You can observe these transitions via the public telemetry events
(`[:rindle, :asset, :state_change]`, `[:rindle, :variant, :state_change]`)
covered in [Background Processing](background_processing.html).

## Attaching to a Domain Object

Use `Rindle.attach/4` to associate a verified asset with one of your own
records (a `User`, `Post`, `Product`, etc.) on a named slot:

```elixir
{:ok, attachment} = Rindle.attach(asset.id, current_user, "avatar")
```

When you replace or delete the attachment later, use `Rindle.detach/3`. The
detach path is *async-by-design*: the database transaction commits the detach
immediately, and an Oban `PurgeStorage` job is enqueued to remove the storage
objects after commit. This avoids the Active-Storage-style failure mode where
a storage error inside a DB transaction leaves the database in an inconsistent
state.

```elixir
:ok = Rindle.detach(current_user, "avatar")
```

## Next Steps

- [Core Concepts](core_concepts.html) — assets, variants, sessions, and the
  finite-state machines that govern their lifecycles
- [Profiles](profiles.html) — full Profile DSL reference: variants, allowlists,
  delivery options, authorizers
- [Secure Delivery](secure_delivery.html) — private-by-default, signed URL
  TTL, public opt-in, authorizer hook
- [Background Processing](background_processing.html) — Oban workers, retry
  behavior, queue configuration, telemetry surface
- [Operations](operations.html) — Mix tasks for Day-2 maintenance
  (cleanup, regeneration, storage verification, expiry, backfill)
- [Troubleshooting](troubleshooting.html) — common failure modes and recovery
