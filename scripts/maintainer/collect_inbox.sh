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

# Open PRs: list, then a per-PR REST read (the gh pr list CLI reports mergeable as
# UNKNOWN), the changed files, and the authoritative CI Summary for the head.
MERGEABLE_SLEEP="${INBOX_MERGEABLE_SLEEP:-2}"
: >"${WORK}/prs.jsonl"
gh_paged "repos/${REPO}/pulls?state=open&per_page=100" >"${WORK}/pulls.list.json" \
  || die "cannot read open pull requests"
PR_NUMBERS="$(jq -r '.[].number' "${WORK}/pulls.list.json")" || die "malformed pull request list"

for n in ${PR_NUMBERS}; do
  attempt=0
  while :; do
    gh_get "repos/${REPO}/pulls/${n}" >"${WORK}/pr.json" || die "cannot read PR #${n}"
    jq -e 'type == "object"' "${WORK}/pr.json" >/dev/null || die "malformed PR #${n}"
    mergeable_null="$(jq -r 'if .mergeable == null then "yes" else "no" end' "${WORK}/pr.json")"
    attempt=$((attempt + 1))
    # mergeable is null while GitHub computes it: bounded retries, never coerced.
    if [ "${mergeable_null}" = no ] || [ "${attempt}" -ge 3 ]; then break; fi
    sleep "${MERGEABLE_SLEEP}"
  done
  head_sha="$(jq -r '.head.sha // empty' "${WORK}/pr.json")"
  case "${head_sha}" in *[!0-9a-f]*|"") die "PR #${n} head sha is not 40 hex" ;; esac
  [ "${#head_sha}" -eq 40 ] || die "PR #${n} head sha is not 40 hex"

  gh_paged "repos/${REPO}/pulls/${n}/files?per_page=100" >"${WORK}/pr.files.json" \
    || die "cannot read files of PR #${n}"
  gh_get "repos/${REPO}/commits/${head_sha}/check-runs?check_name=CI%20Summary&per_page=100" \
    >"${WORK}/pr.checks.json" || die "cannot read check-runs of PR #${n}"

  # Pitfall 5: a cancelled earlier run leaves a failed CI Summary beside the later
  # success, and filter=latest does not de-duplicate. Take the greatest completed_at.
  jq -S -n \
    --slurpfile d "${WORK}/pr.json" \
    --slurpfile f "${WORK}/pr.files.json" \
    --slurpfile c "${WORK}/pr.checks.json" \
    '$d[0] as $p | $f[0] as $files | $c[0] as $checks
     | ([ $checks.check_runs[]? | select(.name == "CI Summary" and .app.slug == "github-actions") ]) as $runs
     | {number: $p.number,
        title: $p.title,
        author: $p.user.login,
        base: $p.base.ref,
        head_sha: $p.head.sha,
        mergeable: (if $p.mergeable == null then "unknown" else $p.mergeable end),
        mergeable_state: ($p.mergeable_state // "unknown"),
        behind: (($p.mergeable_state // "") == "behind"),
        ci_summary: (if ($runs | length) == 0
                     then {conclusion: null, reason: "no_check_runs"}
                     else ($runs | max_by(.completed_at // "")) as $r
                          | {conclusion: $r.conclusion, completed_at: $r.completed_at,
                             check_run_id: $r.id, superseded_count: (($runs | length) - 1)}
                     end),
        manifest_files: [ $files[] | .filename
                          | select(test("(^|/)mix\\.exs$") or test("(^|/)mix\\.lock$")
                                   or test("^\\.github/workflows/") or test("(^|/)package[^/]*\\.json$")) ],
        lock_delta: ([ $files[]
                       | select(.filename == "mix.lock" or .filename == "examples/adoption_demo/mix.lock")
                       | .filename as $lock
                       | (.patch // "") | split("\n")[]
                       | capture("^(?<sign>[-+])  \"(?<pkg>[a-z_0-9]+)\": \\{:hex, :[a-z_0-9]+, \"(?<ver>[^\"]+)\"")
                       | {lock: $lock, sign: .sign, pkg: .pkg, ver: .ver} ]
                     | group_by([.lock, .pkg])
                     | map({lock: .[0].lock, package: .[0].pkg,
                            from: (map(select(.sign == "-") | .ver) | .[0]),
                            to: (map(select(.sign == "+") | .ver) | .[0])}))}' \
    >>"${WORK}/prs.jsonl" || die "cannot assemble PR #${n}"
done
jq -S -s '{prs: (sort_by(.number))}' "${WORK}/prs.jsonl" >"${WORK}/sec-prs.json" \
  || die "cannot assemble PR list"

# Terminal lookups for ledger entries that are no longer open (--include N).
: >"${WORK}/terminal.jsonl"
for n in ${INCLUDES}; do
  gh_get "repos/${REPO}/issues/${n}" >"${WORK}/term.issue.json" || die "cannot read #${n}"
  if jq -e '.pull_request != null' "${WORK}/term.issue.json" >/dev/null 2>&1; then
    gh_get "repos/${REPO}/pulls/${n}" >"${WORK}/term.pull.json" || die "cannot read PR #${n}"
  else
    echo '{"merged":false}' >"${WORK}/term.pull.json"
  fi
  jq -S -n --slurpfile i "${WORK}/term.issue.json" --slurpfile p "${WORK}/term.pull.json" \
    '$i[0] as $x | {number: $x.number,
                    kind: (if $x.pull_request != null then "pr" else "issue" end),
                    state: $x.state, state_reason: $x.state_reason,
                    merged: ($p[0].merged // false)}' >>"${WORK}/terminal.jsonl" \
    || die "cannot assemble terminal record for #${n}"
done
jq -S -s '{terminal: (sort_by(.number))}' "${WORK}/terminal.jsonl" >"${WORK}/sec-terminal.json" \
  || die "cannot assemble terminal records"

# Branch protection on main: full read, else the reader-visible partial, else unreadable.
gh_get_opt "repos/${REPO}/branches/main/protection"
PROT_STATUS="${OPT_STATUS}"
case "${PROT_STATUS}" in
  200)
    jq -S '{branch_protection: {source: "protection", http: 200,
              contexts: (.required_status_checks.contexts // [ .required_status_checks.checks[]?.context ]),
              strict: (.required_status_checks.strict // false),
              enforce_admins: (.enforce_admins.enabled // false)}}' \
      "${OPT_BODY}" >"${WORK}/sec-protection.json" || die "malformed protection response"
    ;;
  403|404)
    gh_get_opt "repos/${REPO}/branches/main"
    case "${OPT_STATUS}" in
      200)
        jq -S --argjson http "${PROT_STATUS}" \
          '{branch_protection: {source: "branches-partial", http: $http,
              contexts: (.protection.required_status_checks.contexts // []),
              strict: "unreadable", enforce_admins: "unreadable"}}' \
          "${OPT_BODY}" >"${WORK}/sec-protection.json" || die "malformed branch response"
        ;;
      403|404)
        jq -S -n --argjson http "${PROT_STATUS}" \
          '{branch_protection: {source: "unreadable", http: $http, contexts: [],
              strict: "unreadable", enforce_admins: "unreadable"}}' \
          >"${WORK}/sec-protection.json"
        ;;
      *) die "unexpected HTTP ${OPT_STATUS} reading branches/main" ;;
    esac
    ;;
  *) die "unexpected HTTP ${PROT_STATUS} reading branch protection" ;;
esac

# Main CI baseline: latest ci.yml push run on main and every job that did not pass.
gh_get "repos/${REPO}/actions/workflows/ci.yml/runs?branch=main&event=push&per_page=5" \
  >"${WORK}/main.runs.json" || die "cannot read main CI runs"
MAIN_RUN_ID="$(jq -r '.workflow_runs[0].id // empty' "${WORK}/main.runs.json")" || die "malformed main CI runs"
case "${MAIN_RUN_ID}" in ''|*[!0-9]*) die "no ci.yml push run found on main" ;; esac
gh_get "repos/${REPO}/actions/runs/${MAIN_RUN_ID}/jobs?per_page=100" >"${WORK}/main.jobs.json" \
  || die "cannot read jobs of main CI run ${MAIN_RUN_ID}"
jq -S -n --slurpfile r "${WORK}/main.runs.json" --slurpfile j "${WORK}/main.jobs.json" \
  '$r[0].workflow_runs[0] as $run
   | {main_ci: {run_id: $run.id, head_sha: $run.head_sha, conclusion: $run.conclusion,
                failed_jobs: [ $j[0].jobs[] | select(.conclusion != "success" and .conclusion != "skipped") | .name ]}}' \
  >"${WORK}/sec-main-ci.json" || die "cannot assemble main CI baseline"

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
