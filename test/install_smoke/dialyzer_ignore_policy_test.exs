defmodule Rindle.InstallSmoke.DialyzerIgnorePolicyTest do
  use ExUnit.Case, async: true

  @ignore_path Path.expand("../../.dialyzer_ignore.exs", __DIR__)
  @legacy_atom_filters [
    {"lib/rindle.ex", :call_without_opaque},
    {"lib/rindle/upload/broker.ex", :call_without_opaque},
    {"lib/rindle/workers/promote_asset.ex", :call_without_opaque},
    {"lib/rindle/html.ex", :pattern_match},
    {"lib/rindle/ops/runtime_status.ex", :pattern_match_cov},
    {"lib/rindle/workers/process_variant.ex", :pattern_match},
    {"lib/rindle/workers/process_variant.ex", :pattern_match_cov},
    {"lib/rindle/workers/promote_asset.ex", :pattern_match_cov}
  ]

  test "TYPE-02: the live curated ignore list is a unique, owned, exact inventory" do
    ignores = Code.eval_file(@ignore_path) |> elem(0)

    assert valid_ignore_list?(ignores)
    assert Enum.count(ignores, fn {_path, discriminator} -> is_atom(discriminator) end) == 8
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

  defp valid_ignore_list?(ignores) when is_list(ignores) do
    Enum.uniq(ignores) == ignores and Enum.all?(ignores, &valid_filter?/1)
  end

  defp valid_ignore_list?(_), do: false

  defp valid_filter?({path, discriminator}) when is_binary(path) do
    valid_owner?(path) and valid_discriminator?({path, discriminator})
  end

  defp valid_filter?(_), do: false

  defp valid_discriminator?({_path, description}) when is_binary(description),
    do: String.trim(description) != ""

  defp valid_discriminator?(filter) when is_tuple(filter), do: filter in @legacy_atom_filters
  defp valid_discriminator?(_), do: false

  defp valid_owner?(path) do
    String.starts_with?(path, ["lib/", "test/support/"]) and
      File.regular?(Path.expand("../..", __DIR__) |> Path.join(path))
  end
end
