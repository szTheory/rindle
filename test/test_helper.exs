{:ok, _} = Rindle.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Rindle.Repo, :manual)

case ExMarcel.TableWrapper.start_link([]) do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end

case Rindle.Adopter.CanonicalApp.Repo.start_link() do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end

Ecto.Adapters.SQL.Sandbox.mode(Rindle.Adopter.CanonicalApp.Repo, :manual)
{:ok, _} = Oban.start_link(repo: Rindle.Repo, queues: false, testing: :manual)

targeted_adopter_or_integration? =
  System.argv()
  |> Enum.any?(fn arg ->
    String.contains?(arg, "test/adopter/") or
      String.ends_with?(arg, "lifecycle_integration_test.exs")
  end)

exclude_tags =
  if targeted_adopter_or_integration? do
    [:minio, :contract]
  else
    [:integration, :minio, :contract, :adopter]
  end

ExUnit.start(exclude: exclude_tags)

unless Code.ensure_loaded?(Rindle.StorageMock) do
  Code.require_file("support/mocks.ex", __DIR__)
end
