#!/usr/bin/env bash
# Fixture harness for scripts/maintainer/collect_inbox.sh.
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

# --- fake mix -----------------------------------------------------------------
cat >"${BIN}/mix" <<'FAKE_MIX'
#!/usr/bin/env bash
set -u
d="${FAKE_DIR}"
scope=root
case "${PWD}" in */examples/adoption_demo) scope=demo ;; esac
printf '%s scope=%s deps=[%s] build=[%s] ignores=[%s]\n' "$*" "${scope}" \
  "${MIX_DEPS_PATH-UNSET}" "${MIX_BUILD_PATH-UNSET}" "${HEX_IGNORE_ADVISORIES-UNSET}" >>"${d}/mix.log"
canned() { # NAME DEFAULT_TEXT: print the canned text and exit with its recorded rc
  if [ -f "${d}/mix/$1.txt" ]; then cat "${d}/mix/$1.txt"; exit "$(cat "${d}/mix/$1.rc")"; fi
  printf '%s\n' "$2"; exit 0
}
case "${1-}" in
  hex.audit)
    if [ "${FAKE_MIX_FAIL-}" = garbage ]; then echo "** (Mix) boom" >&2; exit 1; fi
    if [ "${FAKE_MIX_FAIL-}" = touchlock ]; then echo "# tampered" >>"${INBOX_ROOT_DIR}/examples/adoption_demo/mix.lock"; fi
    canned "hex_audit_${scope}" "No vulnerable packages found" ;;
  deps.audit) canned deps_audit "No vulnerabilities found." ;;
  deps.get)
    if [ "${FAKE_MIX_FAIL-}" = demo_get ]; then echo "** (Mix) Failed to fetch dependencies" >&2; exit 1; fi
    exit 0 ;;
  hex.info)
    f="${d}/mix/hex_info_${2-}.txt"
    if [ -f "${f}" ]; then cat "${f}"; exit 0; fi
    echo "** (Mix) No package with name ${2-}" >&2; exit 1 ;;
  *) echo "unexpected mix call: $*" >>"${d}/unexpected"; exit 99 ;;
esac
FAKE_MIX
chmod +x "${BIN}/mix"

# Fixture project tree (the collector fingerprints these two locks).
PROJ="${ROOT_TMP}/proj"
mkdir -p "${PROJ}/examples/adoption_demo"
printf '%%{"a": {:hex, :a, "1.0.0"}}\n' >"${PROJ}/mix.lock"
printf '%%{"b": {:hex, :b, "1.0.0"}}\n' >"${PROJ}/examples/adoption_demo/mix.lock"
export INBOX_ROOT_DIR="${PROJ}"

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
  fx "repos/szTheory/rindle/actions/runs/555/jobs?per_page=100" '{"jobs":[{"name":"Quality","status":"completed","conclusion":"success"}]}'
  fx "repos/szTheory/rindle/dependabot/alerts?state=open&per_page=100" \
    '{"message":"Dependabot alerts are disabled for this repository.","status":"403"}' 403
  fx "repos/szTheory/rindle/vulnerability-alerts" '{"message":"Not Found"}' 404
  mkdir -p "${FAKE_DIR}/mix"
  cp "${PROJ}/mix.lock" "${PROJ}/mix.lock.orig"
  cp "${PROJ}/examples/adoption_demo/mix.lock" "${PROJ}/examples/adoption_demo/mix.lock.orig"
  cp "${PROJ}/mix.lock.orig" "${PROJ}/mix.lock"
  cp "${PROJ}/examples/adoption_demo/mix.lock.orig" "${PROJ}/examples/adoption_demo/mix.lock"
}

# mixfx NAME RC TEXT: canned mix output (hex_audit_root, hex_audit_demo, deps_audit, hex_info_PKG)
mixfx() {
  printf '%s\n' "$3" >"${FAKE_DIR}/mix/$1.txt"
  printf '%s\n' "$2" >"${FAKE_DIR}/mix/$1.rc"
}

