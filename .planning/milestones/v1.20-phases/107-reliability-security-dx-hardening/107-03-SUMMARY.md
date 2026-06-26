---
phase: 107-reliability-security-dx-hardening
plan: 03
subsystem: infra
tags: [mix, ci, contributing, readme, dx, ci-summary, brandbook, minio]

# Dependency graph
requires:
  - phase: 107-02
    provides: "the settled CI surface — ci.yml (name: CI), the SOLE required check CI Summary (job ci-summary), the quality lane (format/lint/compile/test + advisory mix deps.audit)"
  - phase: 106
    provides: "the lane keep/move/nightly classification (106-LANE-CLASSIFICATION.md) the docs mirror"
provides:
  - "`mix ci` alias in mix.exs aliases/0 reproducing the PR merge-blocking verdict locally"
  - "filled CONTRIBUTING.md local-command section (mix ci + ordered checks + CI Summary sole-required + prerequisites + full-parity MinIO command + e2e_local.sh)"
  - "README CI badge clarified to reflect the CI Summary gate"
affects: [107-04, ship, contributor-onboarding]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "`mix ci` alias mirrors the merge-blocking PR set (deps/compile/format/brandbook drift gates + default-tag suite), ending in the gating suite; registered ci: :test in def cli preferred_envs"
    - "Docs name the single required check (CI Summary, skipped==pass) rather than per-lane names"

key-files:
  created:
    - .planning/phases/107-reliability-security-dx-hardening/107-03-SUMMARY.md
  modified:
    - mix.exs
    - CONTRIBUTING.md
    - README.md

key-decisions:
  - "mix ci ends in `test` (not `coveralls`) so it carries ecto.create/migrate and runs on a fresh clone; registered ci: :test so the nested test task runs under MIX_ENV=test"
  - "MinIO/integration legs deliberately excluded from the base alias (default-tag suite skips :integration/:minio/:contract/:adopter); full-parity command documented in CONTRIBUTING, not embedded"
  - "Playwright gallery proof omitted from mix ci (covered by brandbook-tokens in CI + scripts/ci/e2e_local.sh locally)"
  - "README keeps the existing workflow-run badge; no custom per-check badge endpoint (D-09)"

patterns-established:
  - "Single local command (mix ci) is the contributor source-of-truth for the PR verdict"
  - "Docs describe the real check set and the real required check name only — no aspirational content"

requirements-completed: [HARD-03]

# Metrics
duration: 8min
completed: 2026-06-22
status: complete
---

# Phase 107 Plan 03: DX hardening — `mix ci` alias + CONTRIBUTING/README (HARD-03) Summary

**A single `mix ci` alias that reproduces the PR merge-blocking verdict locally (lockfile drift + compile-warnings-as-errors + format + the four brandbook token→CSS drift gates + the default-tag ExUnit suite), plus a filled CONTRIBUTING local-command section and a README badge clarified to reflect the `CI Summary` gate.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-06-22T19:22Z
- **Completed:** 2026-06-22T19:30Z
- **Tasks:** 2
- **Files modified:** 3 (mix.exs, CONTRIBUTING.md, README.md)

## Accomplishments
- Added a `ci:` alias to `mix.exs` `aliases/0` mirroring ONLY the merge-blocking PR set surfaced by the `CI Summary` gate: `deps.get --check-locked`, `deps.unlock --check-unused`, `compile --warnings-as-errors`, `format --check-formatted`, the four brandbook drift gates, then the gating default-tag `test` suite. Registered `ci: :test` in `def cli` `preferred_envs`.
- `mix ci` runs end-to-end on a fresh clone WITHOUT MinIO — the default-tag suite excludes `:integration`/`:minio`/`:contract`/`:adopter` (76 excluded), so no hard-fail on missing MinIO. Brandbook regen is idempotent (zero tracked-file drift).
- Replaced the reserved Phase-107/HARD-03 placeholder in `CONTRIBUTING.md` with the local-command section: `mix ci` + ordered checks, the SOLE required check (`CI Summary`, `skipped`==pass), prerequisites (Postgres + Node), the fresh-clone no-MinIO note, the full-parity `--include minio --include integration` command, and the `scripts/ci/e2e_local.sh` browser repro path.
- Kept the existing README `ci.yml/badge.svg?branch=main` workflow-run badge and added a line stating it reflects the `CI Summary` gate (no native per-check badge; no custom endpoint).

