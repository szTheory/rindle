defmodule Rindle.Migration.V1 do
  @moduledoc false

  use Ecto.Migration

  @current_version 1
  @marker_table "rindle_migration_versions"

  @rindle_tables ~w(
    media_assets
    media_attachments
    media_variants
    media_upload_sessions
    media_processing_runs
    media_provider_assets
  )

  @spec up(%{prefix: String.t()}) :: :ok
  def up(%{prefix: prefix}) do
    create_media_assets(prefix)
    create_media_attachments(prefix)
    create_media_variants(prefix)
    create_media_upload_sessions(prefix)
    create_media_processing_runs(prefix)
    create_media_provider_assets(prefix)
    create_marker(prefix)
    record_marker(prefix)

    :ok
  end

  @spec down(%{prefix: String.t()}) :: :ok
  def down(%{prefix: prefix}) do
    for table <- [
          "media_attachments",
          "media_variants",
          "media_provider_assets",
          "media_processing_runs",
          "media_upload_sessions",
          "media_assets",
          @marker_table
        ] do
      drop_if_exists table(table, prefix: prefix)
    end

    :ok
  end

  @spec current_version() :: 1
  def current_version, do: @current_version

  @spec marker_table() :: String.t()
  def marker_table, do: @marker_table

  @spec rindle_tables() :: [String.t()]
  def rindle_tables, do: @rindle_tables

  @spec catalog_requirements() :: map()
  def catalog_requirements do
    %{
      current_version: current_version(),
      marker_table: marker_table(),
      tables: rindle_tables()
    }
  end

  defp create_media_assets(prefix) do
    create_if_not_exists table(:media_assets, table_opts(prefix)) do
      add :id, :binary_id, primary_key: true
      add :state, :string, null: false, default: "staged"
      add :storage_key, :string, null: false
      add :content_type, :string
      add :byte_size, :bigint
      add :filename, :string
      add :metadata, :map, null: false, default: %{}
      add :recipe_digest, :string
      add :profile, :string, null: false
      add :kind, :string, null: false, default: "image"
      add :width, :integer
      add :height, :integer
      add :duration_ms, :bigint
      add :has_video_track, :boolean
      add :has_audio_track, :boolean
      add :error_reason, :text

      timestamps()
    end

    alter table(:media_assets, prefix: prefix) do
      add_if_not_exists :kind, :string, null: false, default: "image"
      add_if_not_exists :width, :integer
      add_if_not_exists :height, :integer
      add_if_not_exists :duration_ms, :bigint
      add_if_not_exists :has_video_track, :boolean
      add_if_not_exists :has_audio_track, :boolean
      add_if_not_exists :error_reason, :text
    end

    create_if_not_exists index(:media_assets, [:state], prefix: prefix)
    create_if_not_exists unique_index(:media_assets, [:storage_key], prefix: prefix)
    create_if_not_exists index(:media_assets, [:kind], prefix: prefix)
  end

  defp create_media_attachments(prefix) do
    create_if_not_exists table(:media_attachments, table_opts(prefix)) do
      add :id, :binary_id, primary_key: true

      add :asset_id,
          references(:media_assets, type: :binary_id, prefix: prefix, on_delete: :delete_all),
          null: false

      add :owner_type, :string, null: false
      add :owner_id, :binary_id, null: false
      add :slot, :string, null: false

      timestamps()
    end

    create_if_not_exists unique_index(:media_attachments, [:owner_type, :owner_id, :slot],
                           prefix: prefix
                         )
  end

  defp create_media_variants(prefix) do
    create_if_not_exists table(:media_variants, table_opts(prefix)) do
      add :id, :binary_id, primary_key: true

      add :asset_id,
          references(:media_assets, type: :binary_id, prefix: prefix, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :state, :string, null: false, default: "planned"
      add :recipe_digest, :string, null: false
      add :storage_key, :string
      add :error_reason, :text
      add :generated_at, :utc_datetime_usec
      add :byte_size, :bigint
      add :content_type, :string
      add :output_kind, :string, null: false, default: "image"
      add :duration_ms, :bigint
      add :width, :integer
      add :height, :integer

      timestamps()
    end

    alter table(:media_variants, prefix: prefix) do
      add_if_not_exists :byte_size, :bigint
      add_if_not_exists :content_type, :string
      add_if_not_exists :output_kind, :string, null: false, default: "image"
      add_if_not_exists :duration_ms, :bigint
      add_if_not_exists :width, :integer
      add_if_not_exists :height, :integer
    end

    create_if_not_exists unique_index(:media_variants, [:asset_id, :name], prefix: prefix)
    create_if_not_exists index(:media_variants, [:state], prefix: prefix)
    create_if_not_exists index(:media_variants, [:output_kind], prefix: prefix)
  end

  defp create_media_upload_sessions(prefix) do
    create_if_not_exists table(:media_upload_sessions, table_opts(prefix)) do
      add :id, :binary_id, primary_key: true

      add :asset_id,
          references(:media_assets, type: :binary_id, prefix: prefix, on_delete: :delete_all),
          null: false

      add :state, :string, null: false, default: "initialized"
      add :upload_key, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :verified_at, :utc_datetime_usec
      add :failure_reason, :text
      add :upload_strategy, :string, null: false, default: "presigned_put"
      add :multipart_upload_id, :string
      add :multipart_parts, :map, null: false, default: %{}
      add :session_uri, :text
      add :session_uri_expires_at, :utc_datetime_usec
      add :last_known_offset, :bigint, null: false, default: 0
      add :region_hint, :string, size: 64
      add :resumable_protocol, :string
      add :upload_length, :integer, null: true

      timestamps()
    end

    alter table(:media_upload_sessions, prefix: prefix) do
      add_if_not_exists :upload_strategy, :string, null: false, default: "presigned_put"
      add_if_not_exists :multipart_upload_id, :string
      add_if_not_exists :multipart_parts, :map, null: false, default: %{}
      add_if_not_exists :session_uri, :text
      add_if_not_exists :session_uri_expires_at, :utc_datetime_usec
      add_if_not_exists :last_known_offset, :bigint, null: false, default: 0
      add_if_not_exists :region_hint, :string, size: 64
      add_if_not_exists :resumable_protocol, :string
      add_if_not_exists :upload_length, :integer, null: true
    end

    create_if_not_exists index(:media_upload_sessions, [:state], prefix: prefix)
    create_if_not_exists index(:media_upload_sessions, [:expires_at], prefix: prefix)

    create_if_not_exists index(:media_upload_sessions, [:session_uri_expires_at],
                           where: "upload_strategy = 'resumable'",
                           name: :media_upload_sessions_resumable_expiry_idx,
                           prefix: prefix
                         )

    create_if_not_exists index(
                           :media_upload_sessions,
                           [:upload_strategy, :resumable_protocol, :state],
                           name: :media_upload_sessions_resumable_protocol_idx,
                           prefix: prefix
                         )
  end

  defp create_media_processing_runs(prefix) do
    create_if_not_exists table(:media_processing_runs, table_opts(prefix)) do
      add :id, :binary_id, primary_key: true

      add :asset_id,
          references(:media_assets, type: :binary_id, prefix: prefix, on_delete: :delete_all),
          null: false

      add :variant_name, :string, null: false
      add :worker, :string, null: false
      add :state, :string, null: false
      add :attempt, :integer, null: false, default: 1
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :error_reason, :text

      timestamps()
    end

    create_if_not_exists index(:media_processing_runs, [:asset_id, :variant_name], prefix: prefix)
    create_if_not_exists index(:media_processing_runs, [:state], prefix: prefix)
  end

  defp create_media_provider_assets(prefix) do
    create_if_not_exists table(:media_provider_assets, table_opts(prefix)) do
      add :id, :binary_id, primary_key: true

      add :asset_id,
          references(:media_assets, type: :binary_id, prefix: prefix, on_delete: :delete_all),
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
      add :mux_passthrough, :string
      add :provider_upload_id, :string

      timestamps()
    end

    alter table(:media_provider_assets, prefix: prefix) do
      add_if_not_exists :mux_passthrough, :string
      add_if_not_exists :provider_upload_id, :string
    end

    create_if_not_exists unique_index(
                           :media_provider_assets,
                           [:provider_name, :provider_asset_id],
                           where: "provider_asset_id IS NOT NULL",
                           name: :media_provider_assets_provider_name_provider_asset_id_index,
                           prefix: prefix
                         )

    create_if_not_exists unique_index(
                           :media_provider_assets,
                           [:asset_id, :profile, :provider_name],
                           prefix: prefix
                         )

    create_if_not_exists index(:media_provider_assets, [:state], prefix: prefix)
    create_if_not_exists index(:media_provider_assets, [:state, :updated_at], prefix: prefix)

    create_if_not_exists unique_index(:media_provider_assets, [:provider_name, :mux_passthrough],
                           where: "mux_passthrough IS NOT NULL",
                           name: :media_provider_assets_provider_name_mux_passthrough_index,
                           prefix: prefix
                         )

    create_if_not_exists unique_index(
                           :media_provider_assets,
                           [:provider_name, :provider_upload_id],
                           where: "provider_upload_id IS NOT NULL",
                           name: :media_provider_assets_provider_name_provider_upload_id_index,
                           prefix: prefix
                         )
  end

  defp create_marker(prefix) do
    create_if_not_exists table(@marker_table, primary_key: false, prefix: prefix) do
      add :version, :integer, primary_key: true
    end
  end

  defp record_marker(prefix) do
    execute("""
    INSERT INTO #{qualified(prefix, @marker_table)} (version)
    VALUES (#{@current_version})
    ON CONFLICT (version) DO NOTHING
    """)
  end

  defp table_opts(prefix), do: [primary_key: false, prefix: prefix]

  defp qualified(prefix, table), do: "#{quote_ident(prefix)}.#{quote_ident(table)}"

  defp quote_ident(identifier) do
    escaped =
      identifier
      |> to_string()
      |> String.replace(~s("), ~s(""))

    ~s("#{escaped}")
  end
end
