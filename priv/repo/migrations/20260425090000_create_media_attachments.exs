defmodule Rindle.Repo.Migrations.CreateMediaAttachments do
  use Ecto.Migration

  def change do
    create table(:media_attachments) do
      add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
      add :owner_type, :string, null: false
      add :owner_id, :binary_id, null: false
      add :slot, :string, null: false

      timestamps()
    end

    create unique_index(:media_attachments, [:owner_type, :owner_id, :slot])
  end
end
