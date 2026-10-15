#!/usr/bin/env bash
# Fixture harness for scripts/maintainer/collect_inbox.sh (INBOX-01).
#
# Pure bash + jq: fake `gh`, `mix` and `date` shims on PATH, no network, no Elixir,
# no real `gh` login. The fake gh records every non-GET method, field/input flag and
# mutating `gh pr|issue|run|label|repo|workflow|release` verb into a `mutations`
# file; every collector run is followed by an assertion that the file is empty.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
collector="${here}/../maintainer/collect_inbox.sh"

ROOT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/test_collect_inbox.XXXXXX")"
trap 'rm -rf "${ROOT_TMP}"' EXIT

pass=0
fail=0

record() {
  local name="$1" ok="$2" detail="${3-}"
  if [ "${ok}" = true ]; then
    echo "ok   - ${name}"
    pass=$((pass + 1))
  else
    echo "FAIL - ${name}: ${detail}" >&2
    fail=$((fail + 1))
  fi
}

# assert NAME COMMAND...: COMMAND must succeed (exit 0).
assert() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    record "${name}" true
  else
    record "${name}" false "assertion command failed: $*"
  fi
}

BIN="${ROOT_TMP}/bin"
mkdir -p "${BIN}"

# --- fake gh ----------------------------------------------------------------
cat >"${BIN}/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -u
log="${FAKE_DIR}/gh.log"
mut="${FAKE_DIR}/mutations"
printf '%s\n' "$*" >>"${log}"

# Mutation tripwire: any write method, field/input flag or mutating verb.
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

if [ "${1-}" = auth ]; then
  [ "${FAKE_GH_FAIL-}" != auth ] || exit 1
  exit 0
fi
if [ "${1-}" != api ]; then
  echo "unexpected gh call: $*" >>"${FAKE_DIR}/unexpected"
  exit 99
fi

paginate=false
slurp=false
head_flag=false
path=""
for a in "$@"; do
  case "${a}" in
    --paginate) paginate=true ;;
    --slurp) slurp=true ;;
    -i) head_flag=true ;;
  esac
  path="${a}"
done
[ "${FAKE_GH_FAIL-}" != api ] || exit 41
if [ "${paginate}" = true ] && [ "${FAKE_GH_FAIL-}" = page2 ]; then
  echo "gh: page 2 failed (HTTP 502)" >&2
  exit 1
fi

san="$(printf '%s' "${path}" | tr -c 'A-Za-z0-9' '_')"
file="${FAKE_DIR}/api/${san}.json"
if [ ! -f "${file}" ]; then
  echo "unexpected gh call: ${path}" >>"${FAKE_DIR}/unexpected"
  exit 99
fi
status=200
[ ! -f "${FAKE_DIR}/api/${san}.status" ] || status="$(cat "${FAKE_DIR}/api/${san}.status")"

if [ "${head_flag}" = true ]; then
  printf 'HTTP/2.0 %s Status\r\nContent-Type: application/json\r\n\r\n' "${status}"
  [ "${status}" = 204 ] || cat "${file}"
  [ "${status}" -lt 400 ] || exit 1
  exit 0
fi
if [ "${status}" -ge 400 ]; then
  cat "${file}"
  echo "gh: error (HTTP ${status})" >&2
  exit 1
fi
if [ "${slurp}" = true ]; then
  printf '[\n'
  cat "${file}"
  printf '\n]\n'
else
  cat "${file}"
fi
FAKE_GH
chmod +x "${BIN}/gh"

# --- fake date (FAKE_NOW_EPOCH) ---------------------------------------------
cat >"${BIN}/date" <<'FAKE_DATE'
#!/usr/bin/env bash
case "$*" in
  *"+%s"*) printf '%s\n' "${FAKE_NOW_EPOCH:-0}" ;;
  *) exec /bin/date "$@" ;;
esac
FAKE_DATE
chmod +x "${BIN}/date"

