defmodule Rindle.Security.ArgvTest do
  use ExUnit.Case, async: true
  alias Rindle.Security.Argv

  describe "validate/1" do
    test "accepts safe strings without shell characters" do
      assert {:ok, _} =
               Argv.validate(
                 "-i input.mp4 -c:v libx264 -protocol_whitelist file,crypto,data output.mp4"
               )

      assert {:ok, _} =
               Argv.validate("ffmpeg -i test.mp4 -protocol_whitelist file,crypto,data out.mp4")
    end

    test "rejects shell interpolation patterns" do
      assert {:error, :invalid_format} = Argv.validate("-i input.mp4; rm -rf /")
      assert {:error, :invalid_format} = Argv.validate("-i input.mp4 && rm -rf /")
      assert {:error, :invalid_format} = Argv.validate("-i input.mp4 | grep test")
      assert {:error, :invalid_format} = Argv.validate("-i $(whoami).mp4")
      assert {:error, :invalid_format} = Argv.validate("-i `whoami`.mp4")
      assert {:error, :invalid_format} = Argv.validate("ffmpeg -i test.mp4 > out.txt")
      assert {:error, :invalid_format} = Argv.validate("ffmpeg -i test.mp4 < in.txt")
    end

    test "rejects ffmpeg commands without protocol whitelist" do
      assert {:error, :missing_protocol_whitelist} = Argv.validate("ffmpeg -i test.mp4 out.mp4")
      assert {:error, :missing_protocol_whitelist} = Argv.validate("-i test.mp4 out.mp4")
    end

    test "rejects HLS, DASH, and MKV ingest inputs" do
      assert {:error, :unsupported_ingest_format} =
               Argv.validate("-i test.m3u8 -protocol_whitelist file,crypto,data out.mp4")

      assert {:error, :unsupported_ingest_format} =
               Argv.validate("-i test.mpd -protocol_whitelist file,crypto,data out.mp4")

      assert {:error, :unsupported_ingest_format} =
               Argv.validate("-i test.mkv -protocol_whitelist file,crypto,data out.mp4")

      assert {:error, :unsupported_ingest_format} =
               Argv.validate("-f hls -i test -protocol_whitelist file,crypto,data out.mp4")

      assert {:error, :unsupported_ingest_format} =
               Argv.validate("-f dash -i test -protocol_whitelist file,crypto,data out.mp4")

      assert {:error, :unsupported_ingest_format} =
               Argv.validate("-f matroska -i test -protocol_whitelist file,crypto,data out.mp4")
    end
  end

  describe "sanitize/1" do
    test "removes shell characters" do
      assert Argv.sanitize("-i input.mp4; rm -rf /") == "-i input.mp4 rm -rf /"
      assert Argv.sanitize("-i input.mp4 & echo 1") == "-i input.mp4  echo 1"
    end
  end
end
