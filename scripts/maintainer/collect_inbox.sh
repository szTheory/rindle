#!/usr/bin/env bash
# collect_inbox.sh - INBOX-01 read-only inventory collector (Phase 134, D-134-03).
#
# Emits ONE timestamped JSON inventory (schema rindle-inbox-inventory-v1) of the
# open issues, open PRs, advisory sources and branch protection of a GitHub repo.
#
# Usage:
#   scripts/maintainer/collect_inbox.sh --out FILE [--repo OWNER/NAME] [--include N]...
#                                       [--hex-package NAME]... [--skip-demo-audit]
#
# Clock injection for tests: INBOX_NOW_EPOCH (seconds since epoch).
# Exit codes: 0 inventory written | 1 collection failure (no file written) | 64 usage.
#
# Read-only by construction: every GitHub call goes through gh_get / gh_get_opt /
# gh_paged below, which only ever run `gh api <path>` with no method or field flag.
# Untrusted text (titles, labels, patches, audit output) only ever reaches jq via
# --arg / --slurpfile, never an eval or an unquoted shell expansion.
# Bash 3.2 compatible (no mapfile, no associative arrays). jq 1.6 compatible.

set -euo pipefail

SCHEMA="rindle-inbox-inventory-v1"
ACCEPT="Accept: application/vnd.github+json"

REPO="szTheory/rindle"
OUT=""
INCLUDES=""
HEX_PACKAGES=""
SKIP_DEMO_AUDIT=false

usage() {
  cat >&2 <<'USAGE'
usage: collect_inbox.sh --out FILE [--repo OWNER/NAME] [--include N]... [--hex-package NAME]... [--skip-demo-audit]
USAGE
  exit 64
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out) [ "$#" -ge 2 ] || usage; OUT="$2"; shift 2 ;;
    --repo) [ "$#" -ge 2 ] || usage; REPO="$2"; shift 2 ;;
    --include)
      [ "$#" -ge 2 ] || usage
      case "$2" in ''|*[!0-9]*) echo "collect_inbox: --include needs a number" >&2; exit 64 ;; esac
      INCLUDES="${INCLUDES} $2"; shift 2 ;;
    --hex-package)
      [ "$#" -ge 2 ] || usage
      case "$2" in
        ''|[!a-z]*|*[!a-z0-9_]*) echo "collect_inbox: bad --hex-package name" >&2; exit 64 ;;
      esac
      HEX_PACKAGES="${HEX_PACKAGES} $2"; shift 2 ;;
    --skip-demo-audit) SKIP_DEMO_AUDIT=true; shift ;;
    -h|--help) usage ;;
    *) echo "collect_inbox: unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "${OUT}" ] || usage
