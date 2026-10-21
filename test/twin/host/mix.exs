defmodule Twin.MixProject do
  use Mix.Project

  def project do
    [app: :twin, version: "0.1.0", elixir: "~> 1.17.3", deps: deps()]
  end

  def application,
    do: [
      mod: {Twin.Application, []},
      extra_applications: [:logger, :inets, :ssl, :phoenix_pubsub]
    ]

  defp deps do
    [
      {:rindle, path: "../package"},
      {:phoenix, "== 1.8.12"},
      {:bandit, "~> 1.0"},
      {:req, "~> 0.6"},
      {:oban, "== 2.21.1"}
    ]
  end
end
