defmodule AdoptionDemo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AdoptionDemoWeb.Telemetry,
      AdoptionDemo.Repo,
      {Oban, Application.fetch_env!(:adoption_demo, Oban)},
      {DNSCluster, query: Application.get_env(:adoption_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AdoptionDemo.PubSub},
      AdoptionDemoWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AdoptionDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AdoptionDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
