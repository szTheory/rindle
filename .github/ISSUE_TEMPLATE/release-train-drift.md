---
title: "Release train drift: main ahead of last rindle-v* tag with no open release PR"
labels: ["area:release", "severity:drift"]
assignees: szTheory
---

The `release-train-drift` guard detected that `main` carries releasable
`feat:`/`fix:` commits ahead of the last `rindle-v*` tag, yet there is **no open
Release Please PR** to cut them. The release train is stuck — this is the same
class of footgun that stalled the 0.3.2 cut (an expired `RELEASE_PLEASE_TOKEN`
silently defeating the `secrets.RELEASE_PLEASE_TOKEN || github.token` fallback).

- Workflow run: {{ env.GITHUB_SERVER_URL }}/{{ env.GITHUB_REPOSITORY }}/actions/runs/{{ env.GITHUB_RUN_ID }}

## Likely causes

- `RELEASE_PLEASE_TOKEN` is expired/revoked or lacks the scopes Release Please
  needs — the `release.yml` token-validity guard (D-06b) surfaces this loudly on
  the next push to `main`. Rotate the secret (fine-grained PAT with
  `contents:write` + `pull-requests:write`, or a GitHub App installation token).
- The Release Please PR was closed without merging — push any commit to `main`
  to re-open it.

## What to do

1. Open the run above and read the predicate output (`ahead` / `open_pr` counts).
2. Verify `RELEASE_PLEASE_TOKEN` validity; the next `release.yml` run on `main`
   will fail loud with a rotation hint if the token is invalid.
3. Once an open Release Please PR exists (or the releasable commits are cut),
   this issue auto-closes on the next scheduled drift check.

See `guides/release_publish.md` "Recovery Workflow Contract" for the stuck-release runbook.
