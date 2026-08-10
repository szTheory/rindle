defmodule Rindle.Ops.OwnershipSnapshot do
  @moduledoc false

  alias Rindle.Config
  alias Rindle.Migration.V1, as: MigrationV1
  alias Rindle.Schema

  @type classification ::
          :ready
          | :legacy_ready
          | :rindle_prefix_mismatch
          | :incomplete
          | :marker_invalid
          | :inspection_failed

  @doc false
  @spec inspect(keyword()) :: %{rindle: map(), oban: map()}
  def inspect(opts \\ []) do
    expected_prefix = Keyword.get(opts, :expected_prefix, Schema.prefix())
    other_prefix = other_prefix!(expected_prefix)

    catalogs = Keyword.get(opts, :catalogs)

    expected_catalog = catalog_for(expected_prefix, catalogs, opts)
    other_catalog = catalog_for(other_prefix, catalogs, opts)

    %{
      rindle: classify_rindle(expected_prefix, other_prefix, expected_catalog, other_catalog),
      oban: classify_oban(Keyword.get(opts, :oban_jobs_catalog), opts)
    }
  rescue
    _error ->
      %{
        rindle: inspection_failed_rindle(Schema.prefix()),
        oban: inspection_failed_oban(Keyword.get(opts, :oban_prefix, Config.oban_prefix()))
      }
  end

  defp catalog_for(prefix, catalogs, _opts) when is_map(catalogs),
    do: normalize_catalog(Map.get(catalogs, prefix), prefix)

  defp catalog_for(prefix, _catalogs, opts) do
    case Keyword.fetch(opts, :rindle_schema_catalog) do
      {:ok, %{prefix: ^prefix} = catalog} -> normalize_catalog(catalog, prefix)
      {:ok, _catalog} -> normalize_catalog(nil, prefix)
      :error -> read_catalog(prefix)
    end
  end

  defp normalize_catalog(nil, _prefix),
    do: %{relations: [], marker_versions: [], legacy_packaged_install?: false}

  defp normalize_catalog(catalog, prefix) do
    relations =
      Map.get(catalog, :relations, Map.get(catalog, :tables, []) ++ marker_relation(catalog))

    %{
      relations: Enum.sort(relations),
      marker_versions: Map.get(catalog, :marker_versions, []),
      legacy_packaged_install?: Map.get(catalog, :legacy_packaged_install?, false),
      prefix: prefix
    }
  end

  defp marker_relation(%{marker_versions: versions}) when versions != [],
    do: [MigrationV1.marker_table()]

  defp marker_relation(%{legacy_packaged_install?: true}), do: [MigrationV1.marker_table()]

  defp marker_relation(_catalog), do: []

  defp read_catalog(prefix) do
    with :ok <- validate_prefix(prefix),
         {:ok, %{rows: rows}} <- query_catalog(prefix) do
      relations = Enum.map(rows, &hd/1)

      marker_versions =
        if MigrationV1.marker_table() in relations do
          read_marker_versions(prefix)
        else
          []
        end

      %{
        relations: relations,
        marker_versions: marker_versions,
        legacy_packaged_install?: false,
        prefix: prefix
      }
    else
      _error -> :inspection_failed
    end
  end

  defp query_catalog(prefix) do
    with_repo(fn repo ->
      repo.query(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = $1
          AND table_name = ANY($2::text[])
        """,
        [prefix, MigrationV1.owned_relations()]
      )
    end)
  end

  defp read_marker_versions(prefix) do
    with :ok <- validate_prefix(prefix),
         {:ok, %{rows: rows}} <-
           with_repo(fn repo ->
             repo.query("SELECT version FROM #{qualified_marker(prefix)} ORDER BY version", [])
           end) do
      Enum.map(rows, &hd/1)
    else
      _error -> :invalid_marker
    end
  end

  defp classify_rindle(expected_prefix, _other_prefix, :inspection_failed, _other),
    do: inspection_failed_rindle(expected_prefix)

  defp classify_rindle(expected_prefix, _other_prefix, _expected, :inspection_failed),
    do: inspection_failed_rindle(expected_prefix)

  defp classify_rindle(expected_prefix, other_prefix, expected, other) do
    cond do
      complete?(expected) and valid_marker?(expected) ->
        rindle_data(expected_prefix, expected_prefix, :ready)

      complete?(expected) and expected.legacy_packaged_install? ->
        rindle_data(expected_prefix, expected_prefix, :legacy_ready)

      not complete?(expected) and complete?(other) and valid_marker?(other) ->
        rindle_data(expected_prefix, other_prefix, :rindle_prefix_mismatch)

      not complete?(expected) ->
        rindle_data(expected_prefix, nil, :incomplete)
        |> Map.put(:missing_relations, missing_relations(expected))

      true ->
        rindle_data(expected_prefix, nil, :marker_invalid)
    end
  end

  defp classify_oban(%{exists?: exists?} = catalog, opts) do
    prefix = Map.get(catalog, :prefix, Keyword.get(opts, :oban_prefix, Config.oban_prefix()))

    %{
      expected_prefix: prefix,
      observed_prefix: if(exists?, do: prefix, else: nil),
      owner: :host,
      classification: if(exists?, do: :ready, else: :incomplete),
      next_action: "Host owns Oban.Migration for oban_jobs. Rindle no longer manages `oban_jobs`."
    }
  end

  defp classify_oban({:error, _reason}, opts),
    do: inspection_failed_oban(Keyword.get(opts, :oban_prefix, Config.oban_prefix()))

  defp classify_oban(_catalog, opts),
    do: inspection_failed_oban(Keyword.get(opts, :oban_prefix, Config.oban_prefix()))

  defp rindle_data(expected_prefix, observed_prefix, classification) do
    %{
      expected_prefix: expected_prefix,
      observed_prefix: observed_prefix,
      owner: :rindle,
      classification: classification,
      next_action: rindle_next_action(classification)
    }
  end

  defp rindle_next_action(:rindle_prefix_mismatch),
    do: "Schedule the host-owned maintenance-window move, then deploy the matching Rindle prefix."

  defp rindle_next_action(:incomplete),
    do:
      "Add a host migration that calls `Rindle.Migration.up(version: 1)` and run `mix ecto.migrate` before retrying."

  defp rindle_next_action(:legacy_ready),
    do:
      "Existing legacy migration history can remain in place; use `Rindle.Migration` for fresh installs going forward."

  defp rindle_next_action(:ready),
    do:
      "Keep host migrations pinned to `Rindle.Migration.up(version: 1)` for deterministic installs."

  defp rindle_next_action(_classification),
    do:
      "Verify the configured Rindle repo can inspect the fixed Rindle catalog, then re-run `mix rindle.doctor`."

  defp inspection_failed_rindle(expected_prefix),
    do: rindle_data(expected_prefix, nil, :inspection_failed)

  defp inspection_failed_oban(prefix) do
    %{
      expected_prefix: prefix,
      observed_prefix: nil,
      owner: :host,
      classification: :inspection_failed,
      next_action: "Host owns Oban.Migration for oban_jobs. Rindle no longer manages `oban_jobs`."
    }
  end

  defp complete?(%{relations: relations}),
    do: Enum.sort(relations) == Enum.sort(MigrationV1.owned_relations())

  defp missing_relations(%{relations: relations}), do: MigrationV1.owned_relations() -- relations

  defp valid_marker?(%{marker_versions: versions}),
    do: versions == [MigrationV1.current_version()]

  defp other_prefix!(prefix) do
    case Schema.supported_prefixes() -- [prefix] do
      [other_prefix] -> other_prefix
      _other -> raise ArgumentError, "unsupported Rindle prefix"
    end
  end

  defp validate_prefix(prefix) do
    if prefix in Schema.supported_prefixes(), do: :ok, else: {:error, :unsupported_prefix}
  end

  defp qualified_marker(prefix) do
    ~s("#{prefix}"."#{MigrationV1.marker_table()}")
  end

  defp with_repo(fun) do
    repo = Config.repo()

    if Process.whereis(repo) and Keyword.get(repo.config(), :pool) == Ecto.Adapters.SQL.Sandbox do
      with_sandbox_checkout(repo, fun)
    else
      if Process.whereis(repo) do
        fun.(repo)
      else
        Ecto.Migrator.with_repo(repo, fun, mode: :temporary)
        |> case do
          {:ok, result, _apps} -> result
          {:error, _reason} -> {:error, :catalog_unavailable}
        end
      end
    end
  rescue
    _error -> {:error, :catalog_unavailable}
  end

  defp with_sandbox_checkout(repo, fun) do
    case Ecto.Adapters.SQL.Sandbox.checkout(repo) do
      :ok ->
        try do
          fun.(repo)
        after
          Ecto.Adapters.SQL.Sandbox.checkin(repo)
        end

      {:already, _owner} ->
        fun.(repo)

      {:error, _reason} ->
        {:error, :catalog_unavailable}
    end
  end
end
