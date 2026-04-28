---
phase: 08-storage-capability-confidence
verified: 2026-04-28T14:13:13Z
status: human_needed
score: 3/4 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run the live Cloudflare R2 contract lane with real R2 credentials"
    expected: "`mix test test/rindle/storage/r2_test.exs --include r2` executes the presigned PUT, head, signed URL, and multipart checks against R2 with no skips or failures, and the reserved resumable capability still returns `{:error, {:upload_unsupported, :resumable_upload}}`."
    why_human: "The repo intentionally keeps R2 out of default CI; this environment had no `RINDLE_R2_*` secrets, so the only R2 executable proof skipped."
---

# Phase 8: Storage Capability Confidence Verification Report

**Phase Goal:** harden capability negotiation and prove provider-specific behavior across MinIO and Cloudflare R2 without regressing the new multipart lane.
**Verified:** 2026-04-28T14:13:13Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Capability flags for upload and delivery flows are centralized, documented, and validated by tests | ✓ VERIFIED | `Rindle.Storage.Capabilities` centralizes the vocabulary and tagged helpers at `lib/rindle/storage/capabilities.ex:1-67`; private delivery gates through it at `lib/rindle/delivery.ex:97-104,184-187`; multipart broker gates use it at `lib/rindle/upload/broker.ex:80-81,163-166,193-199`; vocabulary and adapter-truth tests live in `test/rindle/storage/storage_adapter_test.exs:56-76`. |
| 2 | MinIO-backed integration coverage exercises both presigned PUT and multipart flows end-to-end | ✓ VERIFIED | The S3 adapter suite performs real presigned PUT and multipart MinIO round-trips in `test/rindle/storage/s3_test.exs:28-125`; broker integration proves both MinIO lanes through promotion in `test/rindle/upload/lifecycle_integration_test.exs:188-323`; the canonical adopter lane proves both paths through promotion, variants, delivery, attach, and detach in `test/adopter/canonical_app/lifecycle_test.exs:105-261`. Targeted runs passed: `mix test test/rindle/storage/s3_test.exs --include minio`, `mix test test/rindle/upload/lifecycle_integration_test.exs --include integration`, `mix test test/adopter/canonical_app/lifecycle_test.exs --include minio`. |
| 3 | Cloudflare R2 behavior is documented and any unsupported flow fails with a tagged, user-actionable capability error | ? UNCERTAIN | The repo now has an opt-in R2 contract lane with explicit skip behavior and a reserved-capability tagged failure at `test/rindle/storage/r2_test.exs:14-28`, plus the canonical guide and R2 boundary docs at `guides/storage_capabilities.md:52-125`, `guides/profiles.md:122-135`, and `guides/secure_delivery.md:123-145`. But the executable R2 proof was skipped here because no `RINDLE_R2_*` credentials were present, so live provider behavior was not observed. |
| 4 | The capability model remains forward-compatible with a future GCS resumable adapter without changing current adopter-facing contracts | ✓ VERIFIED | Reserved resumable atoms are additive in `lib/rindle/storage/capabilities.ex:12-29`; tagged upload errors remain stable via `require_upload/2` at `lib/rindle/storage/capabilities.ex:50-57`; tests lock the reserved semantics in `test/rindle/upload/broker_test.exs:440-448` and `test/rindle/storage/r2_test.exs:26-28`; docs explicitly defer GCS/resumable APIs at `guides/storage_capabilities.md:23-28,127-138`. |

