# Phase 123: Runtime Operations Decomposition - Context

**Gathered:** 2026-08-23 (assumptions mode, auto-resolved)
**Status:** Ready for planning

<domain>
## Phase Boundary

Decompose the three enumerated runtime-operations hotspots—runtime diagnostics, populated-install
migration preflight, and runtime-status reporting—into cohesive internal responsibilities while
preserving every public API, schema/migration effect, telemetry event and metadata field, error shape,
operator-visible output, filter, limit, and refusal boundary.

</domain>

<decisions>
## Implementation Decisions

### Runtime diagnostics
- **D-123-01:** Keep `Rindle.Ops.RuntimeChecks.run/2` as the sole orchestration, aggregation, ordering,
  and telemetry boundary. Extract internal collaborators by diagnostic domain: core profile/delivery
  runtime, migration/ownership/Oban, and optional GCS/tus/streaming integrations.
- **D-123-02:** Keep the shared result constructors, per-check telemetry wrapper, final ID sort, and
  report aggregation together at the orchestration boundary. Do not introduce a configurable registry
  or independently public check APIs.

### Migration preflight
- **D-123-03:** Keep `Rindle.Migration.V1` authoritative for the fixed six-table-plus-marker catalog,
  DDL, directional move order, transactions, and the existing hidden preflight entry points.
- **D-123-04:** Extract only snapshot inspection and directional validation/classification into named
  bounded internals. Prefer one explicit shared classifier parameterized by direction when it preserves
  the current ordered refusal precedence; otherwise use two thin directional validators over shared
  predicates. The relation catalog and move sequence must never become configurable or duplicated.

### Runtime status and command presentation
- **D-123-05:** Keep `Rindle.Ops.RuntimeStatus.runtime_status/1` as the API orchestration boundary for
  filter validation, readiness-before-query refusal, report composition, recommendation composition,
  and refusal telemetry. Extract cohesive internal collectors and classifiers without exposing new
  public APIs.
- **D-123-06:** Separate runtime-status text/JSON and error presentation from
  `Mix.Tasks.Rindle.RuntimeStatus` command parsing and exit behavior. Preserve exact report fields,
  section order, JSON/text shapes, redaction, flags, limits, and non-zero failure semantics.

### Sequencing and proof
- **D-123-07:** Execute one surface at a time: runtime checks, migration preflight, then runtime-status
  API/formatting/task. Each slice must pass its focused behavioral and telemetry contracts plus SAFE-01
  before the next surface begins.
- **D-123-08:** Add objective behavior, telemetry, compiled-boundary, and structural tests only where
  current proof is insufficient. Do not freeze incidental source text, split helpers solely by line
  count, or broaden this phase into upload, test-support, dependency, Admin, or type-baseline work.

### The agent's Discretion
- Exact private module names and the smallest internal data structures, provided responsibility names
  remain domain-readable and the locked orchestration boundaries stay intact.
- Whether migration direction is represented by one shared classifier or two thin directional modules,
  decided from the simplest structure that makes refusal precedence obvious and non-duplicated.
- Test file placement and narrowly scoped structural assertions that prove dependency direction without
  coupling to function-body strings.

### Folded Todos

None; the phase todo matcher returned no relevant pending items.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/PROJECT.md` — v1.24 finite maintenance charter and decide-by-default contract.
- `.planning/REQUIREMENTS.md` — OPS-01, OPS-02, OPS-03, and SAFE-01 acceptance boundaries.
- `.planning/ROADMAP.md` — Phase 123 goal and success criteria.
- `.planning/phases/121-truthful-quality-signals-mechanical-hygiene/121-CONTEXT.md` — SAFE-01 and
  truthful-gate decisions.
- `.planning/phases/122-live-truth-compile-clarity/122-CONTEXT.md` — behavior-backed structural proof
  and no-churn decisions.
- `scripts/maintainer/refactor_contract.sh` — inherited preservation gate.
- `lib/rindle/ops/runtime_checks.ex` and `test/rindle/ops/runtime_checks_test.exs` — diagnostic
  orchestration, result, ordering, and core behavior authority.
- `test/rindle/ops/runtime_checks_streaming_test.exs` — optional streaming checks and telemetry authority.
- `lib/rindle/migration/v1.ex` and `test/rindle/migration_test.exs` — catalog, preflight refusal,
  transaction, move order, and reversal authority.
- `lib/rindle/ops/runtime_status.ex` and `test/rindle/ops/runtime_status_test.exs` — readiness, collection,
  classification, filter, redaction, limit, recommendation, and telemetry authority.
- `lib/mix/tasks/rindle.runtime_status.ex` and `test/rindle/runtime_status_task_test.exs` — command flags,
  formatting, output order, error rendering, and exit semantics authority.
- `test/rindle/api_surface_boundary_test.exs` and `test/rindle/contracts/telemetry_contract_test.exs` —
  public/internal surface and telemetry contract authority.

No external specs are required; repository behavior and contracts fully define this refactor.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RuntimeChecks.run/2` already provides one deterministic assembly point for dependencies, conditional
  checks, telemetry, sorting, and report totals; the extraction should make that existing shape visible.
- `Migration.V1` already has a shared migration snapshot and predicate vocabulary beneath two ordered
  preflight classifiers; these are the natural internal validation seam.
- `RuntimeStatus.runtime_status/1` already gates readiness before reporting and the Mix task already
  centralizes command-facing presentation, giving collection and formatter seams without an API redesign.
- Focused tests freeze stable check IDs, telemetry, refusal-before-query/mutation, relation ownership,
  output order, redaction, filters, limits, rollback, and exit status.

### Established Patterns
- Public façades remain small while internal domain modules own focused mechanics; extraction is not an
  invitation to add public APIs.
- Boundary modules assemble deterministic results; leaf modules return explicit data and avoid hidden
  ordering or telemetry side effects.
- SAFE-01 runs after every refactor slice, and structural proof uses module/API boundaries or behavior
  rather than self-inspecting implementation strings.
- Maintenance delivery uses non-release-triggering `chore:` PR titles unless adopter-visible behavior
  actually changes.

### Integration Points
- Runtime doctor task and Admin runtime doctor consume `RuntimeChecks` report IDs/order/shapes.
- `Rindle.Migration` dispatches to `Migration.V1`; host migrations rely on the exact existing entry points
  and transactional effects.
- `Rindle.runtime_status/1`, the Mix task, Admin operator surfaces, Ecto/Oban queries, and refusal telemetry
  all meet at the runtime-status orchestration boundary.

</code_context>

<specifics>
## Specific Ideas

Optimize for code that reads top-down like a short operational narrative: resolve input, verify readiness,
delegate by domain, assemble one stable result. Names should explain the operational responsibility; comments
should remain only where they preserve non-obvious safety rationale or refusal precedence.

</specifics>

<deferred>
## Deferred Ideas

Upload/tus and broker decomposition remains Phase 124; generated-app and documentation test-support work
plus async issue #42 remains Phase 125; Dialyzer baseline retirement remains Phase 126. Public API changes,
schema or migration redesign, telemetry/error changes, dependency upgrades, Admin feature work, archive
normalization, and style-only churn remain out of scope.

### Reviewed Todos (not folded)

None.

</deferred>
