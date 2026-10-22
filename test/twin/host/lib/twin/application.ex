defmodule Twin.Application do
  use Application
  @impl true
  def start(_type, _args) do
    File.mkdir_p!("/retained/tmp")
    :persistent_term.put({Twin, :boot}, Ecto.UUID.generate())

    Supervisor.start_link(
      children(System.get_env("TWIN_START_ROLE")),
      strategy: :one_for_one,
      name: Twin.Supervisor
    )
  end

  # Single-use maintenance tasks share storage and the Repo, without starting
  # a second endpoint, queue supervisor, tracer or peer in the live host.
  def children("maintenance"), do: [Twin.Repo]

  def children(nil) do
    [Twin.Repo, {Oban, Application.fetch_env!(:twin, Oban)}, Twin.Tracer, Twin.Endpoint]
  end

  def children(_), do: raise(ArgumentError, "unknown twin runtime role")
end