# --- fake mix (answers arrive with the advisory fixtures) --------------------
cat >"${BIN}/mix" <<'FAKE_MIX'
#!/usr/bin/env bash
echo "unexpected mix call: $*" >>"${FAKE_DIR}/unexpected"
exit 99
FAKE_MIX
chmod +x "${BIN}/mix"

# --- fixture helpers ---------------------------------------------------------

NOW=1792000000   # 2026-10-14T18:13:20Z
MAIN_SHA=0123456789abcdef0123456789abcdef01234567

# fx_new: fresh FAKE_DIR with the minimum fixtures every run needs.
fx_new() {
  FAKE_DIR="${ROOT_TMP}/case.$1"
  rm -rf "${FAKE_DIR}"
  mkdir -p "${FAKE_DIR}/api"
  export FAKE_DIR
  fx "repos/szTheory/rindle/commits/main" "{\"sha\":\"${MAIN_SHA}\"}"
  fx "repos/szTheory/rindle/issues?state=open&per_page=100" '[]'
  fx "repos/szTheory/rindle/pulls?state=open&per_page=100" '[]'
  fx "repos/szTheory/rindle/branches/main/protection" \
    '{"required_status_checks":{"strict":true,"contexts":["CI Summary"],"checks":[{"context":"CI Summary","app_id":15368}]},"enforce_admins":{"enabled":false}}'
  fx "repos/szTheory/rindle/actions/workflows/ci.yml/runs?branch=main&event=push&per_page=5" \
    '{"workflow_runs":[{"id":555,"head_sha":"'"${MAIN_SHA}"'","conclusion":"success"}]}'
  fx "repos/szTheory/rindle/actions/runs/555/jobs?per_page=100" '{"jobs":[{"name":"Quality","conclusion":"success"}]}'
}

# fx PATH BODY [STATUS]
fx() {
  local san
  san="$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')"
  printf '%s\n' "$2" >"${FAKE_DIR}/api/${san}.json"
  if [ -n "${3-}" ]; then printf '%s\n' "$3" >"${FAKE_DIR}/api/${san}.status"; fi
}

# run_collector OUTFILE [ARGS...]: sets RC, leaves stderr in ${FAKE_DIR}/stderr.
run_collector() {
  local out="$1"
  shift
  RC=0
  PATH="${BIN}:${PATH}" INBOX_NOW_EPOCH="${NOW}" INBOX_MERGEABLE_SLEEP=0 \
    bash "${collector}" --out "${out}" "$@" >"${FAKE_DIR}/stdout" 2>"${FAKE_DIR}/stderr" || RC=$?
}

no_mutations() {
  local name="$1"
  if [ ! -s "${FAKE_DIR}/mutations" ] && [ ! -s "${FAKE_DIR}/unexpected" ]; then
    record "${name}: no mutations or unexpected gh calls" true
  else
    record "${name}: no mutations or unexpected gh calls" false \
      "$(cat "${FAKE_DIR}/mutations" "${FAKE_DIR}/unexpected" 2>/dev/null | head -5)"
  fi
}

# --- Task 1: issues-only tracer ------------------------------------------------

fx_new issues
fx "repos/szTheory/rindle/issues?state=open&per_page=100" \
  '[{"number":42,"title":"async flake \"quoted\" $(touch pwned)","labels":[{"name":"flake"}],"updated_at":"2026-08-28T00:00:00Z"},
    {"number":120,"title":"a PR","labels":[],"updated_at":"2026-10-14T00:00:00Z","pull_request":{"url":"x"}},
    {"number":7,"title":"second issue","labels":[],"updated_at":"2026-09-01T00:00:00Z"}]'
out="${ROOT_TMP}/issues.json"
run_collector "${out}"
if [ "${RC}" -eq 0 ] && [ -f "${out}" ]; then
  record "issues-only inventory: exit 0 and file written" true
