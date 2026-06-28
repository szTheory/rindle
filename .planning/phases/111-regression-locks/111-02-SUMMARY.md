---
phase: 111-regression-locks
plan: 02
subsystem: ci-pipeline
tags: [ci, regression-lock, package-consumer, phx-new, cold-path, LOCK-02]
requires:
  - "scripts/install_smoke.sh self-install path (:31 --version probe + :33 archive.install)"
  - ".github/workflows/ci.yml lean `package-consumer` job (LANE-02 split)"
provides:
  - "ci.yml step `Purge phx.new archive to exercise the cold-runner self-install path` in the `package-consumer` job"
  - "Cold-runner self-install path of install_smoke.sh genuinely exercised on every PR"
affects:
  - ".github/workflows/ci.yml"
tech-stack:
  added: []
  patterns:
    - "Honest cold-path lock: purge a warm runner artifact before the smoke so the failing condition is taken every PR (vs warm-cache theater)"
key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"
decisions:
  - "Step placed immediately after `Set up MinIO…` and before the `Run built-artifact image-only…` smoke (purge precedes smoke; mandatory ordering per plan)"
  - "Step name uses Claude's Discretion per D-CONTEXT: `Purge phx.new archive to exercise the cold-runner self-install path`"
  - "`|| true` retained so the step is a no-op when the archive is already absent (cold-runner case); the goal is to GUARANTEE absence before the smoke"
  - "Added only to the lean PR-gating `package-consumer` job (:541), NOT `package-consumer-full` (:686, off-PR)"
metrics:
  duration: "3 min"
  completed: "2026-06-28"
  tasks: 1
  files: 1
status: complete
---

# Phase 111 Plan 02: LOCK-02 cold-path purge before package-consumer smoke — Summary

Added one `mix archive.uninstall phx_new --force || true` step to the lean PR-gating
`package-consumer` job in `.github/workflows/ci.yml`, positioned immediately before the
built-artifact image-only smoke, so the cold-runner self-install path in
`scripts/install_smoke.sh` is genuinely exercised on every PR instead of being hidden by a
warm phx.new archive cache.

## What Was Built

A single CI `run:` step (`LOCK-02`) in the `package-consumer` job:

```yaml
- name: Purge phx.new archive to exercise the cold-runner self-install path
  run: mix archive.uninstall phx_new --force || true
```

Placed after `Set up MinIO for S3-compatible package-consumer proofs` and before
`Run built-artifact image-only package-consumer proof against MinIO`
(`bash scripts/install_smoke.sh image`). Purging the archive makes the
`install_smoke.sh:31` `mix phx.new --version` probe fail cold, so the `:33`
`mix archive.install hex phx_new --force` self-install path runs for real each PR. A guard
that only ran in the same warm cache that hid the original 2026-06-26 flake would prove
nothing; this converts warm-cache theater into an honest cold-path exercise (RESEARCH §6
footgun #1; threat T-111-04 mitigated).

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | LOCK-02 — purge phx.new archive before the package-consumer smoke | 2c8cdb1 | .github/workflows/ci.yml |

## Verification

- `grep -n 'mix archive.uninstall phx_new --force' .github/workflows/ci.yml` → line 654, inside the `package-consumer` job, BEFORE the smoke step.
- Ordering: purge step name at line 653, `Run built-artifact image-only…` smoke at line 659 → purge precedes smoke (done-criterion met).
- Job placement: purge sits between `package-consumer:` (:541) and `package-consumer-full:` (:686) → it is in the lean PR-gating job, NOT the off-PR full job (threat T-111-05 mitigated).
- YAML well-formed: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` → `YAML OK`.
- Invariants byte-unchanged: `name: CI` (line 1), the workflow filename, the `CI Summary` `needs` block, and `package-consumer-full` are untouched. `git diff --stat` → `1 file changed, 8 insertions(+)`, zero deletions, zero `lib/` change.
- OBS-02 content-drift guard: `grep -rn "Run built-artifact\|Purge phx.new\|package-consumer" test/` — no meta-test asserts a literal this edit changed. Existing matches in `ci_lane_split_test.exs` / `release_docs_parity_test.exs` assert job-key existence, `needs` membership, and matrix shape only; the new step + comment add content without altering those literals. No red-main risk.
- LOCK-02 is behavioral (CI-exercised) — full proof is a live PR run taking the self-install path; recorded as the manual-only verification in 111-VALIDATION.

## Deviations from Plan

None — plan executed exactly as written. Single task, single file, mandatory position honored, discretionary step name chosen per D-CONTEXT.

## Known Stubs

None.

## Threat Flags

None — single idempotent CI step over a transient first-party runner artifact; no new endpoint, secret, package, or `lib/` surface. Threat register dispositions (T-111-04 mitigate, T-111-05 mitigate, T-111-SC accept) are satisfied as planned.

## Self-Check: PASSED

- Modified file exists: `.github/workflows/ci.yml` — FOUND.
- Commit exists: `2c8cdb1` — FOUND (`ci(111-02): purge phx.new archive before package-consumer smoke`).
