defmodule Rindle.Repo.Migrations.ExtendMediaForAv do
  @moduledoc """
  Phase 24 — additive migration for AV (image / video / audio / waveform) support.

  Image-only adopters: existing rows valid pre-deploy via column defaults
  (`default: "image"` on both kind enums). No data backfill required (D-04).

  No DDL transaction disabling and no `lock_timeout` — matches every prior
  migration in this project (D-01).
  """
  use Ecto.Migration

  def change do
    alter table(:media_assets) do
      add :kind, :string, null: false, default: "image"
      add :width, :integer
      add :height, :integer
      add :duration_ms, :bigint
      add :has_video_track, :boolean
      add :has_audio_track, :boolean
      add :error_reason, :text
    end

    alter table(:media_variants) do
      add :output_kind, :string, null: false, default: "image"
      add :duration_ms, :bigint
      add :width, :integer
      add :height, :integer
    end

    create index(:media_assets, [:kind])
    create index(:media_variants, [:output_kind])
  end
end
