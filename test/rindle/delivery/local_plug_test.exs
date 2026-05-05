defmodule Rindle.Delivery.LocalPlugTest do
  use Rindle.DataCase, async: true

  alias Plug.Conn
  alias Plug.Test
  alias Rindle.Delivery.LocalPlug
  alias Rindle.Storage.Local

  defmodule LocalProfile do
    use Rindle.Profile,
      storage: Local,
      variants: [web: [kind: :video, preset: :web_720p]]
  end

  setup do
    root =
      Path.join(System.tmp_dir!(), "rindle-local-plug-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf(root) end)

    key = "assets/asset-1/video.mp4"
    body = "0123456789abcdef"
    path = Local.path_for(key, root: root)

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, body)

    {:ok,
     root: root,
     body: body,
     key: key,
     path: path,
     route: [
       base_url: "http://example.test/rindle/local",
       secret_key_base: String.duplicate("local-secret-", 4)
     ]}
  end

  describe "task 1 local delivery seam" do
    test "publishes the local root/path resolver as the canonical filesystem seam", %{
      root: root,
      key: key
    } do
      assert Local.root(root: root) == Path.expand(root)
      assert Local.path_for(key, root: root) == Path.expand(key, root)
    end

    test "streaming_url/3 mints a local playback URL when route context is provided", %{
      root: root,
      key: key,
      route: route
    } do
      assert {:ok, %{url: url, kind: :progressive, mime: "video/mp4"}} =
               Rindle.Delivery.streaming_url(
                 LocalProfile,
                 key,
                 root: root,
                 local_route: route,
                 actor: %{id: "viewer-1"}
               )

      parsed = URI.parse(url)

      assert parsed.scheme == "http"
      assert parsed.host == "example.test"
      assert parsed.path == "/rindle/local"
      assert parsed.query =~ "token="
    end

    test "streaming_url/3 keeps local playback token actor-bound", %{
      root: root,
      key: key,
      route: route
    } do
      assert {:ok, %{url: first_url}} =
               Rindle.Delivery.streaming_url(
                 LocalProfile,
                 key,
                 root: root,
                 local_route: route,
                 actor: %{id: "viewer-1"}
               )

      assert {:ok, %{url: second_url}} =
               Rindle.Delivery.streaming_url(
                 LocalProfile,
                 key,
                 root: root,
                 local_route: route,
                 actor: %{id: "viewer-2"}
               )

      refute first_url == second_url
    end

    test "streaming_url/3 preserves the existing delivery error when no local route context is provided",
         %{
           root: root,
           key: key
         } do
      assert {:error, {:delivery_unsupported, :signed_url}} =
               Rindle.Delivery.streaming_url(LocalProfile, key, root: root)
    end
  end

  describe "task 2 local plug" do
    defmodule RemoteProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.S3,
        variants: [web: [kind: :video, preset: :web_720p]]
    end

    test "init/1 refuses non-local storage adapters" do
      assert_raise ArgumentError, ~r/Rindle\.Storage\.Local/, fn ->
        LocalPlug.init(profile: RemoteProfile, secret_key_base: String.duplicate("secret-", 4))
      end
    end

    test "serves a signed local playback URL with shared content disposition headers", %{
      root: root,
      key: key,
      route: route
    } do
      conn =
        playback_conn(
          root,
          route,
          key,
          actor: %{id: "viewer-1"},
          disposition: :attachment,
          filename: "../my clip?.mp4"
        )

      assert conn.status == 200
      assert conn.resp_body == "0123456789abcdef"
      assert Conn.get_resp_header(conn, "accept-ranges") == ["bytes"]

      assert Conn.get_resp_header(conn, "content-disposition") == [
               "attachment; filename=\"my_clip_.mp4\"; filename*=UTF-8''my_clip_.mp4"
             ]
    end

    test "returns 206 for a single explicit byte range and emits local range telemetry", %{
      root: root,
      key: key,
      route: route
    } do
      ref = :telemetry_test.attach_event_handlers(self(), [[:rindle, :delivery, :range_request]])
      on_exit(fn -> :telemetry.detach(ref) end)

      conn =
        playback_conn(root, route, key,
          actor: %{id: "viewer-1"},
          req_headers: [{"range", "bytes=4-7"}]
        )

      assert conn.status == 206
      assert conn.resp_body == "4567"
      assert Conn.get_resp_header(conn, "content-range") == ["bytes 4-7/16"]
      assert Conn.get_resp_header(conn, "content-length") == ["4"]

      assert_received {[:rindle, :delivery, :range_request], ^ref, measurements, metadata}
      assert measurements.offset == 4
      assert measurements.length == 4
      assert measurements.file_size == 16
      assert is_integer(measurements.system_time)
      assert metadata.profile == LocalProfile
      assert metadata.adapter == Local
      assert metadata.key == key
      assert metadata.actor_subject == "viewer-1"
    end

    test "supports suffix and open-ended single-byte ranges", %{root: root, key: key, route: route} do
      suffix_conn =
        playback_conn(root, route, key,
          req_headers: [{"range", "bytes=-4"}]
        )

      assert suffix_conn.status == 206
      assert suffix_conn.resp_body == "cdef"
      assert Conn.get_resp_header(suffix_conn, "content-range") == ["bytes 12-15/16"]

      open_ended_conn =
        playback_conn(root, route, key,
          req_headers: [{"range", "bytes=10-"}]
        )

      assert open_ended_conn.status == 206
      assert open_ended_conn.resp_body == "abcdef"
      assert Conn.get_resp_header(open_ended_conn, "content-range") == ["bytes 10-15/16"]
    end

    test "falls back to 200 full body for multi-range and malformed range headers", %{
      root: root,
      key: key,
      route: route
    } do
      multi_range_conn =
        playback_conn(root, route, key,
          req_headers: [{"range", "bytes=0-1,4-5"}]
        )

      assert multi_range_conn.status == 200
      assert multi_range_conn.resp_body == "0123456789abcdef"
      assert Conn.get_resp_header(multi_range_conn, "content-range") == []

      malformed_conn =
        playback_conn(root, route, key,
          req_headers: [{"range", "not-a-range"}]
        )

      assert malformed_conn.status == 200
      assert malformed_conn.resp_body == "0123456789abcdef"
    end

    test "rejects invalid tokens and missing files", %{root: root, key: key, route: route} do
      valid_url = signed_local_url(root, route, key)
      invalid_token_url = String.replace(valid_url, "token=", "token=broken")

      invalid_conn = request(invalid_token_url, root, route)
      assert invalid_conn.status == 403

      missing_conn = request(signed_local_url(root, route, "assets/asset-1/missing.mp4"), root, route)
      assert missing_conn.status == 404
    end

    test "rejects signed keys that resolve outside the configured local root", %{
      root: root,
      route: route
    } do
      escaped_key = "../escaped/video.mp4"
      escaped_path = Path.expand(escaped_key, root)
      File.mkdir_p!(Path.dirname(escaped_path))
      File.write!(escaped_path, "escaped")

      conn = request(signed_local_url(root, route, escaped_key), root, route)
      assert conn.status == 403
    end
  end

  defp playback_conn(root, route, key, opts \\ []) do
    request(signed_local_url(root, route, key, opts), root, route, Keyword.get(opts, :req_headers, []))
  end

  defp request(url, root, route, req_headers \\ []) do
    conn =
      Test.conn("GET", request_path(url))
      |> Map.put(:secret_key_base, Keyword.fetch!(route, :secret_key_base))
      |> put_req_headers(req_headers)

    opts = LocalPlug.init(profile: LocalProfile, root: root, secret_key_base: route[:secret_key_base])
    LocalPlug.call(conn, opts)
  end

  defp signed_local_url(root, route, key, opts \\ []) do
    {:ok, %{url: url}} =
      Rindle.Delivery.streaming_url(
        LocalProfile,
        key,
        Keyword.merge([root: root, local_route: route], opts)
      )

    url
  end

  defp request_path(url) do
    uri = URI.parse(url)
    uri.path <> if(uri.query, do: "?" <> uri.query, else: "")
  end

  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc -> Conn.put_req_header(acc, key, value) end)
  end
end
