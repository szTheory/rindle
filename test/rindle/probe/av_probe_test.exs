defmodule Rindle.Probe.AVProbeTest do
  use ExUnit.Case, async: true

  alias Rindle.Probe.AVProbe

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "rindle-probe-av-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  describe "accepts?/1" do
    test "returns true for video and audio mime types" do
      assert AVProbe.accepts?("video/mp4")
      assert AVProbe.accepts?("audio/mpeg")
    end

    test "returns false for other mime types and non-binaries" do
      refute AVProbe.accepts?("image/png")
      refute AVProbe.accepts?(nil)
      refute AVProbe.accepts?(:audio)
    end
  end

  describe "probe/1" do
    test "returns reshaped result for a video fixture", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "sample.mp4")
      metadata_title = String.duplicate("a", 1100) <> "\nscript"
      build_video_fixture!(path, metadata_title)

      assert {:ok, result} = AVProbe.probe(path)
      assert result.kind == :video
      assert result.has_video_track == true
      assert result.has_audio_track == true
      assert result.width == 16
      assert result.height == 16
      assert is_integer(result.duration_ms)
      assert result.duration_ms >= 100
      assert byte_size(result.metadata["format"]["title"]) <= 1024
      refute String.contains?(result.metadata["format"]["title"], "\n")
    end

    test "returns reshaped result for an audio fixture", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "sample.mp3")
      build_audio_fixture!(path)

      assert {:ok, result} = AVProbe.probe(path)
      assert result.kind == :audio
      assert result.has_video_track == false
      assert result.has_audio_track == true
      assert is_integer(result.duration_ms)
      assert result.duration_ms >= 100
      refute Map.has_key?(result, :width)
      refute Map.has_key?(result, :height)
    end

    test "propagates ffprobe failures for invalid input", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "garbage.mp4")
      File.write!(path, "not a real container")

      assert {:error, {:ffprobe_failed, _status, _output}} = AVProbe.probe(path)
    end
  end

  defp build_video_fixture!(path, title) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "testsrc=size=16x16:rate=1:duration=0.2",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=1000:duration=0.2",
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-c:a",
      "aac",
      "-metadata",
      "title=#{title}",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end

  defp build_audio_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=660:duration=0.2",
      "-c:a",
      "libmp3lame",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end
end