else
  record "issues-only inventory: exit 0 and file written" false "rc=${RC} $(head -3 "${FAKE_DIR}/stderr")"
fi
assert "issues-only inventory: schema, repo, 40-hex main_sha" \
  jq -e --arg sha "${MAIN_SHA}" '.schema=="rindle-inbox-inventory-v1" and .repo=="szTheory/rindle" and .main_sha==$sha' "${out}"
assert "issues-only inventory: collected_at from INBOX_NOW_EPOCH" \
  jq -e '.collected_at=="2026-10-14T17:46:40Z"' "${out}"
assert "issues-only inventory: exactly two issues, PR filtered, sorted" \
  jq -e '(.issues|map(.number))==[7,42] and (.issues[1].labels==["flake"]) and (.issues[1].title|contains("$(touch pwned)"))' "${out}"
assert "issues-only inventory: shell-metachar title was not executed" \
  test ! -e pwned
no_mutations "issues-only inventory"

fx_new auth
fx "repos/szTheory/rindle/issues?state=open&per_page=100" '[]'
out="${ROOT_TMP}/auth.json"
FAKE_GH_FAIL=auth run_collector "${out}"
if [ "${RC}" -ne 0 ] && [ ! -e "${out}" ]; then
  record "auth failure: non-zero exit and no output file" true
else
  record "auth failure: non-zero exit and no output file" false "rc=${RC} exists=$([ -e "${out}" ] && echo yes || echo no)"
fi
no_mutations "auth failure"

fx_new page2
fx "repos/szTheory/rindle/issues?state=open&per_page=100" '[]'
out="${ROOT_TMP}/page2.json"
FAKE_GH_FAIL=page2 run_collector "${out}"
if [ "${RC}" -ne 0 ] && [ ! -e "${out}" ]; then
  record "page2 failure: non-zero exit and no output file" true
else
  record "page2 failure: non-zero exit and no output file" false "rc=${RC} exists=$([ -e "${out}" ] && echo yes || echo no)"
fi
no_mutations "page2 failure"
leftovers="$(find "${ROOT_TMP}" -maxdepth 1 -name '.inbox-inventory.*' | wc -l | tr -d ' ')"
if [ "${leftovers}" = 0 ]; then
  record "failure leaves no temp inventory behind" true
else
  record "failure leaves no temp inventory behind" false "${leftovers} leftover temp files"
fi

# Usage errors exit 64.
fx_new usage
RC=0
PATH="${BIN}:${PATH}" bash "${collector}" --bogus >/dev/null 2>&1 || RC=$?
if [ "${RC}" -eq 64 ]; then
  record "unknown flag exits 64" true
else
  record "unknown flag exits 64" false "rc=${RC}"
fi

# --- Task 2: PRs, CI Summary selection, lock delta, terminal, protection, main CI ----

SHA_A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
SHA_B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
SHA_C=cccccccccccccccccccccccccccccccccccccccc

pr_fixture() { # number sha mergeable mergeable_state
  fx "repos/szTheory/rindle/pulls/$1" \
    "{\"number\":$1,\"title\":\"PR $1 \$(touch pwned2)\",\"user\":{\"login\":\"dependabot[bot]\"},\"base\":{\"ref\":\"main\"},\"head\":{\"sha\":\"$2\"},\"mergeable\":$3,\"mergeable_state\":\"$4\"}"
}

fx_new prs
fx "repos/szTheory/rindle/pulls?state=open&per_page=100" '[{"number":108},{"number":95},{"number":120}]'
pr_fixture 108 "${SHA_A}" true behind
pr_fixture 95 "${SHA_B}" null unknown
pr_fixture 120 "${SHA_C}" true blocked
LOCK_PATCH="$(printf '%s\n' \
  '@@ -1,5 +1,5 @@' \
  '-  "mint": {:hex, :mint, "1.9.3", "abc", [:mix], [], "hexpm", "def"},' \
  '+  "mint": {:hex, :mint, "1.10.0", "abc", [:mix], [], "hexpm", "def"},' \
  '-  "req": {:hex, :req, "0.7.3", "abc", [:mix], [], "hexpm", "def"},' \
  '+  "req": {:hex, :req, "0.7.4", "abc", [:mix], [], "hexpm", "def"},' \
  '   "unchanged": {:hex, :unchanged, "1.0.0", "abc", [:mix], [], "hexpm", "def"},' \
  '+garbage line that is not a lock row')"
