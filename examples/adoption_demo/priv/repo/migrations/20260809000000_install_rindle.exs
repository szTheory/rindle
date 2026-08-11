defmodule AdoptionDemo.Repo.Migrations.InstallRindle do
  use Ecto.Migration

  def up, do: Rindle.Migration.up(version: 1)

  def down, do: Rindle.Migration.down(version: 1)
end
