defmodule Rindle.Domain.MediaProviderAssetTest do
  use Rindle.DataCase, async: true

  alias Rindle.Domain.MediaAsset
  alias Rindle.Domain.MediaProviderAsset
  alias Rindle.Repo

  describe "migration smoke" do
    test "media_provider_assets table exists with expected columns" do
      {:ok, %{rows: rows}} =
        Rindle.Repo.query(
          "SELECT column_name FROM information_schema.columns " <>
            "WHERE table_name = 'media_provider_assets' ORDER BY column_name",
          []
        )

      column_names = rows |> List.flatten() |> MapSet.new()

      for col <- ~w(id asset_id profile provider_name provider_asset_id
                    playback_ids playback_policy ingest_mode state
                    last_event_id last_event_at last_sync_error
                    raw_provider_metadata inserted_at updated_at) do
        assert col in column_names, "expected column #{col} in media_provider_assets"
      end
    end

    test "partial-where unique index exists on (provider_name, provider_asset_id)" do
      {:ok, %{rows: rows}} =
        Rindle.Repo.query(
          "SELECT indexdef FROM pg_indexes " <>
            "WHERE tablename = 'media_provider_assets' " <>
            "AND indexname = 'media_provider_assets_provider_name_provider_asset_id_index'",
          []
        )

      assert length(rows) == 1
      [[indexdef]] = rows
      assert indexdef =~ "WHERE"
      assert indexdef =~ "provider_asset_id IS NOT NULL"
    end
  end

  describe "schema source + reflection" do
    test "maps to the media_provider_assets table" do
      assert "media_provider_assets" == MediaProviderAsset.__schema__(:source)
    end

    test "states/0 returns the locked 6-state vocabulary" do
      assert MediaProviderAsset.states() ==
               ~w(pending uploading processing ready errored deleted)
    end

    test "declares belongs_to :asset, MediaAsset, foreign_key: :asset_id" do
      assert MediaProviderAsset.__schema__(:association, :asset).related ==
               Rindle.Domain.MediaAsset

      assert MediaProviderAsset.__schema__(:association, :asset).owner_key == :asset_id
    end
  end

  describe "changeset state validation" do
    setup do
      {:ok, asset: insert_media_asset!()}
    end

    for state <- ~w(pending uploading processing ready errored deleted) do
      test "accepts state=#{state}", %{asset: asset} do
        changeset =
          MediaProviderAsset.changeset(%MediaProviderAsset{}, base_attrs(asset, unquote(state)))

        assert changeset.valid?,
               "expected state=#{unquote(state)} to be valid; got: #{inspect(changeset.errors)}"
      end
    end

    test "rejects unknown states", %{asset: asset} do
      for bad <-
            ~w(validating analyzing unknown promoting available transcoding degraded quarantined) do
        changeset = MediaProviderAsset.changeset(%MediaProviderAsset{}, base_attrs(asset, bad))
        refute changeset.valid?, "expected state=#{bad} to be rejected"
        assert {"is invalid", _meta} = Keyword.fetch!(changeset.errors, :state)
      end
    end
  end

  describe "changeset validate_required" do
    setup do
      {:ok, asset: insert_media_asset!()}
    end

    test "rejects missing :asset_id", %{asset: asset} do
      attrs = base_attrs(asset, "pending") |> Map.delete(:asset_id)
      changeset = MediaProviderAsset.changeset(%MediaProviderAsset{}, attrs)
      refute changeset.valid?
      assert {"can't be blank", _meta} = Keyword.fetch!(changeset.errors, :asset_id)
    end

    test "rejects missing :profile", %{asset: asset} do
      attrs = base_attrs(asset, "pending") |> Map.delete(:profile)
      changeset = MediaProviderAsset.changeset(%MediaProviderAsset{}, attrs)
      refute changeset.valid?
      assert {"can't be blank", _meta} = Keyword.fetch!(changeset.errors, :profile)
    end

    test "rejects missing :provider_name", %{asset: asset} do
      attrs = base_attrs(asset, "pending") |> Map.delete(:provider_name)
      changeset = MediaProviderAsset.changeset(%MediaProviderAsset{}, attrs)
      refute changeset.valid?
      assert {"can't be blank", _meta} = Keyword.fetch!(changeset.errors, :provider_name)
    end

    test "rejects missing :state", %{asset: asset} do
      attrs = base_attrs(asset, "pending") |> Map.put(:state, nil)
      changeset = MediaProviderAsset.changeset(%MediaProviderAsset{}, attrs)
      refute changeset.valid?
      assert {"can't be blank", _meta} = Keyword.fetch!(changeset.errors, :state)
    end
  end

  describe "changeset last_sync_error truncation (D-09)" do
    test "rejects last_sync_error longer than 4096 chars" do
      asset = insert_media_asset!()
      long = String.duplicate("x", 4097)

      attrs = base_attrs(asset, "errored") |> Map.put(:last_sync_error, long)
      changeset = MediaProviderAsset.changeset(%MediaProviderAsset{}, attrs)

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {field, _} -> field == :last_sync_error end)
    end

    test "accepts last_sync_error of exactly 4096 chars" do
      asset = insert_media_asset!()
      max = String.duplicate("x", 4096)

      attrs = base_attrs(asset, "errored") |> Map.put(:last_sync_error, max)
      changeset = MediaProviderAsset.changeset(%MediaProviderAsset{}, attrs)

      assert changeset.valid?
    end
  end

  describe "unique constraints (D-10)" do
    setup do
      {:ok, asset: insert_media_asset!()}
    end

    test "enforces unique (provider_name, provider_asset_id) where not null", %{asset: asset} do
      shared_id = "mux-asset-#{Ecto.UUID.generate()}"

      attrs1 = base_attrs(asset, "ready") |> Map.put(:provider_asset_id, shared_id)

      assert {:ok, _row} =
               %MediaProviderAsset{} |> MediaProviderAsset.changeset(attrs1) |> Repo.insert()

      # Second insert: different (asset_id, profile, provider_name) tuple but
      # same (provider_name, provider_asset_id) — must collide on the partial-where
      # unique index.
      asset2 = insert_media_asset!()
      attrs2 = base_attrs(asset2, "ready") |> Map.put(:provider_asset_id, shared_id)

      assert {:error, changeset} =
               %MediaProviderAsset{} |> MediaProviderAsset.changeset(attrs2) |> Repo.insert()

      assert {"has already been taken", _meta} =
               Keyword.fetch!(changeset.errors, :provider_name)
    end

    test "enforces unique (asset_id, profile, provider_name)", %{asset: asset} do
      attrs = base_attrs(asset, "pending") |> Map.put(:provider_asset_id, nil)

      assert {:ok, _row} =
               %MediaProviderAsset{} |> MediaProviderAsset.changeset(attrs) |> Repo.insert()

      assert {:error, changeset} =
               %MediaProviderAsset{} |> MediaProviderAsset.changeset(attrs) |> Repo.insert()

      assert Enum.any?(changeset.errors, fn {field, {msg, _}} ->
               field in [:asset_id, :profile, :provider_name] and msg == "has already been taken"
             end)
    end

    test "foreign_key_constraint(:asset_id) declared", %{asset: _asset} do
      bogus_id = Ecto.UUID.generate()
      attrs = base_attrs(%MediaAsset{id: bogus_id}, "pending")

      assert {:error, changeset} =
               %MediaProviderAsset{} |> MediaProviderAsset.changeset(attrs) |> Repo.insert()

      assert {"does not exist", _meta} = Keyword.fetch!(changeset.errors, :asset_id)
    end
  end

  describe "Inspect redaction (security invariant 14, D-14)" do
    test "redacts provider_asset_id to last 4 chars when length >= 4" do
      record = %MediaProviderAsset{provider_asset_id: "abc-123-XYZ-9999"}
      output = inspect(record)

      assert output =~ "...9999"
      refute output =~ "abc-123"
      refute output =~ "XYZ"
    end

    test "leaves provider_asset_id as nil when nil (no crash)" do
      record = %MediaProviderAsset{provider_asset_id: nil}
      output = inspect(record)

      assert output =~ "provider_asset_id: nil"
    end

    test "redacts short provider_asset_id (< 4 chars) to opaque sentinel" do
      record = %MediaProviderAsset{provider_asset_id: "ab"}
      output = inspect(record)

      assert output =~ "...redacted"
      refute output =~ "\"ab\""
    end

    test "redacts raw_provider_metadata to %{redacted: true}" do
      record = %MediaProviderAsset{
        raw_provider_metadata: %{secret: "supersecret-token-XYZ"}
      }

      output = inspect(record)

      assert output =~ "redacted: true"
      refute output =~ "supersecret-token-XYZ"
      refute output =~ "secret:"
    end

    test "redacts both provider_asset_id and raw_provider_metadata in one struct" do
      record = %MediaProviderAsset{
        provider_asset_id: "live-token-DEAD-BEEF",
        raw_provider_metadata: %{token: "leak-target"}
      }

      output = inspect(record)

      assert output =~ "...BEEF"
      assert output =~ "redacted: true"
      refute output =~ "live-token-DEAD"
      refute output =~ "leak-target"
    end
  end

  defp insert_media_asset! do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "staged",
      storage_key: "assets/#{Ecto.UUID.generate()}",
      profile: "image",
      kind: "image"
    })
    |> Repo.insert!()
  end

  defp base_attrs(asset, state) do
    %{
      asset_id: asset.id,
      profile: "Rindle.TestProfile",
      provider_name: "mux",
      state: state,
      playback_ids: [],
      raw_provider_metadata: %{}
    }
  end
end
