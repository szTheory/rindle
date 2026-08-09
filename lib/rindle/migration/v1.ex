defmodule Rindle.Migration.V1 do
  @moduledoc false

  use Ecto.Migration

  @current_version 1
  @marker_table "rindle_migration_versions"
  @public_schema "public"
  @rindle_schema "rindle"

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
    provision_schema(prefix)
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

  @spec owned_relations() :: [String.t()]
  def owned_relations, do: rindle_tables() ++ [marker_table()]

  @spec catalog_requirements() :: map()
  def catalog_requirements do
    %{
      current_version: current_version(),
      marker_table: marker_table(),
      tables: rindle_tables()
    }
  end

  @doc false
  @spec move_public_to_rindle(%{version: 1}) :: :ok
  def move_public_to_rindle(%{version: 1}) do
    failure_point = Process.get(:rindle_migration_test_failure)

    case preflight_public_to_rindle() do
      :already_upgraded ->
        :ok

      {:provisionable_absent_target, _snapshot} ->
        provision_schema(@rindle_schema)
        inject_test_failure_after(failure_point, :after_target_schema)
        move_owned_relations(@public_schema, @rindle_schema, failure_point)
        :ok

      {:movable_existing_target, _snapshot} ->
        move_owned_relations(@public_schema, @rindle_schema, failure_point)
        :ok

      {:refusal, reason} ->
        raise_preflight_error!(reason)
    end
  end

  @doc false
  @spec move_rindle_to_public(%{version: 1}) :: :ok
  def move_rindle_to_public(%{version: 1}) do
    case preflight_rindle_to_public() do
      :already_reversed ->
        :ok

      {:movable_existing_target, _snapshot} ->
        move_owned_relations(
          @rindle_schema,
          @public_schema,
          Process.get(:rindle_migration_test_failure)
        )

        :ok

      {:refusal, reason} ->
        raise_preflight_error!(reason, :rindle_to_public)
    end
  end

  @doc false
  @spec preflight_public_to_rindle() ::
          :already_upgraded
          | {:provisionable_absent_target | :movable_existing_target, map()}
          | {:refusal, atom()}
  def preflight_public_to_rindle do
    snapshot = migration_snapshot()

    cond do
      complete_source?(snapshot) and
        snapshot.target_relations == [] and
        valid_marker?(snapshot.source_marker) and
        snapshot.source_owned? and not snapshot.target_exists? and
          snapshot.database_create? ->
        {:provisionable_absent_target, snapshot}

      complete_source?(snapshot) and
        snapshot.target_relations == [] and
        valid_marker?(snapshot.source_marker) and
        snapshot.source_owned? and snapshot.target_exists? and snapshot.target_usable? ->
        {:movable_existing_target, snapshot}

      snapshot.source_relations == [] and complete_target?(snapshot) and
          valid_marker?(snapshot.target_marker) ->
        :already_upgraded

      not snapshot.source_owned? ->
        {:refusal, :source_not_owned}

      not complete_source?(snapshot) ->
        {:refusal, :public_incomplete}

      not valid_marker?(snapshot.source_marker) ->
        {:refusal, :public_marker_invalid}

      snapshot.target_relations != [] ->
        {:refusal, :rindle_not_empty}

      not snapshot.target_exists? and not snapshot.database_create? ->
        {:refusal, :database_create_denied}

      snapshot.target_exists? and not snapshot.target_usable? ->
        {:refusal, :rindle_unusable}

      true ->
        {:refusal, :mixed_state}
    end
  end

  @doc false
  @spec preflight_rindle_to_public() ::
          :already_reversed | {:movable_existing_target, map()} | {:refusal, atom()}
  def preflight_rindle_to_public do
    snapshot = migration_snapshot()

    cond do
      complete_target?(snapshot) and snapshot.source_relations == [] and
        valid_marker?(snapshot.target_marker) and snapshot.target_owned? and
          snapshot.public_usable? ->
        {:movable_existing_target, snapshot}

      complete_source?(snapshot) and snapshot.target_relations == [] and
          valid_marker?(snapshot.source_marker) ->
        :already_reversed

      not snapshot.target_owned? ->
        {:refusal, :source_not_owned}

      not complete_target?(snapshot) ->
        {:refusal, :rindle_incomplete}

      not valid_marker?(snapshot.target_marker) ->
        {:refusal, :rindle_marker_invalid}

      snapshot.source_relations != [] ->
        {:refusal, :public_not_empty}

      not snapshot.public_usable? ->
        {:refusal, :public_unusable}

      true ->
        {:refusal, :mixed_state}
    end
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

  defp move_owned_relations(source, destination, failure_point) do
    for {relation, index} <- Enum.with_index(owned_relations(), 1) do
      execute(fn ->
        move_relation!(source, destination, relation)
      end)

      inject_test_failure_after(failure_point, {:after_relation, index})
    end
  end

  defp move_relation!(source, destination, relation) do
    sql = "ALTER TABLE #{qualified(source, relation)} SET SCHEMA #{quote_ident(destination)}"

    try do
      case Process.get(:rindle_migration_test_postgrex_error) do
        nil ->
          repo().query!(sql, [])

        code ->
          raise Postgrex.Error,
            postgres: %{code: code, message: "injected Postgrex error", severity: "ERROR"}
      end
    rescue
      error in Postgrex.Error ->
        if lock_not_available?(error) do
          raise ArgumentError,
                "Rindle public-to-rindle migration could not acquire the required table lock; " <>
                  "host relations were not touched. Next action: keep Rindle writers and workers " <>
                  "quiesced, then retry the host migration."
        else
          reraise error, __STACKTRACE__
        end
    end
  end

  defp lock_not_available?(%Postgrex.Error{postgres: %{code: :lock_not_available}}), do: true
  defp lock_not_available?(%Postgrex.Error{postgres: %{pg_code: "55P03"}}), do: true
  defp lock_not_available?(_error), do: false

  defp inject_test_failure_after(failure_point, point) do
    execute(fn ->
      if failure_point == point do
        raise RuntimeError, "injected Rindle migration failure"
      end
    end)
  end

  defp migration_snapshot do
    %{rows: schema_rows} =
      repo().query!(
        "SELECT nspname FROM pg_namespace WHERE nspname = ANY($1) ORDER BY nspname",
        [[@public_schema, @rindle_schema]]
      )

    %{rows: relation_rows} =
      repo().query!(
        """
        SELECT namespace.nspname, relation.relname,
               pg_has_role(current_user, relation.relowner, 'USAGE')
        FROM pg_class AS relation
        JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
        WHERE namespace.nspname = ANY($1)
          AND relation.relname = ANY($2)
          AND relation.relkind IN ('r', 'p')
        ORDER BY namespace.nspname, relation.relname
        """,
        [[@public_schema, @rindle_schema], owned_relations()]
      )

    marker_rows = marker_rows(relation_rows)

    %{rows: [[database_create?]]} =
      repo().query!("SELECT has_database_privilege(current_database(), 'CREATE')", [])

    schemas = Enum.map(schema_rows, &hd/1)
    target_exists? = @rindle_schema in schemas

    target_usable? =
      if target_exists? do
        %{rows: [[usable?]]} =
          repo().query!("SELECT has_schema_privilege($1, 'USAGE, CREATE')", [@rindle_schema])

        usable?
      else
        false
      end

    %{rows: [[public_usable?]]} =
      repo().query!("SELECT has_schema_privilege($1, 'USAGE, CREATE')", [@public_schema])

    relation_state =
      Enum.reduce(
        relation_rows,
        %{
          @public_schema => %{names: [], owned?: true},
          @rindle_schema => %{names: [], owned?: true}
        },
        fn [schema, name, owned?], acc ->
          update_in(acc, [schema], fn state ->
            state
            |> Map.update!(:names, &[name | &1])
            |> Map.update(:owned?, owned?, &(&1 and owned?))
          end)
        end
      )

    marker_state = Enum.group_by(marker_rows, &hd/1, &List.last/1)

    %{
      source_relations: relation_state[@public_schema].names |> Enum.sort(),
      target_relations: relation_state[@rindle_schema].names |> Enum.sort(),
      source_owned?: relation_state[@public_schema].owned?,
      target_owned?: relation_state[@rindle_schema].owned?,
      source_marker: Map.get(marker_state, @public_schema, []),
      target_marker: Map.get(marker_state, @rindle_schema, []),
      target_exists?: target_exists?,
      database_create?: database_create?,
      target_usable?: target_usable?,
      public_usable?: public_usable?
    }
  end

  defp marker_rows(relation_rows) do
    relation_rows
    |> Enum.filter(fn [_schema, relation, _owned?] -> relation == @marker_table end)
    |> Enum.flat_map(fn [schema, _relation, _owned?] ->
      %{rows: rows} =
        repo().query!(
          "SELECT version FROM #{qualified(schema, @marker_table)} ORDER BY version",
          []
        )

      Enum.map(rows, fn [version] -> [schema, version] end)
    end)
  end

  defp complete_source?(snapshot), do: snapshot.source_relations == Enum.sort(owned_relations())
  defp complete_target?(snapshot), do: snapshot.target_relations == Enum.sort(owned_relations())
  defp valid_marker?(versions), do: versions == [@current_version]

  defp raise_preflight_error!(reason, direction \\ :public_to_rindle) do
    action =
      case reason do
        :provisionable_absent_target ->
          "prepare a maintenance window, then run the fixed Rindle table move"

        :movable_existing_target ->
          "prepare a maintenance window, then run the fixed Rindle table move"

        :public_incomplete ->
          "restore or complete the legacy public Rindle tables before retrying"

        :public_marker_invalid ->
          "repair the public Rindle migration marker before retrying"

        :source_not_owned ->
          "run the migration as the owner of the public Rindle tables"

        :database_create_denied ->
          "grant database CREATE privilege or create the rindle schema before retrying"

        :rindle_unusable ->
          "grant CREATE and USAGE on the rindle schema before retrying"

        :public_unusable ->
          "grant CREATE and USAGE on the public schema before retrying"

        :rindle_incomplete ->
          "restore or complete the rindle Rindle tables before retrying"

        :rindle_marker_invalid ->
          "repair the rindle Rindle migration marker before retrying"

        :public_not_empty ->
          "resolve the existing public Rindle relation state before retrying"

        :rindle_not_empty ->
          "resolve the existing rindle Rindle relation state before retrying"

        _ ->
          "resolve the mixed Rindle schema state before retrying"
      end

    label = if direction == :rindle_to_public, do: "rindle-to-public", else: "public-to-rindle"

    raise ArgumentError,
          "Rindle #{label} migration refused #{inspect(reason)}; host relations were not touched. Next action: #{action}."
  end

  defp provision_schema(prefix) do
    execute("CREATE SCHEMA IF NOT EXISTS #{quote_ident(prefix)}")
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
