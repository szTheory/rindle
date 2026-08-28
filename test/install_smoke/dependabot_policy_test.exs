defmodule Rindle.InstallSmoke.DependabotPolicyTest do
  use ExUnit.Case, async: true

  @config_path Path.expand("../../.github/dependabot.yml", __DIR__)

  test "Mix grouping is limited to development dependencies" do
    config = YamlElixir.read_from_file!(@config_path)

    mix_update =
      Enum.find(config["updates"], &(&1["package-ecosystem"] == "mix")) ||
        flunk("missing Mix Dependabot configuration")

    group = get_in(mix_update, ["groups", "dev-dependencies"])

    assert group["dependency-type"] == "development"
    assert group["patterns"] == ["*"]
    assert group["update-types"] == ["minor", "patch"]
  end
end
