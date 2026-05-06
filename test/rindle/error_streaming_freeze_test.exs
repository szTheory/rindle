defmodule Rindle.ErrorStreamingFreezeTest do
  use ExUnit.Case, async: true

  @public_streaming_reasons [
    :provider_asset_not_ready,
    :provider_webhook_invalid,
    :provider_sync_failed,
    :provider_quota_exceeded,
    :streaming_provider_requires_asset_struct
  ]

  test "locks the five public streaming reason atoms" do
    assert @public_streaming_reasons == [
             :provider_asset_not_ready,
             :provider_webhook_invalid,
             :provider_sync_failed,
             :provider_quota_exceeded,
             :streaming_provider_requires_asset_struct
           ]
  end

  test "renders exact messages for the five new streaming reason atoms" do
    expected_messages = %{
      provider_asset_not_ready:
        exact("""
        The provider asset is not yet ready for playback.

        Check `mix rindle.runtime_status --provider-stuck` to see whether ingest is in flight or stuck. If the row is in :uploading or :processing, wait for the provider webhook to confirm readiness. If the row stays in :processing past the configured threshold, inspect Oban for the `MuxIngestVariant` job (Phase 34) and consider re-ingest via `Rindle.regenerate_variants/2`.
        """),
      provider_webhook_invalid:
        exact("""
        A streaming-provider webhook payload failed signature verification or replay-window validation.

        To fix:
          1. Confirm the webhook secret matches the value configured in the provider dashboard. If you recently rotated, the new secret should be the FIRST entry in `:webhook_secrets`.
          2. Check the request timestamp tolerance — Mux's default is 300s; signed payloads outside this window are rejected as replays.
          3. Inspect telemetry under `[:rindle, :provider, :webhook, :rejected]` to see whether the failure was a signature mismatch or a replay-window failure.

        The 400 response is intentional and is identical for signature and replay failures (operators distinguish via telemetry metadata, not error variants).
        """),
      provider_sync_failed:
        exact("""
        A `media_provider_assets` row is in `:errored` state. The provider asset cannot be served.

        To fix:
          1. Inspect `last_sync_error` on the row to see the provider-side cause.
          2. If the original source is recoverable, re-ingest via `Rindle.regenerate_variants/2` (the FSM allows `:errored → :processing` re-entry).
          3. If the asset should be retired, delete it via the provider dashboard and then `Rindle.detach/1` the local row.

        Run `mix rindle.runtime_status --provider-stuck` for a list of errored rows.
        """),
      provider_quota_exceeded:
        exact("""
        The streaming provider rejected a request due to quota or rate-limit caps.

        To fix:
          1. Check the provider dashboard for current quota usage and limits (Mux: storage, encoding minutes, delivery minutes).
          2. Back off automatic retries — Oban will requeue but the underlying limit will not clear until the quota window rolls.
          3. If you are scaling intentionally, contact the provider to raise limits before retrying.

        This atom is the bare-atom v1.6 surface. Provider/retry-after detail can be inspected from telemetry metadata.
        """),
      streaming_provider_requires_asset_struct:
        exact("""
        `Rindle.Delivery.streaming_url/3` was called with a binary storage key on a profile that has streaming configured.

        To fix: pass the asset struct (`%Rindle.Domain.MediaAsset{}` or equivalent map with `:id`) instead of the storage key. Streaming dispatch needs the asset's binary_id to look up the matching `media_provider_assets` row.

        For profiles that have NOT opted into streaming, the binary-key form continues to work and falls through to v1.4 progressive playback.
        """)
    }

    for {reason, expected} <- expected_messages do
      error = struct!(Rindle.Error, action: :test_contract, reason: reason)
      assert Rindle.Error.message(error) == expected
    end
  end

  defp exact(text), do: String.trim_trailing(text)
end
