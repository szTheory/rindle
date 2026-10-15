---
created: 2026-10-15T22:00:00.000Z
title: Stop the hex-baseline hygiene BLOCK from reddening main CI that overlaps a Hex publish
area: ci-release
trigger: "A main CI run fails 'Repo hygiene gate (release train)' with '[BLOCK] hex baseline: Hex.pm (X) matches mix.exs but RELEASE-TRAIN baseline is still Y' right after a release"
files:
  - scripts/maintainer/repo_hygiene_check.sh
  - .github/workflows/release.yml
---

## Problem

`repo_hygiene_check.sh` (hex baseline check) BLOCKs when Hex.pm already lists the `mix.exs` version but
`RELEASE-TRAIN.md` still records the previous baseline. The release workflow writes the new baseline
only after Public Verify, in a `[skip ci]` commit. Any main CI run that checked out a commit before
that baseline commit, and reaches the hygiene step after Hex publishes, goes red.

Seen 2026-10-15: run 38809962966 on `da637439` (#122 req bump). All five Package Consumer Full lanes
failed with the BLOCK above while 0.4.8 published (recovery run 38806586167). The baseline commit
`23f18750` (#126) is `[skip ci]`, so main HEAD had no CI run until the next non-skip push.

## Solution options

1. In the hygiene check, PASS (or WARN) when the baseline lags Hex by exactly the version in `mix.exs`
   and that version was published recently, since the release workflow will record it.
2. Drop `[skip ci]` from the release workflow's baseline commit, so main HEAD always gets a CI run
   after a publish. This costs one extra CI run per release.

Option 1 fixes the red. Option 2 only shortens how long main HEAD goes without a CI run. Both can apply.
