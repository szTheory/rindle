defmodule Rindle.Processor.AVTest do
  use ExUnit.Case, async: false

  alias Rindle.Probe.AVProbe
  alias Rindle.Processor.AV
  alias Rindle.Processor.AV.Audio
  alias Rindle.Processor.AV.Video
  alias Rindle.Processor.Ffmpeg

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "rindle-processor-av-#{System.unique_integer([:positive])}")

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
      canonical = AV.normalize!(%{kind: :audio, preset: :m4a_128k})

      assert canonical ==
               AV.normalize!(%{
                 preset: :m4a_128k,
                 kind: :audio,
                 normalize: false,
                 two_pass: false
               })

      assert canonical == %{
               kind: :audio,
               output_kind: :audio,
               preset: :m4a_128k,
               container: :m4a,
               audio_codec: :aac,
               audio_bitrate_kbps: 128,
               normalize: false,
               two_pass: false
             }
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

  describe "process/3 audio outputs" do
    test "transcodes the m4a preset into real AAC audio and supports channel reduction", %{
      tmp_dir: tmp_dir
    } do
      source = Path.join(tmp_dir, "source.wav")
      destination = Path.join(tmp_dir, "preview.m4a")

      build_stereo_audio_fixture!(source)

      assert {:ok, ^destination} =
               AV.process(source, %{kind: :audio, preset: :m4a_128k, channels: 1}, destination)

      assert {:ok, probe} = AVProbe.probe(destination)
      assert probe.kind == :audio
      assert probe.has_audio_track == true
      assert probe.has_video_track == false
      assert audio_codec_name(destination) == "aac"
      assert audio_channel_count(destination) == 1
    end

    test "single-pass loudnorm produces a real mp3 output", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "quiet.wav")
      destination = Path.join(tmp_dir, "normalized.mp3")

      build_stereo_audio_fixture!(source, volume_db: -20)

      assert {:ok, ^destination} =
               AV.process(
                 source,
                 %{kind: :audio, preset: :mp3_128k, normalize: true},
                 destination
               )

      assert {:ok, probe} = AVProbe.probe(destination)
      assert probe.kind == :audio
      assert audio_codec_name(destination) == "mp3"
    end

    test "two-pass loudnorm uses the explicit higher-fidelity branch", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "quiet-two-pass.wav")
      destination = Path.join(tmp_dir, "normalized-two-pass.m4a")

      build_stereo_audio_fixture!(source, volume_db: -20)

      assert {:ok, ^destination} =
               AV.process(
                 source,
                 %{kind: :audio, preset: :m4a_128k, normalize: true, two_pass: true},
                 destination
               )

      assert {:ok, probe} = AVProbe.probe(destination)
      assert probe.kind == :audio
      assert audio_codec_name(destination) == "aac"
    end
  end

  describe "audio transcode helpers" do
    test "rejects two_pass without normalize at the audio boundary" do
      assert {:error, {:invalid_audio_recipe, :two_pass_requires_normalize}} =
               Audio.transcode("/tmp/in.wav", %{two_pass: true, normalize: false}, "/tmp/out.m4a")
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

  describe "process/3 explicit image outputs" do
    test "extracts a poster from the first scene-change I-frame", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "scene-source.mp4")
      destination = Path.join(tmp_dir, "poster.jpg")

      build_scene_change_fixture!(source)

      assert {:ok, %{path: ^destination, strategy: :scene_change}} =
               Video.poster(
                 source,
                 AV.normalize!(%{kind: :image, preset: :video_poster_scene}),
                 destination
               )

      assert File.exists?(destination)
      assert image_width(destination) == 320
      assert image_height(destination) == 180
      assert grayscale_luma(destination) > 200
    end

    test "falls back to the first I-frame when no scene-change frame qualifies", %{
      tmp_dir: tmp_dir
    } do
      source = Path.join(tmp_dir, "static-source.mp4")
      destination = Path.join(tmp_dir, "poster-fallback.jpg")

      build_static_video_fixture!(source)

      assert {:ok, %{path: ^destination, strategy: :first_i_frame}} =
               Video.poster(
                 source,
                 AV.normalize!(%{kind: :image, preset: :video_poster_scene}),
                 destination
               )

      assert File.exists?(destination)
      assert image_width(destination) == 320
      assert image_height(destination) == 180
    end

    test "generates a thumbnail strip only when explicitly requested", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "strip-source.mp4")
      destination = Path.join(tmp_dir, "strip.jpg")

      build_strip_fixture!(source)

      assert {:ok, ^destination} =
               AV.process(source, %{kind: :image, preset: :video_thumbnail_strip}, destination)

      assert File.exists?(destination)
      assert image_width(destination) == 640
      assert image_height(destination) == 90
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

  defp build_stereo_audio_fixture!(path, opts \\ []) do
    volume_db = Keyword.get(opts, :volume_db, -6)
    volume = "volume=#{volume_db}dB"

    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=440:sample_rate=48000:duration=1.2",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=660:sample_rate=48000:duration=1.2",
      "-filter_complex",
      "[0:a]#{volume}[left];[1:a]#{volume}[right];[left][right]join=inputs=2:channel_layout=stereo[a]",
      "-map",
      "[a]",
      "-c:a",
      "pcm_s16le",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end

  defp build_scene_change_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "color=c=black:size=320x180:rate=2:duration=0.5",
      "-f",
      "lavfi",
      "-i",
      "color=c=white:size=320x180:rate=2:duration=0.5",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=660:sample_rate=48000:duration=1.0",
      "-filter_complex",
      "[0:v][1:v]concat=n=2:v=1:a=0[v]",
      "-map",
      "[v]",
      "-map",
      "2:a:0",
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-force_key_frames",
      "0.5",
      "-c:a",
      "aac",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end

  defp build_static_video_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "color=c=gray:size=320x180:rate=2:duration=1.0",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=550:sample_rate=48000:duration=1.0",
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

  defp build_strip_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "testsrc=size=320x180:rate=1:duration=4",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=330:sample_rate=48000:duration=4",
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

  defp audio_channel_count(path) do
    ffprobe_stream_value!(path, "a:0", "channels") |> String.to_integer()
  end

  defp faststart_enabled?(path) do
    {output, 0} =
      System.cmd(
        "ffprobe",
        [
          "-v",
          "error",
          "-show_entries",
          "format_tags=major_brand",
          "-of",
          "default=nokey=1:noprint_wrappers=1",
          path
        ],
        stderr_to_stdout: true
      )

    # Also verify the moov atom appears before mdat in the binary, which is the
    # operational effect `+faststart` is meant to guarantee.
    {:ok, binary} = File.read(path)
    moov_index = :binary.match(binary, "moov")
    mdat_index = :binary.match(binary, "mdat")

    String.trim(output) == "isom" and moov_index != :nomatch and mdat_index != :nomatch and
      moov_index < mdat_index
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

  defp image_width(path), do: ffprobe_stream_value!(path, "v:0", "width") |> String.to_integer()
  defp image_height(path), do: ffprobe_stream_value!(path, "v:0", "height") |> String.to_integer()

  defp grayscale_luma(path) do
    args = [
      "-v",
      "error",
      "-i",
      path,
      "-vf",
      "scale=1:1,format=gray",
      "-frames:v",
      "1",
      "-f",
      "rawvideo",
      "-"
    ]

    {output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: false)
    <<luma, _rest::binary>> = output
    luma
  end
end
