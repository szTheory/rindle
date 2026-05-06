defmodule Rindle.Streaming.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias Rindle.Streaming.Capabilities

  defmodule GoodAdapter do
    @moduledoc false
    def capabilities, do: [:signed_playback, :unknown_cap, :webhook_ingest]
  end

  defmodule RaisingAdapter do
    @moduledoc false
    def capabilities, do: raise("boom")
  end

  defmodule BadShapeAdapter do
    @moduledoc false
    def capabilities, do: :not_a_list
  end

  defmodule SignedPlaybackOnlyAdapter do
    @moduledoc false
    def capabilities, do: [:signed_playback]
  end

  describe "known/0" do
    test "returns the locked 5-atom vocabulary in D-02 order" do
      assert Capabilities.known() == [
               :signed_playback,
               :public_playback,
               :webhook_ingest,
               :server_push_ingest,
               :direct_creator_upload
             ]
    end
  end

  describe "safe/1" do
    test "filters out unknown atoms returned by the adapter" do
      assert Capabilities.safe(GoodAdapter) == [:signed_playback, :webhook_ingest]
    end

    test "rescues a raise from adapter.capabilities/0 and returns []" do
      assert Capabilities.safe(RaisingAdapter) == []
    end

    test "returns [] when adapter.capabilities/0 returns a non-list" do
      assert Capabilities.safe(BadShapeAdapter) == []
    end
  end

  describe "supports?/2" do
    test "returns true for an advertised, known capability" do
      assert Capabilities.supports?(SignedPlaybackOnlyAdapter, :signed_playback)
    end

    test "returns false for a capability not in @known" do
      refute Capabilities.supports?(SignedPlaybackOnlyAdapter, :random_atom)
    end
  end

  describe "absence of require_streaming/2 (D-03 — Phase 37 / MUX-22)" do
    test "Rindle.Streaming.Capabilities does NOT export require_streaming/2" do
      Code.ensure_loaded!(Rindle.Streaming.Capabilities)
      refute function_exported?(Rindle.Streaming.Capabilities, :require_streaming, 2)
    end
  end
end
