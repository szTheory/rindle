Application.ensure_all_started(:rindle)
{:ok, _} = AdoptionDemo.Repo.start_link()

rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")

unless File.dir?(rindle_path) do
  raise "Rindle migration path missing: #{rindle_path}"
end

{:ok, _, _} =
  Ecto.Migrator.with_repo(AdoptionDemo.Repo, fn repo ->
    Ecto.Migrator.run(repo, rindle_path, :up, all: true)
  end)

IO.puts("Rindle migrations applied from #{rindle_path}")
