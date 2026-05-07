defmodule Rindle.Capability do
  @moduledoc """
  Aggregates Rindle runtime capability surfaces for ops/doctor consumers.

  Phase 33 ships the aggregator function only. Phase 36 (MUX-16) refactors
  `mix rindle.doctor` to consume `report/0`.

  ## Security invariant 14

  `report/0` returns booleans and module names — NEVER actual configuration
  values. `signed_playback_configured?` is a presence check on the
  `Rindle.Streaming.Provider.Mux` config keys; it does NOT echo the keys back.
  The function uses `Application.get_env/2`, which returns `[]` when nothing is
  configured, so it does not crash when the optional `:mux` dep is absent.
  """

  @typedoc "Locked report shape per Phase 33 D-30."
  @type report :: %{
          storage: %{module() => [atom()]},
          processor: %{module() => [atom()]},
          streaming: %{
            providers: %{module() => [atom()]},
            signed_playback_configured?: boolean(),
            configured_profiles: [module()]
          }
        }

  @spec report() :: report()
  def report do
    profiles = profile_modules()

    %{
      storage: storage_report(profiles),
      processor: processor_report(profiles),
      streaming: %{
        providers: streaming_providers_report(profiles),
        signed_playback_configured?: signed_playback_configured?(),
        configured_profiles: configured_streaming_profiles(profiles)
      }
    }
  end

  # --- storage ---

  defp storage_report(profiles) do
    for profile <- profiles, into: %{} do
      adapter = safely_call_zero(profile, :storage_adapter)
      key = adapter || profile
      {key, capabilities_for(adapter, Rindle.Storage.Capabilities)}
    end
  end

  # --- processor ---

  defp processor_report(profiles) do
    # Phase 33 has no Rindle.Processor.Capabilities module yet (AV uses a
    # different shape via Rindle.AV.Capability). Map known processor modules
    # to their advertised capabilities; if the function is missing or raises,
    # return an empty list.
    for profile <- profiles, into: %{} do
      processor = safely_call_zero(profile, :processor)

      caps =
        if processor, do: List.wrap(safely_call_zero(processor, :capabilities) || []), else: []

      {processor || profile, caps}
    end
  end

  # --- streaming ---

  defp streaming_providers_report(profiles) do
    for profile <- profiles,
        streaming = streaming_config_for(profile),
        not is_nil(streaming),
        provider = streaming_provider(streaming),
        not is_nil(provider),
        into: %{} do
      {provider, capabilities_for(provider, streaming_vocabulary())}
    end
  end

  defp signed_playback_configured? do
    cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    is_binary(cfg_get(cfg, :signing_key_id)) and
      is_binary(cfg_get(cfg, :signing_private_key))
  end

  @doc """
  Returns the subset of `profiles` that opt into the `:streaming` delivery key.

  Public seam used by `mix rindle.doctor`'s streaming checks (Phase 36 / MUX-16)
  as the single source of truth for "is this profile streaming-enabled?". The
  predicate is identity with the inner `report/0` filter — both call
  `streaming_config_for/1` via `delivery_policy/0`.
  """
  @spec configured_streaming_profiles([module()]) :: [module()]
  def configured_streaming_profiles(profiles) do
    for profile <- profiles,
        not is_nil(streaming_config_for(profile)) do
      profile
    end
  end

  @doc """
  Returns the subset of `profiles` that select `Rindle.Storage.GCS` as their storage adapter.

  Public seam used by `mix rindle.doctor`'s GCS checks (Phase 37 / D-13) as the
  single source of truth for "is this profile GCS-enabled?". Mirrors
  `configured_streaming_profiles/1` (Phase 36 / MUX-16) — both delegate from
  `runtime_checks.ex` so the doctor module never inlines profile-filter logic.
  """
  @spec configured_gcs_profiles([module()]) :: [module()]
  def configured_gcs_profiles(profiles) do
    for profile <- profiles,
        safely_call_zero(profile, :storage_adapter) == Rindle.Storage.GCS do
      profile
    end
  end

  # --- helpers ---

  defp profile_modules do
    Rindle.Config.profile_modules()
  rescue
    _ -> []
  end

  defp streaming_config_for(profile) do
    case safely_call_zero(profile, :delivery_policy) do
      %{streaming: streaming} -> streaming
      _ -> nil
    end
  end

  defp streaming_provider(streaming) when is_map(streaming), do: Map.get(streaming, :provider)

  defp streaming_provider(streaming) when is_list(streaming),
    do: Keyword.get(streaming, :provider)

  defp streaming_provider(_), do: nil

  defp streaming_vocabulary, do: Rindle.Streaming.Capabilities

  defp capabilities_for(nil, _vocab), do: []

  defp capabilities_for(module, vocab) do
    if function_exported?(module, :capabilities, 0) do
      try do
        vocab.safe(module)
      rescue
        _ -> []
      end
    else
      []
    end
  end

  defp safely_call_zero(nil, _fun), do: nil

  defp safely_call_zero(module, fun) do
    if function_exported?(module, fun, 0) do
      apply(module, fun, [])
    else
      nil
    end
  rescue
    _ -> nil
  end

  defp cfg_get(cfg, key) when is_list(cfg), do: Keyword.get(cfg, key)
  defp cfg_get(cfg, key) when is_map(cfg), do: Map.get(cfg, key)
  defp cfg_get(_, _), do: nil
end
