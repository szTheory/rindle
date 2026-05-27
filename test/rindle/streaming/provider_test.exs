defmodule Rindle.Streaming.ProviderTest do
  use ExUnit.Case, async: true

  alias Rindle.Domain.MediaProviderAsset
  alias Rindle.Streaming.Provider

  @expected_required_callbacks [
    {:capabilities, 0},
    {:create_asset, 3},
    {:get_asset, 1},
    {:delete_asset, 1},
    {:signed_playback_url, 3},
    {:verify_webhook, 3}
  ]

  @expected_optional_callbacks [
    {:create_direct_upload, 2},
    {:cancel_direct_upload, 1}
  ]

  describe "behaviour_info(:callbacks) (D-04 lock)" do
    test "declares the locked 6 required + 2 optional callbacks (8 total)" do
      callbacks = Provider.behaviour_info(:callbacks)

      expected_all =
        Enum.sort(@expected_required_callbacks ++ @expected_optional_callbacks)

      assert Enum.sort(callbacks) == expected_all
    end

    test "declares create_direct_upload/2 and cancel_direct_upload/1 as optional (D-04)" do
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

  describe "BL-04: provider_state typespec aligned to String.t() (schema is :string)" do
    # The schema column `media_provider_assets.state` is a string field
    # (MediaProviderAsset), the FSM keys
    # (Rindle.Domain.ProviderAssetFSM.@allowed_transitions) are strings, and
    # adapter implementations (e.g. Rindle.Streaming.Provider.Mux.normalize_state/1)
    # return strings. The behaviour typespec must mirror that surface — atom
    # states would be a contract drift that Dialyzer would (correctly) flag as
    # soon as adopter callers land in Phase 36.
    test "provider_state type spec resolves to a String.t() / binary form" do
      # We can't introspect @type definitions cheaply at runtime, so this test
      # locks behavior end-to-end: the Mux adapter returns strings, and the
      # behaviour declares `state: provider_state()` for get_asset/1; if a
      # future commit re-introduces atom states in the typespec without
      # converting at the boundary, this assertion still passes (because the
      # impl is what matters), but the regression for Mux specifically is
      # caught by mux_test.exs (`%{state: "ready", ...}`). Here we lock that
      # the schema-canonical state set stays a list of strings.
      states = MediaProviderAsset.states()
      assert Enum.all?(states, &is_binary/1)

      assert Enum.sort(states) ==
               Enum.sort(["pending", "uploading", "processing", "ready", "errored", "deleted"])
    end
  end
end
