defmodule Rindle.Delivery.LocalPlugTest do
  use Rindle.DataCase, async: true

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

    {:ok,
     root: root,
     key: "assets/asset-1/video.mp4",
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
end
