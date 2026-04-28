defmodule Rindle.InstallSmoke.PackageMetadataTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @preflight_script Path.join(@repo_root, "scripts/release_preflight.sh")
  @docs_assertion_script Path.join(@repo_root, "scripts/assert_release_docs_html.sh")
  @required_paths [
    "mix.exs",
    "README.md",
    "LICENSE",
    "guides/getting_started.md",
    "guides/release_publish.md"
  ]
  @prohibited_paths ["_build", ".planning", "test", ".github", "coveralls.json"]

  setup_all do
    package_root = build_package!()
    metadata_path = Path.join(package_root, "hex_metadata.config")

    on_exit(fn ->
      File.rm_rf(Path.dirname(package_root))
    end)

    {:ok,
     %{
       package_root: package_root,
       metadata: File.read!(metadata_path),
       script: File.read!(@preflight_script),
       docs_assertion_script: File.read!(@docs_assertion_script)
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
      "MIX_ENV=dev mix hex.build --unpack",
      "MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs",
      "MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs",
      "MIX_ENV=test bash scripts/install_smoke.sh",
      "MIX_ENV=dev mix docs --warnings-as-errors",
      "bash scripts/assert_release_docs_html.sh"
    ]

    positions = Enum.map(commands, &command_position(script, &1))

    assert Enum.all?(positions, &is_integer/1)
    assert positions == Enum.sort(positions)

    refute script =~ "HEX_API_KEY"
    refute script =~ "mix hex.publish"
  end

  test "docs HTML assertion script checks generated navigation and adopter boundary", %{
    docs_assertion_script: script
  } do
    assert script =~ "release_publish.html"
    assert script =~ "sidebar_items-*.js"
    assert script =~ ~s("id":"release_publish")
    assert script =~ "operations.html"
    assert script =~ "readme.html"
    assert script =~ "getting_started.html"
    assert script =~ "HEX_API_KEY|mix hex\\.user|mix hex\\.owner"
  end

  defp build_package! do
    output_root =
      Path.join(System.tmp_dir!(), "rindle-package-metadata-#{System.unique_integer([:positive])}")

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

    package_root
  end

  defp command_position(script, command) do
    case :binary.match(script, command) do
      {position, _length} -> position
      :nomatch -> nil
    end
  end
end
