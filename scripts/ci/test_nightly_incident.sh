#!/usr/bin/env bash
# Regression matrix for the scheduled-only rolling Nightly incident lifecycle.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
evaluator="${here}/eval_nightly_incident.sh"
manager="${here}/manage_nightly_incident.sh"

pass=0
fail=0

record() {
  local name="$1" ok="$2" detail="$3"
  if [ "${ok}" = true ]; then
    echo "ok   — ${name}"
    pass=$((pass + 1))
  else
    echo "FAIL — ${name}: ${detail}" >&2
    fail=$((fail + 1))
  fi
}

incident_json() {
  local count="$1" evidence="${2:-}"
  case "${count}" in
    0) printf '[]' ;;
    1)
      jq -cn --arg evidence "${evidence}" \
        '[{number:88,title:"Nightly CI failure",body:$evidence,comments:[]}]'
      ;;
    2)
      printf '[{"number":88,"title":"Nightly CI failure","body":"","comments":[]},{"number":89,"title":"Nightly CI failure","body":"","comments":[]}]'
      ;;
  esac
}

eval_case() {
  local name="$1" want_exit="$2" want_action="$3" event="$4" verdict="$5"
  local open_count="$6" run_sha="${7:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
  local run_ref="${8:-refs/heads/main}" remote_sha="${9:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
  local evidence="${10:-}" output="" got=0

  output="$(
    EVENT_NAME="${event}" NIGHTLY_VERDICT="${verdict}" RUN_ID=123 RUN_ATTEMPT=2 \
      RUN_URL=https://github.com/szTheory/rindle/actions/runs/123 \
      RUN_SHA="${run_sha}" RUN_REF="${run_ref}" DEFAULT_BRANCH=main \
      REMOTE_MAIN_SHA="${remote_sha}" OPEN_INCIDENTS_JSON="$(incident_json "${open_count}" "${evidence}")" \
      bash "${evaluator}" 2>/dev/null
  )" || got=$?

  if [ "${got}" -eq "${want_exit}" ] && { [ "${want_exit}" -ne 0 ] || [ "${output}" = "${want_action}" ]; }; then
    record "${name}" true ""
  else
    record "${name}" false "expected exit/action ${want_exit}/${want_action}, got ${got}/${output:-<empty>}"
  fi
}

# Policy truth table: all four actions plus every non-mutation/fail-closed boundary.
eval_case "scheduled red with no incident opens" 0 open schedule red 0
eval_case "scheduled red with one incident updates" 0 update schedule red 1
eval_case "scheduled green with one incident closes" 0 close schedule green 1
eval_case "scheduled green with no incident is a no-op" 0 noop schedule green 0
eval_case "diagnostic dispatch is a no-op" 0 noop workflow_dispatch red 0
eval_case "stale SHA is a no-op" 0 noop schedule red 0 \
  bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb refs/heads/main \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
eval_case "non-default ref is a no-op" 0 noop schedule red 0 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/topic \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
eval_case "repeated run evidence is a no-op" 0 noop schedule red 1 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/main \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "nightly-run:123:2"
eval_case "duplicate open incidents fail closed" 1 error schedule red 2
eval_case "invalid verdict fails closed" 1 error schedule incomplete 0
eval_case "malformed inventory fails closed" 1 error schedule red malformed
eval_case "missing remote-main fact fails closed" 1 error schedule red 0 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/main ""

