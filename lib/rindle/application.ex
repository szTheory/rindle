defmodule Rindle.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExMarcel.TableWrapper
    ]

    opts = [strategy: :one_for_one, name: Rindle.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
