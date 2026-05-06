defmodule Rindle.Repo.Migrations.CreateMediaProviderAssets do
  @moduledoc """
  Phase 33 — additive migration for `media_provider_assets`.

  Creates one row per `(asset, profile, provider)` to track durable provider-side
  state for streaming providers (Mux first, in Phase 34). No change to
  `media_assets` or `media_variants`. Idempotent and additive — adopters running
  this migration get one new empty table; existing rows are unaffected.

  No DDL transaction disabling and no `lock_timeout` — matches every prior
  migration in this project (Phase 33 D-11).
  """
  use Ecto.Migration

  def change do
    create table(:media_provider_assets, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :asset_id,
          references(:media_assets, type: :binary_id, on_delete: :delete_all),
          null: false

      add :profile, :string, null: false
      add :provider_name, :string, null: false
      add :provider_asset_id, :string
      add :playback_ids, {:array, :string}, null: false, default: []
      add :playback_policy, :string
      add :ingest_mode, :string
      add :state, :string, null: false, default: "pending"
      add :last_event_id, :string
      add :last_event_at, :utc_datetime_usec
      add :last_sync_error, :text
      add :raw_provider_metadata, :map, null: false, default: %{}

      timestamps()
    end

    create unique_index(:media_provider_assets, [:provider_name, :provider_asset_id],
             where: "provider_asset_id IS NOT NULL",
             name: :media_provider_assets_provider_name_provider_asset_id_index
           )

    create unique_index(:media_provider_assets, [:asset_id, :profile, :provider_name])

    create index(:media_provider_assets, [:state])
    create index(:media_provider_assets, [:state, :updated_at])
  end
end
