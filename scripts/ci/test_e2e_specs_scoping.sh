#!/usr/bin/env bash
# test_e2e_specs_scoping.sh — static assertion for the ADOPTION_DEMO_E2E_SPECS
# spec-scoping contract in scripts/ci/e2e_local.sh (GATE-01, research GATE-A3).
#
# WHY THIS EXISTS
# ---------------
# The lean `adoption-demo-e2e-smoke` PR lane (ci.yml) runs only a deterministic
# 2-spec subset by setting ADOPTION_DEMO_E2E_SPECS, while the full
# `adoption-demo-e2e` push:main lane leaves it unset and runs the whole suite.
# Both lanes share the same wrapper, scripts/ci/e2e_local.sh. The scoping is a
# back-compatible contract:
#   unset -> the playwright command carries NO positional spec (full suite,
#            byte-equivalent to before this var existed);
#   set   -> the playwright command carries exactly the listed spec files.
# This test pins that contract WITHOUT invoking docker or playwright: it extracts
# the `sh -c "..."` invocation line from the wrapper and expands
# `${ADOPTION_DEMO_E2E_SPECS:-}` under each condition, asserting the resolved
# playwright command shape. It is pure string analysis so it can run in any lane.
#
# Usage: bash scripts/ci/test_e2e_specs_scoping.sh   (exit 0 = all cases pass)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wrapper="${here}/e2e_local.sh"

pass=0
fail=0

ok() {
  echo "ok   — $1"
  pass=$((pass + 1))
}
bad() {
  echo "FAIL — $1" >&2
  fail=$((fail + 1))
}

# --- (1) The wrapper references ADOPTION_DEMO_E2E_SPECS in BOTH the docker -e
#         pass-through AND the playwright command line. -----------------------
if grep -q -- '-e ADOPTION_DEMO_E2E_SPECS="${ADOPTION_DEMO_E2E_SPECS:-}"' "${wrapper}"; then
  ok "wrapper passes ADOPTION_DEMO_E2E_SPECS into the container via -e"
else
  bad "wrapper is missing the -e ADOPTION_DEMO_E2E_SPECS pass-through"
fi

# Extract the ACTUAL container command line (the `sh -c "..."` invocation), not any
# prose mention of the command in comments. Anchor on `sh -c` so a comment that
# happens to spell out `npx playwright test` cannot be picked up by accident.
playwright_line="$(grep -E '^\s*sh -c ".*npx playwright test' "${wrapper}" | head -n1)"
if [ -z "${playwright_line}" ]; then
  bad "could not locate the 'sh -c \"... npx playwright test ...\"' invocation in the wrapper"
  echo "—"
  echo "passed: ${pass}  failed: ${fail}"
  exit 1
fi

if printf '%s' "${playwright_line}" | grep -q '${ADOPTION_DEMO_E2E_SPECS:-}'; then
  ok "playwright command references \${ADOPTION_DEMO_E2E_SPECS:-}"
else
  bad "playwright command does not reference \${ADOPTION_DEMO_E2E_SPECS:-}"
fi

# The var MUST be unquoted in the command so word-splitting yields one positional
# argument per spec path. If it were "\${ADOPTION_DEMO_E2E_SPECS:-}" the two specs
# would collapse into a single bogus path.
if printf '%s' "${playwright_line}" | grep -q '"${ADOPTION_DEMO_E2E_SPECS:-}"'; then
  bad "ADOPTION_DEMO_E2E_SPECS is QUOTED in the playwright command (would break multi-spec word-splitting)"
else
  ok "ADOPTION_DEMO_E2E_SPECS is unquoted in the playwright command (word-splits per spec)"
fi

# Resolve the playwright command portion (everything from 'npx playwright test'
# onward) so we can expand the var under each condition exactly as the host bash
# would when building the `sh -c "..."` string.
cmd_template="npx playwright test${playwright_line#*npx playwright test}"
# Drop the trailing closing quote of the surrounding "..." string, if present.
cmd_template="${cmd_template%\"}"

resolve() {
  # Expand ${ADOPTION_DEMO_E2E_SPECS:-} inside the template under the current
  # environment, then collapse whitespace so trailing/duplicate spaces from an
  # empty expansion do not produce false mismatches.
  local resolved
  resolved="$(eval "printf '%s' \"${cmd_template}\"")"
  # shellcheck disable=SC2001
  echo "${resolved}" | sed -e 's/[[:space:]]\{1,\}/ /g' -e 's/[[:space:]]*$//'
}

# --- (2) UNSET -> full suite: the resolved command carries NO positional spec. -
unset ADOPTION_DEMO_E2E_SPECS 2>/dev/null || true
unset_cmd="$(resolve)"
if [ "${unset_cmd}" = "npx playwright test --config=playwright.config.js" ]; then
  ok "unset -> full-suite invocation (no positional spec): ${unset_cmd}"
else
  bad "unset -> expected exact full-suite command, got: '${unset_cmd}'"
fi

# --- (3) SET to the two-spec subset -> exactly those two specs are positional. -
export ADOPTION_DEMO_E2E_SPECS="e2e/smoke.spec.js e2e/admin-console.spec.js"
set_cmd="$(resolve)"
want_set="npx playwright test --config=playwright.config.js e2e/smoke.spec.js e2e/admin-console.spec.js"
if [ "${set_cmd}" = "${want_set}" ]; then
  ok "set -> two-spec invocation: ${set_cmd}"
else
  bad "set -> expected '${want_set}', got: '${set_cmd}'"
fi
unset ADOPTION_DEMO_E2E_SPECS

echo "—"
echo "passed: ${pass}  failed: ${fail}"
[ "${fail}" -eq 0 ]
