# Phase 1: Foundation - Context

**Gathered:** 2026-04-24 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the queryable data model, behaviour contracts, and security primitives so all later phases build on a correct substrate.

</domain>

<decisions>
## Implementation Decisions

### Runtime Ownership
- **D-01:** Rindle remains adopter-repo-first. `Rindle.Repo` is a local test/dev harness for this repository and not a runtime ownership model for consumers.

### Foundation Execution Order
- **D-02:** Phase 1 work prioritizes substrate-first sequencing: migrations/schemas and state transitions first, then behaviour contracts and profile DSL, with minimal public facade expansion until invariants are stable.

### Security and Storage Contracts
- **D-03:** Storage contracts must keep storage side effects out of DB transactions and expose backend capabilities explicitly.
- **D-04:** Security primitives in Phase 1 are mandatory: magic-byte MIME detection, extension/MIME/size/pixel allowlist enforcement, and deterministic non-user-controlled storage key generation.

### Dependency Baseline
- **D-05:** Phase 1 includes dependency baseline alignment needed by the foundation scope (Oban, Image/Vix, S3 adapter deps, MIME detection dep) so Phase 2 is not blocked by stack churn.

### Claude's Discretion
- Exact module layout under `lib/rindle/` as long as boundaries remain clear between domain schemas/FSMs, behaviour contracts, and adapters.
- Internal naming/details for helper modules that do not change public behaviour contracts or violate security/runtime ownership constraints.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope and Constraints
- `.planning/ROADMAP.md` — Phase 1 goal, dependency boundary, and success criteria.
- `.planning/REQUIREMENTS.md` — Locked requirement set for schema/state machine/behaviour/security/storage/config/error requirements in Phase 1.
- `.planning/PROJECT.md` — Core value, hard constraints, and key architectural decisions that must carry into implementation.
- `.planning/STATE.md` — Current progress state, pre-phase decisions, and pending constraints relevant to planning.

### Research Baseline
- `.planning/research/SUMMARY.md` — Consolidated architecture and stack recommendations for the full milestone.
- `.planning/research/ARCHITECTURE.md` — Target module boundaries and lifecycle patterns (transactional enqueueing, async purge, atomic promote).
- `.planning/research/STACK.md` — Dependency recommendations and version alignment rationale.
- `.planning/research/PITFALLS.md` — Known failure modes to avoid while implementing foundation contracts.
- `.planning/research/FEATURES.md` — Feature/dependency landscape and phase fit.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/rindle/repo.ex`: Existing Ecto repo harness with Postgres adapter and `:rindle` OTP app wiring.
- `config/config.exs`: Existing `ecto_repos` and migration defaults (`binary_id`, `utc_datetime_usec`) that Phase 1 migrations should align with.
- `lib/rindle/application.ex`: Supervisor bootstrap point that can host future infrastructure wiring without changing app startup model.
- `lib/rindle.ex`: Public module shell with module docs/version helper, suitable as stable facade entry point while internals expand.

### Established Patterns
- The repository currently favors a minimal public API surface and incremental layering under `lib/rindle/`.
- Runtime DB config is environment-driven in host-style config (`config/runtime.exs`) and should not be replaced with library-owned runtime credential management.
- Migrations are configured for binary primary keys and UTC microsecond timestamps, indicating expected schema conventions.

### Integration Points
- New Phase 1 domain schemas and FSM logic should connect through `Rindle.Repo` and existing Ecto config conventions.
- Behaviour contracts should be consumed by future adapters in `lib/rindle/` and by later upload/processing/delivery modules.
- Profile DSL and validation primitives should integrate cleanly with the eventual public `Rindle` facade and future worker orchestration.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-04-24*
