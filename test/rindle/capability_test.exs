defmodule Rindle.CapabilityTest do
  # async: false because tests mutate Application env for the Mux config keys.
  use ExUnit.Case, async: false

  @mux_config_key Rindle.Streaming.Provider.Mux

  setup do
    prior = Application.get_env(:rindle, @mux_config_key)

    on_exit(fn ->
      case prior do
        nil -> Application.delete_env(:rindle, @mux_config_key)
        value -> Application.put_env(:rindle, @mux_config_key, value)
      end
    end)

    Application.delete_env(:rindle, @mux_config_key)
    :ok
  end

  describe "report/0 top-level shape" do
    test "returns a map with :storage, :processor, :streaming top-level keys" do
      report = Rindle.Capability.report()

      assert is_map(report)
      assert Map.has_key?(report, :storage)
      assert Map.has_key?(report, :processor)
      assert Map.has_key?(report, :streaming)
    end

    test "report().streaming has :providers, :signed_playback_configured?, :configured_profiles" do
      report = Rindle.Capability.report()

      assert is_map(report.streaming)
      assert Map.has_key?(report.streaming, :providers)
      assert Map.has_key?(report.streaming, :signed_playback_configured?)
      assert Map.has_key?(report.streaming, :configured_profiles)

      assert is_map(report.streaming.providers)
      assert is_list(report.streaming.configured_profiles)
    end

    test "report().storage is a map" do
      report = Rindle.Capability.report()
      assert is_map(report.storage)
    end

    test "report().processor is a map" do
      report = Rindle.Capability.report()
      assert is_map(report.processor)
    end
  end

  describe "report().streaming.signed_playback_configured?" do
    test "is a boolean" do
      report = Rindle.Capability.report()
      assert is_boolean(report.streaming.signed_playback_configured?)
    end

    test "is false when Mux config is empty" do
      Application.put_env(:rindle, @mux_config_key, [])
      assert Rindle.Capability.report().streaming.signed_playback_configured? == false
    end

    test "is false when only signing_key_id is set (missing signing_private_key)" do
      Application.put_env(:rindle, @mux_config_key, signing_key_id: "kid-abc")
      assert Rindle.Capability.report().streaming.signed_playback_configured? == false
    end

    test "is false when only signing_private_key is set (missing signing_key_id)" do
      Application.put_env(:rindle, @mux_config_key,
        signing_private_key: "-----BEGIN PRIVATE KEY-----..."
      )

      assert Rindle.Capability.report().streaming.signed_playback_configured? == false
    end

    test "is true when both signing_key_id AND signing_private_key are binaries" do
      Application.put_env(:rindle, @mux_config_key,
        signing_key_id: "kid-abc",
        signing_private_key: "-----BEGIN PRIVATE KEY-----..."
      )

      assert Rindle.Capability.report().streaming.signed_playback_configured? == true
    end

    test "does not crash when :mux dep is absent (no Mux config + module not loaded)" do
      Application.delete_env(:rindle, @mux_config_key)

      # Must NOT raise — D-30 mandates Application.get_env/2 (returns []), not
      # Code.ensure_loaded?/1.
      report = Rindle.Capability.report()
      assert report.streaming.signed_playback_configured? == false
    end
  end

  describe "security invariant 14 — booleans + module names only" do
    test "inspect(report) does not contain the literal signing_private_key value" do
      private_key_marker = "-----BEGIN PRIVATE KEY-----TEST-DO-NOT-LEAK-ABCD-1234"

      Application.put_env(:rindle, @mux_config_key,
        signing_key_id: "kid-leak-test",
        signing_private_key: private_key_marker
      )

      report = Rindle.Capability.report()

      rendered = inspect(report, limit: :infinity, printable_limit: :infinity)
      refute rendered =~ private_key_marker
      refute rendered =~ "kid-leak-test"
    end
  end

  # Phase 36 WR-07: configured_streaming_profiles/1 is a public seam for the
  # doctor's streaming checks; the four input-shape branches need direct
  # coverage so a regression in the map vs keyword-list dual handling cannot
  # silently slip through.
  describe "configured_streaming_profiles/1 (Phase 36 WR-07)" do
    defmodule NoDeliveryProfile do
      @moduledoc false
      use Rindle.Profile,
        storage: Rindle.Storage.S3,
        variants: [thumb: [mode: :fit, width: 64, height: 64]]
    end

    defmodule MapStreamingProfile do
      @moduledoc false
      # The MuxWeb preset emits a keyword-list-shaped :streaming block which
      # delivery_policy/0 normalizes to a map. Use the preset to exercise the
      # map-shape branch end-to-end.
      use Rindle.Profile.Presets.MuxWeb,
        storage: Rindle.Storage.S3,
        allow_mime: ["video/mp4"],
        max_bytes: 100_000_000
    end

    defmodule KeywordStreamingProfile do
      @moduledoc false
      # Adopters who write a hand-rolled :streaming keyword list should hit
      # the keyword-shape branch in streaming_provider/1.
      use Rindle.Profile,
        storage: Rindle.Storage.S3,
        variants: [hero: [mode: :fit, width: 320]],
        allow_mime: ["video/mp4"],
        max_bytes: 100_000_000,
        delivery: [
          streaming: [
            provider: Rindle.Streaming.Provider.Mux,
            playback_policy: :signed,
            ingest_mode: :server_push,
            source_variant: :hero
          ]
        ]
    end

    defmodule RaisingDeliveryProfile do
      @moduledoc false
      # Stub a profile module whose delivery_policy/0 raises. The capability
      # aggregator's safely_call_zero/2 wraps this in a rescue and returns
      # nil, which configured_streaming_profiles/1 must treat as "not
      # streaming".
      def __rindle_profile__, do: true
      def variants, do: []
      def storage_adapter, do: Rindle.Storage.S3
      def delivery_policy, do: raise("boom")
    end

    test "(a) profile with no :streaming key returns []" do
      assert Rindle.Capability.configured_streaming_profiles([NoDeliveryProfile]) == []
    end

    test "(b) profile with map-shape :streaming is included" do
      assert Rindle.Capability.configured_streaming_profiles([MapStreamingProfile]) ==
               [MapStreamingProfile]
    end

    test "(c) profile with keyword-shape :streaming is included" do
      assert Rindle.Capability.configured_streaming_profiles([KeywordStreamingProfile]) ==
               [KeywordStreamingProfile]
    end

    test "(d) profile whose delivery_policy/0 raises is excluded gracefully" do
      assert Rindle.Capability.configured_streaming_profiles([RaisingDeliveryProfile]) == []
    end

    test "mixed list filters non-streaming, includes streaming, ignores raising" do
      profiles = [
        NoDeliveryProfile,
        MapStreamingProfile,
        KeywordStreamingProfile,
        RaisingDeliveryProfile
      ]

      result = Rindle.Capability.configured_streaming_profiles(profiles)

      assert MapStreamingProfile in result
      assert KeywordStreamingProfile in result
      refute NoDeliveryProfile in result
      refute RaisingDeliveryProfile in result
    end

    test "empty profile list returns []" do
      assert Rindle.Capability.configured_streaming_profiles([]) == []
    end
  end
end
