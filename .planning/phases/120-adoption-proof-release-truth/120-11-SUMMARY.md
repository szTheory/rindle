---
phase: 120-adoption-proof-release-truth
plan: 11
subsystem: release-proof
tags: [elixir, packaged-artifact, cohort, docker, postgresql, release]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: snapshot-only Oban proof contract from Plan 120-10
provides:
  - clean local packed and Cohort diagnostic receipt for the post-fix candidate
affects: [package-consumer, cohort-demo, release-proof]
tech-stack:
  added: []
  patterns: [clean-detached-candidate, dedicated-tmpdir, fail-fast-preflight, fail-closed-integration]
key-files:
  created: []
  modified:
    - .planning/phases/120-adoption-proof-release-truth/120-11-SUMMARY.md
key-decisions:
  - "Local package and Cohort receipts are diagnostic only; immutable external authorization must match the exact candidate SHA."
  - "Focused MinIO scenario tags guard sibling generated-app modules, so each Phase 120 packed command executes only its selected scenario."
metrics:
  completed: 2026-08-11
  tasks: 1
  files: 1
status: blocked
---

# Phase 120 Plan 11: Local Proof Complete, External Evidence Pending

**The post-fix candidate passes the complete clean packed and Cohort local proof; exact-SHA GitHub CI and Release authorization have not run and remain a blocking human verification gate.**

## Candidate and Environment Identity

- **Candidate SHA:** `ec3aae5d85225dbdd43992f28a5d30e16fb8aea5` (40 characters), commit subject `fix(install-smoke): isolate focused MinIO scenarios`.
- **Candidate provenance:** current `HEAD` resolved to this exact commit and includes the cleanup fix; the superseded `50b769f48d176ba6dcba47d560e3f09635124576` receipt is not used as passing evidence.
- **Clean detached worktree:** `/private/tmp/rindle-120-11-clean.PNda4i`; `git status --porcelain=v1` was empty before and after the evidence chain.
- **Dedicated TMPDIR:** `/private/tmp/rindle-120-11-tmp.rin4NS`, mode `700`, used for dependency resolution and every receipt command.
- **Preconditions:** Docker server `29.5.2` and PostgreSQL `localhost:5432` were reachable. Loopback ports `14102`, `19000`, and `19001` were free before the worktree was created and again immediately before Cohort launch.
- **Dependency fetch:** `TMPDIR=/private/tmp/rindle-120-11-tmp.rin4NS MIX_ENV=test mix deps.get` exited `0` (`All dependencies have been fetched`).

The main checkout deliberately stayed dirty and untouched; its unrelated user edits and `.planning/debug/phase-120-plan-11-cleanup.md` were not staged or changed.

## Task 1 — Fail-Fast Preflight

The first recorder had the known shell-status defect and did not produce reliable status values. No integration command had started, so the entire preflight was rerun through Bash before MinIO, generated-app, or Cohort work. The following complete second receipt passed in order:

| Command | Exit | Result |
| --- | ---: | --- |
| `MIX_ENV=test mix deps.get` | 0 | Declared dependencies fetched |
| `mix format --check-formatted test/install_smoke/support/generated_app_helper.ex test/install_smoke/generated_app_smoke_test.exs` | 0 | Formatter passed |
| `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` | 0 | `8 tests, 0 failures` |
| `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_fast_contract --seed 0` | 0 | `12 tests, 0 failures` |
| `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0` | 0 | `56 tests, 0 failures` |

Only after this receipt passed did `bash scripts/ensure_minio.sh` run; it exited `0`.

## Task 1 — Packed Package Receipts

Each command ran in a separate BEAM instance with `RINDLE_INSTALL_SMOKE_PROFILE=image`, `--include minio`, and an explicit Phase 120 scenario tag. The post-fix scenario guard excluded sibling generated-app modules, as confirmed by the focused public command running one test rather than serially executing the upgrade scenario.

| Stage | Command | Exit | Result |
| --- | --- | ---: | --- |
| Packed explicit-public compatibility | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_public_compat --seed 0` | 0 | `1 test, 0 failures` in `43.2s` |
| Packed populated isolation upgrade | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio --only phase_120_isolation_upgrade --seed 0` | 0 | `1 test, 0 failures` in `88.5s` |

The populated-upgrade assertion passed from the built package consumer and therefore observed all required catalog facts:

