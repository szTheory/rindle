defmodule Rindle.Repo.Migrations.CreateMediaProcessingRuns do
  use Ecto.Migration

  def change do
    create table(:media_processing_runs) do
      add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
      add :variant_name, :string, null: false
      add :worker, :string, null: false
      add :state, :string, null: false
      add :attempt, :integer, null: false, default: 1
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :error_reason, :text

      timestamps()
    end

    create index(:media_processing_runs, [:asset_id, :variant_name])
    create index(:media_processing_runs, [:state])
  end
end
