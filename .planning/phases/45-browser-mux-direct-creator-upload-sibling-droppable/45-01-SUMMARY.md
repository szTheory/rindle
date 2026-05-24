# Plan 45-01 Summary

## Completed

- Added `media_provider_assets.mux_passthrough` with a partial unique index on
  `(provider_name, mux_passthrough)`.
- Extended `Rindle.Domain.MediaProviderAsset` to cast/redact `mux_passthrough`
  and enforce the new unique constraint.
- Added `create_upload/1` to the Mux HTTP client boundary and implemented
  `Rindle.Streaming.Provider.Mux.create_direct_upload/2`.
- Updated the Mux adapter capability set to advertise
  `:direct_creator_upload`.

## Verification

- `mix test test/rindle/streaming/provider/mux/mux_test.exs test/rindle/streaming/capabilities_test.exs test/rindle/domain/media_provider_asset_test.exs`

## Notes

- The direct-upload adapter returns the locked shape
  `%{upload_url, upload_id, provider_asset_id: nil}`.
- `mux_passthrough` is persisted for webhook correlation but redacted in
  `Inspect`.
