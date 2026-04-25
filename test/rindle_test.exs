defmodule RindleTest do
  use ExUnit.Case, async: true

  test "module is defined" do
    assert Code.ensure_loaded?(Rindle)
  end

  test "version returns a string" do
    version = Rindle.version()
    assert is_binary(version)
    assert version != ""
  end
end
