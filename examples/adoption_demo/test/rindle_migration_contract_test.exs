defmodule AdoptionDemo.RindleMigrationContractTest do
  use AdoptionDemo.DataCase, async: false

  alias AdoptionDemo.Repo
  alias Rindle.Domain.MediaAsset
  alias Rindle.Migration.V1

  @rindle_schema "rindle"
  @public_schema "public"

  test "the host migration installs Rindle relations in rindle and persists through the facade schema" do
    migration = File.read!("priv/repo/migrations/20260809000000_install_rindle.exs")
    oban_migration = File.read!("priv/repo/migrations/20260528120100_add_oban.exs")

    assert migration =~ "defmodule AdoptionDemo.Repo.Migrations.InstallRindle"
    assert migration =~ "Rindle.Migration.up(version: 1)"
    assert migration =~ "Rindle.Migration.down(version: 1)"
    refute migration =~ "Application.app_dir"
    assert oban_migration =~ "Oban.Migration.up()"
    assert oban_migration =~ "Oban.Migration.down()"
    refute oban_migration =~ "Rindle.Migration"

    assert_owned_relations!(@rindle_schema, true)
    assert_owned_relations!(@public_schema, false)
    assert table_exists?(@public_schema, "oban_jobs")
    assert table_exists?(@public_schema, "schema_migrations")

    oban_snapshot = relation_snapshot(@public_schema, "oban_jobs")

    storage_key = "migration-contract/#{Ecto.UUID.generate()}"

    %MediaAsset{}
    |> MediaAsset.changeset(%{
      storage_key: storage_key,
      profile: "AdoptionDemo.RindleProfile",
      kind: "image"
    })
    |> Repo.insert!()

    assert %MediaAsset{storage_key: ^storage_key} = Repo.get_by!(MediaAsset, storage_key: storage_key)
    assert relation_snapshot(@public_schema, "oban_jobs") == oban_snapshot
  end

  test "the cold-start proof tracks the fixed Rindle relation catalog" do
    script = File.read!("../../scripts/ci/cohort_demo_smoke.sh")

    [_, relations_block] = Regex.run(~r/rindle_relations=\(\n(.*?)\n\)/s, script)

    script_relations =
      relations_block
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)

    assert script_relations == V1.owned_relations()
  end

  defp assert_owned_relations!(schema, expected?) do
    for relation <- V1.owned_relations() do
      assert table_exists?(schema, relation) == expected?,
             "expected #{schema}.#{relation} to exist? #{expected?}"
    end
  end

  defp table_exists?(schema, relation) do
    %{rows: [[exists?]]} = Repo.query!("SELECT to_regclass($1) IS NOT NULL", ["#{schema}.#{relation}"])
    exists?
  end

  defp relation_snapshot(schema, relation) do
    %{rows: [[count]]} = Repo.query!("SELECT count(*) FROM #{schema}.#{relation}")
    count
  end
end
