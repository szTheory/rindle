defmodule Rindle.ErrorTest do
  use ExUnit.Case, async: true

  @troubleshooting_path Path.expand("../../guides/troubleshooting.md", __DIR__)
  @operations_path Path.expand("../../guides/operations.md", __DIR__)
  @av_public_reasons [
    :processor_capability_missing,
    :ffmpeg_not_found,
    :capability_drift,
    :variant_source_not_found,
    :unsupported_codec,
    :streaming_not_configured,
    :variant_processing_cancelled,
    :range_unparseable,
    :tus_session_not_found,
    :tus_session_expired,
    :tus_offset_conflict,
    :tus_size_exceeded,
    :tus_url_signature_invalid
  ]

  test "locks the public AV and tus reason atoms" do
    assert @av_public_reasons == [
             :processor_capability_missing,
             :ffmpeg_not_found,
             :capability_drift,
             :variant_source_not_found,
             :unsupported_codec,
             :streaming_not_configured,
             :variant_processing_cancelled,
             :range_unparseable,
             :tus_session_not_found,
             :tus_session_expired,
             :tus_offset_conflict,
             :tus_size_exceeded,
             :tus_url_signature_invalid
           ]
  end

  test "renders exact messages for generic AV-facing reason atoms" do
    expected_messages = %{
      processor_capability_missing:
        exact("""
        Variant processing requires a processor capability that is not available.

        To fix:
          1. Confirm FFmpeg is installed and on PATH (`which ffmpeg`).
          2. Use a processor that declares the required AV capability.
          3. Or remove the incompatible AV variant from the profile.

        Run `mix rindle.doctor` to verify.
        """),
      ffmpeg_not_found:
        exact("""
        FFmpeg executable not found on PATH.

        Rindle's video and audio processors require FFmpeg ≥ 4.0. To fix:
          • macOS:        brew install ffmpeg
          • Debian/Ubuntu: apt-get install ffmpeg
          • Alpine/Docker: apk add ffmpeg

        If FFmpeg is installed elsewhere, set:
          config :rindle, :ffmpeg_path, "/usr/local/bin/ffmpeg"
        """),
      capability_drift:
        exact("""
        A previously available Rindle capability is no longer advertised by the current runtime.

        To proceed, either:
          1. Restore the missing capability in the adapter or processor configuration.
          2. Migrate any in-flight work that depended on it.
          3. Drop the capability requirement from your profile.
        """),
      variant_source_not_found:
        exact("""
        Source media could not be downloaded from storage before variant processing started.

        Check that the asset still exists, the storage adapter can read it, and the original ProcessVariant job is not racing with a purge or detach.
        """),
      unsupported_codec:
        exact("""
        The requested audio or video codec is not supported by the current Rindle processor configuration.

        Check your FFmpeg build and the variant's declared codec requirements before retrying.
        """),
      streaming_not_configured:
        exact("""
        Streaming playback was requested, but the current profile is not configured for that delivery path.

        Until a streaming provider is configured, callers should use `Rindle.Delivery.url/3` for progressive playback.
        """),
      variant_processing_cancelled:
        exact("""
        Variant processing was cancelled.

        This is expected when Rindle.cancel_processing/1 is called. The variant will not retry automatically; use `Rindle.requeue_variants/2` for asset-scoped repair if needed.
        """),
      range_unparseable:
        exact("""
        The HTTP Range header could not be parsed.

        Rindle falls back to a `200 OK` full-body response for malformed ranges by default. Fix the caller's Range header or enable strict parsing if you need hard failures.
        """),
      tus_session_not_found:
        exact("""
        The tus upload session could not be found.

        To fix:
          1. Confirm the client is resuming with the exact `Location` URL returned by the original tus `POST`.
          2. If the upload was deleted or expired, create a fresh tus upload instead of retrying the old URL.
          3. If you use `tus-js-client`, keep `removeFingerprintOnSuccess: true` enabled; modern `@uppy/tus` resumes and clears stale fingerprints automatically.
        """),
      tus_session_expired:
        exact("""
        The tus upload session has expired.

        To fix:
          1. Start a new tus upload and discard the expired URL.
          2. Keep client retries shorter than the server-side upload TTL.
          3. If long pauses are expected, increase the upload-session TTL in your runtime config before retrying.
        """),
      tus_offset_conflict:
        exact("""
        The tus client resumed from the wrong byte offset.

        To fix:
          1. Let the client issue `HEAD` and trust the returned `Upload-Offset` before resuming.
          2. Avoid mutating or replaying old partial chunks manually.
          3. If you are using tus-js-client or @uppy/tus, keep automatic resume enabled and do not override the offset flow.
        """),
      tus_size_exceeded:
        exact("""
        The tus upload exceeded the declared or allowed size.

        To fix:
          1. Keep the client's `Upload-Length` aligned with the real file size.
          2. Increase the server-side tus max size if this file should be accepted.
          3. Start a fresh upload after correcting the file or size limit; the current URL cannot be repaired in place.
        """),
      tus_url_signature_invalid:
        exact("""
        The tus upload URL signature is invalid.

        To fix:
          1. Treat the tus `Location` URL as opaque and reuse it byte-for-byte.
          2. Do not trim, rebuild, or append client-side path segments to the signed URL.
          3. If the URL was copied, cached, or mutated, start a new tus upload and use the fresh location.
        """)
    }

    for {reason, expected} <- expected_messages do
      error = struct!(Rindle.Error, action: :test_contract, reason: reason)
      assert Rindle.Error.message(error) == expected
    end
  end

  test "troubleshooting guide points operators back to the runtime-owned AV error contract" do
    troubleshooting = File.read!(@troubleshooting_path)

    assert troubleshooting =~ "Rindle.Error.message/1"
    assert troubleshooting =~ "test/rindle/error_test.exs"

    for reason <- @av_public_reasons do
      assert troubleshooting =~ "`#{inspect(reason)}`"
    end
  end

  test "operations and troubleshooting guides teach the supported repair verbs explicitly" do
    operations = File.read!(@operations_path)
    troubleshooting = File.read!(@troubleshooting_path)

    for guide <- [operations, troubleshooting] do
      assert guide =~ "reprobe"
      assert guide =~ "requeue"
      assert guide =~ "regenerate"
      assert guide =~ "cleanup"
      assert guide =~ "sweep"
    end

    assert operations =~ "Rindle.reprobe/1"
    assert operations =~ "Rindle.requeue_variants/2"
    assert operations =~ "mix rindle.regenerate_variants"
    assert operations =~ "mix rindle.cleanup_orphans"
    assert operations =~ "mix rindle.sweep_orphaned_temp_files"

    assert troubleshooting =~ "Rindle.reprobe/1"
    assert troubleshooting =~ "Rindle.requeue_variants/2"
  end

  test "renders exact message for processor_capability_missing" do
    error =
      struct!(Rindle.Error,
        action: :declare_variant,
        reason:
          {:processor_capability_missing,
           %{
             processor: MyApp.VideoProcessor,
             required: :video_transcode,
             declared: [:image_resize],
             variant: :hd_mp4,
             profile: MyApp.VideoProfile
           }}
      )

    assert Rindle.Error.message(error) ==
             exact("""
             Variant :hd_mp4 in MyApp.VideoProfile requires processor capability :video_transcode, but MyApp.VideoProcessor only declares: [:image_resize].

             To fix:
               1. Confirm FFmpeg is installed and on PATH (`which ffmpeg`).
               2. Use a processor that declares :video_transcode.
               3. Or remove :hd_mp4 from the profile's variants/0.

             Run `mix rindle.doctor MyApp.VideoProfile` to verify.
             """)
  end

  test "renders exact message for ffmpeg_not_found" do
    error =
      struct!(Rindle.Error,
        action: :process_variant,
        reason: {:ffmpeg_not_found, %{searched_path: "/usr/bin:/opt/homebrew/bin"}}
      )

    assert Rindle.Error.message(error) ==
             exact("""
             FFmpeg executable not found on PATH.

             Rindle's video and audio processors require FFmpeg ≥ 4.0. To fix:
               • macOS:        brew install ffmpeg
               • Debian/Ubuntu: apt-get install ffmpeg
               • Alpine/Docker: apk add ffmpeg

             If FFmpeg is installed elsewhere, set:
               config :rindle, :ffmpeg_path, "/usr/local/bin/ffmpeg"

             PATH checked: /usr/bin:/opt/homebrew/bin
             """)
  end

  test "renders exact message for capability_drift" do
    error =
      struct!(Rindle.Error,
        action: :validate_profile,
        reason:
          {:capability_drift,
           %{
             adapter: MyApp.MyStorage,
             previously: [:presigned_put, :head, :signed_url, :multipart_upload],
             now: [:presigned_put, :head, :signed_url],
             missing: [:multipart_upload]
           }}
      )

    assert Rindle.Error.message(error) ==
             exact("""
             Storage adapter MyApp.MyStorage previously advertised capability :multipart_upload but now does not.

             This may indicate:
               • The adapter is misconfigured (e.g. credentials lost permission to initiate multipart uploads).
               • The provider has changed (e.g. Cloudflare R2 multipart compatibility is provider-version-sensitive — see Rindle's R2 docs).
               • A code change removed the capability.

             Previously declared capabilities: [:presigned_put, :head, :signed_url, :multipart_upload]

             To proceed, either:
               1. Restore the adapter's capability (check provider config / credentials).
               2. Migrate existing in-flight multipart uploads with `mix rindle.cleanup --multipart-orphans`.
               3. Drop the capability requirement from your profile.
             """)
  end

  test "renders exact message for variant_source_not_found" do
    error =
      struct!(Rindle.Error,
        action: :process_variant,
        reason: {:variant_source_not_found, %{key: "uploads/abc.mp4", asset_id: 42}}
      )

    assert Rindle.Error.message(error) ==
             exact("""
             Source file for asset 42 (storage key "uploads/abc.mp4") could not be downloaded from storage.

             Likely causes:
               • The asset was purged before variant processing started (race condition between detach and the variant worker).
               • The storage adapter credentials lost permission to read the key.
               • The bucket policy blocks GET on this prefix.

             Check Oban dashboard for the original ProcessVariant job; if it has been retrying, the asset may be in a `quarantined` state.
             """)
  end

  test "renders exact message for unsupported_codec" do
    error =
      struct!(Rindle.Error,
        action: :process_variant,
        reason:
          {:unsupported_codec,
           %{codec: :av1, processor: Rindle.Processor.Video, supported: [:h264, :vp9, :hevc]}}
      )

    assert Rindle.Error.message(error) ==
             exact("""
             Variant requires codec :av1 but Rindle.Processor.Video only supports: [:h264, :vp9, :hevc].

             AV1 transcoding requires libaom or SVT-AV1 in your FFmpeg build:
               ffmpeg -codecs 2>&1 | grep av1

             If your FFmpeg supports av1 but Rindle still rejects it, file an issue at https://github.com/szTheory/rindle/issues with `ffmpeg -version` output.
             """)
  end

  test "renders exact message for streaming_not_configured" do
    error =
      struct!(Rindle.Error,
        action: :streaming_url,
        reason: {:streaming_not_configured, %{profile: MyApp.VideoProfile, requested_kind: :hls}}
      )

    assert Rindle.Error.message(error) ==
             exact("""
             MyApp.VideoProfile is not configured with a streaming provider, but :hls streaming was requested.

             In Rindle v1.4, only :progressive (signed-redirect MP4/WebM) is supported out of the box. To use HLS:
               1. Wait for the Rindle.Streaming.Mux or Rindle.Streaming.Cloudflare adapter (post-v1.4).
               2. Or configure your profile with a custom streaming provider:

                  use Rindle.Profile,
                    storage:   Rindle.Storage.S3,
                    streaming: MyApp.MyStreamingProvider

             Until then, callers should use Rindle.Delivery.url/3 for progressive playback.
             """)
  end

  test "renders exact message for variant_processing_cancelled" do
    error =
      struct!(Rindle.Error,
        action: :process_variant,
        reason:
          {:variant_processing_cancelled,
           %{
             variant_id: "variant-123",
             cancelled_at: "2026-05-02 14:23:11Z",
             reason: :user_cancelled
           }}
      )

    assert Rindle.Error.message(error) ==
             exact("""
             Variant variant-123 processing was cancelled (reason: user_cancelled, at: 2026-05-02 14:23:11Z).

             This is expected when Rindle.cancel_processing/1 is called. The variant will not retry; requeue the asset-scoped repair with Rindle.requeue_variants/2 if needed. Broad preset or profile drift stays on `mix rindle.regenerate_variants`.
             """)
  end

  test "renders exact message for range_unparseable" do
    error =
      struct!(Rindle.Error,
        action: :serve_range,
        reason: {:range_unparseable, %{header: "bytes=abc-xyz"}}
      )

    assert Rindle.Error.message(error) ==
             exact("""
             Range header "bytes=abc-xyz" could not be parsed.

             Rindle falls back to a `200 OK` full-body response for malformed or multi-range requests by default. Fix the caller's Range header or enable strict parsing with:
               config :rindle, :strict_range_parsing, true
             """)
  end

  test "renders exact message for tus_url_signature_invalid" do
    error =
      struct!(Rindle.Error, action: :resume_upload, reason: :tus_url_signature_invalid)

    assert Rindle.Error.message(error) ==
             exact("""
             The tus upload URL signature is invalid.

             To fix:
               1. Treat the tus `Location` URL as opaque and reuse it byte-for-byte.
               2. Do not trim, rebuild, or append client-side path segments to the signed URL.
               3. If the URL was copied, cached, or mutated, start a new tus upload and use the fresh location.
             """)
  end

  defp exact(text), do: String.trim_trailing(text)
end
