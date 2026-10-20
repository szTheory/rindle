#!/usr/bin/env bash
# Fixture harness for scripts/maintainer/collect_phase_gate_evidence.sh.
#
# Pure bash + jq + local git: a fake `gh` on PATH answers `gh api -X GET <path>` from
# per-case fixture files and logs argv. Any other gh invocation is logged as a
# rejection and exits 97, so a collector that tried to rerun, merge, label or post would
# be caught. Commits with planted subjects live in a throwaway git repository. No
# network, no real gh login, no Elixir.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
collector="${here}/../maintainer/collect_phase_gate_evidence.sh"

ROOT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/test_phase_gate_evidence.XXXXXX")"
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

BIN="${ROOT_TMP}/bin"
mkdir -p "${BIN}"

# --- fake gh ----------------------------------------------------------------
cat >"${BIN}/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"${FAKE_DIR}/gh.log"
if [ "$#" -ne 4 ] || [ "$1" != api ] || [ "$2" != -X ] || [ "$3" != GET ]; then
  printf '%s\n' "$*" >>"${FAKE_DIR}/rejected"
  exit 97
fi
key="$(printf '%s' "$4" | tr -c 'A-Za-z0-9._-' '_')"
if [ -f "${FAKE_DIR}/fx/${key}" ]; then
  cat "${FAKE_DIR}/fx/${key}"
  exit 0
fi
echo '{"message":"Not Found"}'
exit 1
FAKE_GH
chmod +x "${BIN}/gh"

