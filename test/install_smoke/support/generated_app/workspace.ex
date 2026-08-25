defmodule Rindle.InstallSmoke.GeneratedApp.Workspace do
  @moduledoc false

  alias Rindle.InstallSmoke.GeneratedApp.CommandRunner

  @doc false
  def create_root! do
    template = Path.join(System.tmp_dir!(), "rindle-install-smoke.XXXXXX")
    {path, 0} = System.cmd("mktemp", ["-d", template], stderr_to_stdout: true)
    String.trim(path)
  end

  @doc false
  def cleanup(%{workspace_root: workspace_root}) do
    File.rm_rf(workspace_root)
    :ok
  end

  def cleanup(_report), do: :ok

  @doc false
  def ensure_package!(workspace_root, package_root) do
    if File.dir?(package_root), do: :ok, else: build_package!(workspace_root, package_root)
  end

  @doc false
  def generate_phoenix_app!(workspace_root, generated_app_root) do
    CommandRunner.run!(
      workspace_root,
      [
        "mix",
        "phx.new",
        generated_app_root,
        "--no-assets",
        "--no-dashboard",
        "--no-mailer",
        "--no-gettext"
      ],
      [{"MIX_ENV", "dev"}]
    )
  end

  @doc false
  def fetch_deps!(generated_app_root, shared_env, network_version) do
    if network_version do
      retry_network_deps_get!(generated_app_root, shared_env)
    else
      CommandRunner.run!(generated_app_root, ["mix", "deps.get"], shared_env)
    end
  end

  @doc false
  def shared_env(db_name, profile_mode) do
    base_env = [
      {"MIX_ENV", "test"},
      {"RINDLE_AV_USE_CGROUPS", "false"},
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

    profile_env =
      case profile_mode do
        :mux -> build_mux_env()
        :gcs -> build_gcs_env()
        _other -> []
      end

    Enum.reject(base_env ++ profile_env, fn {_key, value} -> is_nil(value) end)
  end

  @doc false
  def install_mode(nil), do: :package
  def install_mode(_network_version), do: :network

  @doc false
  def package_root_provenance(:network, generated_app_root, _package_root) do
    fetched_package_root = Path.join(generated_app_root, "deps/rindle")

    %{
      path: fetched_package_root,
      unpacked?: File.dir?(fetched_package_root),
      repository_path_fallback?: false
    }
  end

  def package_root_provenance(:package, _generated_app_root, package_root) do
    %{path: package_root, unpacked?: File.dir?(package_root), repository_path_fallback?: false}
  end

  @doc false
  def install_source(:package, package_root, _network_version), do: package_root
  def install_source(:network, _package_root, network_version), do: "hex:#{network_version}"

  @doc false
  def package_name, do: "#{Mix.Project.config()[:app]}-#{Mix.Project.config()[:version]}"

  @doc false
  def repo_root, do: File.cwd!()

  defp build_package!(workspace_root, package_root) do
    File.mkdir_p!(Path.join(workspace_root, "package"))

    CommandRunner.run!(
      repo_root(),
      ["mix", "hex.build", "--unpack", "--output", package_root],
      [{"MIX_ENV", "dev"}]
    )
  end

  defp retry_network_deps_get!(generated_app_root, shared_env) do
    Enum.reduce_while(1..30, :error, fn attempt, _acc ->
      case CommandRunner.run(generated_app_root, ["mix", "deps.get"], shared_env) do
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

  defp build_mux_env do
    private_key_pem =
      System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY") ||
        File.read!("test/fixtures/mux/test_signing_private_key.pem")

    [
      {"RINDLE_MUX_TOKEN_ID", env_or_default("RINDLE_MUX_TOKEN_ID", "test-token-id")},
      {"RINDLE_MUX_TOKEN_SECRET", env_or_default("RINDLE_MUX_TOKEN_SECRET", "test-token-secret")},
      {"RINDLE_MUX_SIGNING_KEY_ID",
       env_or_default("RINDLE_MUX_SIGNING_KEY_ID", "test-signing-key-id")},
      {"RINDLE_MUX_SIGNING_PRIVATE_KEY", private_key_pem},
      {"RINDLE_MUX_WEBHOOK_SECRETS",
       env_or_default(
         "RINDLE_MUX_WEBHOOK_SECRETS",
         "whsec_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
       )},
      {"RINDLE_MUX_USE_REAL_API", System.get_env("RINDLE_MUX_USE_REAL_API")},
      {"RINDLE_MUX_PASSTHROUGH_TAG", System.get_env("RINDLE_MUX_PASSTHROUGH_TAG")}
    ]
  end

  defp build_gcs_env do
    [
      {"GOOGLE_APPLICATION_CREDENTIALS_JSON",
       System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")},
      {"RINDLE_GCS_BUCKET", System.get_env("RINDLE_GCS_BUCKET")},
      {"RINDLE_INSTALL_SMOKE_GCS_PREFIX", System.get_env("RINDLE_INSTALL_SMOKE_GCS_PREFIX")},
      {"RINDLE_INSTALL_SMOKE_GCS_CLEANUP_FILE",
       System.get_env("RINDLE_INSTALL_SMOKE_GCS_CLEANUP_FILE")}
    ]
  end

  defp env_or_default(name, default), do: System.get_env(name) || default
end
