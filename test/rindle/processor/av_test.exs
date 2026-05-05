defmodule Rindle.Processor.AVTest do
  use ExUnit.Case, async: true

  alias Rindle.Processor.AV
  alias Rindle.Processor.Ffmpeg

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
end
