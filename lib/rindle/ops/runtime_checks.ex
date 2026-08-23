defmodule Rindle.Ops.RuntimeChecks do
  @moduledoc false

  alias Ecto.Migrator
  alias Rindle.Config
  alias Rindle.Migration.V1, as: MigrationV1
  alias Rindle.Ops.OwnershipSnapshot
  alias Rindle.Ops.RuntimeChecks.{CoreChecks, IntegrationChecks, OwnershipChecks}

  @migration_inspection_failure "migration inspection failed"

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
    mix_app = Keyword.get_lazy(opts, :mix_app, &Config.host_app/0)
    resolved = resolve_profiles(args, Keyword.get(opts, :profiles, Config.profile_modules()))
    profiles = resolved.profiles
    oban_config = Keyword.get(opts, :oban_config, Application.get_env(mix_app, Oban))
    local_playback_route = Keyword.get(opts, :local_playback_route, Config.local_playback_route())

    migration_statuses =
      Keyword.get_lazy(opts, :migration_statuses, fn -> migration_statuses(opts) end)

    rindle_schema_catalog =
      Keyword.get_lazy(opts, :rindle_schema_catalog, fn -> rindle_schema_catalog(opts) end)

    oban_jobs_catalog = Keyword.get(opts, :oban_jobs_catalog)

    ownership_snapshot =
      Keyword.get_lazy(opts, :ownership_snapshot, fn ->
        OwnershipSnapshot.inspect(
          rindle_schema_catalog: rindle_schema_catalog,
          oban_jobs_catalog: oban_jobs_catalog,
          mix_app: mix_app,
          oban_binding: Keyword.get(opts, :oban_binding, oban_config),
          compatibility_oban_prefix: Keyword.get(opts, :oban_prefix, Config.oban_prefix())
        )
      end)

    resumable_session_schema_catalog =
      Keyword.get_lazy(opts, :resumable_session_schema_catalog, fn ->
        resumable_session_schema_catalog()
      end)

    streaming_profiles = Rindle.Capability.configured_streaming_profiles(profiles)
    gcs_profiles = Rindle.Capability.configured_gcs_profiles(profiles)
    tus_profiles = Rindle.Capability.configured_tus_profiles(profiles)

    {core_checks, core_facts} =
      CoreChecks.schedule(profiles, probe, local_playback_route, resolved, env)

    schema_context = %{
      expected_prefix: Config.rindle_prefix(),
      supported_prefixes: Rindle.Schema.supported_prefixes(),
      repo: Config.repo(),
      oban_prefix: Config.oban_prefix()
    }

    ownership_checks =
      OwnershipChecks.schedule(
        migration_statuses,
        rindle_schema_catalog,
        resumable_session_schema_catalog,
        ownership_snapshot,
        profiles,
        oban_config,
        streaming_profiles,
        core_facts,
        schema_context
      )

    integration_checks =
      IntegrationChecks.schedule(
        %{streaming: streaming_profiles, gcs: gcs_profiles, tus: tus_profiles},
        env,
        opts,
        %{
          gcs_config: fn -> Application.get_env(:rindle, Rindle.Storage.GCS, []) end,
          mux_config: fn ->
            Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
          end
        }
      )

    checks =
      (core_checks ++ ownership_checks ++ integration_checks)
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
    result = fun.() |> build_result()

    :telemetry.execute(
      [:rindle, :runtime, :check, :stop],
      %{duration_us: elapsed_us(started_at)},
      %{check: result.id, status: result.status, component: result.component}
    )

    result
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

      {:error, _reason} ->
        [{:down, -1, @migration_inspection_failure}]
    end
  rescue
    _error ->
      [{:down, -1, @migration_inspection_failure}]
  end

  defp rindle_schema_catalog(opts) do
    prefix = Keyword.get(opts, :prefix, Config.rindle_prefix())
    requirements = MigrationV1.catalog_requirements()
    rindle_tables = MigrationV1.rindle_tables()
    marker_table = MigrationV1.marker_table()
    inspected_tables = rindle_tables ++ [marker_table]

    with_catalog_repo(fn started_repo ->
      with {:ok, %{rows: table_rows}} <-
             started_repo.query(
               """
               SELECT table_name
               FROM information_schema.tables
               WHERE table_schema = $1
                 AND table_name = ANY($2::text[])
               """,
               [prefix, inspected_tables]
             ) do
        present_tables = Enum.map(table_rows, fn [table_name] -> table_name end)
        marker_versions = marker_versions(started_repo, prefix, marker_table, present_tables)
        missing_tables = Map.fetch!(requirements, :tables) -- present_tables

        %{
          marker_versions: marker_versions,
          tables: present_tables -- [marker_table],
          missing_tables: missing_tables,
          legacy_packaged_install?: marker_versions == [] and missing_tables == [],
          prefix: prefix
        }
      end
    end)
  end

  defp marker_versions(repo, prefix, marker_table, present_tables) do
    if marker_table in present_tables do
      sql = """
      SELECT version
      FROM #{qualified_table(prefix, marker_table)}
      ORDER BY version
      """

      case repo.query(sql, []) do
        {:ok, %{rows: rows}} -> Enum.map(rows, fn [version] -> version end)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  defp with_catalog_repo(fun) do
    repo = Config.repo()

    cond do
      Process.whereis(repo) && sandbox_repo?(repo) ->
        with_existing_or_checked_out_sandbox(repo, fun)

      Process.whereis(repo) ->
        fun.(repo)

      true ->
        case Migrator.with_repo(repo, fun, mode: :temporary) do
          {:ok, result, _apps} -> result
          {:error, reason} -> {:error, reason}
        end
    end
  rescue
    error -> {:error, error}
  end

  defp with_existing_or_checked_out_sandbox(repo, fun) do
    fun.(repo)
  rescue
    _error in DBConnection.OwnershipError ->
      with_sandbox_checkout(repo, fun)
  end

  defp with_sandbox_checkout(repo, fun) do
    case Ecto.Adapters.SQL.Sandbox.checkout(repo) do
      :ok ->
        try do
          fun.(repo)
        after
          Ecto.Adapters.SQL.Sandbox.checkin(repo)
        end

      {:already, _owner_or_allowed} ->
        fun.(repo)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sandbox_repo?(repo) do
    Keyword.get(repo.config(), :pool) == Ecto.Adapters.SQL.Sandbox
  end

  defp resumable_session_schema_catalog do
    prefix = Config.rindle_prefix()

    with_catalog_repo(fn started_repo ->
      with {:ok, %{rows: column_rows}} <-
             started_repo.query(
               """
               SELECT column_name, is_nullable, column_default
               FROM information_schema.columns
               WHERE table_schema = $1 AND table_name = 'media_upload_sessions'
                 AND column_name IN ('session_uri', 'session_uri_expires_at', 'last_known_offset', 'region_hint')
               """,
               [prefix]
             ),
           {:ok, %{rows: index_rows}} <-
             started_repo.query(
               """
               SELECT indexdef
               FROM pg_indexes
               WHERE schemaname = $1 AND tablename = 'media_upload_sessions'
               """,
               [prefix]
             ) do
        %{
          columns:
            Map.new(column_rows, fn [name, is_nullable, column_default] ->
              {name, %{is_nullable: is_nullable, column_default: column_default}}
            end),
          indexes: Enum.map(index_rows, fn [indexdef] -> indexdef end)
        }
      end
    end)
  end

  defp qualified_table(prefix, table), do: "#{quote_ident(prefix)}.#{quote_ident(table)}"

  defp quote_ident(identifier) do
    escaped =
      identifier
      |> to_string()
      |> String.replace(~s("), ~s(""))

    ~s("#{escaped}")
  end

  defp module_from_string(name) do
    name
    |> String.split(".")
    |> Module.concat()
  end

  @doc false
  def probe_gcs_bucket(bucket, finch_name, goth_name, opts \\ []),
    do: IntegrationChecks.probe_gcs_bucket(bucket, finch_name, goth_name, opts)

  @doc false
  def do_probe(bucket, finch_name, goth_name, opts \\ []),
    do: IntegrationChecks.do_probe(bucket, finch_name, goth_name, opts)

  defp build_result({:runtime_check, status, id, component, summary, fix, details}) do
    Map.merge(
      %{id: id, status: status, component: component, summary: summary, fix: fix},
      result_details(details)
    )
  end

  defp result_details(%{} = details), do: details

  defp result_details({:ownership, snapshot}) do
    %{
      expected_prefix: snapshot.expected_prefix,
      observed_prefix: snapshot.observed_prefix,
      owner: snapshot.owner,
      classification: snapshot.classification,
      next_action: snapshot.next_action,
      ownership_boundary:
        "Rindle never creates, moves, drops, or prefixes `oban_jobs` or host `schema_migrations`."
    }
  end

  defp elapsed_us(started_at) do
    System.convert_time_unit(System.monotonic_time() - started_at, :native, :microsecond)
  end
end
