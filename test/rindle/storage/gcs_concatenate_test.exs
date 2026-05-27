defmodule Rindle.Storage.GCSConcatenateTest do
  use ExUnit.Case, async: false

  alias Rindle.Storage.GCS

  describe "concatenate/3 (Bypass)" do
    setup do
      bypass = Bypass.open()
      finch_name = :"gcs_test_finch_#{System.unique_integer([:positive])}"
      start_supervised!({Finch, name: finch_name})

      original_env = Application.get_env(:rindle, GCS)

      Application.put_env(:rindle, GCS,
        bucket: "test-bucket",
        base_url: "http://localhost:#{bypass.port}",
        finch: finch_name
      )

      on_exit(fn ->
        if original_env do
          Application.put_env(:rindle, GCS, original_env)
        else
          Application.delete_env(:rindle, GCS)
        end
      end)

      %{bypass: bypass, opts: [token: "fake-token"]}
    end

    test "concatenate/3 correctly invokes compose via JSON API", %{bypass: bypass, opts: opts} do
      Bypass.expect(bypass, fn conn ->
        if conn.method == "POST" do
          assert conn.request_path == "/storage/v1/b/test-bucket/o/final_key/compose"

          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          json = Jason.decode!(body)

          assert json["sourceObjects"] == [
                   %{"name" => "part1"},
                   %{"name" => "part2"}
                 ]

          Plug.Conn.resp(conn, 200, Jason.encode!(%{"name" => "final_key"}))
        else
          assert conn.method == "DELETE"
          Plug.Conn.resp(conn, 204, "")
        end
      end)

      assert {:ok, %{key: "final_key", bucket: "test-bucket"}} =
               GCS.concatenate("final_key", ["part1", "part2"], opts)
    end

    test "concatenate/3 correctly batches sources when count > 32 and folds them", %{
      bypass: bypass,
      opts: opts
    } do
      source_keys = Enum.map(1..35, &"part_#{&1}")

      pid = self()

      Bypass.expect(bypass, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)

        if conn.method == "POST" do
          json = Jason.decode!(body)
          sources = Enum.map(json["sourceObjects"], & &1["name"])

          send(pid, {:post, conn.request_path, sources})
          Plug.Conn.resp(conn, 200, Jason.encode!(%{"name" => "composed_tmp"}))
        else
          assert conn.method == "DELETE"
          # Extract key from URL
          # /storage/v1/b/test-bucket/o/key
          key = conn.request_path |> String.split("/") |> List.last() |> URI.decode()
          send(pid, {:delete, key})
          Plug.Conn.resp(conn, 204, "")
        end
      end)

      assert {:ok, %{key: "final_key", bucket: "test-bucket"}} =
               GCS.concatenate("final_key", source_keys, opts)

      # Assert what happened
      assert_receive {:post, "/storage/v1/b/test-bucket/o/" <> first_tmp_path,
                      first_batch_sources}

      first_tmp_url = String.replace_suffix(first_tmp_path, "/compose", "")
      assert length(first_batch_sources) == 32
      first_tmp = URI.decode(first_tmp_url)

      # The next batch should compose [first_tmp | remaining_3_sources]
      assert_receive {:post, "/storage/v1/b/test-bucket/o/final_key/compose",
                      second_batch_sources}

      assert length(second_batch_sources) == 4
      assert hd(second_batch_sources) == first_tmp

      # It should clean up the tmp object
      assert_receive {:delete, ^first_tmp}
    end

    test "concatenate/3 cleans up source keys after successful composition", %{
      bypass: bypass,
      opts: opts
    } do
      pid = self()

      Bypass.expect(bypass, fn conn ->
        if conn.method == "POST" do
          Plug.Conn.resp(conn, 200, Jason.encode!(%{"name" => "final"}))
        else
          assert conn.method == "DELETE"
          key = conn.request_path |> String.split("/") |> List.last() |> URI.decode()
          send(pid, {:delete, key})
          Plug.Conn.resp(conn, 204, "")
        end
      end)

      assert {:ok, _} = GCS.concatenate("final_key", ["p1", "p2", "p3"], opts)

      assert_receive {:delete, "p1"}
      assert_receive {:delete, "p2"}
      assert_receive {:delete, "p3"}
    end
  end
end
