#!/usr/bin/env bash
# eval_ci_summary.sh — the CI Summary aggregate gate logic (GATE-01), extracted.
#
# WHY THIS EXISTS
# ---------------
# The `ci-summary` job in .github/workflows/ci.yml is the single merge-blocking
# CI-health signal for `main` (Phase 105). Its decision is a pure evaluation of the
# `needs.*.result` context — no network, no `gh api`, so it can never false-red on a
# GitHub API hiccup (D-02). This file holds that decision as a standalone script so it
# can be exercised by an automated unit test (scripts/ci/test_ci_summary_gate.sh)
# instead of only being observable on a real (fork) PR. The ci.yml step calls this
# script; behavior is byte-identical to the previous inline `run:` block.
#
# CONTRACT
#   Input : NEEDS_JSON env var = the GitHub Actions `toJSON(needs)` object, e.g.
#             {"quality":{"result":"success"},"cohort-demo-smoke":{"result":"skipped"}}
#   Output: a `| Job | Result |` table appended to $GITHUB_STEP_SUMMARY (when set).
#   Exit  : 0 if every gating job is success OR skipped (D-05 skip-as-pass — this is
#           what stops fork PRs hanging when repo-gated jobs skip); 1 if ANY job is
#           failure/cancelled. All red lanes are logged before exiting (D-06).
#
# Usage: NEEDS_JSON='{"quality":{"result":"success"}}' scripts/ci/eval_ci_summary.sh
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "[eval-ci-summary] jq is required" >&2
  exit 1
fi

: "${NEEDS_JSON:?NEEDS_JSON must be set to toJSON(needs)}"
# Off CI (local run / unit test) there is no $GITHUB_STEP_SUMMARY; sink the table so
# `set -u` does not trip and the exit code stays the only observable signal.
summary_file="${GITHUB_STEP_SUMMARY:-/dev/null}"

failed=0
{
  echo "## CI Summary"
  echo ""
  echo "| Job | Result |"
  echo "| --- | --- |"
} >> "${summary_file}"
# Iterate every job in needs (drift-proof: auto-covers whatever is in needs:, so there
# is no per-lane env var to keep in sync — D-06).
while IFS=$'\t' read -r job result; do
  echo "| ${job} | ${result} |" >> "${summary_file}"
  case "${result}" in
    success|skipped) ;;                       # D-05: success + skipped → pass
    *)                                         # failure | cancelled → fail
      echo "Gating job '${job}': ${result}"
      failed=1
      ;;
  esac
done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.result)"' <<<"${NEEDS_JSON}")
# Collect-all-then-exit (D-06): every red lane is logged above before we fail.
if [ "${failed}" -ne 0 ]; then
  echo "CI Summary: one or more gating jobs did not pass." >&2
  exit 1
fi
echo "CI Summary: all gating jobs passed (success or intentional skip)."
