defmodule Rindle.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/szTheory/rindle"

  def project do
    [
      app: :rindle,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      package: package(),
      name: "Rindle",
      description: "Phoenix/Ecto-native media lifecycle library. Media, made durable.",
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Rindle.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.18"},
      {:jason, "~> 1.4"},

      # Background processing
      {:oban, "~> 2.18"},

      # Image processing
      {:image, "~> 0.54"},

      # Configuration validation
      {:nimble_options, "~> 1.1"},

      # Observability
      {:telemetry, "~> 1.2"},

      # Dev/Test
      # Required by :color (via :image) visualizer modules in non-prod envs
      {:plug, "~> 1.16", only: [:dev, :test]},
      {:mox, "~> 1.2", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Rindle",
      source_url: @source_url,
      extras: [
        "README.md"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
