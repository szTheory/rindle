defmodule Rindle.Upload.ProxiedTest do
  use Rindle.DataCase, async: true
  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100]
      ],
      allow_mime: ["image/jpeg", "image/png"],
      max_bytes: 10_485_760
  end

  setup do
    # Create a small valid JPEG (or at least with JPEG magic bytes)
    tmp_path = Path.join(System.tmp_dir!(), "test_#{Ecto.UUID.generate()}.jpg")
    # JPEG magic bytes: FF D8 FF
    File.write!(tmp_path, <<0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06>>)
    
    on_exit(fn ->
      File.rm(tmp_path)
    end)
    
    {:ok, tmp_path: tmp_path}
  end

  describe "upload/2" do
    test "successfully uploads a valid file", %{tmp_path: tmp_path} do
      expect(Rindle.StorageMock, :store, fn _key, path, _opts ->
        assert path == tmp_path
        {:ok, %{key: "some-key"}}
      end)

      upload_params = %{
        path: tmp_path,
        filename: "test.jpg"
      }

      {:ok, asset} = Rindle.upload(TestProfile, upload_params)

      assert asset.state == "analyzing"
      assert asset.content_type == "image/jpeg"
      assert asset.filename == "test.jpg"
      assert asset.profile == to_string(TestProfile)
    end

    test "quarantines file with mismatched MIME", %{tmp_path: tmp_path} do
      # Overwrite with different magic bytes (e.g., PNG)
      File.write!(tmp_path, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>)
      
      upload_params = %{
        path: tmp_path,
        filename: "test.jpg" # Extension says JPG, bytes say PNG
      }

      assert {:error, {:quarantine, :extension_mime_mismatch}} = Rindle.upload(TestProfile, upload_params)
    end

    test "quarantines file exceeding max_bytes", %{tmp_path: tmp_path} do
      # Small file but we'll use a profile with tiny max_bytes
      defmodule TinyProfile do
        use Rindle.Profile,
          storage: Rindle.StorageMock,
          variants: [],
          allow_mime: ["image/jpeg"],
          max_bytes: 1
      end
      
      upload_params = %{
        path: tmp_path,
        filename: "test.jpg"
      }

      assert {:error, {:quarantine, :max_bytes_exceeded}} = Rindle.upload(TinyProfile, upload_params)
    end
  end
end
