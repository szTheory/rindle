# Phase 121: Truthful Quality Signals & Mechanical Hygiene - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via `workflow.skip_discuss`)

<domain>
## Phase Boundary

Restore truthful contract, documentation-coverage, and curated Credo gates; remove only mechanically
proven residue; and establish the invariant regression contract every later v1.24 refactor must run.

</domain>

<decisions>
## Implementation Decisions

### the agent's Discretion
- Choose the smallest CI/test configuration changes that make deterministic failures blocking.
- Keep environment-dependent doctor and AV checks explicit and prerequisite-aware rather than globally
  blocking on machines that cannot satisfy them.
- Gate Credo warnings plus complexity/nesting and public docs/spec drift; keep low-value style suggestions
  advisory.
- Delete only residue proven unreferenced or byte-duplicated; preserve and reconcile any unique audit
  evidence before removing a duplicate-looking artifact.
- Build SAFE-01 from existing public-contract, telemetry, schema/migration, error-vocabulary, and
  CI/release-invariant tests rather than freezing incidental implementation text.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/ci.yml` already separates Contract, Proof, Quality, and package/adopter lanes.
- Existing install-smoke, docs-parity, telemetry-parity, migration, and error-vocabulary tests provide
  the ingredients for the SAFE-01 regression contract.
- `mix doctor`, Credo configuration, and `.dialyzer_ignore.exs` expose current quality-policy seams.

### Established Patterns
- `CI Summary` is the sole required check; skipped jobs count as pass and workflow names are release-train
  invariants.
- Behavior contracts are asserted from shipped artifacts or compiled metadata, not `.planning/` files.
- Maintenance changes use non-release-triggering commit types unless adopter-visible behavior changes.

### Integration Points
- Contract/Quality job step severity and tool prerequisites in `.github/workflows/ci.yml`.
- Doctor and Credo configuration in `mix.exs`, `.credo.exs`, and related regression tests.
- Root tracked residue, `.gitignore`, and canonical milestone audit locations under `.planning/milestones/`.

</code_context>

<specifics>
## Specific Ideas

Use the 2026-08-22 baseline evidence: the local Contract suite exposed stale public-event prose and an
FFmpeg `:enoent` prerequisite gap; Doctor measured 75.9% total docs and 83.8% specs while its test only
asserted configured thresholds; strict Credo produced actionable warnings/refactors mixed with AliasUsage
style noise. Preserve unique v1.8 audit evidence before any root audit removal.

</specifics>

<deferred>
## Deferred Ideas

Dialyzer baseline retirement belongs to Phase 126. Broad dependency/toolchain upgrades, Admin feature
work, historical archive rewrites, and subjective alias/style churn remain out of scope.

</deferred>
