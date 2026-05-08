defmodule Rindle.Storage.GCS.ClientTest do
  use ExUnit.Case, async: true

  alias Rindle.Storage.GCS.Client

  @bucket "my-bucket"

  setup do
    # Bypass 2.1 auto-cleans the cowboy listener when the test process exits;
    # there is no public `Bypass.shutdown/1`. Linking via Bypass.open() is
    # sufficient.
    bypass = Bypass.open()

    # Each test gets a fresh Finch supervisor name via System.unique_integer/1 to
    # avoid name collisions across async tests. start_supervised!/1 ensures the
    # Finch supervisor is torn down when the test process exits.
    finch_name = Module.concat(__MODULE__, :"Finch_#{System.unique_integer([:positive])}")
    {:ok, _pid} = Finch.start_link(name: finch_name)

    {:ok, bypass: bypass, base_url: "http://localhost:#{bypass.port}", finch: finch_name}
  end

  describe "head/3" do
    test "returns size + content_type on 200 OK", %{
      bypass: bypass,
      base_url: base_url,
      finch: finch
    } do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/assets%2Ffoo.jpg", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "size" => "1024000",
            "contentType" => "image/jpeg"
          })
        )
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:ok, %{size: 1_024_000, content_type: "image/jpeg"}} =
               Client.head(@bucket, "assets/foo.jpg", opts)
    end

    test "returns :not_found on 404", %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/missing.jpg", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]
      assert {:error, :not_found} = Client.head(@bucket, "missing.jpg", opts)
    end

    test "returns {:gcs_http_error, ...} on 403", %{
      bypass: bypass,
      base_url: base_url,
      finch: finch
    } do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/forbidden.jpg", fn conn ->
        Plug.Conn.resp(conn, 403, ~s({"error":{"code":403,"message":"Forbidden"}}))
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:error, {:gcs_http_error, %{status: 403, body: _body}}} =
               Client.head(@bucket, "forbidden.jpg", opts)
    end

    test "returns {:gcs_http_error, ...} on 500", %{
      bypass: bypass,
      base_url: base_url,
      finch: finch
    } do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/boom.jpg", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error":{"code":500,"message":"Internal"}}))
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:error, {:gcs_http_error, %{status: 500, body: _body}}} =
               Client.head(@bucket, "boom.jpg", opts)
    end

    test "honors :base_url opt threading (RESEARCH Section 2 / Q4 — Bypass discovery seam)",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      # Q4 — the :base_url opt is the test-only seam that lets Bypass intercept
      # requests at http://localhost:#{port} instead of the default
      # https://storage.googleapis.com. This explicit test asserts the request
      # actually hit the Bypass server (Bypass.expect_once raises if not).
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/seam.jpg", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"size" => "1", "contentType" => "image/jpeg"}))
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:ok, %{size: 1, content_type: "image/jpeg"}} =
               Client.head(@bucket, "seam.jpg", opts)
    end

    test "URL-encodes `/` as `%2F` in object name path segment (RESEARCH Pitfall 1)",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      # Pitfall 1 — Elixir's URI.encode/1 leaves `/` unencoded, which would make
      # GCS interpret a slash-bearing object key as a multi-segment path and
      # 404. The Client uses `URI.encode/2` with `&URI.char_unreserved?/1`,
      # which encodes `/` as `%2F`. This test verifies the on-the-wire URL by
      # specifying the encoded path in `Bypass.expect_once/4`.
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/a%2Fb%2Fc.jpg", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"size" => "10", "contentType" => "image/jpeg"}))
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:ok, %{size: 10, content_type: "image/jpeg"}} =
               Client.head(@bucket, "a/b/c.jpg", opts)
    end
  end

  describe "store/4 (multipart)" do
    test "POSTs to uploadType=multipart and writes contentType + contentDisposition atomically",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      tmp =
        Path.join(System.tmp_dir!(), "rindle-gcs-store-#{System.unique_integer([:positive])}.bin")

      File.write!(tmp, "abc123")

      Bypass.expect_once(bypass, "POST", "/upload/storage/v1/b/#{@bucket}/o", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["uploadType"] == "multipart"
        {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)
        assert body =~ "\"contentType\":\"image/jpeg\""
        assert body =~ "\"contentDisposition\":\"inline; filename=\\\"foo.jpg\\\"\""
        assert body =~ "abc123"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"name" => "assets/foo.jpg", "bucket" => @bucket})
        )
      end)

      opts = [
        base_url: base_url,
        token: "fake-token",
        finch: finch,
        content_type: "image/jpeg",
        content_disposition: "inline; filename=\"foo.jpg\""
      ]

      assert {:ok, %{key: "assets/foo.jpg"}} =
               Client.store(@bucket, "assets/foo.jpg", tmp, opts)
    after
      _ = File.rm(Path.join(System.tmp_dir!(), "rindle-gcs-store-fake"))
    end

    test "returns {:gcs_http_error, ...} on 400", %{
      bypass: bypass,
      base_url: base_url,
      finch: finch
    } do
      tmp =
        Path.join(
          System.tmp_dir!(),
          "rindle-gcs-store-bad-#{System.unique_integer([:positive])}.bin"
        )

      File.write!(tmp, "x")

      Bypass.expect_once(bypass, "POST", "/upload/storage/v1/b/#{@bucket}/o", fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"error":{"code":400,"message":"Bad Request"}}))
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch, content_type: "image/jpeg"]

      assert {:error, {:gcs_http_error, %{status: 400, body: _}}} =
               Client.store(@bucket, "k.jpg", tmp, opts)
    end
  end

  describe "download/4" do
    test "streams body to destination on 200 OK", %{
      bypass: bypass,
      base_url: base_url,
      finch: finch
    } do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/dl.bin", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["alt"] == "media"
        Plug.Conn.resp(conn, 200, "STREAMED-BYTES")
      end)

      dest =
        Path.join(System.tmp_dir!(), "rindle-gcs-dl-#{System.unique_integer([:positive])}.bin")

      opts = [base_url: base_url, token: "fake-token", finch: finch]
      assert {:ok, ^dest} = Client.download(@bucket, "dl.bin", dest, opts)
      assert File.read!(dest) == "STREAMED-BYTES"
    end

    test "returns :not_found on 404", %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/gone.bin", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
      end)

      dest =
        Path.join(
          System.tmp_dir!(),
          "rindle-gcs-dl-404-#{System.unique_integer([:positive])}.bin"
        )

      opts = [base_url: base_url, token: "fake-token", finch: finch]
      assert {:error, :not_found} = Client.download(@bucket, "gone.bin", dest, opts)
    end
  end

  describe "resumable_upload lifecycle" do
    test "initiates via uploadType=resumable and returns broker-safe metadata",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "POST", "/upload/storage/v1/b/#{@bucket}/o", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["uploadType"] == "resumable"
        assert Plug.Conn.get_req_header(conn, "x-goog-resumable") == ["start"]
        assert Plug.Conn.get_req_header(conn, "x-upload-content-length") == ["1024"]
        {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)
        assert body =~ "\"name\":\"assets/resumable.bin\""

        conn
        |> Plug.Conn.put_resp_header("location", "#{base_url}/session/upload-123")
        |> Plug.Conn.put_resp_header("x-guploader-uploadid", "upload-123")
        |> Plug.Conn.put_resp_header("x-goog-upload-region", "us-east1")
        |> Plug.Conn.resp(201, "")
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:ok,
              %{
                session_uri: session_uri,
                upload_id: "upload-123",
                expires_at: %DateTime{},
                region_hint: "us-east1"
              }} = Client.initiate_resumable_upload(@bucket, "assets/resumable.bin", 1024, opts)

      assert session_uri == "#{base_url}/session/upload-123"
    end

    test "maps 308 Range to in-progress committed bytes",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "PUT", "/session/upload-123", fn conn ->
        assert Plug.Conn.get_req_header(conn, "content-range") == ["bytes */*"]

        conn
        |> Plug.Conn.put_resp_header("range", "bytes=0-511")
        |> Plug.Conn.resp(308, "")
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:ok, %{committed_bytes: 512, state: :in_progress}} =
               Client.resumable_upload_status(
                 @bucket,
                 "assets/resumable.bin",
                 "#{base_url}/session/upload-123",
                 opts
               )
    end

    test "maps status polling offset disagreements to {:offset_mismatch, ...}",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "PUT", "/session/upload-offset", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("range", "bytes=0-255")
        |> Plug.Conn.resp(308, "")
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch, client_offset: 128]

      assert {:error, {:offset_mismatch, %{server: 256, client: 128}}} =
               Client.resumable_upload_status(
                 @bucket,
                 "assets/resumable.bin",
                 "#{base_url}/session/upload-offset",
                 opts
               )
    end

    test "maps 404 and 410 to locked session-uri errors",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "PUT", "/session/upload-missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      Bypass.expect_once(bypass, "PUT", "/session/upload-expired", fn conn ->
        Plug.Conn.resp(conn, 410, "")
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:error, :session_uri_unknown} =
               Client.resumable_upload_status(
                 @bucket,
                 "assets/resumable.bin",
                 "#{base_url}/session/upload-missing",
                 opts
               )

      assert {:error, :session_uri_expired} =
               Client.resumable_upload_status(
                 @bucket,
                 "assets/resumable.bin",
                 "#{base_url}/session/upload-expired",
                 opts
               )
    end

    test "returns :complete with stored content length when the upload is finalized",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "PUT", "/session/upload-complete", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-goog-stored-content-length", "1024")
        |> Plug.Conn.resp(200, "")
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch, client_offset: 1024]

      assert {:ok, %{committed_bytes: 1024, state: :complete}} =
               Client.resumable_upload_status(
                 @bucket,
                 "assets/resumable.bin",
                 "#{base_url}/session/upload-complete",
                 opts
               )
    end

    test "cancel returns success and preserves 404/410 mappings",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "DELETE", "/session/upload-cancelled", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      Bypass.expect_once(bypass, "DELETE", "/session/upload-gone", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      Bypass.expect_once(bypass, "DELETE", "/session/upload-expired", fn conn ->
        Plug.Conn.resp(conn, 410, "")
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]

      assert {:ok, %{cancelled: true}} =
               Client.cancel_resumable_upload(
                 @bucket,
                 "assets/resumable.bin",
                 "#{base_url}/session/upload-cancelled",
                 opts
               )

      assert {:error, :session_uri_unknown} =
               Client.cancel_resumable_upload(
                 @bucket,
                 "assets/resumable.bin",
                 "#{base_url}/session/upload-gone",
                 opts
               )

      assert {:error, :session_uri_expired} =
               Client.cancel_resumable_upload(
                 @bucket,
                 "assets/resumable.bin",
                 "#{base_url}/session/upload-expired",
                 opts
               )
    end
  end

  describe "delete/3" do
    test "returns {:ok, %{key: key}} on 204 No Content",
         %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "DELETE", "/storage/v1/b/#{@bucket}/o/d.bin", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]
      assert {:ok, %{key: "d.bin"}} = Client.delete(@bucket, "d.bin", opts)
    end

    test "returns :not_found on 404", %{bypass: bypass, base_url: base_url, finch: finch} do
      Bypass.expect_once(bypass, "DELETE", "/storage/v1/b/#{@bucket}/o/gone.bin", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
      end)

      opts = [base_url: base_url, token: "fake-token", finch: finch]
      assert {:error, :not_found} = Client.delete(@bucket, "gone.bin", opts)
    end
  end

  describe "Goth integration" do
    test "fetch_token/1 ArgumentError on unstarted instance is mapped to {:error, :goth_unconfigured}",
         %{base_url: base_url, finch: finch} do
      # RESEARCH Pitfall 6 — Goth.fetch/1 against a name with no registered
      # process raises ArgumentError (NOT :exit, :noproc). The Client MUST
      # `rescue ArgumentError -> {:error, :goth_unconfigured}` so adopters get
      # a clean error tuple instead of a crash dump. Defense-in-depth catching
      # `:exit, _reason` as well is acceptable but not required — `rescue
      # ArgumentError` is the load-bearing branch.
      opts = [base_url: base_url, finch: finch, goth: :rindle_test_unstarted_goth_instance]
      assert {:error, :goth_unconfigured} = Client.head(@bucket, "any.bin", opts)
    end
  end
end
