defmodule Rindle.Ops.RuntimeChecks.CoreChecks do
  @moduledoc false

  alias Rindle.Delivery
  alias Rindle.Processor.AV
  alias Rindle.Processor.AV.RuntimeGuard
  alias Rindle.Storage.Local

  @local_playback_fix """
  Configure `config :rindle, :local_playback_route, [base_url: ..., secret_key_base: ...]` and mount `Rindle.Delivery.LocalPlug` for local AV playback, or use `Rindle.Delivery.url/3` for progressive delivery instead.
  """

  @doc false
  def schedule(profiles, probe, local_playback_route, resolved, env) do
    checks = [
      fn -> check_delivery_support(profiles) end,
      fn -> check_ffmpeg_runtime(probe) end,
      fn -> check_local_playback(profiles, local_playback_route) end,
      fn -> check_profile_runtime_fit(resolved, env) end
    ]

    {checks, %{av_profiles?: Enum.any?(profiles, &profile_has_av_variants?/1)}}
  end

  defp check_ffmpeg_runtime(probe) do
    probe.()

    ok_result(
      "doctor.ffmpeg_runtime",
      :runtime,
      "FFmpeg is installed and available in PATH.",
      "Keep `ffmpeg` >= 6.0 available on the host path."
    )
  rescue
    error in RuntimeError ->
      error_result(
        "doctor.ffmpeg_runtime",
        :runtime,
        "FFmpeg runtime drift detected: #{error.message}",
        "Install or repair `ffmpeg` >= 6.0 on the host before retrying `mix rindle.doctor`."
      )
  end

  defp check_profile_runtime_fit(%{error: message}, _env)
       when is_binary(message) and message != "" do
    error_result(
      "doctor.profile_runtime_fit",
      :profiles,
      message,
      "Pass loaded Rindle profile modules explicitly, or configure `config :rindle, :profiles, [...]` so doctor can discover them deterministically."
    )
  end

  defp check_profile_runtime_fit(%{profiles: profiles}, env) do
    case profile_runtime_failures(profiles, env) do
      [] ->
        av_variants =
          profiles
          |> Enum.flat_map(& &1.variants())
          |> Enum.count(fn {_name, spec} -> av_variant?(spec) end)

        ok_result(
          "doctor.profile_runtime_fit",
          :profiles,
          "Profile/runtime fit OK for #{length(profiles)} profile(s); checked #{av_variants} AV variant(s).",
          "Keep profile declarations aligned with the current runtime capabilities."
        )

      failures ->
        error_result(
          "doctor.profile_runtime_fit",
          :profiles,
          Enum.join(failures, " "),
          "Adjust the failing profile variants, or move the host onto a runtime that satisfies the declared AV requirements before retrying."
        )
    end
  end

  defp check_delivery_support(profiles) do
    failures =
      Enum.flat_map(profiles, fn profile ->
        adapter = profile.storage_adapter()

        if Delivery.public_delivery?(profile) or :signed_url in adapter.capabilities() do
          []
        else
          [
            "#{inspect(profile)} is private by default but #{inspect(adapter)} does not advertise `:signed_url`."
          ]
        end
      end)

    if failures == [] do
      ok_result(
        "doctor.delivery_support",
        :delivery,
        "Profile delivery configuration matches adapter capabilities.",
        "Keep private profiles on adapters that advertise `:signed_url`, or opt the profile into explicit public delivery."
      )
    else
      error_result(
        "doctor.delivery_support",
        :delivery,
        Enum.join(failures, " "),
        "Switch the failing profile to an adapter that advertises `:signed_url`, or set `delivery: [public: true]` when public delivery is intentional."
      )
    end
  end

  defp check_local_playback(profiles, local_playback_route) do
    local_av_profiles =
      profiles
      |> Enum.filter(&local_av_profile?(&1))
      |> Enum.map(&inspect/1)

    cond do
      local_av_profiles == [] ->
        ok_result(
          "doctor.local_playback",
          :delivery,
          "No local AV playback profiles were discovered.",
          @local_playback_fix
        )

      complete_local_playback_route?(local_playback_route) ->
        ok_result(
          "doctor.local_playback",
          :delivery,
          "Local AV playback route config is present for #{Enum.join(local_av_profiles, ", ")}.",
          @local_playback_fix
        )

      true ->
        error_result(
          "doctor.local_playback",
          :delivery,
          "Local AV playback route config is missing or incomplete for #{Enum.join(local_av_profiles, ", ")}.",
          @local_playback_fix
        )
    end
  end

  defp profile_runtime_failures(profiles, env) do
    Enum.flat_map(profiles, fn profile ->
      profile.variants()
      |> Enum.filter(fn {_name, spec} -> av_variant?(spec) end)
      |> Enum.flat_map(fn {name, spec} ->
        with {:ok, normalized} <- AV.normalize(spec),
             :ok <- RuntimeGuard.check!(normalized, env: env),
             :ok <- ensure_capability_supported(normalized) do
          []
        else
          {:error, reason} ->
            [
              "profile #{inspect(profile)} variant #{inspect(name)} failed runtime checks: #{inspect(reason)}."
            ]
        end
      end)
    end)
  end

  defp ensure_capability_supported(normalized) do
    capability = required_capability(normalized)

    if capability in AV.capabilities() do
      :ok
    else
      {:error, {:unsupported_processor_capability, capability}}
    end
  end

  defp complete_local_playback_route?(route) when is_list(route) do
    is_binary(Keyword.get(route, :base_url)) and is_binary(Keyword.get(route, :secret_key_base))
  end

  defp complete_local_playback_route?(route) when is_map(route) do
    complete_local_playback_route?(Enum.to_list(route))
  end

  defp complete_local_playback_route?(_route), do: false

  defp local_av_profile?(profile) do
    profile.storage_adapter() == Local and profile_has_av_variants?(profile)
  end

  defp profile_has_av_variants?(profile) do
    Enum.any?(profile.variants(), fn {_name, spec} -> av_variant?(spec) end)
  end

  defp required_capability(%{kind: :video, output_kind: :video}), do: :video_transcode
  defp required_capability(%{kind: :audio, output_kind: :audio}), do: :audio_transcode
  defp required_capability(%{kind: :waveform, output_kind: :waveform}), do: :audio_waveform
  defp required_capability(%{preset: :video_thumbnail_strip}), do: :video_thumbnail_strip
  defp required_capability(%{kind: :image, output_kind: :image}), do: :video_frame_extract

  defp av_variant?(spec) when is_list(spec), do: spec |> Map.new() |> av_variant?()
  defp av_variant?(%{kind: kind}) when kind in [:video, :audio, :waveform], do: true

  defp av_variant?(%{preset: preset})
       when preset in [:video_poster_scene, :video_thumbnail_strip, :web_720p],
       do: true

  defp av_variant?(%{output_kind: kind}) when kind in [:video, :audio, :waveform], do: true
  defp av_variant?(_spec), do: false

  defp ok_result(id, component, summary, fix) do
    {:runtime_check, :ok, id, component, summary, fix, %{}}
  end

  defp error_result(id, component, summary, fix) do
    {:runtime_check, :error, id, component, summary, fix, %{}}
  end
end
