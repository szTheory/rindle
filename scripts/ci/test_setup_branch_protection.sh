#!/usr/bin/env bash
# Regression matrix for the setup_branch_protection.sh pending-forever guard (D-12),
# driven by a fake `gh`. Covers the `[skip ci]` head commit that has no check-runs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${here}/../setup_branch_protection.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

mkdir -p "${tmp}/bin"
cat >"${tmp}/bin/gh" <<'FAKE'
#!/usr/bin/env bash
# Fake gh: FAKE_DIR/commits lists SHAs newest first; FAKE_DIR/runs/<sha> lists check-run
# names; FAKE_DIR/fail_commits / fail_runs force API errors; PUTs are logged to FAKE_DIR/puts.
set -euo pipefail
args="$*"
case "${args}" in
  *"-X PUT"*)
    cat >/dev/null
    echo "${args}" >>"${FAKE_DIR}/puts"
    echo '{}'
    ;;
  *"/commits?sha="*)
    [ -e "${FAKE_DIR}/fail_commits" ] && exit 1
    per_page="$(sed -E 's#.*per_page=([0-9]+).*#\1#' <<<"${args}")"
    head -n "${per_page}" "${FAKE_DIR}/commits"
    ;;
  *"/check-runs"*)
    [ -e "${FAKE_DIR}/fail_runs" ] && exit 1
    sha="$(sed -E 's#.*/commits/([^/]+)/check-runs.*#\1#' <<<"${args}")"
    cat "${FAKE_DIR}/runs/${sha}" 2>/dev/null || true
    ;;
  *) echo "unexpected gh call: ${args}" >&2; exit 99 ;;
esac
FAKE
chmod +x "${tmp}/bin/gh"

pass=0
fail=0
record() {
  if [ "$2" = true ]; then echo "ok   — $1"; pass=$((pass + 1)); else echo "FAIL — $1: $3" >&2; fail=$((fail + 1)); fi
}

# scenario NAME EXPECT_EXIT EXPECT_PUT [script args...]; fixture prepared in $FAKE_DIR beforehand.
run_case() {
  local name="$1" want_rc="$2" want_put="$3"
  shift 3
  local rc=0 puts=0
  PATH="${tmp}/bin:${PATH}" FAKE_DIR="${FAKE_DIR}" GH_TOKEN=fake GUARD_LOOKBACK=3 \
    bash "${script}" "$@" >"${FAKE_DIR}/out" 2>&1 || rc=$?
  [ -f "${FAKE_DIR}/puts" ] && puts="$(wc -l <"${FAKE_DIR}/puts" | tr -d ' ')"
  if [ "${rc}" = "${want_rc}" ] && [ "${puts}" = "${want_put}" ]; then
    record "${name}" true ""
  else
    record "${name}" false "rc=${rc} (want ${want_rc}) puts=${puts} (want ${want_put}); $(tail -3 "${FAKE_DIR}/out")"
  fi
}

fixture() {
  FAKE_DIR="${tmp}/$1"
  mkdir -p "${FAKE_DIR}/runs"
  printf '%s\n' "${@:2}" >"${FAKE_DIR}/commits"
}

fixture head_reported aaa bbb
printf 'Quality\nCI Summary\n' >"${FAKE_DIR}/runs/aaa"
run_case "head commit reported CI Summary -> applies" 0 1 main

fixture skip_ci_head skipci aaa bbb
printf 'CI Summary\n' >"${FAKE_DIR}/runs/aaa"
run_case "[skip ci] head with no check-runs, parent reported -> applies" 0 1 main

fixture never_reported aaa bbb ccc ddd
printf 'CI Summary\n' >"${FAKE_DIR}/runs/ddd"
run_case "context only beyond lookback window -> refuses" 1 0 main

fixture commits_unreadable aaa
touch "${FAKE_DIR}/fail_commits"
run_case "commit list unreadable -> refuses" 1 0 main

fixture runs_unreadable aaa
touch "${FAKE_DIR}/fail_runs"
run_case "check-runs unreadable -> refuses" 1 0 main

fixture forced aaa
run_case "--force bypasses the guard" 0 1 main --force

echo "${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
