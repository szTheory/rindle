defmodule Rindle.Streaming.ProviderTest do
  use ExUnit.Case, async: true

  alias Rindle.Streaming.Provider

  @expected_required_callbacks [
    {:capabilities, 0},
    {:create_asset, 3},
    {:get_asset, 1},
    {:delete_asset, 1},
    {:signed_playback_url, 3},
    {:verify_webhook, 3}
  ]

  @expected_optional_callbacks [{:create_direct_upload, 2}]

  describe "behaviour_info(:callbacks) (D-04 lock)" do
    test "declares the locked 6 required + 1 optional callbacks (7 total)" do
      callbacks = Provider.behaviour_info(:callbacks)

      expected_all =
        Enum.sort(@expected_required_callbacks ++ @expected_optional_callbacks)

      assert Enum.sort(callbacks) == expected_all
    end

    test "declares exactly [{:create_direct_upload, 2}] as optional (D-04)" do
      assert Provider.behaviour_info(:optional_callbacks) == @expected_optional_callbacks
    end

    test "does NOT declare streaming_url/3 as a callback (D-05 — Rindle.Delivery owns dispatch)" do
      refute {:streaming_url, 3} in Provider.behaviour_info(:callbacks)
    end

    test "required-callback count is exactly 6" do
      total = length(Provider.behaviour_info(:callbacks))
      optional = length(Provider.behaviour_info(:optional_callbacks))
      assert total - optional == 6
    end
  end

  describe "module loadability + compile cleanliness" do
    test "module loads (no callback arity drift / compile errors)" do
      assert Code.ensure_loaded?(Provider)
    end

    test "individual required callback signatures are present (no arity drift)" do
      callbacks = Provider.behaviour_info(:callbacks)

      for cb <- @expected_required_callbacks do
        assert cb in callbacks,
               "expected required callback #{inspect(cb)} to be declared, " <>
                 "but behaviour_info(:callbacks) returned #{inspect(callbacks)}"
      end
    end
  end
end
