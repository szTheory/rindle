defmodule Rindle.Streaming.Provider.Mux.OptionalDepTest do
  alias Rindle.Streaming.Provider.Mux.Client
  use ExUnit.Case, async: true

  # MUX-01 smoke test (D-31, D-33). The :mux and :jose deps are loaded in the
  # Rindle test environment via `optional: true` in mix.exs; the adapter module
  # `Rindle.Streaming.Provider.Mux` is wrapped in
  # `if Code.ensure_loaded?(Mux.Video.Assets) do ... end` so it is present in
  # tests but absent for adopters who do not opt in.

  test "Rindle.Streaming.Provider.Mux is loaded with all required Phase 33 callbacks (test env)" do
    assert Code.ensure_loaded?(Rindle.Streaming.Provider.Mux),
           "Rindle.Streaming.Provider.Mux module must compile when :mux is loaded"

    for {fun, arity} <- [
          {:capabilities, 0},
          {:create_asset, 3},
          {:get_asset, 1},
          {:delete_asset, 1},
          {:signed_playback_url, 3},
          {:verify_webhook, 3}
        ] do
      assert function_exported?(Rindle.Streaming.Provider.Mux, fun, arity),
             "Rindle.Streaming.Provider.Mux must export #{fun}/#{arity}"
    end
  end

  test "Mux + JOSE deps are loaded in test env" do
    assert Code.ensure_loaded?(Mux.Video.Assets)
    assert Code.ensure_loaded?(Mux.Token)
    assert Code.ensure_loaded?(Mux.Webhooks)
    assert Code.ensure_loaded?(JOSE.JWK)
  end

  test "Client behaviour declares the three SDK-shape callbacks" do
    assert Code.ensure_loaded?(Client)
    callbacks = Client.behaviour_info(:callbacks)
    assert {:create_asset, 1} in callbacks
    assert {:get_asset, 1} in callbacks
    assert {:delete_asset, 1} in callbacks
  end

  test "Rindle.Streaming.Provider.Mux.ClientMock is registered for downstream worker tests" do
    assert Code.ensure_loaded?(Rindle.Streaming.Provider.Mux.ClientMock)
  end
end
