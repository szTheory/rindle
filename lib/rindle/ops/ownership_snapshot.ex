defmodule Rindle.Ops.OwnershipSnapshot do
  @moduledoc false

  alias Rindle.Config
  alias Rindle.Migration.V1, as: MigrationV1
  alias Rindle.Schema

  @default_oban_prefix "public"
  @type classification ::
          :ready
          | :legacy_ready
          | :rindle_prefix_mismatch
          | :incomplete
          | :marker_invalid
          | :inspection_failed
          | :oban_binding_unavailable
          | :oban_binding_drift

  @doc false
  @spec inspect(keyword()) :: %{rindle: map(), oban: map()}
  def inspect(opts \\ []) do
    expected_prefix = Keyword.get(opts, :expected_prefix, Schema.prefix())

    case resolve_oban_binding(opts) do
      {:ok, oban_prefix} ->
        inspect_catalogs(expected_prefix, oban_prefix, opts)

      {:error, classification, expected, observed} ->
        refusal(expected_prefix, classification, expected, observed)
    end
  rescue
    _error ->
      %{
        rindle: inspection_failed_rindle(Schema.prefix()),
        oban: inspection_failed_oban(@default_oban_prefix)
      }
  end

  defp inspect_catalogs(expected_prefix, oban_prefix, opts) do
    other_prefix = other_prefix!(expected_prefix)
    catalogs = Keyword.get(opts, :catalogs)
    expected_catalog = catalog_for(expected_prefix, catalogs, opts)
    other_catalog = catalog_for(other_prefix, catalogs, opts)

    %{
      rindle: classify_rindle(expected_prefix, other_prefix, expected_catalog, other_catalog),
      oban: classify_oban(oban_catalog_for(oban_prefix, opts), oban_prefix)
    }
  end

  defp refusal(expected_prefix, classification, oban_prefix, observed_prefix) do
    %{
      rindle:
        rindle_data(expected_prefix, nil, :incomplete)
        |> Map.put(:missing_relations, MigrationV1.owned_relations()),
      oban: oban_data(oban_prefix, observed_prefix, classification)
    }
  end

  defp resolve_oban_binding(opts) do
    mix_app = Keyword.get(opts, :mix_app, :rindle)
    binding = Keyword.get_lazy(opts, :oban_binding, fn -> Application.get_env(mix_app, Oban) end)
    compatibility_prefix = Keyword.get(opts, :compatibility_oban_prefix, Config.oban_prefix())

    with binding when is_list(binding) <- binding,
         :ok <- validate_default_oban(binding),
         :ok <- validate_oban_repo(binding),
         {:ok, prefix} <-
           normalize_oban_prefix(Keyword.get(binding, :prefix, @default_oban_prefix)),
         :ok <- validate_compatibility(prefix, compatibility_prefix) do
      {:ok, prefix}
    else
      {:drift, expected, observed} -> {:error, :oban_binding_drift, expected, observed}
      _other -> {:error, :oban_binding_unavailable, @default_oban_prefix, nil}
    end
  end

  defp validate_default_oban(binding) do
    case Keyword.get(binding, :name) do
      nil -> :ok
      Oban -> :ok
      _other -> {:error, :named_instance}
    end
  end

  defp validate_oban_repo(binding) do
    if Keyword.get(binding, :repo) == Config.repo(), do: :ok, else: {:error, :repo_mismatch}
  end

  defp normalize_oban_prefix(prefix) when is_binary(prefix) do
    if Regex.match?(~r/\A[a-zA-Z_][a-zA-Z0-9_$]*\z/, prefix),
      do: {:ok, prefix},
      else: {:error, :invalid_prefix}
  end

  defp normalize_oban_prefix(_prefix), do: {:error, :invalid_prefix}

  defp validate_compatibility(prefix, prefix), do: :ok

  defp validate_compatibility(prefix, observed) when is_binary(observed),
    do: {:drift, prefix, observed}

  defp validate_compatibility(_prefix, _observed), do: {:error, :invalid_compatibility_prefix}

  defp catalog_for(prefix, catalogs, _opts) when is_map(catalogs),
    do: normalize_catalog(Map.get(catalogs, prefix), prefix)

  defp catalog_for(prefix, _catalogs, opts) do
    case Keyword.fetch(opts, :rindle_schema_catalog) do
      {:ok, %{prefix: ^prefix} = catalog} -> normalize_catalog(catalog, prefix)
      {:ok, _catalog} -> normalize_catalog(nil, prefix)
      :error -> read_catalog(prefix, opts)
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

  defp read_catalog(prefix, opts) do
    with :ok <- validate_rindle_prefix(prefix),
         {:ok, %{rows: rows}} <- catalog_query(prefix, opts) do
      relations = Enum.map(rows, &hd/1)

      marker_versions =
        if MigrationV1.marker_table() in relations,
          do: read_marker_versions(prefix, opts),
          else: []

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

  defp catalog_query(prefix, opts) do
    case Keyword.get(opts, :catalog_reader) do
      fun when is_function(fun, 1) -> {:ok, normalize_catalog_result(fun.(prefix))}
      _other -> query_catalog(prefix)
    end
  rescue
    _error -> {:error, :catalog_unavailable}
  end

  defp normalize_catalog_result(%{rows: _rows} = result), do: result
  defp normalize_catalog_result(%{} = catalog), do: %{rows: Enum.map(catalog.relations, &[&1])}
  defp normalize_catalog_result(_result), do: %{rows: []}

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

  defp read_marker_versions(prefix, _opts) do
    with :ok <- validate_rindle_prefix(prefix),
         {:ok, %{rows: rows}} <-
           with_repo(fn repo ->
             repo.query("SELECT version FROM #{qualified_marker(prefix)} ORDER BY version", [])
           end) do
      Enum.map(rows, &hd/1)
    else
      _error -> :invalid_marker
    end
  end

  defp oban_catalog_for(prefix, opts) do
    case Keyword.get(opts, :oban_jobs_catalog) do
      fun when is_function(fun, 1) -> fun.(prefix)
      nil -> read_oban_catalog(prefix)
      catalog -> catalog
    end
  rescue
    _error -> {:error, :catalog_unavailable}
  end

  defp read_oban_catalog(prefix) do
    with {:ok, %{num_rows: count}} <-
           with_repo(fn repo ->
             repo.query(
               "SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = 'oban_jobs' LIMIT 1",
               [prefix]
             )
           end) do
      %{exists?: count == 1, prefix: prefix}
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

      empty?(expected) and complete?(other) and valid_marker?(other) ->
        rindle_data(expected_prefix, other_prefix, :rindle_prefix_mismatch)

      not complete?(expected) ->
        rindle_data(expected_prefix, nil, :incomplete)
        |> Map.put(:missing_relations, missing_relations(expected))

      true ->
        rindle_data(expected_prefix, nil, :marker_invalid)
    end
  end

  defp classify_oban(%{exists?: true}, prefix), do: oban_data(prefix, prefix, :ready)
  defp classify_oban(%{exists?: false}, prefix), do: oban_data(prefix, nil, :incomplete)
  defp classify_oban(_catalog, prefix), do: inspection_failed_oban(prefix)

  defp rindle_data(expected_prefix, observed_prefix, classification) do
    %{
      expected_prefix: expected_prefix,
      observed_prefix: observed_prefix,
      owner: :rindle,
      classification: classification,
      next_action: rindle_next_action(classification)
    }
  end

  defp oban_data(expected_prefix, observed_prefix, classification) do
    %{
      expected_prefix: expected_prefix,
      observed_prefix: observed_prefix,
      owner: :host,
      classification: classification,
      next_action: oban_next_action(classification)
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

  defp oban_next_action(:oban_binding_drift),
    do:
      "Align `:rindle, :oban_prefix` with the default host Oban binding, then re-run `mix rindle.doctor`."

  defp oban_next_action(:oban_binding_unavailable),
    do:
      "Configure the default `Oban` module with the Rindle repo and a safe schema prefix; Rindle does not manage host Oban."

  defp oban_next_action(_classification),
    do: "Host owns Oban.Migration for oban_jobs. Rindle no longer manages `oban_jobs`."

  defp inspection_failed_rindle(expected_prefix),
    do: rindle_data(expected_prefix, nil, :inspection_failed)

  defp inspection_failed_oban(prefix), do: oban_data(prefix, nil, :inspection_failed)

  defp complete?(%{relations: relations}),
    do: Enum.sort(relations) == Enum.sort(MigrationV1.owned_relations())

  defp empty?(%{relations: relations, marker_versions: versions}),
    do: relations == [] and versions == []

  defp missing_relations(%{relations: relations}), do: MigrationV1.owned_relations() -- relations

  defp valid_marker?(%{marker_versions: versions}),
    do: versions == [MigrationV1.current_version()]

  defp other_prefix!(prefix) do
    case Schema.supported_prefixes() -- [prefix] do
      [other_prefix] -> other_prefix
      _other -> raise ArgumentError, "unsupported Rindle prefix"
    end
  end

  defp validate_rindle_prefix(prefix),
    do: if(prefix in Schema.supported_prefixes(), do: :ok, else: {:error, :unsupported_prefix})

  defp qualified_marker(prefix), do: ~s("#{prefix}"."#{MigrationV1.marker_table()}")

  defp with_repo(fun) do
    repo = Config.repo()

    cond do
      Process.whereis(repo) ->
        fun.(repo)

      true ->
        Ecto.Migrator.with_repo(repo, fun, mode: :temporary)
        |> case do
          {:ok, result, _apps} -> result
          {:error, _reason} -> {:error, :catalog_unavailable}
        end
    end
  rescue
    _error -> {:error, :catalog_unavailable}
  end
end
