defmodule Rindle.Security.UploadValidationTest do
  use ExUnit.Case, async: true

  alias Rindle.Security.UploadValidation

  @jpeg_header <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, "JFIF", 0x00, 0x01, 0x01, 0x00>>
  @png_header <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D>>

  describe "validate_mime_and_extension/2" do
    test "rejects detected MIME types outside the allowlist" do
      upload = upload_fixture(@jpeg_header, filename: "photo.jpg", extension: ".jpg")
      policy = %{allow_mime: ["image/png"], allow_extensions: [".jpg"]}

      assert {:error, {:quarantine, :mime_not_allowed}} =
               UploadValidation.validate_mime_and_extension(upload, policy)
    end

    test "rejects extension and detected MIME mismatches" do
      upload = upload_fixture(@jpeg_header, filename: "spoofed.png", extension: ".png")
      policy = %{allow_mime: ["image/jpeg"], allow_extensions: [".png"]}

      assert {:error, {:quarantine, :extension_mime_mismatch}} =
               UploadValidation.validate_mime_and_extension(upload, policy)
    end

    test "ignores client-declared content-type when bytes disagree" do
      upload =
        upload_fixture(@jpeg_header,
          filename: "actual.jpg",
          extension: ".jpg",
          client_content_type: "image/png"
        )

      policy = %{allow_mime: ["image/jpeg"], allow_extensions: [".jpg"]}

      assert {:ok, %{detected_mime: "image/jpeg"}} =
               UploadValidation.validate_mime_and_extension(upload, policy)
    end
  end

  describe "validate_limits/2" do
    test "rejects uploads over byte limit" do
      upload = %{byte_size: 10_000, width: 120, height: 120}
      policy = %{max_bytes: 1_024, max_pixels: 1_000_000}

      assert {:error, {:quarantine, :max_bytes_exceeded}} =
               UploadValidation.validate_limits(upload, policy)
    end

    test "rejects uploads over pixel limit" do
      upload = %{byte_size: 10_000, width: 4_000, height: 4_000}
      policy = %{max_bytes: 100_000, max_pixels: 1_000_000}

      assert {:error, {:quarantine, :max_pixels_exceeded}} =
               UploadValidation.validate_limits(upload, policy)
    end
  end

  describe "validate_promotion_gate/2" do
    test "blocks direct-upload promotion when verification state is invalid" do
      upload = %{direct_upload: true, upload_session_state: "uploaded"}

      assert {:error, {:quarantine, :direct_upload_not_verified}} =
               UploadValidation.validate_promotion_gate(upload, :ok)
    end
  end

  describe "validate_for_promotion/4" do
    test "returns sanitized filename and generated storage key on success" do
      upload =
        upload_fixture(@png_header,
          filename: "../../unsafe name?.png",
          extension: ".png",
          direct_upload: true,
          upload_session_state: "verifying",
          width: 600,
          height: 400
        )

      policy = %{
        allow_mime: ["image/png"],
        allow_extensions: [".png"],
        max_bytes: 2_000_000,
        max_pixels: 1_000_000
      }

      assert {:ok, %{sanitized_filename: sanitized, storage_key: key}} =
               UploadValidation.validate_for_promotion(upload, policy, "avatars", "asset-123")

      assert String.contains?(sanitized, "_")
      refute String.contains?(key, "..")
      assert String.starts_with?(key, "avatars/asset-123/")
    end
  end

  defp upload_fixture(bytes, opts) do
    extension = Keyword.get(opts, :extension, ".jpg")
    filename = Keyword.get(opts, :filename, "upload#{extension}")
    path = write_temp_file(bytes, extension)

    %{
      path: path,
      filename: filename,
      extension: extension,
      client_content_type: Keyword.get(opts, :client_content_type, "application/octet-stream"),
      byte_size: Keyword.get(opts, :byte_size, byte_size(bytes)),
      width: Keyword.get(opts, :width, 1_024),
      height: Keyword.get(opts, :height, 768),
      direct_upload: Keyword.get(opts, :direct_upload, false),
      upload_session_state: Keyword.get(opts, :upload_session_state, "completed")
    }
  end

  defp write_temp_file(bytes, extension) do
    filename = "rindle-upload-#{System.unique_integer([:positive])}#{extension}"
    path = Path.join(System.tmp_dir!(), filename)
    File.write!(path, bytes)

    on_exit(fn ->
      File.rm(path)
    end)

    path
  end
end
