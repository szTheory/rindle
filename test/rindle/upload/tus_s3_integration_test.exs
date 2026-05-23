defmodule Rindle.Upload.TusS3IntegrationTest do
  @moduledoc """
  TUS-09 headline proof scaffold: a >= 1 GiB tus upload over S3-multipart backing
  survives a mid-stream drop + resume, converges into the unchanged
  `verify_completion/2` lane, and leaves ZERO orphaned multipart uploads after a
  separate abandoned session is reaped (`list_multipart_uploads` returns no entry
  for the abandoned key).

  `@moduletag :minio` — EXCLUDED from the default `mix test` run (the harness only
  runs it when MinIO is configured + the `:minio` tag is included). It MUST
  compile cleanly today. Plan 05 fills in the live S3 dispatch body against the
  running MinIO service; the steps below are the executable contract it satisfies.

  Why >= 1 GiB: the proof is that bytes never accumulate in BEAM memory and that
  the S3 tail-buffer slices real multipart parts across a drop. Size, not
  content, is the point (RESEARCH A5) — a synthetic byte stream satisfies the
  floor without a fixture file.
  """
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  import Plug.Test
  import Plug.Conn

  alias Rindle.Domain.{MediaAsset, MediaUploadSession}
  alias Rindle.Ops.UploadMaintenance
  alias Rindle.Upload.TusPlug

  @moduletag :minio
  # >= 1 GiB drop+resume + a live multipart complete is a long round-trip.
  @moduletag timeout: 600_000

  @secret_key_base "tus-s3-integration-secret-key-base-0123456789abcdef"
  @tus_url_salt "rindle:tus:url"

  # 1 GiB floor for the headline proof; PATCH in ~600 MiB then resume the rest.
  @one_gib 1 * 1024 * 1024 * 1024
  @first_patch_bytes 600 * 1024 * 1024
  # 2 GiB ceiling. Literal: the Profile DSL validates :max_bytes at compile time
  # and rejects arithmetic expressions (must be a positive integer).
  @two_gib 2_147_483_648

  defmodule MinioTusProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.S3,
      variants: [thumb: [mode: :fit, width: 8, height: 8]],
      allow_mime: ["application/octet-stream"],
      max_bytes: 2_147_483_648
  end

  setup do
    case :inets.start() do
      :ok -> :ok
      {:error, {:already_started, :inets}} -> :ok
    end

    previous_s3 = Application.get_env(:rindle, Rindle.Storage.S3)
    previous_ex_aws = Application.get_env(:ex_aws, :s3)

    minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
    bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")
    access_key = System.get_env("RINDLE_MINIO_ACCESS_KEY", "minioadmin")
    secret_key = System.get_env("RINDLE_MINIO_SECRET_KEY", "minioadmin")
    region = System.get_env("RINDLE_MINIO_REGION", "us-east-1")
    %URI{host: host, port: port, scheme: scheme} = URI.parse(minio_url)

    Application.put_env(:rindle, Rindle.Storage.S3, bucket: bucket)

    Application.put_env(:ex_aws, :s3,
      scheme: "#{scheme}://",
      host: host,
      port: port,
      region: region,
      access_key_id: access_key,
      secret_access_key: secret_key
    )

    on_exit(fn ->
      case previous_s3 do
        nil -> Application.delete_env(:rindle, Rindle.Storage.S3)
        value -> Application.put_env(:rindle, Rindle.Storage.S3, value)
      end

      case previous_ex_aws do
        nil -> Application.delete_env(:ex_aws, :s3)
        value -> Application.put_env(:ex_aws, :s3, value)
      end
    end)

    {:ok, bucket: bucket}
  end

  # The S3 ex_aws config used for direct list_multipart_uploads assertions.
  defp aws_config do
    Application.get_env(:ex_aws, :s3, [])
  end

  defp opts_for do
    TusPlug.init(
      profile: MinioTusProfile,
      secret_key_base: @secret_key_base,
      max_size: @two_gib
    )
  end

  defp create(opts, length) do
    conn =
      conn(:post, "/uploads/tus")
      |> put_req_header("upload-length", Integer.to_string(length))
      |> put_req_header("upload-metadata", "filename YmlnLmJpbg==")
      |> TusPlug.call(opts)

    [location] = get_resp_header(conn, "location")
    token = location |> String.split("/") |> List.last()
    {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
    {token, payload["session_id"]}
  end

  defp patch(opts, token, offset, body) do
    conn(:patch, "/uploads/tus/" <> token, body)
    |> put_req_header("content-type", "application/offset+octet-stream")
    |> put_req_header("upload-offset", Integer.to_string(offset))
    |> TusPlug.call(opts)
  end

  defp head(opts, token), do: conn(:head, "/uploads/tus/" <> token) |> TusPlug.call(opts)

  # A synthetic byte stream of the requested size, materialized lazily so the
  # >= 1 GiB body never sits in one binary in the test process.
  defp synthetic_bytes(size) do
    chunk = String.duplicate("x", 1024 * 1024)
    full = div(size, byte_size(chunk))
    remainder = rem(size, byte_size(chunk))

    stream = Stream.cycle([chunk]) |> Stream.take(full)
    if remainder > 0, do: Stream.concat(stream, [String.duplicate("x", remainder)]), else: stream
  end

  test "a >= 1 GiB tus upload over S3 backing survives drop+resume and leaves zero multipart leak",
       %{bucket: bucket} do
    opts = opts_for()

    # 1. POST -> signed tus URL + tus-stamped session.
    {token, sid} = create(opts, @one_gib)
    assert get_resp_header(head(opts, token), "upload-offset") == ["0"]

    # 2. PATCH ~600 MiB -> 204, Upload-Offset advances, multipart_upload_id
    #    persisted on the session row.
    first = synthetic_bytes(@first_patch_bytes) |> Enum.to_list() |> IO.iodata_to_binary()
    p1 = patch(opts, token, 0, first)
    assert p1.status == 204
    assert get_resp_header(p1, "upload-offset") == [Integer.to_string(@first_patch_bytes)]

    persisted = repo().get!(MediaUploadSession, sid)
    assert is_binary(persisted.multipart_upload_id)

    # The S3 tail-buffer sliced >= 1 multipart part out of the ~600 MiB PATCH and
    # persisted them under the `"parts"` key (tus_plug encode_parts convention) —
    # proving real UploadParts crossed the wire before the drop.
    assert %{"parts" => persisted_parts} = persisted.multipart_parts
    assert is_list(persisted_parts)
    assert length(persisted_parts) >= 1

    # 3. Simulate drop: client re-HEADs for the authoritative offset.
    assert get_resp_header(head(opts, token), "upload-offset") == [
             Integer.to_string(@first_patch_bytes)
           ]

    # 4. Resume PATCH from the offset through the final PATCH (offset == length).
    rest = synthetic_bytes(@one_gib - @first_patch_bytes) |> Enum.to_list() |> IO.iodata_to_binary()
    p2 = patch(opts, token, @first_patch_bytes, rest)
    assert p2.status == 204
    assert get_resp_header(p2, "upload-offset") == [Integer.to_string(@one_gib)]

    # 5. Convergence into the UNCHANGED verify_completion/2 lane.
    session = repo().get!(MediaUploadSession, sid)
    assert session.state == "completed"

    asset = repo().get!(MediaAsset, session.asset_id)
    assert asset.state in ["validating", "ready"]
    assert asset.byte_size == @one_gib

    # The convergence proof: the final PATCH drove the adapter's tus sink into the
    # UNCHANGED Broker.verify_completion/2 lane (D-08), which enqueues PromoteAsset
    # for the freshly-validated asset. `testing: :inline` runs the job; assert it
    # was enqueued for THIS asset (not merely that some job exists).
    assert_enqueued(worker: Rindle.Workers.PromoteAsset, args: %{asset_id: asset.id})

    # 6. A SECOND session, abandoned after one PATCH, then expired + reaped.
    {token2, sid2} = create(opts, @one_gib)
    abandoned = synthetic_bytes(@first_patch_bytes) |> Enum.to_list() |> IO.iodata_to_binary()
    assert patch(opts, token2, 0, abandoned).status == 204

    abandoned_session = repo().get!(MediaUploadSession, sid2)
    abandoned_key = abandoned_session.upload_key

    # Force the session past its TTL and run the reaper.
    abandoned_session
    |> MediaUploadSession.changeset(%{expires_at: DateTime.add(DateTime.utc_now(), -60, :second)})
    |> repo().update!()

    {:ok, _report} = UploadMaintenance.abort_incomplete_uploads([])

    # 7. ZERO LEAK: list_multipart_uploads returns NO entry for the abandoned key.
    {:ok, %{body: %{uploads: uploads}}} =
      ExAws.S3.list_multipart_uploads(bucket) |> ExAws.request(aws_config())

    refute Enum.any?(uploads, fn upload -> upload.key == abandoned_key end)
  end

  # The integration test persists through the adopter Repo configured at runtime;
  # resolve it via Rindle.Config so the assertion reads the same row the plug
  # wrote (mirrors lifecycle_integration_test's repo handling).
  defp repo, do: Rindle.Config.repo()
end
