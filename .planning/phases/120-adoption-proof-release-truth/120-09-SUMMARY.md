---
phase: 120-adoption-proof-release-truth
plan: 09
subsystem: release-proof
tags: [elixir, packaged-artifact, cohort, github-actions, release]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: repaired packed compatibility, populated-upgrade, and documentation parity contracts
provides:
  - fail-closed local verification receipt for the exact candidate SHA
  - explicit external exact-SHA evidence request for release authorization
affects: [package-consumer, cohort-demo, release-proof]
tech-stack:
  added: []
  patterns: [clean-candidate verification, exact-SHA release evidence, fail-closed receipts]
key-files:
  created:
    - .planning/phases/120-adoption-proof-release-truth/120-09-SUMMARY.md
  modified: []
key-decisions:
  - "Local verification is blocked until the clean candidate worktree has its declared dependencies fetched; no checkout-only or partial result is release authority."
requirements-completed: []
coverage:
  - id: D1
    description: "Packed compatibility, populated-upgrade, and Cohort local pathways for the candidate."
    requirement: PROOF-01
    verification:
      - kind: integration
        ref: "Task 1 exact chained command"
        status: fail
    human_judgment: true
    rationale: "The first gate could not run because the clean candidate worktree has no declared dependencies; remaining chained gates were not executed."
  - id: D2
    description: "Immutable exact-SHA CI and Release workflow evidence."
    requirement: PROOF-02
    verification:
      - kind: manual_procedural
        ref: "GitHub Actions exact-SHA evidence requested below"
        status: unknown
    human_judgment: true
    rationale: "Task 1 is blocked and release authorization requires GitHub-hosted results on the identical candidate SHA."
metrics:
  duration: 4m
  completed: 2026-08-10
  tasks: 0
  files: 1
status: blocked
---

# Phase 120 Plan 09: Blocked Local Release-Proof Receipt

The exact candidate checkout was clean, but the required Task 1 chain stopped at its first command because its declared Mix dependencies are unavailable in that worktree. No local release proof or release authorization has been established.

## Candidate and Checkout Identity

- **Candidate SHA:** `2a32a0ae34a3866c4a95b1252134d59bc6210f87` (40 characters)
- **Candidate checkout:** detached clean worktree at `/tmp/rindle-120-09-clean-2a32a0a`
- **Candidate worktree status:** clean (`git status --porcelain=v1` produced no output)
- **Shared checkout:** intentionally left dirty; no product source was changed by this plan.

## Preconditions

- `docker info --format 'ServerVersion={{.ServerVersion}}; Containers={{.Containers}}; Running={{.ContainersRunning}}; Networks={{.NFd}}'` exited `0`: `ServerVersion=29.5.2; Containers=54; Running=8; Networks=121`.
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost PGPORT=5432 pg_isready -d rindle_test` exited `0`: `localhost:5432 - accepting connections`.
- `docker ps` exited `0`; Docker was reachable. No running MinIO container was listed, but both the generated-app and Cohort harnesses own their required service setup.

## Task 1 Local Receipt — BLOCKED

Executed exactly, from the clean candidate checkout:

```bash
mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0 && RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_public_compat --seed 0 && RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_isolation_upgrade --seed 0 && bash scripts/ci/cohort_demo_smoke.sh
```

- **Stage 1 — docs/release parity:** exit `1`; tests did not start.
- **Stage 2 — packed explicit-public compatibility:** not executed because the chain uses `&&`.
- **Stage 3 — packed populated isolation upgrade:** not executed because the chain uses `&&`.
- **Stage 4 — Cohort Compose smoke:** not executed because the chain uses `&&`.

Raw diagnostic from Stage 1:

```text
Unchecked dependencies for environment test:
* ex_machina, nimble_options, jason, junit_formatter, mox, oban, ex_aws_s3, jose, finch, bypass, goth, hackney, mux, ecto_sql, ex_aws, mix_audit, phoenix_live_view, excoveralls, telemetry, ex_marcel, doctor, gcs_signed_url, dialyxir, lazy_html, credo, plug, postgrex, muontrap, image, httpoison
the dependency is not available, run "mix deps.get"
** (Mix) Can't continue due to errors on dependencies
```

This is an environment prerequisite failure, not a passing receipt. It also means the known PostgreSQL `53300` capacity condition was not reached or evaluated in this attempt.

## Required External Evidence (Not Inspected)

Per the plan, GitHub evidence is intentionally not inspected until Task 1 has clean passing local receipts. When the dependency prerequisite has been restored and Task 1 passes, record immutable URLs, run IDs, conclusions, and job/step results for this exact SHA only:

`2a32a0ae34a3866c4a95b1252134d59bc6210f87`

Required evidence:

- Green `ci.yml` with matching `headSha`, including `Proof`, lean `Package Consumer Proof Matrix + Release Preflight`, and `Adoption Demo Unit`.
- For the push-to-main candidate, green `Package Consumer Full Matrix + Release Preflight` and `Cohort Demo Smoke`.
- Green `Release` workflow on that same SHA with `Run release preflight`, `Verify version alignment`, `Dry run Hex publish`, and `Verify public Hex.pm artifact`.

Local output is diagnostic only and is never release authorization.

## Deviations from Plan

None — the plan required a fail-closed record when an environment prerequisite blocked the command chain.

## Issues Encountered

- The clean candidate worktree did not have any declared Mix dependencies available. Fetching them is required before rerunning the exact Task 1 chain; no fallback to the shared dirty checkout was used.

## Next Phase Readiness

Blocked. Restore the clean worktree's declared dependencies, rerun the exact chained Task 1 command, and only after all four stages pass inspect GitHub Actions evidence for the recorded immutable SHA.

## Self-Check: PASSED

- Candidate SHA resolves to the detached clean worktree and has 40 characters.
- This receipt file exists; no product source files were modified.
