defmodule Rindle.SchemaPrefixCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Domain.{MediaAsset, MediaAttachment, MediaVariant}
  alias Rindle.Repo

  using do
    quote do
      alias Rindle.Repo
      import Ecto.Query
      import Rindle.SchemaPrefixCase
    end
  end

  setup _tags do
    owner = Sandbox.start_owner!(Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(owner) end)

    Rindle.SchemaPrefixCase.prepare_fixtures!()
  end

  def prepare_fixtures! do
    selected_prefix = Rindle.Config.rindle_prefix()
    decoy_prefix = other_prefix(selected_prefix)

    ensure_schema!(decoy_prefix)
    create_tables!(decoy_prefix)

    selected = insert_asset!(selected_prefix, "selected-#{selected_prefix}")
    decoy = insert_asset!(decoy_prefix, "decoy-#{decoy_prefix}")

    %{
      selected_prefix: selected_prefix,
      decoy_prefix: decoy_prefix,
      selected: selected,
      decoy: decoy
    }
  end

  def insert_asset!(prefix, storage_key, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          state: "available",
          profile: "Rindle.SchemaPrefixCase.Profile",
          storage_key: storage_key,
          filename: "#{storage_key}.jpg",
          kind: "image"
        },
        attrs
      )

    %MediaAsset{}
    |> MediaAsset.changeset(attrs)
    |> Repo.insert!(prefix: prefix)
  end

  def insert_attachment!(prefix, asset, owner_id, slot) do
    %MediaAttachment{}
    |> MediaAttachment.changeset(%{
      asset_id: asset.id,
      owner_type: "Elixir.Rindle.SchemaPrefixCase.Owner",
      owner_id: owner_id,
      slot: slot
    })
    |> Repo.insert!(prefix: prefix)
  end

  def insert_variant!(prefix, asset, name) do
    %MediaVariant{}
    |> MediaVariant.changeset(%{
      asset_id: asset.id,
      name: name,
      state: "planned",
      recipe_digest: "schema-prefix-#{name}",
      output_kind: "image"
    })
    |> Repo.insert!(prefix: prefix)
  end

  defp other_prefix("public"), do: "rindle"
  defp other_prefix("rindle"), do: "public"

  defp ensure_schema!(prefix) do
    Repo.query!("CREATE SCHEMA IF NOT EXISTS #{quote_ident(prefix)}")
  end

  defp create_tables!(prefix) do
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{qualified(prefix, "media_assets")} (
      id uuid PRIMARY KEY,
      state varchar NOT NULL,
      storage_key varchar NOT NULL,
      content_type varchar,
      byte_size bigint,
      filename varchar,
      metadata jsonb,
      recipe_digest varchar,
      profile varchar NOT NULL,
      kind varchar NOT NULL,
      width integer,
      height integer,
      duration_ms integer,
      has_video_track boolean,
      has_audio_track boolean,
      error_reason varchar,
      inserted_at timestamp(0) NOT NULL,
      updated_at timestamp(0) NOT NULL
    )
    """)

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{qualified(prefix, "media_attachments")} (
      id uuid PRIMARY KEY,
      owner_type varchar NOT NULL,
      owner_id uuid NOT NULL,
      slot varchar NOT NULL,
      asset_id uuid NOT NULL REFERENCES #{qualified(prefix, "media_assets")}(id) ON DELETE CASCADE,
      inserted_at timestamp(0) NOT NULL,
      updated_at timestamp(0) NOT NULL,
      UNIQUE (owner_type, owner_id, slot)
    )
    """)

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{qualified(prefix, "media_variants")} (
      id uuid PRIMARY KEY,
      asset_id uuid NOT NULL REFERENCES #{qualified(prefix, "media_assets")}(id) ON DELETE CASCADE,
      name varchar NOT NULL,
      state varchar NOT NULL,
      recipe_digest varchar NOT NULL,
      output_kind varchar NOT NULL,
      inserted_at timestamp(0) NOT NULL,
      updated_at timestamp(0) NOT NULL,
      UNIQUE (asset_id, name)
    )
    """)
  end

  defp qualified(prefix, table), do: "#{quote_ident(prefix)}.#{quote_ident(table)}"

  defp quote_ident(identifier) do
    escaped = identifier |> to_string() |> String.replace(~s("), ~s(""))
    ~s("#{escaped}")
  end
end
