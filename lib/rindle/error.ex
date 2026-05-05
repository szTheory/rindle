defmodule Rindle.Error do
  @moduledoc """
  Exception raised by bang variants on the `Rindle` facade when an
  operation fails for a non-changeset reason.

  Fields:

    * `:action` — atom identifying the failing operation
      (`:attach`, `:detach`, `:upload`, `:url`, `:variant_url`)
    * `:reason` — the underlying error term returned by the non-bang variant

  For changeset validation failures, bangs raise `Ecto.InvalidChangesetError`
  instead. For storage adapter exceptions, bangs re-raise the original
  exception directly.

  ## Examples

      iex> try do
      ...>   raise Rindle.Error, action: :attach, reason: :not_found
      ...> rescue
      ...>   e in Rindle.Error -> Exception.message(e)
      ...> end
      "could not attach: not found"

  """

  defexception [:action, :reason]

  @typedoc "A `Rindle.Error` exception struct."
  @type t :: %__MODULE__{action: atom(), reason: term()}

  @doc """
  Returns a human-readable message describing the failure.

  Branches on three common reason shapes:

    * `:not_found` — `"could not <action>: not found"`
    * `{:quarantine, why}` — `"could not <action>: upload quarantined (<inspect why>)"`
    * AV-facing reason atoms — exact fix-oriented guidance for the locked
      public vocabulary
    * any other — `"could not <action>: <inspect reason>"`

  """
  @impl true
  @spec message(t()) :: String.t()
  def message(%{
        reason:
          {:processor_capability_missing,
           %{
             processor: processor,
             required: required,
             declared: declared,
             variant: variant,
             profile: profile
           }}
      }) do
    """
    Variant #{inspect(variant)} in #{inspect(profile)} requires processor capability #{inspect(required)}, but #{inspect(processor)} only declares: #{inspect(declared)}.

    To fix:
      1. Confirm FFmpeg is installed and on PATH (`which ffmpeg`).
      2. Use a processor that declares #{inspect(required)}.
      3. Or remove #{inspect(variant)} from the profile's variants/0.

    Run `mix rindle.doctor #{inspect(profile)}` to verify.
    """
    |> String.trim()
  end

  def message(%{reason: :processor_capability_missing}) do
    """
    Variant processing requires a processor capability that is not available.

    To fix:
      1. Confirm FFmpeg is installed and on PATH (`which ffmpeg`).
      2. Use a processor that declares the required AV capability.
      3. Or remove the incompatible AV variant from the profile.

    Run `mix rindle.doctor` to verify.
    """
    |> String.trim()
  end

  def message(%{reason: {:ffmpeg_not_found, %{searched_path: searched_path}}}) do
    """
    FFmpeg executable not found on PATH.

    Rindle's video and audio processors require FFmpeg ≥ 4.0. To fix:
      • macOS:        brew install ffmpeg
      • Debian/Ubuntu: apt-get install ffmpeg
      • Alpine/Docker: apk add ffmpeg

    If FFmpeg is installed elsewhere, set:
      config :rindle, :ffmpeg_path, "/usr/local/bin/ffmpeg"

    PATH checked: #{searched_path}
    """
    |> String.trim()
  end

  def message(%{reason: :ffmpeg_not_found}) do
    """
    FFmpeg executable not found on PATH.

    Rindle's video and audio processors require FFmpeg ≥ 4.0. To fix:
      • macOS:        brew install ffmpeg
      • Debian/Ubuntu: apt-get install ffmpeg
      • Alpine/Docker: apk add ffmpeg

    If FFmpeg is installed elsewhere, set:
      config :rindle, :ffmpeg_path, "/usr/local/bin/ffmpeg"
    """
    |> String.trim()
  end

  def message(%{
        reason: {:capability_drift, %{adapter: adapter, previously: previously, missing: missing}}
      }) do
    """
    Storage adapter #{inspect(adapter)} previously advertised capability #{format_capability_list(missing)} but now does not.

    This may indicate:
      • The adapter is misconfigured (e.g. credentials lost permission to initiate multipart uploads).
      • The provider has changed (e.g. Cloudflare R2 multipart compatibility is provider-version-sensitive — see Rindle's R2 docs).
      • A code change removed the capability.

    Previously declared capabilities: #{inspect(previously)}

    To proceed, either:
      1. Restore the adapter's capability (check provider config / credentials).
      2. Migrate existing in-flight multipart uploads with `mix rindle.cleanup --multipart-orphans`.
      3. Drop the capability requirement from your profile.
    """
    |> String.trim()
  end

  def message(%{reason: :capability_drift}) do
    """
    A previously available Rindle capability is no longer advertised by the current runtime.

    To proceed, either:
      1. Restore the missing capability in the adapter or processor configuration.
      2. Migrate any in-flight work that depended on it.
      3. Drop the capability requirement from your profile.
    """
    |> String.trim()
  end

  def message(%{reason: {:variant_source_not_found, %{key: key, asset_id: asset_id}}}) do
    """
    Source file for asset #{asset_id} (storage key "#{key}") could not be downloaded from storage.

    Likely causes:
      • The asset was purged before variant processing started (race condition between detach and the variant worker).
      • The storage adapter credentials lost permission to read the key.
      • The bucket policy blocks GET on this prefix.

    Check Oban dashboard for the original ProcessVariant job; if it has been retrying, the asset may be in a `quarantined` state.
    """
    |> String.trim()
  end

  def message(%{reason: :variant_source_not_found}) do
    """
    Source media could not be downloaded from storage before variant processing started.

    Check that the asset still exists, the storage adapter can read it, and the original ProcessVariant job is not racing with a purge or detach.
    """
    |> String.trim()
  end

  def message(%{
        reason: {:unsupported_codec, %{codec: codec, processor: processor, supported: supported}}
      }) do
    """
    Variant requires codec #{inspect(codec)} but #{inspect(processor)} only supports: #{inspect(supported)}.

    AV1 transcoding requires libaom or SVT-AV1 in your FFmpeg build:
      ffmpeg -codecs 2>&1 | grep av1

    If your FFmpeg supports #{codec} but Rindle still rejects it, file an issue at https://github.com/szTheory/rindle/issues with `ffmpeg -version` output.
    """
    |> String.trim()
  end

  def message(%{reason: :unsupported_codec}) do
    """
    The requested audio or video codec is not supported by the current Rindle processor configuration.

    Check your FFmpeg build and the variant's declared codec requirements before retrying.
    """
    |> String.trim()
  end

  def message(%{
        reason: {:streaming_not_configured, %{profile: profile, requested_kind: requested_kind}}
      }) do
    """
    #{inspect(profile)} is not configured with a streaming provider, but #{inspect(requested_kind)} streaming was requested.

    In Rindle v1.4, only :progressive (signed-redirect MP4/WebM) is supported out of the box. To use HLS:
      1. Wait for the Rindle.Streaming.Mux or Rindle.Streaming.Cloudflare adapter (post-v1.4).
      2. Or configure your profile with a custom streaming provider:

         use Rindle.Profile,
           storage:   Rindle.Storage.S3,
           streaming: MyApp.MyStreamingProvider

    Until then, callers should use Rindle.Delivery.url/3 for progressive playback.
    """
    |> String.trim()
  end

  def message(%{reason: :streaming_not_configured}) do
    """
    Streaming playback was requested, but the current profile is not configured for that delivery path.

    Until a streaming provider is configured, callers should use `Rindle.Delivery.url/3` for progressive playback.
    """
    |> String.trim()
  end

  def message(%{
        reason:
          {:variant_processing_cancelled,
           %{variant_id: variant_id, cancelled_at: cancelled_at, reason: reason}}
      }) do
    """
    Variant #{variant_id} processing was cancelled (reason: #{reason}, at: #{cancelled_at}).

    This is expected when Rindle.cancel_processing/1 is called. The variant will not retry; re-trigger with Rindle.regenerate_variant/2 if needed.
    """
    |> String.trim()
  end

  def message(%{reason: :variant_processing_cancelled}) do
    """
    Variant processing was cancelled.

    This is expected when Rindle.cancel_processing/1 is called. The variant will not retry automatically; re-trigger it explicitly if needed.
    """
    |> String.trim()
  end

  def message(%{reason: {:range_unparseable, %{header: header}}}) do
    """
    Range header "#{header}" could not be parsed.

    Rindle falls back to a `200 OK` full-body response for malformed or multi-range requests by default. Fix the caller's Range header or enable strict parsing with:
      config :rindle, :strict_range_parsing, true
    """
    |> String.trim()
  end

  def message(%{reason: :range_unparseable}) do
    """
    The HTTP Range header could not be parsed.

    Rindle falls back to a `200 OK` full-body response for malformed ranges by default. Fix the caller's Range header or enable strict parsing if you need hard failures.
    """
    |> String.trim()
  end

  def message(%{action: action, reason: :not_found}) do
    "could not #{action}: not found"
  end

  def message(%{action: action, reason: {:quarantine, why}}) do
    "could not #{action}: upload quarantined (#{inspect(why)})"
  end

  def message(%{action: action, reason: reason}) do
    "could not #{action}: #{inspect(reason)}"
  end

  defp format_capability_list([single]), do: inspect(single)
  defp format_capability_list(capabilities), do: inspect(capabilities)
end
