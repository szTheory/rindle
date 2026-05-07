defmodule Rindle.Streaming.Provider do
  @moduledoc """
  Behaviour contract for streaming providers (Phase 33 — promoted from v1.4 reserved shim).

  A streaming provider implements asset-CRUD + signed-playback-URL + webhook-verify
  against an external streaming service (e.g. Mux). The dispatch surface that decides
  whether to call into a provider lives on `Rindle.Delivery.streaming_url/3`, NOT on
  this behaviour.

  ## Security invariant 14

  Implementations MUST NOT expose `provider_asset_id` (or any provider-internal
  identifier) in adopter-facing URLs, telemetry metadata, log lines, or `inspect/2`
  output. Only the public-side `playback_id` (or its provider equivalent) crosses
  into URLs. Custom `Inspect` impls on persistence rows enforce redaction at the
  schema layer (see `Rindle.Domain.MediaProviderAsset`).

  ## Callback discipline

  Every callback returns an `:ok`-tuple or `:error`-tuple. No raises on the happy
  path. `verify_webhook/3` returns a normalized `provider_event` map — provider
  structs (e.g. Mux structs) MUST NOT cross this boundary.
  """

  @typedoc "Provider-internal asset identifier. Treated as a secret; never exposed in adopter-facing paths."
  @type provider_asset_id :: String.t()

  @typedoc "Public-side playback identifier. Safe for URL embedding."
  @type playback_id :: String.t()

  @typedoc """
  Locked finite-state-machine vocabulary for `media_provider_assets.state`.

  BL-04 alignment: the schema column is `:string` (see
  `Rindle.Domain.MediaProviderAsset.@states`), the FSM keys are strings
  (`Rindle.Domain.ProviderAssetFSM.@allowed_transitions`), and adapter
  implementations return strings (e.g. `Rindle.Streaming.Provider.Mux.normalize_state/1`).
  This typespec mirrors that surface — the closed set lives at the schema
  layer, not in the type system. Adopters MUST treat values as one of:

      "pending" | "uploading" | "processing" | "ready" | "errored" | "deleted"
  """
  @type provider_state :: String.t()

  @typedoc """
  Normalized webhook event surface. Provider-specific structs MUST be normalized
  into this shape by `verify_webhook/3` before crossing into core.

  `state` is `nil` when the webhook payload carries no recognized status
  (e.g. lifecycle events like `video.asset.created` that pre-date transcoding).

  `:upload_id` is OPTIONAL and populated only by adapter typed branches that
  carry both an upload id and a provider asset id (e.g. Mux's
  `video.upload.asset_created` — see D-29 / D-30, added in Phase 35 as
  forward-compat for Phase 37 / direct-creator-upload).
  """
  @type provider_event :: %{
          required(:type) => atom(),
          required(:provider_asset_id) => provider_asset_id() | nil,
          required(:playback_ids) => [playback_id()],
          required(:state) => provider_state() | nil,
          required(:occurred_at) => DateTime.t() | nil,
          required(:raw) => map(),
          optional(:upload_id) => String.t() | nil
        }

  @typedoc "Capability atom advertised by `capabilities/0`. Closed vocabulary lives in `Rindle.Streaming.Capabilities`."
  @type capability ::
          :signed_playback
          | :public_playback
          | :webhook_ingest
          | :server_push_ingest
          | :direct_creator_upload

  @doc "Capabilities advertised by this provider. Filtered against `Rindle.Streaming.Capabilities.known/0` by `safe/1`."
  @callback capabilities() :: [capability()]

  @doc """
  Create a provider-side asset for `source_url` under `profile`. Returns the
  provider-internal identifier and (when known) initial playback ids.
  """
  @callback create_asset(profile :: module(), source_url :: String.t(), opts :: keyword()) ::
              {:ok, %{provider_asset_id: provider_asset_id(), playback_ids: [playback_id()]}}
              | {:error, term()}

  @doc "Fetch the current provider-side state for `provider_asset_id`."
  @callback get_asset(provider_asset_id()) ::
              {:ok,
               %{
                 state: provider_state(),
                 playback_ids: [playback_id()],
                 raw: map()
               }}
              | {:error, term()}

  @doc "Delete the provider-side asset. Idempotent on `:not_found`."
  @callback delete_asset(provider_asset_id()) :: :ok | {:error, term()}

  @doc """
  Mint a signed playback URL for `playback_id` under `profile`. Implementations
  MUST respect the profile's `signed_url_ttl_seconds` policy (no hidden defaults).
  Returns the v1.4-stable shape `%{url, kind, mime}`.
  """
  @callback signed_playback_url(profile :: module(), playback_id(), opts :: keyword()) ::
              {:ok, %{url: String.t(), kind: :hls, mime: String.t()}}
              | {:error, term()}

  @doc """
  Verify a raw webhook payload against `secrets`. Returns a normalized
  `provider_event` map on success — provider-specific structs MUST be normalized
  before returning.
  """
  @callback verify_webhook(raw_body :: binary(), headers :: map(), secrets :: [String.t()]) ::
              {:ok, provider_event()} | {:error, term()}

  @doc """
  OPTIONAL: Mint a direct-creator upload URL the browser can PUT to. Reserved
  for Phase 37 / v1.7; no v1.6 adapter implements this callback.
  """
  @callback create_direct_upload(profile :: module(), opts :: keyword()) ::
              {:ok,
               %{
                 upload_url: String.t(),
                 upload_id: String.t(),
                 provider_asset_id: provider_asset_id() | nil
               }}
              | {:error, term()}

  @optional_callbacks [create_direct_upload: 2]
end
