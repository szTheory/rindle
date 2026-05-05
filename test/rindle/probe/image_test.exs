defmodule Rindle.Probe.ImageTest do
  use ExUnit.Case, async: true

  alias Rindle.Probe.Image, as: ImageProbe

  @png_1x1 <<
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x02,
    0x00,
    0x00,
    0x00,
    0x90,
    0x77,
    0x53,
    0xDE,
    0x00,
    0x00,
    0x00,
    0x0C,
    0x49,
    0x44,
    0x41,
    0x54,
    0x08,
    0xD7,
    0x63,
    0xF8,
    0xFF,
    0xFF,
    0x3F,
    0x00,
    0x05,
    0xFE,
    0x02,
    0xFE,
    0xDC,
    0x44,
    0x74,
    0x06,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82
  >>

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "rindle-probe-image-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    source_path = Path.join(tmp_dir, "source.png")
    File.write!(source_path, @png_1x1)

    on_exit(fn -> File.rm_rf(tmp_dir) end)

    {:ok, source_path: source_path, tmp_dir: tmp_dir}
  end

  describe "accepts?/1" do
    test "returns true for image mime types" do
      assert ImageProbe.accepts?("image/jpeg")
      assert ImageProbe.accepts?("image/png")
    end

    test "returns false for non-image mime types and non-binaries" do
      refute ImageProbe.accepts?("video/mp4")
      refute ImageProbe.accepts?("audio/mpeg")
      refute ImageProbe.accepts?(nil)
    end
  end

  describe "probe/1" do
    test "returns kind and dimensions for a valid image", %{source_path: source_path} do
      assert {:ok, %{kind: :image, width: 1, height: 1}} = ImageProbe.probe(source_path)
    end

    test "returns an error for a non-image file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "garbage.jpg")
      File.write!(path, "not an image")

      assert {:error, _reason} = ImageProbe.probe(path)
    end
  end
end
