defmodule Rindle.Domain.MediaSchemaTest do
  use Rindle.DataCase, async: true

  alias Rindle.Domain.MediaAsset
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Domain.MediaVariant
  alias Rindle.Repo

  describe "schema sources" do
    test "maps each schema to its backing table" do
      assert "media_assets" == Rindle.Domain.MediaAsset.__schema__(:source)
      assert "media_attachments" == Rindle.Domain.MediaAttachment.__schema__(:source)
      assert "media_variants" == Rindle.Domain.MediaVariant.__schema__(:source)
      assert "media_upload_sessions" == Rindle.Domain.MediaUploadSession.__schema__(:source)
      assert "media_processing_runs" == Rindle.Domain.MediaProcessingRun.__schema__(:source)
    end
  end

  describe "changeset constraints" do
    test "asset changeset rejects missing state" do
      changeset =
        MediaAsset.changeset(%MediaAsset{}, %{
          state: nil,
          storage_key: "assets/#{Ecto.UUID.generate()}",
          profile: "image"
        })

      assert {"can't be blank", _meta} = Keyword.fetch!(changeset.errors, :state)
    end

    test "variant enforces uniqueness on asset and variant name" do
      asset = insert_asset!()

      attrs = %{
        asset_id: asset.id,
        name: "thumbnail",
        state: "planned",
        recipe_digest: "digest-v1"
      }

      assert {:ok, _variant} = %MediaVariant{} |> MediaVariant.changeset(attrs) |> Repo.insert()

      assert {:error, changeset} = %MediaVariant{} |> MediaVariant.changeset(attrs) |> Repo.insert()
      assert {"has already been taken", _meta} = Keyword.fetch!(changeset.errors, :asset_id)
    end

    test "upload session changeset requires upload_key" do
      asset = insert_asset!()

      changeset =
        MediaUploadSession.changeset(%MediaUploadSession{}, %{
          asset_id: asset.id,
          state: "initialized",
          upload_key: nil,
          expires_at: DateTime.utc_now()
        })

      assert {"can't be blank", _meta} = Keyword.fetch!(changeset.errors, :upload_key)
    end
  end

  describe "queryable state columns" do
    test "filters variants by state" do
      asset = insert_asset!()

      insert_variant!(asset.id, "thumb", "planned", "digest-p")
      insert_variant!(asset.id, "hero", "ready", "digest-r")

      names =
        Repo.all(
          from v in MediaVariant,
            where: v.state == "planned",
            select: v.name
        )

      assert ["thumb"] == names
    end
  end

  defp insert_asset! do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "staged",
      storage_key: "assets/#{Ecto.UUID.generate()}",
      profile: "image"
    })
    |> Repo.insert!()
  end

  defp insert_variant!(asset_id, name, state, recipe_digest) do
    %MediaVariant{}
    |> MediaVariant.changeset(%{
      asset_id: asset_id,
      name: name,
      state: state,
      recipe_digest: recipe_digest
    })
    |> Repo.insert!()
  end
end
