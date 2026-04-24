defmodule Rindle.Profile.ProfileTest do
  use ExUnit.Case, async: true

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      allow_mime: ["image/jpeg", "image/png"],
      allow_extensions: [".jpg", ".jpeg", ".png"],
      max_bytes: 5_000_000,
      max_pixels: 24_000_000,
      variants: [
        thumb: [mode: :fit, width: 256, format: :jpeg, quality: 70],
        banner: [mode: :crop, width: 1_200, height: 400, format: :webp, quality: 80]
      ]
  end

  test "invalid profile options raise at compile time" do
    assert_raise ArgumentError, fn ->
      Code.compile_string("""
      defmodule #{unique_module_name("InvalidProfileUnknownKey")} do
        use Rindle.Profile,
          storage: Rindle.StorageMock,
          allow_mime: ["image/jpeg"],
          allow_extensions: [".jpg"],
          max_bytes: 1024,
          max_pixels: 1_000_000,
          variants: [thumb: [mode: :fit, width: 120]],
          unsupported_option: true
      end
      """)
    end
  end

  test "contradictory crop variant options raise at compile time" do
    assert_raise ArgumentError, ~r/requires both :width and :height/, fn ->
      Code.compile_string("""
      defmodule #{unique_module_name("InvalidProfileCrop")} do
        use Rindle.Profile,
          storage: Rindle.StorageMock,
          allow_mime: ["image/jpeg"],
          allow_extensions: [".jpg"],
          max_bytes: 1024,
          max_pixels: 1_000_000,
          variants: [hero: [mode: :crop, width: 900]]
      end
      """)
    end
  end

  test "variants/0 returns deterministic named entries" do
    assert [banner: banner, thumb: thumb] = TestProfile.variants()
    assert banner.mode == :crop
    assert thumb.mode == :fit
  end

  test "validate_upload/1 returns tuple outcomes" do
    valid_upload = %{
      content_type: "image/jpeg",
      extension: ".jpg",
      byte_size: 1_000_000,
      width: 1_920,
      height: 1_080
    }

    assert {:ok, ^valid_upload} = TestProfile.validate_upload(valid_upload)
    assert {:error, {:mime_not_allowed, "image/gif"}} = TestProfile.validate_upload(%{valid_upload | content_type: "image/gif"})
    assert {:error, {:byte_size_exceeded, 10_000_000, 5_000_000}} = TestProfile.validate_upload(%{valid_upload | byte_size: 10_000_000})
  end

  test "digest is stable when equivalent specs use reordered keys" do
    module_a =
      compile_profile("""
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :fit, width: 320, format: :jpeg, quality: 75]
      ],
      allow_mime: ["image/jpeg"],
      allow_extensions: [".jpg"],
      max_bytes: 5_000_000,
      max_pixels: 24_000_000
      """)

    module_b =
      compile_profile("""
      max_pixels: 24_000_000,
      allow_extensions: [".jpg"],
      variants: [
        thumb: [quality: 75, format: :jpeg, width: 320, mode: :fit]
      ],
      storage: Rindle.StorageMock,
      max_bytes: 5_000_000,
      allow_mime: ["image/jpeg"]
      """)

    digest_a = module_a.recipe_digest(:thumb)
    digest_b = module_b.recipe_digest(:thumb)

    assert digest_a == digest_b
  end

  test "digest changes when recipe options change" do
    digest_before_module =
      compile_profile("""
      storage: Rindle.StorageMock,
      allow_mime: ["image/jpeg"],
      allow_extensions: [".jpg"],
      max_bytes: 5_000_000,
      max_pixels: 24_000_000,
      variants: [
        thumb: [mode: :fit, width: 320, format: :jpeg, quality: 70]
      ]
      """)

    digest_after_module =
      compile_profile("""
      storage: Rindle.StorageMock,
      allow_mime: ["image/jpeg"],
      allow_extensions: [".jpg"],
      max_bytes: 5_000_000,
      max_pixels: 24_000_000,
      variants: [
        thumb: [mode: :fit, width: 320, format: :webp, quality: 82]
      ]
      """)

    digest_before = digest_before_module.recipe_digest(:thumb)
    digest_after = digest_after_module.recipe_digest(:thumb)

    assert digest_before != digest_after
  end

  defp compile_profile(profile_opts_source) do
    module_name = unique_module_name("CompiledProfile")

    source = """
    defmodule #{module_name} do
      use Rindle.Profile,
        #{profile_opts_source}
    end
    """

    [{compiled_module, _bytecode}] = Code.compile_string(source)
    compiled_module
  end

  defp unique_module_name(prefix) do
    :"Elixir.Rindle.Profile.#{prefix}#{System.unique_integer([:positive])}"
  end
end
