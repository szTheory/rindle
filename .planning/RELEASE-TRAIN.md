# Rindle Release Train

Rindle is on a sustaining release train after the v1.17 mission-complete boundary.

The default operating mode is not "find the next milestone." The default is: keep `main`
green, keep release truth coherent, and let patch-eligible merged changes ride the
maintained automated release lane. When future feature work is justified, use the milestone
PR lane in `.planning/DEVELOPMENT-TRAIN.md`.

## Current Baseline

- Latest released version: `0.1.8` (Hex.pm, 2026-05-28)
- Catch-up release: none (published)
- GSD posture: `demand-gated-pause` (formalized 2026-05-27)
- Release automation: Release Please + exact-ref dispatch publish (see `.github/workflows/release.yml`)
- Last publish workflow: https://github.com/szTheory/rindle/actions/runs/26591161873
- Last publish CI gate: https://github.com/szTheory/rindle/actions/runs/26588942723
- Last public verify: https://github.com/szTheory/rindle/actions/runs/26591161873 (Hex index + `scripts/public_smoke.sh` passed)

Update this section after each successful Hex publish with run ID, version, and public-smoke proof.

## Verification Log (maintainer)

| Date | Check | Result | Evidence |
|------|-------|--------|----------|
| 2026-05-28 | Catch-up 0.1.6 publish + public smoke | Pass | [run 26552727276](https://github.com/szTheory/rindle/actions/runs/26552727276) — Publish + Public Verify success |
| 2026-05-28 | Baseline job on first 0.1.6 publish | Fail then manual fix | Same run — `Update RELEASE-TRAIN Baseline` failed; ledger synced in `43cfe62` |
| 2026-05-28 | Release Please automerge | Pass | [26552711873](https://github.com/szTheory/rindle/actions/runs/26552711873), [26553751051](https://github.com/szTheory/rindle/actions/runs/26553751051) |
| 2026-05-28 | Branch Protection Apply (cron) | Pass | [26564029665](https://github.com/szTheory/rindle/actions/runs/26564029665) |
| 2026-05-28 | PATs configured | Pass | `RELEASE_PLEASE_TOKEN`, `BRANCH_PROTECTION_PAT` set in repo secrets |
| 2026-05-28 | 0.1.7 publish + public smoke + automated baseline | Pass | [run 26578423402](https://github.com/szTheory/rindle/actions/runs/26578423402) — all jobs success; baseline ledger updated on `main` without manual edit |
| 2026-05-28 | Release Please new PR after 0.1.6 | **Resolved** | Retagged `rindle-v0.1.6` → `b5a6a0d`; removed `autorelease: pending` from PR #12; RP opened [#14](https://github.com/szTheory/rindle/pull/14) (0.1.8) |

## Automated Release Loop

```text
green main CI
  → Release Please opens/updates release PR
  → release-please-automerge.yml squash-merges when eligible
  → release.yml workflow_dispatch on exact merge SHA
  → gate-ci-green (ci.yml must succeed on that SHA)
  → publish (Hex + GitHub release)
  → public_verify (Hex index + scripts/public_smoke.sh)
  → update-release-train-baseline commit to main [skip ci]
```

Branch protection is re-asserted by `.github/workflows/branch-protection-apply.yml` when
`BRANCH_PROTECTION_PAT` is configured (see below).

## Repository Secrets

| Secret | Required | Role |
|--------|----------|------|
| `HEX_API_KEY` | Yes (release environment) | Hex.pm publish in `release.yml` |
| `RELEASE_PLEASE_TOKEN` | Optional | Automerge, baseline push, and dispatch if `GITHUB_TOKEN` recursion blocks |
| `BRANCH_PROTECTION_PAT` | Optional | Fine-grained PAT with **Administration: read/write** for `branch-protection-apply.yml` |

Without `BRANCH_PROTECTION_PAT`, run `bash scripts/setup_branch_protection.sh main` locally once
with an admin-capable `gh auth` session.

## Normal Train Rules

- `demand-gated-pause` remains the default GSD milestone state.
- Patch-eligible merged changes flow to the next release through Release Please on `main`.
- The train is ready to move only when `main` is green and
  `./scripts/maintainer/repo_hygiene_check.sh` passes without `BLOCK`.
- If `main` is green and release truth is coherent, the default stance is **silence on the wire**:
  no milestone churn, no release drama, no invented work.
- `workflow_dispatch` is exact-ref only for release automation or recovery and must replay an
  exact immutable ref; it does not create new release intent.
- Push-triggered Release Please manages release PRs only (`skip-github-release: true`); the
  exact-ref dispatch publish lane owns GitHub release/tag creation and Hex publish.
- Eligible Release Please PRs auto-merge only after green `main` CI and only through the
  guarded Release Please branch/title/file allowlist in `release-please-automerge.yml`.

## Patch-Eligible Change Classes

- Bug fixes on shipped behavior
- Docs or support-truth corrections that narrow drift without widening claims
- Release-hygiene, CI-drift, or maintainer-runbook hardening
- Narrow hardening on already-supported surfaces that does not expand the public API contract

## Work That Requires A New Milestone

- Force-delete shared assets (LIFE-06) — compliance/legal ticket required
- Second streaming provider (STREAM-10) — named adopter + provider choice required
- Signed dynamic transforms (TRANS-01) or EXIF privacy stripping (PRIV-01) — explicit product pull
- Any semver-significant public API reshape or new support claim

Feature milestones run on `milestone/vNEXT-short-slug` branches and merge through one PR to
`main` after GSD verification, milestone audit, and green PR CI. Do not create manual release
branches for feature milestones; after merge, Release Please owns the normal release PR.

## Next Cut Condition

Cut the next release when there is at least one merged patch-eligible change on `main`, the
latest `main` CI is green (merge-blocking jobs: Quality, Integration, Proof, Package Consumer,
Adopter), the repo hygiene gate reports no `BLOCK`, and release truth is coherent across
`mix.exs`, `.release-please-manifest.json`, and `CHANGELOG.md`.

## Merge-Blocking CI Jobs

Required for a releasable `main` (see `RUNNING.md` and `.github/workflows/ci.yml`):

- Quality (1.15, 26) and Quality (1.17, 27)
- Integration
- Contract
- Proof
- Package Consumer Proof Matrix + Release Preflight
- Adopter

Optional/soak lanes (mux-soak, gcs-soak) are not merge-blocking.

When `BRANCH_PROTECTION_PAT` is set, `branch-protection-apply.yml` enforces these contexts on
`main` (see `bash scripts/setup_branch_protection.sh --print-expected`).
