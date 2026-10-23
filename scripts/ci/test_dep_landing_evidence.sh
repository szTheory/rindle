#!/usr/bin/env bash
# Harness for scripts/maintainer/dep_landing_evidence.sh.
#
# Pure bash + git + jq: a throwaway git repo with crafted squash commits and a fake
# `gh` on PATH that answers run/job reads from fixture files. The fake gh records every
# write method, field/input flag and mutating verb into a `mutations` tripwire file.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${here}/../maintainer/dep_landing_evidence.sh"
TWIN='not-applicable: twin not built (Phase 137)'

pass=0
fail=0
record() {
  local name="$1" ok="$2" detail="${3-}"
  if [ "${ok}" = true ]; then
    echo "ok   — ${name}"
    pass=$((pass + 1))
  else
    echo "FAIL — ${name}: ${detail}" >&2
    fail=$((fail + 1))
  fi
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/dep-landing-test.XXXXXX")"
cleanup() { chmod -R u+w "${TMP}" 2>/dev/null || true; rm -rf "${TMP}"; }
trap cleanup EXIT

BIN="${TMP}/bin"
FAKE_DIR="${TMP}/fake"
REPO_DIR="${TMP}/repo"
mkdir -p "${BIN}" "${FAKE_DIR}/api" "${REPO_DIR}"
: >"${FAKE_DIR}/mutations"
export FAKE_DIR

# --- fake gh ----------------------------------------------------------------
cat >"${BIN}/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -u
mut="${FAKE_DIR}/mutations"
printf '%s\n' "$*" >>"${FAKE_DIR}/gh.log"
for a in "$@"; do
  case "${a}" in
    -f|-F|--field|--raw-field|--input|-f?*|-F?*|--field=*|--raw-field=*|--input=*)
      echo "field/input flag: ${a}" >>"${mut}" ;;
    -X?*) [ "${a#-X}" = GET ] || echo "non-GET method: ${a}" >>"${mut}" ;;
    --method=*) [ "${a#--method=}" = GET ] || echo "non-GET method: ${a}" >>"${mut}" ;;
  esac
done
prev=""
for a in "$@"; do
  case "${prev}" in
    -X|--method) [ "${a}" = GET ] || echo "non-GET method: ${a}" >>"${mut}" ;;
  esac
  prev="${a}"
done
case "${1-}" in
  pr|issue|run|label|repo|workflow|release)
    case "${2-}" in
      list|view|diff|checks|status) ;;
      *) echo "mutating verb: $1 ${2-}" >>"${mut}" ;;
    esac ;;
esac
if [ "${1-}" != api ]; then
  echo "unexpected gh call: $*" >>"${FAKE_DIR}/unexpected"
  exit 99
fi
slurp=false
path=""
for a in "$@"; do
  [ "${a}" != --slurp ] || slurp=true
  path="${a}"
done
san="$(printf '%s' "${path}" | tr -c 'A-Za-z0-9' '_')"
file="${FAKE_DIR}/api/${san}.json"
if [ ! -f "${file}" ]; then
  echo "unexpected gh call: ${path}" >>"${FAKE_DIR}/unexpected"
  exit 99
fi
if [ "${slurp}" = true ]; then
  printf '[\n'; cat "${file}"; printf '\n]\n'
else
  cat "${file}"
fi
FAKE_GH
chmod +x "${BIN}/gh"
export PATH="${BIN}:${PATH}"

san_of() { printf '%s' "$1" | tr -c 'A-Za-z0-9' '_'; }

# put_run SHA RUN_ID STATUS CONCLUSION  | put_run_none SHA
put_run() {
  local sha="$1" id="$2" status="$3" conclusion="$4"
  jq -n --arg sha "${sha}" --argjson id "${id}" --arg st "${status}" --arg co "${conclusion}" \
    '{workflow_runs:[{id:$id, head_sha:$sha, event:"push", head_branch:"main", path:".github/workflows/ci.yml", repository:{full_name:"szTheory/rindle"}, status:$st,
       conclusion:(if $co == "" then null else $co end)}]}' \
    >"${FAKE_DIR}/api/$(san_of "repos/szTheory/rindle/actions/workflows/ci.yml/runs?head_sha=${sha}&event=push&per_page=5").json"
}
put_run_none() {
  echo '{"workflow_runs":[]}' \
    >"${FAKE_DIR}/api/$(san_of "repos/szTheory/rindle/actions/workflows/ci.yml/runs?head_sha=$1&event=push&per_page=5").json"
}