# fx PATH BODY [STATUS]
fx() {
  local san
  san="$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')"
  printf '%s\n' "$2" >"${FAKE_DIR}/api/${san}.json"
  rm -f "${FAKE_DIR}/api/${san}.status"
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
fx "repos/szTheory/rindle/pulls/77" '{"number":77,"merged":true,"merge_commit_sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}'
fx "repos/szTheory/rindle/pulls/77/files?per_page=100" '[{"filename":"mix.lock"}]'
fx "repos/szTheory/rindle/actions/runs/555/jobs?per_page=100" \
  '{"jobs":[{"name":"Quality","status":"completed","conclusion":"success"},{"name":"Adoption Demo E2E","status":"completed","conclusion":"failure"},{"name":"Cohort Demo Smoke","status":"completed","conclusion":"skipped"},{"name":"Package Consumer Full","status":"in_progress","conclusion":null}]}'
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
  jq -e '.terminal[]|select(.number==77)|(.merged==true and .state=="closed" and .merge_sha=="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" and .changed_files==["mix.lock"] and .landing_evidence==[])' "${out}"
assert "terminal include 88: issue with state_reason completed" \
  jq -e '.terminal[]|select(.number==88)|(.kind=="issue" and .state_reason=="completed" and .merged==false)' "${out}"
assert "protection 200: source protection, strict true, enforce_admins false (booleans)" \
  jq -e '.branch_protection==({source:"protection",http:200,contexts:["CI Summary"],strict:true,enforce_admins:false})' "${out}"
assert "main_ci: latest push run with completed failures exclude unfinished jobs" \
  jq -e '.main_ci|(.run_id==555 and .conclusion=="success" and .failed_jobs==["Adoption Demo E2E"] and .unfinished_jobs==["Package Consumer Full"])' "${out}"
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

# --- Task 3: advisory sources --------------------------------------------------

ADV_FINDINGS="$(printf '%s\n' \
  'Advisories:' \
  '  cowlib 2.19.0 - EEF-CVE-2026-43971 (MEDIUM)' \
  '    aka: CVE-2026-43971' \
  '    Link Header Directive Smuggling' \
  '    https://osv.dev/vulnerability/EEF-CVE-2026-43971' \
  '' \
  '  mint 1.9.3 - EEF-CVE-2026-91043 (HIGH)' \
  '    aka: CVE-2026-91043' \
  '    https://osv.dev/vulnerability/EEF-CVE-2026-91043' \
  '' \
  '  decimal 3.1.1 - EEF-CVE-2026-97853 (MEDIUM)' \
  '    https://osv.dev/vulnerability/EEF-CVE-2026-97853')"

fx_new adv_findings
mixfx hex_audit_root 1 "${ADV_FINDINGS}"
out="${ROOT_TMP}/adv_findings.json"
run_collector "${out}"
if [ "${RC}" -eq 0 ]; then
  record "hex.audit findings: collector exits 0" true
else
  record "hex.audit findings: collector exits 0" false "rc=${RC} $(head -3 "${FAKE_DIR}/stderr")"
fi
assert "hex.audit findings: hex_audit_root status findings" \
  jq -e '.advisories.sources.hex_audit_root.status=="findings"' "${out}"
assert "hex.audit findings: three root findings, ignored false, source hex_audit" \
  jq -e '(.advisories.findings|length)==3 and (.advisories.findings|all(.scope=="root" and .ignored==false and .source=="hex_audit")) and (.advisories.findings|map(.id)==["EEF-CVE-2026-43971","EEF-CVE-2026-91043","EEF-CVE-2026-97853"]) and (.advisories.findings[1]=={id:"EEF-CVE-2026-91043",package:"mint",version:"1.9.3",severity:"HIGH",scope:"root",source:"hex_audit",ignored:false})' "${out}"
assert "hex.audit runs with ignores emptied (root)" grep -q 'hex.audit scope=root .*ignores=\[\]' "${FAKE_DIR}/mix.log"
assert "demo audit uses scratch MIX_DEPS_PATH/MIX_BUILD_PATH, never the caller's" \
  grep -qE 'hex.audit scope=demo deps=\[[^]U][^]]*\] build=\[[^]U][^]]*\] ignores=\[\]' "${FAKE_DIR}/mix.log"
assert "demo audit clean when fake demo audit is clean" \
  jq -e '.advisories.sources.hex_audit_demo.status=="clean"' "${out}"
assert "deps_audit second opinion recorded" \
  jq -e '.advisories.sources.deps_audit.status=="clean" and (.advisories.sources.deps_audit.output_tail|contains("No vulnerabilities"))' "${out}"
assert "actions recorded not-applicable" \
  jq -e '.advisories.sources.actions=={status:"not-applicable",reason:"SHA-pinned actions produce no alerts"}' "${out}"
no_mutations "hex.audit findings"

fx_new adv_clean
out="${ROOT_TMP}/adv_clean.json"
run_collector "${out}"
assert "hex.audit clean: status clean and no findings" \
  jq -e '.advisories.sources.hex_audit_root.status=="clean" and .advisories.findings==[]' "${out}"

fx_new adv_garbage
out="${ROOT_TMP}/adv_garbage.json"
FAKE_MIX_FAIL=garbage run_collector "${out}"
if [ "${RC}" -ne 0 ] && [ ! -e "${out}" ]; then
  record "hex.audit exit 1 with no section marker: abort, no output file" true
else
  record "hex.audit exit 1 with no section marker: abort, no output file" false "rc=${RC}"
fi

fx_new adv_ignored
mixfx hex_audit_root 0 "$(printf '%s\n' 'Ignored advisories:' '  bandit 1.12.5 - EEF-CVE-2026-105659 (HIGH)' '    https://osv.dev/vulnerability/EEF-CVE-2026-105659')"
out="${ROOT_TMP}/adv_ignored.json"
run_collector "${out}"
assert "Ignored advisories section: findings tagged ignored true (exit 0 still findings)" \
  jq -e '.advisories.sources.hex_audit_root.status=="findings" and (.advisories.findings|length)==1 and .advisories.findings[0].ignored==true and .advisories.findings[0].package=="bandit"' "${out}"

fx_new adv_demo
mixfx hex_audit_demo 1 "$(printf '%s\n' 'Advisories:' '  bandit 1.12.5 - EEF-CVE-2026-105659 (HIGH)')"
out="${ROOT_TMP}/adv_demo.json"
run_collector "${out}"
assert "demo findings carry scope examples/adoption_demo" \
  jq -e '.advisories.sources.hex_audit_demo.status=="findings" and .advisories.sources.hex_audit_root.status=="clean" and (.advisories.findings|map(.scope)==["examples/adoption_demo"])' "${out}"

fx_new adv_demo_get
out="${ROOT_TMP}/adv_demo_get.json"
FAKE_MIX_FAIL=demo_get run_collector "${out}"
assert "demo deps.get failure records unreadable with reason (never clean)" \
  jq -e '.advisories.sources.hex_audit_demo.status=="unreadable" and (.advisories.sources.hex_audit_demo.reason|startswith("deps.get failed"))' "${out}"

fx_new adv_skip
out="${ROOT_TMP}/adv_skip.json"
run_collector "${out}" --skip-demo-audit
assert "--skip-demo-audit records unreadable with reason skipped" \
  jq -e '.advisories.sources.hex_audit_demo=={status:"unreadable",reason:"skipped"}' "${out}"
if ! grep -q 'scope=demo' "${FAKE_DIR}/mix.log"; then
  record "--skip-demo-audit never touches the demo project" true
else
  record "--skip-demo-audit never touches the demo project" false "$(grep 'scope=demo' "${FAKE_DIR}/mix.log" | head -2)"
fi

fx_new adv_lockchange
out="${ROOT_TMP}/adv_lockchange.json"
FAKE_MIX_FAIL=touchlock run_collector "${out}"
if [ "${RC}" -ne 0 ] && [ ! -e "${out}" ]; then
  record "a lock file changing during collection aborts with no output file" true
else
  record "a lock file changing during collection aborts with no output file" false "rc=${RC}"
fi

fx_new adv_depsaudit
mixfx deps_audit 1 "$(printf '%s\n' 'Name: plug' 'Title: error: secret disclosure in malformed calls' '1 vulnerabilities found')"
out="${ROOT_TMP}/adv_depsaudit.json"
run_collector "${out}"
assert "deps.audit findings recorded as second opinion" \
  jq -e '.advisories.sources.deps_audit.status=="findings"' "${out}"

fx_new adv_depsaudit_refresh_error
mixfx deps_audit 0 "$(printf '\033[31merror: cannot open .git/FETCH_HEAD: Operation not permitted\033[0m\nNo vulnerabilities found.\n')"
out="${ROOT_TMP}/adv_depsaudit_refresh_error.json"
run_collector "${out}"
assert "deps.audit successful exit cannot hide a Git refresh error" \
  jq -e '.advisories.sources.deps_audit.status=="unreadable"' "${out}"
no_mutations "deps.audit refresh error"

fx_new adv_depsaudit_early_error
mixfx deps_audit 0 "$(printf 'fatal: unable to access advisory database\n'; for i in $(seq 1 25); do printf 'audit output %s\n' "${i}"; done; printf 'No vulnerabilities found.\n')"
out="${ROOT_TMP}/adv_depsaudit_early_error.json"
run_collector "${out}"
assert "deps.audit error detection reads complete output before the diagnostic tail" \
  jq -e '.advisories.sources.deps_audit.status=="unreadable" and (.advisories.sources.deps_audit.output_tail|contains("fatal:")|not)' "${out}"
no_mutations "deps.audit early error"

fx_new adv_depsaudit_error_and_findings
mixfx deps_audit 1 "$(printf '%s\n' 'fatal: unable to fetch advisory database' '1 vulnerabilities found')"
out="${ROOT_TMP}/adv_depsaudit_error_and_findings.json"
run_collector "${out}"
assert "deps.audit refresh failure stays unreadable alongside cached findings" \
  jq -e '.advisories.sources.deps_audit.status=="unreadable"' "${out}"
no_mutations "deps.audit error with findings"

# GitHub-side sources.
fx_new gh_disabled
out="${ROOT_TMP}/gh_disabled.json"
run_collector "${out}"
assert "alerts 403 'disabled for this repository' -> source_disabled; vulnerability-alerts 404 -> source_disabled; no zero count" \
  jq -e '.advisories.sources.dependabot_alerts=={status:"source_disabled",http:403} and .advisories.sources.vulnerability_alerts=={status:"source_disabled",http:404} and (.advisories.findings|map(select(.source=="dependabot"))==[])' "${out}"

fx_new gh_scope
fx "repos/szTheory/rindle/dependabot/alerts?state=open&per_page=100" \
  '{"message":"Resource not accessible by personal access token; requires the security_events scope"}' 403
fx "repos/szTheory/rindle/vulnerability-alerts" '{"message":"forbidden"}' 403
out="${ROOT_TMP}/gh_scope.json"
run_collector "${out}"
assert "alerts 403 missing scope -> unreadable (never source_disabled); vulnerability-alerts 403 -> unreadable" \
  jq -e '.advisories.sources.dependabot_alerts.status=="unreadable" and .advisories.sources.dependabot_alerts.http==403 and (.advisories.sources.dependabot_alerts.message|contains("scope")) and .advisories.sources.vulnerability_alerts.status=="unreadable"' "${out}"

fx_new gh_404
fx "repos/szTheory/rindle/dependabot/alerts?state=open&per_page=100" '{"message":"Not Found"}' 404
out="${ROOT_TMP}/gh_404.json"
run_collector "${out}"
assert "alerts 404 -> unreadable with http and message" \
  jq -e '.advisories.sources.dependabot_alerts=={status:"unreadable",http:404,message:"Not Found"}' "${out}"

fx_new gh_enabled
fx "repos/szTheory/rindle/vulnerability-alerts" '' 204
fx "repos/szTheory/rindle/dependabot/alerts?state=open&per_page=100" \
  '[{"security_advisory":{"ghsa_id":"GHSA-aaaa-bbbb-cccc","severity":"high"},"dependency":{"package":{"name":"plug"},"manifest_path":"mix.lock"},"security_vulnerability":{"vulnerable_version_range":"< 1.2.3"}},
    {"security_advisory":{"ghsa_id":"GHSA-dddd-eeee-ffff","severity":"low"},"dependency":{"package":{"name":"bandit"},"manifest_path":"examples/adoption_demo/mix.lock"},"security_vulnerability":{"vulnerable_version_range":"< 2"}}]'
