defmodule Rindle.Storage.LocalTest do
  use ExUnit.Case, async: true

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
