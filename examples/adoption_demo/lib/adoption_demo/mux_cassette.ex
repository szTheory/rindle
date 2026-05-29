defmodule AdoptionDemo.MuxCassette do
  @moduledoc false

  @signing_private_key_path Path.expand(
                              "../../../../test/fixtures/mux/test_signing_private_key.pem",
                              __DIR__
                            )

  def configure! do
    if Application.get_env(:adoption_demo, :mux_cassette_configured) do
      :ok
    else
      ensure_mock!()
      configure_mux_env!()
      stub_calls!()
      Application.put_env(:adoption_demo, :mux_cassette_configured, true)
      :ok
    end
  end

  defp ensure_mock! do
    unless Code.ensure_loaded?(Rindle.Streaming.Provider.Mux.ClientMock) do
      Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock,
        for: Rindle.Streaming.Provider.Mux.Client
      )
    end
  end

  defp configure_mux_env! do
    signing_key = File.read!(@signing_private_key_path)

    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
      http_client: Rindle.Streaming.Provider.Mux.ClientMock,
      token_id: "cassette-token-id",
      token_secret: "cassette-token-secret",
      signing_key_id: "test-signing-key-id",
      signing_private_key: signing_key,
      webhook_secrets: []
    )

    Application.put_env(:rindle, :__mux_cassette_mode__, true)
  end

  defp stub_calls! do
    Mox.set_mox_global(Rindle.Streaming.Provider.Mux.ClientMock)

    Mox.stub(Rindle.Streaming.Provider.Mux.ClientMock, :create_asset, fn _params ->
      {:ok,
       %{
         "id" => "cassette-asset-id-aaaa",
         "playback_ids" => [%{"id" => "cassette-playback-id-bbbb", "policy" => "signed"}],
         "status" => "preparing"
       }}
    end)

    Mox.stub(Rindle.Streaming.Provider.Mux.ClientMock, :get_asset, fn _id ->
      {:ok,
       %{
         "id" => "cassette-asset-id-aaaa",
         "playback_ids" => [%{"id" => "cassette-playback-id-bbbb", "policy" => "signed"}],
         "status" => "ready"
       }}
    end)

    Mox.stub(Rindle.Streaming.Provider.Mux.ClientMock, :delete_asset, fn _id -> :ok end)
  end
end
