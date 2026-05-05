defmodule Rindle.Workers.PromoteAssetTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Workers.PromoteAsset

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
        thumb: [mode: :crop, width: 100, height: 100],
        large: [mode: :fit, width: 800, height: 600]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule QueueAwareProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100],
        hero: [kind: :video, preset: :web_720p],
        preview: [kind: :audio, preset: :m4a_128k]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "rindle-promote-asset-#{System.unique_integer([:positive])}")

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

    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "analyzing",
        profile: to_string(TestProfile),
        storage_key: "test/key.jpg"
      })
      |> Rindle.Repo.insert!()

    {:ok, asset: asset, tmp_dir: tmp_dir}
  end

  test "promotes asset to available and enqueues variants", %{asset: asset} do
    expect_download(:png)

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"
    assert asset.kind == "image"
    assert asset.width == 1
    assert asset.height == 1

    # Check variants
    variants = Rindle.Repo.all(MediaVariant)
    assert length(variants) == 2
    assert Enum.any?(variants, fn v -> v.name == "thumb" and v.state == "planned" end)
    assert Enum.any?(variants, fn v -> v.name == "large" and v.state == "planned" end)

    # Check Oban jobs
    assert_enqueued worker: Rindle.Workers.ProcessVariant,
                    args: %{"asset_id" => asset.id, "variant_name" => "thumb"}

    assert_enqueued worker: Rindle.Workers.ProcessVariant,
                    args: %{"asset_id" => asset.id, "variant_name" => "large"}
  end

  test "uses normalized variant specs to route AV jobs onto the media queue" do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "analyzing",
        profile: to_string(QueueAwareProfile),
        storage_key: "test/queue-aware.jpg"
      })
      |> Rindle.Repo.insert!()

    expect_download(:png)

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    variants =
      Rindle.Repo.all(
        Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id, order_by: v.name)
      )

    assert Enum.map(variants, &{&1.name, &1.output_kind}) == [
             {"hero", "video"},
             {"preview", "audio"},
             {"thumb", "image"}
           ]

    jobs =
      Rindle.Repo.all(
        Ecto.Query.from(j in Oban.Job,
          where: j.worker == "Rindle.Workers.ProcessVariant",
          where: fragment("?->>'asset_id' = ?", j.args, ^asset.id)
        )
      )

    assert Enum.any?(jobs, &(&1.args["variant_name"] == "thumb" and &1.queue == "rindle_process"))

    assert Enum.any?(jobs, fn job ->
             job.args["variant_name"] == "hero" and job.queue == "rindle_media" and
               job.args["timeout"] == :timer.minutes(10)
           end)

    assert Enum.any?(jobs, fn job ->
             job.args["variant_name"] == "preview" and job.queue == "rindle_media" and
               job.args["timeout"] == :timer.minutes(10)
           end)
  end

  test "handles assets starting from validating state", %{asset: asset} do
    {:ok, asset} = asset |> MediaAsset.changeset(%{state: "validating"}) |> Rindle.Repo.update()
    expect_download(:png)

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"
    assert asset.kind == "image"
    assert asset.width == 1
    assert asset.height == 1
  end

  test "writes video probe fields before promotion", %{asset: asset} do
    expect_download({:video, String.duplicate("a", 1100) <> "\nscript"})

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"
    assert asset.kind == "video"
    assert asset.width == 16
    assert asset.height == 16
    assert is_integer(asset.duration_ms)
    assert asset.duration_ms >= 100
    assert asset.has_video_track == true
    assert asset.has_audio_track == true
    assert is_map(asset.metadata)
    assert byte_size(asset.metadata["format"]["title"]) <= 1024
    refute String.contains?(asset.metadata["format"]["title"], "\n")
  end

  test "writes audio probe fields before promotion", %{asset: asset} do
    expect_download(:audio)

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"
    assert asset.kind == "audio"
    assert is_integer(asset.duration_ms)
    assert asset.duration_ms >= 100
    assert is_nil(asset.has_video_track)
    assert asset.has_audio_track == true
    assert is_nil(asset.width)
    assert is_nil(asset.height)
  end

  test "quarantines when probe fails", %{asset: asset} do
    expect_download(:corrupt_png)

    assert {:error, {:quarantined, _reason}} =
             perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "quarantined"
    assert is_binary(asset.error_reason)
  end

  test "quarantines unsupported mime types", %{asset: asset} do
    expect_download(:pdf)

    assert {:error, {:quarantined, {:no_probe_for_mime, "application/pdf"}}} =
             perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "quarantined"
    assert asset.error_reason == "{:no_probe_for_mime, \"application/pdf\"}"
  end

  test "deletes the probe tempfile on success", %{asset: asset, tmp_dir: tmp_dir} do
    before_files = probe_tempfiles(tmp_dir)
    expect_download(:png)

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    assert probe_tempfiles(tmp_dir) == before_files
  end

  test "deletes the probe tempfile on failure", %{asset: asset, tmp_dir: tmp_dir} do
    before_files = probe_tempfiles(tmp_dir)
    expect_download(:corrupt_png)

    assert {:error, {:quarantined, _reason}} =
             perform_job(PromoteAsset, %{"asset_id" => asset.id})

    assert probe_tempfiles(tmp_dir) == before_files
  end

  test "retries from analyzing by probing again when typed fields are empty", %{asset: asset} do
    expect_download(:png)
    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})
    Rindle.Repo.delete_all(MediaVariant)

    Rindle.Repo.update_all(
      Ecto.Query.from(a in MediaAsset, where: a.id == ^asset.id),
      set: [state: "analyzing", width: nil, height: nil]
    )

    expect_download(:png)

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"
    assert asset.kind == "image"
    assert asset.width == 1
    assert asset.height == 1
  end

  defp expect_download(kind) do
    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      write_fixture!(kind, tmp_path)
      {:ok, tmp_path}
    end)
  end

  defp write_fixture!(:png, tmp_path), do: File.write!(tmp_path, @png_1x1)

  defp write_fixture!(:corrupt_png, tmp_path) do
    File.write!(tmp_path, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01, 0x02>>)
  end

  defp write_fixture!(:pdf, tmp_path) do
    File.write!(tmp_path, "%PDF-1.7\n1 0 obj\n<<>>\nendobj\n")
  end

  defp write_fixture!({:video, title}, tmp_path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "testsrc=size=16x16:rate=1:duration=0.2",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=1000:duration=0.2",
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-c:a",
      "aac",
      "-f",
      "mp4",
      "-metadata",
      "title=#{title}",
      tmp_path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
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

  defp probe_tempfiles(dir) do
    case File.ls(dir) do
      {:ok, files} -> Enum.filter(files, &String.starts_with?(&1, "rindle_probe_"))
      _ -> []
    end
  end
end
