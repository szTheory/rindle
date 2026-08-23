Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.GeneratedAppSmokeAssertions do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      defp assert_install_source!(report) do
        assert File.dir?(report.generated_app_root)
        assert report.profile_mode in [:image, :video, :tus, :upgrade, :mux, :gcs]
        assert report.install_mode in [:package, :network]
        assert report.install_source

        if report.install_mode == :package do
          assert File.dir?(report.package_root)
          assert report.install_source == report.package_root
        else
          assert report.network_mode?
          assert String.starts_with?(report.install_source, "hex:")
          assert report.deps_rindle_present?
        end

        if report.install_mode == :package do
          refute report.deps_rindle_present?
        end

        assert report.compile_exit_code == 0
        assert report.boot_exit_code == 0
      end

      defp assert_host_owned_migrations!(report) do
        assert report.host_migration_ran?
        assert report.host_oban_migration_ran?
        assert report.rindle_migration_ran?
        assert report.migration_resolution == :host_migrations
        assert String.contains?(report.rindle_migration_path || "", "install_rindle")
        refute String.contains?(report.rindle_migration_path || "", "deps/rindle")
        refute String.contains?(report.rindle_migration_path || "", "Application.app_dir")
      end

      defp assert_default_schema_ownership!(report) do
        assert report.package_root_provenance.unpacked?
        refute report.package_root_provenance.repository_path_fallback?
        assert File.dir?(report.package_root_provenance.path)

        assert Enum.all?(report.selected_schema_relations, fn {_relation, exists?} -> exists? end)

        assert Enum.all?(report.decoy_schema_relations, fn {_relation, exists?} -> not exists? end)

        assert report.public_host_relations == %{"oban_jobs" => true, "schema_migrations" => true}

        assert String.contains?(report.host_migration_paths["oban"], "install_host_owned_oban")
        assert String.contains?(report.host_migration_paths["rindle"], "install_rindle")
      end

      defp assert_tus_guide_parity! do
        guide = File.read!("guides/resumable_uploads.md")

        assert guide =~ "plug Plug.Parsers,"
        assert guide =~ ~s(pass: ["application/offset+octet-stream", "*/*"])
        assert guide =~ ~s("Upload-Offset")
        assert guide =~ ~s("Location")
        assert guide =~ ~s("Upload-Length")
        assert guide =~ ~s("Tus-Resumable")
        assert guide =~ ~s("Upload-Expires")
        assert guide =~ "no-silent-downgrade"
        assert guide =~ "raises at init time"
        assert guide =~ "bearer credential"
        assert guide =~ "config :rindle, :tus_resume_authorizer, MyApp.TusAuth"
        assert guide =~ "@uppy/tus"
        assert guide =~ "tus-js-client"

        assert guide =~
                 "Supported tus extensions: creation, expiration, termination, checksum, creation-defer-length, concatenation."

        assert guide =~ "checksum"
        assert guide =~ "creation-defer-length"
        assert guide =~ "concatenation"
        assert guide =~ "parallelUploads"
        assert guide =~ "uploadLengthDeferred"
        assert guide =~ "parallelUploads: 2"
        assert guide =~ "uploadLengthDeferred: true"
        refute guide =~ "parallelUploads: 1 is the supported posture for the Rindle tus edge."
        assert guide =~ "sticky-session or single-node"
        assert Regex.scan(~r/removeFingerprintOnSuccess: true/, guide) |> length() == 3
      end

      defp tus_failure_details(report) do
        """
        tus smoke failed
        workspace: #{report.generated_app_root}
        report: #{report.tus_report_path}
        debug_report: #{report.tus_debug_report_path}
        phase: #{inspect(report.tus_failure_phase)}
        mode: #{inspect(report.tus_failure_mode)}
        endpoint: #{inspect(report.tus_failure_endpoint)}
        summary: #{inspect(report.tus_failure_summary)}
        """
      end
    end
  end
end

alias Rindle.InstallSmoke.GeneratedAppHelper

