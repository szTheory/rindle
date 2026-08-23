Code.require_file("generated_app/contracts.ex", __DIR__)
Code.require_file("generated_app/command_runner.ex", __DIR__)
Code.require_file("generated_app/workspace.ex", __DIR__)
Code.require_file("generated_app/patcher.ex", __DIR__)
Code.require_file("generated_app/migrations.ex", __DIR__)
Code.require_file("generated_app/smoke_source.ex", __DIR__)
Code.require_file("generated_app/profile_helpers.ex", __DIR__)

defmodule Rindle.InstallSmoke.GeneratedAppHelper do
  @moduledoc false
  alias Mix.Dep.Lock
  alias Rindle.InstallSmoke.GeneratedApp.CommandRunner
  alias Rindle.InstallSmoke.GeneratedApp.Contracts
  alias Rindle.InstallSmoke.GeneratedApp.Migrations
  alias Rindle.InstallSmoke.GeneratedApp.Patcher
  alias Rindle.InstallSmoke.GeneratedApp.ProfileHelpers
  alias Rindle.InstallSmoke.GeneratedApp.SmokeSource
  alias Rindle.InstallSmoke.GeneratedApp.Workspace

  @host_migration_version "20260428170000"
  @host_oban_migration_version "20260428170100"
  @rindle_migration_version "20260428170200"
  @directional_migration_version "20260428170300"
  @legacy_rindle_migration_version 20_260_428_110_000
  @generated_command_timeout_ms :timer.minutes(20)

  defdelegate default_install_contract(), to: Contracts
  defdelegate persistence_lifecycle_report_keys(), to: Contracts
  defdelegate tus_outcome_contract(), to: Contracts
  defdelegate public_compatibility_contract(), to: Contracts
  defdelegate isolation_upgrade_contract(), to: Contracts
  defdelegate legacy_upgrade_contract(), to: Contracts
  defdelegate isolation_upgrade_catalog_preserved?(report), to: Contracts

  def profile_enabled?(profile_mode) when profile_mode in [:image, :video, :tus, :mux, :gcs],
    do: Contracts.profile_enabled?(profile_mode)

  def phase_120_scenario_enabled?(scenario, included_tags \\ nil),
    do: Contracts.phase_120_scenario_enabled?(scenario, included_tags)

  def prove_package_install!(profile_mode \\ :image)
      when profile_mode in [:image, :video, :tus, :mux, :gcs] do
    prove_package_install!(profile_mode, [])
  end

  def prove_public_compatibility_install! do
    contract = public_compatibility_contract()

    prove_package_install!(:image,
      app_name: contract.app_name,
      compile_prefix: contract.compile_prefix,
      migration_report_name: contract.report_identity,
      scenario: contract.scenario
    )
  end

  def prove_isolation_upgrade! do
    public_report = prove_public_compatibility_install!()
    public_env = shared_env(public_report.database_name, :image)

    _ =
      run_cmd!(
        public_report.generated_app_root,
        ["mix", "run", "--no-start", "priv/install_smoke/seed_isolation_upgrade.exs"],
        public_env
      )

    seed =
      read_json!(Path.join(public_report.generated_app_root, "tmp/isolation_upgrade_seed.json"))

    default_contract = isolation_upgrade_contract()
    default_root = Path.join(public_report.workspace_root, default_contract.default_app_name)
    default_module = Macro.camelize(default_contract.default_app_name)
    network_version = System.get_env("RINDLE_INSTALL_SMOKE_NETWORK_VERSION")

    generate_phoenix_app!(public_report.workspace_root, default_root)

    patch_generated_app!(
      default_root,
      default_contract.default_app_name,
      default_module,
      public_report.package_root,
      network_version,
      :image,
      migration_kind: :directional_upgrade,
      migration_report_name: "isolation_upgrade_migration_report.json"
    )

    fetch_deps!(default_root, public_env, network_version)
    compile_result = run_cmd!(default_root, ["mix", "compile"], public_env)

    _ =
      run_cmd!(
        default_root,
        ["mix", "run", "--no-start", "priv/install_smoke/migrate.exs"],
        public_env
      )

    migration_report =
      read_json!(Path.join(default_root, "tmp/isolation_upgrade_migration_report.json"))

    doctor_result =
      run_cmd(
        default_root,
        ["mix", "rindle.doctor", "#{default_module}.RindleProfile"],
        public_env
      )

    boot_result = boot_app!(default_root, default_module, public_env)

    smoke_result =
      run_cmd(default_root, ["mix", "test", "test/rindle_install_smoke_test.exs"], public_env)

    persistence_lifecycle =
      read_json!(Path.join(default_root, "tmp/install_smoke_persistence_lifecycle_report.json"))

    %{
      workspace_root: public_report.workspace_root,
      generated_app_root: default_root,
      public_generated_app_root: public_report.generated_app_root,
      package_root: public_report.package_root,
      database_name: public_report.database_name,
      scenario: :isolation_upgrade,
      profile_mode: :image,
      public_compile_prefix: public_report.compile_prefix,
      default_compile_prefix: "rindle",
      install_mode: public_report.install_mode,
      network_mode?: public_report.network_mode?,
      install_source: public_report.install_source,
      package_root_provenance: public_report.package_root_provenance,
      compile_exit_code: compile_result.exit_code,
      boot_exit_code: boot_result.exit_code,
      smoke_exit_code: smoke_result.exit_code,
      deps_rindle_present?: File.exists?(Path.join(default_root, "deps/rindle")),
      host_migration_ran?: migration_report["host_migration_ran"] == true,
      host_oban_migration_ran?: migration_report["host_oban_migration_ran"] == true,
      rindle_migration_ran?: migration_report["rindle_migration_ran"] == true,
      migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
      rindle_migration_path: migration_report["rindle_migration_path"],
      selected_schema_relations: migration_report["selected_schema_relations"] || %{},
      decoy_schema_relations: migration_report["decoy_schema_relations"] || %{},
      public_host_relations: migration_report["public_host_relations"] || %{},
      host_migration_paths: migration_report["host_migration_paths"] || %{},
      persistence_lifecycle: persistence_lifecycle,
      seeded_asset_id: seed["asset_id"],
      seeded_variant_id: seed["variant_id"],
      marker_versions: migration_report["marker_versions"] || [],
      media_variants_foreign_key: migration_report["media_variants_foreign_key"],
      media_variants_indexes: migration_report["media_variants_indexes"] || [],
      oban_jobs_before: migration_report["oban_jobs_before"] || %{},
      oban_jobs_after: migration_report["oban_jobs_after"] || %{},
      doctor_ready?: smoke_result.exit_code == 0,
      doctor_output: doctor_result.output,
      lifecycle_proved?: successful_lifecycle?(smoke_result)
    }
  end

  defp prove_package_install!(profile_mode, options) do
    network_version = System.get_env("RINDLE_INSTALL_SMOKE_NETWORK_VERSION")
    install_mode = install_mode(network_version)

    workspace_root = create_workspace_root!()

    app_name =
      Keyword.get(options, :app_name, ProfileHelpers.install_smoke_app_name(profile_mode))

    app_module = Macro.camelize(app_name)

    package_root =
      System.get_env("RINDLE_INSTALL_SMOKE_PACKAGE_ROOT") ||
        Path.join(workspace_root, "package/#{package_name()}")

    generated_app_root = Path.join(workspace_root, app_name)
    db_name = "#{app_name}_#{System.system_time(:microsecond)}_test"
    shared_env = shared_env(db_name, profile_mode)

    if is_nil(network_version) do
      ensure_package!(workspace_root, package_root)
    end

    generate_phoenix_app!(workspace_root, generated_app_root)

    patch_generated_app!(
      generated_app_root,
      app_name,
      app_module,
      package_root,
      network_version,
      profile_mode,
      options
    )

    fetch_deps!(generated_app_root, shared_env, network_version)

    compile_result = run_cmd!(generated_app_root, ["mix", "compile"], shared_env)
    _ = run_cmd!(generated_app_root, ["mix", "ecto.create"], shared_env)

    _ =
      run_cmd!(
        generated_app_root,
        ["mix", "run", "--no-start", "priv/install_smoke/migrate.exs"],
        shared_env
      )

    migration_report =
      read_json!(
        Path.join(
          generated_app_root,
          "tmp/#{Keyword.get(options, :migration_report_name, "install_smoke_migration_report.json")}"
        )
      )

    boot_result = boot_app!(generated_app_root, app_module, shared_env)

    smoke_result =
      run_cmd(
        generated_app_root,
        ["mix", "test", "test/rindle_install_smoke_test.exs"],
        shared_env
      )

    deps_rindle_present? = File.exists?(Path.join(generated_app_root, "deps/rindle"))
    av_report_path = Path.join(generated_app_root, "tmp/install_smoke_av_report.json")
    av_report = if File.exists?(av_report_path), do: read_json!(av_report_path), else: %{}
    tus_report_path = Path.join(generated_app_root, "tmp/install_smoke_tus_report.json")
    tus_report = if File.exists?(tus_report_path), do: read_json!(tus_report_path), else: %{}

    tus_debug_report_path =
      Path.join(generated_app_root, "tmp/install_smoke_tus_debug_report.json")

    tus_debug_report =
      if File.exists?(tus_debug_report_path), do: read_json!(tus_debug_report_path), else: %{}

    gcs_report_path = Path.join(generated_app_root, "tmp/install_smoke_gcs_report.json")
    gcs_report = if File.exists?(gcs_report_path), do: read_json!(gcs_report_path), else: %{}

    persistence_lifecycle_report_path =
      Path.join(generated_app_root, "tmp/install_smoke_persistence_lifecycle_report.json")

    persistence_lifecycle =
      if File.exists?(persistence_lifecycle_report_path),
        do: read_json!(persistence_lifecycle_report_path),
        else: %{}

    tus_extensions = normalize_tus_extensions(tus_report["extensions"])
    tus_report_data = Map.put(tus_report, "extensions", tus_extensions)

    report = %{
      workspace_root: workspace_root,
      generated_app_root: generated_app_root,
      package_root: package_root,
      database_name: db_name,
      profile_mode: profile_mode,
      scenario: Keyword.get(options, :scenario, :default),
      compile_prefix: Keyword.get(options, :compile_prefix, "rindle"),
      install_mode: install_mode,
      install_source: install_source(install_mode, package_root, network_version),
      package_root_provenance:
        package_root_provenance(install_mode, generated_app_root, package_root),
      compile_exit_code: compile_result.exit_code,
      boot_exit_code: boot_result.exit_code,
      smoke_exit_code: smoke_result.exit_code,
      network_mode?: install_mode == :network,
      deps_rindle_present?: deps_rindle_present?,
      host_migration_ran?: migration_report["host_migration_ran"] == true,
      host_oban_migration_ran?: migration_report["host_oban_migration_ran"] == true,
      rindle_migration_ran?: migration_report["rindle_migration_ran"] == true,
      migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
      rindle_migration_path: migration_report["rindle_migration_path"],
      selected_schema_relations: migration_report["selected_schema_relations"] || %{},
      decoy_schema_relations: migration_report["decoy_schema_relations"] || %{},
      public_host_relations: migration_report["public_host_relations"] || %{},
      host_migration_paths: migration_report["host_migration_paths"] || %{},
      persistence_lifecycle: persistence_lifecycle,
      smoke_output: smoke_result.output,
      av_ready_variants: av_report["ready_variants"] || [],
      av_playback_storage_key: av_report["playback_storage_key"],
      av_delivery_path: av_report["delivery_path"],
      delivery_path: av_report["delivery_path"],
      streaming_url_kind: av_report["streaming_url_kind"],
      tus_upload_url: tus_report_data["upload_url"],
      tus_previous_uploads: tus_report_data["previous_uploads"],
      tus_byte_size: tus_report_data["byte_size"],
      tus_content_type: tus_report_data["content_type"],
      tus_ready_variants: tus_report_data["ready_variants"] || [],
      phoenix_helper_uploader: tus_report_data["phoenix_helper_uploader"],
      phoenix_helper_endpoint: tus_report_data["phoenix_helper_endpoint"],
      phoenix_helper_upload_url: tus_report_data["phoenix_helper_upload_url"],
      phoenix_helper_session_id: tus_report_data["phoenix_helper_session_id"],
      phoenix_helper_asset_id: tus_report_data["phoenix_helper_asset_id"],
      completion_surface: tus_report_data["completion_surface"],
      phoenix_state_sequence: tus_report_data["phoenix_state_sequence"] || [],
      phoenix_error_state: tus_report_data["phoenix_error_state"],
      extensions: tus_extensions,
      tus_report_path: tus_report_path,
      tus_debug_report_path: tus_debug_report_path,
      tus_report_data: tus_report_data,
      tus_debug_report_data: tus_debug_report,
      tus_failure_phase: tus_debug_report["failure_phase"] || tus_report_data["failure_phase"],
      tus_failure_endpoint: tus_debug_report["endpoint"] || tus_report_data["endpoint"],
      tus_failure_summary:
        tus_debug_report["failure_summary"] || tus_report_data["failure_summary"],
      tus_failure_mode: tus_debug_report["failure_mode"] || tus_report_data["failure_mode"],
      doctor_command: gcs_report["doctor_command"],
      doctor_success?: gcs_report["doctor_success"] == true,
      gcs_live_enabled?: gcs_report["live_enabled"] == true,
      gcs_status_surface: gcs_report["status_surface"],
      gcs_status_state: gcs_report["status_state"],
      gcs_status_committed_bytes: gcs_report["status_committed_bytes"],
      gcs_asset_state_after_verify: gcs_report["asset_state_after_verify"],
      gcs_asset_state_after_promote: gcs_report["asset_state_after_promote"],
      gcs_upload_key: gcs_report["upload_key"],
      lifecycle_proved?:
        smoke_result.exit_code == 0 and String.contains?(smoke_result.output, "0 failures")
    }

    maybe_write_tus_run_hint!(report)
    report
  end

  defp normalize_tus_extensions(raw_extensions) when is_map(raw_extensions) do
    %{
      "concatenation" =>
        normalize_tus_extension(
          Map.get(raw_extensions, "concatenation") || Map.get(raw_extensions, :concatenation),
          %{"parallel_uploads" => nil, "status" => nil}
        ),
      "creation_defer_length" =>
        normalize_tus_extension(
          Map.get(raw_extensions, "creation_defer_length") ||
            Map.get(raw_extensions, :creation_defer_length),
          %{"used_upload_defer_length" => false, "status" => nil}
        ),
      "checksum" =>
        normalize_tus_extension(
          Map.get(raw_extensions, "checksum") || Map.get(raw_extensions, :checksum),
          %{"algorithm" => nil, "status" => nil}
        )
    }
  end

  defp normalize_tus_extensions(_raw_extensions) do
    %{
      "concatenation" =>
        normalize_tus_extension(nil, %{"parallel_uploads" => nil, "status" => nil}),
      "creation_defer_length" =>
        normalize_tus_extension(nil, %{"used_upload_defer_length" => false, "status" => nil}),
      "checksum" => normalize_tus_extension(nil, %{"algorithm" => nil, "status" => nil})
    }
  end

  defp normalize_tus_extension(raw_extension, defaults) when is_map(raw_extension) do
    normalized =
      Enum.into(raw_extension, %{}, fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        {key, value} -> {key, value}
      end)

    proved = normalized["proved"] == true

    defaults
    |> Map.put("proved", false)
    |> Map.merge(normalized)
    |> Map.put("proved", proved)
  end

  defp normalize_tus_extension(_raw_extension, defaults) do
    defaults
    |> Map.put("proved", false)
  end

  def prove_upgrade_install! do
    network_version = System.get_env("RINDLE_INSTALL_SMOKE_NETWORK_VERSION")
    install_mode = install_mode(network_version)
    upgrade_contract = legacy_upgrade_contract()

    workspace_root = create_workspace_root!()

    app_name = "rindle_smoke_app"
    app_module = Macro.camelize(app_name)

    package_root =
      System.get_env("RINDLE_INSTALL_SMOKE_PACKAGE_ROOT") ||
        Path.join(workspace_root, "package/#{package_name()}")

    generated_app_root = Path.join(workspace_root, app_name)
    db_name = "#{app_name}_#{System.system_time(:microsecond)}_test"
    shared_env = shared_env(db_name, :video)

    if is_nil(network_version) do
      ensure_package!(workspace_root, package_root)
    end

    generate_phoenix_app!(workspace_root, generated_app_root)

    patch_generated_app!(
      generated_app_root,
      app_name,
      app_module,
      package_root,
      network_version,
      :video,
      migration_kind: upgrade_contract.migration_kind
    )

    fetch_deps!(generated_app_root, shared_env, network_version)

    compile_result = run_cmd!(generated_app_root, ["mix", "compile"], shared_env)
    _ = run_cmd!(generated_app_root, ["mix", "ecto.create"], shared_env)

    _ =
      run_cmd!(
        generated_app_root,
        ["mix", "run", "--no-start", "priv/install_smoke/prepare_upgrade.exs"],
        shared_env
      )

    legacy_seed = read_json!(Path.join(generated_app_root, "tmp/install_smoke_upgrade_seed.json"))

    _ =
      run_cmd!(
        generated_app_root,
        ["mix", "run", "--no-start", "priv/install_smoke/migrate.exs"],
        shared_env
      )

    migration_report =
      read_json!(Path.join(generated_app_root, "tmp/install_smoke_migration_report.json"))

    boot_result = boot_app!(generated_app_root, app_module, shared_env)

    smoke_result =
      run_cmd!(
        generated_app_root,
        ["mix", "test", "test/rindle_install_smoke_test.exs"],
        shared_env
      )

    upgrade_report =
      read_json!(Path.join(generated_app_root, "tmp/install_smoke_upgrade_report.json"))

    deps_rindle_present? = File.exists?(Path.join(generated_app_root, "deps/rindle"))

    %{
      workspace_root: workspace_root,
      generated_app_root: generated_app_root,
      package_root: package_root,
      database_name: db_name,
      profile_mode: :upgrade,
      install_mode: install_mode,
      install_source: install_source(install_mode, package_root, network_version),
      compile_exit_code: compile_result.exit_code,
      boot_exit_code: boot_result.exit_code,
      smoke_exit_code: smoke_result.exit_code,
      network_mode?: install_mode == :network,
      deps_rindle_present?: deps_rindle_present?,
      host_migration_ran?: migration_report["host_migration_ran"] == true,
      host_oban_migration_ran?: migration_report["host_oban_migration_ran"] == true,
      rindle_migration_ran?: migration_report["rindle_migration_ran"] == true,
      migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
      rindle_migration_path: migration_report["rindle_migration_path"],
      legacy_rindle_migration_path: legacy_seed["legacy_rindle_migration_path"],
      legacy_migration_cutoff: legacy_seed["legacy_rindle_migration_version"],
      legacy_current_marker_preinstalled?:
        legacy_seed["current_rindle_marker_preinstalled"] == true,
      canonical_upgrade_step_sequence: canonical_upgrade_step_sequence(),
      legacy_asset_kind: get_in(upgrade_report, ["legacy_asset", "kind"]),
      legacy_asset_profile: get_in(upgrade_report, ["legacy_asset", "profile"]),
      legacy_asset_upgrade_safe?:
        get_in(upgrade_report, ["legacy_asset", "upgrade_safe"]) == true,
      legacy_ready_variants: get_in(upgrade_report, ["legacy_asset", "ready_variants"]) || [],
      doctor_passed?: get_in(upgrade_report, ["doctor", "success"]) == true,
      runtime_status_classes: get_in(upgrade_report, ["runtime_status", "classes"]) || [],
      runtime_status_recommendation_actions:
        get_in(upgrade_report, ["runtime_status", "recommendation_actions"]) || [],
      runtime_status_recommendation_surfaces:
        get_in(upgrade_report, ["runtime_status", "recommendation_surfaces"]) || [],
      requeue_selected: get_in(upgrade_report, ["requeue", "selected"]),
      requeue_enqueued: get_in(upgrade_report, ["requeue", "enqueued"]),
      requeue_skipped: get_in(upgrade_report, ["requeue", "skipped"]),
      repaired_variant_state: get_in(upgrade_report, ["requeue", "repaired_variant_state"]),
      ready_sibling_state: get_in(upgrade_report, ["requeue", "ready_sibling_state"]),
      smoke_output: smoke_result.output,
      lifecycle_proved?:
        smoke_result.exit_code == 0 and String.contains?(smoke_result.output, "0 failures")
    }
  end

  def canonical_upgrade_step_sequence do
    [
      %{
        checkpoint: "Confirm runtime ownership and AV prerequisites",
        proof: "FFmpeg >= 6.0"
      },
      %{
        checkpoint: "Run explicit host and packaged migrations",
        proof: "Application.app_dir(:rindle, \"priv/repo/migrations\")"
      },
      %{
        checkpoint: "Validate the upgraded runtime",
        proof: "mix rindle.doctor"
      },
      %{
        checkpoint: "Inspect degraded upgraded work when needed",
        proof: "mix rindle.runtime_status",
        optional: true
      },
      %{
        checkpoint: "Repair one upgraded asset through the public facade",
        proof: "Rindle.requeue_variants/2"
      },
      %{
        checkpoint: "Reserve broad drift repair for stale or missing variants",
        proof: "mix rindle.regenerate_variants"
      }
    ]
  end

  def cleanup(report), do: Workspace.cleanup(report)

  defp create_workspace_root!, do: Workspace.create_root!()

  defp ensure_package!(workspace_root, package_root),
    do: Workspace.ensure_package!(workspace_root, package_root)

  defp generate_phoenix_app!(workspace_root, generated_app_root),
    do: Workspace.generate_phoenix_app!(workspace_root, generated_app_root)

  defp patch_generated_app!(
         root,
         app_name,
         app_module,
         package_root,
         network_version,
         profile_mode,
         options
       ) do
    compile_prefix = Keyword.get(options, :compile_prefix, "rindle")

    Patcher.patch!(
      root,
      app_name,
      app_module,
      package_root,
      network_version,
      profile_mode,
      compile_prefix,
      oban_requirement(),
      System.get_env("RINDLE_MUX_USE_REAL_API") == "1"
    )

    Migrations.write!(
      root,
      app_module,
      compile_prefix,
      Keyword.get(options, :migration_kind, :install),
      Keyword.get(options, :migration_report_name, "install_smoke_migration_report.json"),
      %{
        host_migration: @host_migration_version,
        host_oban_migration: @host_oban_migration_version,
        rindle_migration: @rindle_migration_version,
        directional_migration: @directional_migration_version,
        legacy_rindle_migration: @legacy_rindle_migration_version
      }
    )

    write_smoke_test!(root, app_module, profile_mode, network_version)
    SmokeSource.write_fixture!(root, profile_mode)
  end

  defp read_json!(path), do: path |> File.read!() |> Jason.decode!()
  defp run_cmd!(cwd, argv, env), do: CommandRunner.run!(cwd, argv, env)

  defp run_cmd(cwd, argv, env),
    do: CommandRunner.run(cwd, argv, env, timeout_ms: @generated_command_timeout_ms)

  defp shared_env(db_name, profile_mode), do: Workspace.shared_env(db_name, profile_mode)
  defp package_name, do: Workspace.package_name()
  defp install_mode(network_version), do: Workspace.install_mode(network_version)

  def package_root_provenance(mode, generated_app_root, package_root),
    do: Workspace.package_root_provenance(mode, generated_app_root, package_root)

  defp install_source(mode, package_root, network_version),
    do: Workspace.install_source(mode, package_root, network_version)

  defp fetch_deps!(root, env, network_version),
    do: Workspace.fetch_deps!(root, env, network_version)

  defp oban_requirement do
    case Lock.read()[:oban] do
      {:hex, :oban, version, _checksum, _managers, _deps, _repo, _outer_checksum} ->
        "~> #{version}"

      other ->
        raise "unexpected Oban lock entry: #{inspect(other)}"
    end
  end

  defp to_existing_atom_safe(nil), do: nil
  defp to_existing_atom_safe(value) when is_binary(value), do: String.to_atom(value)

  defp successful_lifecycle?(result),
    do: result.exit_code == 0 and String.contains?(result.output, "0 failures")

  defp maybe_write_tus_run_hint!(report), do: SmokeSource.maybe_write_tus_run_hint!(report)

  defp boot_app!(root, app_module, env),
    do:
      run_cmd!(
        root,
        [
          "mix",
          "run",
          "--no-start",
          "-e",
          "Application.ensure_all_started(:#{Macro.underscore(app_module)}); repo = Application.fetch_env!(:rindle, :repo); oban_repo = Application.fetch_env!(:#{Macro.underscore(app_module)}, Oban)[:repo]; if repo != #{app_module}.Repo or oban_repo != #{app_module}.Repo, do: raise(\"boot wiring invalid\"); IO.puts(\"boot ok\")"
        ],
        env
      )

  defp write_smoke_test!(root, app_module, profile_mode, network_version) do
    SmokeSource.write!(
      root,
      app_module,
      profile_mode,
      network_version,
      ProfileHelpers.mux_test_imports(profile_mode),
      ProfileHelpers.profile_test_moduletag(profile_mode),
      ProfileHelpers.profile_test_helpers(app_module, profile_mode)
    )
  end
end
