defmodule Rindle.Delivery do
  @moduledoc """
  Delivery policy and URL resolution helpers.

  Private delivery is the default. Public delivery is an explicit profile opt-in,
  and authorization (when configured) runs before any URL is issued.

  Production delivery remains redirect-oriented: Rindle resolves URLs and lets
  the underlying storage or future streaming provider serve bytes directly.

  Signed URL TTL guidance stays intentionally policy-level rather than
  widening the profile DSL:

  - images: about 15 minutes (`900` seconds)
  - audio: about 1 hour (`3600` seconds)
  - video-on-demand: about 2 hours (`7200` seconds)
  - long-form playback: keep the same delivery surface and refresh tokens on
    the adopter side instead of introducing per-request TTL knobs

  Telemetry contract:

  - `[:rindle, :delivery, :signed]`
    measurements: `%{system_time: integer()}`
    metadata: `%{profile: module(), adapter: module(), mode: :public | :private}`
  - `[:rindle, :delivery, :streaming, :resolved]`
    measurements: `%{system_time: integer()}`
    metadata: `%{profile: module(), adapter: module(), mode: :public | :private, kind: :progressive, mime: String.t()}`
  """

  require Logger

  alias Rindle.Delivery.ContentDisposition
  alias Rindle.Domain.MediaProviderAsset
  alias Rindle.Domain.StalePolicy
  alias Rindle.Storage.Capabilities
  alias Rindle.Storage.Local

  @type delivery_mode :: :public | :private

  @local_playback_salt "rindle:delivery:local-playback"

  @doc """
  Returns the delivery policy map declared by a profile module.

  ## Examples

      # Requires a profile module that defines `delivery_policy/0`.
      iex> Rindle.Delivery.profile_delivery_policy(MyApp.MediaProfile)
      %{public: false, signed_url_ttl_seconds: 900}

  """
  @spec profile_delivery_policy(module()) :: map()
  def profile_delivery_policy(profile), do: profile.delivery_policy()

  @doc """
  Returns `true` when the profile opts in to public delivery.

  Defaults to `false` (private-by-default).

  ## Examples

      # Requires a profile module.
      iex> Rindle.Delivery.public_delivery?(MyApp.MediaProfile)
      false

  """
  @spec public_delivery?(module()) :: boolean()
  def public_delivery?(profile), do: Map.get(profile_delivery_policy(profile), :public, false)

  @doc """
  Returns the signed URL TTL (seconds) for a profile.

  Falls back to the application-wide default when the profile does not
  override it.

  ## Examples

      # Requires a profile module.
      iex> ttl = Rindle.Delivery.signed_url_ttl_seconds(MyApp.MediaProfile)
      iex> is_integer(ttl) and ttl > 0
      true

  """
  @spec signed_url_ttl_seconds(module()) :: pos_integer()
  def signed_url_ttl_seconds(profile) do
    Map.get(
      profile_delivery_policy(profile),
      :signed_url_ttl_seconds,
      Rindle.Config.signed_url_ttl_seconds()
    )
  end

  @doc """
  Returns the configured delivery authorizer module, or `nil` if none is set.

  Authorizers implement `c:Rindle.Authorizer.authorize/3` and run before any
  delivery URL is issued.

  ## Examples

      # Requires a profile module.
      iex> Rindle.Delivery.delivery_authorizer(MyApp.MediaProfile)
      nil

  """
  @spec delivery_authorizer(module()) :: module() | nil
  def delivery_authorizer(profile), do: Map.get(profile_delivery_policy(profile), :authorizer)

  @doc """
  Returns a deliverable URL for an asset's storage key.

  Public profiles return the storage adapter's bare URL; private profiles
  return a signed URL with the profile's configured TTL. Emits
  `[:rindle, :delivery, :signed]` telemetry on success.

  ## Examples

      # Requires a configured storage adapter and a key that exists in storage.
      iex> {:ok, url} = Rindle.Delivery.url(MyApp.MediaProfile, "uploads/abc.png")
      iex> is_binary(url)
      true

  """
  @spec url(module(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def url(profile, key, opts \\ []) do
    mode = delivery_mode(profile)
    adapter = profile.storage_adapter()
    subject = %{profile: profile, key: key, mode: mode}
    opts = normalize_delivery_opts(key, opts)

    with :ok <- authorize_delivery(profile, :deliver, subject, opts),
         :ok <- require_delivery_support(adapter, mode),
         {:ok, url} <- resolve_url(adapter, key, mode, opts, signed_url_ttl_seconds(profile)) do
      :telemetry.execute(
        [:rindle, :delivery, :signed],
        %{system_time: System.system_time()},
        %{
          profile: profile,
          adapter: adapter,
          mode: mode
        }
      )

      {:ok, url}
    end
  end

  @doc """
  Returns a streaming URL for an asset.

  Phase 33 — Promotes the v1.4 no-op delegate to a deterministic 8-branch
  dispatch tree (per CONTEXT D-19). When a profile has not opted into streaming
  via the `:streaming` key, behaviour is byte-for-byte identical to v1.4:
  progressive playback wrapped as `%{url, kind: :progressive, mime}` with the
  existing `[:rindle, :delivery, :streaming, :resolved]` telemetry emit.

  When a profile has opted in:

    1. profile streaming nil                → existing v1.4 progressive path (Branch 1)
    2. streaming + binary key               → :streaming_provider_requires_asset_struct (Branch 2)
    3. row in (pending|uploading|processing) → :provider_asset_not_ready (Branch 3)
    4. row in :errored                      → :provider_sync_failed (Branch 4)
    5. row in :ready + playback_id          → provider.signed_playback_url/3 (Branch 5)
    6. no row + opts[:strict] == false      → progressive fallback (Branch 6)
    7. no row + opts[:strict] == true       → :provider_asset_not_ready (Branch 7, D-20)

  `[:rindle, :delivery, :streaming, :resolved]` telemetry is preserved verbatim
  on Branches 1 and 6 (`kind: :progressive`); fires with `kind: :hls` on Branch 5
  (D-24).
  """
  @spec streaming_url(module(), String.t() | map(), keyword()) ::
          {:ok, %{url: String.t(), kind: :progressive | :hls, mime: String.t()}}
          | {:error, term()}
  def streaming_url(profile, asset_or_key, opts \\ []) do
    streaming_config = Map.get(profile.delivery_policy(), :streaming)

    cond do
      # Branch 1: no streaming configured → v1.4 progressive path verbatim.
      is_nil(streaming_config) ->
        do_progressive_streaming_url(profile, asset_or_key, opts)

      # Branch 2: streaming configured + binary key → require asset struct.
      is_binary(asset_or_key) ->
        {:error, :streaming_provider_requires_asset_struct}

      # Branches 3-7: streaming configured + asset struct → Repo lookup + dispatch.
      true ->
        dispatch_streaming(profile, streaming_config, asset_or_key, opts)
    end
  end

  # Preserves the v1.4 body verbatim. Called from Branch 1 AND Branch 6 (no row,
  # non-strict). D-24 — telemetry contract preservation.
  defp do_progressive_streaming_url(profile, key, opts) when is_binary(key) do
    opts = normalize_delivery_opts(key, opts)
    mime = Keyword.get(opts, :mime, "video/mp4")
    adapter = profile.storage_adapter()
    mode = delivery_mode(profile)
    subject = %{profile: profile, key: key, mode: mode}

    with :ok <- authorize_delivery(profile, :deliver, subject, opts),
         :ok <- require_streaming_support(adapter, mode, opts),
         {:ok, url} <-
           resolve_streaming_url(
             profile,
             adapter,
             key,
             mode,
             opts,
             signed_url_ttl_seconds(profile)
           ) do
      :telemetry.execute(
        [:rindle, :delivery, :streaming, :resolved],
        %{system_time: System.system_time()},
        %{
          profile: profile,
          adapter: adapter,
          mode: mode,
          kind: :progressive,
          mime: mime
        }
      )

      {:ok, %{url: url, kind: :progressive, mime: mime}}
    end
  end

  # When the caller passed an asset struct/map, Branch 1 / Branch 6's progressive
  # path needs a storage key. Pull from the struct.
  #
  # WR-03: guard the recursive call. If the caller passes a map that has no
  # :storage_key (or a non-binary one), `key_for/2` returns `nil` and the
  # binary clause above does NOT match (it requires `is_binary(key)`). Falling
  # through would raise FunctionClauseError from inside core dispatch; surface
  # a typed `:provider_asset_not_ready` instead so callers stay inside the
  # locked public-error vocabulary.
  defp do_progressive_streaming_url(profile, asset, opts) when is_map(asset) do
    case key_for(asset, :storage_key) do
      key when is_binary(key) -> do_progressive_streaming_url(profile, key, opts)
      _ -> {:error, :provider_asset_not_ready}
    end
  end

  defp dispatch_streaming(profile, streaming_config, asset, opts) do
    provider_name = derive_provider_name(streaming_config.provider)
    asset_id = asset_id_of(asset)

    case Rindle.Repo.get_by(MediaProviderAsset,
           asset_id: asset_id,
           profile: to_string(profile),
           provider_name: provider_name
         ) do
      nil ->
        if Keyword.get(opts, :strict, false) do
          # Branch 7
          {:error, :provider_asset_not_ready}
        else
          # Branch 6
          do_progressive_streaming_url(profile, asset, opts)
        end

      %MediaProviderAsset{state: state}
      when state in ["pending", "uploading", "processing"] ->
        # Branches 3a/3b/3c
        {:error, :provider_asset_not_ready}

      %MediaProviderAsset{state: "errored"} ->
        # Branch 4
        {:error, :provider_sync_failed}

      %MediaProviderAsset{state: "ready", playback_ids: []} ->
        # Branch 5b — defensive: state is :ready but no playback id available yet.
        {:error, :provider_asset_not_ready}

      %MediaProviderAsset{state: "ready", playback_ids: [playback_id | _]} = row ->
        # Branch 5 — but first cross-check the row's persisted playback_policy
        # and ingest_mode against the live streaming_config (WR-04). When
        # they disagree, refuse to mint and emit a config_drift warning so
        # operators can see the divergence without it surfacing as a silent
        # successful URL.
        case streaming_config_drift(row, streaming_config) do
          :ok ->
            dispatch_provider_signed_url(profile, streaming_config, playback_id, opts)

          {:drift, drift_meta} ->
            :telemetry.execute(
              [:rindle, :delivery, :streaming, :config_drift],
              %{system_time: System.system_time()},
              Map.merge(drift_meta, %{
                profile: profile,
                provider: streaming_config.provider
              })
            )

            {:error, :provider_sync_failed}
        end

      # Defensive: any other state ("deleted" or unexpected) falls through to the
      # not-ready error so callers never see a successful URL for a deleted asset.
      %MediaProviderAsset{} ->
        {:error, :provider_asset_not_ready}
    end
  end

  defp dispatch_provider_signed_url(profile, streaming_config, playback_id, opts) do
    mime = Keyword.get(opts, :mime, "application/vnd.apple.mpegurl")
    mode = delivery_mode(profile)
    subject = %{profile: profile, playback_id: playback_id, mode: mode, kind: :hls}

    with :ok <- authorize_delivery(profile, :deliver, subject, opts) do
      case streaming_config.provider.signed_playback_url(profile, playback_id, opts) do
        {:ok, %{url: _url, kind: :hls, mime: returned_mime}} = result ->
          :telemetry.execute(
            [:rindle, :delivery, :streaming, :resolved],
            %{system_time: System.system_time()},
            %{
              profile: profile,
              adapter: profile.storage_adapter(),
              mode: mode,
              kind: :hls,
              mime: returned_mime || mime
            }
          )

          # D-23 — pass-through return shape unchanged.
          result

        {:error, _} = err ->
          err

        # WR-01: defensive catch-all. The Rindle.Streaming.Provider behaviour
        # requires kind: :hls in the success shape; any other shape (including
        # bare :ok, kind: :progressive, or missing :kind / :url / :mime) is
        # treated as a misbehaving adapter and surfaced as a typed
        # :provider_sync_failed rather than crashing core dispatch with
        # CaseClauseError.
        other ->
          Logger.warning(
            "rindle.streaming.provider_returned_invalid_shape provider=" <>
              inspect(streaming_config.provider) <>
              " returned=" <> inspect(other, limit: 5)
          )

          {:error, :provider_sync_failed}
      end
    end
  end

  # D-22 — provider_name derivation. Module suffix to underscore.
  defp derive_provider_name(provider_module) when is_atom(provider_module) do
    provider_module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  # WR-04 — cross-check the persisted policy/mode on a :ready row against the
  # live streaming_config. nil row fields are treated as "not yet recorded"
  # and skipped (no drift), matching how D-19 historically used `state` as the
  # source of truth pre-Phase 33. When BOTH the row and the config carry a
  # value AND they disagree, return drift metadata so the dispatch layer can
  # emit a warning telemetry event and refuse the URL.
  defp streaming_config_drift(
         %MediaProviderAsset{playback_policy: row_policy, ingest_mode: row_mode},
         streaming_config
       ) do
    expected_policy = Atom.to_string(streaming_config.playback_policy)
    expected_mode = Atom.to_string(streaming_config.ingest_mode)

    cond do
      is_binary(row_policy) and row_policy != expected_policy ->
        {:drift,
         %{
           field: :playback_policy,
           row_value: row_policy,
           expected: expected_policy
         }}

      is_binary(row_mode) and row_mode != expected_mode ->
        {:drift,
         %{
           field: :ingest_mode,
           row_value: row_mode,
           expected: expected_mode
         }}

      true ->
        :ok
    end
  end

  # Pull the asset's binary_id. Supports asset structs/maps and variant-like
  # structs/maps that only carry `asset_id`.
  defp asset_id_of(%{asset_id: asset_id}) when is_binary(asset_id), do: asset_id
  defp asset_id_of(%{"asset_id" => asset_id}) when is_binary(asset_id), do: asset_id
  defp asset_id_of(%{id: id}) when is_binary(id), do: id
  defp asset_id_of(%{"id" => id}) when is_binary(id), do: id
  defp asset_id_of(asset), do: key_for(asset, :id) || key_for(asset, :asset_id)

  @doc """
  Returns a deliverable URL for a variant, falling back to the original asset
  when the variant is not yet `ready`.

  Stale variants are resolved against the configured stale-serving policy; missing or
  failed variants fall back to the original asset URL so callers never see
  broken links.

  ## Examples

      # Requires a configured storage adapter and ready/stale variant rows.
      iex> {:ok, url} = Rindle.Delivery.variant_url(MyApp.MediaProfile, asset, variant)
      iex> is_binary(url)
      true

  """
  @spec variant_url(module(), map(), map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def variant_url(profile, asset, variant, opts \\ []) do
    original_key = key_for(asset, :storage_key)
    variant_key = key_for(variant, :storage_key)
    variant_state = key_for(variant, :state)

    with {:ok, original_url} <- url(profile, original_key, opts) do
      do_variant_url(profile, variant_key, variant_state, original_url, opts)
    end
  end

  defp do_variant_url(profile, variant_key, "ready", _original_url, opts)
       when is_binary(variant_key) do
    url(profile, variant_key, opts)
  end

  defp do_variant_url(profile, variant_key, "stale", original_url, opts)
       when is_binary(variant_key) do
    stale_mode = Keyword.get(opts, :stale_mode, :fallback_original)

    case StalePolicy.resolve_stale_variant(stale_mode, "stale", original_url) do
      {:serve_variant, :stale} -> url(profile, variant_key, opts)
      {:serve_original, fallback_url} -> {:ok, fallback_url}
    end
  end

  defp do_variant_url(_profile, _variant_key, _variant_state, original_url, _opts) do
    {:ok, original_url}
  end

  defp delivery_mode(profile) do
    if public_delivery?(profile), do: :public, else: :private
  end

  defp authorize_delivery(profile, action, subject, opts) do
    case delivery_authorizer(profile) do
      nil ->
        :ok

      authorizer ->
        actor = Keyword.get(opts, :actor)

        case authorizer.authorize(actor, action, subject) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp require_delivery_support(_adapter, :public), do: :ok

  defp require_delivery_support(adapter, :private),
    do: Capabilities.require_delivery(adapter, :signed_url)

  defp require_streaming_support(Local, _mode, opts) do
    if local_playback_route?(opts), do: :ok, else: {:error, :streaming_not_configured}
  end

  defp require_streaming_support(adapter, mode, _opts),
    do: require_delivery_support(adapter, mode)

  defp resolve_url(adapter, key, :public, opts, _ttl) do
    adapter.url(key, opts)
  end

  defp resolve_url(adapter, key, :private, opts, ttl) do
    adapter.url(key, Keyword.put_new(opts, :expires_in, ttl))
  end

  defp resolve_streaming_url(profile, Local, key, _mode, opts, ttl) do
    if local_playback_route?(opts) do
      {:ok, local_playback_url(profile, key, opts, ttl)}
    else
      resolve_url(Local, key, :private, opts, ttl)
    end
  end

  defp resolve_streaming_url(_profile, adapter, key, mode, opts, ttl) do
    resolve_url(adapter, key, mode, opts, ttl)
  end

  defp normalize_delivery_opts(key, opts) do
    case ContentDisposition.normalize(key, opts) do
      nil -> opts
      content_disposition -> Keyword.put(opts, :content_disposition, content_disposition)
    end
  end

  defp local_playback_route?(opts) do
    case Keyword.get(opts, :local_route) do
      route_opts when is_list(route_opts) ->
        is_binary(Keyword.get(route_opts, :base_url)) and
          is_binary(Keyword.get(route_opts, :secret_key_base))

      _ ->
        false
    end
  end

  defp local_playback_url(profile, key, opts, ttl) do
    route_opts = Keyword.fetch!(opts, :local_route)
    base_url = Keyword.fetch!(route_opts, :base_url)
    secret_key_base = Keyword.fetch!(route_opts, :secret_key_base)
    expires_in = Keyword.get(opts, :expires_in, ttl)
    now = System.system_time(:second)

    token =
      Plug.Crypto.sign(
        secret_key_base,
        @local_playback_salt,
        %{
          "actor_subject" => actor_subject(Keyword.get(opts, :actor)),
          "content_disposition" => Keyword.get(opts, :content_disposition),
          "expires_at" => now + expires_in,
          "key" => key,
          "mime" => Keyword.get(opts, :mime, "video/mp4"),
          "profile" => inspect(profile)
        },
        max_age: expires_in,
        signed_at: now
      )

    uri = URI.parse(base_url)
    query = uri.query |> decode_query() |> Map.put("token", token) |> URI.encode_query()

    uri
    |> Map.put(:query, query)
    |> URI.to_string()
  end

  defp actor_subject(nil), do: "anonymous"
  defp actor_subject(actor) when is_binary(actor), do: actor
  defp actor_subject(actor) when is_atom(actor), do: Atom.to_string(actor)

  defp actor_subject(%{id: id}) when is_binary(id) or is_integer(id),
    do: to_string(id)

  defp actor_subject(%{"id" => id}) when is_binary(id) or is_integer(id),
    do: to_string(id)

  defp actor_subject(actor) do
    actor
    |> :erlang.term_to_binary()
    |> Base.url_encode64(padding: false)
  end

  defp decode_query(nil), do: %{}
  defp decode_query(query), do: URI.decode_query(query)

  defp key_for(%{} = record, key),
    do: Map.get(record, key) || Map.get(record, Atom.to_string(key))
end
