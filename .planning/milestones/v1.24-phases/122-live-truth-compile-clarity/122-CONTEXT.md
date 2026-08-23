# Phase 122: Live Truth & Compile Clarity - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via `workflow.skip_discuss`; user approved recommendations)

<domain>
## Phase Boundary

Replace obsolete planning-era commentary in live code and tests with durable domain rationale, reconcile
current maintainer/adopter documentation with shipped behavior, and remove the `Rindle.Schema` compile
cycle without changing any public or persistence contract.

</domain>

<decisions>
## Implementation Decisions

### The agent's Discretion
- Treat `lib/`, `test/`, current guides, root docs, scripts, and active workflows as live truth; leave
  `.planning/milestones/**` and other historical planning archives unchanged.
- Rewrite only comments or assertions that are obsolete, forward-looking, or coupled to a Phase/Plan;
  preserve useful rationale by expressing the domain invariant directly.
- Reconcile CI lane names/severity, supported toolchain posture, Admin navigation labels, and shipped tus
  and streaming behavior against executable code and workflow truth.
- Break the schema cycle at the internal caller-allowlist dependency while retaining the macro boundary,
  supported prefixes, compile-time validation, exception semantics, compiled schema metadata, and struct
  metadata.
- Add objective regression proof for zero compile cycles and extend current parity/SAFE-01 contracts rather
  than adding brittle source-string snapshots of incidental implementation.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/maintainer/refactor_contract.sh` already aggregates the behavior-preservation suites required
  by SAFE-01.
- `test/rindle/schema_prefix_contract_test.exs` and the public-prefix integration probes already freeze
  macro ownership, caller rejection, supported-prefix, compiled metadata, and runtime-immutability behavior.
- Current install-smoke documentation parity suites already own CI, release, tus, streaming, and Admin
  truth assertions.

### Established Patterns
- Behavior contracts use observable behavior, compiled metadata, or explicit structural boundaries; they
  do not read `.planning/` as runtime truth.
- `CI Summary` remains the sole required check, skipped jobs count as pass, and release workflow topology
  is immutable in this phase.
- Maintenance commits are non-release-triggering unless adopter-visible behavior changes.

### Integration Points
- The baseline command `mix xref graph --format cycles --label compile-connected --fail-above 0` reports
  one seven-file cycle: `lib/rindle/schema.ex` plus the six Rindle-owned domain schemas.
- `Rindle.Schema` currently names those six modules in its internal allowlist while each schema uses the
  macro, creating the reverse compile edges.
- Live planning residue is present across source/test comments and several tests still describe already
  shipped work as EXPECTED RED or future Plan work.

</code_context>

<specifics>
## Specific Ideas

Prefer a non-module-reference representation for the six internal caller identities so the allowlist
continues to fail closed without teaching `Rindle.Schema` compile-time dependencies on its consumers. Lock
the result with the xref failure threshold plus the existing default/public schema probes and SAFE-01.

</specifics>

<deferred>
## Deferred Ideas

Runtime-operations decomposition belongs to Phase 123, upload-path decomposition to Phase 124, test-support
rearchitecture and async issue #42 to Phase 125, and Dialyzer retirement to Phase 126. Broad style churn,
dependency upgrades, Admin feature redesign, and historical archive normalization remain out of scope.

</deferred>
