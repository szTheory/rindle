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
  - "The OID binding fix requires a new immutable candidate; that clean candidate clears the prior connection-capacity failure but still fails closed on an unquoted pg_constraint alias in the generated packed migration script."
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
    rationale: "The latest docs/release parity gate passed and PostgreSQL had no lingering rindle_test sessions, but packed explicit-public failed on a pg_constraint alias syntax error; later chained gates were not executed."
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
  duration: 18m
  completed: 2026-08-10
  tasks: 0
  files: 1
status: blocked
---

# Phase 120 Plan 09: Blocked Local Release-Proof Receipt

The current exact candidate checkout is clean and has its declared dependencies, but the required Task 1 chain still fails in the packed explicit-public stage. No local release proof or release authorization has been established.

## Candidate and Checkout Identity

- **Current candidate SHA:** `92201beea7969a80aa7d335646c408cfc424a592` (40 characters)
- **Current candidate checkout:** detached clean worktree at `/private/tmp/rindle-120-09-clean-92201be`
- **Candidate worktree status:** clean (`git status --porcelain=v1` produced no output)
- **Shared checkout:** intentionally left dirty; no product source was changed by this plan.
- **Superseded candidate:** `2a32a0ae34a3866c4a95b1252134d59bc6210f87` predates the OID binding fix and is not eligible for external release evidence.

## Preconditions

- `docker info --format 'ServerVersion={{.ServerVersion}}; Containers={{.Containers}}; Running={{.ContainersRunning}}; Networks={{.NFd}}'` exited `0`: `ServerVersion=29.5.2; Containers=54; Running=8; Networks=121`.
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost PGPORT=5432 pg_isready -d rindle_test` exited `0`: `localhost:5432 - accepting connections`.
- `docker ps` exited `0`; Docker was reachable. No running MinIO container was listed, but both the generated-app and Cohort harnesses own their required service setup.
- Before the current-candidate run, `rindle_test` reported `0` lingering non-self PostgreSQL sessions.

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

This was an environment prerequisite failure, not a passing receipt. The declared test dependencies were subsequently fetched in the clean candidate worktree with `MIX_ENV=test mix deps.get` before the following rerun.

### Historical Rerun on Superseded Candidate

The same exact chained command was rerun from the same clean candidate checkout. Its results were:

- **Stage 1 — docs/release parity:** passed: `56 tests, 0 failures`.
- **Stage 2 — packed explicit-public compatibility:** failed during `setup_all`; it did not produce a valid packed receipt.
- **Stage 3 — packed populated isolation upgrade:** not executed because the chain uses `&&`.
- **Stage 4 — Cohort Compose smoke:** not executed because the chain uses `&&`.

Raw failure diagnostics from Stage 2:

```text
** (RuntimeError) command failed (1): mix run --no-start priv/install_smoke/migrate.exs
cwd: /var/folders/f3/f0clj9rd2zb85n2c849wcsrc0000gn/T/rindle-install-smoke-8/rindle_public_compat_smoke_app

[error] Postgrex.Protocol ... FATAL 53300 (too_many_connections) sorry, too many clients already

** (ArgumentError) you tried to use a binary for an oid type (public.oban_jobs) when an integer was expected.
    (postgrex 0.22.4) lib/postgrex/type_module.ex:1045: Postgrex.DefaultTypes.encode_params/3
    test/install_smoke/support/generated_app_helper.ex:1918: Rindle.InstallSmoke.GeneratedAppHelper.run_cmd!/3
    test/install_smoke/support/generated_app_helper.ex:361: Rindle.InstallSmoke.GeneratedAppHelper.prove_package_install!/2
    test/install_smoke/generated_app_smoke_test.exs:411: Rindle.InstallSmoke.GeneratedAppPublicCompatibilityTest.__ex_unit_setup_all_1/1
```

After the failure, the command remained stalled in its generated-app cleanup for over a minute. The isolated verification session was interrupted and exited `130`; it is explicitly not recorded as success. That candidate has since been superseded by the OID binding fix.

### Current-Candidate Rerun After Capacity Cleanup and OID Binding Fix

The exact chained command was run from clean detached candidate `92201beea7969a80aa7d335646c408cfc424a592` after `MIX_ENV=test mix deps.get` exited `0`.

- **Stage 1 — docs/release parity:** passed: `56 tests, 0 failures`.
- **Stage 2 — packed explicit-public compatibility:** failed during `setup_all`; it did not produce a valid packed receipt.
- **Stage 3 — packed populated isolation upgrade:** not executed because the chain uses `&&`.
- **Stage 4 — Cohort Compose smoke:** not executed because the chain uses `&&`.

Raw Stage 2 diagnostic:

```text
** (RuntimeError) command failed (1): mix run --no-start priv/install_smoke/migrate.exs
cwd: /var/folders/f3/f0clj9rd2zb85n2c849wcsrc0000gn/T/rindle-install-smoke-11010/rindle_public_compat_smoke_app

** (Postgrex.Error) ERROR 42601 (syntax_error) syntax error at or near "constraint"

query: select constraint.conname, constraint.contype::text, pg_get_constraintdef(constraint.oid) from pg_constraint constraint where constraint.conrelid = $1 order by constraint.conname
    (ecto_sql 3.14.0) lib/ecto/adapters/sql.ex:1121: Ecto.Adapters.SQL.raise_sql_call_error/1
    priv/install_smoke/migrate.exs:46: anonymous fn/1 in :elixir_compiler_2.__FILE__/1
```

No `53300` connection-limit error occurred in this current-candidate attempt. Its failed generated-app cleanup again stalled, so the isolated verification session was interrupted and exited `130`; it is explicitly not recorded as success.

## Required External Evidence (Not Inspected)

Per the plan, GitHub evidence is intentionally not inspected until Task 1 has clean passing local receipts. When the dependency prerequisite has been restored and Task 1 passes, record immutable URLs, run IDs, conclusions, and job/step results for this exact SHA only:

`92201beea7969a80aa7d335646c408cfc424a592`

Required evidence:

- Green `ci.yml` with matching `headSha`, including `Proof`, lean `Package Consumer Proof Matrix + Release Preflight`, and `Adoption Demo Unit`.
- For the push-to-main candidate, green `Package Consumer Full Matrix + Release Preflight` and `Cohort Demo Smoke`.
- Green `Release` workflow on that same SHA with `Run release preflight`, `Verify version alignment`, `Dry run Hex publish`, and `Verify public Hex.pm artifact`.

Local output is diagnostic only and is never release authorization.

## Deviations from Plan

None — the plan required a fail-closed record when an environment prerequisite blocked the command chain.

## Issues Encountered

- The superseded candidate initially lacked declared Mix dependencies, then hit PostgreSQL `53300` and the OID parameter encoding error. It is retained only as historical diagnostic evidence.
- The current candidate clears the prior connection-capacity and OID failures but its packed explicit-public generated migration now has an unquoted `pg_constraint constraint` alias, which PostgreSQL rejects with `42601`. Product source was not changed because this executor owns receipts only.

## Next Phase Readiness

Blocked. Resolve the current candidate's packed generated-app `pg_constraint` alias syntax error, then rerun the exact chained Task 1 command. Only after all four stages pass may GitHub Actions evidence for `92201beea7969a80aa7d335646c408cfc424a592` be inspected.

## Self-Check: PASSED

- Current candidate SHA resolves to the detached clean worktree and has 40 characters.
- This receipt file exists; no product source files were modified.
