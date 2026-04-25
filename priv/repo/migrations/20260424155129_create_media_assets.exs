defmodule Rindle.Repo.Migrations.CreateMediaAssets do
  use Ecto.Migration

  def change do
    create table(:media_assets) do
      add :state, :string, null: false, default: "staged"
      add :storage_key, :string, null: false
      add :content_type, :string
      add :byte_size, :bigint
      add :filename, :string
      add :metadata, :map, null: false, default: %{}
      add :recipe_digest, :string
      add :profile, :string, null: false

      timestamps()
    end

    create index(:media_assets, [:state])
    create unique_index(:media_assets, [:storage_key])
  end
end