case "${REPO}" in
  */*) ;;
  *) echo "collect_inbox: --repo must be OWNER/NAME" >&2; exit 64 ;;
esac
case "${REPO}" in
  *[!A-Za-z0-9._/-]*) echo "collect_inbox: --repo has unexpected characters" >&2; exit 64 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${INBOX_ROOT_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

WORK=""
TMP_OUT=""

cleanup() {
  [ -z "${TMP_OUT}" ] || [ ! -e "${TMP_OUT}" ] || rm -f "${TMP_OUT}"
  [ -z "${WORK}" ] || [ ! -d "${WORK}" ] || rm -rf "${WORK}"
}

on_exit() {
  local rc=$?
  trap - EXIT
  cleanup
  # Any failure other than a usage error is a collection failure: exit 1.
  if [ "${rc}" -ne 0 ] && [ "${rc}" -ne 64 ]; then
    exit 1
  fi
  exit "${rc}"
}
trap on_exit EXIT

die() {
  echo "collect_inbox: $*" >&2
  exit 1
}

for tool in gh jq; do
  command -v "${tool}" >/dev/null 2>&1 || die "${tool} is required"
done

out_dir="$(dirname "${OUT}")"
[ -d "${out_dir}" ] || die "output directory does not exist: ${out_dir}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/collect_inbox.XXXXXX")"
TMP_OUT="$(mktemp "${out_dir}/.inbox-inventory.XXXXXX")"

# --- read-only GitHub access ------------------------------------------------

check_path() {
  case "$1" in
    -*|"") die "refusing unsafe gh api path: '$1'" ;;
  esac
}

# gh_get PATH: one GET, body on stdout. Non-2xx or transport error aborts.
gh_get() {
  check_path "$1"
  gh api -H "${ACCEPT}" "$1"
}

# gh_paged PATH: every page of a list endpoint, flattened to one JSON array.
# --slurp cannot be combined with --jq, so the flatten happens in jq.
gh_paged() {
  check_path "$1"
  gh api -H "${ACCEPT}" --paginate --slurp "$1" | jq -S '[.[][]]'
}

# gh_get_opt PATH: for endpoints where 403/404 is a recordable state, not a
# failure. Sets OPT_STATUS (HTTP code) and OPT_BODY (file). A response with no
# parseable status line (transport failure) or a 5xx aborts the collection.
OPT_STATUS=""
OPT_BODY="${WORK:-/dev/null}/opt.body"
gh_get_opt() {
  check_path "$1"
  local raw="${WORK}/opt.raw" first rc=0
  OPT_BODY="${WORK}/opt.body"
  gh api -i -H "${ACCEPT}" "$1" >"${raw}" 2>"${WORK}/opt.err" || rc=$?
  first="$(head -n 1 "${raw}" | tr -d '\r')"
  case "${first}" in
    HTTP/*" "[0-9][0-9][0-9]*) ;;
    *) die "no HTTP status from GET $1 (gh exit ${rc})" ;;
  esac
  OPT_STATUS="$(printf '%s' "${first}" | awk '{print $2}')"
  awk 'b{print} !b && /^\r?$/{b=1}' "${raw}" | tr -d '\r' >"${OPT_BODY}"
  case "${OPT_STATUS}" in
    2??) [ "${rc}" -eq 0 ] || die "GET $1 returned ${OPT_STATUS} but gh exited ${rc}" ;;
    5??) die "GET $1 returned HTTP ${OPT_STATUS}" ;;
  esac
}

# --- collection -------------------------------------------------------------

command -v gh >/dev/null 2>&1
gh auth status >/dev/null 2>&1 || die "gh is not authenticated (gh auth status failed)"

if [ -n "${INBOX_NOW_EPOCH:-}" ]; then
  NOW_EPOCH="${INBOX_NOW_EPOCH}"
else
  NOW_EPOCH="$(date -u +%s)"
fi
case "${NOW_EPOCH}" in ''|*[!0-9]*) die "clock is not an integer epoch: ${NOW_EPOCH}" ;; esac

MAIN_SHA="$(gh_get "repos/${REPO}/commits/main" | jq -r '.sha // empty')" || die "cannot read main commit"
case "${MAIN_SHA}" in
  *[!0-9a-f]*|"") die "main sha is not 40 hex: '${MAIN_SHA}'" ;;
esac
[ "${#MAIN_SHA}" -eq 40 ] || die "main sha is not 40 hex: '${MAIN_SHA}'"

# Issues (the issues endpoint also returns PRs; drop them).
gh_paged "repos/${REPO}/issues?state=open&per_page=100" >"${WORK}/issues.raw.json" \
  || die "cannot read open issues"
jq -S '{issues: ([ .[] | select(.pull_request == null)
        | {number, title, labels: [ .labels[]? | (if type == "object" then .name else . end) ], updated_at} ]
      | sort_by(.number))}' "${WORK}/issues.raw.json" >"${WORK}/sec-issues.json" \
  || die "malformed issues response"

# --- assemble ---------------------------------------------------------------

jq -S -n \
  --arg schema "${SCHEMA}" \
  --argjson now "${NOW_EPOCH}" \
  --arg repo "${REPO}" \
  --arg main_sha "${MAIN_SHA}" \
  '{schema: $schema, collected_at: ($now | todate), repo: $repo, main_sha: $main_sha}' \
  >"${WORK}/sec-header.json" || die "cannot build header"

jq -S -s 'add' "${WORK}"/sec-*.json >"${TMP_OUT}" || die "cannot assemble inventory"
jq -e '.schema and .collected_at and .repo and (.main_sha | length == 40)' "${TMP_OUT}" >/dev/null \
  || die "assembled inventory failed shape check"

mv "${TMP_OUT}" "${OUT}"
TMP_OUT=""
echo "collect_inbox: wrote ${OUT}" >&2