files108="$(jq -c -n --arg patch "${LOCK_PATCH}" \
  '[{filename:"mix.lock",patch:$patch},{filename:"lib/rindle/foo.ex",patch:"x"},{filename:"mix.exs"},{filename:".github/workflows/ci.yml"},{filename:"brandbook/package-lock.json"},{filename:"README.md"}]')"
fx "repos/szTheory/rindle/pulls/108/files?per_page=100" "${files108}"
fx "repos/szTheory/rindle/pulls/95/files?per_page=100" '[{"filename":"mix.exs"}]'
fx "repos/szTheory/rindle/pulls/120/files?per_page=100" '[]'
# #108: failure completed earlier, success later (cancelled-run duplicate).
fx "repos/szTheory/rindle/commits/${SHA_A}/check-runs?check_name=CI%20Summary&per_page=100" \
  '{"check_runs":[
     {"id":1,"name":"CI Summary","app":{"slug":"github-actions"},"conclusion":"failure","completed_at":"2026-10-14T12:11:41Z"},
     {"id":2,"name":"CI Summary","app":{"slug":"github-actions"},"conclusion":"success","completed_at":"2026-10-14T12:19:50Z"},
     {"id":3,"name":"CI Summary","app":{"slug":"other-app"},"conclusion":"failure","completed_at":"2026-10-14T13:00:00Z"}]}'
fx "repos/szTheory/rindle/commits/${SHA_B}/check-runs?check_name=CI%20Summary&per_page=100" '{"check_runs":[]}'
fx "repos/szTheory/rindle/commits/${SHA_C}/check-runs?check_name=CI%20Summary&per_page=100" \
  '{"check_runs":[{"id":9,"name":"CI Summary","app":{"slug":"github-actions"},"conclusion":"success","completed_at":"2026-10-14T01:00:00Z"}]}'
fx "repos/szTheory/rindle/issues/93" '{"number":93,"state":"closed","state_reason":null,"pull_request":{"url":"x"}}'
fx "repos/szTheory/rindle/pulls/93" '{"number":93,"merged":false}'
fx "repos/szTheory/rindle/issues/88" '{"number":88,"state":"closed","state_reason":"completed"}'
fx "repos/szTheory/rindle/issues/77" '{"number":77,"state":"closed","state_reason":null,"pull_request":{"url":"x"}}'
fx "repos/szTheory/rindle/pulls/77" '{"number":77,"merged":true}'
fx "repos/szTheory/rindle/actions/runs/555/jobs?per_page=100" \
  '{"jobs":[{"name":"Quality","conclusion":"success"},{"name":"Adoption Demo E2E","conclusion":"failure"},{"name":"Cohort Demo Smoke","conclusion":"skipped"},{"name":"Package Consumer Full","conclusion":null}]}'
out="${ROOT_TMP}/prs.json"
run_collector "${out}" --include 93 --include 88 --include 77
if [ "${RC}" -eq 0 ] && [ -f "${out}" ]; then
  record "PR inventory: exit 0 and file written" true
else
  record "PR inventory: exit 0 and file written" false "rc=${RC} $(head -3 "${FAKE_DIR}/stderr")"
fi
assert "duplicate check-runs: latest completed_at wins (success, superseded_count 1, foreign app ignored)" \
  jq -e '.prs[]|select(.number==108)|.ci_summary|(.conclusion=="success" and .superseded_count==1 and .check_run_id==2)' "${out}"
