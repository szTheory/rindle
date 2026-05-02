# Phase 12: Public Verification and Release Operations - Context

**Gathered:** 2026-04-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

First public `Hex.pm` publish readiness and execution path; Reusable release automation around the publish flow; Docs and package-consumer verification aligned with the published artifact.
</domain>

<decisions>
## Implementation Decisions

### Public Verification Execution
- **D-01:** The consumer verification step will fetch Rindle from the public Hex.pm registry via standard `mix deps.get` network resolution, completely replacing the local `path:` dependency override used in current smoke tests. A polling/retry mechanism (up to 5 minutes) must be implemented to handle Hex.pm indexing delay.

### Verification Environment Isolation
- **D-02:** The post-publish verification will run in a pristine environment without the `HEX_API_KEY` or local repository state to simulate an anonymous user.

### Release Rollback Mechanics
- **D-03:** Package rollback and revert procedures will be manual maintainer actions documented in the runbook, rather than automated CI rollback jobs. The runbook will specify the 1-hour revert window (24h for first release) and document that reverted versions can be reused.

### Runbook Distribution Strategy
- **D-04:** The updated maintainer runbook (including rollback paths) will continue to be shipped as a public HexDoc page, but actively fenced off from the canonical adopter onboarding flow.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` (Phase 12)
- `.planning/REQUIREMENTS.md`
- `scripts/release_preflight.sh`
- `guides/release_publish.md`
- `test/install_smoke/generated_app_smoke_test.exs`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/release_preflight.sh` and `scripts/assert_release_docs_html.sh` provide the foundation for preflight checks.
- `test/install_smoke/generated_app_smoke_test.exs` implements the package smoke testing logic that must be adapted for public registry resolution.

### Established Patterns
- `guides/release_publish.md` establishes the manual metadata checks and owner-assignment processes.
- `.github/workflows/release.yml` restricts `HEX_API_KEY` specifically to the publish step, establishing the pattern for strict credential scoping.

### Integration Points
- Integration with Hex.pm registry for `mix deps.get` resolution.
- Verification workflows will integrate cleanly as a subsequent step or workflow after the live publish step in `.github/workflows/release.yml`.
</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches
</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope
</deferred>