out="${ROOT_TMP}/gh_enabled.json"
run_collector "${out}"
assert "vulnerability-alerts 204 and alerts 200 -> enabled, open alerts become dependabot findings" \
  jq -e '.advisories.sources.vulnerability_alerts=={status:"enabled",http:204} and .advisories.sources.dependabot_alerts=={status:"enabled",http:200} and (.advisories.findings|map(select(.source=="dependabot"))|map([.id,.package,.scope])==[["GHSA-aaaa-bbbb-cccc","plug","root"],["GHSA-dddd-eeee-ffff","bandit","examples/adoption_demo"]])' "${out}"
no_mutations "GitHub-side advisory sources"

fx_new gh_5xx
fx "repos/szTheory/rindle/dependabot/alerts?state=open&per_page=100" '{"message":"oops"}' 503
out="${ROOT_TMP}/gh_5xx.json"
run_collector "${out}"
if [ "${RC}" -ne 0 ] && [ ! -e "${out}" ]; then
  record "5xx on dependabot alerts: abort with no output file" true
else
  record "5xx on dependabot alerts: abort with no output file" false "rc=${RC}"
fi

# hex_latest.
fx_new hexlatest
mixfx hex_info_bandit 0 "$(printf '%s\n' 'A pure-Elixir HTTP server' '' 'Config: {:bandit, "~> 1.12"}' '' 'Recent releases:' '  1.12.5 (2026-08-20)' '  1.12.4 (2026-07-27)')"
mixfx hex_info_req 0 "$(printf '%s\n' 'Config: {:req, "~> 0.7"}' '' 'Recent releases:' '  0.7.5 (2026-10-06)' '  0.7.4 (2026-09-01)')"
out="${ROOT_TMP}/hexlatest.json"
run_collector "${out}" --hex-package bandit --hex-package req
assert "--hex-package records the first released version per package" \
  jq -e '.hex_latest=={bandit:"1.12.5",req:"0.7.5"}' "${out}"
