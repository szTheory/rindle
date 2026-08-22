# Rindle Release Train

Rindle is on a sustaining release train after the v1.17 mission-complete boundary.

The default operating mode is not "find the next milestone." The default is: keep `main`
green, keep release truth coherent, and let patch-eligible merged changes ride the
maintained automated release lane. When future feature work is justified, use the milestone
PR lane in `.planning/DEVELOPMENT-TRAIN.md`.

## Current Baseline

- Latest released version: `0.4.1` (Hex.pm, 2026-08-22)
- Catch-up release: none (published)
- GSD posture: `demand-gated-pause` (formalized 2026-05-27)
- Release automation: Release Please + exact-ref dispatch publish (see `.github/workflows/release.yml`)
- Last publish workflow: https://github.com/szTheory/rindle/actions/runs/32570753742
- Last publish CI gate: https://github.com/szTheory/rindle/actions/runs/32546847350
- Last public verify: https://github.com/szTheory/rindle/actions/runs/32570753742 (Hex index + `scripts/public_smoke.sh` passed)

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
| 2026-06-29 | Release-please stuck: 0.3.2 PR never opened | Root-caused + guarded | `Bad credentials` 401 in [run 28399407429](https://github.com/szTheory/rindle/actions/runs/28399407429); `RELEASE_PLEASE_TOKEN` expired; `secrets.X \|\| github.token` masks a bad token (PR #40 was the 0.3.1 PR; fixes merged 2026-06-28). Rotated token + added release-train-drift guard + token-validity guard. |
| 2026-06-30 | 0.3.2 publish + public verify | Pass | [run 28420598348](https://github.com/szTheory/rindle/actions/runs/28420598348) (merge SHA `d228b67`) — Publish + Public Verify GREEN; Hex live == 0.3.2. Required THREE fixes: rotate expired `RELEASE_PLEASE_TOKEN` (fine-grained PAT) + relabel #40 `pending`→`tagged` + manual publish-dispatch (PAT lacked `Actions: write` — durable fix pending: add `Actions: Read and write` to the PAT or move to a GitHub App token). |
| 2026-08-20 | 0.4.0 publish + public verify | Pass | [run 32383632492](https://github.com/szTheory/rindle/actions/runs/32383632492) — frozen source `78349c1…`; exact-source CI [32371768158](https://github.com/szTheory/rindle/actions/runs/32371768158); Hex and fresh public artifact verification green. |

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
latest `main` CI is green (`CI Summary` succeeded), the repo hygiene gate reports no `BLOCK`,
and release truth is coherent across
`mix.exs`, `.release-please-manifest.json`, and `CHANGELOG.md`.

## Merge-Blocking CI Jobs

Branch protection requires the single aggregate `CI Summary` context. Its merge-blocking
inputs are (see `RUNNING.md` and `.github/workflows/ci.yml`):

- Quality (1.15, 26) and Quality (1.17, 27)
- ADMIN-06 Optional Dependencies (1.15, 26) and (1.17, 27)
- Integration
- Contract
- Proof
- Package Consumer (lean image proof; workflow display name remains historical)
- Adoption Demo Unit
- Adoption Demo E2E Smoke
- Adopter
- brandbook-tokens
- CI Script Tests

The full package-consumer matrix, Cohort smoke, and full browser E2E run on push to
`main`; Dialyzer and GCS live proof run nightly. Mux soak is label-gated. These are not
PR merge-blocking contexts, but push-main failures block release readiness.

When `BRANCH_PROTECTION_PAT` is set, `branch-protection-apply.yml` enforces these contexts on
`main` (see `bash scripts/setup_branch_protection.sh --print-expected`).
