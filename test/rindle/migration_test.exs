defmodule Rindle.MigrationTest do
  use Rindle.DataCase, async: false

  alias Rindle.Repo

  @marker_table Rindle.Migration.V1.marker_table()
  @rindle_tables Rindle.Migration.V1.rindle_tables()

  describe "Rindle.Migration.up/1" do
    test "defaults to rindle, provisions its schema, and records the current Rindle migration version" do
      reset_rindle_schema!()

      run_up(fn ->
        Rindle.Migration.up(version: 1)
      end)

      assert schema_exists?("rindle")

      assert table_exists?("rindle", @marker_table),
             "expected Rindle.Migration.up(version: 1) to default to prefix: \"rindle\""

      assert marker_versions("rindle") == [1]

      for table <- @rindle_tables do
        assert table_exists?("rindle", table),
               "expected Rindle.Migration.up(version: 1) to create rindle.#{table}"
      end
    end

    test "supports explicit public compatibility and remains idempotent without host relations" do
      prefix = "public"
      host_relations_before = host_relation_snapshots(prefix)

      run_up([prefix: prefix], fn ->
        Rindle.Migration.up(version: 1, prefix: prefix)
      end)

      run_up([prefix: prefix], fn ->
        Rindle.Migration.up(version: 1, prefix: prefix)
      end)

      for table <- @rindle_tables do
        assert table_exists?(prefix, table),
               "expected #{table} to exist after idempotent Rindle.Migration.up/1"
      end

      assert table_exists?(prefix, @marker_table)
      assert marker_versions(prefix) == [1]
      assert host_relation_snapshots(prefix) == host_relations_before
    end

    test "uses explicit uuid primary keys for Rindle-owned tables" do
      prefix = "public"

      run_up([prefix: prefix], fn ->
        Rindle.Migration.up(version: 1, prefix: prefix)
      end)

      for table <- @rindle_tables do
        assert primary_key_columns(prefix, table) == [{"id", "uuid"}],
               "expected #{table}.id to be an explicit uuid primary key"
      end
    end
  end

  describe "Rindle.Migration.down/1" do
    test "drops only Rindle-owned tables and marker state while leaving oban_jobs intact" do
      prefix = "public"

      Repo.query!(
        "CREATE TABLE IF NOT EXISTS #{qualified(prefix, "oban_jobs")} (id bigint PRIMARY KEY)"
      )

      oban_jobs_before = relation_snapshot(prefix, "oban_jobs")

      run_up([prefix: prefix], fn ->
        Rindle.Migration.up(version: 1, prefix: prefix)
      end)

      run_down([prefix: prefix], fn ->
        Rindle.Migration.down(version: 1, prefix: prefix)
      end)

      for table <- [@marker_table | @rindle_tables] do
        refute table_exists?(prefix, table),
               "expected Rindle.Migration.down(version: 1) to drop #{table}"
      end

      assert table_exists?(prefix, "oban_jobs")

      assert relation_snapshot(prefix, "oban_jobs") == oban_jobs_before
    end
  end

  describe "Rindle.Migration option validation" do
    test "rejects unknown options, invalid versions, and non-string prefixes" do
      assert_raise ArgumentError, ~r/unknown|extra|option/i, fn ->
        Rindle.Migration.up(version: 1, unknown: true)
      end

      assert_raise ArgumentError, ~r/version/i, fn ->
        Rindle.Migration.up(version: 2)
      end

      assert_raise ArgumentError, ~r/prefix/i, fn ->
        Rindle.Migration.down(version: 1, prefix: :public)
      end
    end
  end

  describe "Rindle.Migration.move_public_to_rindle/1 preflight" do
    test "classifies a complete public source and absent rindle destination without DDL" do
      reset_rindle_schema!()

      run_up([prefix: "public"], fn ->
        Rindle.Migration.up(version: 1, prefix: "public")
      end)

      assert {:provisionable_absent_target, snapshot} =
               run_move(fn -> Rindle.Migration.V1.preflight_public_to_rindle() end)

      assert snapshot.source_relations == Enum.sort(Rindle.Migration.V1.owned_relations())
      refute snapshot.target_exists?
      refute schema_exists?("rindle")
    end

    test "classifies marker-invalid, mixed, and already-upgraded states before mutation" do
      reset_rindle_schema!()

      run_up([prefix: "public"], fn ->
        Rindle.Migration.up(version: 1, prefix: "public")
      end)

      Repo.query!("DELETE FROM public.rindle_migration_versions")
      Repo.query!("INSERT INTO public.rindle_migration_versions (version) VALUES (2)")

      assert {:refusal, :public_marker_invalid} =
               run_move(fn -> Rindle.Migration.V1.preflight_public_to_rindle() end)

      Repo.query!("DELETE FROM public.rindle_migration_versions")
      Repo.query!("INSERT INTO public.rindle_migration_versions (version) VALUES (1)")

      run_up(fn ->
        Rindle.Migration.up(version: 1)
      end)

      assert {:refusal, :rindle_not_empty} =
               run_move(fn -> Rindle.Migration.V1.preflight_public_to_rindle() end)

      run_down([prefix: "public"], fn ->
        Rindle.Migration.down(version: 1, prefix: "public")
      end)

      assert :already_upgraded =
               run_move(fn -> Rindle.Migration.V1.preflight_public_to_rindle() end)
    end

    test "refuses an incomplete public source without creating rindle or touching host relations" do
      reset_rindle_schema!()
      host_relations_before = host_relation_snapshots("public")

      assert_raise ArgumentError, ~r/public.*incomplete|prepare/i, fn ->
        run_move(fn ->
          Rindle.Migration.move_public_to_rindle(version: 1)
        end)
      end

      refute schema_exists?("rindle")
      assert host_relation_snapshots("public") == host_relations_before
    end
  end

  defp run_up(fun) when is_function(fun, 0), do: run_migration(:up, [], fun)

  defp run_up(opts, fun), do: run_migration(:up, opts, fun)

  defp run_down(opts, fun), do: run_migration(:down, opts, fun)

  defp run_move(fun), do: run_migration(:up, [], fun)

  defp run_migration(direction, opts, fun) do
    {:ok, runner} =
      Ecto.Migration.Runner.start_link(
        {self(), Repo, Repo.config(), __MODULE__, :forward, direction,
         %{level: false, sql: false}}
      )

    Ecto.Migration.Runner.metadata(runner, opts)

    try do
      result = fun.()
      Ecto.Migration.Runner.flush()
      result
    after
      if Process.alive?(runner), do: Ecto.Migration.Runner.stop()
      Process.delete(:ecto_migration)
    end
  end

  defp reset_rindle_schema! do
    Repo.query!("DROP SCHEMA IF EXISTS \"rindle\" CASCADE")

    on_exit(fn ->
      Repo.query!("DROP SCHEMA IF EXISTS \"rindle\" CASCADE")
    end)
  end

  defp schema_exists?(schema) do
    %{rows: [[exists?]]} = Repo.query!("SELECT to_regnamespace($1) IS NOT NULL", [schema])
    exists?
  end

  defp table_exists?(prefix, table) do
    %{rows: [[exists?]]} =
      Repo.query!("SELECT to_regclass($1) IS NOT NULL", ["#{prefix}.#{table}"])

    exists?
  end

  defp marker_versions(prefix) do
    %{rows: rows} =
      Repo.query!("SELECT version FROM #{qualified(prefix, @marker_table)} ORDER BY version")

    Enum.map(rows, fn [version] -> version end)
  end

  defp host_relation_snapshots(prefix) do
    for relation <- ["oban_jobs", "schema_migrations"], into: %{} do
      {relation, relation_snapshot(prefix, relation)}
    end
  end

  defp relation_snapshot(prefix, relation) do
    if table_exists?(prefix, relation) do
      %{rows: [[count]]} = Repo.query!("SELECT count(*) FROM #{qualified(prefix, relation)}")
      {:present, count}
    else
      :absent
    end
  end

  defp primary_key_columns(prefix, table) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT key_column.column_name, column_info.udt_name
        FROM information_schema.table_constraints AS constraint_info
        JOIN information_schema.key_column_usage AS key_column
          ON constraint_info.constraint_name = key_column.constraint_name
         AND constraint_info.table_schema = key_column.table_schema
         AND constraint_info.table_name = key_column.table_name
        JOIN information_schema.columns AS column_info
          ON column_info.table_schema = key_column.table_schema
         AND column_info.table_name = key_column.table_name
         AND column_info.column_name = key_column.column_name
        WHERE constraint_info.constraint_type = 'PRIMARY KEY'
          AND constraint_info.table_schema = $1
          AND constraint_info.table_name = $2
        ORDER BY key_column.ordinal_position
        """,
        [prefix, table]
      )

    Enum.map(rows, fn [column, type] -> {column, type} end)
  end

  defp qualified(prefix, table), do: "#{quote_ident(prefix)}.#{quote_ident(table)}"

  defp quote_ident(identifier) do
    escaped =
      identifier
      |> to_string()
      |> String.replace(~s("), ~s(""))

    ~s("#{escaped}")
  end
end
