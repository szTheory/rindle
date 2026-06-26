# Storage Capabilities

Rindle exposes storage capabilities as an explicit adapter contract so adopters
can tell which upload and delivery flows are expected to work before wiring a
profile to a backend. Unsupported flows fail with tagged tuples instead of
falling back silently.

This guide is the canonical capability reference. Other guides link
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
| `:resumable_upload` | The adapter can drive a resumable upload lifecycle instead of a single-shot direct PUT. |
| `:resumable_upload_session` | The adapter can create and continue provider-owned resumable upload sessions. |

These atoms are shipped vocabulary, but adapter-specific. Rindle does not imply
that every storage backend supports them.

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
- A resumable path against an adapter that does not advertise it remains
  intentionally explicit:
  `{:error, {:upload_unsupported, :resumable_upload}}`.

These failures are part of the adopter-facing contract. Rindle does not guess,
downgrade, or silently swap in another flow.

## Provider Matrix

The table below describes the current shipped posture for adapters and common
provider choices.

| Backend / provider | Runtime seam | Expected capabilities today | Proof posture | Notes |
| ------------------ | ------------ | --------------------------- | ------------- | ----- |
| Local filesystem | `Rindle.Storage.Local` | `[:local, :presigned_put]` | Automated in the default test suite | Presigned PUT is a local-development parity shim, not a remote-object-store claim. `Rindle.Storage.Local` does not advertise `:resumable_upload` or `:resumable_upload_session`. |
| MinIO | `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` | Automated in default CI and local integration lanes | This is the always-on real S3-compatible proof for direct PUT, multipart upload, metadata verification, and signed delivery URL generation. `Rindle.Storage.S3` does not advertise the resumable capability family. |
| Generic S3-compatible provider | `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` | Expected by contract; not proven against every vendor in default CI | Rindle uses the shipped S3 adapter seam. Provider-specific behavior beyond that seam should be validated in adopter-owned environments. |
| Cloudflare R2 | `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` when the provider honors the shipped S3-compatible operations | Documented compatibility target; adopters validate vendor behavior in their own environments | Uses the shipped S3 adapter seam (no separate R2 adapter). MinIO is the automated CI proof lane. |
| Google Cloud Storage | `Rindle.Storage.GCS` | `[:head, :signed_url, :resumable_upload, :resumable_upload_session]` | Live GCS proof exists in the GCS test lanes; adopters still own bucket and browser wiring | `Rindle.Storage.GCS` is the shipped adapter that honestly advertises the resumable capability family. See [Storage (GCS)](storage_gcs.html) for runtime wiring, CORS, and session hygiene. |

## Capability boundaries

Rindle separates "documented contract" from "what the repo proves by default":

- MinIO is the default real-provider proof lane in CI for the shipped S3
  adapter contract.
- Cloudflare R2 is documented as a compatibility target through the shipped
  `Rindle.Storage.S3` seam.
- Default CI proves the shipped S3-style contract against MinIO, not against
  every vendor-branded backend.
- Generic S3 providers are expected to match the shipped S3 adapter contract,
  but adopters should still validate vendor-specific behavior in their own
  environments before rollout.

That distinction improves auditability, not marketing claims.
This guide does not imply provider-specific live R2 proof in CI.

## Adapter Honesty

Capability claims are adapter-specific, not marketing-wide:

- `Rindle.Storage.GCS` advertises `:resumable_upload` and `:resumable_upload_session`
- `Rindle.Storage.S3` advertises neither resumable capability today
- `Rindle.Storage.Local` advertises neither resumable capability today
- custom adapters may honestly advertise either, both, or neither depending on
  what they actually implement

Rindle does not silently downgrade resumable requests into presigned PUT.

## Cloudflare R2 Boundary

Cloudflare R2 is documented here as an S3-compatible provider path through the
existing `Rindle.Storage.S3` adapter. The supported Rindle contract is:

- Direct upload via presigned PUT.
- Metadata verification via `head/2`.
- Signed delivery URL generation when `:signed_url` is advertised.
- S3-style multipart upload when `:multipart_upload` is advertised.

This guide does not claim:

- A bespoke `Rindle.Storage.R2` adapter.
- HTML form POST uploads as part of the shipped contract.
- Provider-specific live R2 coverage in CI.
- A shipped resumable-upload API through the S3 adapter.

## Resumable Boundary

Resumable upload is shipped where the adapter advertises it. Today that means
`Rindle.Storage.GCS`.

That does not mean:

- every adapter supports resumable upload
- Rindle falls back automatically from resumable upload to presigned PUT
- S3-compatible providers inherit resumable semantics through `Rindle.Storage.S3`
- Rindle ships tus or a provider-agnostic resumable abstraction beyond the
  honest capability contract

## Public (browser-facing) delivery endpoint (S3)

By default `Rindle.Storage.S3` signs browser-facing presigned URLs (signed delivery
GET, presigned PUT, presigned multipart upload-part) using the same `:ex_aws, :s3`
endpoint it uses for server-side operations. When the endpoint the browser can reach
differs from the cluster-internal endpoint — split-horizon DNS, a public/CDN/edge
host, or a dev Docker setup where the server talks to `minio:9000` in-network but the
browser must use a published `localhost:<port>` — set a `:public_endpoint` for the
adapter:

```elixir
config :rindle, Rindle.Storage.S3,
  bucket: "my-bucket",
  public_endpoint: [scheme: "https://", host: "cdn.example.com", port: 443]
```

- Only `:scheme`, `:host`, and `:port` are read.
- It applies **only** to presigned URL signing; server-side `store`/`download`/`head`/
  multipart keep using the `:ex_aws, :s3` endpoint.
- Because the S3 signature binds the `host` header (`SignedHeaders=host`), the
  configured public host MUST be exactly the host the browser requests.
- Leave it unset for identical pre-existing behaviour.

The Cohort Docker demo wires this from `RINDLE_MINIO_PUBLIC_URL`; see
`guides/docker_demo_dx.md` ("Split-horizon S3 endpoint").
