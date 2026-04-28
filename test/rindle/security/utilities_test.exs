defmodule Rindle.Security.UtilitiesTest do
  use ExUnit.Case, async: true

  alias Rindle.Security.{Filename, Mime, StorageKey}

  describe "Filename.sanitize/1" do
    test "normalizes paths, control characters, and punctuation" do
      assert Filename.sanitize("../weird/\u0007photo name?.JPG") == "photo_name_.JPG"
    end

    test "falls back when the sanitized name is empty" do
      assert Filename.sanitize("\u0000////") == "upload"
    end
  end

  describe "StorageKey.generate/3" do
    test "normalizes all segments and extension" do
      key = StorageKey.generate("My Profile", "asset/../1", " PNG")

      assert String.starts_with?(key, "my-profile/asset----1/")
      assert String.ends_with?(key, ".png")
      refute String.contains?(key, "..")
      refute String.contains?(key, " ")
    end

  test "falls back when segments are not usable" do
      key = StorageKey.generate(nil, nil, nil)

      assert String.starts_with?(key, "profile/asset/")
      assert length(String.split(key, "/")) == 3
    end
  end

  describe "Mime helpers" do
    test "normalize_extension/1 adds a leading dot and downcases" do
      assert Mime.normalize_extension(" JPG ") == ".jpg"
    end

    test "detect/1 returns unknown_mime for missing files" do
      assert {:error, :unknown_mime} = Mime.detect("/no/such/file")
    end

    test "extension_matches_mime?/2 compares normalized extension values" do
      assert Mime.extension_matches_mime?(".JPG", "image/jpeg")
    end
  end
end
