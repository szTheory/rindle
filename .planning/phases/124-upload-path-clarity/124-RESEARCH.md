# Phase 124: Upload Path Clarity - Research

**Researched:** 2026-08-22
**Domain:** behavior-preserving Elixir/Plug tus edge and upload-broker decomposition
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### the agent's Discretion
- Choose the smallest internal collaborator boundaries that make request parsing, protocol validation,
  storage effects, response construction, broker validation, capability negotiation, persistence, and
  completion orchestration independently readable.
- Prefer behavior-backed characterization and parity tests over source-text snapshots.
- Keep `Rindle.Upload.TusPlug` and `Rindle.Upload.Broker` as the public facades; new collaborators are
  internal and must not expand the documented public API.
- Avoid abstraction for line-count reduction alone. Extract only cohesive mechanics with a clear owner.

### Deferred Ideas (OUT OF SCOPE)

No new tus protocol features, richer uploader abstractions, GCS-as-tus backend, storage behavior,
schema changes, or public API redesign. Those remain outside the v1.24 maintenance charter.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Keep edits focused and run the checks named by `RUNNING.md`. [VERIFIED: `AGENTS.md`]
- Keep merge-blocking CI green; use the repository's PR-first release-train posture for this serious maintenance work. [VERIFIED: `AGENTS.md`]
- Do not change product scope or shipped claims; this approved phase is a finite behavior-preserving refactor. [VERIFIED: `AGENTS.md`; `.planning/ROADMAP.md`]
- Run `./scripts/maintainer/repo_hygiene_check.sh` only for release preparation; it is not a phase-local acceptance command. [VERIFIED: `AGENTS.md`]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPLOAD-01 | Tus parsing, protocol validation, storage effects, and response construction are cohesive while the Plug contract, resumability, and error vocabulary remain unchanged. [VERIFIED: `.planning/REQUIREMENTS.md`] | Dispatch, creation/signing, authorization, PATCH streaming/storage, and response/error seams are identified with their observable protocol locks. [VERIFIED: `lib/rindle/upload/tus_plug.ex`; `test/rindle/upload/tus_plug_test.exs`] |
| UPLOAD-02 | Broker validation, capability negotiation, session persistence, and completion orchestration are cohesive while public APIs and storage-adapter behavior remain unchanged. [VERIFIED: `.planning/REQUIREMENTS.md`] | The public façade, lifecycle preparation, storage operations, persistence/compensation, and completion convergence are separately mapped. [VERIFIED: `lib/rindle/upload/broker.ex`; `test/rindle/upload/broker_test.exs`; `test/rindle/upload/lifecycle_integration_test.exs`] |
</phase_requirements>

## Summary

This phase needs no dependency, schema, migration, protocol, or API work. `TusPlug` (1,048 lines) is a public `Plug` edge with only `init/1`, `call/2`, `create_upload/2`, and `default_actor/1` exposed; `Broker` (1,013 lines) is the public lifecycle surface. Both modules already contain conceptual seams, but their private mechanics co-reside with public dispatch/orchestration. Preserve the facades and move only cohesive private mechanics behind `@moduledoc false` collaborators. [VERIFIED: `lib/rindle/upload/tus_plug.ex`; `lib/rindle/upload/broker.ex`; `lib/rindle.ex`; `test/rindle/api_surface_boundary_test.exs`]

The hard part is ordering, not code size. A PATCH must authenticate/load/authorize, reject content type and offset mismatch before reading the body, stream to a per-PATCH temporary file, dispatch polymorphically through the configured adapter, persist adapter-returned state, emit/broadcast, then either respond or converge through the existing broker completion lane. DELETE must authenticate before touching storage and abort backing storage before persisting `aborted`; `verify_completion/2` must retain its storage-head/FSM/Ecto.Multi/Oban/post-commit telemetry-and-broadcast sequence. [VERIFIED: `lib/rindle/upload/tus_plug.ex`; `lib/rindle/upload/broker.ex`; focused tests]

