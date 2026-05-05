defmodule Rindle.Profile.ValidatorTest do
  use ExUnit.Case, async: true

  describe "validate_variant! :kind dispatch" do
    test "explicit :kind => :image compiles and omits :kind from validated map" do
      mod = compile_profile("""
      storage: Rindle.StorageMock,
      variants: [thumb: [kind: :image, mode: :fit, width: 64, height: 64]],
      allow_mime: ["image/jpeg"],
      allow_extensions: [".jpg"]
      """)

      thumb = mod.variants()[:thumb]
      refute Map.has_key?(thumb, :kind)
    end

    test ":kind => :video persists into validated map" do
      mod = compile_profile("""
      storage: Rindle.StorageMock,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      allow_extensions: [".mp4"]
      """)

      assert mod.variants()[:hero][:kind] == :video
    end
  end

  describe "validate_variant! :from_variant rejection" do
    test ":from_variant raises with cross-variant-chaining message" do
      assert_raise ArgumentError, ~r/cross-variant chaining is not supported/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("InvalidFromVariant")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["image/jpeg"],
            allow_extensions: [".jpg"],
            variants: [
              hero: [mode: :fit, width: 1200],
              poster: [kind: :image, mode: :fit, width: 320, from_variant: :hero]
            ]
        end
        """)
      end
    end
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
