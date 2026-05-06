defmodule Rindle.Domain.MediaProviderAssetTest do
  use Rindle.DataCase, async: true

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
end
