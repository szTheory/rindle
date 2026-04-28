# Phase 11: Protected Publish Automation - Context

**Gathered:** 2026-04-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn the existing guarded release workflow into a real `Hex.pm` publish path that reuses the already-proved package, docs, and package-consumer gates while keeping the write credential and release trigger path narrowly controlled.

</domain>

<decisions>
## Implementation Decisions

### Publish Credential Boundary
- **D-01:** Phase 11 wires the real `HEX_API_KEY` only through the existing GitHub Actions `release` environment on the current release job. It does not introduce a repo-level secret, a second publish workflow, or a local-maintainer-only publish dependency for the automated path.

### Preflight Reuse and Fail-Fast Gating
- **D-02:** The live publish step stays downstream of `scripts/release_preflight.sh` in the existing release workflow. Package metadata checks, release-doc parity, package-consumer install smoke, docs generation, and generated-doc assertions remain must-pass gates before any networked publish attempt.
- **D-03:** Phase 11 must reuse the same preflight path already exercised in PR CI and release preflight rather than re-implementing or partially duplicating those checks in a publish-only branch of the workflow.

### Trigger Surface and Release Entry Path
- **D-04:** The protected publish path stays on the existing release workflow entrypoints: `workflow_dispatch` and `v*` tag pushes. Phase 11 should not broaden publish execution to PRs, normal branch pushes, or a separate automation lane.
- **D-05:** Environment protections remain part of the release contract. Planning should assume the `release` environment is configured with explicit branch/tag restrictions and reviewer gating so the workflow cannot access publish credentials from an unapproved or out-of-policy ref.

### Version Source and Publish Semantics
- **D-06:** `mix.exs` remains the release version source of truth. The release workflow publishes the version already declared there and preserves the maintainer runbook sequence: update from `-dev` to the release version, create the matching tag, publish, then bump `main` back to the next `-dev` version.
- **D-07:** The live publish command should be the full `mix hex.publish --yes` path so package and docs publish together. `mix hex.publish package` remains the package-only/dry-run path, not the real release command.

### the agent's Discretion
- Exact workflow step layout after preflight, as long as the real publish remains strictly downstream of the shared gate.
- Whether to add workflow-level `concurrency` or additional guard assertions around tag/version alignment, as long as they strengthen the protected single-lane publish model.
- Exact helper-script/test split for validating publish-only conditions that are not already covered by Phase 10 preflight.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and locked requirements
- `.planning/ROADMAP.md` — Phase 11 goal, success criteria, dependency on Phase 10, and the two-plan split.
- `.planning/REQUIREMENTS.md` — `RELEASE-06` and `RELEASE-07`.
- `.planning/PROJECT.md` — v1.2 milestone intent, narrow release focus, and the remaining public-release trust gap.
- `.planning/STATE.md` — current decision preference, pending release-oriented todos, and milestone position.

### Prior decisions that constrain Phase 11
- `.planning/milestones/v1.0-phases/05-ci-1-0-readiness/05-CONTEXT.md` — release-lane posture, manual/tag-triggered release entry, and secret-exposure constraints.
- `.planning/milestones/v1.1-phases/07-multipart-uploads/07-CONTEXT.md` — established rule that capability/policy enforcement stays above primitives and should remain explicit.
- `.planning/milestones/v1.1-phases/09-install-release-confidence/09-CONTEXT.md` — package-consumer smoke/release gate split and the requirement that release-time checks reuse the same trusted install path.

### Phase 10 artifacts Phase 11 builds on
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-RESEARCH.md` — research findings that Phase 10 stops short of live publish automation and that full `mix hex.publish` is needed for docs publication.
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-01-PLAN.md` — maintainer runbook and version/owner expectations that Phase 11 must preserve.
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-02-PLAN.md` — release preflight contract and explicit deferment of live credential wiring to Phase 11.
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md` — delivered maintainer-facing release guide and parity coverage.
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-02-SUMMARY.md` — delivered shared preflight gate, docs-warning cleanup, and release workflow posture.

### Existing code and workflow surface
- `.github/workflows/release.yml` — current protected release lane, environment boundary, trigger shape, and dry-run placeholder seam.
- `.github/workflows/ci.yml` — existing PR-side package-consumer + release-preflight reuse that the real publish path must stay aligned with.
- `scripts/release_preflight.sh` — current must-pass preflight sequence.
- `scripts/install_smoke.sh` — shared package-consumer proof used by preflight.
- `test/install_smoke/package_metadata_test.exs` — packaged metadata and tarball assertions.
- `test/install_smoke/release_docs_parity_test.exs` — release guide and maintainer-doc boundary contract.
- `scripts/assert_release_docs_html.sh` — generated-doc HTML assertions reused by preflight.
- `guides/release_publish.md` — maintainer release sequence and owner/auth/version policy that automation must honor.
- `mix.exs` — current package metadata, docs extras, and version source of truth.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/release.yml`: already owns the protected release lane, `release` environment binding, and current dry-run publish seam.
- `scripts/release_preflight.sh`: already serializes package build, metadata checks, maintainer-doc parity, package-consumer install smoke, docs build, and generated-doc assertions into one gate.
- `.github/workflows/ci.yml`: already reuses release preflight in PR CI, which gives Phase 11 an existing alignment point instead of a fresh implementation.
- `guides/release_publish.md`: already defines the maintainer-facing version/tag/owner sequence the live workflow should mirror rather than replace.

### Established Patterns
- Release confidence is proved through one shared scripted gate rather than ad hoc inline workflow steps.
- Package-consumer installability is treated as a release signal, not just a CI nicety.
- Maintainer-only release policy lives in maintainer docs and targeted parity tests, not in adopter-facing onboarding docs.
- Protected release behavior is intentionally narrow: one workflow, one environment boundary, and explicit comments when a live credential seam is deferred.

### Integration Points
- Real publish wiring should land in `.github/workflows/release.yml` after the shared preflight step.
- Any publish-specific assertions should compose onto `scripts/release_preflight.sh` or adjacent release-test helpers, not create a second unchecked path.
- Tag/version protection should align `guides/release_publish.md`, `mix.exs`, and the workflow trigger semantics so the release lane publishes the same version maintainers intentionally cut.

</code_context>

<specifics>
## Specific Ideas

- The live publish path should remain the same lane maintainers already inspect in CI/release, not a parallel “special” workflow.
- Real release automation should preserve the maintainer runbook contract instead of inventing a CI-only version source or docs-publish shortcut.
- The protected credential boundary matters as much as the publish command itself; approval and ref restrictions are part of the deliverable, not incidental setup.

</specifics>

<deferred>
## Deferred Ideas

- Post-publish verification from public `Hex.pm` remains Phase 12 work.
- Broader release orchestration changes such as release-please or third-party publish wrappers remain out of scope while the native `mix hex.publish` path is being proved.

</deferred>

---

*Phase: 11-protected-publish-automation*
*Context gathered: 2026-04-28*
