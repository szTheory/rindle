defmodule Rindle.MigrationFastTest do
  use ExUnit.Case, async: true

  alias Rindle.Migration.{Options, V1}
  alias Rindle.Migration.V1.Preflight

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

  test "classifies the V1-provided fixed catalog before any move authority runs" do
    owned_relations = Enum.sort(V1.owned_relations())

    snapshot = %{
      source_relations: owned_relations,
      target_relations: [],
      source_owned?: true,
      target_owned?: true,
      source_marker: [V1.current_version()],
      target_marker: [],
      target_exists?: false,
      database_create?: true,
      target_usable?: false,
      public_usable?: true,
      owned_relations: owned_relations,
      current_version: V1.current_version()
    }

    assert {:provisionable_absent_target, ^snapshot} =
             Preflight.classify(:public_to_rindle, snapshot)

    assert {:refusal, :source_not_owned} =
             Preflight.classify(:public_to_rindle, %{snapshot | source_owned?: false})

    assert {:refusal, :public_marker_invalid} =
             Preflight.classify(:public_to_rindle, %{snapshot | source_marker: [2]})
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

  test "current migration documentation names the bounded schema upgrade contract" do
    docs =
      ["README.md", "guides/getting_started.md", "guides/upgrading.md"]
      |> Enum.map(&File.read!/1)

    for doc <- docs do
      assert doc =~ "Rindle.Migration.up(version: 1)"
      assert doc =~ "prefix: \"public\""
      assert doc =~ "public schema"
      assert doc =~ "oban_jobs"
      assert doc =~ "schema_migrations"
      assert doc =~ "Rindle.Migration.down/1"
      assert doc =~ "destructive"
      refute doc =~ "tenant_media"
    end

    upgrade = File.read!("guides/upgrading.md")

    for phrase <- [
          "SET LOCAL lock_timeout = '5s'",
          "Rindle.Migration.move_public_to_rindle(version: 1)",
          "Rindle.Migration.move_rindle_to_public(version: 1)",
          "maintenance window",
          "ACCESS EXCLUSIVE",
          "does not quiesce application traffic"
        ] do
      assert upgrade =~ phrase
    end
  end
end
