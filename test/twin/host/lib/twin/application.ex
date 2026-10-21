defmodule Twin.Application do
  use Application
  @impl true
  def start(_type, _args) do
    File.mkdir_p!("/retained/tmp")
    :persistent_term.put({Twin, :boot}, Ecto.UUID.generate())

    Supervisor.start_link(
      [
        Twin.Repo,
        {Oban, Application.fetch_env!(:twin, Oban)},
        Twin.Tracer,
        Twin.Endpoint
      ],
      strategy: :one_for_one,
      name: Twin.Supervisor
    )
  end
end
