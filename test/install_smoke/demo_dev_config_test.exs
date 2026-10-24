defmodule Rindle.InstallSmoke.DemoDevConfigTest do
  use ExUnit.Case, async: true

  test "demo development configuration loads for lock audits and keeps upload reload excluded" do
    path = Path.expand("../../examples/adoption_demo/config/config.exs", __DIR__)
    config = Config.Reader.read!(path, env: :dev)
    refute Keyword.has_key?(config[:adoption_demo][AdoptionDemoWeb.Endpoint], :live_reload)

    runtime = Path.join(Path.dirname(path), "runtime.exs")
    config = Config.Reader.read!(runtime, env: :dev)
    patterns = config[:adoption_demo][AdoptionDemoWeb.Endpoint][:live_reload][:patterns]

    assert is_list(patterns)
    assert Enum.any?(patterns, &Regex.match?(&1, "priv/static/assets/app.js"))
    refute Enum.any?(patterns, &Regex.match?(&1, "priv/static/uploads/example.png"))

    test_config = Config.Reader.read!(runtime, env: :test)
    refute Keyword.has_key?(test_config[:adoption_demo][AdoptionDemoWeb.Endpoint], :live_reload)
  end

  test "demo development configuration can be stored in an application file" do
    source = Path.expand("../../examples/adoption_demo/config/config.exs", __DIR__)

    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-demo-config-#{System.pid()}-#{System.unique_integer([:positive])}"
      )

    File.mkdir!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    File.write!(Path.join(root, "mix.exs"), """
    defmodule DemoConfigFixture.MixProject do
      use Mix.Project
      def project, do: [app: :demo_config_fixture, version: "0.1.0", deps: []]
      def application do
        config = Config.Reader.read!(System.fetch_env!("RINDLE_CONFIG_SOURCE"), env: :dev)
        [env: Keyword.fetch!(config, :adoption_demo)]
      end
    end
    """)

    File.mkdir!(Path.join(root, "config"))

    File.write!(Path.join(root, "config/runtime.exs"), """
    import Config
    runtime = Config.Reader.read!(System.fetch_env!("RINDLE_RUNTIME_SOURCE"), env: config_env())
    config :demo_config_fixture, Keyword.fetch!(runtime, :adoption_demo)
    """)

    env = [
      {"MIX_ENV", "dev"},
      {"MIX_HOME", Path.join(root, "mix-home")},
      {"HEX_HOME", Path.join(root, "hex-home")},
      {"MIX_DEPS_PATH", Path.join(root, "deps")},
      {"MIX_BUILD_PATH", Path.join(root, "_build")},
      {"RINDLE_CONFIG_SOURCE", source},
      {"RINDLE_RUNTIME_SOURCE", Path.join(Path.dirname(source), "runtime.exs")}
    ]

    {output, status} =
      System.cmd(System.find_executable("elixir"), ["-S", "mix", "compile.app", "--force"],
        cd: root,
        stderr_to_stdout: true,
        env: env
      )

    assert status == 0, output
    app = Path.join(root, "_build/lib/demo_config_fixture/ebin/demo_config_fixture.app")

    assert {:ok, [{:application, :demo_config_fixture, properties}]} =
             :file.consult(to_charlist(app))

    refute Keyword.has_key?(properties[:env][AdoptionDemoWeb.Endpoint], :live_reload)

    {output, status} =
      System.cmd(
        System.find_executable("elixir"),
        [
          "-S",
          "mix",
          "run",
          "--no-start",
          "--no-compile",
          "-e",
          """
          patterns = Application.fetch_env!(:demo_config_fixture, AdoptionDemoWeb.Endpoint)[:live_reload][:patterns]
          true = Enum.any?(patterns, &Regex.match?(&1, "priv/static/assets/app.js"))
          false = Enum.any?(patterns, &Regex.match?(&1, "priv/static/uploads/example.png"))
          """
        ],
        cd: root,
        stderr_to_stdout: true,
        env: env
      )

    assert status == 0, output
  end
end
