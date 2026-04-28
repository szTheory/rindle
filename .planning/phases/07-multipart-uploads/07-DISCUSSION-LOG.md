# Phase 7: Multipart Uploads - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `07-CONTEXT.md`; this log preserves the analysis.

**Date:** 2026-04-28
**Phase:** 07-multipart-uploads
**Mode:** assumptions
**Areas analyzed:** Runtime and flow ownership, Capability and adapter contract, Verification and promotion path, Session lifecycle and maintenance, Testing and provider proof

## Assumptions Presented

### Runtime and flow ownership
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Multipart should extend the existing broker-owned direct-upload flow rather than introduce a separate subsystem. | Confident | `lib/rindle/upload/broker.ex`, `lib/rindle.ex`, `.planning/ROADMAP.md` |
| Multipart persistence and follow-up jobs must stay on `Rindle.Config.repo/0` and preserve the Phase 6 adopter-owned runtime seam. | Confident | `lib/rindle/upload/broker.ex`, `.planning/phases/06-adopter-runtime-ownership/06-adopter-runtime-ownership-02-SUMMARY.md`, `test/rindle/upload/broker_test.exs`, `test/adopter/canonical_app/lifecycle_test.exs` |

### Capability and adapter contract
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Multipart availability should be capability-gated and unsupported adapters should fail with explicit tagged capability errors. | Likely | `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `lib/rindle/delivery.ex`, `lib/rindle/storage.ex`, `test/rindle/storage/storage_adapter_test.exs` |
| The capability model should be additive so multipart does not disturb existing `:presigned_put` support. | Confident | `.planning/ROADMAP.md`, `.planning/PROJECT.md`, `lib/rindle/storage/s3.ex`, `lib/rindle/storage/local.ex` |

### Verification and promotion path
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Completing multipart upload parts is not enough by itself; the flow should converge back into the existing trusted verification/promotion path before attachable assets emerge. | Confident | `.planning/ROADMAP.md`, `lib/rindle/upload/broker.ex`, `test/rindle/upload/lifecycle_integration_test.exs`, `test/adopter/canonical_app/lifecycle_test.exs` |
| Presigned PUT remains a supported path and multipart ships as an additive option, not a replacement. | Confident | `.planning/ROADMAP.md`, `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md` |

### Session lifecycle and maintenance
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Multipart metadata should be layered onto the current upload-session model, keeping `media_upload_sessions` as the authoritative session lifecycle surface for operators and maintenance code. | Likely | `lib/rindle/domain/media_upload_session.ex`, `lib/rindle/domain/upload_session_fsm.ex`, `lib/rindle/upload/broker.ex` |
| Abandoned multipart uploads should extend the existing abort-then-cleanup maintenance lane rather than create a separate cleanup mechanism. | Confident | `.planning/ROADMAP.md`, `lib/rindle/ops/upload_maintenance.ex`, `lib/rindle/workers/abort_incomplete_uploads.ex`, `test/rindle/ops/upload_maintenance_test.exs` |

### Testing and provider proof
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Multipart needs real MinIO-backed proof using the same adopter/integration harness patterns already used for direct upload. | Confident | `.planning/phases/05-ci-1-0-readiness/05-CONTEXT.md`, `test/adopter/canonical_app/lifecycle_test.exs`, `test/rindle/upload/lifecycle_integration_test.exs`, `test/rindle/storage/s3_test.exs` |

## Corrections Made

None. Assumptions mode proceeded using the project's stored decision preference:
agent decides by default unless a high-impact ambiguity appears.
