---
phase: 16-live-publish-execution-and-post-publish-verification
plan: 02
subsystem: release
tags: [release, github-actions, hex, runbook, parity]
requirements_completed:
  - PUBLISH-03
  - RELEASE-01
completed: 2026-04-30
---

# Phase 16 Plan 02 Summary

Phase 16 plan 02 wired the local idempotency probe into the release workflow, aligned the publish/runbook contract around skip-on-rerun behavior, and extended parity coverage so future workflow drift is caught in tests.

## Accomplishments

- Updated `.github/workflows/release.yml` to run `scripts/hex_release_exists.sh` before publish, skip both publish steps when `already_published=true`, emit an idempotent publish summary, use a single global concurrency token, and switch version parsing to `Mix.Project.config()[:version]`.
- Renamed the live publish and Hex index wait steps, added a four-job topology comment, and improved the `HEX_API_KEY` guard message to point maintainers at the release environment and runbook.
- Extended `test/install_smoke/package_metadata_test.exs` and `test/install_smoke/release_docs_parity_test.exs` to cover the workflow gate, summary step, concurrency token, version parse, renamed step names, rollback language, runbook appendices, and release guide drift checks.
- Landed the accompanying runbook, changelog, requirements, roadmap, and revert-rehearsal edits in the same working tree so the human-facing release contract matches the workflow changes under test.

## Verification

- `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs test/install_smoke/release_docs_parity_test.exs`

The combined package/parity suite passed with 32 tests on 2026-04-30.

## Notes

- `MIX_ENV=dev bash scripts/release_preflight.sh` revalidated package build plus the first two ExUnit gates, then failed during database creation because the local Postgres server was already at `too_many_connections`. That is an environment limit, not a Phase 16 assertion failure.
- Live GitHub proof is still pending: the `gh workflow run release.yml ...` rehearsal should happen after these local workflow changes are committed and pushed so the remote runner sees the fixed YAML.
