---
phase: 106-trigger-split-matrix-lane-refinement
plan: 02
subsystem: ci-cd
tags: [ci, concurrency, lane-01, github-actions]
requires: []
provides:
  - "ci.yml top-level concurrency group (per-workflow + per-ref; PR-cancel / push-serialize)"
affects:
  - ".github/workflows/ci.yml"
tech-stack:
  added: []
  patterns:
    - "GitHub Actions top-level concurrency: group keyed on github.workflow + github.ref"
    - "cancel-in-progress as an expression gated on github.event_name == 'pull_request'"
key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"
decisions:
  - "group: ${{ github.workflow }}-${{ github.ref }} (per-workflow + per-ref) so each PR branch and the push:main run get an independent serialization queue"
  - "cancel-in-progress: ${{ github.event_name == 'pull_request' }} — true only for PRs; false (serialize, never cancel) for push:main / workflow_dispatch, preserving the release-coupling full-matrix evidence (D-06)"
metrics:
  duration: "3 min"
  completed: "2026-06-22"
  tasks: 1
  files: 1
status: complete
---

# Phase 106 Plan 02: Top-level CI Concurrency Group Summary

Added a top-level `concurrency:` block to `ci.yml` that cancels stale in-progress PR runs while serializing — and never cancelling — push:main and release runs, using `github.workflow`+`github.ref` for the group key and `github.event_name == 'pull_request'` for cancel-in-progress (LANE-01, D-06).

## What Was Built

A single edit to `.github/workflows/ci.yml`: a new top-level `concurrency:` block inserted between the `on:` trigger block and the `env:` block (sibling of `on:`/`env:`/`permissions:`, not nested inside any job).

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

- **`group`** combines `github.workflow` (per-workflow) with `github.ref` (per-ref), so each PR branch and the push:main run each get an independent serialization queue — one branch's churn never affects another's.
- **`cancel-in-progress`** is an expression that is `true` only for `pull_request` events. For `push:main` and `workflow_dispatch` it evaluates `false`, so those runs serialize and are never cancelled.

A multi-line comment cites D-06 and the release-coupling footgun: `release.yml gate-ci-green` keys off the push:main `ci.yml` run `conclusion`, and cancelling a main run would destroy the full-matrix evidence the Hex publish gate depends on. The comment also notes the expression reads only the trusted `github.event_name` context (no injection surface added).

## How It Works

GitHub evaluates the `cancel-in-progress` expression per run against the triggering event:
- A second push to an open PR (`pull_request` / `synchronize`) → `true` → the superseded run is cancelled (saves runner minutes, sharpens the ≤7-min PR signal).
- A `labeled` event is still `event_name == 'pull_request'`, so label-triggered PR runs also cancel correctly (canonical-refs note).
- A push to `main` or a `workflow_dispatch` → `false` → the run joins the per-ref queue and is never cancelled, so the full-matrix run that release coupling reads via run `conclusion` is always preserved.

## Deviations from Plan

None — plan executed exactly as written. The `group:` key phrasing (`${{ github.workflow }}-${{ github.ref }}`) was Claude's discretion per CONTEXT, satisfying the per-workflow + per-ref requirement.

## Threat Model Coverage

- **T-106-02-D (self-inflicted DoS — cancelling a push:main run):** mitigated. `cancel-in-progress` keys on `github.event_name == 'pull_request'`, which is false for push:main, so a main run is never cancelled; release-coupling evidence preserved.
- **T-106-02-T (event-name expression injection):** mitigated. The expression reads only the trusted `github.event_name` context — no PR body/title/branch string interpolated into a shell; no `run:` injection surface added.
- **T-106-02-E (privilege elevation):** accepted — no `permissions:` change.
- **T-106-02-SC (supply chain):** accepted — no package install in this plan.

No new security-relevant surface introduced beyond the threat model.

## Invariants Preserved

- `ci.yml` line 1 is still exactly `name: CI`; the filename is unchanged (git shows the file modified, not renamed).
- No job-level `concurrency:` was added (grep `^concurrency:` matches exactly once, at top level).
- No lane gained `continue-on-error`; no `on:` trigger, `env:`, `permissions:`, or job body was changed.
- `ci.yml` parses as valid YAML (`python3 yaml.safe_load` → OK).

## Verification

- `head -1 .github/workflows/ci.yml` == `name: CI` ✓
- Top-level `^concurrency:` present (count 1, not nested) ✓
- `concurrency.group` references both `github.workflow` and `github.ref` ✓
- `concurrency.cancel-in-progress` references `github.event_name == 'pull_request'` (false on push:main) ✓
- YAML parses without error ✓
- `git diff` shows only the added concurrency block; no job bodies changed ✓
- Commit `59112f1` contains only `.github/workflows/ci.yml` with zero deletions ✓

## Commits

- `59112f1`: feat(106-02): add top-level concurrency group to ci.yml (LANE-01, D-06)

## Known Stubs

None.

## Downstream

106-03 (package-consumer split) depends on this landing first to avoid same-file overlap in the serialized ci.yml chain (wave 1 → wave 2).

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml`
- FOUND: `.planning/phases/106-trigger-split-matrix-lane-refinement/106-02-SUMMARY.md`
- FOUND: commit `59112f1`
