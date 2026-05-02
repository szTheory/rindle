---
phase: 12
plan: 02
status: completed
requirements-completed: [RELEASE-09]
files_modified:
  - guides/release_publish.md
verification:
  - grep -q "## Rollback and Revert" guides/release_publish.md
completed_at: 2026-04-28
---

# Phase 12 Plan 12-02 Summary

Updated the maintainer release runbook so it now covers first publish, routine releases after `0.1.0`, the shipped workflow contract, and rollback/revert instructions for published Hex releases.

## Outcomes

- Replaced the opening scope so the guide explicitly covers the first public release, routine releases after `0.1.0`, and rollback/revert.
- Split the release flow into `## First Public Release (0.1.0)` and `## Routine Releases After 0.1.0`.
- Added a `## Release Workflow Contract` section tying maintainer steps to `bash scripts/release_preflight.sh`, `bash scripts/assert_version_match.sh`, `mix hex.publish --yes`, and `bash scripts/public_smoke.sh`.
- Preserved the maintainer-only rollback and revert guidance, including `mix hex.revert rindle VERSION`, the 1-hour window, the 24-hour first-release window, and version reuse after revert.
- Updated post-publish follow-up so owner verification stays first-release-specific while workflow verification and bumping back to the next `-dev` version apply to every release.

## Verification Evidence

Automated plan verification commands:

```bash
grep -q "## First Public Release (0.1.0)" guides/release_publish.md
grep -q "## Routine Releases After 0.1.0" guides/release_publish.md
grep -q "## Release Workflow Contract" guides/release_publish.md
grep -q "create and push tag \`vVERSION\`" guides/release_publish.md
grep -q "Run release preflight" guides/release_publish.md
grep -q "Verify version alignment" guides/release_publish.md
grep -q "Live publish to Hex" guides/release_publish.md
grep -q "Verify public Hex.pm artifact" guides/release_publish.md
grep -q "bash scripts/release_preflight.sh" guides/release_publish.md
grep -q "bash scripts/assert_version_match.sh" guides/release_publish.md
grep -q "bash scripts/public_smoke.sh" guides/release_publish.md
grep -q "mix hex.revert rindle VERSION" guides/release_publish.md
grep -q "1-hour window" guides/release_publish.md
grep -q "24-hour" guides/release_publish.md
```

Result: passed (all commands exit code 0).

## Deviations from Plan

None. The runbook now matches the shipped release workflow and closes the routine-release documentation gap.
