defmodule Rindle.Repo.Migrations.AddResumableProtocolToMediaUploadSessions do
  use Ecto.Migration

  def change do
    alter table(:media_upload_sessions) do
      # "gcs_native" | "tus"; nil for legacy rows (no backfill, D-10).
      add :resumable_protocol, :string
    end

    # Plain covering index for resumable-protocol lane queries (D-10).
    # Explicit name avoids the >63-char auto-name truncation on PostgreSQL.
    create index(:media_upload_sessions, [:upload_strategy, :resumable_protocol, :state],
             name: :media_upload_sessions_resumable_protocol_idx
           )
  end
end
