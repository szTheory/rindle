defmodule Rindle.Processor.FfmpegTest do
  use ExUnit.Case, async: true
  alias Rindle.Processor.Ffmpeg

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    source = Path.join(tmp_dir, "input.mp4")
    dest = Path.join(tmp_dir, "output.mp4")
    # Create dummy source
    File.write!(source, "dummy")
    %{source: source, dest: dest}
  end

  describe "process/3" do
    test "processes video_transcode capability", %{source: source, dest: dest} do
      spec = %{
        capability: :video_transcode,
        width: 1280,
        height: 720,
        video_codec: "libx264",
        audio_codec: "aac"
      }

      # We just check if it fails due to ffmpeg not existing or failing on dummy file,
      # which proves it executed Subprocess.run. But we can also mock it.
      # Actually, since it's a dummy file, ffmpeg will return exit status > 0
      # But let's verify it returns error instead of crashing.
      assert {:error, {:ffmpeg_failed, _status, _output}} = Ffmpeg.process(source, spec, dest)
    end

    test "processes audio_normalize capability", %{source: source, dest: dest} do
      spec = %{capability: :audio_normalize}
      assert {:error, {:ffmpeg_failed, _status, _output}} = Ffmpeg.process(source, spec, dest)
    end

    test "fails validation on shell injection", %{source: source, dest: dest} do
      spec = %{
        capability: :video_transcode,
        width: 1280,
        height: 720,
        video_codec: "libx264; rm -rf /"
      }

      assert {:error, :invalid_format} = Ffmpeg.process(source, spec, dest)
    end

    test "fails validation on unsupported ingest format" do
      spec = %{capability: :video_transcode}

      assert {:error, :unsupported_ingest_format} =
               Ffmpeg.process("input.m3u8", spec, "output.mp4")
    end
  end
end
