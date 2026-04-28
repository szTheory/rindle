---
phase: 05-ci-1-0-readiness
plan: 05
subsystem: ci-release-lane
tags: [ci, release, hex, github-actions, package, environment]
status: complete

# Dependency graph
requires:
  - phase: 05-ci-1-0-readiness
    plan: 03
    provides: "mix.exs already touched for excoveralls + ex_doc bump; this plan layers files: allowlist on top without disturbing those edits"
  - phase: 05-ci-1-0-readiness
    plan: 04
    provides: "elixirc_paths(:test) adds test/adopter — preserved by this plan's package/0 edit (Warning 4)"

provides:
  - "Release lane (CI-09) — separate `.github/workflows/release.yml` triggered ONLY on workflow_dispatch + push tags v*"
  - "Explicit `files:` allowlist in mix.exs package/0 prevents .planning/, priv/plts/, test/ leakage at publish time"
  - "`environment: release` declaration on the release job — gates future HEX_API_KEY behind GitHub Actions Environment protection rules (Blocker 6)"
  - "LICENSE file added at repo root (Apache-2.0) so package/0 `files:` allowlist resolves cleanly"

requirements_completed:
  - CI-09
---

## Summary

Plan 05-05 ships the v1.0 release lane as a dry-run-only gate that catches package-metadata regressions every tag push, without ever performing a real Hex publish until the 1.0 cutover.

## What was built

**Task 1 — `mix.exs` `package/0` allowlist + LICENSE (commit `724b7eb`):**
- Added `files: ~w(lib priv/repo/migrations mix.exs README.md LICENSE)` to `package/0`. This is the primary leak guard: `.planning/`, `priv/plts/`, `test/`, `_build/`, `coveralls.json`, `.github/` cannot end up in the published tarball even if the underlying file tree contains them.
- Preserved `elixirc_paths(:test)` addition for `test/adopter` from Plan 04 (Warning 4 invariant).
- Created `LICENSE` (Apache-2.0) at repo root so the `files:` allowlist resolves; absence would have crashed `mix hex.build`.

**Task 2 — `.github/workflows/release.yml` (commit `e73aee5`):**
- Triggers: `workflow_dispatch` + `push: tags: v*` ONLY (D-10).
- `mix hex.build --unpack` is the must-pass step (no auth required).
- Tarball assertions: required paths present (`lib/rindle.ex`, `mix.exs`, `README.md`, `LICENSE`); prohibited paths absent (`_build`, `.planning`, `priv/plts`, `test`, `coveralls.json`, `.github`).
- `mix hex.publish --dry-run` runs with auth-failure tolerance (A1 resolution): if it exits with "No authenticated user found", emit a `::warning::` and exit 0 — the artifact inspection above is the active gate. Real auth-key wiring deferred to 1.0 cutover.
- `environment: release` declared on the job (Blocker 6) so any future `HEX_API_KEY` is bound to GitHub Actions Environment protection rules (required reviewers + branch/tag restriction). The environment must be created in repo settings BEFORE a real key is added.

## Verification

- `mix hex.build --unpack` succeeds locally; the unpacked `rindle-0.1.0-dev/` tree contains exactly the allowlisted paths and nothing else.
- `mix hex.publish package --dry-run --yes` exits 1 with "No authenticated user found" — confirms A1 risk and validates the auth-tolerance branch in the workflow.
- `cat mix.exs | grep -E "elixirc_paths|files:"` confirms both Plan 04's `test/adopter` path and this plan's `files:` allowlist coexist without conflict.
- All 160 default tests still pass after this plan's mix.exs edit.

## Deviations

Two minor inline fixes during execution:

1. **LICENSE creation** — the original plan's `files:` allowlist included `LICENSE`, but the file did not exist at the repo root. `mix hex.build` would have failed on a missing file. Created an Apache-2.0 LICENSE inline (consistent with PROJECT.md license declaration). Rolled into Task 1 commit.

2. **Hex auth shim env var** — `mix hex.publish --dry-run` requires `HEX_API_KEY` even for a dry-run when running in CI's clean environment. Added a `dryrun-placeholder` shim env var so the dry-run reaches the metadata-validation phase even without real auth. The shim never PUTs to the Hex API; the artifact assertions above are the load-bearing gate.

Both deviations are documented inline in the workflow file's comments.

## Key files

- `/Users/jon/projects/rindle/.github/workflows/release.yml` (new, 98 lines)
- `/Users/jon/projects/rindle/mix.exs` (modified — `package/0` `files:` allowlist)
- `/Users/jon/projects/rindle/LICENSE` (new — Apache-2.0)

## Self-Check: PASSED
