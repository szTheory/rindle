# Phase 1 Research: Foundation

- **Phase:** `01-foundation`
- **Date:** 2026-04-24
- **Purpose:** Define what must be known to plan Phase 1 with low rework risk and clear verification criteria.
- **Scope guard:** Phase 1 only (schema/domain substrate, contracts, security primitives, storage adapters, and foundational config/error behavior).

## What Must Be Planned

Phase 1 planning should produce concrete deliverables that satisfy the full requirement set mapped to Phase 1 in `ROADMAP.md`, with special attention to ordering and invariants:

1. **Queryable normalized data substrate**
   - Complete migrations and schemas for `media_assets`, `media_attachments`, `media_variants`, `media_upload_sessions`, `media_processing_runs`.
   - Enforce queryable lifecycle state columns (no JSON-only state).
   - Add indexes needed for lifecycle and cleanup queries (`state`, polymorphic attachment lookup, unique variant identity, expiry queries).

2. **State transition model as explicit domain logic**
   - Implement asset, variant, and upload-session transition guards as explicit transition functions.
   - Reject invalid jumps with tagged errors (no silent coercion).
   - Keep transitions DB-backed and queryable, not process-memory state machines.

3. **Behavior contracts and adapter seam**
   - Define `Rindle.Storage`, `Rindle.Processor`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Authorizer` with typed callbacks.
   - Include `capabilities/0` in storage behavior so provider differences are explicit.
   - Keep storage side effects out of DB transactions by contract and calling pattern.

4. **Profile DSL and recipe digest**
   - `use Rindle.Profile` with compile-time validation (invalid config fails compile).
   - Profile must expose `variants/0` and `validate_upload/1`.
   - Stable digest algorithm for variants to support stale detection.

5. **Security primitives as non-optional defaults**
   - Magic-byte MIME detection, extension/MIME consistency checks, byte-size and pixel-limit validation.
   - Storage key generation is deterministic and not user-controlled.
   - Filename sanitization is distinct from storage key generation.

6. **Storage foundation**
   - Local adapter and S3-compatible adapter satisfy the same behavior suite.
   - Capability reporting matches reality (`:presigned_put` for S3 path; no fake capability claims).
   - Error contract is tagged tuples (`{:error, reason}`), never hidden raises in domain paths.

7. **Foundation-level configuration and error semantics**
   - `config :rindle` baseline, queue naming defaults, TTL defaults, signed-URL defaults (for downstream phases).
   - Public API and contract-facing functions use tagged tuple semantics.
   - Logging shape for transition failures, quarantine, and storage failures defined now to avoid drift.

## Implementation Strategy

Recommended Phase 1 planning sequence (substrate-first):

1. **Dependency and baseline alignment**
   - Plan `mix.exs` updates required by Phase 1 substrate (`Oban`, `Image/Vix`, S3 deps, MIME detection deps, test deps).
   - Capture libvips/dev environment assumptions as plan preconditions.
   - Respect hard constraints: Oban required, Image/Vix default, no ImageMagick/FFmpeg in core.

2. **Schema-first domain core**
   - Finish remaining migrations after `media_assets` and define indexes/constraints before writing broad domain logic.
   - Immediately pair each table with an Ecto schema + changeset constraints so DB and app rules align.
   - Plan around binary IDs and UTC microsecond timestamps already configured.

3. **Transition guards and state invariants**
   - Add transition modules/functions for ASM/VSM/USM with exhaustive allowlists.
   - Define transition error shapes and transition logging semantics.
   - Ensure planner encodes anti-jump requirements (e.g., no `staged -> ready`).

4. **Behavior contracts before adapter implementation detail**
   - Lock callback signatures and capability model first.
   - Then implement local + S3 adapters against those contracts.
   - Keep boundaries strict: domain layer should not know provider-specific semantics.

5. **Profile DSL and validation primitives**
   - Implement compile-time profile validation and recipe digest.
   - Bind upload validation primitives to profile policy model.
   - Ensure outputs are reusable by later upload/processing phases without redesign.

6. **Security gate wiring**
   - Plan integration points for MIME/extension/size/pixel checks and key generation.
   - Explicitly model quarantine failure path in transitions.
   - Add test vectors for spoofed MIME and extension mismatches.

7. **Contract test harness + targeted integration checks**
   - Behavior conformance tests (especially storage adapters).
   - State machine transition suites (valid/invalid matrix).
   - Focus on Phase 1 checks only; defer full upload pipeline E2E to Phase 2+.

Boundary rules for planning:
- **In scope:** SCHEMA/ASM/VSM/USM/BHV/PROF/SEC/STOR/STALE/CONF/ERR families mapped to Phase 1.
- **Out of scope for this phase:** full upload transport flow, processing worker orchestration, delivery UX, Day-2 operations UI/CLI expansion, CI multi-lane hardening.
- **Dependency handoff to later phases:** Phase 1 must expose stable contracts and data model so Phase 2+ can build without migration churn.

## File-Level Plan Inputs

Likely files/modules planners should include, with rationale:

- `mix.exs`
  - Update and lock foundational deps (`oban`, `image`, `ex_aws_s3`, `ex_aws`, MIME detection lib, test deps) required by Phase 1 contracts.

- `config/config.exs`
  - Confirm defaults and compile-time settings stay aligned with binary IDs/timestamps and foundation config posture.

- `config/runtime.exs`
  - Ensure host-owned runtime DB config posture is preserved (no library-owned runtime secrets model).

- `priv/repo/migrations/*`
  - Existing `create_media_assets` migration is present; planner should add remaining 4 core tables and required indexes/constraints.

- `lib/rindle/repo.ex`
  - Repo remains local harness/test substrate; planner should avoid shifting runtime ownership model.

- `lib/rindle/domain/media_asset.ex`
- `lib/rindle/domain/media_attachment.ex`
- `lib/rindle/domain/media_variant.ex`
- `lib/rindle/domain/media_upload_session.ex`
- `lib/rindle/domain/media_processing_run.ex`
  - Core schema + changeset + query helpers aligned with normalized model and queryability constraints.

- `lib/rindle/domain/asset_fsm.ex`
- `lib/rindle/domain/variant_fsm.ex`
- `lib/rindle/domain/upload_session_fsm.ex`
  - Explicit transition guard modules (or equivalent functions) for valid/invalid transition enforcement.

- `lib/rindle/storage.ex`
- `lib/rindle/processor.ex`
- `lib/rindle/analyzer.ex`
- `lib/rindle/scanner.ex`
- `lib/rindle/authorizer.ex`
  - Behavior contracts and callback specs.

- `lib/rindle/storage/local.ex`
- `lib/rindle/storage/s3.ex`
  - Concrete adapter implementations; must pass shared behavior suite.

- `lib/rindle/profile.ex`
- `lib/rindle/profile/validator.ex`
- `lib/rindle/profile/digest.ex`
  - DSL compile-time validation and stable recipe digest support.

- `lib/rindle/security/mime.ex`
- `lib/rindle/security/upload_validation.ex`
- `lib/rindle/security/storage_key.ex`
- `lib/rindle/security/filename.ex`
  - Security primitives required by Phase 1 invariants.

- `lib/rindle.ex`
  - Keep public facade minimal while contracts stabilize.

- `test/support/*`
- `test/rindle/domain/*_test.exs`
- `test/rindle/storage/*_test.exs`
- `test/rindle/profile/*_test.exs`
- `test/rindle/security/*_test.exs`
  - Planner should allocate comprehensive contract and invariant tests before phase completion claims.

## Risks and Landmines

1. **Transaction boundary violation**
   - Risk: storage writes/deletes inside DB transactions create split-brain state.
   - Mitigation: enforce design rule in behavior usage patterns and test for it.

2. **Schema drift from requirement matrix**
   - Risk: missing columns/indexes now force migration churn in Phase 2+.
   - Mitigation: requirement-by-requirement schema checklist tied to SCHEMA IDs.

3. **State machine under-specification**
   - Risk: permissive transitions introduce invalid lifecycle states.
   - Mitigation: explicit transition map tests for each state family, including invalid-jump assertions.

4. **Security checks treated as optional helpers**
   - Risk: MIME spoofing, extension mismatch, or key path abuse slips through.
   - Mitigation: make security checks part of required validation path and encode rejection transitions (`quarantined`/`failed`).

5. **Adapter capability ambiguity**
   - Risk: callers assume unsupported provider features and break at runtime.
   - Mitigation: `capabilities/0` is mandatory and consumed by planner-defined calling contracts.

6. **Premature expansion into Phase 2 concerns**
   - Risk: planning scope creep reduces certainty on foundational contracts.
   - Mitigation: planner explicitly marks upload transport/worker orchestration as downstream dependencies.

7. **Inconsistent error contract**
   - Risk: mixed raises and tuples make future composition brittle.
   - Mitigation: standardize tuple-returning boundaries and log structure in Phase 1.

## Test and Verification Inputs

Concrete checks that should be encoded directly in the Phase 1 plan:

1. **Migration verification**
   - Fresh DB migration creates all 5 tables with expected columns, defaults, FK constraints, and indexes.
   - Negative check: missing required state/index should fail verification.

2. **Schema/changeset verification**
   - Each schema rejects invalid required fields, invalid enum/state values, and constraint-violating writes.
   - Queryability checks for key operational filters (`state`, `expires_at`, polymorphic attachment lookup).

3. **State transition verification**
   - Transition matrix tests for ASM/VSM/USM: valid transitions accepted, invalid transitions rejected.
   - Explicit assertion for representative disallowed jumps (e.g., `staged -> ready`).

4. **Behavior contract verification**
   - Compile-time callback conformance for adapters.
   - Shared behavior tests pass for local and S3 adapters.
   - `capabilities/0` advertised features match implementation behavior.

5. **Security primitive verification**
   - Magic-byte detection overrides client content-type assumptions.
   - Extension/MIME mismatch rejected.
   - Size/pixel limit violations rejected.
   - Storage key generation never includes user-provided path segments.

6. **Profile DSL verification**
   - Invalid profile raises at compile-time.
   - Valid profile exposes `variants/0`, `validate_upload/1`.
   - Digest is stable for same recipe and changes when recipe changes.

7. **Error and logging verification**
   - Public/domain boundary functions return tagged tuples for expected failures.
   - Failure logs include context keys needed for ops (`asset_id`, `variant`, transition or reason).

## Validation Architecture

Phase 1 should be validated across Nyquist dimensions as a layered test architecture:

1. **Coverage**
   - Requirement-level coverage matrix maps each Phase 1 ID to at least one automated test.
   - Distinguish unit (schema/DSL/security helpers), integration (adapter behavior), and migration validation.

2. **Edge cases**
   - Empty/unknown MIME signatures.
   - Filename edge patterns (path separators, unicode normalization, duplicate names).
   - Boundary values for `max_bytes` and pixel limits.
   - Transition edge states (repeated transition attempts, terminal-state transitions).

3. **Failure modes**
   - Simulate storage adapter errors and assert tupled propagation.
   - Simulate invalid transition attempts and assert no unintended DB mutation.
   - Simulate profile compile-time misconfiguration and assert compile failure path.

4. **Idempotency**
   - Re-applying deterministic state transitions should not corrupt records.
   - Duplicate validation invocations for same input should produce consistent outcomes.
   - Storage-key generation for the same canonical identity should be deterministic by design.

5. **Security invariants**
   - Never trust client MIME/filename.
   - No user-controlled storage key path.
   - Validation enforcement happens before any promotion semantics.
   - Default security posture remains private/signed unless explicitly configured otherwise.

6. **Observability**
   - Foundation logs and errors are structured enough for downstream telemetry/ops.
   - Transition failures and quarantine events carry machine-parseable context.
   - Planner should reserve stable event/error naming seeds to avoid later contract drift.

Recommended planner output artifact: a test matrix table with columns
`requirement_id | test_type | happy_path | edge_case | failure_case | invariant_asserted`.

## Requirement Coverage Map

Phase 1 requirement families mapped to implementation concerns planners must encode:

| Family | Planning concern in Phase 1 |
|---|---|
| `SCHEMA` | Complete normalized tables, FK/index strategy, defaults, and queryability guarantees. |
| `ASM` | Asset transition allowlist, invalid-jump rejection, and persisted state consistency. |
| `VSM` | Variant lifecycle transition model and queryable recovery states (`failed/stale/missing/purged`). |
| `USM` | Upload-session lifecycle model with expiry/abort/failure terminal handling ready for downstream upload flows. |
| `BHV` | Behavior callback contracts and typed return conventions for storage/processing/analyzer/scanner/authorizer. |
| `PROF` | Compile-time DSL validation, variant spec normalization, and stable digest generation strategy. |
| `SEC` | MIME magic-byte validation, extension consistency checks, size/pixel guardrails, key generation and filename sanitization. |
| `STOR` | Local + S3 adapter conformance, capability reporting, and explicit storage error semantics. |
| `STALE` | Digest-driven stale detection model on variants (schema + comparison primitives in place). |
| `CONF` | Config defaults and override model that align with per-profile adapter and queue/TTL settings. |
| `ERR` | Tagged tuple error contract, warning/error/info logging semantics, and transition failure transparency. |

## Open Questions for Planner

Only unresolved decisions that materially affect planning quality:

1. **MIME detection library final choice**
   - Use `ex_marcel` (broader signature support) or `file_type` (smaller dependency surface) as default implementation under the same abstraction?

2. **Canonical storage key schema**
   - What exact deterministic key format should be locked in Phase 1 (e.g., profile-prefixed vs asset-id rooted), balancing future migration cost and human operability?

3. **State representation shape**
   - Should states be plain strings only at DB boundary with typed wrappers in code, or shared enum constants/macros to reduce drift?

4. **S3 adapter integration test scope in Phase 1**
   - Given CI integration lane is Phase 5, what minimum Phase 1 integration evidence (local MinIO lane vs contract-only tests) is required to confidently satisfy `STOR-07` without phase bleed?

5. **Transition concurrency guard strategy**
   - Is optimistic locking (`lock_version`) needed in Phase 1 domain schemas now, or can guarded `where` updates suffice until Phase 2 attach/promote concurrency logic?