ALL_JOBS='["Quality (1.17.3 / OTP 27.3.4.15)","ADMIN-06 Optional Dependencies (1.17.3)","Contract","Proof","Integration","CI Script Tests","Package Consumer Proof Matrix + Release Preflight","Adopter","Adoption Demo Unit","Adoption Demo E2E Smoke","Package Consumer Full Matrix + Release Preflight (stable)","Cohort Demo Smoke","Adoption Demo E2E","Mux Soak (real API)","CI Summary"]'

# put_jobs RUN_ID [drop_name] [fail_name]: every gate job success, optionally dropping or failing one.
put_jobs() {
  local id="$1" drop="${2-}" failname="${3-}"
  jq -n --argjson names "${ALL_JOBS}" --arg drop "${drop}" --arg failname "${failname}" '
    {jobs: [$names[] | select(. != $drop)
            | {name: ., conclusion: (if . == $failname then "failure" else "success" end)}]}' \
    >"${FAKE_DIR}/api/$(san_of "repos/szTheory/rindle/actions/runs/${id}/jobs?per_page=100").json"
}

# --- temp git repo ----------------------------------------------------------
LOCK_BASE='%{
  "ecto": {:hex, :ecto, "3.13.0", [:mix], [], "hexpm", "aaa"},
  "ecto_sql": {:hex, :ecto_sql, "3.13.0", [:mix], [], "hexpm", "bbb"},
  "mint": {:hex, :mint, "1.7.0", [:mix], [], "hexpm", "ccc"},
}'
cd "${REPO_DIR}"
git init -q .
git config user.name Test
git config user.email test@example.invalid
git config commit.gpgsign false
printf '%s\n' "${LOCK_BASE}" >mix.lock
echo 'defmodule M do end' >mix.exs
mkdir -p .github/workflows examples/adoption_demo
echo 'name: CI' >.github/workflows/ci.yml
git add -A && git commit -q -m base
BASE0="$(git rev-parse HEAD)"

commit_lock() {
  # commit_lock MESSAGE  (reads sed expression list from remaining args)
  local msg="$1"; shift
  sed "$@" mix.lock >mix.lock.new && mv mix.lock.new mix.lock
  git add -A && git commit -q -m "${msg}"
  git rev-parse HEAD
}

SHA_ECTO="$(commit_lock bump-ecto -e 's/:ecto, "3.13.0"/:ecto, "3.13.5"/' -e 's/:ecto_sql, "3.13.0"/:ecto_sql, "3.13.5"/')"

git checkout -q "${BASE0}" 2>/dev/null
git checkout -q -b mixexs
printf '%s\n' "${LOCK_BASE}" >mix.lock
echo 'defmodule M do end # changed' >mix.exs
sed -i.bak 's/:mint, "1.7.0"/:mint, "1.8.0"/' mix.lock; rm -f mix.lock.bak
git add -A && git commit -q -m 'bump-with-mix-exs'
SHA_MIXEXS="$(git rev-parse HEAD)"

git checkout -q "${BASE0}" 2>/dev/null
git checkout -q -b workflowonly
echo '# touched' >>.github/workflows/ci.yml
git add -A && git commit -q -m 'workflow-only'
SHA_WORKFLOW="$(git rev-parse HEAD)"

git checkout -q "${BASE0}" 2>/dev/null
git checkout -q -b lockandworkflow
echo '# touched' >>.github/workflows/ci.yml
sed -i.bak 's/:mint, "1.7.0"/:mint, "1.9.0"/' mix.lock; rm -f mix.lock.bak
git add -A && git commit -q -m 'workflow-plus-lock'
SHA_WFLOCK="$(git rev-parse HEAD)"

