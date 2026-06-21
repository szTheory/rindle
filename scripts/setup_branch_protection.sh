#!/usr/bin/env bash
# setup_branch_protection.sh — idempotently configure branch protection on main.
#
# Usage:
#   GH_TOKEN=<admin-PAT> scripts/setup_branch_protection.sh [branch]
#   scripts/setup_branch_protection.sh --print-expected
#   scripts/setup_branch_protection.sh --print-expected-json

set -euo pipefail

OWNER="${GITHUB_REPOSITORY_OWNER:-szTheory}"
REPO_NAME="${GITHUB_REPOSITORY:-}"
REPO_NAME="${REPO_NAME##*/}"
REPO_NAME="${REPO_NAME:-rindle}"
REPO="${OWNER}/${REPO_NAME}"

REQUIRED_CHECKS=(
  "CI Summary"
)

print_expected_text() {
  cat <<'TEXT'
Expected required status checks:
  - CI Summary

Expected non-context branch protection fields:
  - required_status_checks.strict: true
  - enforce_admins: false
  - required_pull_request_reviews: null
  - restrictions: null
  - allow_force_pushes: false
  - allow_deletions: false
  - block_creations: false
  - required_conversation_resolution: false
  - lock_branch: false
  - allow_fork_syncing: false
TEXT
}

expected_json() {
  local contexts_json
  contexts_json=$(printf '%s\n' "${REQUIRED_CHECKS[@]}" | jq -R . | jq -s .)

  jq -n \
    --argjson contexts "${contexts_json}" \
    '{
      required_status_checks: {
        strict: true,
        contexts: $contexts
      },
      enforce_admins: false,
      required_pull_request_reviews: null,
      restrictions: null,
      allow_force_pushes: false,
      allow_deletions: false,
      block_creations: false,
      required_conversation_resolution: false,
      lock_branch: false,
      allow_fork_syncing: false
    }'
}

FORCE=false
BRANCH=""
for arg in "$@"; do
  case "${arg}" in
    --print-expected)
      print_expected_text
      exit 0
      ;;
    --print-expected-json)
      expected_json
      exit 0
      ;;
    --force)
      FORCE=true
      ;;
    -*)
      echo "unknown option: ${arg}" >&2
      exit 2
      ;;
    *)
      BRANCH="${arg}"
      ;;
  esac
done
BRANCH="${BRANCH:-main}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

# Guard against GitHub's pending-forever trap (D-12). GitHub never verifies that a
# required status-check context name was ever produced: if we make a context (e.g.
# "CI Summary") required BEFORE a check-run with that exact name has posted on BRANCH,
# every subsequent PR hangs forever ("Expected — Waiting for status to be reported").
# So refuse to apply unless every REQUIRED_CHECKS name already exists as a check-run on
# BRANCH's latest commit. This makes the apply self-deferring and safe to run unattended
# (nightly cron / workflow_dispatch / local) with no human go/no-go. When we cannot read
# check-runs (token lacks Checks: read), we also refuse — never mutate when we cannot
# verify. `--force` bypasses the guard for a deliberate first-time bootstrap only.
require_contexts_exist() {
  local ctx names
  for ctx in "${REQUIRED_CHECKS[@]}"; do
    if ! names="$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "repos/${REPO}/commits/${BRANCH}/check-runs" \
        --jq '.check_runs[].name' 2>/dev/null)"; then
      echo "ERROR: could not read check-runs on ${REPO}@${BRANCH} to verify required" >&2
      echo "       contexts before applying (token needs Checks: read)." >&2
      echo "       Refusing to apply to avoid the pending-forever trap (D-12)." >&2
      echo "       Re-run with --force only if the contexts already report." >&2
      return 1
    fi
    if ! grep -Fxq "${ctx}" <<<"${names}"; then
      echo "ERROR: required context '${ctx}' has not yet posted a check-run on" >&2
      echo "       ${REPO}@${BRANCH}. Requiring it now would hang every PR forever" >&2
      echo "       (GitHub does not validate required-context names — D-12)." >&2
      echo "       Let CI run on ${BRANCH} once, then re-run. Use --force to override." >&2
      return 1
    fi
  done
  return 0
}

if [ "${FORCE}" != "true" ]; then
  require_contexts_exist || exit 1
fi

echo "Configuring branch protection for ${REPO}@${BRANCH}..."

gh api -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${REPO}/branches/${BRANCH}/protection" \
  --input - <<<"$(expected_json)"

echo "OK: branch protection configured for ${REPO}@${BRANCH}."
print_expected_text
