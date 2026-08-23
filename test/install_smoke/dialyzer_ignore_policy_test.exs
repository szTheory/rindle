defmodule Rindle.InstallSmoke.DialyzerIgnorePolicyTest do
  use ExUnit.Case, async: true

  @ignore_path Path.expand("../../.dialyzer_ignore.exs", __DIR__)
  @legacy_atoms [
    :call_without_opaque,
    :pattern_match,
    :pattern_match_cov
  ]

  test "TYPE-02: the live curated ignore list is a unique, owned, exact inventory" do
    ignores = Code.eval_file(@ignore_path) |> elem(0)

    assert valid_ignore_list?(ignores)
    assert Enum.count(ignores, fn {_path, discriminator} -> is_atom(discriminator) end) == 8
    assert Enum.count(ignores, fn {_path, discriminator} -> is_binary(discriminator) end) == 37
    assert length(ignores) == 45
    assert ignores |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == 18
  end

  test "TYPE-02: invalid fixtures are rejected without freezing the live count" do
    assert_invalid([{"lib/rindle.ex", :unapproved_atom}])
    assert_invalid([{"lib/rindle.ex", "specific"}, {"lib/rindle.ex", "specific"}])
    assert_invalid([{"lib/missing.ex", "specific"}])
    assert_invalid([{"lib/rindle.ex", ""}])
    assert_invalid([{"lib/rindle.ex", ~r/specific/}])
    assert_invalid([{"lib/rindle.ex"}])
  end

  defp assert_invalid(ignores), do: refute(valid_ignore_list?(ignores))
end