# a merge commit (two parents) must be rejected
git checkout -q "${BASE0}" 2>/dev/null
git checkout -q -b mergeside
echo x >side.txt && git add -A && git commit -q -m side
git checkout -q workflowonly
git merge -q --no-ff -m merge mergeside >/dev/null 2>&1
SHA_MERGE="$(git rev-parse HEAD)"

BASELINE="dddddddddddddddddddddddddddddddddddddddd"

run() {
  # run NAME ARGS... : sets RC and OUT_JSON
  RC=0
  : >"${FAKE_DIR}/mutations"
  OUT_JSON="$("${script}" "$@" 2>"${TMP}/stderr")" || RC=$?
}
assert_rc() {
  local name="$1" want="$2"
  if [ "${RC}" = "${want}" ]; then record "${name}: exit ${want}" true
  else record "${name}: exit ${want}" false "got ${RC}; stderr: $(head -3 "${TMP}/stderr")"; fi
}
assert_jq() {
  local name="$1" expr="$2"
  if printf '%s' "${OUT_JSON}" | jq -e "${expr}" >/dev/null 2>&1; then record "${name}" true
  else record "${name}" false "jq ${expr} on: $(printf '%s' "${OUT_JSON}" | head -c 400)"; fi
}
no_mutations() {
  if [ ! -s "${FAKE_DIR}/mutations" ] && [ ! -s "${FAKE_DIR}/unexpected" ]; then
    record "$1: no mutations or unexpected gh calls" true
  else
    record "$1: no mutations or unexpected gh calls" false \
      "$(cat "${FAKE_DIR}/mutations" "${FAKE_DIR}/unexpected" 2>/dev/null | head -5)"
  fi
}

# --- 1. clean ecto group lands ----------------------------------------------
put_run "${SHA_ECTO}" 1001 completed success
put_jobs 1001
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql
assert_rc "clean group" 0
assert_jq "clean group: verdict pass and attributable" '.verdict == "pass" and .attributable == true'
assert_jq "clean group: schema tag" '.schema == "rindle-dep-landing-v1"'
assert_jq "clean group: delta shows from/to per package" \
  '(.lock_delta | map(select(.package == "ecto")) | first) == {package:"ecto",from:"3.13.0",to:"3.13.5"}'
assert_jq "clean group: mix_exs_changed false" '.mix_exs_changed == false'
assert_jq "clean group: all gates pass" \
  '.gates.supported_toolchain == "pass" and .gates.public_contract == "pass" and .gates.package_consumer == "pass"'
assert_jq "clean group: twin is the not-applicable literal" ".gates.twin == \"${TWIN}\""
assert_jq "clean group: twin never reported as pass" '.gates.twin != "pass"'
assert_jq "clean group: main-only lanes are mapped to package_consumer" \
  '[.jobs[] | select(.gate == "package_consumer") | .name] | (index("Cohort Demo Smoke") != null and index("Adoption Demo E2E") != null and index("Package Consumer Full Matrix + Release Preflight (stable)") != null)'
assert_jq "clean group: unrelated job has no gate" \
  '(.jobs[] | select(.name == "Mux Soak (real API)") | .gate) == null'
assert_jq "clean group: run recorded" '.run.id == 1001 and .run.conclusion == "success"'
no_mutations "clean group"

# --- 2. attribution failures ------------------------------------------------
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto_sql
assert_rc "extra package in delta" 1
assert_jq "extra package: attributable false" '.attributable == false and .verdict == "attribution_failed"'
no_mutations "extra package"

put_run "${SHA_MIXEXS}" 1002 completed success
put_jobs 1002
run --sha "${SHA_MIXEXS}" --group mint --packages mint
assert_rc "mix.exs also edited" 1
assert_jq "mix.exs edit: flagged" '.mix_exs_changed == true and .attributable == false'

run --sha "${SHA_MERGE}" --group actions --packages ""
assert_rc "merge commit rejected" 1

# --- 3. workflow-only group with empty packages -----------------------------
put_run "${SHA_WORKFLOW}" 1003 completed success
put_jobs 1003
run --sha "${SHA_WORKFLOW}" --group actions --packages ""
assert_rc "actions group, workflow-only commit" 0
assert_jq "actions group: attributable with empty delta" '.attributable == true and (.lock_delta | length) == 0'

