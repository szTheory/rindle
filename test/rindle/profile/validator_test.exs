defmodule Rindle.Profile.ValidatorTest do
  @moduledoc """
  Compile-time per-kind validation tests (AV-02-06, AV-02-07, AV-02-08).
  Mirrors the assert_raise/Code.compile_string idiom from
  test/rindle/profile/profile_test.exs:17-48.
  """
  use ExUnit.Case, async: true

  describe "validate_variant! :kind dispatch (AV-02-06)" do
    test "default :kind => :image (omitted) compiles and produces a variant map without :kind" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        variants: [thumb: [mode: :fit, width: 64, height: 64]],
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        max_bytes: 5_000_000,
        max_pixels: 24_000_000
        """)

      thumb = mod.variants()[:thumb]

      refute Map.has_key?(thumb, :kind),
             "default :image must omit :kind from validated map (D-14)"

      assert thumb.mode == :fit
      assert thumb.width == 64
    end

    test "explicit :kind => :image compiles and ALSO omits :kind from validated map (D-14 invariant)" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        variants: [thumb: [kind: :image, mode: :fit, width: 64, height: 64]],
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"]
        """)

      thumb = mod.variants()[:thumb]

      refute Map.has_key?(thumb, :kind),
             "explicit :image must ALSO omit :kind for digest parity with default :image (D-14)"
    end

    test ":kind => :video persists into validated map" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        variants: [hero: [kind: :video, preset: :web_720p]],
        allow_mime: ["video/mp4"],
        allow_extensions: [".mp4"]
        """)

      hero = mod.variants()[:hero]
      assert hero[:kind] == :video
      assert hero[:preset] == :web_720p
      assert hero[:faststart] == true
      refute Map.has_key?(hero, :codec)
      refute Map.has_key?(hero, :container)
    end

    test ":kind => :audio persists into validated map" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        variants: [aac: [kind: :audio, preset: :m4a_128k]],
        allow_mime: ["audio/mp4"],
        allow_extensions: [".m4a"]
        """)

      aac = mod.variants()[:aac]
      assert aac[:kind] == :audio
      assert aac[:preset] == :m4a_128k
      assert aac[:normalize] == false
      assert aac[:two_pass] == false
    end

    test ":kind => :waveform persists into validated map" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        variants: [peaks: [kind: :waveform, preset: :overview]],
        allow_mime: ["audio/mpeg"],
        allow_extensions: [".mp3"]
        """)

      peaks = mod.variants()[:peaks]
      assert peaks[:kind] == :waveform
      assert peaks[:preset] == :overview
      assert Map.keys(peaks) |> Enum.sort() == [:kind, :preset]
    end

    test ":kind => :unknown raises with allowed-list fix hint (D-13)" do
      assert_raise ArgumentError, ~r/allowed: :image \| :video \| :audio \| :waveform/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("InvalidKind")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            variants: [bad: [kind: :unknown, mode: :fit, width: 100]],
            allow_mime: ["image/jpeg"],
            allow_extensions: [".jpg"]
        end
        """)
      end
    end
  end

  describe "validate_variant! :from_variant rejection (AV-02-08, D-15)" do
    test ":from_variant in any variant spec raises with cross-variant-chaining message" do
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

    test "from_variant rejection mentions AV-02-08 anchor in message" do
      assert_raise ArgumentError, ~r/AV-02-08/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("InvalidFromVariantAnchor")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [poster: [kind: :video, preset: :web_720p, from_variant: :hero]]
        end
        """)
      end
    end
  end

  describe "per-kind schema rejection of cross-kind keys" do
    test ":image schema rejects :preset (AV key)" do
      assert_raise ArgumentError, ~r/unknown options/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("ImageWithPreset")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["image/jpeg"],
            allow_extensions: [".jpg"],
            variants: [thumb: [mode: :fit, width: 64, preset: :web_720p]]
        end
        """)
      end
    end

    test ":video schema rejects raw codec passthrough" do
      assert_raise ArgumentError, ~r/unknown options/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("VideoWithCodec")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [hero: [kind: :video, preset: :web_720p, codec: :h264]]
        end
        """)
      end
    end

    test ":audio schema rejects raw bitrate passthrough" do
      assert_raise ArgumentError, ~r/unknown options/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("AudioWithBitrate")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["audio/mp4"],
            allow_extensions: [".m4a"],
            variants: [aac: [kind: :audio, preset: :m4a_128k, bitrate_kbps: 192]]
        end
        """)
      end
    end

    test ":waveform schema rejects raw peaks passthrough" do
      assert_raise ArgumentError, ~r/unknown options/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("WaveformWithPeaks")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["audio/mpeg"],
            allow_extensions: [".mp3"],
            variants: [peaks: [kind: :waveform, preset: :overview, peaks: 1000]]
        end
        """)
      end
    end

    test ":waveform schema rejects sample_rate passthrough" do
      assert_raise ArgumentError, ~r/unknown options/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("WaveformWithSampleRate")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["audio/mpeg"],
            allow_extensions: [".mp3"],
            variants: [peaks: [kind: :waveform, preset: :overview, sample_rate: 8_000]]
        end
        """)
      end
    end

    test ":waveform schema rejects channels passthrough" do
      assert_raise ArgumentError, ~r/unknown options/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("WaveformWithChannels")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["audio/mpeg"],
            allow_extensions: [".mp3"],
            variants: [peaks: [kind: :waveform, preset: :overview, channels: 1]]
        end
        """)
      end
    end
  end

  describe "per-kind schema preset allowlists" do
    test ":video preset must be :web_720p or :web_480p" do
      assert_raise ArgumentError, ~r/preset/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("VideoBadPreset")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [hero: [kind: :video, preset: :ultra_4k]]
        end
        """)
      end
    end

    test ":audio preset must be :m4a_128k or :mp3_128k" do
      assert_raise ArgumentError, ~r/preset/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("AudioBadPreset")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["audio/mp4"],
            allow_extensions: [".m4a"],
            variants: [aac: [kind: :audio, preset: :flac_lossless]]
        end
        """)
      end
    end

    test ":waveform preset must be :overview" do
      assert_raise ArgumentError, ~r/preset/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("WaveformBadPreset")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["audio/mpeg"],
            allow_extensions: [".mp3"],
            variants: [wave: [kind: :waveform, preset: :detailed]]
        end
        """)
      end
    end
  end

  describe "normalized AV digest stability" do
    test "equivalent video specs hash identically after normalization" do
      implicit_defaults =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["video/mp4"],
        allow_extensions: [".mp4"],
        variants: [hero: [kind: :video, preset: :web_720p]]
        """)

      explicit_defaults =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["video/mp4"],
        allow_extensions: [".mp4"],
        variants: [hero: [faststart: true, preset: :web_720p, kind: :video]]
        """)

      assert implicit_defaults.recipe_digest(:hero) == explicit_defaults.recipe_digest(:hero)
    end

    test "equivalent audio specs hash identically after normalization" do
      implicit_defaults =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["audio/mp4"],
        allow_extensions: [".m4a"],
        variants: [preview: [kind: :audio, preset: :m4a_128k]]
        """)

      explicit_defaults =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["audio/mp4"],
        allow_extensions: [".m4a"],
        variants: [preview: [preset: :m4a_128k, kind: :audio, normalize: false, two_pass: false]]
        """)

      assert implicit_defaults.recipe_digest(:preview) ==
               explicit_defaults.recipe_digest(:preview)
    end
  end

  describe "image dimension regression (AV-02-07 backward compat)" do
    test "mode: :crop without width AND height still raises (existing v1.0 behavior preserved)" do
      assert_raise ArgumentError, ~r/requires both :width and :height/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("CropMissingDim")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["image/jpeg"],
            allow_extensions: [".jpg"],
            variants: [hero: [mode: :crop, width: 900]]
        end
        """)
      end
    end

    test "mode: :fit with no dimensions still raises" do
      assert_raise ArgumentError, ~r/requires at least one dimension/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("FitNoDim")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["image/jpeg"],
            allow_extensions: [".jpg"],
            variants: [thumb: [mode: :fit]]
        end
        """)
      end
    end
  end

  describe "validate_delivery! :streaming key (Phase 33 STREAM-05; D-15..D-18)" do
    test "full valid :streaming config compiles and produces all 4 keys (D-15)" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["video/mp4"],
        allow_extensions: [".mp4"],
        variants: [web: [kind: :video, preset: :web_720p]],
        delivery: [
          streaming: [
            provider: Rindle.Streaming.Provider.Mux,
            playback_policy: :signed,
            ingest_mode: :server_push,
            source_variant: :web
          ]
        ]
        """)

      streaming = mod.delivery_policy()[:streaming]
      assert streaming.provider == Rindle.Streaming.Provider.Mux
      assert streaming.playback_policy == :signed
      assert streaming.ingest_mode == :server_push
      assert streaming.source_variant == :web
    end

    test "no :streaming key → delivery.streaming is nil (D-17)" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        variants: [thumb: [mode: :fit, width: 64]],
        delivery: [public: false]
        """)

      assert Map.get(mod.delivery_policy(), :streaming) == nil
    end

    test "explicit streaming: nil → delivery.streaming is nil (D-17)" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        variants: [thumb: [mode: :fit, width: 64]],
        delivery: [streaming: nil]
        """)

      assert Map.get(mod.delivery_policy(), :streaming) == nil
    end

    test "image-only profile compiles without :streaming (D-17 regression)" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        variants: [thumb: [mode: :fit, width: 64, height: 64]]
        """)

      thumb = mod.variants()[:thumb]
      assert thumb.mode == :fit
      assert Map.get(mod.delivery_policy(), :streaming) == nil
    end

    test "AV-only profile (variant kind: :video) compiles without :streaming (D-17)" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["video/mp4"],
        allow_extensions: [".mp4"],
        variants: [web: [kind: :video, preset: :web_720p]]
        """)

      web = mod.variants()[:web]
      assert web[:kind] == :video
      assert Map.get(mod.delivery_policy(), :streaming) == nil
    end

    test "raw provider knob :max_resolution_tier raises (D-16)" do
      assert_raise ArgumentError,
                   ~r/(unknown options.*max_resolution_tier|max_resolution_tier.*unknown)/i,
                   fn ->
                     Code.compile_string("""
                     defmodule #{unique_module_name("StreamingRawKnob")} do
                       use Rindle.Profile,
                         storage: Rindle.StorageMock,
                         allow_mime: ["video/mp4"],
                         allow_extensions: [".mp4"],
                         variants: [web: [kind: :video, preset: :web_720p]],
                         delivery: [
                           streaming: [
                             provider: Rindle.Streaming.Provider.Mux,
                             playback_policy: :signed,
                             ingest_mode: :server_push,
                             source_variant: :web,
                             max_resolution_tier: "1080p"
                           ]
                         ]
                     end
                     """)
                   end
    end

    test "raw provider knob :input raises (D-16)" do
      assert_raise ArgumentError, ~r/unknown options.*input/i, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("StreamingInputKnob")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [web: [kind: :video, preset: :web_720p]],
            delivery: [
              streaming: [
                provider: Rindle.Streaming.Provider.Mux,
                playback_policy: :signed,
                ingest_mode: :server_push,
                source_variant: :web,
                input: "https://example/foo.mp4"
              ]
            ]
        end
        """)
      end
    end

    test "missing :provider raises (NimbleOptions required)" do
      assert_raise ArgumentError, ~r/required.*:provider|:provider.*required/i, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("StreamingNoProvider")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [web: [kind: :video, preset: :web_720p]],
            delivery: [
              streaming: [
                playback_policy: :signed,
                ingest_mode: :server_push,
                source_variant: :web
              ]
            ]
        end
        """)
      end
    end

    test ":playback_policy must be :signed or :public (rejects :other)" do
      assert_raise ArgumentError, ~r/playback_policy/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("StreamingBadPolicy")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [web: [kind: :video, preset: :web_720p]],
            delivery: [
              streaming: [
                provider: Rindle.Streaming.Provider.Mux,
                playback_policy: :other,
                ingest_mode: :server_push,
                source_variant: :web
              ]
            ]
        end
        """)
      end
    end

    test ":ingest_mode must be :server_push or :direct_creator_upload (rejects :other)" do
      assert_raise ArgumentError, ~r/ingest_mode/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("StreamingBadIngest")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [web: [kind: :video, preset: :web_720p]],
            delivery: [
              streaming: [
                provider: Rindle.Streaming.Provider.Mux,
                playback_policy: :signed,
                ingest_mode: :other,
                source_variant: :web
              ]
            ]
        end
        """)
      end
    end

    test ":source_variant non-atom raises (NimbleOptions :atom type check)" do
      assert_raise ArgumentError, ~r/source_variant/, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("StreamingBadVariantType")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [web: [kind: :video, preset: :web_720p]],
            delivery: [
              streaming: [
                provider: Rindle.Streaming.Provider.Mux,
                playback_policy: :signed,
                ingest_mode: :server_push,
                source_variant: "web"
              ]
            ]
        end
        """)
      end
    end

    test "source_variant atom not declared in variants/0 raises (D-18 partial)" do
      assert_raise ArgumentError, ~r/source_variant.*:nonexistent.*not declared/i, fn ->
        Code.compile_string("""
        defmodule #{unique_module_name("StreamingMissingVariant")} do
          use Rindle.Profile,
            storage: Rindle.StorageMock,
            allow_mime: ["video/mp4"],
            allow_extensions: [".mp4"],
            variants: [web: [kind: :video, preset: :web_720p]],
            delivery: [
              streaming: [
                provider: Rindle.Streaming.Provider.Mux,
                playback_policy: :signed,
                ingest_mode: :server_push,
                source_variant: :nonexistent
              ]
            ]
        end
        """)
      end
    end

    test "source_variant points at :image-kind variant compiles in Phase 33 (D-18 deferred to Phase 34)" do
      # Phase 33 only validates atom presence in variants/0; per-variant kind: enforcement
      # (e.g. source_variant must be :video/:audio) is deferred to Phase 34.
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        variants: [web: [mode: :fit, width: 1024]],
        delivery: [
          streaming: [
            provider: Rindle.Streaming.Provider.Mux,
            playback_policy: :signed,
            ingest_mode: :server_push,
            source_variant: :web
          ]
        ]
        """)

      assert mod.delivery_policy()[:streaming].source_variant == :web
    end

    test "pre-existing delivery: [public: true] without :streaming compiles unchanged (regression)" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        variants: [thumb: [mode: :fit, width: 64]],
        delivery: [public: true]
        """)

      assert mod.delivery_policy().public == true
      assert Map.get(mod.delivery_policy(), :streaming) == nil
    end

    test "pre-existing delivery: [signed_url_ttl_seconds: 3600] without :streaming compiles unchanged (regression)" do
      mod =
        compile_profile("""
        storage: Rindle.StorageMock,
        allow_mime: ["image/jpeg"],
        allow_extensions: [".jpg"],
        variants: [thumb: [mode: :fit, width: 64]],
        delivery: [signed_url_ttl_seconds: 3600]
        """)

      assert mod.delivery_policy().signed_url_ttl_seconds == 3600
      assert Map.get(mod.delivery_policy(), :streaming) == nil
    end
  end

  # Helpers (mirror test/rindle/profile/profile_test.exs:179-195)
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