**Primary recommendation:** plan two sequential refactor slices: first extract TusPlug private protocol mechanics while retaining dispatch and all response construction in the façade; then extract Broker private lifecycle mechanics while retaining its public functions, persistence transitions, post-commit side effects, and result shaping in the façade. Add only behavioral/compiled-boundary tests where existing proof lacks a guard.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| tus HTTP dispatch, signed URL creation, protocol parsing and response headers | API / Backend | — | `TusPlug` is mounted into Plug/Phoenix and owns `Plug.Conn`, signed token creation, and tus request/response behavior. [VERIFIED: `lib/rindle/upload/tus_plug.ex`] |
| PATCH temporary-file streaming and adapter dispatch | API / Backend | Database / Storage | The edge bounds/read-drains HTTP input and asks the configured adapter to store it; the returned offset/upload state is persisted to the session. [VERIFIED: `TusPlug` PATCH helpers; `Rindle.Storage` behaviour tests] |
| upload session / asset lifecycle and promotion enqueue | API / Backend | Database / Storage | `Broker` checks adapter state, applies FSM checks, persists session/asset changes transactionally, and schedules `PromoteAsset`. [VERIFIED: `lib/rindle/upload/broker.ex`] |
| object/multipart/resumable storage effects | Database / Storage | API / Backend | Adapters own `head`, initiation, part stream, complete, cancel, concatenate, and abort behavior; the two facades must remain polymorphic clients. [VERIFIED: `lib/rindle/storage.ex`; `lib/rindle/storage/local.ex`; `lib/rindle/storage/s3.ex`; storage tests] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Existing Elixir/Plug/Ecto/Oban stack | Project-pinned; supported acceptance cell is Elixir 1.17 / OTP 27 | Existing HTTP, persistence, transaction, and job semantics | This is an internal decomposition; adding a framework would expand the risk surface. [VERIFIED: `mix.exs`; `RUNNING.md`] |
| Existing `Rindle.Storage` behaviours and `Rindle.Storage.Capabilities` | Existing project code | Adapter negotiation and polymorphic storage effects | They encode Local/S3/GCS capability distinctions and prevent protocol fallback. [VERIFIED: `lib/rindle/storage.ex`; `lib/rindle/storage/capabilities.ex`] |
| Existing `Rindle.Upload.ResumableTelemetry` | Existing project code | Locked resumable event vocabulary and metadata filtering | It is already the central telemetry owner and prevents leaking signed URI/storage data. [VERIFIED: `lib/rindle/upload/resumable_telemetry.ex`; telemetry contract tests] |

**Installation:** None. This phase must not install packages. [VERIFIED: phase scope]

## Package Legitimacy Audit

Not applicable: no external package is recommended or installed. [VERIFIED: phase scope]

## Exact Responsibility Seams

### TusPlug: preserve façade ownership

Keep `init/1`, method dispatch in `call/2`, `create_upload/2`, and `default_actor/1` in `Rindle.Upload.TusPlug`. `call/2` is the observable entry point, including Phoenix's forwarded `GET`-with-`Tus-Resumable` compatibility path. `create_upload/2` is used by `Rindle.initiate_tus_upload/2`; do not silently move it to a newly public module. [VERIFIED: `lib/rindle/upload/tus_plug.ex`; `lib/rindle.ex`]