## Task Commits

1. **Task 1: Add the `mix ci` alias mirroring the PR merge-blocking set (D-07)** — `57dd99b` (feat)
2. **Task 2: Fill the CONTRIBUTING reserved section + clarify the README badge (D-08, D-09)** — `048efd9` (docs)

## Files Created/Modified
- `mix.exs` — added the `ci:` alias to `aliases/0` (9 sub-tasks) and `ci: :test` to `def cli` `preferred_envs`.
- `CONTRIBUTING.md` — filled the reserved local-command section (lanes + `CI Summary` sole-required + `mix ci` + prerequisites + full-parity MinIO command + `e2e_local.sh`).
- `README.md` — kept the workflow-run badge; added a `<sub>` line clarifying it reflects the `CI Summary` gate.

## The `mix ci` alias (exact sub-task list)

```elixir
ci: [
  "deps.get --check-locked",
  "deps.unlock --check-unused",
  "compile --warnings-as-errors",
  "format --check-formatted",
  "cmd node brandbook/src/tokens-build.mjs",
  "cmd node brandbook/src/admin-css-build.mjs",
  "cmd node brandbook/src/admin-contrast.mjs",
  "cmd node brandbook/src/sync-admin-css.mjs",
  "test"
]
```
Plus `ci: :test` registered in `def cli` `preferred_envs` (so the nested `test` task runs under `MIX_ENV=test`).

## Decisions Made
- Ended the alias in `test` (the project's DB-prepping default-tag alias) rather than `coveralls`, so `mix ci` carries `ecto.create`/`ecto.migrate` and runs on a fresh clone. Both were sanctioned by the plan (`coveralls` or `test`).
- Documented the MinIO full-parity legs and the Playwright browser repro in CONTRIBUTING instead of embedding them in the alias, keeping `mix ci` fast and Elixir/Node-toolchain-only.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered `ci: :test` in `def cli` `preferred_envs`**
- **Found during:** Task 1 (verify gate `mix ci`)
- **Issue:** `mix ci` runs in the default `:dev` environment; the alias's final nested `test` task raised Mix's "mix test is running in the dev environment" guard and aborted before running the suite.
- **Fix:** Added `ci: :test` to `def cli` `preferred_envs` (mirrors the existing `precommit: :test`) so `mix ci` runs the full alias under `MIX_ENV=test`.
- **Files modified:** mix.exs
- **Verification:** Re-ran `mix ci`; the alias completed end-to-end and the suite ran under the test env (76 storage/integration tags excluded).
- **Committed in:** `57dd99b` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The fix was required for the alias to function as specified (run the gating suite). No scope creep — touched only `def cli` in `mix.exs`, no `lib/` change.

## Issues Encountered
- **Pre-existing, out-of-scope test failure (NOT fixed):** `mix ci`'s default-tag suite reports exactly **1 failure** — `test/install_smoke/release_docs_parity_test.exs:319` ("operations guide stays a thin adopter index and maintainer proof lives in RUNNING"). This is the known pre-existing out-of-scope failure named in the execution constraints; it is unrelated to the `mix.exs` alias or the docs changes in this plan and was deliberately left untouched. The `mix ci` *alias itself* works correctly: all in-scope gates (lockfile drift, compile-warnings-as-errors, format, the four brandbook drift gates) pass, brandbook regen is idempotent (zero drift), and the suite runs on a fresh clone without MinIO.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- HARD-03 complete: contributors have one command (`mix ci`) mirroring the PR verdict, and the docs truthfully describe the lane split + sole required check (`CI Summary`).
- Plan 107-04 (final phase plan, HARD-04) remains: the pinned Playwright container + `scripts/ci/e2e_local.sh` referenced from CONTRIBUTING is its deliverable.
- No `lib/` change; no new CI lane added (`git diff --name-only` shows 0 `lib/` files).

## Self-Check: PASSED

---
*Phase: 107-reliability-security-dx-hardening*
*Completed: 2026-06-22*
