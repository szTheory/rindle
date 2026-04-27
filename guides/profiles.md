# Profiles

A `Rindle.Profile` is a compile-time module that declares how a particular
family of media is handled — which storage adapter to use, what variants
to derive, what upload constraints to enforce, and how delivery should
behave. Profiles are the single source of truth for a media domain in
your application; you typically have one per logical "thing" (avatars,
post images, document uploads, etc.).

## Defining a Profile

The minimal profile declares a storage adapter and at least one variant:

```elixir
defmodule MyApp.AvatarProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]]
end
```

The DSL validates options at compile time via `Rindle.Profile.Validator`,
so an unknown option, a malformed variant spec, or a non-atom storage
module all fail at `mix compile` — not at runtime.

## DSL Options

| Option              | Type                | Required | Default | Notes                                                     |
| ------------------- | ------------------- | :------: | ------- | --------------------------------------------------------- |
| `:storage`          | atom (module)       |   yes    | —       | Storage adapter module — must implement `Rindle.Storage`  |
| `:variants`         | keyword list        |   yes    | —       | Map of variant name → variant spec (see below)            |
| `:allow_mime`       | list of strings     |    no    | `[]`    | Allowlist of MIME types accepted at upload validation     |
| `:allow_extensions` | list of strings     |    no    | `[]`    | Allowlist of filename extensions                          |
| `:max_bytes`        | pos_integer or nil  |    no    | `nil`   | Hard upper bound on upload size                           |
| `:max_pixels`       | pos_integer or nil  |    no    | `nil`   | Hard upper bound on image pixel count (image profiles)    |
| `:delivery`         | keyword list        |    no    | `[]`    | Delivery policy (see [Secure Delivery](secure_delivery.html)) |

## Variant Specs

Each variant is a `{name, opts}` pair. The variant spec controls how the
processor derives the output:

| Option      | Type                                | Required | Default | Notes                                              |
| ----------- | ----------------------------------- | :------: | ------- | -------------------------------------------------- |
| `:mode`     | `:fit`, `:fill`, `:crop`            |   yes    | —       | Resize mode                                        |
| `:width`    | pos_integer or nil                  |    no    | `nil`   | Target width in pixels                             |
| `:height`   | pos_integer or nil                  |    no    | `nil`   | Target height in pixels                            |
| `:format`   | `:jpeg`, `:png`, `:webp`, `:avif`   |    no    | `:jpeg` | Output format                                      |
| `:quality`  | 1–100 or nil                        |    no    | `nil`   | Output quality (0 = no override; processor default) |

Each variant gets its own `MediaVariant` row with its own state — see
[Core Concepts](core_concepts.html) for the variant FSM. Variants are
queryable, regeneratable, and individually addressable.

## A Real-World Profile

Here is the canonical adopter profile from `test/adopter/canonical_app/profile.ex`:

```elixir
defmodule MyApp.MediaProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/png", "image/jpeg"],
    max_bytes: 10_485_760
end
```

The profile module exposes a small public surface that Rindle uses internally:

- `MyApp.MediaProfile.storage_adapter/0` returns `Rindle.Storage.S3`
- `MyApp.MediaProfile.variants/0` returns `[thumb: %{mode: :fit, format: :jpeg, width: 64, height: 64}]`
- `MyApp.MediaProfile.upload_policy/0` returns the validation policy map
- `MyApp.MediaProfile.delivery_policy/0` returns the delivery policy map
- `MyApp.MediaProfile.recipe_digest/1` returns a stable hash of a variant's
  options — when the recipe changes, all existing variants are detected as
  `stale` and `mix rindle.regenerate_variants` will re-enqueue them.

## Multiple Variants

Most profiles declare more than one variant. The order in the keyword list
does not affect processing (variants are processed in parallel), but it does
affect deterministic ordering when iterating:

```elixir
defmodule MyApp.PostImageProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [
      thumb: [mode: :fit, width: 200, height: 200, format: :webp, quality: 80],
      large: [mode: :fit, width: 1200, height: 1200, format: :webp, quality: 85],
      square: [mode: :crop, width: 400, height: 400, format: :webp]
    ],
    allow_mime: ["image/png", "image/jpeg", "image/webp"],
    allow_extensions: [".png", ".jpg", ".jpeg", ".webp"],
    max_bytes: 25_165_824,
    max_pixels: 50_000_000
end
```

Each variant generates a separate `Rindle.Workers.ProcessVariant` Oban job.
Variants are individually retryable and individually queryable for state.

## Storage Adapter Selection

The `storage:` option is per-profile, so you can mix adapters in one app:

```elixir
defmodule MyApp.AvatarProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,                    # avatars on S3
    variants: [thumb: [mode: :fit, width: 64, height: 64]]
end

defmodule MyApp.AdminUploadProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.Local,                 # admin uploads on local disk
    variants: [original: [mode: :fit]]             # no resizing — store as-is
end
```

The S3 adapter advertises `[:presigned_put, :signed_url]` capabilities; the
Local adapter advertises `[:local]`. Profiles using private delivery require
the adapter to support `:signed_url` — Rindle returns `{:error,
{:delivery_unsupported, :signed_url}}` if the adapter cannot sign.

## Adapter Configuration

Adapter-specific configuration (S3 endpoint, bucket name, credentials) lives
in your application config — not on the profile. The profile only references
the adapter module:

```elixir
# config/runtime.exs (adopter-owned, NOT inside the Rindle dependency)
config :rindle, Rindle.Storage.S3,
  bucket: System.fetch_env!("S3_BUCKET")

config :ex_aws, :s3,
  scheme: "https://",
  host: System.fetch_env!("S3_HOST"),
  region: System.fetch_env!("S3_REGION"),
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
```

Per project decision: runtime DB and storage credentials are adopter-owned;
Rindle never reads secrets from a library-level config block.

## Recipe Digests and Stale Detection

Every variant has a `recipe_digest` — a stable hash computed from the variant's
options. Computing the digest canonicalizes option key ordering, so
`[mode: :fit, width: 64]` and `[width: 64, mode: :fit]` hash to the same
value.

When you change a variant spec (say, bumping `quality: 85` to `quality: 90`),
existing variants generated under the old spec are detected as `stale` because
their stored `recipe_digest` no longer matches the profile's current digest.
`mix rindle.regenerate_variants` walks stale rows and re-enqueues them. See
[Operations](operations.html).

## Validation Failure Modes

The Profile DSL fails at compile time for:

- Missing `:storage` or `:variants`
- Storage value that is not an atom (module reference)
- Variant spec missing `:mode`, or with `:mode` outside `[:fit, :fill, :crop]`
- Variant `:format` outside `[:jpeg, :png, :webp, :avif]`
- Variant `:quality` outside `1..100`
- Unknown top-level keys (e.g., a typo'd `varient:` instead of `variants:`)

Compile-time validation is intentional — invalid profiles should never reach
runtime, where they would surface as confusing errors deep inside the upload
or processing path.
