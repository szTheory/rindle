# Phase 59: E2E Proof & Truth Closure - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `59-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-05-27T00:00:00Z
**Phase:** 59-e2e-proof-truth-closure
**Mode:** assumptions + subagent research
**Areas analyzed:** E2E proof scope for tus extensions (Checksum, Defer-Length, Concatenation), documentation parity, milestone closure

## Assumptions Presented

### E2E Proof Scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The existing `tus-js-client` Node script in `generated_app_helper.ex` should be extended (or duplicated) to prove `uploadLengthDeferred`, `parallelUploads` (Concatenation), and Checksums. | Confident | `.planning/ROADMAP.md` explicitly calls for "node-based tus-js-client proofs for the new extensions." |
| We can use `tus-js-client`'s native options (`uploadLengthDeferred: true`, `parallelUploads: 2`, etc.) to trigger the required extension flows against the live Phoenix/MinIO generated app. | Confident | Upstream `tus-js-client` documentation. |

### Documentation Parity
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `guides/resumable_uploads.md` must be updated to explicitly document the full protocol support (Checksum, Defer-Length, Concatenation) and any adopter configurations needed to enable them. | Confident | `.planning/ROADMAP.md` phase definition calls for updating `guides/resumable_uploads.md`. |
| The `docs_parity_test.exs` and `generated_app_smoke_test.exs` must assert the presence of these new protocol features in the guides. | Likely | Existing pattern from Phase 44 (`44-03-PLAN.md`). |

### Milestone Closure
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Closing this phase also closes the overarching milestone (likely v1.11), requiring standard audit procedures. | Confident | `.planning/ROADMAP.md` calls for "Complete audit and close milestone." |

## Corrections Made

No user corrections required. The default path represents low-risk, high-value verification additions.

## Subagent Findings

### E2E Harness
- Recommended adding explicit command-line flags or a new track in the `test/install_smoke/support/generated_app_helper.ex` Node script to enable:
  - `uploadLengthDeferred`
  - `parallelUploads: 2` (triggers Concat)
  - `uploadChecksum` / `checksumAlgorithm` (if supported directly, or via headers).
- These ensure the LiveView and Plug integrations properly handle the extensions end-to-end under real socket conditions.

### Guide Parity
- The guides need to document that Rindle now fully supports the tus 1.0.0 extensions, including parallel uploads and checksums, with examples of how to configure the client (e.g. `@uppy/tus` parallel uploads).

## External Research

- **tus-js-client options:**
  - `parallelUploads: 2` or higher triggers the `Upload-Concat` behavior natively.
  - `uploadLengthDeferred: true` delays length generation.
  - Checksums are typically handled automatically by `tus-js-client` in Node.js if `chunkSize` is set and the server exposes `Checksum` in the extensions header, or can be explicitly passed.