- Marker versions were exactly `[1]`.
- `rindle.media_variants` had the named `media_variants_asset_id_fkey` foreign key to `rindle.media_assets(id)`.
- The ordered named indexes were `media_variants_asset_id_name_index`, `media_variants_state_index`, and `media_variants_output_kind_index`.
- The complete `public.oban_jobs` catalog snapshots before and after the directional migration were non-empty/complete and exactly equal.
- Public host relations remained `oban_jobs` and `schema_migrations`; generated Rindle relations appeared only in the selected schema, and persistence lifecycle/doctor assertions passed.

After each packed stage, generated-app PostgreSQL session count returned to `0`; there was no stalled process or cleanup residue.

## Task 1 — Cohort Receipt

```sh
COHORT_DEMO_PORT=14102 COHORT_MINIO_PORT=19000 COHORT_MINIO_CONSOLE_PORT=19001 \
  bash scripts/ci/cohort_demo_smoke.sh
```

The command exited `0`. Cohort built and started its Compose-owned services, then cleaned up its containers, volumes, and network. The smoke receipt confirms:

- `/`, `/admin/rindle`, and `/admin/rindle/assets` all returned HTTP `200`.
- Seeded data was present on the admin assets surface.
- All seven Rindle relations—`media_assets`, `media_attachments`, `media_variants`, `media_upload_sessions`, `media_processing_runs`, `media_provider_assets`, and `rindle_migration_versions`—were in `rindle` only.
- Oban and the host migration ledger remained in `public`.
- The explicit host-publish overrides eliminated the prior MinIO port-9000 collision without changing Compose-internal `minio:9000` routing.

## Task 2 — Repository Hygiene and Immutable Evidence

`./scripts/maintainer/repo_hygiene_check.sh` ran from the same clean detached candidate before external inspection. It exited `0` with `10 PASS, 1 WARN, 0 BLOCK`; the only warning was that local main is ahead of `origin/main` by 296 commits. The candidate worktree was clean.

Exact-SHA inspection then returned no immutable runs:

```text
gh run list --commit ec3aae5d85225dbdd43992f28a5d30e16fb8aea5 --workflow ci.yml ...  => []
gh run list --commit ec3aae5d85225dbdd43992f28a5d30e16fb8aea5 --workflow release.yml ... => []
git branch -r --contains ec3aae5d85225dbdd43992f28a5d30e16fb8aea5 => (none)
```

No GitHub Actions URL, run ID, `headSha`, conclusion, push-main lane, or protected Release authorization exists for this candidate. Local results are diagnostic evidence only and do **not** authorize a release claim.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Superseded the stale packed-cleanup receipt after the scenario-isolation fix**

- **Found during:** Task 1 continuation.
- **Issue:** `--include minio` and `--only phase_120_public_compat` were additive, so sibling MinIO generated-app scenarios could run after the selected test and make cleanup appear stalled.
- **Fix:** Candidate `ec3aae5` adds scenario-aware module guards and regression coverage. Task 1 was rerun in full from a new clean detached worktree, and both focused packed stages now terminate cleanly.
- **Files modified:** Candidate source/test files in commit `ec3aae5`; this plan changes only the receipt.
- **Commit:** Task receipt commit below.

**2. [Rule 1 - Bug] Re-ran the preflight with reliable Bash pipeline status capture**

- **Found during:** Task 1 continuation.
- **Issue:** An initial zsh recorder emitted empty stage exit values.
- **Fix:** Before any integration command, reran the entire preflight in Bash and recorded every zero exit code above.
- **Files modified:** None.
- **Commit:** Task receipt commit below.

## Known Stubs

None.

## Threat Flags

None. This evidence-only plan adds no endpoint, authentication path, file-access pattern, or schema change.

## Awaiting Human Verification

Push/merge is intentionally not authorized here. Provide immutable GitHub Actions URLs for the exact SHA `ec3aae5d85225dbdd43992f28a5d30e16fb8aea5`, with successful `headSha`-matched conclusions for:

1. `ci.yml`: `Proof`, lean `Package Consumer Proof Matrix + Release Preflight`, and `Adoption Demo Unit`.
2. Push-to-main lanes: `Package Consumer Full Matrix + Release Preflight` and `Cohort Demo Smoke`.
3. Protected `Release`: `Run release preflight`, `Verify version alignment`, `Dry run Hex publish`, and `Verify public Hex.pm artifact` when release authorization is requested.

## Self-Check: PASSED (Task 1)

- The exact candidate commit and the clean detached worktree were verified before testing.
- All five preflight stages, MinIO, both packed stages, Cohort, and repository hygiene recorded exit `0`.
- The local candidate worktree was clean after the complete chain.

Plan completion remains blocked until a human supplies or describes the missing exact-SHA external evidence.
