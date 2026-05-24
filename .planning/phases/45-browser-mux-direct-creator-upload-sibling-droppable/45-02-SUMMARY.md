# Plan 45-02 Summary

## Completed

- Added `Rindle.Streaming.create_direct_upload/2` as the streaming-owned public
  direct-upload entrypoint.
- The entrypoint now creates the local `MediaAsset` + `MediaProviderAsset`
  records, stamps a generated passthrough token, and returns only
  `%{upload_url, asset_id}`.
- Upgraded `Rindle.Workers.IngestProviderWebhook` so
  `video.upload.asset_created` links rows by `mux_passthrough`, stamps
  `provider_asset_id`, advances `uploading -> processing`, and broadcasts
  `:provider_asset_created`.
- Preserved the existing `video.asset.ready` follow-up path so
  `:provider_asset_ready` still fires later for the same asset.

## Verification

- `mix test test/rindle/streaming/create_direct_upload_test.exs test/rindle/workers/ingest_provider_webhook_test.exs test/rindle/delivery/streaming_dispatch_test.exs test/rindle/streaming/direct_upload_flow_test.exs`

## Notes

- Duplicate upload-created deliveries remain idempotent.
- No public response or PubSub payload leaks raw Mux ids.
