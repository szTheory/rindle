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

  def message(%{reason: :provider_asset_not_ready}) do
    """
    The provider asset is not yet ready for playback.

    Check `mix rindle.runtime_status --provider-stuck` to see whether ingest is in flight or stuck. If the row is in :uploading or :processing, wait for the provider webhook to confirm readiness. If the row stays in :processing past the configured threshold, inspect Oban for the `MuxIngestVariant` job (Phase 34) and consider re-ingest via `Rindle.regenerate_variants/2`.
    """
    |> String.trim()
  end

  def message(%{reason: :provider_webhook_invalid}) do
    """
    A streaming-provider webhook payload failed signature verification or replay-window validation.

    To fix:
      1. Confirm the webhook secret matches the value configured in the provider dashboard. If you recently rotated, the new secret should be the FIRST entry in `:webhook_secrets`.
      2. Check the request timestamp tolerance — Mux's default is 300s; signed payloads outside this window are rejected as replays.
      3. Inspect telemetry under `[:rindle, :provider, :webhook, :rejected]` to see whether the failure was a signature mismatch or a replay-window failure.

    The 400 response is intentional and is identical for signature and replay failures (operators distinguish via telemetry metadata, not error variants).
    """
    |> String.trim()
  end

  def message(%{reason: :provider_sync_failed}) do
    """
    A `media_provider_assets` row is in `:errored` state. The provider asset cannot be served.

    To fix:
      1. Inspect `last_sync_error` on the row to see the provider-side cause.
      2. If the original source is recoverable, re-ingest via `Rindle.regenerate_variants/2` (the FSM allows `:errored → :processing` re-entry).
      3. If the asset should be retired, delete it via the provider dashboard and then `Rindle.detach/1` the local row.

    Run `mix rindle.runtime_status --provider-stuck` for a list of errored rows.
    """
    |> String.trim()
  end

  def message(%{reason: :provider_quota_exceeded}) do
    """
    The streaming provider rejected a request due to quota or rate-limit caps.

    To fix:
      1. Check the provider dashboard for current quota usage and limits (Mux: storage, encoding minutes, delivery minutes).
      2. Back off automatic retries — Oban will requeue but the underlying limit will not clear until the quota window rolls.
      3. If you are scaling intentionally, contact the provider to raise limits before retrying.

    This atom is the bare-atom v1.6 surface. Provider/retry-after detail can be inspected from telemetry metadata.
    """
    |> String.trim()
  end

  def message(%{reason: :streaming_provider_requires_asset_struct}) do
    """
    `Rindle.Delivery.streaming_url/3` was called with a binary storage key on a profile that has streaming configured.

    To fix: pass the asset struct (`%Rindle.Domain.MediaAsset{}` or equivalent map with `:id`) instead of the storage key. Streaming dispatch needs the asset's binary_id to look up the matching `media_provider_assets` row.

    For profiles that have NOT opted into streaming, the binary-key form continues to work and falls through to v1.4 progressive playback.
    """
    |> String.trim()
  end

  def message(%{reason: {:not_cancellable, %{reason: :state, state: state}}}) do
    """
    Direct upload cancel is not allowed while the provider row is in state #{inspect(state)}.

    To fix:
      1. Check the asset's provider row state — only `pending` and `uploading` are cancellable.
      2. If ingest already advanced to processing or ready, wait for completion or use provider-dashboard retirement instead of cancel.
      3. Re-run `Rindle.Streaming.cancel_direct_upload/1` only after confirming the row is still in a cancellable state.
    """
    |> String.trim()
  end

  def message(%{reason: {:not_cancellable, %{reason: :ingest_mode, ingest_mode: mode}}}) do
    """
    Direct upload cancel applies only to `direct_creator_upload` ingest (current ingest_mode: #{inspect(mode)}).

    To fix:
      1. Confirm the profile uses `ingest_mode: :direct_creator_upload` in its streaming delivery config.
      2. For server-push ingest, use the provider dashboard or asset retirement path instead of direct-upload cancel.
    """
    |> String.trim()
  end

  def message(%{reason: {:not_cancellable, %{reason: :missing_upload_id}}}) do
    """
    This direct upload row has no persisted provider upload handle (pre-v1.13 rows are not backfilled).

    To fix:
      1. Create a new direct upload via `Rindle.Streaming.create_direct_upload/2` if you still need browser upload.
      2. For legacy rows, cancel via the provider dashboard and detach locally if the asset should be retired.
    """
    |> String.trim()
  end

  def message(%{reason: :empty_batch}) do
    """
    Batch owner erasure requires at least one owner struct.

    To fix:
      1. Pass a non-empty list of owner structs (same shape as preview_owner_erasure/2).
      2. For single-owner erasure, use Rindle.preview_owner_erasure/2 or Rindle.erase_owner/2 instead.
    """
    |> String.trim()
  end

  def message(%{reason: {:batch_too_large, %{requested: requested, max: max}}}) do
    """
    Batch owner erasure exceeds the configured owner limit (requested: #{requested}, max: #{max}).

    To fix:
      1. Split the batch into smaller chunks at or below the limit.
      2. Pass max_owners: N in opts to raise the per-call limit when your ops policy allows it.
      3. Optionally set config :rindle, :max_batch_erasure_owners for a host-app default.
    """
    |> String.trim()
  end

  def message(%{
        reason: {:batch_owner_failed, %{owner: {owner_type, owner_id}, partial_report: partial}}
      }) do
    completed = length(partial.owners)

    """
    Batch owner erasure stopped because owner #{owner_type}:#{owner_id} failed after #{completed} owner(s) completed successfully.

    Completed owners remain committed. Inspect `partial_report` on the error reason for their reports, fix the failing owner, and rerun the batch for remaining owners.

    For single-owner debugging, use preview_owner_erasure/2 or erase_owner/2.
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

    This is expected when Rindle.cancel_processing/1 is called. The variant will not retry; requeue the asset-scoped repair with Rindle.requeue_variants/2 if needed. Broad preset or profile drift stays on `mix rindle.regenerate_variants`.
    """
    |> String.trim()
  end

  def message(%{reason: :variant_processing_cancelled}) do
    """
    Variant processing was cancelled.

    This is expected when Rindle.cancel_processing/1 is called. The variant will not retry automatically; use `Rindle.requeue_variants/2` for asset-scoped repair if needed.
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

  def message(%{reason: :tus_session_not_found}) do
    """
    The tus upload session could not be found.

    To fix:
      1. Confirm the client is resuming with the exact `Location` URL returned by the original tus `POST`.
      2. If the upload was deleted or expired, create a fresh tus upload instead of retrying the old URL.
      3. If you use `tus-js-client`, keep `removeFingerprintOnSuccess: true` enabled; modern `@uppy/tus` resumes and clears stale fingerprints automatically.
    """
    |> String.trim()
  end

  def message(%{reason: :tus_session_expired}) do
    """
    The tus upload session has expired.

    To fix:
      1. Start a new tus upload and discard the expired URL.
      2. Keep client retries shorter than the server-side upload TTL.
      3. If long pauses are expected, increase the upload-session TTL in your runtime config before retrying.
    """
    |> String.trim()
  end

  def message(%{reason: :tus_offset_conflict}) do
    """
    The tus client resumed from the wrong byte offset.

    To fix:
      1. Let the client issue `HEAD` and trust the returned `Upload-Offset` before resuming.
      2. Avoid mutating or replaying old partial chunks manually.
      3. If you are using tus-js-client or @uppy/tus, keep automatic resume enabled and do not override the offset flow.
    """
    |> String.trim()
  end

  def message(%{reason: :tus_size_exceeded}) do
    """
    The tus upload exceeded the declared or allowed size.

    To fix:
      1. Keep the client's `Upload-Length` aligned with the real file size.
      2. Increase the server-side tus max size if this file should be accepted.
      3. Start a fresh upload after correcting the file or size limit; the current URL cannot be repaired in place.
    """
    |> String.trim()
  end

  def message(%{reason: :tus_url_signature_invalid}) do
    """
    The tus upload URL signature is invalid.

    To fix:
      1. Treat the tus `Location` URL as opaque and reuse it byte-for-byte.
      2. Do not trim, rebuild, or append client-side path segments to the signed URL.
      3. If the URL was copied, cached, or mutated, start a new tus upload and use the fresh location.
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
