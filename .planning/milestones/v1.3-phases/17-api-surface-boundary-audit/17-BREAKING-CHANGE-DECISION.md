# Phase 17 Breaking-Change Decision

## Locked Public Allowlist

Phase 17 locks the adopter-facing API around the facade-first path and the
explicit advanced modules from D-03.

- `Rindle` is the primary public facade.
- `Rindle.Profile` is the first-tier configuration entrypoint.
- `Rindle.Upload.Broker` remains public for transport-specific direct-upload
  steps such as `sign_url/1` and multipart flows.
- `Rindle.Delivery`, `Rindle.Storage`, `Rindle.Storage.Local`,
  `Rindle.Storage.S3`, `Rindle.Authorizer`, `Rindle.Analyzer`,
  `Rindle.Scanner`, `Rindle.Processor`, `Rindle.LiveView`, `Rindle.HTML`,
  `Mix.Tasks.Rindle.*`, `Rindle.Workers.AbortIncompleteUploads`, and
  `Rindle.Workers.CleanupOrphans` remain public per the locked context.

## D-03 Override: Storage Adapter Visibility

Older generic requirement wording implied that adapter modules might be hidden.
That is not the contract for Phase 17.

D-03 overrides that older wording and keeps `Rindle.Storage.Local` and
`Rindle.Storage.S3` public because adopters are expected to reference storage
adapters directly in profile definitions and runtime configuration.

## Additive 0.1.x Compatibility Posture

Phase 17 ships additive-compatible cleanup on `0.1.x` only.

- `Rindle.verify_completion/2` is now the preferred direct-upload verification
  name.
- `Rindle.verify_upload/2` remains callable on `0.1.x` as a documented legacy
  compatibility shim that points adopters to `verify_completion/2`.
- `Rindle.complete_multipart_upload/3` stays unchanged because it names the
  transport-specific multipart completion step rather than the direct-upload
  verification boundary.
- `Rindle.log_variant_processing_failure/3` remains callable on `0.1.x`, but
  it is no longer part of the documented public facade. Its implementation now
  lives behind the hidden `Rindle.Internal.VariantFailureLogger` module.

## Explicit Deferrals To v0.2.0

Phase 17 does not remove public names on the published `0.1.x` line.

The following changes are explicitly deferred to `v0.2.0` or later if they are
still warranted after Phase 18 documentation and downstream adopter feedback:

- Remove `verify_upload/2` after the `verify_completion/2` naming transition is
  established.
- Remove the `log_variant_processing_failure/3` compatibility shim if a better
  public observability extension point replaces it.
- Revisit any additional facade tightening only on a deliberate breaking-change
  release boundary.
