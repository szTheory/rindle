defmodule Rindle.Repo.Migrations.ExtendMediaUploadSessionsForMultipart do
  use Ecto.Migration

  def change do
    alter table(:media_upload_sessions) do
      add :upload_strategy, :string, null: false, default: "presigned_put"
      add :multipart_upload_id, :string
      add :multipart_parts, :map, null: false, default: %{}
    end
  end
end