run_collector "${ROOT_TMP}/hexlatest-none.json" --hex-package no_such_pkg
if [ "${RC}" -ne 0 ] && [ ! -e "${ROOT_TMP}/hexlatest-none.json" ]; then
  record "unknown --hex-package aborts with no output file" true
else
  record "unknown --hex-package aborts with no output file" false "rc=${RC}"
fi

# Paginated jobs, unfinished state and adverse terminal conclusions.
fx_new job_states
fx "repos/szTheory/rindle/actions/runs/555/jobs?per_page=100" \
  '{"jobs":[{"name":"Queued","status":"queued","conclusion":null},{"name":"Running","status":"in_progress","conclusion":null},{"name":"Okay","status":"completed","conclusion":"success"}]},
   {"jobs":[{"name":"Failed","status":"completed","conclusion":"failure"},{"name":"Cancelled","status":"completed","conclusion":"cancelled"},{"name":"Timed out","status":"completed","conclusion":"timed_out"},{"name":"Action required","status":"completed","conclusion":"action_required"},{"name":"Malformed terminal","status":"completed","conclusion":null},{"name":"Skipped","status":"completed","conclusion":"skipped"}]}'
out="${ROOT_TMP}/job-states.json"
run_collector "${out}"
assert "all job pages: unfinished jobs separated from terminal failures" jq -e \
  '.main_ci.failed_jobs==["Failed","Cancelled","Timed out","Action required","Malformed terminal"] and .main_ci.unfinished_jobs==["Queued","Running"]' "${out}"