assert "no check-runs: conclusion null with reason no_check_runs" \
  jq -e '.prs[]|select(.number==95)|.ci_summary==({conclusion:null,reason:"no_check_runs"})' "${out}"
assert "unknown mergeable: stays \"unknown\" after bounded retries, not coerced" \
  jq -e '.prs[]|select(.number==95)|(.mergeable=="unknown" and .behind==false)' "${out}"
if [ "$(grep -c 'pulls/95$' "${FAKE_DIR}/gh.log")" -eq 3 ]; then
  record "unknown mergeable: exactly 3 bounded reads" true
else
  record "unknown mergeable: exactly 3 bounded reads" false "$(grep -c 'pulls/95$' "${FAKE_DIR}/gh.log")"
fi
assert "mergeable_state behind sets behind true" \
  jq -e '.prs[]|select(.number==108)|(.behind==true and .mergeable==true and .mergeable_state=="behind")' "${out}"
assert "lock_delta parse: two packages with from/to, garbage ignored" \
  jq -e '.prs[]|select(.number==108)|.lock_delta==[{lock:"mix.lock",package:"mint",from:"1.9.3",to:"1.10.0"},{lock:"mix.lock",package:"req",from:"0.7.3",to:"0.7.4"}]' "${out}"
assert "manifest_files: mix.exs, mix.lock, workflows, package*.json only" \
  jq -e '.prs[]|select(.number==108)|.manifest_files==["mix.lock","mix.exs",".github/workflows/ci.yml","brandbook/package-lock.json"]' "${out}"
assert "PR fields: author, base, head_sha, title kept verbatim" \
  jq -e --arg sha "${SHA_A}" '.prs[]|select(.number==108)|(.author=="dependabot[bot]" and .base=="main" and .head_sha==$sha and (.title|contains("$(touch pwned2)")))' "${out}"
assert "prs sorted by number" jq -e '(.prs|map(.number))==[95,108,120]' "${out}"
assert "terminal include 93: closed, merged false, kind pr" \
  jq -e '.terminal[]|select(.number==93)|(.state=="closed" and .merged==false and .kind=="pr")' "${out}"
assert "terminal include 77: merged true" \
  jq -e '.terminal[]|select(.number==77)|(.merged==true and .state=="closed")' "${out}"
assert "terminal include 88: issue with state_reason completed" \
  jq -e '.terminal[]|select(.number==88)|(.kind=="issue" and .state_reason=="completed" and .merged==false)' "${out}"
assert "protection 200: source protection, strict true, enforce_admins false (booleans)" \
  jq -e '.branch_protection==({source:"protection",http:200,contexts:["CI Summary"],strict:true,enforce_admins:false})' "${out}"
assert "main_ci: latest push run with every non-passing job listed" \
  jq -e '.main_ci|(.run_id==555 and .conclusion=="success" and .failed_jobs==["Adoption Demo E2E","Package Consumer Full"])' "${out}"
no_mutations "PR inventory"
assert "PR title with shell metacharacters was not executed" test ! -e pwned2

# Protection 403 -> branches/main partial.
fx "repos/szTheory/rindle/branches/main/protection" '{"message":"Resource not accessible by integration"}' 403
fx "repos/szTheory/rindle/branches/main" '{"protected":true,"protection":{"required_status_checks":{"contexts":["CI Summary"],"enforcement_level":"non_admins"}}}'
out="${ROOT_TMP}/prot403.json"
run_collector "${out}"
assert "protection 403: branches-partial with strict/enforce_admins \"unreadable\" (never booleans)" \
  jq -e '.branch_protection==({source:"branches-partial",http:403,contexts:["CI Summary"],strict:"unreadable",enforce_admins:"unreadable"})' "${out}"
no_mutations "protection 403"

