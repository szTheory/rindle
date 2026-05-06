defmodule Rindle.Ops.LifecycleRepairTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaUploadSession, MediaVariant}
  alias Rindle.Ops.LifecycleRepair
  alias Rindle.Workers.ProcessVariant

  @png_1x1 <<
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x02,
    0x00,
    0x00,
    0x00,
    0x90,
    0x77,
    0x53,
    0xDE,
    0x00,
    0x00,
    0x00,
    0x0C,
    0x49,
    0x44,
    0x41,
    0x54,
    0x08,
    0xD7,
    0x63,
    0xF8,
    0xFF,
    0xFF,
    0x3F,
    0x00,
    0x05,
    0xFE,
    0x02,
    0xFE,
    0xDC,
    0x44,
    0x74,
    0x06,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82
  >>

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :fit, width: 64, height: 64],
        large: [mode: :fit, width: 512, height: 512]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "rindle-lifecycle-repair-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)

    previous_tmp_dir = Application.get_env(:rindle, :tmp_dir)
    Application.put_env(:rindle, :tmp_dir, tmp_dir)

    on_exit(fn ->
      if is_nil(previous_tmp_dir) do
        Application.delete_env(:rindle, :tmp_dir)
      else
        Application.put_env(:rindle, :tmp_dir, previous_tmp_dir)
      end

      File.rm_rf(tmp_dir)
    end)

    :ok
  end

  describe "reprobe_asset/1" do
    test "persists only probe-derived fields and clears stale probe columns" do
      asset = insert_asset(%{state: "ready"})
      variant = insert_variant(asset)
      upload_session = insert_upload_session(asset)

      original_updated_at = ~N[2020-01-01 00:00:00]

      Rindle.Repo.update_all(
        Ecto.Query.from(a in MediaAsset, where: a.id == ^asset.id),
        set: [updated_at: original_updated_at]
      )

      expect_download(:audio)

      assert {:ok, report} = LifecycleRepair.reprobe_asset(asset.id)

      updated = Rindle.Repo.get!(MediaAsset, asset.id)

      assert updated.content_type == "audio/mpeg"
      assert updated.kind == "audio"
      assert is_integer(updated.duration_ms)
      assert updated.duration_ms >= 100
      assert updated.has_audio_track == true
      assert is_nil(updated.width)
      assert is_nil(updated.height)
      assert is_nil(updated.has_video_track)

      assert updated.state == asset.state
      assert updated.error_reason == asset.error_reason
      assert updated.metadata == asset.metadata
      assert updated.profile == asset.profile
      assert updated.storage_key == asset.storage_key
      assert updated.filename == asset.filename
      assert updated.byte_size == asset.byte_size
      assert NaiveDateTime.compare(updated.updated_at, original_updated_at) == :gt

      assert Rindle.Repo.get!(MediaVariant, variant.id).updated_at == variant.updated_at

      assert Rindle.Repo.get!(MediaUploadSession, upload_session.id).updated_at ==
               upload_session.updated_at

      assert report == %{
               asset_id: asset.id,
               attempted: 1,
               refreshed: 1,
               errors: 0,
               failures: [],
               refreshed_fields: [:content_type, :kind, :duration_ms, :has_audio_track],
               cleared_fields: [:width, :height, :has_video_track],
               content_type: "audio/mpeg",
               kind: "audio",
               updated_at: updated.updated_at
             }
    end

    test "surfaces probe failures without mutating lifecycle or probe state" do
      asset = insert_asset(%{state: "available"})
      snapshot = Rindle.Repo.get!(MediaAsset, asset.id)

      expect_download(:pdf)

      assert {:error, {:probe_failed, {:no_probe_for_mime, "application/pdf"}}} =
               LifecycleRepair.reprobe_asset(asset)

      unchanged = Rindle.Repo.get!(MediaAsset, asset.id)

      assert unchanged.state == snapshot.state
      assert unchanged.error_reason == snapshot.error_reason
      assert unchanged.metadata == snapshot.metadata
      assert unchanged.content_type == snapshot.content_type
      assert unchanged.kind == snapshot.kind
      assert unchanged.width == snapshot.width
      assert unchanged.height == snapshot.height
      assert unchanged.duration_ms == snapshot.duration_ms
      assert unchanged.has_video_track == snapshot.has_video_track
      assert unchanged.has_audio_track == snapshot.has_audio_track
      assert unchanged.updated_at == snapshot.updated_at
    end
  end

  describe "Rindle.reprobe/1" do
    test "accepts an asset struct and keeps lifecycle state untouched on success" do
      asset = insert_asset(%{state: "degraded"})

      expect_download(:png)

      assert {:ok, report} = Rindle.reprobe(asset)

      updated = Rindle.Repo.get!(MediaAsset, asset.id)

      assert updated.state == "degraded"
      assert updated.kind == "image"
      assert updated.content_type == "image/png"
      assert updated.width == 1
      assert updated.height == 1
      assert is_nil(updated.duration_ms)
      assert is_nil(updated.has_video_track)
      assert is_nil(updated.has_audio_track)

      assert report.refreshed_fields == [:content_type, :kind, :width, :height]
      assert report.cleared_fields == [:duration_ms, :has_video_track, :has_audio_track]
    end
  end

  describe "requeue_failed_variants/2" do
    test "requeues only failed or cancelled variants and preserves ready siblings" do
      asset = insert_asset(%{state: "degraded"})
      failed = insert_variant(asset, %{name: "thumb", state: "failed"})
      cancelled = insert_variant(asset, %{name: "large", state: "cancelled"})

      ready =
        insert_variant(asset, %{
          name: "poster",
          state: "ready",
          recipe_digest: "poster-v1",
          storage_key: "variants/poster.jpg"
        })

      assert {:ok, report} = LifecycleRepair.requeue_failed_variants(asset.id)

      assert report == %{
               asset_id: asset.id,
               selected: 2,
               enqueued: 2,
               skipped: 0,
               errors: 0,
               failures: []
             }

      assert_enqueued(
        worker: ProcessVariant,
        args: %{"asset_id" => asset.id, "variant_name" => failed.name}
      )

      assert_enqueued(
        worker: ProcessVariant,
        args: %{"asset_id" => asset.id, "variant_name" => cancelled.name}
      )

      refute_enqueued(
        worker: ProcessVariant,
        args: %{"asset_id" => asset.id, "variant_name" => ready.name}
      )

      ready = Rindle.Repo.get!(MediaVariant, ready.id)
      assert ready.state == "ready"
      assert ready.storage_key == "variants/poster.jpg"
    end

    test "cancelled variants can resume through the shared worker path after requeue" do
      asset = insert_asset(%{state: "degraded"})
      cancelled = insert_variant(asset, %{name: "thumb", state: "cancelled"})

      expect_download(:png)

      expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
        assert key =~ asset.id
        assert key =~ cancelled.recipe_digest
        {:ok, %{key: key}}
      end)

      assert {:ok, report} =
               LifecycleRepair.requeue_failed_variants(asset.id, variant_names: ["thumb"])

      assert report.selected == 1
      assert report.enqueued == 1
      assert report.errors == 0

      assert :ok =
               perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

      resumed = Rindle.Repo.get!(MediaVariant, cancelled.id)
      asset = Rindle.Repo.get!(MediaAsset, asset.id)

      assert resumed.state == "ready"
      assert is_binary(resumed.storage_key)
      assert asset.state == "ready"
    end

    test "rejects unknown explicit variant names loudly" do
      asset = insert_asset(%{})
      _failed = insert_variant(asset, %{name: "thumb", state: "failed"})

      assert {:error, {:unknown_variant_names, ["missing"]}} =
               LifecycleRepair.requeue_failed_variants(asset.id, variant_names: ["missing"])
    end

    test "returns deterministic no-op report for an empty explicit selection" do
      asset = insert_asset(%{})
      _failed = insert_variant(asset, %{name: "thumb", state: "failed"})

      assert {:ok, report} =
               LifecycleRepair.requeue_failed_variants(asset.id, variant_names: [])

      assert report == %{
               asset_id: asset.id,
               selected: 0,
               enqueued: 0,
               skipped: 0,
               errors: 0,
               failures: []
             }

      refute_enqueued(worker: ProcessVariant)
    end

    test "counts uniqueness conflicts as skipped instead of duplicate work" do
      asset = insert_asset(%{})
      failed = insert_variant(asset, %{name: "thumb", state: "failed"})

      assert {:ok, first} =
               LifecycleRepair.requeue_failed_variants(asset.id, variant_names: ["thumb"])

      assert first.enqueued == 1
      assert first.skipped == 0

      assert {:ok, second} =
               LifecycleRepair.requeue_failed_variants(asset.id, variant_names: ["thumb"])

      assert second.selected == 1
      assert second.enqueued == 0
      assert second.skipped == 1
      assert second.errors == 0
      assert second.failures == []

      jobs =
        Rindle.Repo.all(
          Ecto.Query.from(j in Oban.Job,
            where: j.worker == "Rindle.Workers.ProcessVariant",
            where: fragment("?->>'asset_id' = ?", j.args, ^asset.id),
            where: fragment("?->>'variant_name' = ?", j.args, ^failed.name)
          )
        )

      assert length(jobs) == 1
    end

    test "returns typed failures for explicit ready siblings without mutating them" do
      asset = insert_asset(%{state: "ready"})
      ready = insert_variant(asset, %{name: "thumb", state: "ready"})

      assert {:ok, report} =
               LifecycleRepair.requeue_failed_variants(asset.id, variant_names: ["thumb"])

      assert report.selected == 1
      assert report.enqueued == 0
      assert report.skipped == 0
      assert report.errors == 1

      assert report.failures == [
               %{
                 asset_id: asset.id,
                 variant_id: ready.id,
                 variant_name: "thumb",
                 state: "ready",
                 failure_class: :state_conflict,
                 reason: :state_not_repairable,
                 message:
                   "Variant thumb is ready; only failed or cancelled variants can be requeued."
               }
             ]

      assert Rindle.Repo.get!(MediaVariant, ready.id).state == "ready"

      refute_enqueued(
        worker: ProcessVariant,
        args: %{"asset_id" => asset.id, "variant_name" => "thumb"}
      )
    end
  end

  describe "Rindle.requeue_variants/2" do
    test "accepts asset structs and explicit atom variant names" do
      asset = insert_asset(%{})
      _failed = insert_variant(asset, %{name: "thumb", state: "failed"})
      _cancelled = insert_variant(asset, %{name: "large", state: "cancelled"})

      assert {:ok, report} = Rindle.requeue_variants(asset, variant_names: [:thumb])

      assert report.selected == 1
      assert report.enqueued == 1
      assert report.skipped == 0
      assert report.errors == 0

      assert_enqueued(
        worker: ProcessVariant,
        args: %{"asset_id" => asset.id, "variant_name" => "thumb"}
      )

      refute_enqueued(
        worker: ProcessVariant,
        args: %{"asset_id" => asset.id, "variant_name" => "large"}
      )
    end
  end

  defp insert_asset(overrides) do
    attrs =
      Map.merge(
        %{
          state: "available",
          profile: to_string(TestProfile),
          storage_key: "assets/source.dat",
          filename: "source.dat",
          byte_size: 12_345,
          metadata: %{"keep" => "me"},
          error_reason: "keep me",
          content_type: "video/mp4",
          kind: "video",
          width: 640,
          height: 360,
          duration_ms: 12_000,
          has_video_track: true,
          has_audio_track: true
        },
        overrides
      )

    %MediaAsset{}
    |> MediaAsset.changeset(attrs)
    |> Rindle.Repo.insert!()
  end

  defp insert_variant(asset) do
    insert_variant(asset, %{})
  end

  defp insert_variant(asset, overrides) do
    attrs =
      Map.merge(
        %{
          asset_id: asset.id,
          name: "thumb",
          state: "ready",
          recipe_digest: TestProfile.recipe_digest(:thumb),
          storage_key: "variants/thumb.jpg",
          output_kind: "image"
        },
        overrides
      )

    %MediaVariant{}
    |> MediaVariant.changeset(attrs)
    |> Rindle.Repo.insert!()
  end

  defp insert_upload_session(asset) do
    %MediaUploadSession{}
    |> MediaUploadSession.changeset(%{
      asset_id: asset.id,
      state: "completed",
      upload_key: "uploads/source.dat",
      upload_strategy: "presigned_put",
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
      verified_at: DateTime.utc_now()
    })
    |> Rindle.Repo.insert!()
  end

  defp expect_download(kind) do
    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      write_fixture!(kind, tmp_path)
      {:ok, tmp_path}
    end)
  end

  defp write_fixture!(:png, tmp_path), do: File.write!(tmp_path, @png_1x1)

  defp write_fixture!(:pdf, tmp_path) do
    File.write!(tmp_path, "%PDF-1.7\n1 0 obj\n<<>>\nendobj\n")
  end

  defp write_fixture!(:audio, tmp_path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=660:duration=0.2",
      "-c:a",
      "libmp3lame",
      "-f",
      "mp3",
      tmp_path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end
end