no_mutations "paginated job states"

# Full collector -> real landing helper integration with an actual local merge.
LANDING_ROOT="${ROOT_TMP}/landing-root"
mkdir -p "${LANDING_ROOT}"
(
  cd "${LANDING_ROOT}"
  git init -q .
  git config user.name Test
  git config user.email test@example.invalid
  git config commit.gpgsign false
  echo 'defmodule M do end' >mix.exs
  printf '%%{\n  "req": {:hex, :req, "0.7.3", [], [], "hexpm", "a"},\n}\n' >mix.lock
  git add -A && git commit -qm base
  sed 's/0.7.3/0.7.5/' mix.lock >lock.new && mv lock.new mix.lock
  git add -A && git commit -qm bump
)
LANDING_SHA="$(git -C "${LANDING_ROOT}" rev-parse HEAD)"
fx_new landing
fx "repos/szTheory/rindle/issues/77" '{"number":77,"state":"closed","pull_request":{}}'
fx "repos/szTheory/rindle/pulls/77" "{\"number\":77,\"merged\":true,\"merge_commit_sha\":\"${LANDING_SHA}\"}"
fx "repos/szTheory/rindle/pulls/77/files?per_page=100" '[{"filename":"mix.lock"}]'
fx "repos/szTheory/rindle/actions/workflows/ci.yml/runs?head_sha=${LANDING_SHA}&event=push&per_page=5" \
  "{\"workflow_runs\":[{\"id\":777,\"head_sha\":\"${LANDING_SHA}\",\"event\":\"push\",\"head_branch\":\"main\",\"repository\":{\"full_name\":\"szTheory/rindle\"},\"path\":\".github/workflows/ci.yml\",\"status\":\"completed\",\"conclusion\":\"success\"}]}"
