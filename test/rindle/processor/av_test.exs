defmodule Rindle.Processor.AVTest do
  use ExUnit.Case, async: true

  alias Rindle.Processor.AV
  alias Rindle.Probe.AVProbe
  alias Rindle.Processor.Ffmpeg

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "rindle-processor-av-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  describe "capabilities/0" do
    test "returns the exact Phase 25 AV capability list" do
      assert AV.capabilities() == [
               :video_transcode,
               :video_frame_extract,
               :video_thumbnail_strip,
               :audio_transcode,
               :audio_normalize,
               :audio_waveform
             ]
    end
  end

  describe "normalize/1" do
    test "canonicalizes equivalent video preset specs into the same map" do
      canonical =
        AV.normalize!(%{
          kind: :video,
          preset: :web_720p
        })

      explicit_defaults =
        AV.normalize!(%{
          preset: :web_720p,
          kind: :video,
          faststart: true
        })

      assert canonical == explicit_defaults

      assert canonical == %{
               kind: :video,
               output_kind: :video,
               preset: :web_720p,
               container: :mp4,
               video_codec: :h264,
               audio_codec: :aac,
               width: 1280,
               height: 720,
               crf: 23,
               audio_bitrate_kbps: 128,
               faststart: true
             }
    end

    test "canonicalizes equivalent audio specs into the same map" do
      assert AV.normalize!(%{kind: :audio, preset: :m4a_128k}) ==
               AV.normalize!(%{
                 preset: :m4a_128k,
                 kind: :audio,
                 normalize: false,
                 two_pass: false
               })
    end

    test "rejects raw ffmpeg passthrough keys at the AV boundary" do
      assert {:error, {:unsupported_keys, [:codec, :vf]}} =
               AV.normalize(%{
                 kind: :video,
                 preset: :web_720p,
                 codec: :h264,
                 vf: "scale=1280:720"
               })
    end
  end

  describe "process/3 compatibility seam" do
    test "compatibility wrapper delegates normalization failures through the AV boundary" do
      source = "/tmp/input.mp4"
      dest = "/tmp/output.mp4"

      assert {:error, {:unsupported_keys, [:codec]}} =
               Ffmpeg.process(source, %{kind: :video, preset: :web_720p, codec: :h264}, dest)
    end
  end

  describe "process/3 video outputs" do
    test "transcodes the web_720p preset into a real faststart mp4", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source.mp4")
      destination = Path.join(tmp_dir, "web_720p.mp4")

      build_video_fixture!(source)

      assert {:ok, ^destination} =
               AV.process(source, %{kind: :video, preset: :web_720p}, destination)

      assert {:ok, probe} = AVProbe.probe(destination)
      assert probe.kind == :video
      assert probe.width == 1280
      assert probe.height == 720
      assert probe.has_video_track == true
      assert probe.has_audio_track == true

      assert video_codec_name(destination) == "h264"
      assert audio_codec_name(destination) == "aac"
      assert faststart_enabled?(destination)
    end
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

  defp video_codec_name(path) do
    ffprobe_stream_value!(path, "v:0", "codec_name")
  end

  defp audio_codec_name(path) do
    ffprobe_stream_value!(path, "a:0", "codec_name")
  end

  defp faststart_enabled?(path) do
    {output, 0} =
      System.cmd("ffprobe", ["-v", "error", "-show_entries", "format_tags=major_brand", "-of", "default=nokey=1:noprint_wrappers=1", path], stderr_to_stdout: true)

    # Also verify the moov atom appears before mdat in the binary, which is the
    # operational effect `+faststart` is meant to guarantee.
    {:ok, binary} = File.read(path)
    moov_index = :binary.match(binary, "moov")
    mdat_index = :binary.match(binary, "mdat")

    String.trim(output) == "isom" and moov_index != :nomatch and mdat_index != :nomatch and moov_index < mdat_index
  end

  defp ffprobe_stream_value!(path, selector, entry) do
    args = [
      "-v",
      "error",
      "-select_streams",
      selector,
      "-show_entries",
      "stream=#{entry}",
      "-of",
      "default=nokey=1:noprint_wrappers=1",
      path
    ]

    {output, 0} = System.cmd("ffprobe", args, stderr_to_stdout: true)
    String.trim(output)
  end
end
