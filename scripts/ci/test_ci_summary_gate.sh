#!/usr/bin/env bash
# test_ci_summary_gate.sh — unit tests for the CI Summary aggregate gate (GATE-01).
#
# WHY THIS EXISTS
# ---------------
# The skip-as-pass semantics of `ci-summary` (D-05) close the fork-PR "pending forever"
# trap: the repo-gated jobs (cohort-demo-smoke, adoption-demo-e2e, brandbook-tokens)
# skip on forks, and treating a skip as a pass is what lets `CI Summary` report success
# instead of hanging. Previously that behavior was "logic-provable but observable only
# via a real fork PR" — a manual UAT item. This test pins the regressable part (OUR
# gate logic in eval_ci_summary.sh) so it is merge-blocking in CI. It does NOT (and
# cannot) test GitHub's own `if: github.repository == ...` fork evaluation — that is the
# platform's behavior, exercised by the real `needs:` graph, not by this script.
#
# Usage: scripts/ci/test_ci_summary_gate.sh   (exit 0 = all cases pass)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval_script="${here}/eval_ci_summary.sh"

pass=0
fail=0

# Run the gate against a NEEDS_JSON payload, assert the expected exit code.
#   $1 = test name, $2 = expected exit (0|1), $3 = NEEDS_JSON
expect_exit() {
  local name="$1" want="$2" needs="$3" got=0
  NEEDS_JSON="${needs}" GITHUB_STEP_SUMMARY=/dev/null bash "${eval_script}" >/dev/null 2>&1 || got=$?
  if [ "${got}" -eq "${want}" ]; then
    echo "ok   — ${name} (exit ${got})"
    pass=$((pass + 1))
  else
    echo "FAIL — ${name}: expected exit ${want}, got ${got}" >&2
    fail=$((fail + 1))
  fi
}

# The fork case: roots succeed, the three repo-gated jobs skip → gate PASSES (exit 0).
# This is the exact shape a fork PR produces and the whole reason for skip-as-pass.
expect_exit "fork: repo-gated jobs skipped, rest success → pass" 0 '{
  "quality": {"result": "success"},
  "optional-dependencies": {"result": "success"},
  "integration": {"result": "success"},
  "contract": {"result": "success"},
  "proof": {"result": "success"},
  "package-consumer": {"result": "success"},
  "adoption-demo-unit": {"result": "success"},
  "cohort-demo-smoke": {"result": "skipped"},
  "adoption-demo-e2e": {"result": "skipped"},
  "adopter": {"result": "success"},
  "brandbook-tokens": {"result": "skipped"}
}'

# All green → pass.
expect_exit "all jobs success → pass" 0 '{
  "quality": {"result": "success"},
  "brandbook-tokens": {"result": "success"}
}'

# All skipped → pass (degenerate skip-as-pass).
expect_exit "all jobs skipped → pass" 0 '{
  "quality": {"result": "skipped"},
  "cohort-demo-smoke": {"result": "skipped"}
}'

# A real failure anywhere → fail (the gate must turn red).
expect_exit "one job failure → fail" 1 '{
  "quality": {"result": "success"},
  "integration": {"result": "failure"},
  "brandbook-tokens": {"result": "skipped"}
}'

# A cancelled job → fail (cancellation is not a pass).
expect_exit "one job cancelled → fail" 1 '{
  "quality": {"result": "success"},
  "proof": {"result": "cancelled"}
}'

# Failure is reported even when a fork-gated job skipped in the same run (no masking).
expect_exit "failure alongside a skip → fail" 1 '{
  "quality": {"result": "failure"},
  "cohort-demo-smoke": {"result": "skipped"}
}'

echo "—"
echo "passed: ${pass}  failed: ${fail}"
[ "${fail}" -eq 0 ]
