# Phase 124: Upload Path Clarity - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Decompose the internal tus request path and upload-broker orchestration into cohesive responsibility
boundaries. Preserve every shipped Plug/protocol response, resumability rule, storage-adapter effect,
public broker API, persistence transition, telemetry event, error term, and broadcast contract.

</domain>

<decisions>
## Implementation Decisions

### the agent's Discretion
- Choose the smallest internal collaborator boundaries that make request parsing, protocol validation,
  storage effects, response construction, broker validation, capability negotiation, persistence, and
  completion orchestration independently readable.
- Prefer behavior-backed characterization and parity tests over source-text snapshots.
- Keep `Rindle.Upload.TusPlug` and `Rindle.Upload.Broker` as the public facades; new collaborators are
  internal and must not expand the documented public API.
- Avoid abstraction for line-count reduction alone. Extract only cohesive mechanics with a clear owner.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Upload.ResumableTelemetry` already centralizes the resumable telemetry vocabulary.
- `Rindle.Security.UploadValidation`, `Rindle.TusResumeAuthorizer`, storage adapters, and the upload FSM
  remain established policy owners and should be composed rather than duplicated.
- Phase 123's facade-plus-internal-collaborator pattern provides a recent decomposition precedent while
  preserving result construction and public entry points at the facade.

### Established Patterns
- Public modules retain stable function signatures while `@moduledoc false` collaborators own cohesive
  mechanics behind them.
- Contract tests lock public API, telemetry vocabulary/order, error shapes, and schema/migration surfaces.
- Supported Elixir 1.17 / OTP 27 CI Summary is authoritative; local Elixir 1.19 / OTP 28 is diagnostic.

### Integration Points
- `lib/rindle/upload/tus_plug.ex` currently owns Plug dispatch plus parsing, validation, streaming,
  persistence, storage completion/abort, response construction, and broadcasts.
- `lib/rindle/upload/broker.ex` currently owns all public session operations plus validation, capability
  negotiation, persistence, compensation, completion, telemetry, and broadcasts.
- Focused proof lives in `test/rindle/upload/tus_plug_test.exs`, local/S3 tus integration tests,
  `test/rindle/upload/broker_test.exs`, lifecycle integration tests, API-surface tests, and telemetry
  contract tests.

</code_context>

<specifics>
## Specific Ideas

This is a finite readability ratchet: make the two upload paths a joy to trace without changing what
adopters can call or observe. The strongest outcome is less cognitive load with byte-/term-equivalent
external behavior, not a target module count or arbitrary line-count goal.

</specifics>

<deferred>
## Deferred Ideas

No new tus protocol features, richer uploader abstractions, GCS-as-tus backend, storage behavior,
schema changes, or public API redesign. Those remain outside the v1.24 maintenance charter.

</deferred>
