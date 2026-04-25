defmodule Rindle.Processor.ImageTest do
  use ExUnit.Case, async: true

  alias Rindle.Processor.Image, as: ImageProcessor

  @png_1x1 <<
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
    0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74, 0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
    0x44, 0xAE, 0x42, 0x60, 0x82
  >>

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "rindle_processor_test_#{Ecto.UUID.generate()}")
    File.mkdir_p!(tmp_dir)
    
    source_path = Path.join(tmp_dir, "source.png")
    File.write!(source_path, @png_1x1)
    
    on_exit(fn ->
      File.rm_rf(tmp_dir)
    end)
    
    {:ok, source_path: source_path, tmp_dir: tmp_dir}
  end

  test "resizes an image", %{source_path: source_path, tmp_dir: tmp_dir} do
    destination_path = Path.join(tmp_dir, "thumb.png")
    spec = %{width: 10, height: 10, mode: :crop}
    
    {:ok, path} = ImageProcessor.process(source_path, spec, destination_path)
    
    assert path == destination_path
    assert File.exists?(path)
    
    {:ok, img} = Image.open(path)
    assert Image.width(img) == 10
    assert Image.height(img) == 10
  end

  test "converts format", %{source_path: source_path, tmp_dir: tmp_dir} do
    destination_path = Path.join(tmp_dir, "converted.jpg")
    spec = %{width: 5, mode: :fit, format: :jpg}
    
    {:ok, path} = ImageProcessor.process(source_path, spec, destination_path)
    
    assert Path.extname(path) == ".jpg"
    assert File.exists?(path)
    
    # Verify it's actually a JPEG via magic bytes
    {:ok, binary} = File.read(path)
    assert binary =~ <<0xFF, 0xD8, 0xFF>>
  end
end
