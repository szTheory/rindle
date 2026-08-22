#!/usr/bin/env bash
set -euo pipefail

# Run only after Public Verify succeeds. If the immutable release SHA came from
# a merged Release Please PR, public verification is the evidence needed to
# move its state label from pending to tagged.

: "${GH_REPO:?GH_REPO must be set to owner/repository}"
: "${RELEASE_SHA:?RELEASE_SHA must be set to the immutable published commit}"

release_pr_numbers="$(
  gh api "repos/${GH_REPO}/commits/${RELEASE_SHA}/pulls" --jq '
    .[]
    | select(.merged_at != null)
    | select(.head.ref | startswith("release-please--branches--main--components--rindle"))
    | select(any(.labels[]?; .name == "autorelease: pending"))
    | .number
  '
)"

if [ -z "$release_pr_numbers" ]; then
  echo "No merged pending Release Please PR is associated with ${RELEASE_SHA}; no label reconciliation needed."
  exit 0
fi

if [ "$(printf '%s\n' "$release_pr_numbers" | sed '/^$/d' | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "::error::Expected one merged pending Release Please PR for ${RELEASE_SHA}, found: ${release_pr_numbers//$'\n'/, }."
  exit 1
fi

release_pr_number="$release_pr_numbers"
gh pr edit "$release_pr_number" \
  --repo "$GH_REPO" \
  --remove-label 'autorelease: pending' \
  --add-label 'autorelease: tagged'

labels="$(gh pr view "$release_pr_number" --repo "$GH_REPO" --json labels --jq '.labels[].name')"

if printf '%s\n' "$labels" | grep -Fxq 'autorelease: pending' ||
  ! printf '%s\n' "$labels" | grep -Fxq 'autorelease: tagged'; then
  echo "::error::Release Please label reconciliation did not persist on PR #${release_pr_number}."
  exit 1
fi

echo "Reconciled Release Please PR #${release_pr_number}: autorelease: pending -> autorelease: tagged."
