Code.require_file("support/package_build_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.ArtifactPackageSetTest do
  use ExUnit.Case, async: true

  alias Rindle.InstallSmoke.PackageBuild

  # async-safety: justified — the only File mutation is `File.rm_rf(cleanup_root)` in on_exit,
  # where `cleanup_root` is the unique per-build tmp root returned by
  # `PackageBuild.build_package!/0`. The static guard can't bridge the setup_all-return tuple,
  # so the file_mutation primitive is allow-listed here.
  @async_safety_allow [:file_mutation]
  # Referenced so the compiler sees the attribute as used; the async-safety guard
  # itself reads it from the source AST (Code.string_to_quoted!), not at runtime.
  def __async_safety_allow__, do: @async_safety_allow

  @repo_root Path.expand("../..", __DIR__)
  @ledger_path Path.join(@repo_root, "scripts/maintainer/artifact_ledger.json")
  @ci_path Path.join(@repo_root, ".github/workflows/ci.yml")

  # Hex writes this file into every package; no tracked path produces it.
  @hex_generated ["hex_metadata.config"]

  setup_all do
    {package_root, cleanup_root} = PackageBuild.build_package!()

    if cleanup_root do
      on_exit(fn -> File.rm_rf(cleanup_root) end)
    end

    {:ok,
     %{
       ledger: @ledger_path |> File.read!() |> Jason.decode!(),
       unpacked: unpacked_files(package_root)
     }}
  end

  test "the ledger's shipped classes plus hex_metadata.config equal the unpacked package", %{
    ledger: ledger,
    unpacked: unpacked
  } do
    {missing, extra} = difference(ledger_shipped_set(ledger), unpacked)

    assert {missing, extra} == {[], []}, """
    the ledger-derived shipped set differs from the unpacked Hex package
      in the ledger but not in the package: #{inspect(missing)}
      in the package but not in the ledger: #{inspect(extra)}
    Reclassify the files in scripts/maintainer/artifact_ledger.json or change the mix.exs
    package files list.
    """
  end

  test "excluding a shipped class makes the comparison report its files", %{
    ledger: ledger,
    unpacked: unpacked
  } do
    class = Enum.find(ledger["classes"], &(&1["id"] == "package-guides"))
    assert class, "expected a package-guides class in the ledger"
    guide_files = git_ls_files(class["pathspecs"])
    assert guide_files != []

    excluded =
      update_in(ledger["classes"], fn classes ->
        Enum.map(classes, fn
          %{"id" => "package-guides"} = c -> Map.put(c, "package", "excluded")
          c -> c
        end)
      end)

    assert difference(ledger_shipped_set(excluded), unpacked) == {[], guide_files}
  end

  test "every hygiene drift command is a brandbook-tokens step and a mix ci command", %{
    ledger: ledger
  } do
    commands =
      for %{"regenerate" => %{"drift_check" => "hygiene", "commands" => cmds}} <-
            ledger["classes"],
          cmd <- cmds,
          do: cmd

    assert commands != [], "expected at least one hygiene drift command in the ledger"

    steps =
      @ci_path
      |> YamlElixir.read_from_file!()
      |> get_in(["jobs", "brandbook-tokens", "steps"])
      |> Enum.map(&(&1 |> Map.get("run", "") |> String.trim()))

    ci_alias = Mix.Project.config()[:aliases][:ci]

    for cmd <- commands do
      assert cmd in steps, "#{inspect(cmd)} is not a run step of the brandbook-tokens job"
      assert ("cmd " <> cmd) in ci_alias, "#{inspect(cmd)} is not a command of the mix ci alias"
    end
  end

  defp ledger_shipped_set(ledger) do
    ledger["classes"]
    |> Enum.filter(&(&1["package"] == "shipped"))
    |> Enum.flat_map(&git_ls_files(&1["pathspecs"]))
    |> Kernel.++(@hex_generated)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp difference(expected, actual) do
    {Enum.sort(expected -- actual), Enum.sort(actual -- expected)}
  end

  defp git_ls_files(pathspecs) do
    {out, 0} = System.cmd("git", ["ls-files", "-z", "--" | pathspecs], cd: @repo_root)

    out
    |> String.split("\0", trim: true)
    |> Enum.sort()
  end

  defp unpacked_files(package_root) do
    package_root
    |> Path.join("**")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, package_root))
    |> Enum.sort()
  end
end
