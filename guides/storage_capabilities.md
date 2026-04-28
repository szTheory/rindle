# Storage Capabilities

Rindle exposes storage capabilities as an explicit adapter contract so adopters
can tell which upload and delivery flows are expected to work before wiring a
profile to a backend. The runtime vocabulary lives in
`Rindle.Storage.Capabilities`; unsupported flows fail with tagged tuples instead
of falling back silently.

This guide is the canonical capability reference for v1.1. Other guides link
here instead of repeating provider matrices inline.

## Shipped Capability Vocabulary

Rindle currently knows these capability atoms:

| Capability | Meaning today |
| ---------- | ------------- |
| `:presigned_put` | The adapter can mint a direct-upload URL for a single-object PUT. |
| `:multipart_upload` | The adapter can initiate, sign parts for, complete, and abort an S3-style multipart upload. |
| `:signed_url` | The adapter can mint a time-limited signed delivery URL for private delivery. |
| `:head` | The adapter can read remote object metadata for verification and cleanup. |
| `:local` | The adapter is backed by local filesystem semantics. |
| `:resumable_upload` | Reserved for a future resumable-upload family. Not shipped in v1.1. |
| `:resumable_upload_session` | Reserved for a future resumable-upload session family. Not shipped in v1.1. |

The reserved resumable atoms are additive placeholders only. Phase 8 does not
ship a GCS adapter, a public resumable API, or hidden resumable behavior under
the existing direct-upload entrypoints.

## Unsupported Flow Contract

Rindle uses tagged unsupported tuples when a flow requires a capability the
adapter does not advertise:

| Flow family | Tagged error |
| ----------- | ------------ |
| Upload | `{:error, {:upload_unsupported, capability}}` |
| Delivery | `{:error, {:delivery_unsupported, capability}}` |

Examples:

- `Rindle.Storage.Local` returns `{:error, {:upload_unsupported, :multipart_upload}}`
  for multipart entrypoints.
- Private delivery against an adapter without `:signed_url` returns
  `{:error, {:delivery_unsupported, :signed_url}}`.
- The reserved future resumable path is intentionally explicit today:
  `{:error, {:upload_unsupported, :resumable_upload}}`.

These failures are part of the adopter-facing contract. Rindle does not guess,
downgrade, or silently swap in another flow.

## Provider Matrix

The table below describes the current v1.1 posture for adapters and common
provider choices.

| Backend / provider | Runtime seam | Expected capabilities today | Proof posture | Notes |
| ------------------ | ------------ | --------------------------- | ------------- | ----- |
| Local filesystem | `Rindle.Storage.Local` | `[:local, :presigned_put]` | Automated in the default test suite | Presigned PUT is a local-development parity shim, not a remote-object-store claim. Multipart and signed delivery fail explicitly with tagged unsupported tuples. |
| MinIO | `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` | Automated in default CI and local integration lanes | This is the always-on real S3-compatible proof for direct PUT, multipart upload, metadata verification, and signed delivery URL generation. |
| Generic S3-compatible provider | `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` | Expected by contract; not proven against every vendor in default CI | Rindle uses the shipped S3 adapter seam. Provider-specific behavior beyond that seam should be validated in adopter-owned environments. |
| Cloudflare R2 | `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` when the provider honors the shipped S3-compatible operations | Opt-in/manual contract lane via `mix test test/rindle/storage/r2_test.exs --include r2` | Phase 8 does not add a bespoke R2 adapter and does not require live R2 credentials in default CI. The repo only claims the current shipped S3-style operations it can exercise through the existing adapter seam. |

## Proof Boundaries

Rindle separates "documented contract" from "what the repo proves by default":

- MinIO is the default real-provider proof lane in CI for the shipped S3
  adapter contract.
- Cloudflare R2 has an executable opt-in/manual lane in
  `test/rindle/storage/r2_test.exs`.
- Default CI does not include live R2 because the repo does not ship R2
  credentials.
- Generic S3 providers are expected to match the shipped S3 adapter contract,
  but adopters should still validate vendor-specific behavior in their own
  environments before rollout.

That distinction matters: Phase 8 improves auditability, not marketing claims.
This guide does not imply live R2 proof in default CI.

## Cloudflare R2 Boundary

Cloudflare R2 is documented here as an S3-compatible provider path through the
existing `Rindle.Storage.S3` adapter. In v1.1, the supported Rindle contract is:

- Direct upload via presigned PUT.
- Metadata verification via `head/2`.
- Signed delivery URL generation when `:signed_url` is advertised.
- S3-style multipart upload when `:multipart_upload` is advertised.

This guide does not claim:

- A bespoke `Rindle.Storage.R2` adapter.
- HTML form POST uploads as part of the shipped contract.
- Live R2 coverage in default CI.
- A shipped resumable-upload API.

## Opt-In R2 Manual Verification

To run the live R2 contract lane, export:

- `RINDLE_R2_URL`
- `RINDLE_R2_ACCESS_KEY_ID`
- `RINDLE_R2_SECRET_ACCESS_KEY`
- `RINDLE_R2_BUCKET`
- `RINDLE_R2_REGION` (optional, defaults to `auto`)

Then run:

```bash
mix test test/rindle/storage/r2_test.exs --include r2
```

When credentials are present, that lane verifies only the current shipped
contract:

- Presigned PUT upload round-trip plus `head/2`
- Signed URL generation when the adapter advertises `:signed_url`
- Multipart upload round-trip when the adapter advertises `:multipart_upload`
- Explicit reserved-capability failure via
  `{:error, {:upload_unsupported, :resumable_upload}}`

When credentials are absent, the lane skips with an explicit message. That is
intentional and keeps R2 proof opt-in/manual instead of pretending the repo has
default-CI coverage it does not have.

## Future Resumable Uploads

The reserved resumable atoms exist so future work can add a distinct resumable
capability family without breaking the current contract. That future work is
expected to be additive:

- New adapter behavior for resumable session creation and continuation
- New proof lanes for providers that use resumable semantics
- New public API only when there is a verified adapter behind it

Until then, resumable flows remain unsupported and should fail loudly through
the existing tagged tuple contract.