# Protection 404 + branches 403 -> unreadable.
fx "repos/szTheory/rindle/branches/main/protection" '{"message":"Not Found"}' 404
fx "repos/szTheory/rindle/branches/main" '{"message":"Forbidden"}' 403
out="${ROOT_TMP}/protunread.json"
run_collector "${out}"
assert "protection and branches both failing: source unreadable" \
  jq -e '.branch_protection|(.source=="unreadable" and .http==404 and .strict=="unreadable" and .enforce_admins=="unreadable")' "${out}"

# 5xx on a required endpoint aborts without output.
fx_new fivexx
fx "repos/szTheory/rindle/branches/main/protection" '{"message":"Bad Gateway"}' 502
out="${ROOT_TMP}/fivexx.json"
run_collector "${out}"
if [ "${RC}" -ne 0 ] && [ ! -e "${out}" ]; then
  record "5xx on protection: abort with no output file" true
else
  record "5xx on protection: abort with no output file" false "rc=${RC}"
fi
fx_new fivexx2
fx "repos/szTheory/rindle/actions/runs/555/jobs?per_page=100" '{"message":"Server Error"}' 500
out="${ROOT_TMP}/fivexx2.json"
run_collector "${out}"
if [ "${RC}" -ne 0 ] && [ ! -e "${out}" ]; then
  record "5xx on main CI jobs: abort with no output file" true
else
  record "5xx on main CI jobs: abort with no output file" false "rc=${RC}"
fi

# Malformed JSON aborts without output.
fx_new malformed
fx "repos/szTheory/rindle/issues?state=open&per_page=100" 'not json {'
out="${ROOT_TMP}/malformed.json"
run_collector "${out}"
if [ "${RC}" -ne 0 ] && [ ! -e "${out}" ]; then
  record "malformed issues response: abort with no output file" true
else
  record "malformed issues response: abort with no output file" false "rc=${RC}"
fi

# Tripwire self-test: the fake gh must flag writes, otherwise "no mutations" proves nothing.
fx_new tripwire
for probe in "api -X POST repos/x" "api --method=PUT repos/x" "api -f a=b repos/x" "pr merge 1" "issue close 2" "run rerun 3" "api -XDELETE repos/x"; do
  : >"${FAKE_DIR}/mutations"
  # shellcheck disable=SC2086 # word splitting of the probe is intended
  PATH="${BIN}:${PATH}" bash "${BIN}/gh" ${probe} >/dev/null 2>&1 || true
  if [ -s "${FAKE_DIR}/mutations" ]; then
    record "tripwire flags: ${probe}" true
  else
    record "tripwire flags: ${probe}" false "mutations file stayed empty"
  fi
done
: >"${FAKE_DIR}/mutations"
rm -f "${FAKE_DIR}/unexpected"
PATH="${BIN}:${PATH}" bash "${BIN}/gh" api -X GET repos/x >/dev/null 2>&1 || true
PATH="${BIN}:${PATH}" bash "${BIN}/gh" pr list >/dev/null 2>&1 || true
if [ ! -s "${FAKE_DIR}/mutations" ]; then
  record "tripwire allows GET and read-only verbs" true
else
  record "tripwire allows GET and read-only verbs" false "$(cat "${FAKE_DIR}/mutations")"
fi

# Without INBOX_NOW_EPOCH the collector reads the (fake) clock.
fx_new clock
fx "repos/szTheory/rindle/issues?state=open&per_page=100" '[]'
out="${ROOT_TMP}/clock.json"
RC=0
PATH="${BIN}:${PATH}" FAKE_NOW_EPOCH=1792000000 bash "${collector}" --out "${out}" >/dev/null 2>"${FAKE_DIR}/stderr" || RC=$?
if [ "${RC}" -eq 0 ] && jq -e '.collected_at=="2026-10-14T17:46:40Z"' "${out}" >/dev/null 2>&1; then
  record "clock falls back to date -u +%s" true
else
  record "clock falls back to date -u +%s" false "rc=${RC}"
fi

echo
echo "collect_inbox harness: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
