defmodule Rindle.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Rindle.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Rindle.DataCase
    end
  end

  setup tags do
    Rindle.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    repo = tags[:sandbox_repo] || Rindle.Repo
    pid = Sandbox.start_owner!(repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end
end
