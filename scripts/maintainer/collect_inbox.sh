#!/usr/bin/env bash
# collect_inbox.sh - read-only maintainer inbox inventory collector.
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
  if [ -n "${WORK}" ] && [ -d "${WORK}" ]; then
    chmod -R u+w "${WORK}" 2>/dev/null || true
    rm -rf "${WORK}"
  fi
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

for tool in gh jq mix; do
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

  # A cancelled earlier run leaves a failed CI Summary beside the later
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

# Terminal lookups for ledger entries that are already closed (--include N).
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

# --- advisories (security advisory input) ---------------------------------
# Every source is an explicit record. A disabled or unreadable source is never a
# zero count, and an unparseable audit aborts the whole collection
# (hex.audit exits 1 for findings AND for operational errors).

ESC="$(printf '\033')"

lock_fingerprint() {
  local f
  for f in "${ROOT}/mix.lock" "${ROOT}/examples/adoption_demo/mix.lock"; do
    if [ -f "${f}" ]; then cksum <"${f}"; else echo missing; fi
  done
}
LOCKS_BEFORE="$(lock_fingerprint)"

# run_hex_audit DIR SCOPE DEST [DEPS_PATH BUILD_PATH]
# Runs `mix hex.audit` with configured ignores emptied so mix.exs/env ignores cannot
# mask the raw advisory set, and writes {status, findings[]} to DEST.
run_hex_audit() {
  local dir="$1" scope="$2" dest="$3" deps_path="${4:-}" build_path="${5:-}" rc=0 markers nfind
  (
    cd "${dir}"
    if [ -n "${deps_path}" ]; then export MIX_DEPS_PATH="${deps_path}" MIX_BUILD_PATH="${build_path}"; fi
    HEX_IGNORE_ADVISORIES="" mix hex.audit
  ) >"${WORK}/audit.out" 2>"${WORK}/audit.err" || rc=$?
  sed "s/${ESC}\[[0-9;]*m//g" "${WORK}/audit.out" | awk '
    BEGIN { ign = 0 }
    /^Advisories:$/ { ign = 0; print "M"; next }
    /^Ignored advisories:$/ { ign = 1; print "M"; next }
    /^  [a-z0-9_]+ [0-9][^ ]* - [A-Za-z0-9-]+ \([A-Z]+\)$/ {
      sev = $5; gsub(/[()]/, "", sev)
      print "F\t" $1 "\t" $2 "\t" $4 "\t" sev "\t" ign
    }' >"${WORK}/audit.tsv"
  markers="$(grep -c '^M' "${WORK}/audit.tsv" || true)"
  nfind="$(grep -c '^F' "${WORK}/audit.tsv" || true)"
  if [ "${rc}" -eq 0 ] && [ "${markers}" -eq 0 ] && [ "${nfind}" -eq 0 ]; then
    echo '{"status":"clean","findings":[]}' >"${dest}"
    return 0
  fi
  if [ "${markers}" -eq 0 ] || [ "${nfind}" -eq 0 ]; then
    die "mix hex.audit in ${scope} exited ${rc} with no recognizable advisory section: $(tail -n 3 "${WORK}/audit.err" | tr '\n' ' ')"
  fi
  jq -R -S -n --arg scope "${scope}" \
    '{status: "findings",
      findings: [ inputs | split("\t") | select(.[0] == "F")
                  | {id: .[3], package: .[1], version: .[2], severity: .[4], scope: $scope,
                     source: "hex_audit", ignored: (.[5] == "1")} ]}' \
    <"${WORK}/audit.tsv" >"${dest}" || die "cannot parse hex.audit findings in ${scope}"
}

run_hex_audit "${ROOT}" "root" "${WORK}/audit-root.json"
jq -S '{status}' "${WORK}/audit-root.json" >"${WORK}/src-hex_audit_root.json"

if [ "${SKIP_DEMO_AUDIT}" = true ]; then
  echo '{"findings":[]}' >"${WORK}/audit-demo.json"
  echo '{"status":"unreadable","reason":"skipped"}' >"${WORK}/src-hex_audit_demo.json"
else
  mkdir -p "${WORK}/demo-deps" "${WORK}/demo-build"
  demo_rc=0
  (
    cd "${ROOT}/examples/adoption_demo"
    export MIX_DEPS_PATH="${WORK}/demo-deps" MIX_BUILD_PATH="${WORK}/demo-build"
    mix deps.get --check-locked
  ) >"${WORK}/demo-get.out" 2>&1 || demo_rc=$?
  if [ "${demo_rc}" -ne 0 ]; then
    echo '{"findings":[]}' >"${WORK}/audit-demo.json"
    jq -S -n --arg reason "deps.get failed: $(tail -n 1 "${WORK}/demo-get.out" | tr -d '\r' | cut -c1-200)" \
      '{status: "unreadable", reason: $reason}' >"${WORK}/src-hex_audit_demo.json"
  else
    run_hex_audit "${ROOT}/examples/adoption_demo" "examples/adoption_demo" "${WORK}/audit-demo.json" \
      "${WORK}/demo-deps" "${WORK}/demo-build"
    jq -S '{status}' "${WORK}/audit-demo.json" >"${WORK}/src-hex_audit_demo.json"
  fi
fi

# deps.audit is a second opinion only (it disagreed with hex.audit in research).
da_rc=0
(cd "${ROOT}" && mix deps.audit) >"${WORK}/deps-audit.out" 2>&1 || da_rc=$?
sed "s/${ESC}\[[0-9;]*m//g" "${WORK}/deps-audit.out" | tail -n 20 >"${WORK}/deps-audit.tail"
if [ "${da_rc}" -eq 0 ]; then
  da_status=clean