make_fake_gh() {
  local bin_dir="$1"
  mkdir -p "${bin_dir}"
  apply_fake="${bin_dir}/gh"
  # shellcheck disable=SC2016 # These literals become the fake executable's source.
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "%s\n" "$*" >> "${FAKE_GH_LOG}"' \
    'if [ "${1-} ${2-}" = "issue list" ]; then' \
    '  [ "${FAKE_GH_FAIL-}" != list ] || exit 41' \
    '  printf "%s\n" "${FAKE_GH_OPEN_JSON-[]}"' \
    '  exit 0' \
    'fi' \
    'if [ "${FAKE_GH_FAIL-}" = "${2-}" ]; then exit 42; fi' \
    'case "${1-} ${2-}" in' \
    '  "issue create") printf "%s\n" "https://github.test/issues/99" ;;' \
    '  "issue comment") printf "%s\n" "commented" ;;' \
    '  "issue close") printf "%s\n" "closed" ;;' \
    '  *) exit 43 ;;' \
    'esac' >"${apply_fake}"
  chmod +x "${apply_fake}"
}

manager_case() {
  local name="$1" want_exit="$2" open_count="$3" fail_op="$4" want_mutations="$5"
  local verdict="${6:-red}" evidence="${7:-}" temp output got=0 mutations
  temp="$(mktemp -d)"
  make_fake_gh "${temp}/bin"
  : >"${temp}/calls"

  output="$(
    PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" \
      FAKE_GH_FAIL="${fail_op}" FAKE_GH_OPEN_JSON="$(incident_json "${open_count}" "${evidence}")" \
      GH_TOKEN=test-token GH_REPO=szTheory/rindle EVENT_NAME=schedule \
      NIGHTLY_VERDICT="${verdict}" RUN_ID=123 RUN_ATTEMPT=2 \
      RUN_URL=https://github.com/szTheory/rindle/actions/runs/123 \
      RUN_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa RUN_REF=refs/heads/main \
      DEFAULT_BRANCH=main REMOTE_MAIN_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      bash "${manager}" 2>&1
  )" || got=$?

  mutations="$(awk '$1 == "issue" && $2 != "list" {count++} END {print count+0}' "${temp}/calls")"
  if [ "${got}" -eq "${want_exit}" ] && [ "${mutations}" -eq "${want_mutations}" ]; then
    record "${name}" true ""
  else
    record "${name}" false "expected exit/mutations ${want_exit}/${want_mutations}, got ${got}/${mutations}; ${output}"
  fi
  rm -rf "${temp}"
}

manager_case "open mutation succeeds" 0 0 "" 1 red
manager_case "update mutation succeeds" 0 1 "" 1 red
manager_case "close mutation succeeds atomically" 0 1 "" 1 green
manager_case "lookup failure performs no mutation" 41 0 list 0 red
manager_case "create failure propagates" 42 0 create 1 red
manager_case "comment failure propagates" 42 1 comment 1 red
manager_case "close failure propagates" 42 1 close 1 green
manager_case "duplicate incidents perform no mutation" 1 2 "" 0 red
manager_case "repeated run performs no mutation" 0 1 "" 0 red "nightly-run:123:2"

# Close must be a single supported command carrying recovery evidence, never comment then close.
temp="$(mktemp -d)"
make_fake_gh "${temp}/bin"
: >"${temp}/calls"
PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_OPEN_JSON="$(incident_json 1)" \
  GH_TOKEN=test-token GH_REPO=szTheory/rindle EVENT_NAME=schedule NIGHTLY_VERDICT=green \
  RUN_ID=123 RUN_ATTEMPT=2 RUN_URL=https://github.com/szTheory/rindle/actions/runs/123 \
  RUN_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa RUN_REF=refs/heads/main DEFAULT_BRANCH=main \
  REMOTE_MAIN_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bash "${manager}" >/dev/null 2>&1 || true
if [ "$(grep -c '^issue close 88 --comment ' "${temp}/calls" || true)" -eq 1 ] && \
   [ "$(grep -c '^issue comment ' "${temp}/calls" || true)" -eq 0 ]; then
  record "recovery evidence is supplied by the atomic close command" true ""
else
  record "recovery evidence is supplied by the atomic close command" false "unexpected close ordering"
fi
rm -rf "${temp}"

echo "—"
echo "passed: ${pass}  failed: ${fail}"
[ "${pass}" -gt 0 ]
[ "${fail}" -eq 0 ]
