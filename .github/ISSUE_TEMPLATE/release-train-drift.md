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

- The selected release credential is invalid or lacks repository access. Check
  `RELEASE_APP_CLIENT_ID` / `RELEASE_APP_PRIVATE_KEY` if configured; otherwise check
  the existing `RELEASE_PLEASE_TOKEN`. Partial or invalid App configuration fails
  without falling back. Release and protection must use different Apps.
- The Release Please PR was closed without merging — push any commit to `main`
  to re-open it.

## What to do

1. Open the run above and read the predicate output (`ahead` / `open_pr` counts).
2. Inspect the selected credential's mint/admission step on the intended `main`
   run. Read admission proves identity and repository scope, not write capability.
   Fix that principal rather than widening it or borrowing protection credentials.
3. Once an open Release Please PR exists (or the releasable commits are cut),
   this issue auto-closes on the next scheduled drift check.

See `guides/release_publish.md` "Recovery Workflow Contract" for the stuck-release runbook.