elif grep -qi 'vulnerabilit' "${WORK}/deps-audit.tail"; then
  da_status=findings
else
  da_status=unreadable
fi
jq -S -n --arg status "${da_status}" --rawfile tail "${WORK}/deps-audit.tail" \
  '{status: $status, output_tail: $tail}' >"${WORK}/src-deps_audit.json"

[ "$(lock_fingerprint)" = "${LOCKS_BEFORE}" ] || die "a mix.lock changed during collection; refusing to write an inventory"

# GitHub Dependabot alerts: 200 enabled; 403 is source_disabled only when GitHub says so.
echo '[]' >"${WORK}/alerts.findings.json"
gh_get_opt "repos/${REPO}/dependabot/alerts?state=open&per_page=100"
alerts_msg="$(jq -r '.message // ""' "${OPT_BODY}" 2>/dev/null || true)"
case "${OPT_STATUS}" in
  200)
    jq -e 'type == "array" and length < 100' "${OPT_BODY}" >/dev/null \
      || die "dependabot alerts response is not a complete single page"
    jq -S '[ .[] | {id: (.security_advisory.ghsa_id // .security_advisory.cve_id // "unknown"),
                    package: .dependency.package.name,
                    version: .security_vulnerability.vulnerable_version_range,
                    severity: .security_advisory.severity,
                    scope: (if ((.dependency.manifest_path // "") | startswith("examples/adoption_demo")) then "examples/adoption_demo" else "root" end),
                    source: "dependabot", ignored: false} ]' \
      "${OPT_BODY}" >"${WORK}/alerts.findings.json" || die "malformed dependabot alerts"
    echo '{"status":"enabled","http":200}' >"${WORK}/src-dependabot_alerts.json"
    ;;
  403)
    case "${alerts_msg}" in
      *"disabled for this repository"*)
        echo '{"status":"source_disabled","http":403}' >"${WORK}/src-dependabot_alerts.json" ;;
      *)
        jq -S -n --arg m "${alerts_msg}" '{status:"unreadable",http:403,message:$m}' >"${WORK}/src-dependabot_alerts.json" ;;
    esac
    ;;
  404)
    jq -S -n --arg m "${alerts_msg}" '{status:"unreadable",http:404,message:$m}' >"${WORK}/src-dependabot_alerts.json"
    ;;
  *) die "unexpected HTTP ${OPT_STATUS} reading dependabot alerts" ;;
esac

# vulnerability-alerts probe: 204 enabled, 404 disabled, 403 unreadable.
gh_get_opt "repos/${REPO}/vulnerability-alerts"
case "${OPT_STATUS}" in
  204) echo '{"status":"enabled","http":204}' >"${WORK}/src-vulnerability_alerts.json" ;;
  404) echo '{"status":"source_disabled","http":404}' >"${WORK}/src-vulnerability_alerts.json" ;;
  403) echo '{"status":"unreadable","http":403}' >"${WORK}/src-vulnerability_alerts.json" ;;
  *) die "unexpected HTTP ${OPT_STATUS} probing vulnerability-alerts" ;;
esac
echo '{"status":"not-applicable","reason":"SHA-pinned actions produce no alerts"}' >"${WORK}/src-actions.json"

jq -S -n \
  --slurpfile root "${WORK}/audit-root.json" --slurpfile demo "${WORK}/audit-demo.json" \
  --slurpfile alerts "${WORK}/alerts.findings.json" \
  --slurpfile s_root "${WORK}/src-hex_audit_root.json" --slurpfile s_demo "${WORK}/src-hex_audit_demo.json" \
  --slurpfile s_deps "${WORK}/src-deps_audit.json" --slurpfile s_dep "${WORK}/src-dependabot_alerts.json" \
  --slurpfile s_vuln "${WORK}/src-vulnerability_alerts.json" --slurpfile s_act "${WORK}/src-actions.json" \
  '{advisories: {sources: {hex_audit_root: $s_root[0], hex_audit_demo: $s_demo[0], deps_audit: $s_deps[0],
                           dependabot_alerts: $s_dep[0], vulnerability_alerts: $s_vuln[0], actions: $s_act[0]},
                 findings: ($root[0].findings + $demo[0].findings + $alerts[0])}}' \
  >"${WORK}/sec-advisories.json" || die "cannot assemble advisories"

# Latest released version per requested package (via mix hex.info).
echo '{}' >"${WORK}/hex_latest.json"
for pkg in ${HEX_PACKAGES}; do
  (cd "${ROOT}" && mix hex.info "${pkg}") >"${WORK}/hexinfo.out" 2>/dev/null || die "mix hex.info ${pkg} failed"
  ver="$(sed "s/${ESC}\[[0-9;]*m//g" "${WORK}/hexinfo.out" \
    | awk '/^(Recent releases|Releases):/ { f = 1; next } f && $1 ~ /^[0-9]/ { print $1; exit }')"
  [ -n "${ver}" ] || die "cannot find a released version for ${pkg} in mix hex.info output"
  jq -S --arg k "${pkg}" --arg v "${ver}" '. + {($k): $v}' "${WORK}/hex_latest.json" >"${WORK}/hex_latest.next" \
    && mv "${WORK}/hex_latest.next" "${WORK}/hex_latest.json"
done
jq -S '{hex_latest: .}' "${WORK}/hex_latest.json" >"${WORK}/sec-hex-latest.json"

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
