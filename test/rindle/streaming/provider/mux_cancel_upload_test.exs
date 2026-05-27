defmodule Rindle.Streaming.Provider.MuxCancelUploadTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Rindle.Streaming.Provider.Mux, as: Adapter
  alias Rindle.Streaming.Provider.Mux.ClientMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev = Application.get_env(:rindle, Adapter, [])

    Application.put_env(
      :rindle,
      Adapter,
      Keyword.merge(prev,
        http_client: ClientMock,
        token_id: "test_token_id",
        token_secret: "test_token_secret"
      )
    )

    on_exit(fn -> Application.put_env(:rindle, Adapter, prev) end)
    :ok
  end

  test "cancel_direct_upload/1 returns :ok on happy path" do
    expect(ClientMock, :cancel_upload, fn "up-1" -> :ok end)

    assert :ok = Adapter.cancel_direct_upload("up-1")
  end

  test "cancel_direct_upload/1 treats already-cancelled upload as :ok at client layer" do
    expect(ClientMock, :cancel_upload, fn "up-gone" -> :ok end)

    assert :ok = Adapter.cancel_direct_upload("up-gone")
  end

  test "cancel_direct_upload/1 maps 429 to :provider_quota_exceeded" do
    expect(ClientMock, :cancel_upload, fn "up-quota" ->
      {:error, "rate limited", %{status: 429}}
    end)

    assert {:error, :provider_quota_exceeded} = Adapter.cancel_direct_upload("up-quota")
  end

  test "cancel_direct_upload/1 maps 5xx to :provider_sync_failed" do
    expect(ClientMock, :cancel_upload, fn "up-503" ->
      {:error, "unavailable", %{status: 503}}
    end)

    assert {:error, :provider_sync_failed} = Adapter.cancel_direct_upload("up-503")
  end
end
