defmodule Rindle.Workers.ProcessVariantTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Workers.ProcessVariant

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :crop, width: 10, height: 10]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule AVProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        hero: [kind: :video, preset: :web_720p]
      ],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  defmodule MuxAVProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        hero: [kind: :video, preset: :web_720p],
        poster: [kind: :image, preset: :video_poster_scene]
      ],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [
        streaming: [
          provider: Rindle.Streaming.Provider.Mux,
          playback_policy: :signed,
          ingest_mode: :server_push,
          source_variant: :hero
        ]
      ]
  end

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "rindle-process-variant-#{System.unique_integer([:positive])}")

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

    start_pubsub!()

    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(TestProfile),
        storage_key: "test/key.jpg"
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "thumb",
        state: "planned",
        recipe_digest: TestProfile.recipe_digest(:thumb),
        output_kind: "image"
      })
      |> Rindle.Repo.insert!()

    {:ok, asset: asset, variant: variant, tmp_dir: tmp_dir}
  end

  test "generates and stores variant successfully with deterministic storage key and temp cleanup",
       %{
         asset: asset,
         variant: variant,
         tmp_dir: tmp_dir
       } do
    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      File.write!(
        tmp_path,
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
          0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
          0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
          0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
          0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>
      )

      {:ok, tmp_path}
    end)

    expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
      assert key =~ asset.id
      assert key =~ "thumb"
      assert key =~ variant.recipe_digest
      {:ok, %{key: key}}
    end)

    assert :ok = perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    asset = Rindle.Repo.get!(MediaAsset, asset.id)

    assert variant.state == "ready"
    assert variant.storage_key =~ asset.id
    assert variant.storage_key =~ variant.recipe_digest
    assert variant.byte_size > 0
    assert variant.generated_at != nil
    assert variant.content_type == "image/jpeg"
    assert asset.state == "ready"
    assert run_temp_entries(tmp_dir) == []
  end

  test "marks failed variants degraded and cleans temp roots on handled failure", %{
    asset: asset,
    variant: variant,
    tmp_dir: tmp_dir
  } do
    expect(Rindle.StorageMock, :download, fn _key, _tmp, _opts ->
      {:error, :not_found}
    end)

    assert {:error, :variant_source_not_found} =
             perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    asset = Rindle.Repo.get!(MediaAsset, asset.id)

    assert variant.state == "failed"
    assert variant.error_reason == inspect(:variant_source_not_found)
    assert asset.state == "degraded"
    assert run_temp_entries(tmp_dir) == []
  end

  test "cancel_processing/1 returns not_processing when the asset has no queued or executing work",
       %{
         asset: asset,
         tmp_dir: tmp_dir
       } do
    assert {:error, :not_processing} = Rindle.cancel_processing(asset.id)

    asset = Rindle.Repo.get!(MediaAsset, asset.id)

    assert asset.state == "available"
    assert run_temp_entries(tmp_dir) == []
  end

  test "cancel_processing/1 cancels queued jobs, marks variants cancelled, and broadcasts public events",
       %{
         asset: asset,
         variant: variant,
         tmp_dir: tmp_dir
       } do
    queued_variant =
      variant
      |> MediaVariant.changeset(%{state: "queued"})
      |> Rindle.Repo.update!()

    {:ok, job} =
      ProcessVariant.new(%{"asset_id" => asset.id, "variant_name" => queued_variant.name})
      |> Oban.insert()

    Phoenix.PubSub.subscribe(Rindle.PubSub, "rindle:variant:#{queued_variant.id}")
    Phoenix.PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{asset.id}")

    assert :ok = Rindle.cancel_processing(asset.id)

    queued_variant = Rindle.Repo.get!(MediaVariant, queued_variant.id)
    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    cancelled_job = Rindle.Repo.get!(Oban.Job, job.id)
    asset_id = asset.id
    variant_id = queued_variant.id

    assert queued_variant.state == "cancelled"
    assert queued_variant.error_reason =~ "variant_processing_cancelled"
    assert asset.state == "degraded"
    assert cancelled_job.state == "cancelled"

    assert_received {:rindle_event, :variant_cancelled,
                     %{asset_id: ^asset_id, variant_id: ^variant_id, state: "cancelled"}}

    assert_received {:rindle_event, :variant_cancelled,
                     %{asset_id: ^asset_id, variant_id: ^variant_id, state: "cancelled"}}

    assert run_temp_entries(tmp_dir) == []
  end

  test "cancel_processing/1 cancels executing jobs and persists the visible cancelled outcome",
       %{asset: asset, variant: variant, tmp_dir: tmp_dir} do
    processing_variant =
      variant
      |> MediaVariant.changeset(%{state: "processing"})
      |> Rindle.Repo.update!()

    {:ok, job} =
      ProcessVariant.new(%{"asset_id" => asset.id, "variant_name" => processing_variant.name})
      |> Oban.insert()

    Rindle.Repo.update_all(
      Ecto.Query.from(j in Oban.Job, where: j.id == ^job.id),
      set: [
        state: "executing",
        attempted_at: DateTime.utc_now(),
        attempted_by: ["test", "worker"]
      ]
    )

    assert :ok = Rindle.cancel_processing(asset.id)

    processing_variant = Rindle.Repo.get!(MediaVariant, processing_variant.id)
    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    cancelled_job = Rindle.Repo.get!(Oban.Job, job.id)

    assert processing_variant.state == "cancelled"
    assert processing_variant.error_reason =~ "variant_processing_cancelled"
    assert asset.state == "degraded"
    assert cancelled_job.state == "cancelled"
    assert run_temp_entries(tmp_dir) == []
  end

  @tag :race_guard
  test "cancels stale-source promotions before the ready write", %{
    asset: asset,
    variant: variant,
    tmp_dir: tmp_dir
  } do
    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      File.write!(
        tmp_path,
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
          0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
          0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
          0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
          0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>
      )

      {:ok, tmp_path}
    end)

    expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
      Rindle.Repo.update_all(
        Ecto.Query.from(a in MediaAsset, where: a.id == ^asset.id),
        set: [storage_key: "test/reuploaded.jpg"]
      )

      {:ok, %{key: key}}
    end)

    assert {:cancel, :variant_source_not_found} =
             perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    asset = Rindle.Repo.get!(MediaAsset, asset.id)

    assert variant.state == "cancelled"
    assert variant.error_reason == inspect(:variant_source_not_found)
    assert asset.state == "degraded"
    assert run_temp_entries(tmp_dir) == []
  end

  @tag :worker_opts
  test "builds AV job options with dedicated queue, timeout, and active-job uniqueness" do
    args =
      ProcessVariant.job_args_for_variant("asset-1", "hero", %{kind: :video, preset: :web_720p})

    opts = ProcessVariant.job_opts_for_variant(%{kind: :video, preset: :web_720p})

    {:ok, first_job} =
      ProcessVariant.new(args, opts)
      |> Oban.insert()

    {:ok, second_job} =
      ProcessVariant.new(args, opts)
      |> Oban.insert()

    assert first_job.queue == "rindle_media"
    assert first_job.args["timeout"] == :timer.minutes(10)
    assert ProcessVariant.timeout(first_job) == :timer.minutes(10)
    assert second_job.conflict?
  end

  test "build_job/3 reuses the shared args and uniqueness contract" do
    job =
      ProcessVariant.build_job("asset-1", "thumb", %{mode: :crop, width: 10, height: 10})

    assert job.changes.args == %{"asset_id" => "asset-1", "variant_name" => "thumb"}
    assert job.changes.queue == "rindle_process"

    assert job.changes.unique == %{
             fields: [:args, :worker, :queue],
             keys: [:asset_id, :variant_name],
             period: :infinity,
             states: [:available, :scheduled, :executing, :retryable],
             timestamp: :inserted_at
           }
  end

  test "processes an explicitly resumed cancelled variant through the queued transition", %{
    asset: asset,
    variant: variant,
    tmp_dir: tmp_dir
  } do
    cancelled_variant =
      variant
      |> MediaVariant.changeset(%{
        state: "cancelled",
        error_reason: inspect(:variant_processing_cancelled)
      })
      |> Rindle.Repo.update!()

    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      File.write!(
        tmp_path,
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
          0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
          0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
          0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
          0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>
      )

      {:ok, tmp_path}
    end)

    expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
      assert key =~ asset.id
      assert key =~ "thumb"
      assert key =~ cancelled_variant.recipe_digest
      {:ok, %{key: key}}
    end)

    assert :ok = perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

    variant = Rindle.Repo.get!(MediaVariant, cancelled_variant.id)
    asset = Rindle.Repo.get!(MediaAsset, asset.id)

    assert variant.state == "ready"
    assert variant.storage_key =~ asset.id
    assert variant.error_reason == nil
    assert asset.state == "ready"
    assert run_temp_entries(tmp_dir) == []
  end

  test "fails AV variants before processing on unsupported ephemeral runtimes", %{
    tmp_dir: tmp_dir
  } do
    System.put_env("LAMBDA_TASK_ROOT", "/tmp/lambda")

    on_exit(fn ->
      System.delete_env("LAMBDA_TASK_ROOT")
    end)

    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(AVProfile),
        kind: "video",
        storage_key: "test/source.mp4",
        duration_ms: 1_200
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "hero",
        state: "planned",
        recipe_digest: AVProfile.recipe_digest(:hero),
        output_kind: "video"
      })
      |> Rindle.Repo.insert!()

    assert {:error, :processor_capability_missing} =
             perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "hero"})

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    asset = Rindle.Repo.get!(MediaAsset, asset.id)

    assert variant.state == "failed"
    assert variant.error_reason == inspect(:processor_capability_missing)
    assert asset.state == "degraded"
    assert run_temp_entries(tmp_dir) == []
  end

  test "rejects truncated AV outputs before upload and ready flip", %{tmp_dir: tmp_dir} do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(AVProfile),
        kind: "video",
        storage_key: "test/source.mp4",
        duration_ms: 4_000
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "hero",
        state: "planned",
        recipe_digest: AVProfile.recipe_digest(:hero),
        output_kind: "video"
      })
      |> Rindle.Repo.insert!()

    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      build_video_fixture!(tmp_path)
      {:ok, tmp_path}
    end)

    assert {:error, :capability_drift} =
             perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "hero"})

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    asset = Rindle.Repo.get!(MediaAsset, asset.id)

    assert variant.state == "failed"
    assert variant.error_reason == inspect(:capability_drift)
    assert is_nil(variant.storage_key)
    assert asset.state == "degraded"
    assert run_temp_entries(tmp_dir) == []
  end

  test "broadcasts public LiveView events to both variant and asset topics", %{tmp_dir: tmp_dir} do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(AVProfile),
        kind: "video",
        storage_key: "test/source.mp4",
        duration_ms: 1_200
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "hero",
        state: "planned",
        recipe_digest: AVProfile.recipe_digest(:hero),
        output_kind: "video"
      })
      |> Rindle.Repo.insert!()

    Phoenix.PubSub.subscribe(Rindle.PubSub, "rindle:variant:#{variant.id}")
    Phoenix.PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{asset.id}")

    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      build_video_fixture!(tmp_path)
      {:ok, tmp_path}
    end)

    expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
      {:ok, %{key: key}}
    end)

    assert :ok = perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "hero"})

    asset_id = asset.id
    variant_id = variant.id

    assert_received {:rindle_event, :variant_started,
                     %{
                       asset_id: ^asset_id,
                       progress: 0,
                       variant_id: ^variant_id,
                       variant_name: "hero",
                       state: "processing"
                     }}

    assert_received {:rindle_event, :variant_started,
                     %{
                       asset_id: ^asset_id,
                       progress: 0,
                       variant_id: ^variant_id,
                       variant_name: "hero",
                       state: "processing"
                     }}

    assert_received {:rindle_event, :variant_ready,
                     %{
                       asset_id: ^asset_id,
                       progress: 100,
                       variant_id: ^variant_id,
                       variant_name: "hero",
                       state: "ready"
                     }}

    assert_received {:rindle_event, :variant_ready,
                     %{
                       asset_id: ^asset_id,
                       progress: 100,
                       variant_id: ^variant_id,
                       variant_name: "hero",
                       state: "ready"
                     }}

    refute_received {:rindle_variant_progress, _payload}
    refute_received {:rindle_event, :variant_progress, _payload}
    assert run_temp_entries(tmp_dir) == []
  end

  test "enqueues MuxIngestVariant when the configured streaming source_variant reaches ready",
       %{tmp_dir: tmp_dir} do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(MuxAVProfile),
        kind: "video",
        storage_key: "test/source.mp4",
        duration_ms: 1_200
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "hero",
        state: "planned",
        recipe_digest: MuxAVProfile.recipe_digest(:hero),
        output_kind: "video"
      })
      |> Rindle.Repo.insert!()

    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      build_video_fixture!(tmp_path)
      {:ok, tmp_path}
    end)

    expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
      {:ok, %{key: key}}
    end)

    assert :ok = perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "hero"})

    assert_enqueued(
      worker: Rindle.Workers.MuxIngestVariant,
      queue: :rindle_provider,
      args: %{
        "asset_id" => asset.id,
        "profile" => to_string(MuxAVProfile),
        "variant_name" => "hero",
        "expected_storage_key" => "test/source.mp4",
        "expected_recipe_digest" => MuxAVProfile.recipe_digest(:hero)
      }
    )

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    assert variant.state == "ready"
    assert run_temp_entries(tmp_dir) == []
  end

  test "does not enqueue MuxIngestVariant for non-source variants on streaming-enabled profiles",
       %{tmp_dir: tmp_dir} do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(MuxAVProfile),
        kind: "video",
        storage_key: "test/source.mp4",
        duration_ms: 1_200
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "poster",
        state: "planned",
        recipe_digest: MuxAVProfile.recipe_digest(:poster),
        output_kind: "image"
      })
      |> Rindle.Repo.insert!()

    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      build_video_fixture!(tmp_path)
      {:ok, tmp_path}
    end)

    expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
      {:ok, %{key: key}}
    end)

    assert :ok =
             perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "poster"})

    refute_enqueued(
      worker: Rindle.Workers.MuxIngestVariant,
      args: %{
        "asset_id" => asset.id,
        "variant_name" => "poster"
      }
    )

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    assert variant.state == "ready"
    assert run_temp_entries(tmp_dir) == []
  end

  defp run_temp_entries(tmp_dir) do
    tmp_dir
    |> Path.join("Rindle.tmp")
    |> File.ls()
    |> case do
      {:ok, entries} -> entries
      {:error, :enoent} -> []
    end
  end

  defp build_video_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "testsrc=size=320x180:rate=30:duration=1.2",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=880:sample_rate=48000:duration=1.2",
      "-map",
      "0:v:0",
      "-map",
      "1:a:0",
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-c:a",
      "aac",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end

  defp start_pubsub! do
    case Process.whereis(Rindle.PubSub) do
      nil ->
        start_supervised!({Phoenix.PubSub, name: Rindle.PubSub})

      _pid ->
        :ok
    end
  end
end