put_run "${SHA_WFLOCK}" 1004 completed success
put_jobs 1004
run --sha "${SHA_WFLOCK}" --group actions --packages ""
assert_rc "actions group, commit that changes mix.lock" 1
assert_jq "actions group lock change: attribution failed" '.attributable == false'

# --- 4. missing gate job ----------------------------------------------------
put_run "${SHA_ECTO}" 1005 completed success
put_jobs 1005 "Adoption Demo E2E"
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql
assert_rc "Adoption Demo E2E absent" 1
assert_jq "absent E2E: package_consumer missing" '.gates.package_consumer == "missing" and .verdict == "missing_gate"'

put_jobs 1005 "Quality (1.17.3 / OTP 27.3.4.15)"
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql
assert_rc "no Quality leg (prefix unmatched)" 1
assert_jq "no Quality leg: supported_toolchain missing" '.gates.supported_toolchain == "missing"'

put_jobs 1005 "Adoption Demo E2E Smoke"
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql
assert_rc "Smoke job does not stand in for exact E2E name" 1
assert_jq "missing Smoke: package_consumer missing" '.gates.package_consumer == "missing"'

# --- 5. regression vs inherited_red -----------------------------------------
put_run "${SHA_ECTO}" 1006 completed failure
put_jobs 1006 "" "Adoption Demo E2E"
put_run "${BASELINE}" 2006 completed success
put_jobs 2006
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql --baseline-sha "${BASELINE}"
assert_rc "red on landing, green on baseline" 1
assert_jq "regression: class and gate" \
  '(.jobs[] | select(.name == "Adoption Demo E2E") | .class) == "regression" and .gates.package_consumer == "fail" and .verdict == "regression"'
assert_jq "regression: baseline recorded" '.baseline_run.id == 2006'
no_mutations "regression"

put_jobs 2006 "" "Adoption Demo E2E"
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql --baseline-sha "${BASELINE}"
assert_rc "red on both runs" 3
assert_jq "inherited_red: class and gate" \
  '(.jobs[] | select(.name == "Adoption Demo E2E") | .class) == "inherited_red" and .gates.package_consumer == "inherited_red"'
assert_jq "inherited_red: baseline conclusion kept" \
  '(.jobs[] | select(.name == "Adoption Demo E2E") | .baseline_conclusion) == "failure"'

run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql
assert_rc "red with no baseline given is a regression" 1

put_jobs 1006 "" "Contract"
put_jobs 2006
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql --baseline-sha "${BASELINE}"
assert_rc "Contract red, baseline green" 1
assert_jq "Contract red: public_contract fail" '.gates.public_contract == "fail"'

# --- 6. in-progress and absent runs -----------------------------------------
put_run "${SHA_ECTO}" 1007 in_progress ""
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql
assert_rc "run in progress" 75
put_run_none "${SHA_ECTO}"
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql
assert_rc "no run for the SHA" 75
no_mutations "75 paths"

# --- 7. baseline mode (no --group) -------------------------------------------
put_run "${BASELINE}" 2007 completed success
put_jobs 2007
run --sha "${BASELINE}"
assert_rc "baseline mode: gates only" 0
assert_jq "baseline mode: attribution skipped" '.attributable == null and .group == null and (.lock_delta | length) == 0'
assert_jq "baseline mode: gates evaluated" '.gates.package_consumer == "pass" and .gates.twin == "'"${TWIN}"'"'

run --packages a --sha "${BASELINE}"
assert_rc "packages without group is a usage error" 64

# --- 8. usage and file output -----------------------------------------------
run
assert_rc "no arguments" 64
run --sha "${BASELINE}" --lock not-a-lock
assert_rc "disallowed lock path" 64
run --sha 'zz!'
assert_rc "non-hex sha" 64

put_run "${SHA_ECTO}" 1008 completed success
put_jobs 1008
RC=0
"${script}" --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql --out "${TMP}/out/evidence.json" >/dev/null 2>&1 || RC=$?
if [ "${RC}" = 0 ] && jq -e '.verdict == "pass"' "${TMP}/out/evidence.json" >/dev/null 2>&1; then
  record "--out writes the evidence file atomically" true
