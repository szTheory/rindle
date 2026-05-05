defmodule Rindle.Delivery do
  @moduledoc """
  Delivery policy and URL resolution helpers.

  Private delivery is the default. Public delivery is an explicit profile opt-in,
  and authorization (when configured) runs before any URL is issued.
  """

  alias Rindle.Delivery.ContentDisposition
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
  Returns a progressive streaming URL wrapper for an asset's storage key.

  This is an additive future-stable playback surface. In v1.4 it delegates to
  `url/3`, preserving the same authorization, TTL, and error semantics while
  wrapping successful results as `%{url, kind, mime}`. Emits
  `[:rindle, :delivery, :streaming, :resolved]` telemetry on success.
  """
  @spec streaming_url(module(), String.t(), keyword()) ::
          {:ok, %{url: String.t(), kind: :progressive, mime: String.t()}} | {:error, term()}
  def streaming_url(profile, key, opts \\ []) do
    opts = normalize_delivery_opts(key, opts)
    mime = Keyword.get(opts, :mime, "video/mp4")
    adapter = profile.storage_adapter()
    mode = delivery_mode(profile)
    subject = %{profile: profile, key: key, mode: mode}

    with :ok <- authorize_delivery(profile, :deliver, subject, opts),
         :ok <- require_streaming_support(adapter, mode, opts),
         {:ok, url} <- resolve_streaming_url(profile, adapter, key, mode, opts, signed_url_ttl_seconds(profile)) do
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
    if local_playback_route?(opts), do: :ok, else: require_delivery_support(Local, :private)
  end

  defp require_streaming_support(adapter, mode, _opts), do: require_delivery_support(adapter, mode)

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
