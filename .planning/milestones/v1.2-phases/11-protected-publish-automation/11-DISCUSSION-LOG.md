# Phase 11: Protected Publish Automation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `11-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-04-28
**Phase:** 11-Protected Publish Automation
**Mode:** assumptions
**Areas analyzed:** Publish Credential Boundary, Preflight Reuse and Fail-Fast Gating, Trigger Surface and Release Entry Path, Version Source and Publish Semantics

## Assumptions Presented

### Publish Credential Boundary

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Wire the real `HEX_API_KEY` only through the existing GitHub `release` environment on the current release job, not through a repo-level secret, new workflow, or local-maintainer-only path. | Confident | `.github/workflows/release.yml`, `.planning/ROADMAP.md`, `.planning/milestones/v1.2-phases/10-publish-readiness/10-02-PLAN.md`, `.planning/milestones/v1.2-phases/10-publish-readiness/10-02-SUMMARY.md` |

### Preflight Reuse and Fail-Fast Gating

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep the live publish step downstream of `scripts/release_preflight.sh` and retain that script as the must-pass gate before any networked publish attempt. | Confident | `scripts/release_preflight.sh`, `.github/workflows/release.yml`, `.github/workflows/ci.yml`, `.planning/ROADMAP.md` |

### Trigger Surface and Release Entry Path

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep the release entrypoints narrow by extending the current `workflow_dispatch` plus `v*` tag-triggered workflow instead of broadening publish execution to PRs, branch pushes, or a separate automation path. | Likely | `.github/workflows/release.yml`, `.planning/milestones/v1.0-phases/05-ci-1-0-readiness/05-CONTEXT.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md` |

### Version Source and Publish Semantics

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Publish the version already declared in `mix.exs`, preserve the documented release sequence, and use full `mix hex.publish --yes` for the real release so docs publish with the package. | Likely | `mix.exs`, `guides/release_publish.md`, `test/install_smoke/release_docs_parity_test.exs`, `https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html`, `https://hex.pm/docs/publish` |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

- Full publish command semantics: `mix hex.publish` publishes the package and generates/publishes docs, while `mix hex.publish package` publishes package-only. Source: `https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html`
- CI publish auth pattern: Hex documents `HEX_API_KEY=... mix hex.publish --yes` for automated publishing. Source: `https://hex.pm/docs/publish`
- Key permissions: Hex user keys default to `api:write`, and permissions can be narrowed, including `package:PACKAGE_NAME`. Source: `https://hexdocs.pm/hex/Mix.Tasks.Hex.User.html`
- Environment gating behavior: environment secrets are unavailable until protection rules pass, and branch/tag policies can explicitly restrict which refs may deploy. Sources: `https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments`, `https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments`
