defmodule Rindle.AV.FfprobeTest do
  use ExUnit.Case, async: true
  alias Rindle.AV.Ffprobe

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    source = Path.join(tmp_dir, "input.mp4")
    %{source: source}
  end

  describe "probe/1" do
    test "handles ffprobe failure on invalid file", %{source: source} do
      File.write!(source, "dummy content")
      assert {:error, {:ffprobe_failed, _status, _output}} = Ffprobe.probe(source)
    end
  end

  describe "parse_and_sanitize/1" do
    test "decodes JSON and HTML escapes string values" do
      json = """
      {
        "format": {
          "tags": {
            "title": "<script>alert(1)</script>"
          },
          "duration": "10.5"
        },
        "streams": [
          {
            "codec_name": "h264",
            "tags": {
              "language": "eng\\\" onerror=\\\"alert(1)"
            }
          }
        ]
      }
      """
      
      assert {:ok, metadata} = Ffprobe.parse_and_sanitize(json)
      assert metadata["format"]["tags"]["title"] == "&lt;script&gt;alert(1)&lt;/script&gt;"
      assert metadata["format"]["duration"] == "10.5"
      assert hd(metadata["streams"])["tags"]["language"] == "eng&quot; onerror=&quot;alert(1)"
      assert hd(metadata["streams"])["codec_name"] == "h264"
    end
    
    test "returns error on invalid JSON" do
      assert {:error, :invalid_json} = Ffprobe.parse_and_sanitize("{invalid")
    end
  end
end
