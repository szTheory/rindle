# Phase 118: Isolated Migration & Safe Upgrade - Context

**Gathered:** 2026-08-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Make fresh Rindle installs provision the selected `rindle` schema and provide a host-owned, data-preserving path that moves exactly the six Rindle tables plus `rindle_migration_versions` from `public` to `rindle`. The phase must fail safely on mixed, incomplete, or insufficient-permission states. It must never take ownership of Oban, the host migration ledger, arbitrary schemas, or live/dual-write cutovers.

</domain>

<decisions>
## Implementation Decisions

### Migration API and ownership

- **D-118-01:** Keep the established host-migration wrapper model. Fresh installs call `Rindle.Migration.up(version: 1)`, which defaults to `rindle`; the only explicit compatibility pairing is `prefix: "public"`. Align migration option validation with the Phase 117 two-value compile-time authority (`"rindle" | "public"`), removing the prior arbitrary-prefix contract. — **Reversibility:** one-way — changing the supported configuration/migration pairing after 0.4.0 would break adopter migration and runtime contracts.
- **D-118-02:** Add a deliberately narrow, version-pinned public upgrade primitive such as `Rindle.Migration.move_public_to_rindle(version: 1)`, invoked from an adopter-owned Ecto migration. Rindle owns the exact seven-relation allowlist, preflight, identifier quoting, and move behavior; the host owns when it runs, deployment order, its Ecto ledger, and operational rollback choice. Do not expose a generic `move(from:, to:)` schema-management API. — **Reversibility:** costly — widening or replacing this public upgrade API would expand its support and migration compatibility surface.
- **D-118-03:** Extend the existing `Rindle.Migration.V1` authority rather than creating a parallel migration manager. Reuse its authoritative owned-table list, idempotent DDL, marker behavior, and identifier-quoting boundary.

### Safe move preflight and execution

- **D-118-04:** Allow the public-to-`rindle` move only when all six Rindle tables and `rindle_migration_versions` are present in `public` and none are present in `rindle`. Treat a complete source plus complete/partial target, partial source, invalid/misplaced marker, unexpected Rindle-owned relation, unusable target schema, or inadequate privileges as a bounded failure before issuing any move. A complete `rindle` set with no public set may be an idempotent already-upgraded result; neither complete set is a fresh-install case and must not be guessed at.
- **D-118-05:** Provision `rindle` idempotently before fresh table DDL; use one internal validated-and-quoted identifier boundary for DDL and bound values for catalog checks. Never rely on `search_path`, permissive arbitrary prefixes, `IF EXISTS` to mask mixed state, or dynamically interpolated unvalidated identifiers.
- **D-118-06:** Use `ALTER TABLE ... SET SCHEMA` for the fixed Rindle relation set inside the host migration transaction. It is the narrow data-preserving route because PostgreSQL moves owned indexes, constraints, and sequences with the table. Never enumerate, create, move, drop, or configure `oban_jobs` or the host `schema_migrations` ledger. — **Reversibility:** one-way — the database move changes an adopter's persisted layout and published 0.4.0 migration path.

### Operations, rollback, and developer experience

- **D-118-07:** Document and enforce a maintenance-window posture: operators back up, stop/drain Rindle writers and workers, run the host migration with a transaction-local lock timeout, deploy the compile-time `rindle` build, then verify. Ecto's migration lock serializes migrators but does not quiesce application traffic; PostgreSQL `ALTER TABLE` can require `ACCESS EXCLUSIVE` locking.
- **D-118-08:** Provide a separately guarded reverse primitive such as `move_rindle_to_public(version: 1)` for the host migration's `down`, only while the app is quiesced and state remains exactly reversible. It must not drop the `rindle` schema. `Rindle.Migration.down/1` remains destructive and must never be presented as an upgrade rollback. — **Reversibility:** one-way — safe use depends on backup, no post-move writes/later migrations, and redeploying the prior public-compiled release.
- **D-118-09:** Make error and docs copy calm, concrete, and operator-directed: state what was found, what Rindle will not touch, and the one next action. Use verbs such as “prepare maintenance window,” “move Rindle tables,” and “verify Rindle schema”; do not promise a seamless or automatic live migration. The adopter job is a safe, copy-pasteable host migration—not a migration DSL or hidden library state.

### Proof boundary and handoffs

- **D-118-10:** Prove fresh `rindle` provisioning, explicit `public` compatibility, populated relational move integrity (rows, foreign keys, indexes, marker), all refusal-state categories, injected transaction failure, lock contention/timeout, and untouched `public.oban_jobs` plus host ledger. Keep the normal public-compiled test suite stable and use an isolated/default-build proof for fresh default provisioning.
- **D-118-11:** Update migration API documentation and the migration snippets/parity expectations made false by the default flip in this phase. Phase 120 retains packed generated-app/Cohort proof, complete release-facing documentation parity, and 0.4.0 release notes; Phase 119 retains separate-prefix diagnostics and raw-SQL/Oban boundary hardening.