# --- fixture repository -------------------------------------------------------
REPO_DIR="${ROOT_TMP}/repo"
git init -q "${REPO_DIR}"
gitc() {
  git -C "${REPO_DIR}" -c user.name=fixture -c user.email=fixture@example.invalid \
    -c commit.gpgsign=false "$@"
}
commit() {
  gitc commit -q --allow-empty -m "$1"
  git -C "${REPO_DIR}" rev-parse HEAD
}
BASE="$(commit "chore: base")"
SHA_A="$(commit "ci: first change (#1)")"
SHA_B="$(commit "test: second change (#2)")"
SHA_FIX="$(commit "fix: a releasing change (#3)")"
SHA_FEAT="$(commit "feat(scope): a releasing feature (#4)")"
SHA_TIP="$(commit "docs: after the phase (#5)")"
git -C "${REPO_DIR}" checkout -q -b side "${BASE}"
SHA_SIDE="$(commit "chore: unrelated side commit")"

REPO="szTheory/rindle"
FAKE_DIR=""
export FAKE_DIR

fx_new() {
  FAKE_DIR="${ROOT_TMP}/case_$1"
  mkdir -p "${FAKE_DIR}/fx"
  : >"${FAKE_DIR}/gh.log"
  printf 'Checks...\nResult: safe to start release prep\n' >"${FAKE_DIR}/hygiene.log"
}

fx() {
  local key
  key="$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')"
  printf '%s\n' "$2" >"${FAKE_DIR}/fx/${key}"
}

runs_path() {
  printf 'repos/%s/actions/workflows/ci.yml/runs?head_sha=%s&event=push&branch=main&per_page=20' "${REPO}" "$1"
}

# push_run SHA RUN_ID CONCLUSION(json) SUMMARY_CONCLUSION(json)
push_run() {
  fx "$(runs_path "$1")" "{\"total_count\":1,\"workflow_runs\":[{\"id\":$2,\"head_sha\":\"$1\",\"created_at\":\"2026-10-18T10:00:00Z\",\"conclusion\":$3}]}"
  fx "repos/${REPO}/actions/runs/$2/jobs?per_page=100" "{\"total_count\":2,\"jobs\":[{\"name\":\"Quality\",\"conclusion\":\"success\"},{\"name\":\"CI Summary\",\"conclusion\":$4}]}"
}

nightly_runs() {
  fx "repos/${REPO}/actions/workflows/nightly.yml/runs?event=schedule&per_page=10" "$1"
}

shas() {
  printf '%s\n' "$@" >"${FAKE_DIR}/shas"
}

OUT=""
RC=0
run_collector() {
  OUT="${FAKE_DIR}/out.json"
  RC=0
  PATH="${BIN}:${PATH}" bash "${collector}" --repo "${REPO}" \
    --shas-file "${FAKE_DIR}/shas" --hygiene-log "${FAKE_DIR}/hygiene.log" \
    --root "${REPO_DIR}" "$@" >"${OUT}" 2>"${FAKE_DIR}/stderr" || RC=$?
}

# check NAME EXPECTED_RC JQ_FILTER
check() {
  if [ "${RC}" -eq "$2" ] && jq -e "$3" "${OUT}" >/dev/null 2>&1; then
    record "$1" true
  else
    record "$1" false "rc=${RC} out=$(cat "${OUT}") err=$(cat "${FAKE_DIR}/stderr")"
  fi
}

only_get_calls() {
  local name="$1"
  if [ -s "${FAKE_DIR}/gh.log" ] && [ ! -e "${FAKE_DIR}/rejected" ] &&
    ! grep -v '^api -X GET repos/' "${FAKE_DIR}/gh.log" >/dev/null; then
    record "${name}" true
  else
    record "${name}" false "$(cat "${FAKE_DIR}/gh.log")"
  fi
}

good_nightly() {
  nightly_runs "{\"workflow_runs\":[{\"id\":900,\"head_sha\":\"${SHA_SIDE}\",\"created_at\":\"2026-10-19T03:00:00Z\",\"conclusion\":\"success\"},{\"id\":800,\"head_sha\":\"${SHA_TIP}\",\"created_at\":\"2026-10-18T03:00:00Z\",\"conclusion\":\"success\"},{\"id\":700,\"head_sha\":\"${BASE}\",\"created_at\":\"2026-10-17T03:00:00Z\",\"conclusion\":\"failure\"}]}"
}

# --- pass ------------------------------------------------------------------------
fx_new pass
shas "${SHA_A}" "${SHA_B}"
push_run "${SHA_A}" 101 '"success"' '"success"'
push_run "${SHA_B}" 102 '"success"' '"success"'
good_nightly
run_collector --hygiene-exit 0 --nightly-after "${SHA_B}"
check "two green SHAs with safe hygiene pass" 0 \
  '.schema == "rindle-phase-gate-evidence-v1" and .verdict == "pass" and .repo == "szTheory/rindle"
   and (keys == ["causes","hygiene","nightly_followup","repo","schema","shas","verdict"])
   and (.shas | length == 2) and all(.shas[]; .ok and .causes == [])
   and .shas[0].subject == "ci: first change (#1)" and .shas[0].ci_push == {"run_id":101,"conclusion":"success"}
   and .shas[1].ci_summary == {"conclusion":"success"}
   and .hygiene == {"result_line":"Result: safe to start release prep","exit":0,"ok":true}'
check "newest scheduled Nightly on a descendant is observed, unrelated runs skipped" 0 \
  '.nightly_followup.status == "observed" and .nightly_followup.run_id == 800'
check "observed Nightly records its head SHA and conclusion" 0 \
  ".nightly_followup.head_sha == \"${SHA_TIP}\" and .nightly_followup.conclusion == \"success\""
only_get_calls "every gh call is api -X GET (pass case)"

# --- run concluded failure ---------------------------------------------------------
fx_new failure
shas "${SHA_A}" "${SHA_B}"
push_run "${SHA_A}" 101 '"success"' '"success"'
push_run "${SHA_B}" 102 '"failure"' '"failure"'
run_collector --hygiene-exit 0
check "a failed push run fails naming the SHA and ci_push failure" 1 \
  ".verdict == \"fail\" and (.causes | index(\"${SHA_B}: ci_push failure\") != null)
   and .shas[0].ok and (.shas[1].ok | not)"

# --- in progress ---------------------------------------------------------------------
fx_new pending
shas "${SHA_A}"
push_run "${SHA_A}" 101 'null' 'null'
run_collector --hygiene-exit 0
check "an in-progress run (null conclusion) fails as ci_push pending" 1 \
  ".verdict == \"fail\" and (.causes | index(\"${SHA_A}: ci_push pending\") != null)
   and .shas[0].ci_push.conclusion == null"

# --- missing run -----------------------------------------------------------------------
fx_new missing
shas "${SHA_A}"
fx "$(runs_path "${SHA_A}")" '{"total_count":0,"workflow_runs":[]}'
run_collector --hygiene-exit 0
check "no push run for a SHA fails as ci_push missing" 1 \
  ".verdict == \"fail\" and (.causes | index(\"${SHA_A}: ci_push missing\") != null)
   and .shas[0].ci_push.run_id == null"

# --- newest run wins -----------------------------------------------------------------
fx_new newest
shas "${SHA_A}"
fx "$(runs_path "${SHA_A}")" "{\"workflow_runs\":[{\"id\":201,\"created_at\":\"2026-10-18T10:00:00Z\",\"conclusion\":\"failure\"},{\"id\":202,\"created_at\":\"2026-10-18T11:00:00Z\",\"conclusion\":\"success\"}]}"
fx "repos/${REPO}/actions/runs/202/jobs?per_page=100" '{"jobs":[{"name":"CI Summary","conclusion":"success"}]}'
run_collector --hygiene-exit 0
check "the newest push run for a SHA is the one judged" 0 \
  '.verdict == "pass" and .shas[0].ci_push.run_id == 202'

# --- CI Summary failure ----------------------------------------------------------------
fx_new summary
shas "${SHA_A}"
push_run "${SHA_A}" 101 '"success"' '"failure"'
run_collector --hygiene-exit 0
check "CI Summary failure on a green run fails as ci_summary failure" 1 \
  ".verdict == \"fail\" and (.causes | index(\"${SHA_A}: ci_summary failure\") != null)"

# --- releasing subjects ---------------------------------------------------------------
fx_new fix
shas "${SHA_FIX}"
push_run "${SHA_FIX}" 103 '"success"' '"success"'
run_collector --hygiene-exit 0
check "a fix: subject fails as releasing subject" 1 \
  ".verdict == \"fail\" and (.causes | index(\"${SHA_FIX}: releasing subject\") != null)"

fx_new feat
shas "${SHA_FEAT}"
push_run "${SHA_FEAT}" 104 '"success"' '"success"'
run_collector --hygiene-exit 0
check "a feat(scope): subject fails as releasing subject" 1 \
  ".verdict == \"fail\" and (.causes | index(\"${SHA_FEAT}: releasing subject\") != null)"

# --- hygiene ------------------------------------------------------------------------------
fx_new hygiene_line
shas "${SHA_A}"
push_run "${SHA_A}" 101 '"success"' '"success"'
printf 'Checks...\nResult: proceed with caution\n' >"${FAKE_DIR}/hygiene.log"
run_collector --hygiene-exit 0
check "a hygiene log without the safe line fails naming hygiene" 1 \
  '.verdict == "fail" and .hygiene.ok == false and .hygiene.result_line == "Result: proceed with caution"
   and any(.causes[]; startswith("hygiene"))'

fx_new hygiene_exit
shas "${SHA_A}"
push_run "${SHA_A}" 101 '"success"' '"success"'
run_collector --hygiene-exit 1
check "hygiene exit 1 fails naming hygiene" 1 \
  '.verdict == "fail" and .hygiene.exit == 1 and .hygiene.ok == false and any(.causes[]; startswith("hygiene"))'

# --- Nightly pending never changes the verdict ------------------------------------------
fx_new nightly_pending
shas "${SHA_A}"
push_run "${SHA_A}" 101 '"success"' '"success"'
nightly_runs "{\"workflow_runs\":[{\"id\":900,\"head_sha\":\"${SHA_SIDE}\",\"created_at\":\"2026-10-19T03:00:00Z\",\"conclusion\":\"failure\"},{\"id\":700,\"head_sha\":\"${BASE}\",\"created_at\":\"2026-10-17T03:00:00Z\",\"conclusion\":\"failure\"}]}"
run_collector --hygiene-exit 0 --nightly-after "${SHA_A}"
check "no scheduled Nightly on a descendant is pending and the verdict still passes" 0 \
  '.verdict == "pass" and .nightly_followup == {"status":"pending","run_id":null,"head_sha":null,"conclusion":null}'
only_get_calls "every gh call is api -X GET (nightly case)"

# --- mutation tripwire ------------------------------------------------------------------
fx_new tripwire
RC=0
PATH="${BIN}:${PATH}" gh run rerun 101 >/dev/null 2>&1 || RC=$?
RC2=0
PATH="${BIN}:${PATH}" gh api -X POST "repos/${REPO}/actions/runs/101/rerun" >/dev/null 2>&1 || RC2=$?
if [ "${RC}" -eq 97 ] && [ "${RC2}" -eq 97 ] && [ "$(wc -l <"${FAKE_DIR}/rejected" | tr -d ' ')" = 2 ]; then
  record "fake gh rejects gh run rerun and api -X POST with exit 97" true
else
  record "fake gh rejects gh run rerun and api -X POST with exit 97" false "rc=${RC} rc2=${RC2}"
fi

# A collector variant whose single GitHub access path reruns instead of reading.
fx_new mutant
shas "${SHA_A}"
push_run "${SHA_A}" 101 '"success"' '"success"'
mutant="${ROOT_TMP}/mutant_collector.sh"
# shellcheck disable=SC2016 # the pattern is literal sed text
sed 's/^  gh api -X GET "\$1"$/  gh run rerun "$1"/' "${collector}" >"${mutant}"
if cmp -s "${collector}" "${mutant}"; then
  record "a collector built to call gh run rerun is caught" false "mutation did not apply"
else
  RC=0
  PATH="${BIN}:${PATH}" bash "${mutant}" --repo "${REPO}" \
    --shas-file "${FAKE_DIR}/shas" --hygiene-log "${FAKE_DIR}/hygiene.log" --hygiene-exit 0 \
    --root "${REPO_DIR}" >"${FAKE_DIR}/out.json" 2>/dev/null || RC=$?
  if [ "${RC}" -ne 0 ] && [ -s "${FAKE_DIR}/rejected" ] && grep -q '^run rerun ' "${FAKE_DIR}/rejected" &&
    jq -e '.verdict == "fail"' "${FAKE_DIR}/out.json" >/dev/null 2>&1; then
    record "a collector built to call gh run rerun is caught" true
  else
    record "a collector built to call gh run rerun is caught" false "rc=${RC}"
  fi
fi

# --- usage and injection --------------------------------------------------------------
fx_new usage
shas "${SHA_A}"
usage_case() {
  local name="$1"
  shift
  RC=0
  PATH="${BIN}:${PATH}" bash "${collector}" "$@" >/dev/null 2>&1 || RC=$?
  if [ "${RC}" -eq 64 ] && [ ! -s "${FAKE_DIR}/gh.log" ]; then
    record "${name}" true
  else
    record "${name}" false "rc=${RC} gh=$(cat "${FAKE_DIR}/gh.log")"
  fi
}
usage_case "an unknown flag exits 64" --repo "${REPO}" --shas-file "${FAKE_DIR}/shas" \
  --hygiene-log "${FAKE_DIR}/hygiene.log" --hygiene-exit 0 --bogus
usage_case "a missing --shas-file exits 64" --repo "${REPO}" \
  --hygiene-log "${FAKE_DIR}/hygiene.log" --hygiene-exit 0
usage_case "a --repo outside OWNER/NAME exits 64 before any gh call" --repo 'szTheory/rindle/../x?a=1' \
  --shas-file "${FAKE_DIR}/shas" --hygiene-log "${FAKE_DIR}/hygiene.log" --hygiene-exit 0
printf '%s\n' "${SHA_A}&event=pull_request" >"${FAKE_DIR}/bad_shas"
usage_case "a SHA line that is not 40-character hex exits 64 before any gh call" --repo "${REPO}" \
  --shas-file "${FAKE_DIR}/bad_shas" --hygiene-log "${FAKE_DIR}/hygiene.log" --hygiene-exit 0

echo
echo "collect_phase_gate_evidence harness: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