else
  record "--out writes the evidence file atomically" false "rc=${RC}"
fi
if [ "$(find "${TMP}/out" -type f | wc -l | tr -d ' ')" = 1 ]; then
  record "--out leaves no temp files" true
else
  record "--out leaves no temp files" false "$(ls -A "${TMP}/out")"
fi

# Replacement CI is allowed only across actual planning-only history.
git checkout -q --detach "${SHA_ECTO}"
mkdir -p .planning
echo bookkeeping >.planning/STATE.md
git add .planning && git commit -qm docs
SHA_DOCS="$(git rev-parse HEAD)"
put_run "${SHA_DOCS}" 3001 completed success
put_jobs 3001
run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql --evidence-sha "${SHA_DOCS}"
assert_rc "planning-only descendant accepted" 0
assert_jq "descendant preserves original merge and explicit equivalence" '.sha != .evidence_sha and .run.head_sha == .evidence_sha and .equivalence.policy == "planning-only-descendant-v1" and .equivalence.changed_files == [".planning/STATE.md"]'
no_mutations "descendant evidence"
run --sha "${SHA_DOCS}" --evidence-sha "${SHA_ECTO}"
assert_rc "reversed descendant range rejected" 1
run --sha "${SHA_ECTO}" --evidence-sha "${SHA_WORKFLOW}"
assert_rc "unrelated descendant range rejected" 1
for file in mix.lock mix.exs lib/rindle.ex .github/workflows/ci.yml .planning/tools/check.py .planning/config.json; do
  git checkout -q --detach "${SHA_DOCS}"
  mkdir -p "$(dirname "${file}")"
  echo change >>"${file}"
  git add -A && git commit -qm changed
  SHA_CHANGED="$(git rev-parse HEAD)"
  run --sha "${SHA_ECTO}" --evidence-sha "${SHA_CHANGED}"
  assert_rc "descendant changing ${file} rejected" 1
  git revert --no-edit "${SHA_CHANGED}" >/dev/null 2>&1
  run --sha "${SHA_ECTO}" --evidence-sha "$(git rev-parse HEAD)"
  assert_rc "reverted ${file} still rejected" 1
done
for field in 'head_sha="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"' 'event="workflow_dispatch"' 'head_branch="other"' 'repository.full_name="foreign/repo"' 'path=".github/workflows/other.yml"'; do
  put_run "${SHA_ECTO}" 1008 completed success
  file="${FAKE_DIR}/api/$(san_of "repos/szTheory/rindle/actions/workflows/ci.yml/runs?head_sha=${SHA_ECTO}&event=push&per_page=5").json"
  jq ".workflow_runs[0].${field}" "${file}" >"${TMP}/run.new" && mv "${TMP}/run.new" "${file}"
  run --sha "${SHA_ECTO}" --group ecto_sql --packages ecto,ecto_sql
  assert_rc "foreign CI identity rejected: ${field}" 1
done

# --- 9. tripwire self-test -----------------------------------------------------
for probe in "api -X POST x" "api --method=PUT x" "api -f a=b x" "api -XDELETE x" "pr merge 1" "run rerun 1"; do
  : >"${FAKE_DIR}/mutations"
  # shellcheck disable=SC2086
  gh ${probe} >/dev/null 2>&1 || true
  if [ -s "${FAKE_DIR}/mutations" ]; then record "tripwire flags: ${probe}" true
  else record "tripwire flags: ${probe}" false "mutations file stayed empty"; fi
done
: >"${FAKE_DIR}/mutations"
rm -f "${FAKE_DIR}/unexpected"

# --- 10. static guards ---------------------------------------------------------
if grep -nE -- '(-X|--method)[ =]*(POST|PUT|PATCH|DELETE)' "${script}" >/dev/null; then
  record "script has no write-method flag" false "found"
else
  record "script has no write-method flag" true
fi
if grep -n '\.planning/phases' "${script}" >/dev/null; then
  record "script reads no .planning/phases path" false "found"
else
  record "script reads no .planning/phases path" true
fi

echo
echo "dep_landing_evidence harness: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
