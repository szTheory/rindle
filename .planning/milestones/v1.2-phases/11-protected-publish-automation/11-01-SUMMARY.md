---
phase: 11
plan: 01
subsystem: release
tags:
  - ci
  - release
  - security
dependencies:
  requires:
    - 11-CONTEXT
  provides:
    - 11-01
  affects:
    - .github/workflows/release.yml
tech_stack:
  added: []
  patterns:
    - Environment/Job pattern
    - Preflight shared gate pattern
key_files:
  created: []
  modified:
    - .github/workflows/release.yml
key_decisions:
  - Swapped out dry-run publish step for a live publish step guarded by real HEX_API_KEY environment variable logic.
metrics:
  duration_minutes: 1
  completed_at: 2026-04-28T21:20:10Z
---

# Phase 11 Plan 01: Protected Publish Automation Summary

Wire real publish auth into release workflow.

## Overview
Turn the existing release lane into a live publish path by wiring the `HEX_API_KEY` from the GitHub Actions `release` environment and executing `mix hex.publish --yes`. This enables automated releases downstream of shared preflight checks without hardcoding maintainer credentials.

## Tasks Completed

- **Task 1:** Wired real publish auth into release workflow. Added `concurrency: release` to prevent overlapping runs. Removed the dummy `dryrun-placeholder` shim and the old `--dry-run` action. Added a final step executing `mix hex.publish --yes` conditional on a valid `HEX_API_KEY`. (Commit: `cf6a5e0`)

## Deviations from Plan
None - plan executed exactly as written.

## Known Stubs
None.

## Threat Flags
| Flag | File | Description |
|------|------|-------------|
| threat_flag: credential_usage | .github/workflows/release.yml | Replaced dry-run placeholder with real credential injection (`secrets.HEX_API_KEY`) for live publish to Hex.pm. Mitigated by `environment: release` constraints and runtime existence checks in the workflow step. |
## Self-Check: PASSED