defmodule Rindle.InstallSmoke.GeneratedAppMigrationContractTest do
  use ExUnit.Case, async: true

  test "generated-app migration proof requires the public Rindle.Migration API" do
    assert Code.ensure_loaded?(Rindle.Migration),
           "generated-app smoke requires Rindle.Migration.up(version: 1) and Rindle.Migration.down(version: 1)"

    assert function_exported?(Rindle.Migration, :up, 1),
           "generated-app smoke requires Rindle.Migration.up(version: 1)"

    assert function_exported?(Rindle.Migration, :down, 1),
           "generated-app smoke requires Rindle.Migration.down(version: 1)"
  end
end

defmodule Rindle.InstallSmoke.GeneratedAppPhase120FastContractTest do
  use ExUnit.Case, async: true

  @moduletag :phase_120_fast_contract

  test "default package proof keeps host migrations separate and reports schema-qualified ownership" do
    contract = GeneratedAppHelper.default_install_contract()

    assert contract.host_oban_migration_source =~ "Oban.Migration.up()"
    assert contract.rindle_migration_source =~ "Rindle.Migration.up(version: 1)"
    refute contract.rindle_migration_source =~ "prefix: \"public\""

    assert contract.required_report_keys == [
             :package_root_provenance,
             :selected_schema_relations,
             :decoy_schema_relations,
             :public_host_relations,
             :host_migration_paths,
             :persistence_lifecycle
           ]
  end

  test "default package proof defines JSON-safe persistence lifecycle facts" do
    assert GeneratedAppHelper.persistence_lifecycle_report_keys() == [
             "initiated_session_id",
             "verified_session_id",
             "asset_id",
             "read_back_asset_id",
             "asset_state"
           ]
  end

  test "stable facade preserves every pure contract and scenario predicate" do
    for {name, facade_value, owner_value} <- [
          {:default_install_contract, GeneratedAppHelper.default_install_contract(),
           Rindle.InstallSmoke.GeneratedApp.Contracts.default_install_contract()},
          {:persistence_lifecycle_report_keys,
           GeneratedAppHelper.persistence_lifecycle_report_keys(),
           Rindle.InstallSmoke.GeneratedApp.Contracts.persistence_lifecycle_report_keys()},
          {:public_compatibility_contract, GeneratedAppHelper.public_compatibility_contract(),
           Rindle.InstallSmoke.GeneratedApp.Contracts.public_compatibility_contract()},
          {:isolation_upgrade_contract, GeneratedAppHelper.isolation_upgrade_contract(),
           Rindle.InstallSmoke.GeneratedApp.Contracts.isolation_upgrade_contract()},
          {:legacy_upgrade_contract, GeneratedAppHelper.legacy_upgrade_contract(),
           Rindle.InstallSmoke.GeneratedApp.Contracts.legacy_upgrade_contract()}
        ] do
      assert facade_value == owner_value, "facade changed #{name}"
    end

    valid_report = valid_isolation_upgrade_catalog_report()

    for report <- [valid_report, %{valid_report | marker_versions: []}] do
      assert GeneratedAppHelper.isolation_upgrade_catalog_preserved?(report) ==
               Rindle.InstallSmoke.GeneratedApp.Contracts.isolation_upgrade_catalog_preserved?(
                 report
               )
    end

    for profile <- [:image, :video, :tus, :mux, :gcs] do
      assert GeneratedAppHelper.profile_enabled?(profile) ==
               Rindle.InstallSmoke.GeneratedApp.Contracts.profile_enabled?(profile)
    end

    tags = [:minio, :phase_120_public_compat]

    for scenario <- [:default, :phase_120_public_compat, :phase_120_isolation_upgrade] do
      assert GeneratedAppHelper.phase_120_scenario_enabled?(scenario, tags) ==
               Rindle.InstallSmoke.GeneratedApp.Contracts.phase_120_scenario_enabled?(
                 scenario,
                 tags
               )
    end
  end

  test "network install provenance reports the fetched unpacked Hex dependency instead of the unused local package path" do
    workspace_root =
      Path.join(
        System.tmp_dir!(),
        "rindle-network-provenance-#{System.unique_integer([:positive])}"
      )

    generated_app_root = Path.join(workspace_root, "generated_app")
    fetched_package_root = Path.join(generated_app_root, "deps/rindle")
    unused_local_package_root = Path.join(workspace_root, "package/rindle")

    File.mkdir_p!(fetched_package_root)
    on_exit(fn -> File.rm_rf(workspace_root) end)

    provenance =
      GeneratedAppHelper.package_root_provenance(
        :network,
        generated_app_root,
        unused_local_package_root
      )

    assert provenance.path == fetched_package_root
    assert provenance.unpacked?
    refute provenance.repository_path_fallback?
  end

  test "package install provenance keeps the unpacked local package root" do
    workspace_root =
      Path.join(
        System.tmp_dir!(),
        "rindle-package-provenance-#{System.unique_integer([:positive])}"
      )

    generated_app_root = Path.join(workspace_root, "generated_app")
    package_root = Path.join(workspace_root, "package/rindle")

    File.mkdir_p!(package_root)
    on_exit(fn -> File.rm_rf(workspace_root) end)

    provenance =
      GeneratedAppHelper.package_root_provenance(
        :package,
        generated_app_root,
        package_root
      )

    assert provenance.path == package_root
    assert provenance.unpacked?
    refute provenance.repository_path_fallback?
  end

  test "legacy video upgrade moves populated public tables into the default isolated schema" do
    contract = GeneratedAppHelper.legacy_upgrade_contract()

    assert contract.scenario == :legacy_upgrade
    assert contract.compile_prefix == "rindle"
    assert contract.migration_kind == :legacy_upgrade
    assert contract.migration_source =~ ~s|Rindle.Migration.up(version: 1, prefix: "public")|
    assert contract.migration_source =~ "Rindle.Migration.move_public_to_rindle(version: 1)"

    up_position = :binary.match(contract.migration_source, "Rindle.Migration.up")
    flush_position = :binary.match(contract.migration_source, "flush()")

    move_position =
      :binary.match(contract.migration_source, "Rindle.Migration.move_public_to_rindle")

    assert up_position < flush_position
    assert flush_position < move_position
  end

  test "focused Phase 120 MinIO commands exclude sibling generated-app scenarios" do
    assert GeneratedAppHelper.phase_120_scenario_enabled?(:phase_120_public_compat, [
             :minio,
             :phase_120_public_compat
           ])

    refute GeneratedAppHelper.phase_120_scenario_enabled?(:phase_120_isolation_upgrade, [
             :minio,
             :phase_120_public_compat
           ])

    refute GeneratedAppHelper.phase_120_scenario_enabled?(:default, [
             :minio,
             :phase_120_public_compat
           ])

    assert GeneratedAppHelper.phase_120_scenario_enabled?(:default, [:minio])
  end

  @tag :phase_120_compat_contract
  test "public compatibility uses an isolated compiled consumer and fixed public migration" do
    contract = GeneratedAppHelper.public_compatibility_contract()

    assert contract.scenario == :public_compatibility
    assert contract.app_name != "rindle_smoke_app"
    assert contract.database_identity != "rindle_smoke_app"
    assert contract.report_identity != "install_smoke_migration_report.json"
    assert contract.compile_prefix == "public"
    assert contract.migration_source =~ ~s|Rindle.Migration.up(version: 1, prefix: "public")|
    refute contract.migration_source =~ "System.get_env"

    assert contract.required_report_keys == [
             :selected_schema_relations,
             :decoy_schema_relations,
             :public_host_relations,
             :persistence_lifecycle
           ]
  end

  @tag :phase_120_upgrade_contract
  test "populated isolation upgrade uses public and default builds plus the directional host migration" do
    contract = GeneratedAppHelper.isolation_upgrade_contract()

    assert contract.scenario == :isolation_upgrade
    assert contract.public_app_name != contract.default_app_name
    assert contract.public_root_identity != contract.default_root_identity
    assert contract.public_compile_prefix == "public"
    assert contract.default_compile_prefix == "rindle"
    assert contract.directional_migration_source =~ "SET LOCAL lock_timeout = '5s'"
    assert contract.directional_migration_source =~ "move_public_to_rindle(version: 1)"
    refute contract.directional_migration_source =~ "move_rindle_to_public"

    assert contract.required_report_keys == [
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
  end

  @tag :phase_120_upgrade_contract
  test "isolation upgrade contract requires before and after Oban catalog snapshots" do
    contract = GeneratedAppHelper.isolation_upgrade_contract()

    assert :oban_jobs_before in contract.required_report_keys
    assert :oban_jobs_after in contract.required_report_keys

    report = valid_isolation_upgrade_catalog_report()
    assert GeneratedAppHelper.isolation_upgrade_catalog_preserved?(report)

    refute GeneratedAppHelper.isolation_upgrade_catalog_preserved?(%{
             report
             | oban_jobs_after: Map.put(report.oban_jobs_after, :columns, [])
           })
  end

  @tag :phase_120_upgrade_contract
  test "isolation upgrade contract requires generated doctor readiness" do
    assert :doctor_ready? in GeneratedAppHelper.isolation_upgrade_contract().required_report_keys
  end

  @tag :phase_120_upgrade_contract
  test "generated child commands have bounded stage-labelled diagnostics" do
    cwd = File.cwd!()

    success =
      Rindle.InstallSmoke.GeneratedApp.CommandRunner.run(
        cwd,
        ["sh", "-c", "printf ready"],
        [],
        stage: "fast-success",
        timeout_ms: 1_000
      )

    assert success == %{
             output: "stage=fast-success\nready",
             exit_code: 0,
             stage: "fast-success",
             timed_out?: false
           }

    failure =
      Rindle.InstallSmoke.GeneratedApp.CommandRunner.run(
        cwd,
        ["sh", "-c", "printf failed; exit 23"],
        [],
        stage: "nonzero",
        timeout_ms: 1_000
      )

    assert failure.exit_code == 23
    assert failure.output == "stage=nonzero\nfailed"

    assert_raise RuntimeError, ~r/stage=nonzero/, fn ->
      Rindle.InstallSmoke.GeneratedApp.CommandRunner.run!(
        cwd,
        ["sh", "-c", "exit 23"],
        [],
        stage: "nonzero",
        timeout_ms: 1_000
      )
    end

    timeout =
      Rindle.InstallSmoke.GeneratedApp.CommandRunner.run(
        cwd,
        ["sh", "-c", "sleep 1"],
        [],
        stage: "short-timeout",
        timeout_ms: 10
      )

    assert timeout.exit_code == 124
    assert timeout.timed_out?
    assert timeout.output =~ "stage=short-timeout"
    assert timeout.output =~ "timed out after 10ms"
  end

  @tag :phase_120_upgrade_contract
  test "generated workspaces use OS-global temporary directory allocation" do
    first_root = Rindle.InstallSmoke.GeneratedApp.Workspace.create_root!()
    second_root = Rindle.InstallSmoke.GeneratedApp.Workspace.create_root!()

    on_exit(fn ->
      Rindle.InstallSmoke.GeneratedApp.Workspace.cleanup(%{workspace_root: first_root})
      Rindle.InstallSmoke.GeneratedApp.Workspace.cleanup(%{workspace_root: second_root})
    end)

    assert first_root != second_root
    assert File.dir?(first_root)
    assert File.dir?(second_root)
    assert Path.dirname(first_root) == Path.expand(System.tmp_dir!())
    assert Path.dirname(second_root) == Path.expand(System.tmp_dir!())

    assert :ok = Rindle.InstallSmoke.GeneratedApp.Workspace.cleanup(%{workspace_root: first_root})
    refute File.exists?(first_root)
    assert :ok = Rindle.InstallSmoke.GeneratedApp.Workspace.cleanup(%{workspace_root: first_root})

    assert :ok =
             Rindle.InstallSmoke.GeneratedApp.Workspace.cleanup(%{workspace_root: second_root})

    refute File.exists?(second_root)

    assert :ok =
             Rindle.InstallSmoke.GeneratedApp.Workspace.cleanup(%{workspace_root: second_root})
  end

  @tag :phase_120_upgrade_contract
  test "upgrade catalog policy rejects missing marker, foreign key, and named indexes" do
    report = valid_isolation_upgrade_catalog_report()

    assert GeneratedAppHelper.isolation_upgrade_catalog_preserved?(report)

    refute GeneratedAppHelper.isolation_upgrade_catalog_preserved?(%{
             report
             | marker_versions: []
           })

    refute GeneratedAppHelper.isolation_upgrade_catalog_preserved?(%{
             report
             | media_variants_foreign_key: nil
           })

    for index_name <- [
          "media_variants_asset_id_name_index",
          "media_variants_state_index",
          "media_variants_output_kind_index"
        ] do
      refute GeneratedAppHelper.isolation_upgrade_catalog_preserved?(%{
               report
               | media_variants_indexes:
                   Enum.reject(report.media_variants_indexes, &(&1["name"] == index_name))
             })
    end

    for index_name <- [
          "media_variants_asset_id_name_index",
          "media_variants_state_index",
          "media_variants_output_kind_index"
        ] do
      refute GeneratedAppHelper.isolation_upgrade_catalog_preserved?(%{
               report
               | media_variants_indexes:
                   Enum.map(report.media_variants_indexes, fn index ->
                     if index["name"] == index_name,
                       do: %{
                         index
                         | "definition" => "CREATE INDEX unrelated_index ON rindle.unrelated (id)"
                       },
                       else: index
                   end)
             })
    end
  end

  @tag :phase_120_upgrade_contract
  test "upgrade catalog policy rejects each public Oban catalog change" do
    report = valid_isolation_upgrade_catalog_report()

    assert GeneratedAppHelper.isolation_upgrade_catalog_preserved?(report)

    for {field, replacement} <- [
          {:identity, %{"oid" => 999, "schema" => "public", "name" => "oban_jobs"}},
          {:columns, [%{"name" => "id", "type" => "integer"}]},
          {:constraints,
           [
             %{
               "name" => "oban_jobs_queue_check",
               "type" => "c",
               "definition" => "CHECK (queue <> '')"
             }
           ]},
          {:indexes,
           [
             %{
               "schema" => "public",
               "name" => "oban_jobs_queue_index",
               "primary" => false,
               "unique" => false,
               "definition" =>
                 "CREATE INDEX oban_jobs_queue_index ON public.oban_jobs USING btree (queue)"
             }
           ]}
        ] do
      changed_after = Map.put(report.oban_jobs_after, field, replacement)

      refute GeneratedAppHelper.isolation_upgrade_catalog_preserved?(%{
               report
               | oban_jobs_after: changed_after
             })
    end
  end

  defp valid_isolation_upgrade_catalog_report do
    %{
      marker_versions: [1],
      media_variants_foreign_key: %{
        "name" => "media_variants_asset_id_fkey",
        "type" => "f",
        "source_schema" => "rindle",
        "source_table" => "media_variants",
        "source_column" => "asset_id",
        "target_schema" => "rindle",
        "target_table" => "media_assets",
        "target_column" => "id",
        "definition" =>
          "FOREIGN KEY (asset_id) REFERENCES rindle.media_assets(id) ON DELETE CASCADE"
      },
      media_variants_indexes: [
        %{
          "name" => "media_variants_asset_id_name_index",
          "definition" =>
            "CREATE UNIQUE INDEX media_variants_asset_id_name_index ON rindle.media_variants USING btree (asset_id, name)"
        },
        %{
          "name" => "media_variants_state_index",
          "definition" =>
            "CREATE INDEX media_variants_state_index ON rindle.media_variants USING btree (state)"
        },
        %{
          "name" => "media_variants_output_kind_index",
          "definition" =>
            "CREATE INDEX media_variants_output_kind_index ON rindle.media_variants USING btree (output_kind)"
        }
      ],
      oban_jobs_before: valid_oban_jobs_snapshot(),
      oban_jobs_after: valid_oban_jobs_snapshot()
    }
  end

  defp valid_oban_jobs_snapshot do
    %{
      identity: %{"oid" => 42, "schema" => "public", "name" => "oban_jobs"},
      columns: [
        %{
          "name" => "id",
          "type" => "bigint",
          "nullable" => false,
          "default" => nil,
          "identity" => "",
          "generated" => ""
        }
      ],
      constraints: [
        %{"name" => "oban_jobs_pkey", "type" => "p", "definition" => "PRIMARY KEY (id)"}
      ],
      indexes: [
        %{
          "schema" => "public",
          "name" => "oban_jobs_pkey",
          "primary" => true,
          "unique" => true,
          "definition" =>
            "CREATE UNIQUE INDEX oban_jobs_pkey ON public.oban_jobs USING btree (id)"
        }
      ]
    }
  end
end

if GeneratedAppHelper.profile_enabled?(:gcs) and
     GeneratedAppHelper.phase_120_scenario_enabled?(:default) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeGCSTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:gcs)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the GCS-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app exposes a first-class GCS path with doctor and resumable status proof surfaces",
         %{report: report} do
      assert_host_owned_migrations!(report)
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
      assert report.doctor_command =~ "mix rindle.doctor"
      assert report.gcs_status_surface == "Rindle.resumable_session_status/2"
    end

    test "generated Phoenix app proves the live GCS resumable lifecycle only when bucket secrets are present",
         %{report: report} do
      if report.gcs_live_enabled? do
        assert report.doctor_success?
        assert report.gcs_status_state == "complete"
        assert is_integer(report.gcs_status_committed_bytes)
        assert report.gcs_status_committed_bytes > 0
        assert report.gcs_asset_state_after_verify == "validating"
        assert report.gcs_asset_state_after_promote in ["available", "processing", "ready"]
        assert is_binary(report.gcs_upload_key)
      else
        refute report.doctor_success?
        assert is_nil(report.gcs_status_state)
        assert is_nil(report.gcs_asset_state_after_promote)
      end
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:image) and
     GeneratedAppHelper.phase_120_scenario_enabled?(:phase_120_public_compat) do
  defmodule Rindle.InstallSmoke.GeneratedAppPublicCompatibilityTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions

    @moduletag :minio
    @moduletag :phase_120_public_compat

    setup_all do
      report = GeneratedAppHelper.prove_public_compatibility_install!()
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app proves the explicit public compatibility build without runtime retargeting",
         %{report: report} do
      assert_install_source!(report)
      assert_host_owned_migrations!(report)
      assert report.scenario == :public_compatibility
      assert report.compile_prefix == "public"
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?

      assert Enum.all?(report.selected_schema_relations, fn {_relation, exists?} -> exists? end)
      assert Enum.all?(report.decoy_schema_relations, fn {_relation, exists?} -> not exists? end)
      assert report.public_host_relations == %{"oban_jobs" => true, "schema_migrations" => true}
      assert report.rindle_migration_path =~ "install_rindle"
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:image) and
     GeneratedAppHelper.phase_120_scenario_enabled?(:phase_120_isolation_upgrade) do
  defmodule Rindle.InstallSmoke.GeneratedAppIsolationUpgradeTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions

    @moduletag :minio
    @moduletag :phase_120_isolation_upgrade

    setup_all do
      report = GeneratedAppHelper.prove_isolation_upgrade!()
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated public and default builds preserve populated Rindle state through the host-owned move",
         %{report: report} do
      assert_install_source!(report)
      assert_host_owned_migrations!(report)
      assert report.scenario == :isolation_upgrade
      assert report.public_compile_prefix == "public"
      assert report.default_compile_prefix == "rindle"
      assert report.public_generated_app_root != report.generated_app_root
      assert report.marker_versions == [1], inspect(report)

      assert report.media_variants_foreign_key == %{
               "name" => "media_variants_asset_id_fkey",
               "type" => "f",
               "source_schema" => "rindle",
               "source_table" => "media_variants",
               "source_column" => "asset_id",
               "target_schema" => "rindle",
               "target_table" => "media_assets",
               "target_column" => "id",
               "definition" => report.media_variants_foreign_key["definition"]
             },
             inspect(report)

      assert Enum.map(report.media_variants_indexes, & &1["name"]) == [
               "media_variants_asset_id_name_index",
               "media_variants_state_index",
               "media_variants_output_kind_index"
             ],
             inspect(report)

      assert Enum.all?(report.media_variants_indexes, &is_binary(&1["definition"])),
             inspect(report)

      assert report.oban_jobs_before == report.oban_jobs_after, inspect(report)
      assert report.oban_jobs_before["identity"]["schema"] == "public"
      assert report.oban_jobs_before["identity"]["name"] == "oban_jobs"
      assert report.oban_jobs_before["columns"] != []
      assert report.oban_jobs_before["constraints"] != []
      assert report.oban_jobs_before["indexes"] != []
      assert GeneratedAppHelper.isolation_upgrade_catalog_preserved?(report), inspect(report)
      assert report.doctor_ready?
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?

      assert Enum.all?(report.selected_schema_relations, fn {_relation, exists?} -> exists? end)
      assert Enum.all?(report.decoy_schema_relations, fn {_relation, exists?} -> not exists? end)
      assert report.public_host_relations == %{"oban_jobs" => true, "schema_migrations" => true}
      assert String.contains?(report.host_migration_paths["host_root"], "/priv/repo/migrations")
      assert String.contains?(report.host_migration_paths["oban"], "install_host_owned_oban")
      assert String.contains?(report.host_migration_paths["rindle"], "install_rindle")
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:image) and
     GeneratedAppHelper.phase_120_scenario_enabled?(:default) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeImageTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:image)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs Rindle from the configured package source and never falls back to repo-local deps",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated image consumer reaches the compiled boot and report boundary through the stable facade",
         %{report: report} do
      assert report.profile_mode == :image
      assert report.compile_prefix == "rindle"
      assert report.compile_exit_code == 0
      assert report.boot_exit_code == 0
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
    end

    test "generated Phoenix app runs host plus Rindle migrations explicitly and proves the canonical presigned PUT lifecycle",
         %{report: report} do
      assert_host_owned_migrations!(report)
      assert_default_schema_ownership!(report)
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?

      lifecycle = report.persistence_lifecycle
      assert lifecycle["initiated_session_id"] == lifecycle["verified_session_id"]
      assert lifecycle["asset_id"] == lifecycle["read_back_asset_id"]
      assert lifecycle["asset_state"] in ["available", "processing", "ready"]
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:video) and
     GeneratedAppHelper.phase_120_scenario_enabled?(:default) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeVideoTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:video)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the AV-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app proves the canonical AV path with web_720p, poster, and signed delivery",
         %{report: report} do
      assert_host_owned_migrations!(report)
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
      assert report.av_ready_variants == ["poster", "web_720p"]
      assert is_binary(report.av_playback_storage_key)
      assert String.contains?(report.av_playback_storage_key, "web_720p")
      assert is_binary(report.av_delivery_path)
      assert String.contains?(report.av_delivery_path, report.av_playback_storage_key)
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:tus) and
     GeneratedAppHelper.phase_120_scenario_enabled?(:default) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeTusTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:tus)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the tus-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app proves a real-socket tus-js-client drop-and-resume flow against MinIO",
         %{report: report} do
      assert_host_owned_migrations!(report)
      assert report.smoke_exit_code == 0, tus_failure_details(report)
      assert report.lifecycle_proved?, tus_failure_details(report)
      assert report.phoenix_helper_uploader == "RindleTus"

      assert report.phoenix_helper_endpoint == "/uploads/tus" or
               String.contains?(report.phoenix_helper_endpoint || "", "/uploads/tus")

      assert is_binary(report.phoenix_helper_upload_url)
      assert String.contains?(report.phoenix_helper_upload_url, "/uploads/tus/")
      assert is_binary(report.phoenix_helper_session_id)
      assert is_binary(report.phoenix_helper_asset_id)
      assert report.completion_surface == "consume_uploaded_entries->verify_completion"
      assert report.phoenix_state_sequence == ["uploading", "verifying", "ready"]

      assert if(report.tus_failure_phase in [nil, "none"],
               do: is_nil(report.phoenix_error_state),
               else: report.phoenix_error_state == "error"
             )

      assert is_binary(report.tus_upload_url)
      assert String.contains?(report.tus_upload_url, "/uploads/tus/")
      assert report.tus_previous_uploads >= 1
      assert report.tus_byte_size >= 200 * 1024 * 1024
      assert report.tus_content_type == "video/mp4"
      assert report.tus_ready_variants == ["poster", "web_720p"]

      assert is_map(report.extensions), tus_failure_details(report)

      assert report.tus_report_data["extensions"] == report.extensions,
             tus_failure_details(report)

      extensions = report.extensions
      concatenation = extensions["concatenation"] || %{}
      creation_defer_length = extensions["creation_defer_length"] || %{}
      checksum = extensions["checksum"] || %{}

      assert concatenation["proved"] == true, tus_failure_details(report)
      assert concatenation["parallel_uploads"] == 2, tus_failure_details(report)
      assert concatenation["status"] in [201, 204], tus_failure_details(report)

      assert creation_defer_length["proved"] == true, tus_failure_details(report)

      assert creation_defer_length["used_upload_defer_length"] == true,
             tus_failure_details(report)

      assert creation_defer_length["status"] == 204, tus_failure_details(report)

      assert checksum["proved"] == true, tus_failure_details(report)
      assert checksum["algorithm"] in ["sha1", "sha256"], tus_failure_details(report)
      assert checksum["status"] == 204, tus_failure_details(report)
      assert_tus_guide_parity!()
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:mux) and
     GeneratedAppHelper.phase_120_scenario_enabled?(:default) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeMuxTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:mux)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the Mux-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app proves the canonical AV path PLUS Mux-signed HLS streaming URL via cassette",
         %{report: report} do
      assert_host_owned_migrations!(report)
      assert report.smoke_exit_code == 0, report.smoke_output
      assert report.lifecycle_proved?
      assert report.av_ready_variants == ["poster", "web_720p"]
      assert is_binary(report.av_playback_storage_key)
      assert String.contains?(report.av_playback_storage_key, "web_720p")
      assert is_binary(report.delivery_path)
      assert report.streaming_url_kind == "hls"
      assert String.contains?(report.delivery_path, ".m3u8")
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:video) and
     GeneratedAppHelper.phase_120_scenario_enabled?(:default) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeUpgradeTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_upgrade_install!()
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app upgrades a pre-v1.4 image-only adopter through the public migration path",
         %{report: report} do
      assert_install_source!(report)
      assert_host_owned_migrations!(report)
      assert report.legacy_migration_cutoff == "20260428110000"
      assert String.ends_with?(report.legacy_rindle_migration_path, "/priv/repo/migrations")
      refute report.legacy_current_marker_preinstalled?
      assert report.legacy_asset_kind == "image"
      assert report.legacy_asset_profile =~ ".RindleProfile"
      assert report.legacy_asset_upgrade_safe?

      assert Enum.map(report.legacy_ready_variants, & &1["name"]) == ["thumb"]
      assert Enum.map(report.legacy_ready_variants, & &1["output_kind"]) == ["image"]
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
    end

    test "generated Phoenix app proves doctor, runtime-status, and asset-scoped cancelled-work requeue after upgrade",
         %{report: report} do
      assert report.doctor_passed?
      assert "cancelled_work" in report.runtime_status_classes
      assert "requeue" in report.runtime_status_recommendation_actions
      assert "Rindle.requeue_variants/2" in report.runtime_status_recommendation_surfaces
      assert report.requeue_selected == 1
      assert report.requeue_enqueued + report.requeue_skipped == 1
      assert report.repaired_variant_state == "ready"
      assert report.ready_sibling_state == "ready"

      assert Enum.map(report.canonical_upgrade_step_sequence, & &1.proof) == [
               "FFmpeg >= 6.0",
               "Application.app_dir(:rindle, \"priv/repo/migrations\")",
               "mix rindle.doctor",
               "mix rindle.runtime_status",
               "Rindle.requeue_variants/2",
               "mix rindle.regenerate_variants"
             ]
    end
  end
end
