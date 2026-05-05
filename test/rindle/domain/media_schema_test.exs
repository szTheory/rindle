defmodule Rindle.Domain.MediaSchemaTest do
  use Rindle.DataCase, async: true

  alias MediaAsset
  alias MediaUploadSession
  alias MediaVariant
  alias Rindle.Domain.MediaAsset
  alias Rindle.Domain.MediaAttachment
  alias Rindle.Domain.MediaProcessingRun
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Domain.MediaVariant
  alias Rindle.Repo

  describe "schema sources" do
    test "maps each schema to its backing table" do
      assert "media_assets" == MediaAsset.__schema__(:source)
      assert "media_attachments" == MediaAttachment.__schema__(:source)
      assert "media_variants" == MediaVariant.__schema__(:source)
      assert "media_upload_sessions" == MediaUploadSession.__schema__(:source)
      assert "media_processing_runs" == MediaProcessingRun.__schema__(:source)
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

      assert {:error, changeset} =
               %MediaVariant{} |> MediaVariant.changeset(attrs) |> Repo.insert()

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

  describe "media_assets - kind/typed cols (Phase 24)" do
    @valid_base_attrs %{
      state: "staged",
      storage_key: "test/some/key.jpg",
      profile: "Rindle.TestProfile",
      kind: "image"
    }

    test "accepts kind=image with no probe columns" do
      assert MediaAsset.changeset(%MediaAsset{}, @valid_base_attrs).valid?
    end

    test "accepts kind=video with width/height/duration_ms/has_video_track" do
      attrs =
        %{@valid_base_attrs | kind: "video", storage_key: "v/clip.mp4"}
        |> Map.merge(%{
          width: 1920,
          height: 1080,
          duration_ms: 5_000,
          has_video_track: true,
          has_audio_track: true
        })

      assert MediaAsset.changeset(%MediaAsset{}, attrs).valid?
    end

    test "accepts kind=audio with duration_ms only" do
      attrs =
        %{@valid_base_attrs | kind: "audio", storage_key: "a/song.m4a"}
        |> Map.put(:duration_ms, 180_000)

      assert MediaAsset.changeset(%MediaAsset{}, attrs).valid?
    end

    test "rejects kind=audio with width" do
      attrs = %{@valid_base_attrs | kind: "audio", storage_key: "a/x.m4a"} |> Map.put(:width, 100)

      changeset = MediaAsset.changeset(%MediaAsset{}, attrs)
      refute changeset.valid?
      assert {:width, _} = List.first(changeset.errors)
    end

    test "rejects kind=audio with height" do
      attrs = %{@valid_base_attrs | kind: "audio", storage_key: "a/y.m4a"} |> Map.put(:height, 100)

      changeset = MediaAsset.changeset(%MediaAsset{}, attrs)
      refute changeset.valid?
    end

    test "rejects kind=image with duration_ms" do
      attrs = Map.put(@valid_base_attrs, :duration_ms, 1000)

      changeset = MediaAsset.changeset(%MediaAsset{}, attrs)
      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {field, _} -> field == :duration_ms end)
    end

    test "rejects kind=image with has_video_track" do
      attrs = Map.put(@valid_base_attrs, :has_video_track, true)

      changeset = MediaAsset.changeset(%MediaAsset{}, attrs)
      refute changeset.valid?
    end

    test "rejects kind=waveform (output-only — see RESEARCH.md Pitfall 4)" do
      attrs = Map.put(@valid_base_attrs, :kind, "waveform")

      changeset = MediaAsset.changeset(%MediaAsset{}, attrs)
      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {field, _} -> field == :kind end)
    end

    test "rejects kind=garbage" do
      attrs = Map.put(@valid_base_attrs, :kind, "garbage")
      changeset = MediaAsset.changeset(%MediaAsset{}, attrs)
      refute changeset.valid?
    end

    test "error_reason is castable as a string" do
      attrs = Map.put(@valid_base_attrs, :error_reason, "probe failed")
      changeset = MediaAsset.changeset(%MediaAsset{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :error_reason) == "probe failed"
    end

    test "transcoding is a valid state value (Plan 03 prerequisite)" do
      attrs = Map.put(@valid_base_attrs, :state, "transcoding")
      assert MediaAsset.changeset(%MediaAsset{}, attrs).valid?
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
