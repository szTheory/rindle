defmodule AdoptionDemo.SeedSupport do
  @moduledoc false

  alias AdoptionDemo.{Media, RindleProfile, VideoProfile}
  alias Rindle.Upload.Broker

  @multipart_min_part_size 5 * 1024 * 1024

  def ensure_inets do
    case :inets.start() do
      :ok -> :ok
      {:error, {:already_started, :inets}} -> :ok
    end
  end

  def fixture_path(name) do
    Path.join([:code.priv_dir(:adoption_demo), "fixtures", name])
  end

  def upload_image!(filename, body) do
    with {:ok, session} <- Broker.initiate_session(RindleProfile, filename: filename),
         {:ok, %{presigned: _presigned}} <- Broker.sign_url(session.id),
         :ok <- store_bytes!(RindleProfile, session.upload_key, body, "image/png"),
         {:ok, %{asset: asset}} <- Broker.verify_completion(session.id) do
      drain_asset_jobs!(asset.id, RindleProfile)
      asset
    else
      {:error, reason} -> raise "image upload failed: #{inspect(reason)}"
    end
  end

  def upload_mux!(filename, body) do
    alias AdoptionDemo.MuxProfile

    with {:ok, session} <- Rindle.initiate_upload(MuxProfile, filename: filename),
         {:ok, %{presigned: _presigned}} <- Broker.sign_url(session.id),
         :ok <- store_bytes!(MuxProfile, session.upload_key, body, "video/webm"),
         {:ok, %{asset: asset}} <- Broker.verify_completion(session.id) do
      drain_asset_jobs!(asset.id, MuxProfile)
      asset
    else
      {:error, reason} -> raise "mux upload failed: #{inspect(reason)}"
    end
  end

  def upload_video!(filename, body) do
    with {:ok, session} <- Rindle.initiate_upload(VideoProfile, filename: filename),
         {:ok, %{presigned: _presigned}} <- Broker.sign_url(session.id),
         :ok <- store_bytes!(VideoProfile, session.upload_key, body, "video/webm"),
         {:ok, %{asset: asset}} <- Broker.verify_completion(session.id) do
      drain_asset_jobs!(asset.id, VideoProfile)
      asset
    else
      {:error, reason} -> raise "video upload failed: #{inspect(reason)}"
    end
  end

  def multipart_png_fixture_parts do
    part1 = String.duplicate("a", @multipart_min_part_size)
    part2 = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
    {part1, part2}
  end

  def upload_multipart_image!(filename) do
    {part1, part2} = multipart_png_fixture_parts()

    with {:ok, %{session: session, multipart: _multipart}} <-
           Rindle.initiate_multipart_upload(RindleProfile, filename: filename),
         {:ok, %{presigned: presigned_part1}} <- Rindle.sign_multipart_part(session.id, 1),
         {:ok, %{presigned: presigned_part2}} <- Rindle.sign_multipart_part(session.id, 2),
         etag1 when is_binary(etag1) <- put_part(presigned_part1.url, part1),
         etag2 when is_binary(etag2) <- put_part(presigned_part2.url, part2),
         {:ok, %{asset: asset}} <-
           Rindle.complete_multipart_upload(session.id, [
             %{part_number: 1, etag: etag1},
             %{part_number: 2, etag: etag2}
           ]) do
      drain_asset_jobs!(asset.id, RindleProfile)
      asset
    else
      {:error, reason} -> raise "multipart upload failed: #{inspect(reason)}"
      other -> raise "multipart upload failed: #{inspect(other)}"
    end
  end

  def drain_asset_jobs!(asset_id, profile) do
    drain_oban_queues!()
    wait_for_asset_ready!(asset_id, profile)
  end

  defp drain_oban_queues! do
    for queue <- [:rindle_promote, :rindle_process, :rindle_media] do
      _ = Oban.drain_queue(queue: queue, with_safety: false)
    end
  end

  defp wait_for_asset_ready!(asset_id, profile, attempts \\ 60) do
    asset = Media.get_asset!(asset_id)
    variants = Media.variants_for(asset_id)

    cond do
      asset.state == "ready" and Enum.all?(variants, &(&1.state == "ready")) ->
        :ok

      attempts <= 0 ->
        :ok

      true ->
        Process.sleep(500)
        drain_oban_queues!()
        wait_for_asset_ready!(asset_id, profile, attempts - 1)
    end
  end

  # Seeding runs SERVER-SIDE (inside the app container). It must NOT upload via the browser-facing
  # presigned PUT URL: with the split-horizon S3 endpoint, that URL is signed for the public host
  # (e.g. localhost:<published-port>) which the container cannot reach. Instead we write the bytes
  # straight to the session's upload_key through the profile's storage adapter, which uses the
  # server-side endpoint (e.g. minio:9000). `Broker.verify_completion/1` then HEADs the same key
  # server-side and promotes the asset exactly as a real browser upload would.
  defp store_bytes!(profile, upload_key, body, content_type) do
    tmp = Path.join(System.tmp_dir!(), "seed-upload-#{System.unique_integer([:positive])}")
    File.write!(tmp, body)

    try do
      case profile.storage_adapter().store(upload_key, tmp, content_type: content_type) do
        {:ok, _meta} -> :ok
        {:error, reason} -> {:error, reason}
      end
    after
      File.rm(tmp)
    end
  end

  defp put_part(url, body) do
    request = {String.to_charlist(url), [], ~c"application/octet-stream", body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_version, status, _reason}, headers, _body}} when status in 200..299 ->
        etag =
          headers
          |> Enum.find(fn {k, _} -> String.downcase(to_string(k)) == "etag" end)
          |> case do
            {_, value} -> List.to_string(value) |> String.trim("\"")
            _ -> nil
          end

        etag || {:error, :missing_etag}

      other ->
        {:error, other}
    end
  end
end
