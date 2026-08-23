defmodule Rindle.InstallSmoke.GeneratedApp.Contracts do
  @moduledoc false

  @expected_media_variants_indexes [
    "media_variants_asset_id_name_index",
    "media_variants_state_index",
    "media_variants_output_kind_index"
  ]

  @doc false
  def default_install_contract do
    %{
      host_oban_migration_source: host_oban_migration_source(),
      rindle_migration_source: rindle_migration_source(),
      required_report_keys: [
        :package_root_provenance,
        :selected_schema_relations,
        :decoy_schema_relations,
        :public_host_relations,
        :host_migration_paths,
        :persistence_lifecycle
      ]
    }
  end

  @doc false
  def persistence_lifecycle_report_keys do
    [
      "initiated_session_id",
      "verified_session_id",
      "asset_id",
      "read_back_asset_id",
      "asset_state"
    ]
  end

  @doc false
  def tus_outcome_contract do
    %{
      required_report_fields: [
        :phoenix_helper_endpoint,
        :phoenix_helper_uploader,
        :phoenix_helper_upload_url,
        :phoenix_helper_session_id,
        :phoenix_helper_asset_id,
        :completion_surface,
        :phoenix_state_sequence,
        :phoenix_error_state
      ],
      endpoint: "/uploads/tus",
      uploader: "RindleTus",
      upload_url_fragment: "/uploads/tus/",
      completion_surface: "consume_uploaded_entries->verify_completion",
      state_sequence: ["uploading", "verifying", "ready"],
      success_error_state: nil,
      failure_error_state: "error"
    }
  end

  @doc false
  def expected_media_variants_indexes, do: @expected_media_variants_indexes

  @doc false
  def public_compatibility_contract do
    migration_source = rindle_migration_source("public")

    %{
      scenario: :public_compatibility,
      app_name: "rindle_public_compat_smoke_app",
      database_identity: "rindle_public_compat_smoke_app",
      report_identity: "public_compatibility_migration_report.json",
      compile_prefix: "public",
      migration_source: migration_source,
      migration_calls: migration_calls(migration_source),
      required_report_keys: [
        :selected_schema_relations,
        :decoy_schema_relations,
        :public_host_relations,
        :persistence_lifecycle
      ]
    }
  end

  @doc false
  def isolation_upgrade_contract do
    %{
      scenario: :isolation_upgrade,
      public_app_name: "rindle_isolation_upgrade_public_app",
      default_app_name: "rindle_isolation_upgrade_default_app",
      public_root_identity: "isolation-upgrade-public",
      default_root_identity: "isolation-upgrade-default",
      public_compile_prefix: "public",
      default_compile_prefix: "rindle",
      directional_migration_source: directional_migration_source(),
      required_report_keys: [
        :seeded_asset_id,
        :seeded_variant_id,
        :marker_versions,
        :media_variants_foreign_key,
        :media_variants_indexes,
        :oban_jobs_before,
        :oban_jobs_after,
        :selected_schema_relations,
        :decoy_schema_relations,
        :public_host_relations,
        :doctor_ready?,
        :persistence_lifecycle
      ]
    }
  end

  @doc false
  def legacy_upgrade_contract do
    %{
      scenario: :legacy_upgrade,
      compile_prefix: "rindle",
      migration_kind: :legacy_upgrade,
      migration_source: legacy_upgrade_migration_source()
    }
  end

  @doc false
  def isolation_upgrade_catalog_preserved?(%{
        marker_versions: [1],
        media_variants_foreign_key: foreign_key,
        media_variants_indexes: indexes,
        oban_jobs_before: oban_jobs_before,
        oban_jobs_after: oban_jobs_after
      }) do
    exact_media_variants_foreign_key?(foreign_key) and
      exact_media_variants_indexes?(indexes) and
      complete_oban_jobs_snapshot?(oban_jobs_before) and
      oban_jobs_before == oban_jobs_after
  end

  def isolation_upgrade_catalog_preserved?(_report), do: false

  @doc false
  def profile_enabled?(profile_mode) when profile_mode in [:image, :video, :tus, :mux, :gcs] do
    selected_profiles() |> Enum.member?(profile_mode)
  end

  @doc false
  def phase_120_scenario_enabled?(scenario, included_tags \\ nil)

  def phase_120_scenario_enabled?(scenario, nil) do
    included_tags = ExUnit.configuration() |> Keyword.get(:include, [])
    phase_120_scenario_enabled?(scenario, included_tags)
  end

  def phase_120_scenario_enabled?(scenario, included_tags) when is_list(included_tags) do
    selected_scenarios =
      included_tags
      |> Enum.map(fn
        {tag, _value} -> tag
        tag -> tag
      end)
      |> Enum.filter(&(&1 in [:phase_120_public_compat, :phase_120_isolation_upgrade]))

    selected_scenarios == [] or scenario in selected_scenarios
  end

  @doc false
  def host_oban_migration_source do
    """
    defmodule RindleSmokeApp.Repo.Migrations.InstallHostOwnedOban do
      use Ecto.Migration

      def up, do: Oban.Migration.up()
      def down, do: Oban.Migration.down(version: 1)
    end
    """
  end

  @doc false
  def rindle_migration_source(prefix \\ "rindle") do
    prefix_option = if prefix == "public", do: ~s(, prefix: "public"), else: ""

    """
    defmodule RindleSmokeApp.Repo.Migrations.InstallRindle do
      use Ecto.Migration

      def up, do: Rindle.Migration.up(version: 1#{prefix_option})
      def down, do: Rindle.Migration.down(version: 1#{prefix_option})
    end
    """
  end

  @doc false
  def directional_migration_source do
    """
    defmodule RindleSmokeApp.Repo.Migrations.MovePublicRindleToDefaultSchema do
      use Ecto.Migration

      def up do
        execute("SET LOCAL lock_timeout = '5s'")
        Rindle.Migration.move_public_to_rindle(version: 1)
      end
    end
    """
  end

  @doc false
  def legacy_upgrade_migration_source do
    """
    defmodule RindleSmokeApp.Repo.Migrations.UpgradeLegacyPublicRindleToDefaultSchema do
      use Ecto.Migration

      def up do
        execute("SET LOCAL lock_timeout = '5s'")
        Rindle.Migration.up(version: 1, prefix: "public")
        flush()
        Rindle.Migration.move_public_to_rindle(version: 1)
      end
    end
    """
  end

  defp migration_calls(source) do
    for callback <- [:up, :down], into: %{} do
      prefix = "def #{callback}, do:"

      call =
        source
        |> String.split("\n")
        |> Enum.find(&String.contains?(&1, prefix))
        |> String.trim()

      {callback, call}
    end
  end

  defp exact_media_variants_foreign_key?(foreign_key) when is_map(foreign_key) do
    Map.take(foreign_key, [
      "name",
      "type",
      "source_schema",
      "source_table",
      "source_column",
      "target_schema",
      "target_table",
      "target_column"
    ]) == %{
      "name" => "media_variants_asset_id_fkey",
      "type" => "f",
      "source_schema" => "rindle",
      "source_table" => "media_variants",
      "source_column" => "asset_id",
      "target_schema" => "rindle",
      "target_table" => "media_assets",
      "target_column" => "id"
    } and is_binary(foreign_key["definition"]) and
      String.contains?(foreign_key["definition"], "FOREIGN KEY (asset_id)") and
      String.contains?(foreign_key["definition"], "REFERENCES rindle.media_assets(id)")
  end

  defp exact_media_variants_foreign_key?(_foreign_key), do: false

  defp exact_media_variants_indexes?(indexes) when is_list(indexes) do
    Enum.map(indexes, & &1["name"]) == @expected_media_variants_indexes and
      Enum.all?(indexes, &exact_media_variants_index?/1)
  end

  defp exact_media_variants_indexes?(_indexes), do: false

  defp exact_media_variants_index?(%{
         "name" => "media_variants_asset_id_name_index",
         "definition" => definition
       }) do
    is_binary(definition) and String.contains?(definition, "CREATE UNIQUE INDEX") and
      String.contains?(definition, "ON rindle.media_variants") and
      String.contains?(definition, "(asset_id, name)")
  end

  defp exact_media_variants_index?(%{
         "name" => "media_variants_state_index",
         "definition" => definition
       }) do
    is_binary(definition) and String.contains?(definition, "CREATE INDEX") and
      String.contains?(definition, "ON rindle.media_variants") and
      String.contains?(definition, "(state)")
  end

  defp exact_media_variants_index?(%{
         "name" => "media_variants_output_kind_index",
         "definition" => definition
       }) do
    is_binary(definition) and String.contains?(definition, "CREATE INDEX") and
      String.contains?(definition, "ON rindle.media_variants") and
      String.contains?(definition, "(output_kind)")
  end

  defp exact_media_variants_index?(_index), do: false

  defp complete_oban_jobs_snapshot?(%{
         "identity" => %{"oid" => oid, "schema" => "public", "name" => "oban_jobs"},
         "columns" => columns,
         "constraints" => constraints,
         "indexes" => indexes
       }) do
    is_integer(oid) and oid > 0 and is_list(columns) and columns != [] and
      is_list(constraints) and constraints != [] and is_list(indexes) and indexes != []
  end

  defp complete_oban_jobs_snapshot?(%{
         identity: %{"oid" => oid, "schema" => "public", "name" => "oban_jobs"},
         columns: columns,
         constraints: constraints,
         indexes: indexes
       }) do
    is_integer(oid) and oid > 0 and is_list(columns) and columns != [] and
      is_list(constraints) and constraints != [] and is_list(indexes) and indexes != []
  end

  defp complete_oban_jobs_snapshot?(_snapshot), do: false

  defp selected_profiles do
    case System.get_env("RINDLE_INSTALL_SMOKE_PROFILE", "all") do
      "all" -> [:image, :video, :tus, :mux, :gcs]
      "image" -> [:image]
      "video" -> [:video]
      "tus" -> [:tus]
      "mux" -> [:mux]
      "gcs" -> [:gcs]
      other -> raise "unsupported RINDLE_INSTALL_SMOKE_PROFILE: #{inspect(other)}"
    end
  end
end
