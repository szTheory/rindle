---
created: 2026-10-15T16:00:00.000Z
title: Replace release and branch-protection PATs with a GitHub App
area: ci-release
due: 2026-11-15
trigger: "RELEASE_PLEASE_TOKEN or BRANCH_PROTECTION_PAT expires, or the release.yml 'Validate RELEASE_PLEASE_TOKEN' step fails"
files:
  - .github/workflows/release.yml
  - .github/workflows/release-please-automerge.yml
  - .github/workflows/branch-protection-apply.yml
  - .github/ISSUE_TEMPLATE/release-train-drift.md
---

## Problem

Two fine-grained PATs drive the release train, and both expire, so the maintainer keeps rotating them:

| Secret | Set | Used by | Needs |
|---|---|---|---|
| `RELEASE_PLEASE_TOKEN` | 2026-08-19 | `release.yml` (release-please, publish/verify steps), `release-please-automerge.yml` (merge + `gh workflow run release.yml`) | Contents, Pull requests, Issues: RW; Actions: RW (the dispatch 403s without it) |
| `BRANCH_PROTECTION_PAT` | 2026-05-28 | `branch-protection-apply.yml` | Administration: RW |

If the release PAT used the 90-day default, it expires around 2026-11-17. Expiry is silent until the next release: the validate step fails loud, but no Hex publish happens.

Note from 2026-10-15: both tokens were **valid**. The red Release run 38680143785 was the `autorelease: pending` race on #116, and the daily Branch Protection Apply red was the `[skip ci]` head-commit guard bug, fixed separately. Check the actual `##[error]` line before blaming a token.

## Solution

Use one private GitHub App with tokens minted per job (`actions/create-github-app-token`, pinned by SHA). The App's private key never expires, and each token lives one hour. App tokens, unlike `github.token`, do trigger downstream workflows, so release-please PRs still get CI.

1. **Human step (auto mode blocks agents from creating credential grants).** Create the app from this pre-filled link, generate a private key, and install the app on `szTheory/rindle` only:
   `https://github.com/settings/apps/new?name=rindle-release-sztheory&url=https%3A%2F%2Fgithub.com%2FszTheory%2Frindle&public=false&webhook_active=false&contents=write&pull_requests=write&issues=write&actions=write&administration=write`
2. Store the app ID as variable `RELEASE_APP_ID` (`gh variable set`) and the key as secret `RELEASE_APP_PRIVATE_KEY` (`gh secret set RELEASE_APP_PRIVATE_KEY < key.pem`; never paste it). Then delete the `.pem`.
3. PR (`ci:` prefix so no release bump): in each job, add a `create-github-app-token` step and narrow it with `permission-*` inputs. Only the branch-protection job gets `administration: write`.
   - Replace `secrets.RELEASE_PLEASE_TOKEN || github.token` with the step output. Keep the "fail loud" validation, now against the minted token.
   - Update the error text and the drift issue template, which name the PAT.
   - Grep `test/install_smoke` for literal `RELEASE_PLEASE_TOKEN` / `BRANCH_PROTECTION_PAT` locks and update them in the same PR.
4. Prove it: dispatch-run `release.yml` with nothing to release, and confirm the validate and release-please steps pass. Run `branch-protection-apply.yml` by `workflow_dispatch`.
5. **Human step.** Delete both PATs at github.com/settings/personal-access-tokens, then remove both secrets (`gh secret delete`).
