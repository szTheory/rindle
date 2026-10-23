defmodule Rindle.InstallSmoke.DemoDevConfigTest do
  use ExUnit.Case, async: true

  test "demo development configuration loads for lock audits and keeps upload reload excluded" do
    path = Path.expand("../../examples/adoption_demo/config/config.exs", __DIR__)
    config = Config.Reader.read!(path, env: :dev)
    patterns = config[:adoption_demo][AdoptionDemoWeb.Endpoint][:live_reload][:patterns]

    assert is_list(patterns)
    assert Enum.any?(patterns, &Regex.match?(&1, "priv/static/assets/app.js"))
    refute Enum.any?(patterns, &Regex.match?(&1, "priv/static/uploads/example.png"))
  end
end
