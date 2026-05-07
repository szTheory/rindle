defmodule Rindle.Test.MuxWebhookFixturesTest do
  use ExUnit.Case, async: true

  alias Rindle.Test.MuxWebhookFixtures

  @secret "phase-35-test-secret-aaaa"
  @body ~s({"hello":"world"})

  describe "sign_header/3" do
    test "returns header in t=...,v1=... format with current timestamp" do
      before = System.system_time(:second)
      header = MuxWebhookFixtures.sign_header(@body, @secret)
      after_ts = System.system_time(:second)

      assert "t=" <> rest = header
      [ts_str, "v1=" <> hex] = String.split(rest, ",")

      {ts, ""} = Integer.parse(ts_str)
      assert ts >= before and ts <= after_ts
      assert String.length(hex) == 64
      assert hex =~ ~r/^[0-9a-f]{64}$/
    end

    test ":timestamp opt overrides default timestamp" do
      header = MuxWebhookFixtures.sign_header(@body, @secret, timestamp: 1_234_567_890)
      assert header =~ ~r/^t=1234567890,v1=[0-9a-f]{64}$/
    end

    test "produced header verifies against Mux.Webhooks.verify_header/4 (byte-accurate SDK compatibility)" do
      header = MuxWebhookFixtures.sign_header(@body, @secret)
      assert :ok = Mux.Webhooks.verify_header(@body, header, @secret, 60)
    end

    test "stale timestamp (replay attack) is rejected by Mux.Webhooks.verify_header/4" do
      stale_ts = System.system_time(:second) - 600
      header = MuxWebhookFixtures.sign_header(@body, @secret, timestamp: stale_ts)

      assert {:error, _} = Mux.Webhooks.verify_header(@body, header, @secret, 300)
    end

    test "different secret produces different signature" do
      h1 = MuxWebhookFixtures.sign_header(@body, "secret-a", timestamp: 1)
      h2 = MuxWebhookFixtures.sign_header(@body, "secret-b", timestamp: 1)

      refute h1 == h2
    end
  end
end
