defmodule Twin.Repo.Migrations.InstallTwin do
  use Ecto.Migration

  def up do
    Oban.Migration.up()
    Rindle.Migration.up(version: 1)

    create table(:twin_fault_counters, primary_key: false) do
      add :run_id, :text, null: false
      add :operation, :text, null: false
      add :source_key, :text, null: false
      add :claims, :integer, null: false, default: 0
    end

    create unique_index(:twin_fault_counters, [:run_id, :operation, :source_key])
  end

  def down do
    drop table(:twin_fault_counters)
    Rindle.Migration.down(version: 1)
    Oban.Migration.down(version: 1)
  end
end
