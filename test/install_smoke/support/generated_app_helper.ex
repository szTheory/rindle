defmodule Rindle.InstallSmoke.GeneratedAppHelper do
  @moduledoc false

  @png_1x1 <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
             0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02,
             0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44,
             0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02,
             0xFE, 0xDC, 0x44, 0x74, 0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
             0xAE, 0x42, 0x60, 0x82>>

  @host_migration_version "20260428170000"

  def prove_package_install! do
    workspace_root =
      Path.join(System.tmp_dir!(), "rindle-install-smoke-#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)

    app_name = "rindle_smoke_app"
    app_module = Macro.camelize(app_name)
    package_root = Path.join(workspace_root, "package/#{package_name()}")
    generated_app_root = Path.join(workspace_root, app_name)
    db_name = "#{app_name}_#{System.unique_integer([:positive])}_test"
    shared_env = shared_env(db_name)

    build_package!(workspace_root, package_root)
    generate_phoenix_app!(workspace_root, generated_app_root)
    patch_generated_app!(generated_app_root, app_name, app_module, package_root)
    _ = run_cmd!(generated_app_root, ["mix", "deps.get"], shared_env)
    compile_result = run_cmd!(generated_app_root, ["mix", "compile"], shared_env)
    _ = run_cmd!(generated_app_root, ["mix", "ecto.create"], shared_env)
    _ = run_cmd!(generated_app_root, ["mix", "run", "--no-start", "priv/install_smoke/migrate.exs"], shared_env)
    migration_report = read_json!(Path.join(generated_app_root, "tmp/install_smoke_migration_report.json"))
    boot_result = boot_app!(generated_app_root, app_module, shared_env)
    smoke_result = run_cmd!(generated_app_root, ["mix", "test", "test/rindle_install_smoke_test.exs"], shared_env)

    %{
      workspace_root: workspace_root,
      generated_app_root: generated_app_root,
      package_root: package_root,
      database_name: db_name,
      compile_exit_code: compile_result.exit_code,
      boot_exit_code: boot_result.exit_code,
      smoke_exit_code: smoke_result.exit_code,
      host_migration_ran?: migration_report["host_migration_ran"] == true,
      migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
      rindle_migration_path: migration_report["rindle_migration_path"],
      lifecycle_proved?: smoke_result.exit_code == 0 and String.contains?(smoke_result.output, "2 tests, 0 failures")
    }
  end

  def cleanup(%{generated_app_root: generated_app_root} = report) do
    _ = generated_app_root
    File.rm_rf(report.workspace_root)
    :ok
  end

  def cleanup(_report), do: :ok

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

  defp patch_generated_app!(root, app_name, app_module, package_root) do
    patch_mix_exs!(root, package_root)
    patch_test_config!(root, app_name)
    patch_runtime_config!(root, app_name, app_module)
    patch_application!(root, app_name, app_module)
    write_profile!(root, app_name, app_module)
    write_host_migration!(root)
    write_migration_runner!(root, app_name, app_module)
    write_smoke_test!(root, app_module)
    write_fixture!(root)
  end

  defp patch_mix_exs!(root, package_root) do
    path = Path.join(root, "mix.exs")
    oban_requirement = oban_requirement()

    updated =
      path
      |> File.read!()
      |> String.replace(
        "{:bandit, \"~> 1.5\"}",
        """
        {:bandit, "~> 1.5"},
              {:oban, "#{oban_requirement}"},
              {:hackney, "~> 1.20"},
              {:rindle, path: #{inspect(package_root)}}
        """
      )

    File.write!(path, updated)
  end

  defp patch_test_config!(root, app_name) do
    path = Path.join(root, "config/test.exs")

    updated =
      path
      |> File.read!()
      |> String.replace(~r/username: "postgres"/, "username: System.get_env(\"PGUSER\") || System.get_env(\"USER\") || \"postgres\"")
      |> String.replace(~r/password: "postgres"/, "password: System.get_env(\"PGPASSWORD\")")
      |> String.replace(~r/hostname: "localhost"/, "hostname: System.get_env(\"PGHOST\") || \"localhost\"")
      |> String.replace(
        ~r/database: "#{app_name}_test#\{System.get_env\("MIX_TEST_PARTITION"\)\}"/,
        "database: System.fetch_env!(\"RINDLE_INSTALL_SMOKE_DB\")"
      )
      |> Kernel.<>(
        """

        config :#{app_name}, Oban,
          repo: #{Macro.camelize(app_name)}.Repo,
          testing: :manual,
          queues: false

        config :#{app_name}, #{Macro.camelize(app_name)}.Repo,
          migration_primary_key: [type: :binary_id],
          migration_timestamps: [type: :utc_datetime_usec]

        config :rindle, :repo, #{Macro.camelize(app_name)}.Repo
        """
      )

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
      queues: false
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
      """
    )
  end

  defp write_host_migration!(root) do
    path = Path.join(root, "priv/repo/migrations/#{@host_migration_version}_create_install_smoke_markers.exs")

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

  defp write_smoke_test!(root, app_module) do
    path = Path.join(root, "test/rindle_install_smoke_test.exs")

    File.write!(
      path,
      """
      defmodule #{app_module}.RindleInstallSmokeTest do
        use #{app_module}.DataCase, async: false
        use Oban.Testing, repo: #{app_module}.Repo

        alias #{app_module}.Repo
        alias #{app_module}.RindleProfile
        alias Rindle.Domain.MediaAsset
        alias Rindle.Domain.MediaVariant
        alias Rindle.Upload.Broker
        alias Rindle.Workers.{ProcessVariant, PromoteAsset}

        @moduletag :minio

        @png_1x1 #{inspect(@png_1x1)}

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

        test "generated app completes the canonical presigned PUT lifecycle" do
          assert {:ok, result} =
                   Repo.query("select to_regclass('public.install_smoke_markers')::text")

          assert result.rows == [["install_smoke_markers"]]

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
      end
      """
    )
  end

  defp write_fixture!(root) do
    File.mkdir_p!(Path.join(root, "tmp"))
    File.write!(Path.join(root, "tmp/generated-app.png"), @png_1x1)
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
      {"PGUSER", System.get_env("PGUSER") || System.get_env("USER") || "postgres"},
      {"PGPASSWORD", System.get_env("PGPASSWORD")},
      {"PGHOST", System.get_env("PGHOST") || "localhost"},
      {"PGPORT", System.get_env("PGPORT") || "5432"},
      {"RINDLE_MINIO_URL", System.get_env("RINDLE_MINIO_URL") || "http://localhost:9000"},
      {"RINDLE_MINIO_BUCKET", System.get_env("RINDLE_MINIO_BUCKET") || "rindle-test"},
      {"RINDLE_MINIO_ACCESS_KEY", System.get_env("RINDLE_MINIO_ACCESS_KEY") || "minioadmin"},
      {"RINDLE_MINIO_SECRET_KEY", System.get_env("RINDLE_MINIO_SECRET_KEY") || "minioadmin"},
      {"RINDLE_MINIO_REGION", System.get_env("RINDLE_MINIO_REGION") || "us-east-1"}
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp package_name do
    "#{Mix.Project.config()[:app]}-#{Mix.Project.config()[:version]}"
  end

  defp repo_root do
    File.cwd!()
  end

  defp oban_requirement do
    case Mix.Dep.Lock.read()[:oban] do
      {:hex, :oban, version, _checksum, _managers, _deps, _repo, _outer_checksum} ->
        "~> #{version}"

      other ->
        raise "unexpected Oban lock entry: #{inspect(other)}"
    end
  end

  defp to_existing_atom_safe(nil), do: nil
  defp to_existing_atom_safe(value) when is_binary(value), do: String.to_atom(value)
end
