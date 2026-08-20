---
phase: 120-adoption-proof-release-truth
plan: 12
subsystem: release-proof
tags: [release-truth, github-actions, packaged-artifact, cohort, evidence]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: Plan 120-11 local receipt, intentionally restricted to ec3aae5d85225dbdd43992f28a5d30e16fb8aea5
provides:
  - fail-closed prerequisite receipt for the current milestone proof chain
affects: [package-consumer, cohort-demo, release-proof]
tech-stack:
  added: []
  patterns: [exact-sha-evidence, unique-pr-resolution, fail-closed-precondition]
key-files:
  created:
    - .planning/phases/120-adoption-proof-release-truth/120-12-SUMMARY.md
  modified: []
key-decisions:
  - "No local or hosted release-proof receipt may start without exactly one open milestone PR whose explicit headRefOid can bind all candidate evidence."
  - "The historical ec3aae5d85225dbdd43992f28a5d30e16fb8aea5 local receipt remains separate from any later candidate."
metrics:
  completed: 2026-08-19
  tasks: 0
  files: 1
status: blocked
---

# Phase 120 Plan 12: Candidate Proof Precondition Blocked

**No milestone candidate can be selected: GitHub returned zero open PRs for `milestone/v1.23-postgres-schema-isolation`, so no same-SHA local or hosted proof was run.**

## Task 1 — Fail-Closed Precondition Receipt

The plan requires exactly one open milestone PR before creating a detached worktree, fetching dependencies, or exercising any packed/Cohort proof. The read-only selection command returned an empty array:

```sh
gh pr list --state open --head milestone/v1.23-postgres-schema-isolation \
  --json number,url,headRefOid --limit 2
# => []
```

`jq 'length'` returned `0`, not the required `1`. Consequently, there is no PR number, URL, 40-character `headRefOid`, candidate SHA, matched remote milestone commit, or exact-SHA successful `ci.yml` run to record.

No detached worktree was created, no dependency fetch was started, and none of the generated-app, MinIO, Cohort, hygiene, merge, Release Please, protected Release, or publish actions ran. This preserves the plan's trust boundary between the dirty shared checkout and an immutable candidate.

## Observed Non-Authoritative Environment Facts

These facts were checked only while evaluating the prerequisite; they do not satisfy the missing PR identity requirement:

| Check | Result |
| --- | --- |
| Docker daemon | reachable; server `29.5.2` |
| Loopback port `14102` | unused |
| Loopback port `19000` | unused |
| Loopback port `19001` | unused |
| Shared checkout | dirty and on `main` at `b9c9785fba4af366fe008687510471cffa6779b1`; never used as candidate evidence |

## Immutable Evidence Separation

- Historical local receipt: `ec3aae5d85225dbdd43992f28a5d30e16fb8aea5` remains recorded by Plan 120-11.
- Historical failed PR CI: run `31448759145` for `ec3aae5d85225dbdd43992f28a5d30e16fb8aea5` remains a failed fact.
- The Plan 120 context's prior successful PR candidate `fcd806685fa86445a4db203a7b338dee23f9ae94` is not treated as current evidence: it is not an open milestone-PR head today and has no same-SHA local receipt in this plan.

No results from those identities have been combined with the current checkout or with each other.

## Verification

| Check | Result |
| --- | --- |
| `frontmatter.validate 120-12-PLAN.md --schema plan` | PASS |
| `verify.plan-structure 120-12-PLAN.md` | PASS (2 tasks) |
| Unique open milestone PR prerequisite | BLOCKED (`0` returned; exactly `1` required) |

## Deviations from Plan

None - the plan's mandatory precondition failed before Task 1 could begin, so no implementation or integration work was performed.

## Known Stubs

None.

## Threat Flags

None. This receipt adds no runtime, network endpoint, authentication path, schema change, or release mutation.

## Awaiting Maintainer Action

Restore or identify the one intended open milestone PR with head `milestone/v1.23-postgres-schema-isolation`, then provide its explicit PR number or URL. On resume, the executor will re-query it, require a 40-character `headRefOid` equal to the fetched `origin/milestone/v1.23-postgres-schema-isolation` SHA, and only then perform the clean detached same-SHA proof chain.

Do not substitute the dirty checkout `HEAD`, a closed PR, a branch label, `ec3aae5...`, `fcd8066...`, or a later `main` commit.

## Self-Check: PASSED

- The receipt is present at the plan-required path.
- The recorded PR-selection output is exact and contains no candidate SHA to misattribute.
- No product, workflow, release, or existing-summary file was changed.
