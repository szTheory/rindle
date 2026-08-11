---
phase: 120-adoption-proof-release-truth
plan: 11
subsystem: release-proof
tags: [elixir, packaged-artifact, cohort, docker, postgresql, release]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: snapshot-only Oban proof contract from Plan 120-10
provides:
  - fail-closed local proof receipt for the post-120-10 candidate
affects: [package-consumer, cohort-demo, release-proof]
tech-stack:
  added: []
  patterns: [clean-detached-candidate, dedicated-tmpdir, fail-fast-preflight, fail-closed-integration]
key-files:
  created:
    - .planning/phases/120-adoption-proof-release-truth/120-11-SUMMARY.md
  modified: []
key-decisions:
  - "A generated-app process that does not complete cleanup is a failed local proof, even after its focused ExUnit assertion has printed a passing dot."
metrics:
  completed: 2026-08-10
  tasks: 0
  files: 1
status: blocked
---

# Phase 120 Plan 11: Blocked Local Proof Receipt

The exact post-120-10 candidate passed all required fast checks, but its first packed image profile stalled during cleanup after its focused assertion. The task was terminated fail-closed; no populated-upgrade, Cohort, repository-hygiene, GitHub Actions, Release, push, merge, dispatch, or publish evidence was collected.

## Candidate and Environment Identity

- **Candidate SHA:** `50b769f48d176ba6dcba47d560e3f09635124576` (40 characters; detached worktree `HEAD` matched exactly).
- **Candidate provenance:** the current post-120-10 commit, with Plan 120-10 commits `9f94c01` and `67bfb5e` verified as ancestors.
- **Clean detached worktree:** `/private/tmp/rindle-120-11-clean.bZzI69`; `git status --porcelain=v1` was empty before testing.
- **Dedicated TMPDIR:** `/private/tmp/rindle-120-11-tmp.nclI7I`, mode `700`, used for dependency resolution and every command below.
- **Preconditions:** Docker responded (`ServerVersion=29.5.2; Containers=55; Running=9; Networks=124`); PostgreSQL returned `localhost:5432 - accepting connections`; ports `14102`, `19000`, and `19001` had no listeners.
- **Dependency fetch:** `TMPDIR=/private/tmp/rindle-120-11-tmp.nclI7I MIX_ENV=test mix deps.get` exited `0` in the detached worktree.

The main checkout intentionally remained dirty and untouched. This receipt contains no substituted SHA or inherited branch-head result.

## Task 1 — Fast Preflight

The following commands ran sequentially before `scripts/ensure_minio.sh`, packed generated-app work, or Cohort work:

| Command | Exit | Receipt |
| --- | --- | --- |
| `mix format --check-formatted test/install_smoke/support/generated_app_helper.ex test/install_smoke/generated_app_smoke_test.exs` | `0` | formatter passed |
| `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` | `0` | `8 tests, 0 failures` |
| `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_fast_contract --seed 0` | `0` | `11 tests, 0 failures` |
| `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0` | `0` | `56 tests, 0 failures` |

An initial local recorder invocation could not read zsh's pipeline-status array after the formatter command; no integration command had started. The recorder was corrected to Bash and the complete preflight above was rerun and recorded. This did not change candidate contents or test order.

## Task 1 — Integration Receipt: BLOCKED

`bash scripts/ensure_minio.sh` ran only after preflight and exited `0`.

The first packed profile then ran from the same detached worktree and TMPDIR:

```sh
RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_public_compat --seed 0
```

Its focused assertion printed `.` but the generated-app cleanup did not finish. After more than two minutes, the owned BEAM process was still alive and PostgreSQL showed the generated app's idle sessions (including `public.rindle_migration_versions` and `public.oban_signal`). Per the plan's fail-closed cleanup rule, the task-owned BEAM process was sent `TERM`; it and its parent exited, the command recorded exit `1`, and the `rindle_test` non-self session count returned to `0`.

Raw terminal receipt:

```text
===== PACKED_PUBLIC_COMPAT =====
COMMAND: RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_public_compat --seed 0
Running ExUnit with seed: 0, max_cases: 36
Excluding tags: [:test, :integration, :contract, :adopter, :canary]
Including tags: [:phase_120_public_compat, :minio]

.
** (EXIT from #PID<0.94.0>) shutdown

PACKED_PUBLIC_COMPAT_EXIT=1
```

Because the public-compatibility stage did not complete, the `&&` chain stopped. The following stages are **not run** and are not passing evidence:

- `RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_isolation_upgrade --seed 0`
- `COHORT_DEMO_PORT=14102 COHORT_MINIO_PORT=19000 COHORT_MINIO_CONSOLE_PORT=19001 bash scripts/ci/cohort_demo_smoke.sh`

## Task 2 Status

**Not reached.** The repository-hygiene gate and external exact-SHA evidence inspection must not begin until Task 1 has a complete passing packed and Cohort receipt. No GitHub release claim can be made from this local diagnostic evidence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the local preflight recorder's shell-specific pipeline-status access**

- **Found during:** Task 1 fast preflight.
- **Issue:** The first recorder ran under zsh and stopped after invoking the formatter because `PIPESTATUS` was unavailable.
- **Fix:** Reran the exact preflight sequentially through a Bash recorder before any integration process was started.
- **Files modified:** None.
- **Commit:** This evidence receipt commit.

## Known Stubs

None.

## Threat Flags

None. This plan writes verification evidence only and introduces no new trust-boundary surface.

## Next Step

Investigate and correct the candidate/environment condition that leaves the packed public-compatibility process stalled during cleanup. Rerun the whole Task 1 chain from one new clean detached worktree at the exact candidate before proceeding to Task 2's blocking human-verification gate.
