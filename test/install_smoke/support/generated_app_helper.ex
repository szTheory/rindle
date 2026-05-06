defmodule Rindle.InstallSmoke.GeneratedAppHelper do
  @moduledoc false
  alias Mix.Dep.Lock

  @png_1x1 <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
             0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
             0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
             0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
             0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>

  @host_migration_version "20260428170000"
  @legacy_rindle_migration_version 20_260_428_110_000

  def profile_enabled?(profile_mode) when profile_mode in [:image, :video] do
    selected_profiles()
    |> Enum.member?(profile_mode)
  end

  def prove_package_install!(profile_mode \\ :image) when profile_mode in [:image, :video] do
    network_version = System.get_env("RINDLE_INSTALL_SMOKE_NETWORK_VERSION")
    install_mode = install_mode(network_version)

    workspace_root =
      Path.join(System.tmp_dir!(), "rindle-install-smoke-#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)

    app_name = "rindle_smoke_app"
    app_module = Macro.camelize(app_name)

    package_root =
      System.get_env("RINDLE_INSTALL_SMOKE_PACKAGE_ROOT") ||
        Path.join(workspace_root, "package/#{package_name()}")

    generated_app_root = Path.join(workspace_root, app_name)
    db_name = "#{app_name}_#{System.unique_integer([:positive])}_test"
    shared_env = shared_env(db_name)

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
      profile_mode
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
      read_json!(Path.join(generated_app_root, "tmp/install_smoke_migration_report.json"))

    boot_result = boot_app!(generated_app_root, app_module, shared_env)

    smoke_result =
      run_cmd!(
        generated_app_root,
        ["mix", "test", "test/rindle_install_smoke_test.exs"],
        shared_env
      )

    deps_rindle_present? = File.exists?(Path.join(generated_app_root, "deps/rindle"))
    av_report_path = Path.join(generated_app_root, "tmp/install_smoke_av_report.json")
    av_report = if File.exists?(av_report_path), do: read_json!(av_report_path), else: %{}

    %{
      workspace_root: workspace_root,
      generated_app_root: generated_app_root,
      package_root: package_root,
      database_name: db_name,
      profile_mode: profile_mode,
      install_mode: install_mode,
      install_source: install_source(install_mode, package_root, network_version),
      compile_exit_code: compile_result.exit_code,
      boot_exit_code: boot_result.exit_code,
      smoke_exit_code: smoke_result.exit_code,
      network_mode?: install_mode == :network,
      deps_rindle_present?: deps_rindle_present?,
      host_migration_ran?: migration_report["host_migration_ran"] == true,
      migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
      rindle_migration_path: migration_report["rindle_migration_path"],
      smoke_output: smoke_result.output,
      av_ready_variants: av_report["ready_variants"] || [],
      av_playback_storage_key: av_report["playback_storage_key"],
      av_delivery_path: av_report["delivery_path"],
      lifecycle_proved?:
        smoke_result.exit_code == 0 and String.contains?(smoke_result.output, "0 failures")
    }
  end

  def prove_upgrade_install! do
    network_version = System.get_env("RINDLE_INSTALL_SMOKE_NETWORK_VERSION")
    install_mode = install_mode(network_version)

    workspace_root =
      Path.join(System.tmp_dir!(), "rindle-install-smoke-#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)

    app_name = "rindle_smoke_app"
    app_module = Macro.camelize(app_name)

    package_root =
      System.get_env("RINDLE_INSTALL_SMOKE_PACKAGE_ROOT") ||
        Path.join(workspace_root, "package/#{package_name()}")

    generated_app_root = Path.join(workspace_root, app_name)
    db_name = "#{app_name}_#{System.unique_integer([:positive])}_test"
    shared_env = shared_env(db_name)

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
      :video
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
      migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
      rindle_migration_path: migration_report["rindle_migration_path"],
      legacy_migration_cutoff: legacy_seed["legacy_rindle_migration_version"],
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

  def cleanup(%{generated_app_root: generated_app_root} = report) do
    _ = generated_app_root
    File.rm_rf(report.workspace_root)
    :ok
  end

  def cleanup(_report), do: :ok

  defp ensure_package!(workspace_root, package_root) do
    if File.dir?(package_root) do
      :ok
    else
      build_package!(workspace_root, package_root)
    end
  end

  defp build_package!(workspace_root, package_root) do
    File.mkdir_p!(Path.join(workspace_root, "package"))

    _ =
      run_cmd!(
        repo_root(),
        ["mix", "hex.build", "--unpack", "--output", package_root],
        [{"MIX_ENV", "dev"}]
      )
  end

  defp generate_phoenix_app!(workspace_root, generated_app_root) do
    _ =
      run_cmd!(
        workspace_root,
        [
          "mix",
          "phx.new",
          generated_app_root,
          "--no-assets",
          "--no-dashboard",
          "--no-mailer",
          "--no-gettext",
          "--install"
        ],
        [{"MIX_ENV", "dev"}]
      )
  end

  defp patch_generated_app!(
         root,
         app_name,
         app_module,
         package_root,
         network_version,
         profile_mode
       ) do
    patch_mix_exs!(root, package_root, network_version)
    patch_test_config!(root, app_name)
    patch_runtime_config!(root, app_name, app_module)
    patch_application!(root, app_name, app_module)
    write_profile!(root, app_name, app_module)
    write_host_migration!(root)
    write_migration_runner!(root, app_name, app_module)
    write_legacy_upgrade_preparer!(root, app_module)
    write_smoke_test!(root, app_module, profile_mode)
    write_fixture!(root, profile_mode)
  end

  defp patch_mix_exs!(root, package_root, network_version) do
    path = Path.join(root, "mix.exs")
    oban_requirement = oban_requirement()

    rindle_dep =
      if network_version do
        "{:rindle, \"~> #{network_version}\"}"
      else
        "{:rindle, path: #{inspect(package_root)}}"
      end

    updated =
      path
      |> File.read!()
      |> String.replace(
        "{:bandit, \"~> 1.5\"}",
        """
        {:bandit, "~> 1.5"},
              {:oban, "#{oban_requirement}"},
              {:hackney, "~> 1.20"},
              #{rindle_dep}
        """
      )

    File.write!(path, updated)
  end

  defp patch_test_config!(root, app_name) do
    path = Path.join(root, "config/test.exs")

    updated =
      path
      |> File.read!()
      |> String.replace(
        ~r/username: "postgres"/,
        "username: System.get_env(\"PGUSER\") || System.get_env(\"USER\") || \"postgres\""
      )
      |> String.replace(~r/password: "postgres"/, "password: System.get_env(\"PGPASSWORD\")")
      |> String.replace(
        ~r/hostname: "localhost"/,
        "hostname: System.get_env(\"PGHOST\") || \"localhost\""
      )
      |> String.replace(
        ~r/database: "#{app_name}_test#\{System.get_env\("MIX_TEST_PARTITION"\)\}"/,
        "database: System.fetch_env!(\"RINDLE_INSTALL_SMOKE_DB\")"
      )
      |> Kernel.<>("""

      config :#{app_name}, Oban,
        repo: #{Macro.camelize(app_name)}.Repo,
        testing: :manual,
        queues: [
          rindle_media: 1,
          rindle_promote: 1,
          rindle_process: 1,
          rindle_purge: 1,
          rindle_maintenance: 1
        ]

      config :#{app_name}, #{Macro.camelize(app_name)}.Repo,
        migration_primary_key: [type: :binary_id],
        migration_timestamps: [type: :utc_datetime_usec]

      config :rindle, :repo, #{Macro.camelize(app_name)}.Repo
      """)

    File.write!(path, updated)
  end

  defp patch_runtime_config!(root, app_name, app_module) do
    path = Path.join(root, "config/runtime.exs")

    runtime_append = """

    minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
    bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")
    access_key = System.get_env("RINDLE_MINIO_ACCESS_KEY", "minioadmin")
    secret_key = System.get_env("RINDLE_MINIO_SECRET_KEY", "minioadmin")
    region = System.get_env("RINDLE_MINIO_REGION", "us-east-1")

    %URI{host: host, port: port, scheme: scheme} = URI.parse(minio_url)

    config :rindle, :repo, #{app_module}.Repo
    config :rindle, Rindle.Storage.S3, bucket: bucket

    config :ex_aws, :s3,
      scheme: "\#{scheme}://",
      host: host,
      port: port,
      region: region,
      access_key_id: access_key,
      secret_access_key: secret_key

    config :#{app_name}, Oban,
      repo: #{app_module}.Repo,
      testing: :manual,
      queues: [
        rindle_media: 1,
        rindle_promote: 1,
        rindle_process: 1,
        rindle_purge: 1,
        rindle_maintenance: 1
      ]
    """

    File.write!(path, File.read!(path) <> runtime_append)
  end

  defp patch_application!(root, app_name, app_module) do
    path = Path.join(root, "lib/#{app_name}/application.ex")

    updated =
      path
      |> File.read!()
      |> String.replace(
        "#{app_module}.Repo,",
        "#{app_module}.Repo,\n      {Oban, Application.fetch_env!(:#{app_name}, Oban)},"
      )

    File.write!(path, updated)
  end

  defp write_profile!(root, app_name, app_module) do
    path = Path.join(root, "lib/#{app_name}/rindle_profile.ex")

    File.write!(
      path,
      """
      defmodule #{app_module}.RindleProfile do
        @moduledoc false

        use Rindle.Profile,
          storage: Rindle.Storage.S3,
          variants: [thumb: [mode: :fit, width: 64, height: 64]],
          allow_mime: ["image/png", "image/jpeg"],
          max_bytes: 10_485_760
      end

      defmodule #{app_module}.VideoProfile do
        @moduledoc false

        use Rindle.Profile.Presets.Web,
          storage: Rindle.Storage.S3,
          allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
          max_bytes: 524_288_000
      end
      """
    )
  end

  defp write_host_migration!(root) do
    path =
      Path.join(
        root,
        "priv/repo/migrations/#{@host_migration_version}_create_install_smoke_markers.exs"
      )

    File.write!(
      path,
      """
      defmodule RindleSmokeApp.Repo.Migrations.CreateInstallSmokeMarkers do
        use Ecto.Migration

        def change do
          create table(:install_smoke_markers) do
            add :name, :string, null: false

            timestamps()
          end
        end
      end
      """
    )
  end

  defp write_migration_runner!(root, _app_name, app_module) do
    path = Path.join(root, "priv/install_smoke/migrate.exs")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      Application.ensure_all_started(:rindle)
      {:ok, _pid} = #{app_module}.Repo.start_link()

      host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
      rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")

      unless File.dir?(rindle_path) do
        raise "Rindle migration path missing: \#{rindle_path}"
      end

      {:ok, _, _} =
        Ecto.Migrator.with_repo(#{app_module}.Repo, fn repo ->
          for path <- [host_path, rindle_path] do
            Ecto.Migrator.run(repo, path, :up, all: true)
          end
        end)

      {:ok, result} =
        #{app_module}.Repo.query(
          "select to_regclass('public.install_smoke_markers')::text"
        )

      File.mkdir_p!("tmp")

      File.write!(
        "tmp/install_smoke_migration_report.json",
        Jason.encode!(%{
          resolver: "application_app_dir",
          host_migration_ran: result.rows == [["install_smoke_markers"]],
          rindle_migration_path: rindle_path
        })
      )
      """
    )
  end

  defp write_legacy_upgrade_preparer!(root, app_module) do
    path = Path.join(root, "priv/install_smoke/prepare_upgrade.exs")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      Application.ensure_all_started(:rindle)
      {:ok, _pid} = #{app_module}.Repo.start_link()

      host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
      rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")
      legacy_cutoff = #{@legacy_rindle_migration_version}

      {:ok, _, _} =
        Ecto.Migrator.with_repo(#{app_module}.Repo, fn repo ->
          Ecto.Migrator.run(repo, host_path, :up, all: true)
          Ecto.Migrator.run(repo, rindle_path, :up, to: legacy_cutoff)
        end)

      legacy_asset_id = Ecto.UUID.generate()
      legacy_variant_id = Ecto.UUID.generate()
      legacy_session_id = Ecto.UUID.generate()
      legacy_asset_db_id = Ecto.UUID.dump!(legacy_asset_id)
      legacy_variant_db_id = Ecto.UUID.dump!(legacy_variant_id)
      legacy_session_db_id = Ecto.UUID.dump!(legacy_session_id)
      recipe_digest = #{app_module}.RindleProfile.recipe_digest(:thumb)
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_assets (
          id, state, storage_key, content_type, byte_size, filename, metadata,
          recipe_digest, profile, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        \"\"\",
        [
          legacy_asset_db_id,
          "ready",
          "legacy/assets/image-only-thumb.png",
          "image/png",
          68,
          "legacy-thumb.png",
          %{"upgrade_seed" => true},
          recipe_digest,
          "#{app_module}.RindleProfile",
          now,
          now
        ]
      )

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_variants (
          id, asset_id, name, state, recipe_digest, storage_key, generated_at,
          byte_size, content_type, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        \"\"\",
        [
          legacy_variant_db_id,
          legacy_asset_db_id,
          "thumb",
          "ready",
          recipe_digest,
          "legacy/variants/thumb.png",
          now,
          68,
          "image/png",
          now,
          now
        ]
      )

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_upload_sessions (
          id, asset_id, state, upload_key, expires_at, verified_at, failure_reason,
          upload_strategy, multipart_upload_id, multipart_parts, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        \"\"\",
        [
          legacy_session_db_id,
          legacy_asset_db_id,
          "completed",
          "legacy/uploads/image-only-thumb.png",
          expires_at,
          expires_at,
          nil,
          "presigned_put",
          nil,
          %{},
          now,
          now
        ]
      )

      File.mkdir_p!("tmp")

      File.write!(
        "tmp/install_smoke_upgrade_seed.json",
        Jason.encode!(%{
          legacy_rindle_migration_version: Integer.to_string(legacy_cutoff),
          legacy_asset_id: legacy_asset_id,
          legacy_variant_id: legacy_variant_id,
          legacy_session_id: legacy_session_id
        })
      )
      """
    )
  end

  defp write_smoke_test!(root, app_module, profile_mode) do
    path = Path.join(root, "test/rindle_install_smoke_test.exs")
    lifecycle_test = lifecycle_test_source(app_module, profile_mode)
    upgrade_test = upgrade_test_source(app_module)

    File.write!(
      path,
      """
      defmodule #{app_module}.RindleInstallSmokeTest do
        use #{app_module}.DataCase, async: false
        use Oban.Testing, repo: #{app_module}.Repo

        import ExUnit.CaptureIO
        import Ecto.Query

        alias Oban.Job
        alias #{app_module}.Repo
        alias #{app_module}.RindleProfile
        alias #{app_module}.VideoProfile
        alias Mix.Tasks.Rindle.{Doctor, RuntimeStatus}
        alias Rindle.Domain.MediaAsset
        alias Rindle.Domain.MediaVariant
        alias Rindle.Upload.Broker
        alias Rindle.Workers.{ProcessVariant, PromoteAsset}

        @moduletag :minio

        @png_1x1 #{inspect(@png_1x1, limit: :infinity)}

        setup do
          case :inets.start() do
            :ok -> :ok
            {:error, {:already_started, :inets}} -> :ok
          end

          :ok
        end

        test "generated app boots with adopter repo ownership and default Oban wiring" do
          assert Application.fetch_env!(:rindle, :repo) == Repo
          assert Application.fetch_env!(:rindle_smoke_app, Oban)[:repo] == Repo
          assert File.dir?(Application.app_dir(:rindle, "priv/repo/migrations"))
          refute File.exists?(Path.join(File.cwd!(), "deps/rindle"))
        end

      #{lifecycle_test}

      if File.exists?(Path.expand("../tmp/install_smoke_upgrade_seed.json", __DIR__)) do
      #{upgrade_test}
      end

        defp assert_install_smoke_marker! do
          assert {:ok, result} =
                   Repo.query("select to_regclass('public.install_smoke_markers')::text")

          assert result.rows == [["install_smoke_markers"]]
        end

        defp put_to_presigned_url(presigned_url, body) do
          request = {String.to_charlist(presigned_url), [], ~c"application/octet-stream", body}

          case :httpc.request(:put, request, [], []) do
            {:ok, {{_http_version, status, _reason}, _headers, _body}} when status in 200..299 ->
              :ok

            {:ok, {{_http_version, status, reason}, _headers, response_body}} ->
              flunk("presigned PUT failed with status \#{status} \#{reason}: \#{inspect(response_body)}")

            {:error, reason} ->
              flunk("presigned PUT failed: \#{inspect(reason)}")
          end
        end

        defp read_upgrade_seed! do
          "tmp/install_smoke_upgrade_seed.json"
          |> File.read!()
          |> Jason.decode!()
        end

        defp write_upgrade_report!(report) do
          File.mkdir_p!("tmp")
          File.write!("tmp/install_smoke_upgrade_report.json", Jason.encode!(report))
        end
      end
      """
    )
  end

  defp write_fixture!(root, profile_mode) do
    File.mkdir_p!(Path.join(root, "tmp"))
    File.write!(Path.join(root, "tmp/generated-app.png"), @png_1x1)

    if profile_mode == :video do
      File.cp!(video_fixture_path(), Path.join(root, "tmp/generated-app-video.webm"))
    end
  end

  defp boot_app!(generated_app_root, app_module, env) do
    run_cmd!(
      generated_app_root,
      [
        "mix",
        "run",
        "--no-start",
        "-e",
        "Application.ensure_all_started(:#{Macro.underscore(app_module)}); repo = Application.fetch_env!(:rindle, :repo); oban_repo = Application.fetch_env!(:#{Macro.underscore(app_module)}, Oban)[:repo]; if repo != #{app_module}.Repo or oban_repo != #{app_module}.Repo, do: raise(\"boot wiring invalid\"); IO.puts(\"boot ok\")"
      ],
      env
    )
  end

  defp read_json!(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  defp run_cmd!(cwd, argv, env) do
    case run_cmd(cwd, argv, env) do
      %{exit_code: 0} = result ->
        result

      %{exit_code: exit_code, output: output} ->
        raise """
        command failed (#{exit_code}): #{Enum.join(argv, " ")}
        cwd: #{cwd}

        #{output}
        """
    end
  end

  defp run_cmd(cwd, argv, env) do
    {output, exit_code} =
      System.cmd(List.first(argv), tl(argv),
        cd: cwd,
        env: env,
        stderr_to_stdout: true,
        into: ""
      )

    %{output: output, exit_code: exit_code}
  end

  defp shared_env(db_name) do
    [
      {"MIX_ENV", "test"},
      {"RINDLE_INSTALL_SMOKE_DB", db_name},
      {"PGUSER", env_or_default("PGUSER", System.get_env("USER") || "postgres")},
      {"PGPASSWORD", System.get_env("PGPASSWORD")},
      {"PGHOST", env_or_default("PGHOST", "localhost")},
      {"PGPORT", env_or_default("PGPORT", "5432")},
      {"RINDLE_MINIO_URL", env_or_default("RINDLE_MINIO_URL", "http://localhost:9000")},
      {"RINDLE_MINIO_BUCKET", env_or_default("RINDLE_MINIO_BUCKET", "rindle-test")},
      {"RINDLE_MINIO_ACCESS_KEY", env_or_default("RINDLE_MINIO_ACCESS_KEY", "minioadmin")},
      {"RINDLE_MINIO_SECRET_KEY", env_or_default("RINDLE_MINIO_SECRET_KEY", "minioadmin")},
      {"RINDLE_MINIO_REGION", env_or_default("RINDLE_MINIO_REGION", "us-east-1")}
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp package_name do
    "#{Mix.Project.config()[:app]}-#{Mix.Project.config()[:version]}"
  end

  defp install_mode(nil), do: :package
  defp install_mode(_network_version), do: :network

  defp install_source(:package, package_root, _network_version), do: package_root
  defp install_source(:network, _package_root, network_version), do: "hex:#{network_version}"

  defp repo_root do
    File.cwd!()
  end

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

  defp fetch_deps!(generated_app_root, shared_env, network_version) do
    if network_version do
      retry_network_deps_get!(generated_app_root, shared_env)
    else
      _ = run_cmd!(generated_app_root, ["mix", "deps.get"], shared_env)
    end
  end

  defp retry_network_deps_get!(generated_app_root, shared_env) do
    Enum.reduce_while(1..30, :error, fn attempt, _acc ->
      case run_cmd(generated_app_root, ["mix", "deps.get"], shared_env) do
        %{exit_code: 0} ->
          {:halt, :ok}

        _ when attempt == 30 ->
          raise "deps.get failed after 30 attempts"

        _ ->
          Process.sleep(10_000)
          {:cont, :error}
      end
    end)
  end

  defp selected_profiles do
    case System.get_env("RINDLE_INSTALL_SMOKE_PROFILE", "all") do
      "all" -> [:image, :video]
      "image" -> [:image]
      "video" -> [:video]
      other -> raise "unsupported RINDLE_INSTALL_SMOKE_PROFILE: #{inspect(other)}"
    end
  end

  defp lifecycle_test_source(_app_module, :image) do
    """
        test "generated app completes the canonical presigned PUT lifecycle" do
          assert_install_smoke_marker!()

          {:ok, session} = Broker.initiate_session(RindleProfile, filename: "generated-app.png")
          {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
          assert signed.state == "signed"

          :ok = put_to_presigned_url(presigned.url, @png_1x1)

          {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
          assert completed.state == "completed"
          assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
          assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

          asset = Repo.get!(MediaAsset, asset.id)
          assert asset.state in ["available", "processing", "ready"]

          variants = Repo.all(from variant in MediaVariant, where: variant.asset_id == ^asset.id)
          assert variants != []

          for variant <- variants do
            assert :ok =
                     perform_job(ProcessVariant, %{
                       "asset_id" => asset.id,
                       "variant_name" => variant.name
                     })
          end

          ready_variants = Repo.all(from variant in MediaVariant, where: variant.asset_id == ^asset.id)
          assert Enum.all?(ready_variants, &(&1.state == "ready"))

          {:ok, signed_url} = Rindle.Delivery.url(RindleProfile, asset.storage_key)
          assert String.contains?(signed_url, asset.storage_key)
        end
    """
  end

  defp lifecycle_test_source(_app_module, :video) do
    """
        test "generated app proves the canonical AV upload, processing, playback-ready variants, and signed delivery path" do
          assert_install_smoke_marker!()
          assert :presigned_put in VideoProfile.storage_adapter().capabilities()

          fixture_path = Path.expand("../tmp/generated-app-video.webm", __DIR__)

          {:ok, session} = Rindle.initiate_upload(VideoProfile, filename: "generated-app-video.webm")
          {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
          assert signed.state == "signed"

          :ok = put_to_presigned_url(presigned.url, File.read!(fixture_path))

          {:ok, %{session: completed, asset: asset}} = Rindle.verify_completion(session.id)
          assert completed.state == "completed"
          assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
          assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

          promoted_asset = Repo.get!(MediaAsset, asset.id)
          assert promoted_asset.kind == "video"
          assert promoted_asset.has_video_track == true
          assert promoted_asset.has_audio_track == true
          assert promoted_asset.duration_ms > 0

          variants =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          assert Enum.map(variants, & &1.name) == ["poster", "web_720p"]

          for variant <- variants do
            assert :ok =
                     perform_job(ProcessVariant, %{
                       "asset_id" => asset.id,
                       "variant_name" => variant.name
                     })
          end

          ready_variants =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          assert Enum.map(ready_variants, &{&1.name, &1.output_kind, &1.state}) == [
                   {"poster", "image", "ready"},
                   {"web_720p", "video", "ready"}
                 ]

          poster_variant = Enum.find(ready_variants, &(&1.name == "poster"))
          web_variant = Enum.find(ready_variants, &(&1.name == "web_720p"))

          assert is_binary(poster_variant.storage_key) and poster_variant.byte_size > 0
          assert is_binary(web_variant.storage_key) and web_variant.byte_size > 0
          assert String.contains?(web_variant.storage_key, "web_720p")

          {:ok, signed_url} = Rindle.url(VideoProfile, web_variant.storage_key)
          assert String.contains?(signed_url, web_variant.storage_key)

          File.mkdir_p!("tmp")

          File.write!(
            "tmp/install_smoke_av_report.json",
            Jason.encode!(%{
              ready_variants: Enum.map(ready_variants, & &1.name),
              playback_storage_key: web_variant.storage_key,
              delivery_path: URI.parse(signed_url).path
            })
          )
        end
    """
  end

  defp upgrade_test_source(app_module) do
    """
        test "generated app upgrades a legacy adopter, diagnoses degraded AV work, and repairs one asset-scoped variant" do
          assert_install_smoke_marker!()

          seed = read_upgrade_seed!()
          legacy_asset = Repo.get!(MediaAsset, seed["legacy_asset_id"])

          assert legacy_asset.profile == "#{app_module}.RindleProfile"
          assert legacy_asset.kind == "image"
          assert legacy_asset.state == "ready"
          assert legacy_asset.content_type == "image/png"
          assert is_nil(legacy_asset.duration_ms)
          assert is_nil(legacy_asset.has_video_track)
          assert is_nil(legacy_asset.has_audio_track)

          legacy_variants = Rindle.ready_variants_for(legacy_asset)

          assert Enum.map(legacy_variants, &{&1.name, &1.output_kind, &1.state}) == [
                   {"thumb", "image", "ready"}
                 ]

          doctor_output =
            capture_io(fn ->
              {:ok, migration_statuses, _apps} =
                Ecto.Migrator.with_repo(
                  Repo,
                  fn repo ->
                    Ecto.Migrator.migrations(
                      repo,
                      Application.app_dir(:rindle, "priv/repo/migrations")
                    )
                  end,
                  mode: :temporary
                )

              filtered_migration_statuses =
                Enum.reject(migration_statuses, fn
                  {:up, #{@host_migration_version}, "** FILE NOT FOUND **"} -> true
                  _other -> false
                end)

              report =
                Doctor.run_checks(
                  [inspect(VideoProfile)],
                  exit_on_failure?: false,
                  migration_statuses: filtered_migration_statuses
                )
              IO.puts("doctor_success=\#{report.success?}")
            end)

          assert doctor_output =~ "Rindle: running environment checks..."
          assert doctor_output =~ "doctor_success=true", doctor_output

          fixture_path = Path.expand("../tmp/generated-app-video.webm", __DIR__)

          {:ok, session} = Rindle.initiate_upload(VideoProfile, filename: "upgrade-proof-video.webm")
          {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
          assert signed.state == "signed"

          :ok = put_to_presigned_url(presigned.url, File.read!(fixture_path))

          {:ok, %{session: completed, asset: asset}} = Rindle.verify_completion(session.id)
          assert completed.state == "completed"
          assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

          ready_variants =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          for variant <- ready_variants do
            assert :ok =
                     perform_job(ProcessVariant, %{
                       "asset_id" => asset.id,
                       "variant_name" => variant.name
                     })
          end

          [poster_variant, web_variant] =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          assert {poster_variant.name, poster_variant.state, poster_variant.output_kind} ==
                   {"poster", "ready", "image"}

          assert {web_variant.name, web_variant.state, web_variant.output_kind} ==
                   {"web_720p", "ready", "video"}

          {1, _} =
            Repo.update_all(
              from(variant in MediaVariant, where: variant.id == ^web_variant.id),
              set: [
                state: "cancelled",
                storage_key: nil,
                generated_at: nil,
                byte_size: nil,
                content_type: nil,
                duration_ms: nil,
                width: nil,
                height: nil,
                error_reason: inspect(:variant_processing_cancelled)
              ]
            )

          cancelled_variant = Repo.get!(MediaVariant, web_variant.id)
          ready_sibling = Repo.get!(MediaVariant, poster_variant.id)

          assert cancelled_variant.state == "cancelled"
          assert ready_sibling.state == "ready"

          {deleted_jobs, _} =
            Repo.delete_all(
              from job in Job,
                where: job.worker == "Rindle.Workers.ProcessVariant",
                where: fragment("?->>'asset_id' = ?", job.args, ^asset.id),
                where: fragment("?->>'variant_name' = ?", job.args, ^"web_720p"),
                where:
                  job.state in ^Enum.map(ProcessVariant.active_job_states(), &Atom.to_string/1)
            )

          assert is_integer(deleted_jobs)

          runtime_status_output =
            capture_io(fn ->
              RuntimeStatus.run([
                "--format",
                "json",
                "--limit",
                "5"
              ])
            end)

          runtime_report = Jason.decode!(runtime_status_output)

          assert Enum.any?(runtime_report["variants"]["findings"], fn finding ->
                   finding["class"] == "cancelled_work"
                 end)

          assert Enum.any?(runtime_report["recommendations"], fn recommendation ->
                   recommendation["action"] == "requeue" and
                     recommendation["surface"] == "Rindle.requeue_variants/2"
                 end)

          assert {:ok, requeue_report} =
                   Rindle.requeue_variants(asset.id, variant_names: ["web_720p"])

          assert requeue_report.selected == 1
          assert requeue_report.enqueued == 1
          assert requeue_report.skipped == 0
          assert requeue_report.errors == 0
          assert ready_sibling.state == "ready"

          assert :ok =
                   perform_job(ProcessVariant, %{
                     "asset_id" => asset.id,
                     "variant_name" => "web_720p"
                   })

          repaired_variant = Repo.get!(MediaVariant, web_variant.id)
          poster_after = Repo.get!(MediaVariant, poster_variant.id)

          assert repaired_variant.state == "ready"
          assert repaired_variant.output_kind == "video"
          assert is_binary(repaired_variant.storage_key)
          assert poster_after.state == "ready"

          write_upgrade_report!(%{
            legacy_asset: %{
              id: legacy_asset.id,
              profile: legacy_asset.profile,
              kind: legacy_asset.kind,
              upgrade_safe: true,
              ready_variants: Enum.map(legacy_variants, &%{
                name: &1.name,
                output_kind: &1.output_kind,
                state: &1.state
              })
            },
            doctor: %{
              success: true
            },
            runtime_status: %{
              classes: Enum.map(runtime_report["variants"]["findings"], & &1["class"]),
              recommendation_actions: Enum.map(runtime_report["recommendations"], & &1["action"]),
              recommendation_surfaces: Enum.map(runtime_report["recommendations"], & &1["surface"])
            },
            requeue: %{
              selected: requeue_report.selected,
              enqueued: requeue_report.enqueued,
              skipped: requeue_report.skipped,
              repaired_variant_state: repaired_variant.state,
              ready_sibling_state: poster_after.state
            }
          })
        end
    """
  end

  defp video_fixture_path do
    Path.join(repo_root(), "test/support/fixtures/smartphone/android_capture.webm")
  end

  defp env_or_default(name, default), do: System.get_env(name) || default
end
