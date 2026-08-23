defmodule Rindle.Migration.V1.Snapshot do
  @moduledoc false

  @spec observe(module(), map()) :: map()
  def observe(repo, requirements) do
    %{source_schema: source_schema, target_schema: target_schema, owned_relations: owned_relations,
      marker_table: marker_table, privilege_override: privilege_override} = requirements

    %{rows: schema_rows} =
      repo.query!(
        "SELECT nspname FROM pg_namespace WHERE nspname = ANY($1) ORDER BY nspname",
        [[source_schema, target_schema]]
      )

    %{rows: relation_rows} =
      repo.query!(
        """
        SELECT namespace.nspname, relation.relname,
               pg_has_role(current_user, relation.relowner, 'USAGE')
        FROM pg_class AS relation
        JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
        WHERE namespace.nspname = ANY($1)
          AND relation.relname = ANY($2)
          AND relation.relkind IN ('r', 'p')
        ORDER BY namespace.nspname, relation.relname
        """,
        [[source_schema, target_schema], owned_relations]
      )

    marker_rows = marker_rows(repo, relation_rows, marker_table)

    %{rows: [[database_create?]]} =
      repo.query!("SELECT has_database_privilege(current_database(), 'CREATE')", [])

    database_create? = Map.get(privilege_override, :database_create?, database_create?)
    schemas = Enum.map(schema_rows, &hd/1)
    target_exists? = target_schema in schemas
    target_usable? = target_usable?(repo, target_schema, target_exists?)
    target_usable? = Map.get(privilege_override, :target_usable?, target_usable?)

    %{rows: [[public_usable?]]} =
      repo.query!("SELECT has_schema_privilege($1, 'USAGE, CREATE')", [source_schema])

    public_usable? = Map.get(privilege_override, :public_usable?, public_usable?)
    relation_state = relation_state(relation_rows, source_schema, target_schema)
    marker_state = Enum.group_by(marker_rows, &hd/1, &List.last/1)

    %{
      source_relations: relation_state[source_schema].names |> Enum.sort(),
      target_relations: relation_state[target_schema].names |> Enum.sort(),
      source_owned?: relation_state[source_schema].owned?,
      target_owned?: relation_state[target_schema].owned?,
      source_marker: Map.get(marker_state, source_schema, []),
      target_marker: Map.get(marker_state, target_schema, []),
      target_exists?: target_exists?,
      database_create?: database_create?,
      target_usable?: target_usable?,
      public_usable?: public_usable?,
      owned_relations: Enum.sort(owned_relations),
      current_version: requirements.current_version
    }
  end

  defp target_usable?(_repo, _target_schema, false), do: false

  defp target_usable?(repo, target_schema, true) do
    %{rows: [[usable?]]} =
      repo.query!("SELECT has_schema_privilege($1, 'USAGE, CREATE')", [target_schema])

    usable?
  end

  defp relation_state(relation_rows, source_schema, target_schema) do
    Enum.reduce(
      relation_rows,
      %{
        source_schema => %{names: [], owned?: true},
        target_schema => %{names: [], owned?: true}
      },
      fn [schema, name, owned?], acc ->
        update_in(acc, [schema], fn state ->
          state
          |> Map.update!(:names, &[name | &1])
          |> Map.update(:owned?, owned?, &(&1 and owned?))
        end)
      end
    )
  end

  defp marker_rows(repo, relation_rows, marker_table) do
    relation_rows
    |> Enum.filter(fn [_schema, relation, _owned?] -> relation == marker_table end)
    |> Enum.flat_map(fn [schema, _relation, owned?] ->
      if owned? and marker_has_version_column?(repo, schema, marker_table) do
        %{rows: rows} =
          repo.query!("SELECT version FROM #{qualified(schema, marker_table)} ORDER BY version", [])

        Enum.map(rows, fn [version] -> [schema, version] end)
      else
        [[schema, :invalid_marker]]
      end
    end)
  end

  defp marker_has_version_column?(repo, schema, marker_table) do
    %{rows: [[exists?]]} =
      repo.query!(
        """
        SELECT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = $1
            AND table_name = $2
            AND column_name = 'version'
        )
        """,
        [schema, marker_table]
      )

    exists?
  end

  defp qualified(prefix, table), do: "#{quote_ident(prefix)}.#{quote_ident(table)}"

  defp quote_ident(identifier) do
    escaped = identifier |> to_string() |> String.replace(~s("), ~s(""))
    ~s("#{escaped}")
  end
end
