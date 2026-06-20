#!/usr/bin/env bash
# check_required_checks.sh — record the LIVE branch-protection required checks
# (OBS-03) and diff them against the committed expected list.
#
# WHY THIS EXISTS
# ---------------
# Phase 103 must capture the *actual* live required-check names BEFORE the v1.20
# pipeline restructuring (the Phase 105 aggregate-check flip depends on knowing the
# exact pre-change gate). The expected list lives in scripts/setup_branch_protection.sh;
# the live list can drift from it — and DOES today: `brandbook-tokens` is in the
# expected list but absent from live `.contexts[]`. Capturing that drift verbatim is
# the whole point of OBS-03 (see 103-RESEARCH.md).
#
# This script is READ-ONLY (D-09 / D-14): it GETs `/required_status_checks` only and
# MUST NOT mutate branch protection — any write request to `/protection` here would be
# a silent gate-behavior change (threat T-103-03). It does NOT re-encode the expected
# names; it reuses setup_branch_protection.sh --print-expected-json as the single
# source of truth.
#
# Auth: reading `.../branches/{branch}/protection/...` requires admin-read on the repo,
# which a maintainer's local `gh auth login` session has. No separate PAT is needed
# for a read-only capture.
#
# Usage: scripts/ci/check_required_checks.sh [branch]   (default branch: main)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

if ! command -v gh >/dev/null 2>&1; then
  echo "[check-required-checks] gh CLI is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[check-required-checks] jq is required" >&2
  exit 1
fi

REPO="${GITHUB_REPOSITORY:-szTheory/rindle}"
BRANCH="${1:-main}"

# LIVE required checks. Prefer legacy flat `.contexts[]` (verbatim names) over the
# newer `.checks[].context` objects (103-RESEARCH.md Pitfall 3).
live="$(gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${REPO}/branches/${BRANCH}/protection/required_status_checks" \
  --jq '.contexts[]' | sort)"

# EXPECTED list — reuse the write script's read-only flag; do NOT re-encode names (D-09).
expected="$(bash "${repo_root}/scripts/setup_branch_protection.sh" --print-expected-json \
  | jq -r '.required_status_checks.contexts[]' | sort)"

echo "## Live required status checks (${REPO}@${BRANCH})"
while IFS= read -r ctx; do
  printf '  - %s\n' "${ctx}"
done <<<"${live}"
echo ""
echo "## Diff vs setup_branch_protection.sh expected (< expected-only / > live-only):"
# Drift is expected (e.g. brandbook-tokens expected-only today); a nonzero diff exit
# is informational, not a failure — tolerate it so the capture always completes.
diff <(echo "${expected}") <(echo "${live}") || true
