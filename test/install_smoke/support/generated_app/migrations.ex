defmodule Rindle.InstallSmoke.GeneratedApp.Migrations do
  @moduledoc false

  alias Rindle.InstallSmoke.GeneratedApp.Contracts

  @doc false
  def write!(root, app_module, selected_prefix, migration_kind, report_name, versions) do
    write_host_migration!(root, versions)
    write_host_oban_migration!(root, versions)

    migration_version =
      write_rindle_migration!(root, selected_prefix, migration_kind, versions)

    write_migration_runner!(
      root,
      app_module,
      selected_prefix,
      report_name,
      migration_version,
      versions
    )

    write_isolation_upgrade_seed!(root, app_module)
    write_legacy_upgrade_preparer!(root, app_module, versions)
  end

  defp write_host_migration!(root, versions) do
    path =
      Path.join(
        root,
        "priv/repo/migrations/#{versions.host_migration}_create_install_smoke_markers.exs"
      )

    File.write!(
      path,
      """
      defmodule RindleSmokeApp.Repo.Migrations.CreateInstallSmokeMarkers do
        use Ecto.Migration

        def change do
          create table(:install_smoke_markers) do
            add :name, :string, null: false

            timestamps()
          end
        end
      end
      """
    )
  end

  defp write_host_oban_migration!(root, versions) do
    path =
      Path.join(
        root,
        "priv/repo/migrations/#{versions.host_oban_migration}_install_host_owned_oban.exs"
      )

    File.write!(path, Contracts.host_oban_migration_source())
  end

  defp write_rindle_migration!(root, prefix, migration_kind, versions) do
    {migration_version, migration_source} =
      case migration_kind do
        :install ->
          {versions.rindle_migration, Contracts.rindle_migration_source(prefix)}

        :directional_upgrade ->
          {versions.directional_migration, Contracts.directional_migration_source()}

        :legacy_upgrade ->
          {versions.directional_migration, Contracts.legacy_upgrade_migration_source()}
      end

    path =
      Path.join(
        root,
        "priv/repo/migrations/#{migration_version}_install_rindle.exs"
      )

    File.write!(path, migration_source)
    migration_version
  end

  defp write_migration_runner!(
         root,
         app_module,
         selected_prefix,
         report_name,
         migration_version,
         versions
       ) do
    path = Path.join(root, "priv/install_smoke/migrate.exs")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      Application.ensure_all_started(:rindle)
      {:ok, _pid} = #{app_module}.Repo.start_link()

      host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])

      rindle_migration_file =
        Path.join(host_path, "#{migration_version}_install_rindle.exs")

      regclass_exists? = fn repo, schema, relation ->
        {:ok, %{rows: [[result]]}} =
          repo.query("select to_regclass($1)::text", ["\#{schema}.\#{relation}"])

        not is_nil(result)
      end

      relation_catalog = fn repo, schema, relations ->
        Map.new(relations, fn relation ->
          {relation, regclass_exists?.(repo, schema, relation)}
        end)
      end

      oban_jobs_snapshot = fn repo ->
        {:ok, %{rows: [[oid, schema, relation]]}} =
          repo.query(
            "select relation.oid, namespace.nspname, relation.relname from pg_class relation join pg_namespace namespace on namespace.oid = relation.relnamespace where namespace.nspname = $1 and relation.relname = $2",
            ["public", "oban_jobs"]
          )

        columns =
          repo.query!(
            "select attribute.attname, pg_catalog.format_type(attribute.atttypid, attribute.atttypmod), not attribute.attnotnull, pg_get_expr(default_value.adbin, default_value.adrelid), attribute.attidentity, attribute.attgenerated from pg_attribute attribute left join pg_attrdef default_value on default_value.adrelid = attribute.attrelid and default_value.adnum = attribute.attnum where attribute.attrelid = $1 and attribute.attnum > 0 and not attribute.attisdropped order by attribute.attnum",
            [oid]
          ).rows
          |> Enum.map(fn [name, type, nullable, default, identity, generated] ->
            %{
              name: name,
              type: type,
              nullable: nullable,
              default: default,
              identity: identity,
              generated: generated
            }
          end)

        constraints =
          repo.query!(
            "select catalog_constraint.conname, catalog_constraint.contype::text, pg_get_constraintdef(catalog_constraint.oid) from pg_constraint catalog_constraint where catalog_constraint.conrelid = $1 order by catalog_constraint.conname",
            [oid]
          ).rows
          |> Enum.map(fn [name, type, definition] ->
            %{name: name, type: type, definition: definition}
          end)

        indexes =
          repo.query!(
            "select namespace.nspname, index_relation.relname, index_metadata.indisprimary, index_metadata.indisunique, pg_get_indexdef(index_relation.oid) from pg_index index_metadata join pg_class index_relation on index_relation.oid = index_metadata.indexrelid join pg_class relation on relation.oid = index_metadata.indrelid join pg_namespace namespace on namespace.oid = index_relation.relnamespace where relation.oid = $1 order by namespace.nspname, index_relation.relname",
            [oid]
          ).rows
          |> Enum.map(fn [schema, name, primary, unique, definition] ->
            %{
              schema: schema,
              name: name,
              primary: primary,
              unique: unique,
              definition: definition
            }
          end)

        %{
          identity: %{oid: oid, schema: schema, name: relation},
          columns: columns,
          constraints: constraints,
          indexes: indexes
        }
      end

      rindle_relations = #{inspect(Rindle.Migration.V1.owned_relations())}

      {:ok, migration_report, _apps} =
        Ecto.Migrator.with_repo(#{app_module}.Repo, fn repo ->
          Ecto.Migrator.run(repo, host_path, :up, to: #{String.to_integer(versions.host_migration)})
          host_migration_ran? = regclass_exists?.(repo, "public", "install_smoke_markers")

          Ecto.Migrator.run(repo, host_path, :up, to: #{String.to_integer(versions.host_oban_migration)})
          host_oban_migration_ran? = regclass_exists?.(repo, "public", "oban_jobs")
          oban_jobs_before = oban_jobs_snapshot.(repo)

          Ecto.Migrator.run(repo, host_path, :up, to: #{String.to_integer(migration_version)})
          selected_schema_relations = relation_catalog.(repo, "#{selected_prefix}", rindle_relations)
          decoy_schema_relations = relation_catalog.(repo, "#{if(selected_prefix == "public", do: "rindle", else: "public")}", rindle_relations)
          rindle_migration_ran? = Enum.all?(selected_schema_relations, fn {_relation, exists?} -> exists? end)
          oban_jobs_after = oban_jobs_snapshot.(repo)
          public_host_relations = relation_catalog.(repo, "public", ["oban_jobs", "schema_migrations"])

          marker_versions =
            repo.query!("select version from #{selected_prefix}.rindle_migration_versions order by version").rows
            |> Enum.map(fn [version] -> version end)

          media_variants_foreign_key =
            case repo.query(
                   "select catalog_constraint.conname, catalog_constraint.contype::text, source_namespace.nspname, source_relation.relname, source_column.attname, target_namespace.nspname, target_relation.relname, target_column.attname, pg_get_constraintdef(catalog_constraint.oid) from pg_constraint catalog_constraint join pg_class source_relation on source_relation.oid = catalog_constraint.conrelid join pg_namespace source_namespace on source_namespace.oid = source_relation.relnamespace join pg_class target_relation on target_relation.oid = catalog_constraint.confrelid join pg_namespace target_namespace on target_namespace.oid = target_relation.relnamespace join unnest(catalog_constraint.conkey) with ordinality as source_key(attnum, position) on true join pg_attribute source_column on source_column.attrelid = source_relation.oid and source_column.attnum = source_key.attnum join unnest(catalog_constraint.confkey) with ordinality as target_key(attnum, position) on target_key.position = source_key.position join pg_attribute target_column on target_column.attrelid = target_relation.oid and target_column.attnum = target_key.attnum where source_namespace.nspname = $1 and source_relation.relname = $2 and catalog_constraint.conname = $3 order by source_key.position",
                   ["#{selected_prefix}", "media_variants", "media_variants_asset_id_fkey"]
                 ) do
              {:ok, %{rows: [[name, type, source_schema, source_table, source_column, target_schema, target_table, target_column, definition]]}} ->
                %{
                  name: name,
                  type: type,
                  source_schema: source_schema,
                  source_table: source_table,
                  source_column: source_column,
                  target_schema: target_schema,
                  target_table: target_table,
                  target_column: target_column,
                  definition: definition
                }

              _other ->
                nil
            end

          expected_media_variants_indexes = #{inspect(Contracts.expected_media_variants_indexes())}

          media_variants_indexes =
            case repo.query(
                   "select namespace.nspname, index_relation.relname, pg_get_indexdef(index_relation.oid) from pg_index index_metadata join pg_class relation on relation.oid = index_metadata.indrelid join pg_namespace relation_namespace on relation_namespace.oid = relation.relnamespace join pg_class index_relation on index_relation.oid = index_metadata.indexrelid join pg_namespace namespace on namespace.oid = index_relation.relnamespace where relation_namespace.nspname = $1 and relation.relname = $2 and index_relation.relname = any($3::text[]) order by index_relation.relname",
                   ["#{selected_prefix}", "media_variants", expected_media_variants_indexes]
                 ) do
              {:ok, %{rows: rows}} ->
                indexes_by_name =
                  Map.new(rows, fn [schema, name, definition] ->
                    {name, %{schema: schema, name: name, definition: definition}}
                  end)

                Enum.flat_map(expected_media_variants_indexes, fn name ->
                  case Map.fetch(indexes_by_name, name) do
                    {:ok, index} -> [index]
                    :error -> []
                  end
                end)

              _other ->
                []
            end

          %{
            resolver: "host_migrations",
            host_migration_ran: host_migration_ran?,
            host_oban_migration_ran: host_oban_migration_ran?,
            rindle_migration_ran: rindle_migration_ran?,
            rindle_migration_path: rindle_migration_file,
            selected_schema_relations: selected_schema_relations,
            decoy_schema_relations: decoy_schema_relations,
            public_host_relations: public_host_relations,
            marker_versions: marker_versions,
            media_variants_foreign_key: media_variants_foreign_key,
            media_variants_indexes: media_variants_indexes,
            oban_jobs_before: oban_jobs_before,
            oban_jobs_after: oban_jobs_after,
            host_migration_paths: %{
              host_root: host_path,
              oban: Path.join(host_path, "#{versions.host_oban_migration}_install_host_owned_oban.exs"),
              rindle: rindle_migration_file
            }
          }
        end)

      File.mkdir_p!("tmp")

      File.write!(
        "tmp/#{report_name}",
        Jason.encode!(migration_report)
      )
      """
    )
  end

  defp write_isolation_upgrade_seed!(root, app_module) do
    path = Path.join(root, "priv/install_smoke/seed_isolation_upgrade.exs")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      Application.ensure_all_started(:rindle)
      {:ok, _pid} = #{app_module}.Repo.start_link()

      asset_id = Ecto.UUID.generate()
      variant_id = Ecto.UUID.generate()
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      #{app_module}.Repo.query!(
        "insert into public.media_assets (id, state, storage_key, content_type, byte_size, filename, metadata, recipe_digest, profile, inserted_at, updated_at) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)",
        [
          Ecto.UUID.dump!(asset_id),
          "ready",
          "isolation-upgrade/assets/seed.png",
          "image/png",
          68,
          "isolation-upgrade-seed.png",
          %{"isolation_upgrade_seed" => true},
          "isolation-upgrade-recipe",
          "#{app_module}.RindleProfile",
          now,
          now
        ]
      )

      #{app_module}.Repo.query!(
        "insert into public.media_variants (id, asset_id, name, state, recipe_digest, storage_key, generated_at, byte_size, content_type, inserted_at, updated_at) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)",
        [
          Ecto.UUID.dump!(variant_id),
          Ecto.UUID.dump!(asset_id),
          "thumb",
          "ready",
          "isolation-upgrade-recipe",
          "isolation-upgrade/variants/seed.png",
          now,
          68,
          "image/png",
          now,
          now
        ]
      )

      File.mkdir_p!("tmp")
      File.write!(
        "tmp/isolation_upgrade_seed.json",
        Jason.encode!(%{"asset_id" => asset_id, "variant_id" => variant_id})
      )
      """
    )
  end

  defp write_legacy_upgrade_preparer!(root, app_module, versions) do
    path = Path.join(root, "priv/install_smoke/prepare_upgrade.exs")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      Application.ensure_all_started(:rindle)
      {:ok, _pid} = #{app_module}.Repo.start_link()

      host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
      rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")
      legacy_cutoff = #{versions.legacy_rindle_migration}

      regclass_exists? = fn repo, table_name ->
        {:ok, %{rows: [[result]]}} =
          repo.query("select to_regclass($1)::text", ["public.\#{table_name}"])

        result == table_name
      end

      {:ok, legacy_report, _} =
        Ecto.Migrator.with_repo(#{app_module}.Repo, fn repo ->
          Ecto.Migrator.run(repo, host_path, :up, to: #{versions.host_migration})
          Ecto.Migrator.run(repo, host_path, :up, to: #{versions.host_oban_migration})
          Ecto.Migrator.run(repo, rindle_path, :up, to: legacy_cutoff)

          %{
            current_rindle_marker_preinstalled:
              regclass_exists?.(repo, "rindle_migration_versions")
          }
        end)

      legacy_asset_id = Ecto.UUID.generate()
      legacy_variant_id = Ecto.UUID.generate()
      legacy_session_id = Ecto.UUID.generate()
      legacy_asset_db_id = Ecto.UUID.dump!(legacy_asset_id)
      legacy_variant_db_id = Ecto.UUID.dump!(legacy_variant_id)
      legacy_session_db_id = Ecto.UUID.dump!(legacy_session_id)
      recipe_digest = #{app_module}.RindleProfile.recipe_digest(:thumb)
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_assets (
          id, state, storage_key, content_type, byte_size, filename, metadata,
          recipe_digest, profile, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        \"\"\",
        [
          legacy_asset_db_id,
          "ready",
          "legacy/assets/image-only-thumb.png",
          "image/png",
          68,
          "legacy-thumb.png",
          %{"upgrade_seed" => true},
          recipe_digest,
          "#{app_module}.RindleProfile",
          now,
          now
        ]
      )

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_variants (
          id, asset_id, name, state, recipe_digest, storage_key, generated_at,
          byte_size, content_type, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        \"\"\",
        [
          legacy_variant_db_id,
          legacy_asset_db_id,
          "thumb",
          "ready",
          recipe_digest,
          "legacy/variants/thumb.png",
          now,
          68,
          "image/png",
          now,
          now
        ]
      )

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_upload_sessions (
          id, asset_id, state, upload_key, expires_at, verified_at, failure_reason,
          upload_strategy, multipart_upload_id, multipart_parts, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        \"\"\",
        [
          legacy_session_db_id,
          legacy_asset_db_id,
          "completed",
          "legacy/uploads/image-only-thumb.png",
          expires_at,
          expires_at,
          nil,
          "presigned_put",
          nil,
          %{},
          now,
          now
        ]
      )

      File.mkdir_p!("tmp")

      File.write!(
        "tmp/install_smoke_upgrade_seed.json",
        Jason.encode!(%{
          legacy_rindle_migration_version: Integer.to_string(legacy_cutoff),
          legacy_rindle_migration_path: rindle_path,
          current_rindle_marker_preinstalled: legacy_report.current_rindle_marker_preinstalled,
          legacy_asset_id: legacy_asset_id,
          legacy_variant_id: legacy_variant_id,
          legacy_session_id: legacy_session_id
        })
      )
      """
    )
  end
end