**Score:** 3/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/rindle/storage/capabilities.ex` | Central capability vocabulary, normalization, and tagged error helpers | ✓ VERIFIED | Exists, substantive, and consumed by delivery and broker gates. |
| `lib/rindle/storage.ex` | Shared capability type contract | ✓ VERIFIED | Typedoc points behavior users to the centralized capability vocabulary. |
| `test/rindle/storage/storage_adapter_test.exs` | Capability vocabulary and adapter-truth regression coverage | ✓ VERIFIED | Covers known atoms, malformed capability normalization, and truthful adapter capability lists. |
| `test/rindle/storage/s3_test.exs` | MinIO proof for presigned PUT and multipart on one adapter seam | ✓ VERIFIED | Uses real HTTP PUT and multipart part uploads against MinIO. |
| `test/rindle/upload/lifecycle_integration_test.exs` | Broker lifecycle proof for both direct-upload lanes | ✓ VERIFIED | Exercises broker-owned MinIO presigned PUT and multipart flows through verification and promotion. |
| `test/adopter/canonical_app/lifecycle_test.exs` | Canonical adopter proof for both direct-upload lanes | ✓ VERIFIED | Exercises both direct-upload paths through the adopter-owned runtime boundary. |
| `test/rindle/storage/r2_test.exs` | Opt-in live R2 contract coverage | ⚠️ VERIFIED STRUCTURALLY | Exists, is wired, and skips loudly without credentials; live provider behavior still needs human execution. |
| `guides/storage_capabilities.md` | Canonical capability matrix and provider-boundary guide | ✓ VERIFIED | Documents vocabulary, tagged failures, MinIO proof posture, opt-in R2 lane, and additive resumable semantics. |
| `guides/profiles.md` | Profile-facing capability selection guidance | ✓ VERIFIED | Links to the canonical guide and documents tagged unsupported outcomes. |
| `guides/secure_delivery.md` | Delivery-capability documentation and R2 signed-delivery notes | ✓ VERIFIED | Links back to the capability guide and documents `:signed_url` failure semantics. |
| `mix.exs` | ExDoc wiring for the capability guide | ✓ VERIFIED | `guides/storage_capabilities.md` is included in `docs.extras` at `mix.exs:100-109`. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/rindle/delivery.ex` | `lib/rindle/storage/capabilities.ex` | private delivery capability gate | ✓ WIRED | `Capabilities.require_delivery(adapter, :signed_url)` at `lib/rindle/delivery.ex:186-187`. |
| `lib/rindle/upload/broker.ex` | `lib/rindle/storage/capabilities.ex` | multipart upload capability gates | ✓ WIRED | `Capabilities.require_upload(adapter, :multipart_upload)` at `lib/rindle/upload/broker.ex:80,163,193`. |
| `test/rindle/storage/storage_adapter_test.exs` | `lib/rindle/storage/capabilities.ex` | known capability subset assertions | ✓ WIRED | `Capabilities.known/0` and `Capabilities.safe/1` asserted at `test/rindle/storage/storage_adapter_test.exs:56-69`. |
| `test/rindle/storage/s3_test.exs` | `lib/rindle/storage/s3.ex` | real MinIO-backed presigned PUT and multipart round-trips | ✓ WIRED | Direct calls to `S3.presigned_put/3`, multipart APIs, `head/2`, and `delete/2` are exercised against MinIO. |
| `test/rindle/upload/lifecycle_integration_test.exs` | `lib/rindle/upload/broker.ex` | broker lifecycle integration over MinIO for both upload lanes | ✓ WIRED | Uses `Broker.sign_url/2`, `Rindle.initiate_multipart_upload/2`, `Rindle.sign_multipart_part/2`, and `Rindle.complete_multipart_upload/2`. |
| `test/adopter/canonical_app/lifecycle_test.exs` | `lib/rindle/upload/broker.ex` | broker-owned direct-upload flows over MinIO | ✓ WIRED | The adopter lane uses public direct-upload APIs for both presigned PUT and multipart paths. |
| `test/rindle/storage/r2_test.exs` | `lib/rindle/storage/s3.ex` | live R2 environment wired through the shipped S3 adapter seam | ✓ WIRED | Calls `S3.presigned_put/3`, `S3.head/2`, `S3.url/2`, and multipart APIs against env-driven R2 config. |
| `mix.exs` | `guides/storage_capabilities.md` | ExDoc extras list | ✓ WIRED | `mix.exs:100-109` includes the guide in `extras`. |
| `guides/storage_capabilities.md` | `lib/rindle/storage/capabilities.ex` | documented capability vocabulary and tagged unsupported errors | ✓ WIRED | The guide mirrors shipped atoms and tagged tuples from the runtime module. |
| `guides/secure_delivery.md` | `guides/storage_capabilities.md` | delivery capability contract reference | ✓ WIRED | `guides/secure_delivery.md:19-20,128-145` points readers back to the shared guide. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `test/rindle/storage/s3_test.exs` | `put_url`, `upload_id`, `size` | `Rindle.Storage.S3` calls backed by MinIO | Yes — verified by real `:httpc` PUTs, multipart ETags, and `head/2` reads | ✓ FLOWING |
| `test/rindle/upload/lifecycle_integration_test.exs` | `presigned.url`, `asset.state`, `multipart.upload_id` | `Broker` + storage adapter + repo | Yes — flows pass through broker verification and promotion | ✓ FLOWING |
| `test/adopter/canonical_app/lifecycle_test.exs` | `presigned.url`, `asset`, `ready_variants`, `signed_url` | Public adopter APIs over repo + MinIO | Yes — the adopter lane reaches promotion, variant processing, delivery, attach, and detach | ✓ FLOWING |
| `test/rindle/storage/r2_test.exs` | `put_url`, `multipart_size`, `signed_url` | `Rindle.Storage.S3` configured for R2 | Unknown in this environment — lane skipped because credentials were absent | ? SKIPPED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Capability seam and tagged error regressions hold | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/delivery_test.exs test/rindle/upload/broker_test.exs` | `37 tests, 0 failures (1 excluded)` | ✓ PASS |
| MinIO S3 adapter proves presigned PUT + multipart | `mix test test/rindle/storage/s3_test.exs --include minio` | `3 tests, 0 failures, 2 skipped` | ✓ PASS |
| Broker lifecycle proves both direct-upload lanes | `mix test test/rindle/upload/lifecycle_integration_test.exs --include integration` | `8 tests, 0 failures` | ✓ PASS |
| Canonical adopter lane proves both direct-upload lanes | `mix test test/adopter/canonical_app/lifecycle_test.exs --include minio` | `3 tests, 0 failures` | ✓ PASS |
| R2 lane is present and opt-in only | `mix test test/rindle/storage/r2_test.exs --include r2` | `1 test, 0 failures, 1 skipped` | ? SKIP |
| ExDoc wiring builds with the capability guide | `mix docs` | Docs generated successfully; two pre-existing hidden-doc warnings from `lib/rindle/live_view.ex` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `CAP-01` | `08-01-PLAN.md` | Storage adapters advertise precise capability flags for delivery and upload flows | ✓ SATISFIED | Central vocabulary and tagged helpers at `lib/rindle/storage/capabilities.ex:1-67`; regression coverage in `test/rindle/storage/storage_adapter_test.exs:56-76`. |
| `CAP-02` | `08-02-PLAN.md` | MinIO/S3 integration tests exercise both presigned PUT and multipart flows end-to-end against real storage | ✓ SATISFIED | Real MinIO adapter, broker, and adopter tests passed under targeted execution. |
| `CAP-03` | `08-03-PLAN.md` | Cloudflare R2 compatibility is documented and verified so unsupported flows fail explicitly rather than implicitly degrading | ? NEEDS HUMAN | Docs and opt-in lane exist, and reserved resumable flow is tagged unsupported, but the live R2 contract lane skipped without credentials. |
| `CAP-04` | `08-01-PLAN.md`, `08-03-PLAN.md` | Capability negotiation remains extensible for a future GCS resumable adapter without breaking current adapter contracts | ✓ SATISFIED | Reserved resumable atoms and tagged failures are additive in code and docs, with no new public resumable API introduced. |

### Anti-Patterns Found

No blocking anti-patterns found in the phase-owned files. Grep hits for `placeholder` were either legitimate prose about reserved resumable placeholders or test helper comments, not stubs.

### Human Verification Required

### 1. Cloudflare R2 Live Contract

**Test:** Export `RINDLE_R2_URL`, `RINDLE_R2_ACCESS_KEY_ID`, `RINDLE_R2_SECRET_ACCESS_KEY`, `RINDLE_R2_BUCKET`, and optionally `RINDLE_R2_REGION`, then run `mix test test/rindle/storage/r2_test.exs --include r2`.
**Expected:** The test should execute the presigned PUT, `head/2`, signed URL, and multipart checks against R2 without skipping, and the reserved resumable capability check should still return `{:error, {:upload_unsupported, :resumable_upload}}`.
**Why human:** The repository deliberately keeps live R2 out of default CI, and this verification environment had no R2 credentials, so actual provider behavior could not be observed programmatically here.

### Gaps Summary

No code or wiring gaps were found in the implemented Phase 8 artifacts. The only remaining closure item is live-provider confirmation for the opt-in Cloudflare R2 lane, so the phase is not `passed` yet.

---

_Verified: 2026-04-28T14:13:13Z_
_Verifier: Claude (gsd-verifier)_
