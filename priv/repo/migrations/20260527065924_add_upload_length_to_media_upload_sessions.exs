defmodule Rindle.Repo.Migrations.AddUploadLengthToMediaUploadSessions do
  use Ecto.Migration

  def change do
    alter table(:media_upload_sessions) do
      add :upload_length, :integer, null: true
    end
  end
end
