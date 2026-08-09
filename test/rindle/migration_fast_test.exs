defmodule Rindle.MigrationFastTest do
  use ExUnit.Case, async: true

  alias Rindle.Migration.{Options, V1}

  test "defaults migration options to rindle and accepts only the supported pair" do
    assert Options.validate!([]) == %{version: 1, prefix: "rindle"}
    assert Options.validate!(prefix: "public") == %{version: 1, prefix: "public"}

    for prefix <- ["other", "", :rindle] do
      assert_raise ArgumentError, ~r/rindle.*public/i, fn ->
        Options.validate!(prefix: prefix)
      end
    end
  end

  test "owns exactly the six Rindle tables and migration marker" do
    assert V1.owned_relations() ==
             ~w(
               media_assets
               media_attachments
               media_variants
               media_upload_sessions
               media_processing_runs
               media_provider_assets
               rindle_migration_versions
             )

    refute "oban_jobs" in V1.owned_relations()
    refute "schema_migrations" in V1.owned_relations()
  end

  test "rejects unknown options and unsupported versions before migration DDL" do
    assert_raise ArgumentError, fn -> Options.validate!(unknown: true) end
    assert_raise ArgumentError, fn -> Options.validate!(version: 2) end
  end

  test "exposes only the two pinned directional moves beside destructive down" do
    assert function_exported?(Rindle.Migration, :move_public_to_rindle, 1)
    assert function_exported?(Rindle.Migration, :move_rindle_to_public, 1)
    assert function_exported?(Rindle.Migration, :down, 1)
    refute function_exported?(Rindle.Migration, :move, 1)
    refute function_exported?(Rindle.Migration, :move, 2)

    for opts <- [[], [prefix: "public"], [from: "public"], [to: "rindle"]] do
      assert_raise ArgumentError, fn -> Rindle.Migration.move_public_to_rindle(opts) end
      assert_raise ArgumentError, fn -> Rindle.Migration.move_rindle_to_public(opts) end
    end

    assert_raise ArgumentError, fn -> Rindle.Migration.move_public_to_rindle(version: 2) end
    assert_raise ArgumentError, fn -> Rindle.Migration.move_rindle_to_public(version: 2) end
  end
end
