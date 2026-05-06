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
end
