defmodule Rindle.ProbeTest do
  use ExUnit.Case, async: true

  defmodule StubProbe do
    @behaviour Rindle.Probe

    @impl Rindle.Probe
    def accepts?("image/" <> _), do: true
    def accepts?(_), do: false

    @impl Rindle.Probe
    def probe(_path), do: {:ok, %{kind: :image, width: 100, height: 100}}
  end

  describe "Rindle.Probe behaviour" do
    test "is loaded as a behaviour module" do
      assert Code.ensure_loaded?(Rindle.Probe)
    end

    test "declares probe/1 and accepts?/1 callbacks" do
      callbacks = Rindle.Probe.behaviour_info(:callbacks)
      assert {:probe, 1} in callbacks
      assert {:accepts?, 1} in callbacks
    end

    test "stub implementation compiles and dispatches" do
      assert StubProbe.accepts?("image/jpeg") == true
      assert StubProbe.accepts?("video/mp4") == false
      assert {:ok, %{kind: :image}} = StubProbe.probe("/dev/null")
    end
  end
end
