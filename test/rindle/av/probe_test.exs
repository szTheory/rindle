defmodule Rindle.AV.ProbeTest do
  use ExUnit.Case, async: true
  alias Rindle.AV.Probe

  describe "check_ffmpeg!/1" do
    test "returns :ok when ffmpeg is >= 6.0" do
      mock_runner = fn "ffmpeg", ["-version"] ->
        {"ffmpeg version 6.0.0 Copyright (c) 2000-2023 the FFmpeg developers\n", 0}
      end

      assert :ok = Probe.check_ffmpeg!(mock_runner)
    end

    test "returns :ok when ffmpeg is much newer" do
      mock_runner = fn "ffmpeg", ["-version"] ->
        {"ffmpeg version 7.1 Copyright (c) 2000-2024 the FFmpeg developers\n", 0}
      end

      assert :ok = Probe.check_ffmpeg!(mock_runner)
    end

    test "raises when ffmpeg is < 6.0" do
      mock_runner = fn "ffmpeg", ["-version"] ->
        {"ffmpeg version 5.1.2 Copyright (c) 2000-2022 the FFmpeg developers\n", 0}
      end

      assert_raise RuntimeError, ~r/Rindle requires FFmpeg >= 6.0, found: 5.1/, fn ->
        Probe.check_ffmpeg!(mock_runner)
      end
    end

    test "raises when ffmpeg output cannot be parsed" do
      mock_runner = fn "ffmpeg", ["-version"] ->
        {"some invalid output\n", 0}
      end

      assert_raise RuntimeError, "Could not parse FFmpeg version.", fn ->
        Probe.check_ffmpeg!(mock_runner)
      end
    end

    test "raises when ffmpeg is not found or fails" do
      mock_runner = fn "ffmpeg", ["-version"] ->
        {"command not found", 127}
      end

      assert_raise RuntimeError, "FFmpeg is not installed or not in PATH.", fn ->
        Probe.check_ffmpeg!(mock_runner)
      end
    end
  end
end
