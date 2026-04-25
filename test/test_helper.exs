{:ok, _} = Rindle.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Rindle.Repo, :manual)
{:ok, _} = Oban.start_link(repo: Rindle.Repo, queues: false, testing: :manual)
ExUnit.start()

unless Code.ensure_loaded?(Rindle.StorageMock) do
  Code.require_file("support/mocks.ex", __DIR__)
end
