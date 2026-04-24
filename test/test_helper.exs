{:ok, _} = Rindle.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Rindle.Repo, :manual)
ExUnit.start()
Code.require_file("support/mocks.ex", __DIR__)
