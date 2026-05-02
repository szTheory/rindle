defmodule Rindle.AV.CapabilityTest do
  use ExUnit.Case, async: true
  alias Rindle.AV.Capability

  describe "all/0" do
    test "returns a list of supported capabilities" do
      capabilities = Capability.all()
      assert is_list(capabilities)
      assert :video_transcode in capabilities
      assert :audio_normalize in capabilities
    end
  end

  describe "valid?/1" do
    test "returns true for valid capabilities" do
      assert Capability.valid?(:video_transcode)
      assert Capability.valid?(:audio_normalize)
    end

    test "returns false for invalid capabilities" do
      refute Capability.valid?(:invalid_capability)
      refute Capability.valid?("video_transcode")
    end
  end
end
