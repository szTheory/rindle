defmodule Rindle.Repo.Migrations.CreateMediaUploadSessions do
  use Ecto.Migration

  def change do
    create table(:media_upload_sessions) do
      add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
      add :state, :string, null: false, default: "initialized"
      add :upload_key, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :verified_at, :utc_datetime_usec
      add :failure_reason, :text

      timestamps()
    end

    create index(:media_upload_sessions, [:state])
    create index(:media_upload_sessions, [:expires_at])
  end
end
