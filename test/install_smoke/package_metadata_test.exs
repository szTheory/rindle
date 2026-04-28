defmodule Rindle.InstallSmoke.PackageMetadataTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @preflight_script Path.join(@repo_root, "scripts/release_preflight.sh")
  @required_paths [
    "mix.exs",
    "README.md",
    "LICENSE",
    "guides/getting_started.md",
    "guides/release_publish.md"
  ]
  @prohibited_paths ["_build", ".planning", "test", ".github", "coveralls.json"]

  setup_all do
    package_root = ensure_package!()
    metadata_path = Path.join(package_root, "hex_metadata.config")

    {:ok,
     %{
       package_root: package_root,
       metadata: File.read!(metadata_path),
       script: File.read!(@preflight_script)
     }}
  end

  test "unpacked metadata contains the expected identity and shipped paths", %{
    metadata: metadata,
    package_root: package_root
  } do
    assert metadata =~ ~s({<<"name">>,<<"rindle">>}.)
    assert metadata =~ ~s({<<"version">>,<<"#{Mix.Project.config()[:version]}">>}.)
    assert metadata =~ ~s({<<"licenses">>,[<<"MIT">>]}.)
    assert metadata =~ ~s({<<"GitHub">>,<<"https://github.com/szTheory/rindle">>})

    for rel_path <- @required_paths do
      assert metadata =~ ~s(<<"#{rel_path}">>)
      assert File.exists?(Path.join(package_root, rel_path))
    end
  end

  test "unpacked artifact excludes prohibited repo-only paths", %{package_root: package_root} do
    for rel_path <- @prohibited_paths do
      refute File.exists?(Path.join(package_root, rel_path))
    end
  end

  test "release preflight script runs the release gates in order", %{script: script} do
    commands = [
      "mix hex.build --unpack",
      "mix test test/install_smoke/package_metadata_test.exs",
      "mix test test/install_smoke/release_docs_parity_test.exs",
      "bash scripts/install_smoke.sh",
      "mix docs --warnings-as-errors"
    ]

    positions = Enum.map(commands, &command_position(script, &1))

    assert Enum.all?(positions, &is_integer/1)
    assert positions == Enum.sort(positions)

    refute script =~ "HEX_API_KEY"
    refute script =~ "mix hex.publish"
  end

  defp ensure_package! do
    package_root = package_root()

    if File.dir?(package_root) do
      package_root
    else
      {_, 0} =
        System.cmd("mix", ["hex.build", "--unpack"], cwd: @repo_root, env: [{"MIX_ENV", "dev"}])

      package_root
    end
  end

  defp package_root do
    Path.join(@repo_root, "rindle-#{Mix.Project.config()[:version]}")
  end

  defp command_position(script, command) do
    case :binary.match(script, command) do
      {position, _length} -> position
      :nomatch -> nil
    end
  end
end
