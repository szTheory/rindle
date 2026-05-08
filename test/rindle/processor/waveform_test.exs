defmodule Rindle.Processor.WaveformTest do
  use ExUnit.Case, async: true

  alias Rindle.Processor.AV

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "rindle-waveform-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  describe "process/3 waveform outputs" do
    test "emits the frozen overview JSON contract for audio assets", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source.wav")
      destination = Path.join(tmp_dir, "waveform.json")

      build_audio_fixture!(source)

      assert {:ok, ^destination} =
               AV.process(source, %{kind: :waveform, preset: :overview}, destination)

      assert {:ok, payload} = read_json(destination)
      assert Map.keys(payload) |> Enum.sort() == ["length", "peaks", "sample_rate"]
      assert payload["length"] == 1000
      assert is_integer(payload["sample_rate"])
      assert length(payload["peaks"]) == payload["length"]
      assert Enum.all?(payload["peaks"], &valid_peak_pair?/1)
    end

    test "extracts a waveform from a video asset that has audio", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source.mp4")
      destination = Path.join(tmp_dir, "video-waveform.json")

      build_video_fixture!(source)

      assert {:ok, ^destination} =
               AV.process(source, %{kind: :waveform, preset: :overview}, destination)

      assert {:ok, payload} = read_json(destination)
      assert payload["length"] == 1000
      assert length(payload["peaks"]) == 1000
    end

    test "fails deterministically when the source video has no audio track", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "silent.mp4")
      destination = Path.join(tmp_dir, "silent-waveform.json")

      build_silent_video_fixture!(source)

      assert {:error, :missing_audio_track} =
               AV.process(source, %{kind: :waveform, preset: :overview}, destination)
    end
  end

  defp build_audio_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=440:sample_rate=48000:duration=1.2",
      "-c:a",
      "pcm_s16le",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end

  defp build_video_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "testsrc=size=320x180:rate=30:duration=1.2",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=880:sample_rate=48000:duration=1.2",
      "-map",
      "0:v:0",
      "-map",
      "1:a:0",
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-c:a",
      "aac",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end

  defp build_silent_video_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "testsrc=size=320x180:rate=30:duration=1.2",
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end

  defp read_json(path) do
    with {:ok, body} <- File.read(path),
         {:ok, payload} <- Jason.decode(body) do
      {:ok, payload}
    end
  end

  defp valid_peak_pair?([min, max])
       when is_float(min) and is_float(max) and min >= -1.0 and max <= 1.0 and min <= max,
       do: true

  defp valid_peak_pair?(_pair), do: false
end