JOBS='["Quality (stable)","ADMIN-06 Optional Dependencies (stable)","Contract","Proof","Integration","CI Script Tests","Package Consumer Proof Matrix + Release Preflight","Adopter","Adoption Demo Unit","Adoption Demo E2E Smoke","Cohort Demo Smoke","Adoption Demo E2E","Package Consumer Full Matrix + Release Preflight (stable)"]'
fx "repos/szTheory/rindle/actions/runs/777/jobs?per_page=100" "$(jq -n --argjson names "$JOBS" '{jobs:[$names[]|{name:.,conclusion:"success"}]}')"
jq -n --arg sha "${LANDING_SHA}" '{repo:"szTheory/rindle",landings:[{number:77,merge_sha:$sha,group:"req",group_packages:["req"],lock:"mix.lock"}]}' >"${ROOT_TMP}/landing-ledger.json"
out="${ROOT_TMP}/landing.json"
INBOX_ROOT_DIR="${LANDING_ROOT}" run_collector "${out}" --include 77 --landing-ledger "${ROOT_TMP}/landing-ledger.json"
assert "collector derives actual terminal attribution and passing CI" jq -e \
  '.terminal[0].landing_evidence[0] | .verdict=="pass" and .attributable==true and .run.id==777 and .lock_delta==[{package:"req",from:"0.7.3",to:"0.7.5"}]' "${out}"
no_mutations "collected landing evidence"
# A malformed/unbound CI response must fail the whole collection, not supply
# an empty successful evidence record.
fx "repos/szTheory/rindle/actions/workflows/ci.yml/runs?head_sha=${LANDING_SHA}&event=push&per_page=5" \
  '{"workflow_runs":[{"id":777,"head_sha":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","status":"completed","event":"push","head_branch":"main","path":".github/workflows/ci.yml","repository":{"full_name":"szTheory/rindle"}}]}'
out="${ROOT_TMP}/landing-wrong-ci.json"
INBOX_ROOT_DIR="${LANDING_ROOT}" run_collector "${out}" --include 77 --landing-ledger "${ROOT_TMP}/landing-ledger.json"
record "unbound landing CI aborts without output" "$([ "$RC" -ne 0 ] && [ ! -e "$out" ] && echo true || echo false)"
no_mutations "unbound landing CI"
# An unreadable files endpoint must not become an empty changed-files list.
fx "repos/szTheory/rindle/pulls/77/files?per_page=100" '{"message":"Forbidden"}' 403
out="${ROOT_TMP}/landing-unreadable.json"
run_collector "${out}" --include 77
record "unreadable terminal files abort without output" "$([ "$RC" -ne 0 ] && [ ! -e "$out" ] && echo true || echo false)"
no_mutations "unreadable terminal files"

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
