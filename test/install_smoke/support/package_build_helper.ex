defmodule Rindle.InstallSmoke.PackageBuild do
  @moduledoc false
  import ExUnit.Assertions

  @repo_root Path.expand("../../..", __DIR__)

  @doc """
  Returns `{package_root, cleanup_root}` for the unpacked Hex package.

  `RINDLE_INSTALL_SMOKE_PACKAGE_ROOT` points at an already unpacked package (release
  preflight builds it once); `cleanup_root` is then `nil`. Otherwise the package is built
  with `mix hex.build --unpack` into a unique temp root that the caller removes.
  """
  def build_package! do
    case System.get_env("RINDLE_INSTALL_SMOKE_PACKAGE_ROOT") do
      package_root when is_binary(package_root) and package_root != "" ->
        assert File.exists?(package_root)
        {package_root, nil}

      _ ->
        output_root =
          Path.join(
            System.tmp_dir!(),
            "rindle-package-metadata-#{System.unique_integer([:positive])}"
          )

        package_root = Path.join(output_root, "rindle-#{Mix.Project.config()[:version]}")

        File.mkdir_p!(output_root)

        {output, 0} =
          System.cmd("mix", ["hex.build", "--unpack", "--output", package_root],
            cd: @repo_root,
            env: [{"MIX_ENV", "dev"}],
            stderr_to_stdout: true
          )

        assert output =~ "Building rindle"
        assert output =~ "Saved to"

        {package_root, output_root}
    end
  end
end
