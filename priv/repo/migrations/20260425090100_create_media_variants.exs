defmodule Rindle.Repo.Migrations.CreateMediaVariants do
  use Ecto.Migration

  def change do
    create table(:media_variants) do
      add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :state, :string, null: false, default: "planned"
      add :recipe_digest, :string, null: false
      add :storage_key, :string
      add :error_reason, :text
      add :generated_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:media_variants, [:asset_id, :name])
    create index(:media_variants, [:state])
  end
end
