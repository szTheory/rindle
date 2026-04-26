defmodule Rindle.Ops.MetadataBackfillTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Rindle.Ops.MetadataBackfill
  alias Rindle.Domain.MediaAsset

  setup :set_mox_from_context
  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_asset(overrides \\ %{}) do
    %MediaAsset{}
    |> MediaAsset.changeset(
      Map.merge(
        %{
          state: "ready",
          profile: "TestProfile",
          storage_key: "assets/#{Ecto.UUID.generate()}.jpg",
          metadata: %{}
        },
        overrides
      )
    )
    |> Rindle.Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # backfill_metadata/1 — success paths
  # ---------------------------------------------------------------------------

  describe "backfill_metadata/1 — success" do
    test "reruns analyzer for all ready assets and persists updated metadata" do
      asset1 = create_asset(%{state: "ready"})
      asset2 = create_asset(%{state: "ready"})

      expect(Rindle.StorageMock, :download, 2, fn key, tmp_path, _opts ->
        File.write!(tmp_path, "fake media bytes for #{key}")
        {:ok, tmp_path}
      end)

      expect(Rindle.AnalyzerMock, :analyze, 2, fn _path ->
        {:ok, %{"width" => 100, "height" => 200, "format" => "jpeg"}}
      end)

      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      assert report.assets_found >= 2
      assert report.assets_updated >= 2
      assert report.failures == 0

      # Verify persisted
      updated1 = Rindle.Repo.get!(MediaAsset, asset1.id)
      updated2 = Rindle.Repo.get!(MediaAsset, asset2.id)
      assert updated1.metadata["width"] == 100
      assert updated2.metadata["format"] == "jpeg"
    end

    test "does not process assets in non-backfillable states" do
      _staged = create_asset(%{state: "staged"})
      _quarantined = create_asset(%{state: "quarantined"})
      _deleted = create_asset(%{state: "deleted"})
      ready = create_asset(%{state: "ready"})

      expect(Rindle.StorageMock, :download, 1, fn _key, tmp_path, _opts ->
        File.write!(tmp_path, "bytes")
        {:ok, tmp_path}
      end)

      expect(Rindle.AnalyzerMock, :analyze, 1, fn _path ->
        {:ok, %{"width" => 50}}
      end)

      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      # Only the ready asset is backfilled
      assert report.assets_updated == 1
      updated = Rindle.Repo.get!(MediaAsset, ready.id)
      assert updated.metadata["width"] == 50
    end

    test "returns zero counts when no eligible assets exist" do
      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      assert report.assets_found == 0
      assert report.assets_updated == 0
      assert report.failures == 0
    end

    test "processes assets in available and degraded states" do
      _available = create_asset(%{state: "available"})
      _degraded = create_asset(%{state: "degraded"})

      expect(Rindle.StorageMock, :download, 2, fn _key, tmp_path, _opts ->
        File.write!(tmp_path, "bytes")
        {:ok, tmp_path}
      end)

      expect(Rindle.AnalyzerMock, :analyze, 2, fn _path ->
        {:ok, %{"format" => "png"}}
      end)

      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      assert report.assets_updated == 2
    end
  end

  # ---------------------------------------------------------------------------
  # backfill_metadata/1 — failure paths
  # ---------------------------------------------------------------------------

  describe "backfill_metadata/1 — failures" do
    test "counts storage download failures and continues" do
      asset1 = create_asset()
      asset2 = create_asset()

      # asset1 fails download, asset2 succeeds
      expect(Rindle.StorageMock, :download, 2, fn key, tmp_path, _opts ->
        if String.ends_with?(key, Path.basename(asset1.storage_key)) do
          {:error, :not_found}
        else
          File.write!(tmp_path, "bytes")
          {:ok, tmp_path}
        end
      end)

      expect(Rindle.AnalyzerMock, :analyze, 1, fn _path ->
        {:ok, %{"width" => 10}}
      end)

      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      assert report.assets_found == 2
      assert report.assets_updated == 1
      assert report.failures == 1
    end

    test "counts analyzer failures and continues" do
      _asset1 = create_asset()
      _asset2 = create_asset()

      expect(Rindle.StorageMock, :download, 2, fn _key, tmp_path, _opts ->
        File.write!(tmp_path, "bytes")
        {:ok, tmp_path}
      end)

      expect(Rindle.AnalyzerMock, :analyze, 2, fn _path ->
        {:error, :unsupported_format}
      end)

      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      assert report.assets_found == 2
      assert report.assets_updated == 0
      assert report.failures == 2
    end

    test "returns {:ok, report} with all failures counted when everything fails" do
      _asset = create_asset()

      expect(Rindle.StorageMock, :download, 1, fn _key, _tmp_path, _opts ->
        {:error, :timeout}
      end)

      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      assert report.failures == 1
      assert report.assets_updated == 0
    end

    test "handles filter by profile" do
      asset1 = create_asset(%{profile: "Elixir.ProfileA"})
      _asset2 = create_asset(%{profile: "Elixir.ProfileB"})

      expect(Rindle.StorageMock, :download, 1, fn key, tmp_path, _opts ->
        assert key == asset1.storage_key
        File.write!(tmp_path, "bytes")
        {:ok, tmp_path}
      end)

      expect(Rindle.AnalyzerMock, :analyze, 1, fn _path ->
        {:ok, %{"source" => "profile_a"}}
      end)

      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock, profile: "Elixir.ProfileA"]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      assert report.assets_found == 1
      assert report.assets_updated == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Report shape
  # ---------------------------------------------------------------------------

  describe "backfill_metadata/1 — report shape" do
    test "report contains required keys" do
      opts = [storage: Rindle.StorageMock, analyzer: Rindle.AnalyzerMock]
      {:ok, report} = MetadataBackfill.backfill_metadata(opts)

      assert Map.has_key?(report, :assets_found)
      assert Map.has_key?(report, :assets_updated)
      assert Map.has_key?(report, :failures)
    end
  end
end
