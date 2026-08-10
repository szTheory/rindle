defmodule Rindle.TestSupport.HostRindleMigration do
  @moduledoc false

  use Ecto.Migration

  # The regular test suite intentionally compiles for explicit `public`
  # compatibility. Model the host-owned migration handoff here rather than
  # relying on Rindle's legacy package migration directory.
  def up, do: Rindle.Migration.up(version: 1, prefix: "public")
  def down, do: Rindle.Migration.down(version: 1, prefix: "public")

  def install! do
    {:ok, runner} =
      Ecto.Migration.Runner.start_link(
        {self(), Rindle.Repo, Rindle.Repo.config(), __MODULE__, :forward, :up,
         %{level: false, sql: false}}
      )

    Ecto.Migration.Runner.metadata(runner, prefix: "public")

    try do
      up()
      Ecto.Migration.Runner.flush()
    after
      if Process.alive?(runner), do: Ecto.Migration.Runner.stop()
      Process.delete(:ecto_migration)
    end
  end
end
