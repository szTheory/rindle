defmodule Rindle.Ops.RuntimeChecks.OwnershipChecks do
  @moduledoc false

  alias Rindle.Ops.OwnershipSnapshot

  @base_queues [:rindle_maintenance, :rindle_process, :rindle_promote, :rindle_purge]

  @doc false
  def schedule(
        migration_statuses,
        rindle_schema_catalog,
        resumable_session_schema_catalog,
        ownership_snapshot,
        _profiles,
        oban_config,
        streaming_profiles,
        %{av_profiles?: av_profiles?},
        schema_context
      ) do
    [
      fn ->
        check_migration_pending(migration_statuses, rindle_schema_catalog, schema_context)
      end,
      fn ->
        check_migration_unresolved(migration_statuses, rindle_schema_catalog, schema_context)
      end,
      fn -> check_resumable_session_schema(resumable_session_schema_catalog) end,
      fn -> check_rindle_schema_ready(ownership_snapshot.rindle) end,
      fn -> check_oban_default_instance(oban_config, schema_context.repo) end,
      fn -> check_oban_jobs_ready(ownership_snapshot.oban) end,
      fn -> check_oban_required_queues(av_profiles?, streaming_profiles, oban_config) end
    ]
  end

  defp check_oban_default_instance(nil, expected_repo) do
    error_result(
      "doctor.oban_default_instance",
      :oban,
      "No default `Oban` configuration was found for the current Mix app.",
      "Configure `config :your_app, Oban, repo: #{inspect(expected_repo)}, queues: [...]` and start `{Oban, Application.fetch_env!(:your_app, Oban)}` under the default `Oban` module path."
    )
  end

  defp check_oban_default_instance(oban_config, expected_repo) do
    configured_repo = Keyword.get(oban_config, :repo)

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

  defp check_oban_required_queues(av_profiles?, streaming_profiles, oban_config) do
    required = required_queues(av_profiles?, streaming_profiles)
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

  defp check_migration_pending(statuses, rindle_schema_catalog, schema_context) do
    pending =
      statuses
      |> Enum.filter(fn
        {:down, _version, _name} -> true
        _other -> false
      end)
      |> Enum.map(&migration_version/1)

    cond do
      pending == [] ->
        ok_result(
          "doctor.migrations.pending",
          :migrations,
          "No pending Rindle migrations were found.",
          "Keep Rindle migrations applied before running the runtime pipeline."
        )

      rindle_schema_ready?(rindle_schema_catalog, schema_context) and
          all_legacy_statuses_pending?(statuses) ->
        warn_result(
          "doctor.migrations.pending",
          :migrations,
          "Legacy Rindle migration history has pending entries, but the Rindle-owned schema catalog is ready.",
          "Treat legacy packaged migration history as historical compatibility when `Rindle.Migration` catalog readiness is current."
        )

      true ->
        error_result(
          "doctor.migrations.pending",
          :migrations,
          "Pending Rindle migrations: #{Enum.join(pending, ", ")}.",
          "Run `mix ecto.migrate` for the repo configured at `config :rindle, :repo` before retrying."
        )
    end
  end

  defp check_migration_unresolved(statuses, rindle_schema_catalog, schema_context) do
    unresolved =
      statuses
      |> Enum.filter(fn
        {:up, _version, "** FILE NOT FOUND **"} -> true
        _other -> false
      end)
      |> Enum.map(&migration_version/1)

    cond do
      unresolved == [] ->
        ok_result(
          "doctor.migrations.unresolved",
          :migrations,
          "No unresolved applied Rindle migrations were found.",
          "Keep local Rindle migration files in sync with the database history."
        )

      rindle_schema_ready?(rindle_schema_catalog, schema_context) and
          no_pending_migration_statuses?(statuses) ->
        warn_result(
          "doctor.migrations.unresolved",
          :migrations,
          "Legacy Rindle migration history has applied file-history drift, but the Rindle-owned schema catalog is ready.",
          "Keep the legacy migration history for compatibility; no destructive history rewrite is required."
        )

      true ->
        error_result(
          "doctor.migrations.unresolved",
          :migrations,
          "Applied Rindle migrations missing from local code: #{Enum.join(unresolved, ", ")}.",
          "Restore the migration files missing from local code, or reconcile the database history before running more Rindle migrations."
        )
    end
  end

  defp check_rindle_schema_ready(snapshot) do
    {status, summary} =
      case snapshot.classification do
        :ready ->
          {:ok,
           "Rindle.Migration catalog is ready in #{inspect(snapshot.expected_prefix)} at version 1."}

        :legacy_ready ->
          {:ok,
           "legacy packaged Rindle install is healthy; catalog readiness is complete in #{inspect(snapshot.expected_prefix)}."}

        :rindle_prefix_mismatch ->
          {:error,
           "Rindle-owned catalog expected #{snapshot.expected_prefix}, observed #{snapshot.observed_prefix}."}

        :inspection_failed ->
          {:error, "Could not inspect Rindle-owned schema readiness."}

        :incomplete ->
          {:error,
           "Rindle-owned schema is incomplete in #{inspect(snapshot.expected_prefix)}; missing tables: #{Enum.join(Map.get(snapshot, :missing_relations, []), ", ")}."}

        :marker_invalid ->
          {:error,
           "Rindle-owned schema marker is invalid in #{inspect(snapshot.expected_prefix)}."}
      end

    ownership_result("doctor.rindle_schema.ready", :migrations, status, summary, snapshot)
  end

  defp check_oban_jobs_ready(snapshot) do
    status = if snapshot.classification == :ready, do: :ok, else: :error

    summary =
      case {status, snapshot.classification} do
        {:ok, _classification} ->
          "Host-owned `oban_jobs` table is installed in #{inspect(snapshot.observed_prefix)}. Host owns Oban.Migration."

        {:error, :oban_binding_drift} ->
          "Default Oban binding drift: expected #{inspect(snapshot.expected_prefix)}, observed #{inspect(snapshot.observed_prefix)}."

        {:error, :oban_binding_unavailable} ->
          "Default Oban binding is unavailable or unsupported; no host catalog query ran."

        {:error, _classification} ->
          "Host-owned `oban_jobs` table is not ready in #{inspect(snapshot.expected_prefix)}."
      end

    ownership_result("doctor.oban_jobs.ready", :oban, status, summary, snapshot)
  end

  defp rindle_schema_ready?(%{} = catalog, schema_context) do
    expected_prefix = Map.get(catalog, :prefix, schema_context.expected_prefix)
    other_prefix = Enum.find(schema_context.supported_prefixes, &(&1 != expected_prefix))

    snapshot =
      OwnershipSnapshot.inspect(
        expected_prefix: expected_prefix,
        catalogs: %{expected_prefix => catalog, other_prefix => %{}},
        oban_binding: [repo: schema_context.repo],
        compatibility_oban_prefix: schema_context.oban_prefix,
        oban_jobs_catalog: %{exists?: true}
      )

    case check_rindle_schema_ready(snapshot.rindle) do
      {:runtime_check, :ok, _id, _component, _summary, _fix, _details} -> true
      _other -> false
    end
  end

  defp rindle_schema_ready?(_catalog, _schema_context), do: false

  defp all_legacy_statuses_pending?([]), do: false

  defp all_legacy_statuses_pending?(statuses) do
    Enum.all?(statuses, fn
      {:down, version, _name} when version > 0 -> true
      _other -> false
    end)
  end

  defp no_pending_migration_statuses?(statuses) do
    not Enum.any?(statuses, fn
      {:down, version, _name} when version > 0 -> true
      _other -> false
    end)
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

  defp required_queues(av_profiles?, streaming_profiles) do
    queues =
      if av_profiles? do
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
      if streaming_profiles == [] do
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

  defp migration_version({_state, -1, _name}), do: "migration inspection failed"
  defp migration_version({_state, version, _name}), do: Integer.to_string(version)

  defp ownership_result(id, component, status, summary, snapshot) do
    {:runtime_check, status, id, component, summary, snapshot.next_action, {:ownership, snapshot}}
  end

  defp ok_result(id, component, summary, fix) do
    {:runtime_check, :ok, id, component, summary, fix, %{}}
  end

  defp warn_result(id, component, summary, fix) do
    {:runtime_check, :warn, id, component, summary, fix, %{}}
  end

  defp error_result(id, component, summary, fix) do
    {:runtime_check, :error, id, component, summary, fix, %{}}
  end

  defp normalize_exception(%_{} = error), do: error
  defp normalize_exception(error), do: RuntimeError.exception(inspect(error))
end