| Internal collaborator | Owns | Façade retains | Non-negotiable inputs/outputs |
|---|---|---|---|
| `TusProtocol` (private) | Header parsing/normalization, length/checksum/metadata parsing, token claim validation, reason-to-status mapping | `call/2` routing and final response construction | Keep atoms and header strings exactly: `:invalid_length`, `:invalid_offset`, `:wrong_content_type`, `:offset_mismatch`, `:too_large`, `:invalid_checksum`, `:checksum_mismatch`, token errors. [VERIFIED: `TusPlug`; `tus_plug_test.exs`] |
| `TusCreation` (private) | POST creation and concatenation mechanics: broker initiation, HMAC claims, opaque location, session URI stamp | POST branch and 201/400/413 response text/header construction | Claims retain session id, actor, expiry, length and optional content type; signed URL remains only in redacting `session_uri`. [VERIFIED: `TusPlug`; `MediaUploadSession`; creation tests] |
| `TusStream` (private) | bounded body drain, checksum verification, per-PATCH temp-file lifecycle, adapter `upload_part_stream/5` / `complete_part_stream/4` calls, prior-state codec | PATCH gate order, persistence call, telemetry/broadcast, and final 204/5xx response | No full body buffering; temp file removed after dispatch; Local and S3 remain adapter-polymorphic. [VERIFIED: `TusPlug`; polymorphic/local/S3 tests] |
| `TusTermination` (private) | normalized retry-marker construction and call to `UploadMaintenance.abort_tus_backing/2` | auth/load/authorization order, session update, broadcast, and 204/5xx response | Preserve `tus_abort_failed:<bounded atom-or-transport>` marker exactly because the reaper selects it byte-for-byte. [VERIFIED: `TusPlug`; `UploadMaintenance`; DELETE tests] |
| `UploadBroadcast` (optional shared private collaborator) | Identical existing topic/payload construction used by both facades | event timing at each façade | Extract only if it removes exact duplicated mechanics without creating public API; its payload and topic order are observable. [VERIFIED: `TusPlug`; `Broker`; upload tests] |

Do not make a general `TusRequest` object, response DSL, adapter registry, or public protocol helper. They add new surface without clarifying a current single-owner concern. [VERIFIED: phase constraints; current public boundary]

### Broker: preserve façade ownership

Keep every currently exported Broker function and type in `Rindle.Upload.Broker`, with public result shaping at that boundary: initiation functions, signing, multipart completion, resumable status/cancel, `concatenate_tus_sessions/3`, and `verify_completion/2`. These are reached directly and through `Rindle` façade delegates. [VERIFIED: `lib/rindle/upload/broker.ex`; `lib/rindle.ex`; `test/rindle/api_surface_boundary_test.exs`]

| Internal collaborator | Owns | Façade retains | Non-negotiable inputs/outputs |
|---|---|---|---|
| `Broker.SessionSeed` (private) | profile-name/key/expiry/asset-id seed construction | public option defaults and result maps | Keep filename, expiry, storage-key generation and adapter resolution values unchanged. [VERIFIED: Broker initiation functions] |
| `Broker.Persistence` (private) | create asset+session transaction; strategy-specific attrs; `update_session`; compensation after persistence failure | public validation/capability order and post-success effects | Preserve states/columns: multipart `initialized`; GCS resumable `signed`; tus `signed`, `upload_strategy: "resumable"`, `resumable_protocol: "tus"`, offset `0`; keep compensation calls and logs. [VERIFIED: `Broker`; `MediaUploadSession`; broker tests] |
| `Broker.SessionValidation` (private) | loaded-session strategy guards, multipart part normalization, profile resolution | public `with` flow / error return translation | Preserve exact invalid state and unsupported capability error terms. [VERIFIED: `Broker`; broker tests] |
| `Broker.Completion` (private) | the existing `Ecto.Multi` construction for verifying/completed session, validating asset, promote job | `verify_completion/2` preconditions, storage `head`, FSM checks, and all post-commit effects | Do not split the Multi in a way that changes transaction keys/order, state changes, metadata assignment, enqueue, result map, or error term. [VERIFIED: `Broker`; broker and lifecycle tests] |
| `UploadBroadcast` (optional shared private collaborator) | existing topic/payload mechanics | each lifecycle method's timing | Preserve topic list (`admin`, session, optional asset), event atom, fields, and optional `offset`. [VERIFIED: `TusPlug`; `Broker`; tests] |

## Contract Inventory: What Must Not Move Semantically

