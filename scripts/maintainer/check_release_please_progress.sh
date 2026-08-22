#!/usr/bin/env bash
set -euo pipefail

# Release Please can return success without opening/updating a release PR when
# it finds an already-merged release PR that still carries
# `autorelease: pending`. Detect that exact false-green state after the action
# runs so a stuck release train is visible on the push that caused it.

: "${GH_REPO:?GH_REPO must be set to owner/repository}"

if ! last_tag="$(git describe --tags --match 'rindle-v*' --abbrev=0 2>/dev/null)"; then
  echo "No rindle-v* tag exists yet; Release Please has no prior train state to reconcile."
  exit 0
fi

releasable_commits="$(git log "${last_tag}..HEAD" --pretty=%s | grep -cE '^(feat|fix)(\(|:)' || true)"
open_release_prs="$(
  gh pr list \
    --repo "$GH_REPO" \
    --state open \
    --base main \
    --search 'head:release-please--branches--main--components--rindle' \
    --limit 100 \
    --json number \
    --jq 'length'
)"
stale_pending_prs="$(
  gh pr list \
    --repo "$GH_REPO" \
    --state merged \
    --base main \
    --label 'autorelease: pending' \
    --search 'head:release-please--branches--main--components--rindle' \
    --limit 100 \
    --json number \
    --jq 'length'
)"

echo "Release Please progress: tag=${last_tag} releasable=${releasable_commits} open=${open_release_prs} stale_pending=${stale_pending_prs}"

if [ "$releasable_commits" -gt 0 ] && [ "$open_release_prs" -eq 0 ] && [ "$stale_pending_prs" -gt 0 ]; then
  echo "::error::Release Please made no progress: ${releasable_commits} releasable commit(s) follow ${last_tag}, no release PR is open, and ${stale_pending_prs} merged release PR(s) still carry 'autorelease: pending'. Reconcile the published release label to 'autorelease: tagged', then rerun this workflow."
  exit 1
fi

echo "Release Please progress check passed."
