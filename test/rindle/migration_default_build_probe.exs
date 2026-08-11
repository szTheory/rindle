alias Rindle.Repo

{:ok, _started} = Application.ensure_all_started(:rindle)
{:ok, _repo} = Repo.start_link()

if Rindle.Schema.prefix() != "rindle" do
  raise "default build must compile Rindle.Schema with the rindle prefix"
end

%{rows: [[false]]} = Repo.query!("SELECT to_regnamespace($1) IS NOT NULL", ["rindle"])

{:error, :probe_rollback} =
  Repo.transaction(fn ->
    {:ok, runner} =
      Ecto.Migration.Runner.start_link(
        {self(), Repo, Repo.config(), __MODULE__, :forward, :up, %{level: false, sql: false}}
      )

    try do
      Ecto.Migration.Runner.metadata(runner, [])
      Rindle.Migration.up(version: 1)
      Ecto.Migration.Runner.flush()

      %{rows: [[true]]} = Repo.query!("SELECT to_regnamespace($1) IS NOT NULL", ["rindle"])

      for relation <- Rindle.Migration.V1.owned_relations() do
        %{rows: [[true]]} =
          Repo.query!("SELECT to_regclass($1) IS NOT NULL", ["rindle.#{relation}"])
      end

      Repo.rollback(:probe_rollback)
    after
      if Process.alive?(runner), do: Ecto.Migration.Runner.stop()
      Process.delete(:ecto_migration)
    end
  end)

%{rows: [[false]]} = Repo.query!("SELECT to_regnamespace($1) IS NOT NULL", ["rindle"])