| Surface | Preservation invariant |
|---------|------------------------|
| Public API | `TusPlug` remains the documented Plug facade; `Broker` retains all existing signatures/types; `Rindle` delegates keep their signatures. New collaborators are hidden (`@moduledoc false`) and no public module list is expanded. [VERIFIED: `TusPlug`; `Broker`; `Rindle`; API-surface test] |
| Protocol | OPTIONS advertises the current version/extensions/max-size/checksum algorithms; creation remains `201` with `Location` and expiry; HEAD remains `204`, authoritative offset, no-store and expiry; successful PATCH remains `204` and reports offset. [VERIFIED: `TusPlug`; `tus_plug_test.exs`; CITED: https://tus.io/protocols/resumable-upload] |
| PATCH rejection | Missing/tampered token/not-found, expired token, expired row, authorizer rejection, wrong content type, offset mismatch, sizes, malformed lengths/checksum, and checksum mismatch retain current status vocabulary. Crucially, 415/409 happen before a body read or storage mutation. [VERIFIED: `TusPlug`; `tus_plug_test.exs`; CITED: https://tus.io/protocols/resumable-upload] |
| Token/security | Salt remains `rindle:tus:url`; final path segment handling, expiry rule, actor claim, optional authorizer call shape, and URI redaction remain unchanged. Never log, inspect, broadcast, or emit `session_uri`. [VERIFIED: `TusPlug`; `MediaUploadSession`; `ResumableTelemetry`; tests] |
| Storage | Keep capability gates and no-fallback behavior. PATCH uses adapter stream calls—not `if Local`; final completion uses adapter completion then existing `Broker.verify_completion/2`; Local and S3 path/cleanup semantics stay intact. [VERIFIED: `Capabilities`; `TusPlug`; local/S3 tests] |
| Persistence | Preserve upload/asset FSM validation; session strategy/protocol attributes; `last_known_offset`, multipart id/parts codec, URI expiry, verification timestamp, asset size/content type, and failure marker values. No migration/schema change. [VERIFIED: `Broker`; `TusPlug`; `MediaUploadSession`; tests] |
| DELETE/reaper | Verify before storage access; abort backing first; update `aborted` second; clean abort stores `failure_reason: nil`; transient abort stores bounded `tus_abort_failed:` marker and still returns 204 after a successful row update; update failure is 5xx. [VERIFIED: `TusPlug`; `UploadMaintenance`; DELETE tests] |
| Telemetry | Preserve raw `[:rindle, :upload, :start|:stop]` timing and resumable start/patch/stop/status/cancel event names, metadata allowlist, measurements, and post-commit ordering. [VERIFIED: `Broker`; `TusPlug`; `ResumableTelemetry`; telemetry contract tests] |
| Broadcasts | Preserve the event atoms, payload keys, optional offset, and all three topic families; emit only at their current successful persistence points. [VERIFIED: `TusPlug`; `Broker`; focused tests] |
| Errors/results | Preserve `{:ok, ...}` map shapes, `{:error, :not_found}` and translated `:storage_object_missing`, FSM tuples, adapter terms, and response body strings. [VERIFIED: `Broker`; `TusPlug`; broker/tus tests] |

## Recommended Extraction Order

1. **Characterize/freeze missing observable seams first.** Add a compiled-doc boundary check for candidate hidden collaborators only if absent; add parity tests for an uncovered ordering/shape, never a source-text assertion. Baseline `TusPlug` and Broker tests now pass locally: 67 tests, 0 failures, 3 skipped under Elixir 1.19/OTP 28, which is diagnostic only. [VERIFIED: local command `mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/broker_test.exs --seed 0`; `RUNNING.md`]
2. **TusPlug slice.** Extract private protocol parsing/creation, streaming, and termination units one at a time while `TusPlug` retains dispatch, gate ordering, response construction, persistence/telemetry/broadcast sequencing. Run focused tus tests after each extraction, then Local backing proof. [VERIFIED: focused test suite and source responsibilities]
3. **Broker slice.** Extract seed/persistence-compensation, validation/normalization, and completion-Multi mechanics one at a time. Retain public `with` ordering, capability checks, post-commit telemetry/broadcast/result construction. Run broker tests after each extraction, then lifecycle integration. [VERIFIED: Broker source and tests]
4. **Cross-adapter/release proof last.** Run the S3 tus integration and the deterministic SAFE-01 runner. MinIO/S3 requires its environment; do not replace it with a mock-only conclusion. [VERIFIED: `tus_s3_integration_test.exs`; `scripts/maintainer/refactor_contract.sh`; CI workflow]

## Common Pitfalls

### Pitfall 1: extracting PATCH gates below streaming

**What goes wrong:** A bad content type or offset can consume a body, create a temp file, or call storage before returning 415/409.

**Avoid:** Keep the entire validate-before-`stream_append` sequence in the façade or a single pure/ordered operation invoked before any reader. Assert no part file and unchanged offset on wrong offset. [VERIFIED: `TusPlug`; `tus_plug_test.exs`; CITED: https://tus.io/protocols/resumable-upload]

### Pitfall 2: adapter-specific extraction

**What goes wrong:** A collaborator hard-wires Local path helpers or changes S3's cross-PATCH multipart/tail state behavior.

**Avoid:** Pass the already-resolved adapter/root and use existing behaviour calls; retain the Mox dispatch test plus Local and S3 integration proof. [VERIFIED: `TusPlug`; local/S3 tests]

### Pitfall 3: separating compensation from the failed persistence path

**What goes wrong:** Multipart/resumable/tus remote or temporary backing is leaked when the database transaction fails.

**Avoid:** Keep each strategy's compensation adjacent to the failed `create_upload_session` outcome, preserving best-effort log/error behavior. [VERIFIED: `Broker`; broker tests]

### Pitfall 4: changing side-effect timing during a clean extraction

**What goes wrong:** telemetry/broadcast fires before commit, or completion enqueues outside the established `Ecto.Multi`.

**Avoid:** Façades own post-commit effects; preserve the existing Multi keys/order and only emit/broadcast after success. [VERIFIED: `Broker`; telemetry and lifecycle tests]

### Pitfall 5: DELETE's two different failure contracts

**What goes wrong:** Either returning 5xx for a successful DB cancellation after a transient backing abort, or returning 204 when the DB state update failed.

**Avoid:** Preserve the current branch distinction and retry marker/reaper coupling. [VERIFIED: `TusPlug`; `UploadMaintenance`; DELETE tests]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Upload protocol parser/response framework | New tus abstraction or generic request/response DSL | Small private parsing/creation/streaming helpers under current façade | Existing code has a deliberately bounded tus subset and response vocabulary. [VERIFIED: phase scope; `TusPlug`] |
| Storage transport selection | `case adapter` or new backend registry | `Capabilities.require_upload/2` and existing storage behaviour callbacks | Preserves no-fallback policy and Local/S3/GCS boundaries. [VERIFIED: `Capabilities`; `TusPlug`; `Broker`] |
| Session lifecycle state machine | New transition map or persistence wrapper | Existing `UploadSessionFSM`, `AssetFSM`, changesets, and `Ecto.Multi` | State/error terms and transaction order are public behavior. [VERIFIED: FSMs; Broker] |
| Telemetry/broadcast vocabulary | New generic event bus | `ResumableTelemetry` plus existing raw upload events/broadcast construction | Event names, metadata filtering, topic shape, and timing are locked. [VERIFIED: telemetry contracts; focused tests] |

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `media_upload_sessions` stores strategy/protocol, URI/expiry, offsets, multipart id/parts, state, verification and failure-marker values; related assets store promotion metadata. [VERIFIED: `MediaUploadSession`; `Broker`] | Code-only extraction; no data migration. Characterization must prove persisted values are byte/term-equivalent. |
| Live service config | Adopter mounts supply profile, secret, optional size/identity; app config may supply `:tus_resume_authorizer`, repo and PubSub server. [VERIFIED: `TusPlug`; `Config`; guides] | No config mutation. Preserve option names/defaults and authorizer validation/call shape. |
| OS-registered state | None found in the upload paths; no launchd/systemd/worker registration embeds these module names. [VERIFIED: codebase search of upload modules and scripts] | None. |
| Secrets/env vars | `secret_key_base` signs bearer URLs; live GCS tests use credentials/bucket environment values. [VERIFIED: `TusPlug`; `broker_test.exs`] | No key/name change; never include signed URI or credentials in new collaborator logs/telemetry. |
| Build artifacts | No generated artefact is part of the two runtime modules; compiled BEAM/docs will naturally reflect hidden collaborators. [VERIFIED: `mix.exs`; API-surface test] | Recompile and run compiled-doc boundary tests; do not publish new public docs. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / OTP | unit and contract tests | ✓, diagnostic only | Elixir 1.19.5 / OTP 28 | CI authority is Elixir 1.17 / OTP 27; do not use local toolchain as acceptance. [VERIFIED: local probe; `RUNNING.md`] |
| PostgreSQL CLI | DB-backed focused tests / integration | ✓ | 14.17 | Test repo configuration supplies test DB; CI integration uses Postgres 16. [VERIFIED: local probe; CI workflow] |
| Docker | MinIO/S3 integration reproduction | ✓ | 29.5.2 | Use CI MinIO lane if local setup is absent. [VERIFIED: local probe; CI workflow] |
| MinIO binary | live local S3 test direct invocation | ✗ | — | CI's setup action provides MinIO; mock and Local tests cover focused extraction locally. [VERIFIED: local probe; CI workflow] |

**Missing dependencies with no fallback:** None for planning. Local manual live-S3 execution needs CI-provided MinIO setup, but the repository retains CI integration coverage.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit / Ecto SQL Sandbox / Mox / Oban Testing. [VERIFIED: focused test modules] |
| Config file | `test/test_helper.exs`. [VERIFIED: repository] |
| Quick run command | `mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/broker_test.exs --seed 0` |
| Full phase suite | `mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/broker_test.exs test/rindle/upload/tus_local_backing_test.exs test/rindle/upload/lifecycle_integration_test.exs --include integration --seed 0` plus environment-provisioned S3 proof. |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UPLOAD-01 | protocol headers/statuses, token/authorization, no-read 409/415 gates, PATCH storage/persistence, DELETE order/marker, checksum/deferred/concatenation | unit/contract | `mix test test/rindle/upload/tus_plug_test.exs --seed 0` | ✅ |
| UPLOAD-01 | actual Local-backed append → finalization → broker completion | integration | `mix test test/rindle/upload/tus_local_backing_test.exs --seed 0` | ✅ |
| UPLOAD-01 | S3 multipart resume/DELETE/reaper behavior | integration (environment provisioned) | `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio --seed 0` | ✅ |
| UPLOAD-02 | all Broker public lifecycle result/error, capability, persistence compensation, telemetry and broadcast behavior | unit/contract | `mix test test/rindle/upload/broker_test.exs --seed 0` | ✅ |
| UPLOAD-02 | direct/multipart lifecycle through adapter and promotion job | integration | `mix test test/rindle/upload/lifecycle_integration_test.exs --include integration --seed 0` | ✅ |
| SAFE-01 | public API/docs, schema/migration, telemetry/errors and CI/release invariants | contract | `bash scripts/maintainer/refactor_contract.sh` | ✅ |

### Sampling Rate

- **Per extraction commit:** quick run command above, then the relevant individual module suite.
- **Per Tus/Broker slice:** full phase suite and `bash scripts/maintainer/refactor_contract.sh`.
- **Phase gate:** supported Elixir 1.17 / OTP 27 CI Summary green; local Elixir 1.19 / OTP 28 is diagnostic only. [VERIFIED: `AGENTS.md`; `RUNNING.md`; CI workflow]

### Wave 0 Gaps

- [ ] Add only an objective compiled-boundary assertion for the new hidden upload collaborators, if the API-surface test does not already cover them.
- [ ] Add only an observable parity test for any extraction seam not covered by current focused tests; never assert helper/source text.
- [ ] No framework or fixture installation gap.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Host-owned mount auth plus signed bearer URL verification; preserve no-token existence disclosure behavior. [VERIFIED: `TusPlug`; resumable guide] |
| V3 Session Management | yes | HMAC claims + expiry plus persisted session expiry/offset. [VERIFIED: `TusPlug`; `MediaUploadSession`] |
| V4 Access Control | yes | Optional `TusResumeAuthorizer.authorize/3` receives actor, token actor, session, profile, and method. [VERIFIED: `TusPlug`; tests] |
| V5 Input Validation | yes | strict protocol header/length/checksum/offset parsing and max size before storage mutation. [VERIFIED: `TusPlug`; tests] |
| V6 Cryptography | yes | Existing `Plug.Crypto.sign/verify`; do not implement custom signing. [VERIFIED: `TusPlug`] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Forged/tampered or expired upload URL | Spoofing | Verify token before session/storage access; retain 404/401 mapping. [VERIFIED: `TusPlug`; tests] |
| Offset race/replay causing overwrite | Tampering | Require exact persisted offset before body read; persist adapter-returned offset only after successful append. [VERIFIED: `TusPlug`; tests] |
| Oversized/body-memory exhaustion | Denial of service | fixed-size read loop and maximum-size checks; never buffer whole PATCH. [VERIFIED: `TusPlug`] |
| URI/credential disclosure | Information disclosure | session URI redaction plus telemetry metadata denylist; preserve log discipline. [VERIFIED: `MediaUploadSession`; `ResumableTelemetry`] |
| Orphaned multipart backing | Denial of service / cost leak | storage-first termination plus retryable marker selected by maintenance reaper. [VERIFIED: `TusPlug`; `UploadMaintenance`] |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| monolithic private implementations | façade plus narrowly scoped hidden collaborators (Phase 123 precedent) | Phase 123 | Use the same visibility and contract-preservation pattern, not a new abstraction framework. [VERIFIED: Phase 123 source/tests/research] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Candidate names such as `TusProtocol` and `Broker.Persistence` are recommended names, not mandatory module/file names. | Exact Responsibility Seams | Low: planner can choose fewer/better named internal modules so long as ownership/invariants hold. |
| A2 | A shared private broadcast helper is worthwhile only if it reduces duplicated exact mechanics without obscuring timing. | Exact Responsibility Seams | Medium: unnecessary extraction could make lifecycle ordering harder to trace. |

## Open Questions

1. **Which existing hidden-module allowlist should own the new collaborators?**
   - What we know: `api_surface_boundary_test.exs` explicitly locks visible and hidden docs boundaries, including Phase 123 collaborator modules. [VERIFIED: API-surface test]
   - What's unclear: it currently does not enumerate Upload collaborator names.
   - Recommendation: choose the minimal stable set during planning, add each only to the hidden boundary assertion, and do not expose them.

2. **Should broadcasts be deduplicated now?**
   - What we know: TusPlug and Broker currently duplicate the payload/topics exactly. [VERIFIED: both modules]
   - What's unclear: whether an extraction makes timing/ownership clearer rather than merely reducing lines.
   - Recommendation: treat it as optional; extract only after the protocol and broker-specific boundaries are independently clear.

## Sources

### Primary (HIGH confidence)

- `lib/rindle/upload/tus_plug.ex` — public façade, gate order, storage, response, token, termination and broadcast behavior.
- `lib/rindle/upload/broker.ex` — public lifecycle, capability, persistence, compensation, completion, telemetry and broadcasts.
- `test/rindle/upload/tus_plug_test.exs`, `broker_test.exs`, `tus_local_backing_test.exs`, `tus_s3_integration_test.exs`, `lifecycle_integration_test.exs` — observable preservation proof.
- `scripts/maintainer/refactor_contract.sh`, `RUNNING.md`, `.github/workflows/ci.yml` — supported CI and SAFE-01 authority.

### Secondary (MEDIUM confidence)

- [tus 1.0 protocol](https://tus.io/protocols/resumable-upload) — core/creation/expiration/checksum requirements used as a protocol cross-check.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependency; existing boundaries are directly inspected.
- Architecture: HIGH — seams, callers, persistence, and effects are all present in source and focused tests.
- Pitfalls: HIGH — failure/ordering cases are asserted by current contract, Local, and S3 test coverage.

**Research date:** 2026-08-22
**Valid until:** 2026-09-21 (internal codebase refactor scope; revisit on changed upload contracts)