### the agent's Discretion

- Pick exact function/module names, internal catalog-query shape, lock-timeout value/configuration pattern, and bounded error wording, provided they preserve the locked narrow API, state machine, and ownership boundary above.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current milestone contract
- `.planning/ROADMAP.md` §Phase 118 — locked goal, requirements, success criteria, and Phase 119/120 boundary.
- `.planning/REQUIREMENTS.md` §Migration & Upgrade — MIGRATE-01 through MIGRATE-03 and explicit exclusions.
- `.planning/STATE.md` §Next Step and §v1.23 roadmap — current phase handoff and the Phase 117 routing dependency.
- `.planning/continue.md` — current operator handoff; do not execute before planning and preserve explicit non-goals.
- `.planning/v1.23-MILESTONE-AUDIT.md` — verified cross-phase gaps and the existing migration/runtime mismatch.

### Architecture and prior research
- `.planning/research/v1.23-SCHEMA-ISOLATION-SYNTHESIS.md` — chosen narrow PostgreSQL move, ownership boundary, security constraints, acceptance-proof matrix, and sibling-library lessons.
- `.planning/phases/117-prefix-routing-architecture/117-VERIFICATION.md` — passed compile-time `rindle`/`public` routing authority that Phase 118 must pair with provisioning, not replace.
- `.planning/phases/117-prefix-routing-architecture/117-02-SUMMARY.md` — selected/decoy-schema testing pattern and Phase 118 readiness notes.

### Code and test integration points
- `lib/rindle/migration.ex` — public versioned migration wrapper and current default contract.
- `lib/rindle/migration/options.ex` — validation boundary that must align with `Rindle.Schema`.
- `lib/rindle/migration/v1.ex` — authoritative six-table/marker ownership list, idempotent DDL, and quoting helpers to extend.
- `lib/rindle/schema.ex` — compile-time two-prefix routing authority.
- `test/rindle/migration_test.exs` — existing DDL integration harness to extend.
- `test/support/schema_prefix_case.ex` — isolated selected/decoy schema fixture pattern.

### Experience and product posture
- `prompts/rindle-brand-book.md` §§Calm developer experience, Brand voice, Documentation tone — canonical DX/microcopy posture: strict defaults, explicit escape hatches, visible state, and honest footguns.
- `prompts/gsd-rindle-research-index.md` — provenance and precedence of prompt-era research; bootstrap material cannot override current v1.23 decisions.
- `prompts/gsd-rindle-elixir-oss-dna.md` — public API discipline, NimbleOptions, named footguns, host-install truth, and layered proof patterns.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Migration.V1`: fixed owned relation list, idempotent schema DDL, marker state, prefix-aware references/indexes, and quoted identifiers.
- `Rindle.Migration.Options`: existing NimbleOptions boundary to restrict to the supported routing contract.
- `Rindle.MigrationTest`: `Ecto.Migration.Runner` DDL harness and catalog helpers for real Postgres integration proof.
- `Rindle.SchemaPrefixCase`: serial, sandbox-owned selected/decoy schema setup without `search_path` mutation.

### Established Patterns
- Host applications own normal Ecto migrations and shared Oban setup; Rindle provides pinned versioned helpers for Rindle-owned state only.
- `Rindle.Schema` is the sole internal compile-time authority for the six domain schemas and supports exactly `rindle` and `public`.
- Dynamic DDL uses quoted identifiers; catalog values use bound query parameters.

### Integration Points
- `Rindle.Migration.up/1`, `down/1`, `Options`, and `V1` need coherent default/validation/provisioning/upgrade behavior.
- Migration tests and schema-prefix fixtures must cover fresh, compatibility, populated move, guardrail, and contention behavior without destabilizing the public-compiled suite.
- Migration docs/snippet tests must reflect only shipped Phase 118 behavior; later packaged-adopter and full release truth stays with Phase 120.

</code_context>

<specifics>
## Specific Ideas

- Follow the ecosystem pattern of a host-owned migration calling a narrow versioned library helper, comparable to Oban's migration integration style.
- PostgreSQL `ALTER TABLE ... SET SCHEMA` preserves a moved table's associated indexes, constraints, and owned sequences but requires a maintenance window and appropriate ownership/`CREATE` privilege.
- UI/visual design is not in scope. The applicable UX surface is API, error, and documentation design for Phoenix product developers, platform developers, and operators.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 118-Isolated Migration & Safe Upgrade*
*Context gathered: 2026-08-09*
