# Phase 21: verify-02-hexdocs-reachability-probe - Context

**Gathered:** 2026-05-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the final v1.3 requirement gap for `VERIFY-02` by making docs reachability observable in CI. This phase adds a first-party HTTP probe for `https://hexdocs.pm/rindle/<version>` to the post-publish `public_verify` job, adds a parity assertion proving that probe stays wired, and updates the release runbook so the docs check remains part of the documented release contract.

Out of scope: changing publish semantics, redesigning the existing Hex.pm index wait, expanding `public_smoke.sh` into a docs probe, or broadening Phase 21 into general release-flow refactors already closed in Phases 16 and 20.
</domain>

<decisions>
## Implementation Decisions

### Workflow placement
- **D-01:** Add the hexdocs reachability check as its own step inside `public_verify`, after `Wait for Hex.pm index (post-publish)` and before `Verify public Hex.pm artifact`.

### Probe contract
- **D-02:** Probe `https://hexdocs.pm/rindle/$VERSION` as a public HTTP request that follows redirects and fails on final non-2xx status.
- **D-03:** Use `GET`, not `HEAD`, for the probe. Live checks on 2026-05-01 showed both `https://hexdocs.pm/rindle/0.1.4` and `https://hexdocs.pm/rindle` return `301` redirects to `/index.html`; a non-following or HEAD-only check would risk false negatives.

### Retry and backoff
- **D-04:** Reuse the same bounded propagation posture already trusted for `mix hex.info` indexing: keep the docs probe aligned to the existing 5-minute / 15-second retry window rather than introducing a materially different timeout policy.

### Verification and documentation
- **D-05:** Assert the probe through the existing install-smoke parity suite, primarily in `test/install_smoke/release_docs_parity_test.exs` and `test/install_smoke/package_metadata_test.exs`, not through a live network test.
- **D-06:** Update `guides/release_publish.md` in the same parity style as prior release changes so the step list and workflow-contract section both mention the docs reachability probe.

### the agent's Discretion
- Exact step name for the hexdocs probe, provided it stays clear in workflow logs and can be mirrored in parity tests.
- Exact `curl` flags and shell wording inside the probe loop.
- Whether the parity assertion lives entirely in `release_docs_parity_test.exs` or is split between that file and `package_metadata_test.exs`, so long as the workflow wiring is explicitly gated.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and closure routing
- `.planning/ROADMAP.md` — Phase 21 goal, success criteria, and explicit routing of `VERIFY-02`
- `.planning/REQUIREMENTS.md` — `VERIFY-02` requirement text and pending traceability state
- `.planning/v1.3-MILESTONE-AUDIT.md` — G4 definition and the recommended first-party `hexdocs.pm` HTTP probe closure

### Prior phase context
- `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-CONTEXT.md` — prior release-path decisions and single-source-of-truth runbook discipline
- `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-VERIFICATION.md` — `VERIFY-02` marked `SATISFIED (functional)` with `forward_reference: phase-21`
- `.planning/phases/20-v1.3-verification-and-metadata-closure/20-CONTEXT.md` — explicit Phase 21 ownership of the hexdocs reachability probe
- `.planning/phases/20-v1.3-verification-and-metadata-closure/20-VERIFICATION.md` — confirms `VERIFY-02` was intentionally left pending for Phase 21

### Implementation targets
- `.github/workflows/release.yml` — existing `public_verify` job, Hex.pm index wait, and public artifact verification chain
- `guides/release_publish.md` — maintainer runbook that must stay in parity with the live workflow
- `test/install_smoke/release_docs_parity_test.exs` — release-guide/workflow parity gate
- `test/install_smoke/package_metadata_test.exs` — workflow topology and public verification wiring assertions
- `scripts/public_smoke.sh` — current public package verification script; boundary reference for what this phase should not absorb
- `scripts/assert_release_docs_html.sh` — existing first-party docs HTML assertion pattern in local build/test context
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `public_verify` in `.github/workflows/release.yml` already owns the public-facing verification chain on a fresh runner.
- `test/install_smoke/release_docs_parity_test.exs` already enforces workflow step-name and command parity against `guides/release_publish.md`.
- `test/install_smoke/package_metadata_test.exs` already asserts `public_verify` topology and key workflow snippets.
- `scripts/assert_release_docs_html.sh` shows an existing first-party pattern for asserting generated docs artifacts and release-doc navigation.

### Established Patterns
- The release workflow separates `publish` from `public_verify`; public checks happen after the protected publish lane, not inside it.
- The current Hex.pm propagation contract is a bounded 5-minute wait with 15-second polling in `Wait for Hex.pm index (post-publish)`.
- Release workflow changes are mirrored into `guides/release_publish.md` and guarded by install-smoke parity tests rather than ad hoc prose updates.
- Focused shell-probe harnesses exist when a standalone script is warranted (`scripts/hex_release_exists.sh`), but this phase does not require a new standalone script by default.

### Integration Points
- `public_verify` should gain one new docs-reachability step between the existing index wait and `bash scripts/public_smoke.sh "$VERSION"`.
- The runbook’s routine step list and workflow contract need to mention the new probe so parity remains green.
- The parity tests need explicit assertions for the new docs probe so future workflow drift fails CI before release time.
</code_context>

<specifics>
## Specific Ideas

- On 2026-05-01, direct checks showed `https://hexdocs.pm/rindle/0.1.4` returns `301` to `https://hexdocs.pm/rindle/0.1.4/index.html`, and `https://hexdocs.pm/rindle` returns `301` to `https://hexdocs.pm/rindle/index.html`.
- That makes redirect-following HTTP verification the safe default; a raw initial-response `2xx` check would be too strict for the live host behavior.
- The docs probe should stay public-path oriented and separate from package-install smoke so `VERIFY-02` closes as an explicit observability check, not an inferred side effect.

</specifics>

<deferred>
## Deferred Ideas

- If docs propagation proves materially slower than Hex index propagation in real releases, revisit whether the docs probe needs a separate retry envelope in a future phase. That is not pre-decided here.
- If maintainers later want stronger encapsulation, a dedicated shell helper for the hexdocs probe could be introduced in a future cleanup pass. This phase does not require a new script by default.

### Reviewed Todos (not folded)
None — `gsd-sdk query todo.match-phase 21` returned 0 matches.
</deferred>

---

*Phase: 21-verify-02-hexdocs-reachability-probe*
*Context gathered: 2026-05-01*
