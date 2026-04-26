defmodule Rindle.Delivery do
  @moduledoc """
  Delivery policy and URL resolution helpers.

  Private delivery is the default. Public delivery is an explicit profile opt-in,
  and authorization (when configured) runs before any URL is issued.
  """

  alias Rindle.Domain.StalePolicy

  @type delivery_mode :: :public | :private

  @spec profile_delivery_policy(module()) :: map()
  def profile_delivery_policy(profile), do: profile.delivery_policy()

  @spec public_delivery?(module()) :: boolean()
  def public_delivery?(profile), do: Map.get(profile_delivery_policy(profile), :public, false)

  @spec signed_url_ttl_seconds(module()) :: pos_integer()
  def signed_url_ttl_seconds(profile) do
    Map.get(
      profile_delivery_policy(profile),
      :signed_url_ttl_seconds,
      Rindle.Config.signed_url_ttl_seconds()
    )
  end

  @spec delivery_authorizer(module()) :: module() | nil
  def delivery_authorizer(profile), do: Map.get(profile_delivery_policy(profile), :authorizer)

  @spec url(module(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def url(profile, key, opts \\ []) do
    mode = delivery_mode(profile)
    adapter = profile.storage_adapter()
    subject = %{profile: profile, key: key, mode: mode}

    with :ok <- authorize_delivery(profile, :deliver, subject, opts),
         :ok <- ensure_signed_delivery_support(adapter, mode),
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

  @spec variant_url(module(), map(), map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def variant_url(profile, asset, variant, opts \\ []) do
    original_key = key_for(asset, :storage_key)
    variant_key = key_for(variant, :storage_key)
    variant_state = key_for(variant, :state)

    with {:ok, original_url} <- url(profile, original_key, opts) do
      case variant_state do
        "ready" when is_binary(variant_key) ->
          url(profile, variant_key, opts)

        "stale" when is_binary(variant_key) ->
          stale_mode = Keyword.get(opts, :stale_mode, :fallback_original)

          case StalePolicy.resolve_stale_variant(stale_mode, variant_state, original_url) do
            {:serve_variant, :stale} -> url(profile, variant_key, opts)
            {:serve_original, fallback_url} -> {:ok, fallback_url}
          end

        _other_state ->
          {:ok, original_url}
      end
    end
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

  defp ensure_signed_delivery_support(_adapter, :public), do: :ok

  defp ensure_signed_delivery_support(adapter, :private) do
    capabilities = safe_capabilities(adapter)

    if :signed_url in capabilities do
      :ok
    else
      {:error, {:delivery_unsupported, :signed_url}}
    end
  end

  defp resolve_url(adapter, key, :public, opts, _ttl) do
    adapter.url(key, opts)
  end

  defp resolve_url(adapter, key, :private, opts, ttl) do
    adapter.url(key, Keyword.put_new(opts, :expires_in, ttl))
  end

  defp safe_capabilities(adapter) do
    case adapter.capabilities() do
      caps when is_list(caps) -> caps
      _ -> []
    end
  rescue
    _ -> []
  end

  defp key_for(%{} = record, key),
    do: Map.get(record, key) || Map.get(record, Atom.to_string(key))
end
