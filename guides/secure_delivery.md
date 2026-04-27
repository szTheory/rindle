# Secure Delivery

Rindle is **private-by-default**. A profile that does not opt into public
delivery serves every original and every variant via signed, time-limited
URLs. This matches the security posture of the reference implementations
Rindle draws from (Active Storage, Shrine, imgproxy) and avoids the most
common media-handling mistake: accidentally exposing storage objects via
unsigned, infinite-lifetime URLs.

This guide covers:

- The default private delivery posture
- How to configure signed URL TTL per profile
- How to opt a profile into public delivery (and when not to)
- How to attach an authorizer for fine-grained per-request checks
- The storage-adapter capability contract for signed URLs
- Threat-model notes on signed URLs

## Default: Private with Signed URLs

A profile that declares no `delivery:` option is private:

```elixir
defmodule MyApp.MediaProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]]
end
```

Calling `Rindle.Delivery.url/3` returns a signed URL that expires after the
profile's configured TTL (or the application-wide default if the profile
does not override it):

```elixir
{:ok, signed_url} = Rindle.Delivery.url(MyApp.MediaProfile, asset.storage_key)
# => {:ok, "https://my-bucket.s3.amazonaws.com/uploads/abc.png?X-Amz-Signature=..."}
```

Rindle emits `[:rindle, :delivery, :signed]` telemetry on every successful
URL issuance, with `profile`, `adapter`, and `mode` metadata.

## Configuring Signed URL TTL

The default signed URL TTL comes from `Rindle.Config.signed_url_ttl_seconds/0`.
A profile can override it per-profile:

```elixir
defmodule MyApp.SensitiveDocsProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [preview: [mode: :fit, width: 600, height: 600]],
    delivery: [signed_url_ttl_seconds: 300]   # 5-minute URLs
end
```

For audit-heavy or PHI/PII-bearing media, prefer short TTLs (60–300s) and
re-issue on each request. For public-ish content (post images on a logged-in
feed), longer TTLs (900s–3600s) are acceptable and reduce signing overhead.

## Public Delivery (Explicit Opt-In)

Public delivery is an explicit per-profile opt-in. There is no global
toggle; you cannot accidentally make all profiles public.

```elixir
defmodule MyApp.PublicLogoProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [favicon: [mode: :fit, width: 32, height: 32]],
    delivery: [public: true]
end
```

When `public: true`, `Rindle.Delivery.url/3` returns the storage adapter's
unsigned URL (suitable for direct CDN caching). Use this only for content
that is genuinely intended for unauthenticated public consumption — logos,
brand assets, marketing imagery — and ideally back the bucket with a CDN
that caches and rate-limits at the edge.

## Authorizers

For fine-grained per-request authorization (e.g., "only the uploader can
view this avatar"), attach an authorizer module:

```elixir
defmodule MyApp.AvatarAuthorizer do
  @behaviour Rindle.Authorizer

  @impl true
  def authorize(%MyApp.User{} = actor, :deliver, %{key: key} = subject) do
    if owner?(actor, key), do: :ok, else: {:error, :forbidden}
  end

  def authorize(_actor, _action, _subject), do: {:error, :forbidden}

  defp owner?(actor, key), do: String.contains?(key, "users/#{actor.id}/")
end

defmodule MyApp.AvatarProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    delivery: [authorizer: MyApp.AvatarAuthorizer]
end
```

Pass the actor in the call options:

```elixir
{:ok, url} = Rindle.Delivery.url(MyApp.AvatarProfile, key, actor: current_user)
```

The authorizer runs **before** the storage adapter signs the URL. A
`{:error, reason}` from the authorizer short-circuits delivery; no URL is
issued and no telemetry is emitted. Public delivery still goes through the
authorizer if one is configured — opting into public mode does not bypass
auth.

## Storage Adapter Capabilities

Private delivery requires the storage adapter to support signed URLs.
Adapters declare their capabilities via `c:Rindle.Storage.capabilities/0`:

| Adapter              | Capabilities                                                |
| -------------------- | ----------------------------------------------------------- |
| `Rindle.Storage.S3`  | `[:presigned_put, :signed_url]`                             |
| `Rindle.Storage.Local` | `[:local]`                                                |

If you point a private profile at an adapter that does not advertise
`:signed_url`, `Rindle.Delivery.url/3` returns
`{:error, {:delivery_unsupported, :signed_url}}` rather than silently
falling back to an unsigned URL. This is intentional — the failure mode
should be loud, not silent.

## Variant URLs and the Stale-Variant Fallback

`Rindle.Delivery.variant_url/4` resolves a deliverable URL for a specific
variant, with safe fallback semantics for non-`ready` variants:

| Variant state | Behavior                                                  |
| ------------- | --------------------------------------------------------- |
| `ready`       | Sign and return the variant URL                           |
| `stale`       | Configurable: serve stale (`:stale_mode :serve_stale`) or fall back to original (`:fallback_original`, default) |
| `missing`     | Fall back to the original asset URL                       |
| `failed`      | Fall back to the original asset URL                       |
| `purged`      | Fall back to the original asset URL                       |

Adopters never see broken-image links because of variant state; the original
is always a valid fallback. See `Rindle.Domain.StalePolicy` for the
stale-variant semantics.

## Threat Model Notes

A few important properties to keep in mind when designing around signed URLs:

- **Signed URLs are bearer-token-equivalent until they expire.** Anyone
  who obtains the URL can use it for the lifetime of the signature. Treat
  signed URLs as secrets in logs and traces — Rindle scrubs them from
  telemetry metadata, but your own log handlers may not.
- **TTL is a tradeoff.** Longer TTLs reduce signing load and improve CDN
  hit rates, but extend the bearer-token window if the URL leaks. For
  PHI/PII or financial documents, prefer 60–300s and re-sign on each
  request.
- **Authorizers run on URL issuance, not on URL use.** A signed URL minted
  for user A still works if user B obtains it (until expiry). For the
  strongest posture, combine short TTLs with per-request authorization at
  the application layer (e.g., a Phoenix controller that re-checks
  permissions and *then* mints a fresh signed URL).
- **Public delivery cannot be silently re-enabled.** Switching from
  `delivery: [public: true]` back to private requires intentional code
  change; there is no environment variable that flips it.
- **Authorizer failure is loud.** A `{:error, reason}` from the authorizer
  is returned from `Rindle.Delivery.url/3`; callers cannot silently fall
  back to an unsigned URL.

## Application-Level TTL Default

Set the application-wide default TTL in your runtime config:

```elixir
# config/runtime.exs
config :rindle, :signed_url_ttl_seconds, 900   # 15 minutes
```

Per-profile overrides take precedence; profiles that don't set
`signed_url_ttl_seconds:` use this default.

## Quick Reference

| Goal                                       | Configuration                                       |
| ------------------------------------------ | --------------------------------------------------- |
| Private + default TTL                      | (no `delivery:` block needed)                       |
| Private + 5-minute URLs                    | `delivery: [signed_url_ttl_seconds: 300]`           |
| Public (CDN-cacheable)                     | `delivery: [public: true]`                          |
| Private + per-request authorization        | `delivery: [authorizer: MyAuthorizer]`              |
| Public + authorization (rare)              | `delivery: [public: true, authorizer: MyAuthorizer]` |
