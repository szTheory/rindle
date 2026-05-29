defmodule AdoptionDemo.MixProject do
  use Mix.Project

  @rindle_path System.get_env("RINDLE_DEMO_RINDLE_PATH") || "../.."

  def project do
    [
      app: :adoption_demo,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {AdoptionDemo.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :ssl]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:rindle, path: @rindle_path},
      {:phoenix, "~> 1.8.7"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:oban, "~> 2.21"},
      {:hackney, "~> 1.20"},
      {:mux, "~> 3.2"},
      {:jose, "~> 1.11"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.vendor", "ecto.setup"],
      "assets.vendor": [
        "cmd mkdir -p priv/static/assets/vendor",
        "cmd cp deps/phoenix/priv/static/phoenix.min.js priv/static/assets/vendor/",
        "cmd cp deps/phoenix_live_view/priv/static/phoenix_live_view.min.js priv/static/assets/vendor/"
      ],
      "ecto.setup": [
        "ecto.create",
        "ecto.migrate",
        "rindle.migrate",
        "run priv/repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "rindle.migrate": ["cmd mix run --no-start priv/rindle_migrate.exs"],
      test: [
        "cmd sh -c 'PHX_SERVER=1 mix ecto.create --quiet || true'",
        "cmd sh -c 'PHX_SERVER=1 mix ecto.migrate --quiet'",
        "cmd sh -c 'PHX_SERVER=1 mix rindle.migrate'",
        "test"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
