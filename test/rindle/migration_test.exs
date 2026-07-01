defmodule Rindle.MigrationTest do
  use Rindle.DataCase, async: false

  alias Rindle.Repo

  @marker_table "rindle_migration_versions"
  @rindle_tables ~w(
    media_assets
    media_attachments
    media_variants
    media_upload_sessions
    media_processing_runs
    media_provider_assets
  )

  describe "Rindle.Migration.up/1" do
    test "defaults to the public prefix and records the current Rindle migration version" do
      run_up(fn ->
        Rindle.Migration.up(version: 1)
      end)

      assert table_exists?("public", @marker_table),
             "expected Rindle.Migration.up(version: 1) to default to prefix: \"public\""

      assert marker_versions("public") == [1]

      for table <- @rindle_tables do
        assert table_exists?("public", table),
               "expected Rindle.Migration.up(version: 1) to create public.#{table}"
      end
    end

    test "creates current Rindle-owned tables idempotently without creating oban_jobs" do
      prefix = temporary_prefix!()

      refute table_exists?(prefix, "oban_jobs")

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
      refute table_exists?(prefix, "oban_jobs")
    end

    test "uses explicit uuid primary keys for Rindle-owned tables" do
      prefix = temporary_prefix!()

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
      prefix = temporary_prefix!()

      Repo.query!("CREATE TABLE #{qualified(prefix, "oban_jobs")} (id bigint PRIMARY KEY)")
      Repo.query!("INSERT INTO #{qualified(prefix, "oban_jobs")} (id) VALUES (1)")

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
      assert %{rows: [[1]]} = Repo.query!("SELECT id FROM #{qualified(prefix, "oban_jobs")}")
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

  defp run_up(fun) when is_function(fun, 0), do: run_migration(:up, [], fun)

  defp run_up(opts, fun), do: run_migration(:up, opts, fun)

  defp run_down(opts, fun), do: run_migration(:down, opts, fun)

  defp run_migration(direction, opts, fun) do
    {:ok, runner} =
      Ecto.Migration.Runner.start_link(
        {self(), Repo, Repo.config(), __MODULE__, :forward, direction,
         %{level: false, sql: false}}
      )

    Ecto.Migration.Runner.metadata(runner, opts)

    try do
      fun.()
      Ecto.Migration.Runner.flush()
    after
      if Process.alive?(runner), do: Ecto.Migration.Runner.stop()
      Process.delete(:ecto_migration)
    end
  end

  defp temporary_prefix! do
    prefix = "rindle_migration_test_#{System.unique_integer([:positive])}"
    Repo.query!("CREATE SCHEMA #{quote_ident(prefix)}")

    on_exit(fn ->
      Repo.query!("DROP SCHEMA IF EXISTS #{quote_ident(prefix)} CASCADE")
    end)

    prefix
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
