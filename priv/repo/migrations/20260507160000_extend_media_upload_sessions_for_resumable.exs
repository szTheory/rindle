defmodule Rindle.Repo.Migrations.ExtendMediaUploadSessionsForResumable do
  use Ecto.Migration

  def change do
    alter table(:media_upload_sessions) do
      # Plaintext :text is the packaged default; adopters with stricter at-rest requirements
      # may substitute an encrypted app-local field posture before rollout.
      add :session_uri, :text
      add :session_uri_expires_at, :utc_datetime_usec
      add :last_known_offset, :bigint, null: false, default: 0
      add :region_hint, :string, size: 64
    end

    create index(:media_upload_sessions, [:session_uri_expires_at],
             where: "upload_strategy = 'resumable'",
             name: :media_upload_sessions_resumable_expiry_idx
           )
  end
end
