defmodule Rindle.Streaming.Provider.Mux.HttpCancelUploadTest do
  use ExUnit.Case, async: true

  alias Rindle.Streaming.Provider.Mux.HTTP

  setup do
    bypass = Bypass.open()
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
      token_id: "test_token_id",
      token_secret: "test_token_secret",
      base_url: "http://localhost:#{bypass.port}"
    )

    on_exit(fn ->
      if prev == [] do
        Application.delete_env(:rindle, Rindle.Streaming.Provider.Mux)
      else
        Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, prev)
      end
    end)

    %{bypass: bypass}
  end

  test "cancel_upload/1 returns :ok on 403 (already terminal upload)", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/video/v1/uploads/up-forbidden/cancel"

      Plug.Conn.resp(conn, 403, "{}")
    end)

    assert :ok = HTTP.cancel_upload("up-forbidden")
  end

  test "cancel_upload/1 returns :ok on 404 (upload not found)", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/video/v1/uploads/up-missing/cancel"

      Plug.Conn.resp(conn, 404, "{}")
    end)

    assert :ok = HTTP.cancel_upload("up-missing")
  end

  test "cancel_upload/1 returns :ok on 200", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/video/v1/uploads/up-ok/cancel"

      Plug.Conn.resp(conn, 200, ~s({"data":{"id":"up-ok"}}))
    end)

    assert :ok = HTTP.cancel_upload("up-ok")
  end
end
