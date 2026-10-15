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
