defmodule Rindle.Ops.RuntimeChecks do
  @moduledoc false

  alias Ecto.Migrator
  alias Rindle.Config
  alias Rindle.Delivery
  alias Rindle.Processor.AV
  alias Rindle.Processor.AV.RuntimeGuard
  alias Rindle.Storage.Local

  @base_queues [:rindle_maintenance, :rindle_process, :rindle_promote, :rindle_purge]
  @local_playback_fix """
  Configure `config :rindle, :local_playback_route, [base_url: ..., secret_key_base: ...]` and mount `Rindle.Delivery.LocalPlug` for local AV playback, or use `Rindle.Delivery.url/3` for progressive delivery instead.
  """

  @type check_status :: :ok | :error
  @type check_result :: %{
          id: String.t(),
          status: check_status(),
          component: atom(),
          summary: String.t(),
          fix: String.t()
        }

  @type report :: %{
          checks: [check_result()],
          failed: non_neg_integer(),
          success?: boolean(),
          total: non_neg_integer()
        }

  @spec run([String.t()], keyword()) :: report()
  def run(args, opts \\ []) do
    env = Keyword.get(opts, :env, System.get_env())
    probe = Keyword.get(opts, :probe, fn -> Rindle.AV.Probe.check_ffmpeg!() end)
    mix_app = Keyword.get(opts, :mix_app, :rindle)
    resolved = resolve_profiles(args, Keyword.get(opts, :profiles, Config.profile_modules()))
    profiles = resolved.profiles
    oban_config = Keyword.get(opts, :oban_config, Application.get_env(mix_app, Oban))
    local_playback_route = Keyword.get(opts, :local_playback_route, Config.local_playback_route())

    migration_statuses = Keyword.get_lazy(opts, :migration_statuses, fn -> migration_statuses(opts) end)

    checks =
      [
        fn -> check_delivery_support(profiles) end,
        fn -> check_ffmpeg_runtime(probe) end,
        fn -> check_local_playback(profiles, local_playback_route) end,
        fn -> check_migration_pending(migration_statuses) end,
        fn -> check_migration_unresolved(migration_statuses) end,
        fn -> check_oban_default_instance(oban_config) end,
        fn -> check_oban_required_queues(profiles, oban_config) end,
        fn -> check_profile_runtime_fit(resolved, env) end
      ]
      |> Enum.map(&run_check/1)
      |> Enum.sort_by(& &1.id)

    failed = Enum.count(checks, &(&1.status == :error))

    %{
      checks: checks,
      failed: failed,
      success?: failed == 0,
      total: length(checks)
    }
  end

  defp run_check(fun) do
    started_at = System.monotonic_time()
    result = fun.()

    :telemetry.execute(
      [:rindle, :runtime, :check, :stop],
      %{duration_us: elapsed_us(started_at)},
      %{check: result.id, status: result.status, component: result.component}
    )

    result
  end

  defp check_ffmpeg_runtime(probe) do
    try do
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

  defp check_oban_default_instance(nil) do
    error_result(
      "doctor.oban_default_instance",
      :oban,
      "No default `Oban` configuration was found for the current Mix app.",
      "Configure `config :your_app, Oban, repo: #{inspect(Config.repo())}, queues: [...]` and start `{Oban, Application.fetch_env!(:your_app, Oban)}` under the default `Oban` module path."
    )
  end

  defp check_oban_default_instance(oban_config) do
    configured_repo = Keyword.get(oban_config, :repo)
    expected_repo = Config.repo()

    if configured_repo == expected_repo do
      ok_result(
        "doctor.oban_default_instance",
        :oban,
        "Default `Oban` ownership matches #{inspect(expected_repo)}.",
        "Keep the default `Oban` repo aligned with `config :rindle, :repo`."
      )
    else
      error_result(
        "doctor.oban_default_instance",
        :oban,
        "Default `Oban` repo drift detected: expected #{inspect(expected_repo)}, got #{inspect(configured_repo)}.",
        "Point the default `Oban` config at #{inspect(expected_repo)}; named-instance or alternate-repo ownership is out of scope for the current Rindle contract."
      )
    end
  end

  defp check_oban_required_queues(profiles, oban_config) do
    required = required_queues(profiles)
    configured = oban_queue_names(oban_config)
    missing = required -- configured

    if missing == [] do
      ok_result(
        "doctor.oban_required_queues",
        :oban,
        "Default `Oban` config declares required queues: #{Enum.map_join(required, ", ", &Atom.to_string/1)}.",
        "Keep the documented queue list in the default `Oban` config."
      )
    else
      error_result(
        "doctor.oban_required_queues",
        :oban,
        "Default `Oban` config is missing required queues: #{Enum.map_join(missing, ", ", &Atom.to_string/1)}.",
        "Add the missing queues to `config :your_app, Oban, queues: [...]`. `rindle_media` is only required when your discovered profiles declare AV-capable variants."
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
      |> Enum.filter(&(local_av_profile?(&1)))
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

  defp check_migration_pending(statuses) do
    pending =
      statuses
      |> Enum.filter(fn
        {:down, _version, _name} -> true
        _other -> false
      end)
      |> Enum.map(&migration_version/1)

    if pending == [] do
      ok_result(
        "doctor.migrations.pending",
        :migrations,
        "No pending Rindle migrations were found.",
        "Keep Rindle migrations applied before running the runtime pipeline."
      )
    else
      error_result(
        "doctor.migrations.pending",
        :migrations,
        "Pending Rindle migrations: #{Enum.join(pending, ", ")}.",
        "Run `mix ecto.migrate` for the repo configured at `config :rindle, :repo` before retrying."
      )
    end
  end

  defp check_migration_unresolved(statuses) do
    unresolved =
      statuses
      |> Enum.filter(fn
        {:up, _version, "** FILE NOT FOUND **"} -> true
        _other -> false
      end)
      |> Enum.map(&migration_version/1)

    if unresolved == [] do
      ok_result(
        "doctor.migrations.unresolved",
        :migrations,
        "No unresolved applied Rindle migrations were found.",
        "Keep local Rindle migration files in sync with the database history."
      )
    else
      error_result(
        "doctor.migrations.unresolved",
        :migrations,
        "Applied Rindle migrations missing from local code: #{Enum.join(unresolved, ", ")}.",
        "Restore the migration files missing from local code, or reconcile the database history before running more Rindle migrations."
      )
    end
  end

  defp resolve_profiles([], profiles), do: %{profiles: Enum.uniq(profiles), error: nil}

  defp resolve_profiles(args, _profiles) do
    {profiles, errors} =
      Enum.reduce(args, {[], []}, fn arg, {profiles, errors} ->
        module = module_from_string(arg)

        case ensure_profile_loaded(module, arg) do
          {:ok, profile} -> {[profile | profiles], errors}
          {:error, error} -> {profiles, [error | errors]}
        end
      end)

    %{
      profiles: Enum.reverse(profiles),
      error: errors |> Enum.reverse() |> Enum.join(" ")
    }
  end

  defp ensure_profile_loaded(module, module_name) do
    if Code.ensure_loaded?(module) do
      validate_profile_module(module, module_name)
    else
      case source_path_for_module(module_name) do
        nil ->
          {:error,
           "unknown profile module #{module_name}. Pass a loaded Rindle profile module like Rindle.Adopter.CanonicalApp.VideoProfile."}

        path ->
          Code.compile_file(path)
          validate_profile_module(module, module_name)
      end
    end
  end

  defp validate_profile_module(module, module_name) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__rindle_profile__, 0) and
         function_exported?(module, :variants, 0) do
      {:ok, module}
    else
      {:error,
       "unknown profile module #{module_name}. Pass a loaded Rindle profile module like Rindle.Adopter.CanonicalApp.VideoProfile."}
    end
  end

  defp source_path_for_module(module_name) do
    ["lib", "test/support", "test/adopter"]
    |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*.ex")))
    |> Enum.find(fn path ->
      File.read!(path) =~ "defmodule #{module_name} do"
    end)
  end

  defp migration_statuses(opts) do
    repo = Config.repo()
    path = Keyword.get(opts, :migrations_path, Config.migrations_path())

    case Migrator.with_repo(repo, fn started_repo ->
           Migrator.migrations(started_repo, path)
         end, mode: :temporary) do
      {:ok, statuses, _apps} ->
        statuses

      {:error, reason} ->
        [
          {:down, -1,
           "migration inspection failed: #{Exception.message(normalize_exception(reason))}"}
        ]
    end
  rescue
    error ->
      [{:down, -1, "migration inspection failed: #{Exception.message(error)}"}]
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

  defp required_queues(profiles) do
    queues =
      if Enum.any?(profiles, &profile_has_av_variants?/1) do
        @base_queues ++ [:rindle_media]
      else
        @base_queues
      end

    Enum.sort(queues)
  end

  defp oban_queue_names(nil), do: []
  defp oban_queue_names(false), do: []

  defp oban_queue_names(oban_config) do
    oban_config
    |> Keyword.get(:queues, [])
    |> case do
      false -> []
      queues when is_list(queues) -> Enum.map(queues, fn {name, _value} -> name end)
      _other -> []
    end
    |> Enum.sort()
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

  defp migration_version({_state, -1, _name}), do: "migration inspection failed"
  defp migration_version({_state, version, _name}), do: Integer.to_string(version)

  defp module_from_string(name) do
    name
    |> String.split(".")
    |> Module.concat()
  end

  defp ok_result(id, component, summary, fix) do
    %{id: id, status: :ok, component: component, summary: summary, fix: fix}
  end

  defp error_result(id, component, summary, fix) do
    %{id: id, status: :error, component: component, summary: summary, fix: fix}
  end

  defp elapsed_us(started_at) do
    System.convert_time_unit(System.monotonic_time() - started_at, :native, :microsecond)
  end

  defp normalize_exception(%_{} = error), do: error
  defp normalize_exception(error), do: RuntimeError.exception(inspect(error))
end
