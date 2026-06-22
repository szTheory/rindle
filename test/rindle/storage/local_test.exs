defmodule Rindle.Storage.LocalTest do
  use ExUnit.Case, async: true

  # async-safety: justified — every File.write! targets a path under a per-test-unique
  # tmp root (`System.tmp_dir!()` + `System.unique_integer`), so no two tests share a path.
  # The static guard can't bridge the `root`→`opts`→`Local.path_for/2` setup-return var, so
  # the file_mutation primitive is allow-listed here. (HARD-01 async-safety guard)
  @async_safety_allow [:file_mutation]
  # Referenced so the compiler sees the attribute as used; the async-safety guard
  # itself reads it from the source AST (Code.string_to_quoted!), not at runtime.
  def __async_safety_allow__, do: @async_safety_allow

  alias Rindle.Storage.Local

  setup do
    root = Path.join(System.tmp_dir!(), "rindle-local-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf(root) end)
    %{root: root, opts: [root: root]}
  end

  test "concatenate/3 combines multiple source files into final file and deletes sources", %{
    opts: opts
  } do
    src1 = "src1.txt"
    src2 = "src2.txt"
    final = "final.txt"

    path1 = Local.path_for(src1, opts)
    path2 = Local.path_for(src2, opts)

    File.write!(path1, "hello ")
    File.write!(path2, "world")

    assert {:ok, %{key: ^final}} = Local.concatenate(final, [src1, src2], opts)

    final_path = Local.path_for(final, opts)
    assert File.read!(final_path) == "hello world"

    refute File.exists?(path1)
    refute File.exists?(path2)
  end
end
