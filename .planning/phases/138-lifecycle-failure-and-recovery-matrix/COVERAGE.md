# API Coverage — Shipped Mux adapter and S3/tus consumer boundaries

Phase 138 exercises existing shipped integrations for six bounded recovery cases. This matrix enumerates the shipped external capability surface relevant to the packaged host. Opt-outs preserve the explicit Phase 138 boundary; they do not imply unsupported library behavior.

| capability | decision | reason |
|---|---|---|
| Mux capabilities discovery | INTEGRATE | Host confirms shipped adapter and optional SDK activation. |
| Mux create_asset | INTEGRATE | Local SDK HTTP fixture records exactly one outbound create. |
| Mux get_asset | INTEGRATE | Ordinary provider sync and convergence observe local fixture state. |
| Mux verify_webhook | INTEGRATE | Signed raw-body HTTP ingress is a required recovery path. |
| Mux create_direct_upload | OPT-OUT | The finite provider case uses source ingest, not a direct provider upload. |
| Mux delete_asset | OPT-OUT | Provider fixture residue is inventoried; provider deletion is not a RECOV event-order requirement. |
| Mux cancel_direct_upload | OPT-OUT | No direct provider upload is created in this matrix. |
| Mux signed_playback_url | OPT-OUT | Playback token issuance is outside failure/recovery matrix scope. |
| Mux create_asset_with_retry_hint | OPT-OUT | Existing source-ingest path supplies the one outbound create; retry hints are not a matrix claim. |
| S3 store and presigned_put | INTEGRATE | Packaged host uploads owned source media. |
| S3 download | INTEGRATE | Real AV worker download and repaired output decode depend on it. |
| S3 delete and head | INTEGRATE | Retry/absence and cleanup use actual deletion and independent absence read. |
| S3 multipart initiate, part upload/sign, abort | INTEGRATE | Interrupted cleanup observes a real part and supported abort. |
| S3 multipart complete | OPT-OUT | Cleanup case aborts an expired incomplete upload; completed upload paths are already exercised by normal ready scenarios. |
| S3 signed URL | INTEGRATE | Public consumer upload and output retrieval use shipped URL capability. |
| S3 tus part stream and completion | INTEGRATE | Client resume drives committed PATCH and final object. |
| S3 concatenate | OPT-OUT | The chosen same-node S3 tus path does not require concatenation. |
| tus OPTIONS/POST/HEAD/PATCH | INTEGRATE | Capability, session, offset authority and resume are RECOV-01. |
| tus GET/DELETE | OPT-OUT | Retrieval and termination methods are outside the specified interrupted-client case. |

No additional cloud account, provider adapter, public API, schema or dependency family is introduced. Local fixture evidence does not claim Mux cloud parity.
