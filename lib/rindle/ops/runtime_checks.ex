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

  @streaming_required_env_vars ~w(RINDLE_MUX_TOKEN_ID RINDLE_MUX_TOKEN_SECRET
                                  RINDLE_MUX_SIGNING_KEY_ID RINDLE_MUX_SIGNING_PRIVATE_KEY
                                  RINDLE_MUX_WEBHOOK_SECRETS)

  @streaming_credentials_fix """
  Set RINDLE_MUX_TOKEN_ID, RINDLE_MUX_TOKEN_SECRET, RINDLE_MUX_SIGNING_KEY_ID, RINDLE_MUX_SIGNING_PRIVATE_KEY, and RINDLE_MUX_WEBHOOK_SECRETS in your runtime config. See guides/streaming_providers.md for setup.
  """

  @streaming_signing_key_fix """
  Verify RINDLE_MUX_SIGNING_PRIVATE_KEY is a valid PEM-encoded RSA private key (re-download from Mux Dashboard -> Settings -> Signing Keys if unsure; Mux does not allow re-downloading the same key, so creating a fresh one is safest).
  """

  @streaming_webhook_secrets_fix """
  Set RINDLE_MUX_WEBHOOK_SECRETS to a comma-separated list of webhook secrets, each at least 32 characters. See Mux Dashboard -> Settings -> Webhooks.
  """

  @streaming_smoke_ping_fix """
  Pass --streaming to enable a live 5s smoke ping to Mux.Video.Assets.list/1. Re-run with `mix rindle.doctor --streaming` once credentials are configured.
  """

  @streaming_dep_missing_fix ~s(Add {:mux, "~> 3.2", optional: true} and {:jose, "~> 1.11", optional: true} to your deps.)

  @gcs_dep_missing_fix ~s(Add {:goth, "~> 1.4", optional: true}, {:finch, "~> 0.21", optional: true}, and {:gcs_signed_url, "~> 0.4.6", optional: true} to your deps and run mix deps.get.)

  @gcs_goth_fix """
  Add {Goth, name: MyApp.Goth, source: {:service_account, creds}} to your supervision tree, then set config :rindle, Rindle.Storage.GCS, goth: MyApp.Goth.
  """

  @gcs_bucket_fix """
  Verify config :rindle, Rindle.Storage.GCS, bucket: "my-bucket" matches a bucket your service account can access.
  """

  @gcs_signing_key_fix """
  Verify the signing_key config is either a decoded service-account JSON map (preferred) or a raw PEM string with `client_email:` configured separately. File-path loading is not supported here; decode the service-account JSON at boot via `Jason.decode!(File.read!("path/to/key.json"))` and pass the resulting map.
  """

  @gcs_precondition_fix """
  Start `MyApp.Finch` and `MyApp.Goth` in your application supervision tree, then set config :rindle, Rindle.Storage.GCS, finch: MyApp.Finch, goth: MyApp.Goth.
  """

  @gcs_resumable_cors_fix """
  Configure bucket CORS for your app origins with `PUT` and `PATCH`, and allow `Content-Range` plus `x-goog-resumable` in the browser-facing response/header policy. Keep `session_uri` secret because it is a bearer credential, expect resumable sessions to expire within one week, and treat region pinning as normal when you choose the bucket location.
  """

  @type check_status :: :ok | :warn | :error
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

    migration_statuses =
      Keyword.get_lazy(opts, :migration_statuses, fn -> migration_statuses(opts) end)

    resumable_session_schema_catalog =
      Keyword.get_lazy(opts, :resumable_session_schema_catalog, fn ->
        resumable_session_schema_catalog()
      end)

    gcs_extra =
      if gcs_profiles(profiles) != [] do
        base_checks = [
          # Phase 37 / D-13 — GCS adapter health checks. Conditionally appended
          # so image-only S3 adopters see no new doctor noise (WARNING 3 lock —
          # not even silent OK rows). Resumable-specific CORS check defers to
          # Phase 41 RESUMABLE-13.
          fn -> check_gcs_goth_running(profiles, env) end,
          fn -> check_gcs_bucket_reachable(profiles, env) end,
          fn -> check_gcs_signing_key(profiles, env) end
        ]

        if resumable_gcs_profiles(profiles) != [] do
          base_checks ++ [fn -> check_gcs_resumable_cors(profiles, opts) end]
        else
          base_checks
        end
      else
        []
      end

    checks =
      ([
         fn -> check_delivery_support(profiles) end,
         fn -> check_ffmpeg_runtime(probe) end,
         fn -> check_local_playback(profiles, local_playback_route) end,
         fn -> check_migration_pending(migration_statuses) end,
         fn -> check_migration_unresolved(migration_statuses) end,
         fn -> check_resumable_session_schema(resumable_session_schema_catalog) end,
         fn -> check_oban_default_instance(oban_config) end,
         fn -> check_oban_required_queues(profiles, oban_config) end,
         fn -> check_profile_runtime_fit(resolved, env) end,
         fn -> check_streaming_credentials(profiles, env) end,
         fn -> check_streaming_signing_key(profiles, env) end,
         fn -> check_streaming_webhook_secrets(profiles, env) end,
         fn -> check_streaming_smoke_ping(profiles, env, opts) end
       ] ++ gcs_extra)
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

  defp check_resumable_session_schema({:error, reason}) do
    error_result(
      "doctor.resumable_session_schema",
      :migrations,
      "Could not inspect media_upload_sessions resumable schema: #{Exception.message(normalize_exception(reason))}.",
      "Verify the configured Rindle repo can query information_schema and pg_indexes, then re-run `mix rindle.doctor`."
    )
  end

  defp check_resumable_session_schema(%{columns: columns, indexes: indexes}) do
    missing_columns =
      ["session_uri", "session_uri_expires_at", "last_known_offset", "region_hint"] --
        Map.keys(columns)

    issues = []
    issues = append_missing_columns_issue(issues, missing_columns)
    issues = append_offset_issue(issues, columns)
    issues = append_index_issue(issues, indexes)

    if issues == [] do
      ok_result(
        "doctor.resumable_session_schema",
        :migrations,
        "All resumable session columns and the expiry index are present on media_upload_sessions.",
        "Keep the packaged resumable migration applied on the adopter-owned media_upload_sessions table."
      )
    else
      error_result(
        "doctor.resumable_session_schema",
        :migrations,
        Enum.join(issues, "; ") <> ".",
        "Re-run the packaged resumable migration so media_upload_sessions regains the locked resumable columns, NOT NULL DEFAULT 0 offset posture, and filtered expiry index."
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

    case Migrator.with_repo(
           repo,
           fn started_repo ->
             Migrator.migrations(started_repo, path)
           end,
           mode: :temporary
         ) do
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

  defp resumable_session_schema_catalog do
    case Migrator.with_repo(
           Config.repo(),
           fn started_repo ->
             with {:ok, %{rows: column_rows}} <-
                    started_repo.query(
                      """
                      SELECT column_name, is_nullable, column_default
                      FROM information_schema.columns
                      WHERE table_schema = 'public' AND table_name = 'media_upload_sessions'
                        AND column_name IN ('session_uri', 'session_uri_expires_at', 'last_known_offset', 'region_hint')
                      """,
                      []
                    ),
                  {:ok, %{rows: index_rows}} <-
                    started_repo.query(
                      """
                      SELECT indexdef
                      FROM pg_indexes
                      WHERE schemaname = 'public' AND tablename = 'media_upload_sessions'
                      """,
                      []
                    ) do
               %{
                 columns:
                   Map.new(column_rows, fn [name, is_nullable, column_default] ->
                     {name, %{is_nullable: is_nullable, column_default: column_default}}
                   end),
                 indexes: Enum.map(index_rows, fn [indexdef] -> indexdef end)
               }
             end
           end,
           mode: :temporary
         ) do
      {:ok, catalog, _apps} -> catalog
      {:error, reason} -> {:error, reason}
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

  defp required_queues(profiles) do
    queues =
      if Enum.any?(profiles, &profile_has_av_variants?/1) do
        @base_queues ++ [:rindle_media]
      else
        @base_queues
      end

    # Phase 36 WR-03: streaming-enabled profiles must declare
    # `:rindle_provider` (the queue MuxSyncCoordinator and MuxIngestVariant
    # workers enqueue onto). The streaming guide instructs adopters to
    # configure `queues: [rindle_provider: 4]`, but the doctor check
    # previously did not enforce it — adopters who mistyped the queue
    # name got a green doctor while their Mux ingestion silently failed.
    queues =
      if Rindle.Capability.configured_streaming_profiles(profiles) == [] do
        queues
      else
        queues ++ [:rindle_provider]
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

  defp append_missing_columns_issue(issues, []), do: issues

  defp append_missing_columns_issue(issues, missing_columns) do
    ["missing columns: #{Enum.join(missing_columns, ", ")}" | issues]
  end

  defp append_offset_issue(issues, columns) do
    case Map.get(columns, "last_known_offset") do
      %{is_nullable: "NO", column_default: default} when is_binary(default) ->
        if String.contains?(default, "0") do
          issues
        else
          ["last_known_offset must be NOT NULL DEFAULT 0" | issues]
        end

      _other ->
        ["last_known_offset must be NOT NULL DEFAULT 0" | issues]
    end
  end

  defp append_index_issue(issues, indexes) do
    if resumable_expiry_index_present?(indexes) do
      issues
    else
      [
        "missing resumable expiry index on session_uri_expires_at for upload_strategy = 'resumable'"
        | issues
      ]
    end
  end

  defp resumable_expiry_index_present?(indexes) do
    Enum.any?(indexes, fn indexdef ->
      normalized = String.downcase(indexdef)

      String.contains?(normalized, "session_uri_expires_at") and
        String.contains?(normalized, "upload_strategy") and
        String.contains?(normalized, "resumable")
    end)
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

  # --- streaming checks (Phase 36 / MUX-16) ---

  defp streaming_profiles(profiles) do
    Rindle.Capability.configured_streaming_profiles(profiles)
  end

  defp check_streaming_credentials(profiles, env) do
    cond do
      streaming_profiles(profiles) == [] ->
        ok_result(
          "doctor.streaming_credentials",
          :streaming,
          "No streaming-enabled profiles discovered.",
          @streaming_credentials_fix
        )

      not Code.ensure_loaded?(Mux.Video.Assets) ->
        error_result(
          "doctor.streaming_credentials",
          :streaming,
          "Streaming-enabled profile detected but :mux dep is not loaded.",
          @streaming_dep_missing_fix
        )

      true ->
        case missing_streaming_credentials(env) do
          [] ->
            ok_result(
              "doctor.streaming_credentials",
              :streaming,
              "All five RINDLE_MUX_* credentials are set.",
              @streaming_credentials_fix
            )

          missing ->
            error_result(
              "doctor.streaming_credentials",
              :streaming,
              "Missing RINDLE_MUX_* credentials: #{Enum.join(missing, ", ")}.",
              @streaming_credentials_fix
            )
        end
    end
  end

  defp missing_streaming_credentials(env) do
    Enum.filter(@streaming_required_env_vars, fn name ->
      case Map.get(env, name) do
        nil -> true
        "" -> true
        _ -> false
      end
    end)
  end

  defp check_streaming_signing_key(profiles, env) do
    cond do
      streaming_profiles(profiles) == [] ->
        ok_result(
          "doctor.streaming_signing_key",
          :streaming,
          "No streaming-enabled profiles discovered.",
          @streaming_signing_key_fix
        )

      not Code.ensure_loaded?(JOSE.JWK) ->
        error_result(
          "doctor.streaming_signing_key",
          :streaming,
          "Streaming-enabled profile detected but :jose dep is not loaded.",
          @streaming_dep_missing_fix
        )

      true ->
        case Map.get(env, "RINDLE_MUX_SIGNING_PRIVATE_KEY", "") do
          "" ->
            error_result(
              "doctor.streaming_signing_key",
              :streaming,
              "RINDLE_MUX_SIGNING_PRIVATE_KEY is not set.",
              @streaming_signing_key_fix
            )

          value ->
            verify_signing_key_pem(value)
        end
    end
  end

  # Pitfall 1: JOSE.JWK.from_pem/1 returns `[]` (NOT raises) on malformed PEM.
  # MUST pattern-match against %JOSE.JWK{}, not just truthy. We also rescue
  # exceptions defensively in case a future jose version changes behavior.
  defp verify_signing_key_pem(value) do
    case JOSE.JWK.from_pem(value) do
      %{__struct__: JOSE.JWK} ->
        ok_result(
          "doctor.streaming_signing_key",
          :streaming,
          "RINDLE_MUX_SIGNING_PRIVATE_KEY parses as a valid JOSE JWK.",
          @streaming_signing_key_fix
        )

      _other ->
        error_result(
          "doctor.streaming_signing_key",
          :streaming,
          "RINDLE_MUX_SIGNING_PRIVATE_KEY did not parse as a JOSE JWK (malformed PEM).",
          @streaming_signing_key_fix
        )
    end
  rescue
    exception ->
      # Phase 36 WR-10: surface the exception class (NOT the message — the
      # message could echo PEM content). The struct name is non-sensitive
      # and unlocks "is it MatchError or FunctionClauseError?" diagnosis
      # for `mix rindle.doctor --raise` without leaking key material.
      error_result(
        "doctor.streaming_signing_key",
        :streaming,
        "RINDLE_MUX_SIGNING_PRIVATE_KEY parse raised: " <>
          inspect(exception.__struct__) <> " (malformed PEM).",
        @streaming_signing_key_fix
      )
  end

  defp check_streaming_webhook_secrets(profiles, env) do
    cond do
      streaming_profiles(profiles) == [] ->
        ok_result(
          "doctor.streaming_webhook_secrets",
          :streaming,
          "No streaming-enabled profiles discovered.",
          @streaming_webhook_secrets_fix
        )

      true ->
        raw = Map.get(env, "RINDLE_MUX_WEBHOOK_SECRETS", "")
        secrets = raw |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

        cond do
          secrets == [] ->
            error_result(
              "doctor.streaming_webhook_secrets",
              :streaming,
              "RINDLE_MUX_WEBHOOK_SECRETS is empty.",
              @streaming_webhook_secrets_fix
            )

          Enum.any?(secrets, &(String.length(&1) < 32)) ->
            error_result(
              "doctor.streaming_webhook_secrets",
              :streaming,
              "At least one RINDLE_MUX_WEBHOOK_SECRETS entry is shorter than the 32-character Mux minimum.",
              @streaming_webhook_secrets_fix
            )

          true ->
            ok_result(
              "doctor.streaming_webhook_secrets",
              :streaming,
              "RINDLE_MUX_WEBHOOK_SECRETS has #{length(secrets)} secret(s), all >= 32 chars.",
              @streaming_webhook_secrets_fix
            )
        end
    end
  end

  defp check_streaming_smoke_ping(profiles, _env, opts) do
    streaming? = Keyword.get(opts, :streaming, false)

    cond do
      streaming_profiles(profiles) == [] ->
        ok_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "No streaming-enabled profiles discovered.",
          @streaming_smoke_ping_fix
        )

      not streaming? ->
        ok_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Smoke ping skipped (pass --streaming to enable live API check).",
          @streaming_smoke_ping_fix
        )

      not Code.ensure_loaded?(Mux.Video.Assets) ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Streaming-enabled profile detected but :mux dep is not loaded.",
          @streaming_dep_missing_fix
        )

      true ->
        run_smoke_ping_with_timeout()
    end
  end

  # Hard 5s wall-clock ceiling via Task.yield + Task.shutdown(:brutal_kill)
  # (RESEARCH "Don't hand-roll" — defer to OTP). The task body returns the
  # raw {:ok, _, _} | {:error, _, _} shape from Mux.Video.Assets.list/2, with
  # exceptions and exits captured into uniform tuples for the case below.
  defp run_smoke_ping_with_timeout do
    task =
      Task.async(fn ->
        try do
          cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
          token_id = Keyword.get(cfg, :token_id)
          token_secret = Keyword.get(cfg, :token_secret)

          if is_binary(token_id) and is_binary(token_secret) do
            client = Mux.Base.new(token_id, token_secret)
            Mux.Video.Assets.list(client, %{limit: 1})
          else
            {:error, :no_credentials}
          end
        rescue
          e -> {:rescue, e}
        catch
          kind, reason -> {:catch, kind, reason}
        end
      end)

    case Task.yield(task, 5_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, _list, _env}} ->
        ok_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux.Video.Assets.list/1 returned 200 (smoke ping OK).",
          @streaming_smoke_ping_fix
        )

      {:ok, {:error, _msg, %{status: status}}} when status in [401, 403] ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping returned #{status}.",
          "Verify RINDLE_MUX_TOKEN_ID and RINDLE_MUX_TOKEN_SECRET in your runtime config."
        )

      {:ok, {:error, _msg, %{status: 429}}} ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping returned 429.",
          "Mux rate-limited the smoke ping; retry in a few seconds."
        )

      {:ok, {:error, _msg, %{status: status}}} ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping returned status #{status}.",
          @streaming_smoke_ping_fix
        )

      {:ok, {:error, :no_credentials}} ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping skipped: RINDLE_MUX_TOKEN_ID / RINDLE_MUX_TOKEN_SECRET are not configured.",
          @streaming_credentials_fix
        )

      nil ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping timed out after 5s.",
          "Could not reach api.mux.com within 5s; check network / proxy / DNS."
        )

      {:ok, _other} ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping returned an unexpected shape.",
          @streaming_smoke_ping_fix
        )
    end
  end

  # --- GCS checks (Phase 37 / D-13) ---

  # WARNING 4 fix — single-line delegator mirroring streaming_profiles/1 at lines
  # 522-524. Single source of truth for profile filtering lives in
  # Rindle.Capability.configured_gcs_profiles/1.
  defp gcs_profiles(profiles) do
    Rindle.Capability.configured_gcs_profiles(profiles)
  end

  defp resumable_gcs_profiles(profiles) do
    Enum.filter(gcs_profiles(profiles), fn profile ->
      case profile.storage_adapter() do
        adapter when is_atom(adapter) ->
          function_exported?(adapter, :capabilities, 0) and
            :resumable_upload_session in adapter.capabilities()

        _other ->
          false
      end
    end)
  end

  # Two-branch cond — the profile-aware short-circuit moved to the splice site
  # in run/2 per WARNING 3.
  defp check_gcs_goth_running(_profiles, _env) do
    cond do
      not Code.ensure_loaded?(Goth) ->
        error_result(
          "doctor.gcs_goth_running",
          :gcs,
          "GCS-enabled profile detected but :goth dep is not loaded.",
          @gcs_dep_missing_fix
        )

      true ->
        goth_name = Application.get_env(:rindle, Rindle.Storage.GCS, [])[:goth]

        case fetch_gcs_goth_token(goth_name) do
          :ok ->
            ok_result(
              "doctor.gcs_goth_running",
              :gcs,
              "Goth instance #{inspect(goth_name)} is running and minting tokens.",
              @gcs_goth_fix
            )

          {:error, :no_goth_configured} ->
            error_result(
              "doctor.gcs_goth_running",
              :gcs,
              "config :rindle, Rindle.Storage.GCS, goth: ... is not set.",
              @gcs_goth_fix
            )

          {:error, reason} ->
            error_result(
              "doctor.gcs_goth_running",
              :gcs,
              "Goth instance #{inspect(goth_name)} is not minting tokens: #{inspect(reason)}.",
              @gcs_goth_fix
            )
        end
    end
  end

  defp fetch_gcs_goth_token(nil), do: {:error, :no_goth_configured}

  defp fetch_gcs_goth_token(name) do
    # RESEARCH Pitfall 6: Goth.fetch/1 raises ArgumentError when the named
    # instance is not in the supervision tree (NOT `:exit, :noproc`). The
    # load-bearing trap is `rescue ArgumentError`. The `catch :exit, _reason`
    # branch is retained as defense-in-depth for older Goth versions or
    # unexpected exit propagation but is NOT the primary trap.
    try do
      case Goth.fetch(name) do
        {:ok, _token} -> :ok
        {:error, exception} when is_struct(exception) -> {:error, exception.__struct__}
        {:error, reason} -> {:error, reason}
      end
    rescue
      ArgumentError -> {:error, :argument_error}
    catch
      :exit, _reason -> {:error, :noproc}
    end
  end

  defp check_gcs_bucket_reachable(_profiles, _env) do
    cond do
      not Code.ensure_loaded?(Finch) ->
        error_result(
          "doctor.gcs_bucket_reachable",
          :gcs,
          "GCS-enabled profile detected but :finch dep is not loaded.",
          @gcs_dep_missing_fix
        )

      true ->
        app_env = Application.get_env(:rindle, Rindle.Storage.GCS, [])

        case app_env[:bucket] do
          nil ->
            error_result(
              "doctor.gcs_bucket_reachable",
              :gcs,
              "config :rindle, Rindle.Storage.GCS, bucket: \"...\" is not set.",
              @gcs_bucket_fix
            )

          bucket ->
            finch_name = app_env[:finch]
            goth_name = app_env[:goth]
            base_url = app_env[:base_url]
            token = app_env[:token]

            opts =
              []
              |> then(fn acc -> if base_url, do: [{:base_url, base_url} | acc], else: acc end)
              |> then(fn acc -> if token, do: [{:token, token} | acc], else: acc end)

            case probe_gcs_bucket(bucket, finch_name, goth_name, opts) do
              :ok ->
                ok_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "Bucket #{inspect(bucket)} is reachable (HTTP 200/403 from /storage/v1/b/$BUCKET).",
                  @gcs_bucket_fix
                )

              {:precondition_missing, which} ->
                error_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "GCS bucket reachability could not be probed (#{which}). Start Finch + Goth in your supervision tree and configure their names.",
                  @gcs_precondition_fix
                )

              {:bucket_missing, _status} ->
                error_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "GCS bucket #{inspect(bucket)} not found (404).",
                  @gcs_bucket_fix
                )

              {:unexpected_status, status} ->
                error_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "GCS API returned unexpected status #{status} for bucket #{inspect(bucket)}.",
                  @gcs_bucket_fix
                )

              {:probe_error, reason} ->
                # Security invariant: Finch.request errors are atoms / Mint
                # transport structs — never raw response bodies. Goth errors
                # surface as exception struct names. Bearer tokens NEVER
                # appear in `reason`.
                error_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "GCS bucket #{inspect(bucket)} probe failed: #{inspect(reason)}.",
                  @gcs_bucket_fix
                )
            end
        end
    end
  end

  # BLOCKER 2 — D-13 LOCK: real HTTP probe with explicit precondition guards.
  # Public (def) so Bypass-mocked unit tests can exercise it directly.
  # @doc false marks it as not part of the documented public API.
  @doc false
  def probe_gcs_bucket(bucket, finch_name, goth_name, opts \\ []) do
    cond do
      not Code.ensure_loaded?(Finch) ->
        {:precondition_missing, :finch_unavailable}

      finch_name == nil ->
        {:precondition_missing, :finch_not_configured}

      not Code.ensure_loaded?(Goth) ->
        {:precondition_missing, :goth_unavailable}

      goth_name == nil ->
        {:precondition_missing, :goth_not_configured}

      true ->
        do_probe(bucket, finch_name, goth_name, opts)
    end
  end

  # BLOCKER 2 — D-13 LOCK: actual HTTP request issuance. Public (def) for
  # testability; @doc false. `:base_url` opt allows Bypass redirection in unit
  # tests; `:token` opt is a test-only seam that bypasses Goth.fetch/1 (which
  # would otherwise call Google's real OAuth endpoint with the fake fixture
  # credentials and fail). Both seams mirror Plan 01's Client conventions.
  @doc false
  def do_probe(bucket, finch_name, goth_name, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "https://storage.googleapis.com")
    encoded_bucket = URI.encode(bucket)
    url = "#{base_url}/storage/v1/b/#{encoded_bucket}"

    with {:ok, token} <- probe_token(goth_name, opts),
         req = Finch.build(:get, url, [{"Authorization", "Bearer " <> token}]),
         {:ok, %Finch.Response{status: status}} <- Finch.request(req, finch_name) do
      case status do
        s when s in [200, 403] -> :ok
        404 -> {:bucket_missing, 404}
        s -> {:unexpected_status, s}
      end
    else
      {:error, reason} -> {:probe_error, reason}
    end
  catch
    :exit, reason -> {:probe_error, {:exit, reason}}
  end

  # `:token` opt is a test-only seam (mirrors Plan 01 Client `:token` opt) so
  # Bypass-mocked unit tests do not have to round-trip through Google's real
  # OAuth endpoint with fake fixture credentials. Production callers do not
  # set `:token` and the Goth path runs.
  defp probe_token(goth_name, opts) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) ->
        {:ok, token}

      _ ->
        case Goth.fetch(goth_name) do
          {:ok, %Goth.Token{token: token}} -> {:ok, token}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp check_gcs_signing_key(_profiles, _env) do
    cond do
      not Code.ensure_loaded?(GcsSignedUrl.Client) ->
        error_result(
          "doctor.gcs_signing_key",
          :gcs,
          "GCS-enabled profile detected but :gcs_signed_url dep is not loaded.",
          @gcs_dep_missing_fix
        )

      true ->
        case Application.get_env(:rindle, Rindle.Storage.GCS, [])[:signing_key] do
          nil ->
            error_result(
              "doctor.gcs_signing_key",
              :gcs,
              "config :rindle, Rindle.Storage.GCS, signing_key: ... is not set.",
              @gcs_signing_key_fix
            )

          signing_key ->
            verify_gcs_signing_key(signing_key)
        end
    end
  end

  # Pattern mirrors verify_signing_key_pem/1 at lines 612-643 (Phase 36 WR-10
  # security parity): emit only inspect(exception.__struct__), NEVER
  # Exception.message/1 — so PEM body / JSON content never echo into doctor
  # output even on failure.
  defp verify_gcs_signing_key(%{"private_key" => _, "client_email" => _} = json_map) do
    try do
      _client = GcsSignedUrl.Client.load(json_map)

      ok_result(
        "doctor.gcs_signing_key",
        :gcs,
        "GCS signing key parses as a valid service-account JSON map.",
        @gcs_signing_key_fix
      )
    rescue
      exception ->
        error_result(
          "doctor.gcs_signing_key",
          :gcs,
          "GCS signing_key parse raised: #{inspect(exception.__struct__)} (malformed service-account JSON).",
          @gcs_signing_key_fix
        )
    end
  end

  defp verify_gcs_signing_key(path) when is_binary(path) and byte_size(path) > 0 do
    cond do
      String.starts_with?(path, "-----BEGIN ") ->
        case Application.get_env(:rindle, Rindle.Storage.GCS, [])[:client_email] do
          client_email when is_binary(client_email) and client_email != "" ->
            ok_result(
              "doctor.gcs_signing_key",
              :gcs,
              "GCS signing key is a raw PEM string and client_email is configured separately.",
              @gcs_signing_key_fix
            )

          _missing ->
            error_result(
              "doctor.gcs_signing_key",
              :gcs,
              "GCS signing_key is a raw PEM string but config :rindle, Rindle.Storage.GCS, client_email: ... is not set.",
              @gcs_signing_key_fix
            )
        end

      true ->
        error_result(
          "doctor.gcs_signing_key",
          :gcs,
          "GCS signing_key is a non-PEM binary. Doctor and the signer accept only a decoded service-account JSON map, or a raw PEM string with client_email configured separately; file-path loading is not supported.",
          @gcs_signing_key_fix
        )
    end
  end

  # WARNING 5 fix — explicit is_map/1 guard. Map.get(other, :__struct__)
  # returns the struct module name for a struct map and nil for a bare map;
  # the `|| :map_without_struct` fallback handles bare maps cleanly. NO rescue
  # clause needed.
  defp verify_gcs_signing_key(other) when is_map(other) do
    error_result(
      "doctor.gcs_signing_key",
      :gcs,
      "GCS signing_key has unexpected shape: #{inspect(Map.get(other, :__struct__) || :map_without_struct)}.",
      @gcs_signing_key_fix
    )
  end

  # WARNING 5 fix — plain catchall for non-map / non-binary inputs (nil,
  # integers, lists, tuples). NO rescue needed.
  defp verify_gcs_signing_key(_other) do
    error_result(
      "doctor.gcs_signing_key",
      :gcs,
      "GCS signing_key has unexpected shape (not a map or binary).",
      @gcs_signing_key_fix
    )
  end

  defp check_gcs_resumable_cors(_profiles, opts) do
    app_env = Application.get_env(:rindle, Rindle.Storage.GCS, [])
    bucket = app_env[:bucket]
    finch_name = app_env[:finch]
    goth_name = app_env[:goth]

    cors_source =
      Keyword.get(opts, :gcs_bucket_cors) ||
        extract_bucket_cors(Keyword.get(opts, :gcs_bucket_metadata)) ||
        app_env[:bucket_cors] ||
        extract_bucket_cors(app_env[:bucket_metadata]) ||
        app_env[:cors]

    result =
      case cors_source do
        nil ->
          fetch_gcs_bucket_cors(bucket, finch_name, goth_name, app_env, opts)

        cors_rules ->
          {:ok, cors_rules}
      end

    build_gcs_resumable_cors_result(result)
  end

  defp build_gcs_resumable_cors_result({:ok, cors_rules}) do
    issues = gcs_resumable_cors_issues(cors_rules)

    if issues == [] do
      ok_result(
        "doctor.gcs_resumable_cors",
        :gcs,
        "Bucket CORS metadata includes app origins plus resumable browser requirements for `PUT`, `PATCH`, `Content-Range`, and `x-goog-resumable`.",
        @gcs_resumable_cors_fix
      )
    else
      warn_result(
        "doctor.gcs_resumable_cors",
        :gcs,
        "Bucket CORS metadata looks incomplete for browser resumable uploads: #{Enum.join(issues, "; ")}.",
        @gcs_resumable_cors_fix
      )
    end
  end

  defp build_gcs_resumable_cors_result({:error, reason}) do
    warn_result(
      "doctor.gcs_resumable_cors",
      :gcs,
      "Bucket CORS metadata could not be inspected automatically: #{format_gcs_cors_reason(reason)}.",
      @gcs_resumable_cors_fix
    )
  end

  defp fetch_gcs_bucket_cors(nil, _finch_name, _goth_name, _app_env, _opts),
    do: {:error, :bucket_not_configured}

  defp fetch_gcs_bucket_cors(bucket, finch_name, goth_name, app_env, opts) do
    cond do
      not Code.ensure_loaded?(Finch) ->
        {:error, :finch_unavailable}

      not Code.ensure_loaded?(Goth) ->
        {:error, :goth_unavailable}

      is_nil(finch_name) ->
        {:error, :finch_not_configured}

      is_nil(goth_name) ->
        {:error, :goth_not_configured}

      not Code.ensure_loaded?(Jason) ->
        {:error, :json_unavailable}

      true ->
        base_url =
          Keyword.get(opts, :gcs_bucket_base_url) || app_env[:base_url] ||
            "https://storage.googleapis.com"

        encoded_bucket = URI.encode(bucket)
        url = "#{base_url}/storage/v1/b/#{encoded_bucket}?fields=cors"

        with {:ok, token} <- probe_token(goth_name, opts),
             req = Finch.build(:get, url, [{"Authorization", "Bearer " <> token}]),
             {:ok, %Finch.Response{status: 200, body: body}} <- Finch.request(req, finch_name),
             {:ok, decoded} <- Jason.decode(body) do
          {:ok, extract_bucket_cors(decoded) || []}
        else
          {:ok, %Finch.Response{status: status}} when status in [403, 404] ->
            {:error, {:unexpected_status, status}}

          {:ok, %Finch.Response{status: status}} ->
            {:error, {:unexpected_status, status}}

          {:error, %Jason.DecodeError{} = error} ->
            {:error, {:decode_error, inspect(error.__struct__)}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp extract_bucket_cors(%{"cors" => cors}) when is_list(cors), do: cors
  defp extract_bucket_cors(%{cors: cors}) when is_list(cors), do: cors
  defp extract_bucket_cors(_other), do: nil

  defp gcs_resumable_cors_issues(cors_rules) when is_list(cors_rules) do
    rules =
      Enum.filter(cors_rules, fn
        rule when is_map(rule) -> true
        _other -> false
      end)

    []
    |> maybe_add_cors_issue(cors_origins_present?(rules), "missing app origins")
    |> maybe_add_cors_issue(
      cors_methods_present?(rules, ["put", "patch"]),
      "missing `PUT`/`PATCH`"
    )
    |> maybe_add_cors_issue(
      cors_headers_present?(rules, ["content-range", "x-goog-resumable"]),
      "missing `Content-Range`/`x-goog-resumable`"
    )
  end

  defp gcs_resumable_cors_issues(_other),
    do: ["bucket CORS metadata is not a list of rules"]

  defp maybe_add_cors_issue(issues, true, _message), do: issues
  defp maybe_add_cors_issue(issues, false, message), do: issues ++ [message]

  defp cors_origins_present?(rules) do
    Enum.any?(rules, fn rule ->
      rule
      |> cors_rule_values(["origin", :origin])
      |> Enum.any?(&(&1 != ""))
    end)
  end

  defp cors_methods_present?(rules, required) do
    Enum.any?(rules, fn rule ->
      values = cors_rule_values(rule, ["method", :method])
      wildcard_or_superset?(values, required)
    end)
  end

  defp cors_headers_present?(rules, required) do
    Enum.any?(rules, fn rule ->
      values = cors_rule_values(rule, ["responseHeader", :responseHeader, :response_header])
      wildcard_or_superset?(values, required)
    end)
  end

  defp wildcard_or_superset?(values, required) do
    normalized =
      values
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    MapSet.member?(normalized, "*") or
      Enum.all?(required, &MapSet.member?(normalized, &1))
  end

  defp cors_rule_values(rule, keys) do
    keys
    |> Enum.flat_map(fn key ->
      case Map.get(rule, key) do
        values when is_list(values) -> values
        value when is_binary(value) -> [value]
        _other -> []
      end
    end)
    |> Enum.map(&String.trim/1)
  end

  defp format_gcs_cors_reason({:unexpected_status, status}),
    do: "GCS bucket metadata returned status #{status}"

  defp format_gcs_cors_reason({:decode_error, detail}),
    do: "GCS bucket metadata returned unreadable JSON (#{detail})"

  defp format_gcs_cors_reason({:exit, reason}),
    do: "bucket metadata request exited: #{inspect(reason)}"

  defp format_gcs_cors_reason(reason), do: inspect(reason)

  defp ok_result(id, component, summary, fix) do
    %{id: id, status: :ok, component: component, summary: summary, fix: fix}
  end

  defp warn_result(id, component, summary, fix) do
    %{id: id, status: :warn, component: component, summary: summary, fix: fix}
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
