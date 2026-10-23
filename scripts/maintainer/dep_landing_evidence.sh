#!/usr/bin/env bash
# dep_landing_evidence.sh - per-landing attribution and post-merge gate evidence
# for dependency updates.
#
# Usage:
#   scripts/maintainer/dep_landing_evidence.sh --sha SHA [--group NAME --packages a,b,...]
#       [--lock mix.lock|examples/adoption_demo/mix.lock] [--baseline-sha SHA]
#       [--evidence-sha SHA] [--repo OWNER/NAME] [--out FILE]
#
# With --group the squash commit SHA must have exactly one parent; its package-level
# lock delta must be a subset of --packages (an empty --packages requires an empty
# delta) and the matching mix.exs must be unchanged. Without --group the tool runs in
# baseline mode: gates only, no attribution.
# An optional --evidence-sha must equal SHA or descend through planning prose
# (*.md) / INBOX-LEDGER.json changes only; executable planning tools never qualify.
#
# The post-merge ci.yml push run for SHA is mapped to the supported_toolchain,
# public_contract and package_consumer gates. The twin gate is always the fixed
# not-applicable literal and is never reported as pass.
#
# Exit codes: 0 pass | 1 regression, attribution failure or missing gate job |
#             3 inherited_red only | 75 run absent or not completed | 64 usage.
#
# Read-only: every GitHub call goes through gh_get / gh_paged, which only ever run
# `gh api <path>` with no method or field flag. Bash 3.2 and jq 1.6 compatible.

set -euo pipefail

SCHEMA="rindle-dep-landing-v1"
ACCEPT="Accept: application/vnd.github+json"
TWIN_LITERAL="not-applicable: twin not built (Phase 137)"

REPO="szTheory/rindle"
SHA=""
GROUP=""
PACKAGES=""
LOCK="mix.lock"
BASELINE_SHA=""
EVIDENCE_SHA=""
RUN_FILE=""
JOBS_FILE=""
OUT=""

usage() {
  cat >&2 <<'USAGE'
usage: dep_landing_evidence.sh --sha SHA [--group NAME --packages a,b,...] [--lock PATH]
                               [--baseline-sha SHA] [--evidence-sha SHA] [--repo OWNER/NAME] [--out FILE]
                               [--run-file FILE --jobs-file FILE]
USAGE
  exit 64
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sha) [ "$#" -ge 2 ] || usage; SHA="$2"; shift 2 ;;
    --group) [ "$#" -ge 2 ] || usage; GROUP="$2"; shift 2 ;;
    --packages) [ "$#" -ge 2 ] || usage; PACKAGES="$2"; shift 2 ;;
    --lock) [ "$#" -ge 2 ] || usage; LOCK="$2"; shift 2 ;;
    --run-file) [ "$#" -ge 2 ] || usage; RUN_FILE="$2"; shift 2 ;;
    --jobs-file) [ "$#" -ge 2 ] || usage; JOBS_FILE="$2"; shift 2 ;;
    --evidence-sha) [ "$#" -ge 2 ] || usage; EVIDENCE_SHA="$2"; shift 2 ;;
    --baseline-sha) [ "$#" -ge 2 ] || usage; BASELINE_SHA="$2"; shift 2 ;;
    --repo) [ "$#" -ge 2 ] || usage; REPO="$2"; shift 2 ;;
    --out) [ "$#" -ge 2 ] || usage; OUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "dep_landing_evidence: unknown argument: $1" >&2; usage ;;
  esac
done

# A bounded authenticated collector may pass retained GET responses to avoid a
# second credential transport. Data inputs never confer acceptance authority.
if [ -n "${RUN_FILE}" ] || [ -n "${JOBS_FILE}" ]; then
  [ -f "${RUN_FILE}" ] && [ -f "${JOBS_FILE}" ] && [ -z "${BASELINE_SHA}" ] || usage
fi

die() { echo "dep_landing_evidence: $*" >&2; exit 1; }

[ -n "${SHA}" ] || usage
case "${SHA}" in *[!0-9a-f]*) echo "dep_landing_evidence: --sha must be hex" >&2; exit 64 ;; esac
[ "${#SHA}" -ge 7 ] && [ "${#SHA}" -le 40 ] || { echo "dep_landing_evidence: --sha must be 7-40 hex chars" >&2; exit 64; }
if [ -n "${BASELINE_SHA}" ]; then
  case "${BASELINE_SHA}" in *[!0-9a-f]*|'') echo "dep_landing_evidence: --baseline-sha must be hex" >&2; exit 64 ;; esac
fi
if [ -n "${EVIDENCE_SHA}" ]; then
  case "${EVIDENCE_SHA}" in *[!0-9a-f]*) usage ;; esac
  [ "${#EVIDENCE_SHA}" -eq 40 ] || usage
fi
case "${REPO}" in */*) ;; *) echo "dep_landing_evidence: --repo must be OWNER/NAME" >&2; exit 64 ;; esac
case "${LOCK}" in
  mix.lock) MIX_EXS="mix.exs" ;;
  examples/adoption_demo/mix.lock) MIX_EXS="examples/adoption_demo/mix.exs" ;;
  *) echo "dep_landing_evidence: --lock must be mix.lock or examples/adoption_demo/mix.lock" >&2; exit 64 ;;
esac
if [ -z "${GROUP}" ] && [ -n "${PACKAGES}" ]; then
  echo "dep_landing_evidence: --packages requires --group" >&2; exit 64
fi
case "${PACKAGES}" in *[!a-z0-9_,]*) echo "dep_landing_evidence: bad --packages list" >&2; exit 64 ;; esac
case "${GROUP}" in *[!A-Za-z0-9_.-]*) echo "dep_landing_evidence: bad --group name" >&2; exit 64 ;; esac

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dep-landing.XXXXXX")"
TMP_OUT=""
cleanup() { rm -rf "${WORK}"; [ -z "${TMP_OUT}" ] || rm -f "${TMP_OUT}"; }
trap cleanup EXIT

# --- read-only GitHub access ------------------------------------------------

check_path() {
  case "$1" in
    -*|"") die "refusing unsafe gh api path: '$1'" ;;
  esac
}

gh_get() {
  check_path "$1"
  if [ -n "${RUN_FILE}" ]; then cat "${RUN_FILE}"
  else gh api -H "${ACCEPT}" "$1"; fi
}

# gh_jobs RUN_ID: every job of a run as one flat JSON array.
gh_jobs() {
  local p="repos/${REPO}/actions/runs/$1/jobs?per_page=100"
  check_path "${p}"
  if [ -n "${JOBS_FILE}" ]; then jq -e 'type == "array"' "${JOBS_FILE}" >/dev/null || die "malformed jobs input"; cat "${JOBS_FILE}"
  else gh api -H "${ACCEPT}" --paginate --slurp "${p}" | jq -S '[.[].jobs[]]'; fi
}

# --- attribution (group mode) ------------------------------------------------

FULL_SHA="${SHA}"
LOCK_DELTA='[]'
MIX_CHANGED='null'
ATTRIBUTABLE='null'

if [ -n "${GROUP}" ]; then
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
  cd "${top}"
  FULL_SHA="$(git rev-parse --verify --quiet "${SHA}^{commit}")" || die "commit ${SHA} not found locally"
  parents="$(git rev-list --parents -n 1 "${FULL_SHA}" | awk '{print NF - 1}')"
  [ "${parents}" = 1 ] || die "commit ${FULL_SHA} has ${parents} parents; a squash commit has exactly one"

  git diff "${FULL_SHA}^" "${FULL_SHA}" -- "${LOCK}" >"${WORK}/lock.diff"
  # Lines look like:  "pkg": {:hex, :pkg, "1.2.3", ...   (any other source is "non-hex")
  awk '
    /^(---|\+\+\+)/ { next }
    /^[-+] *"[A-Za-z0-9_]+": *\{/ {
      sign = substr($0, 1, 1)
      n = split($0, q, "\"")
      pkg = q[2]
      ver = ($0 ~ /\{:hex,/) ? q[4] : "non-hex"
      print sign "\t" pkg "\t" ver
    }
  ' "${WORK}/lock.diff" >"${WORK}/lock.tsv"
  LOCK_DELTA="$(jq -R -s -c '
    split("\n") | map(select(length > 0) | split("\t")) as $rows
    | [$rows[] | .[1]] | unique as $pkgs
    | [ $pkgs[] as $p
        | { package: $p,
            from: ([ $rows[] | select(.[1] == $p and .[0] == "-") | .[2] ] | first // null),
            to:   ([ $rows[] | select(.[1] == $p and .[0] == "+") | .[2] ] | first // null) } ]
  ' "${WORK}/lock.tsv")"

  if git diff --quiet "${FULL_SHA}^" "${FULL_SHA}" -- "${MIX_EXS}"; then
    MIX_CHANGED=false
  else
    MIX_CHANGED=true
  fi

  ATTRIBUTABLE="$(jq -n -c \
    --argjson delta "${LOCK_DELTA}" --arg packages "${PACKAGES}" --argjson mix "${MIX_CHANGED}" '
    ($packages | split(",") | map(select(length > 0))) as $allowed
    | ($delta | map(.package)) as $got
    | ($got | all(. as $g | $allowed | index($g) != null)) as $subset
    | (if ($allowed | length) == 0 then ($got | length) == 0 else ($got | length) > 0 end) as $shape
    | ($subset and $shape and ($mix | not))')"
fi

# A replacement run may qualify only an actual docs-only descendant. Inspect
# EVERY commit, not just the endpoint diff: a code change followed by a revert
# must not silently qualify. GitHub run identity below binds this history to REPO.
CI_SHA="${FULL_SHA}"
EQUIVALENCE='null'
if [ -n "${EVIDENCE_SHA}" ]; then
  FULL_SHA="$(git rev-parse --verify "${SHA}^{commit}")" || die "merge commit absent locally"
  CI_SHA="$(git rev-parse --verify "${EVIDENCE_SHA}^{commit}")" || die "evidence commit absent locally"
  git merge-base --is-ancestor "${FULL_SHA}" "${CI_SHA}" || die "evidence SHA is not a descendant of merge SHA"
  if [ "${CI_SHA}" != "${FULL_SHA}" ]; then
    git rev-list "${FULL_SHA}..${CI_SHA}" >"${WORK}/range"
    while IFS= read -r commit; do
      # Inspect merges against every parent as well as ordinary commits.
      git diff-tree --root -m --no-commit-id --name-only -r "${commit}" >>"${WORK}/range.files"
    done <"${WORK}/range"
    jq -R -s 'split("\n") | map(select(length > 0)) | unique' "${WORK}/range.files" >"${WORK}/range.files.json"
    jq -e 'all(.[]; test("^\\.planning/([^/]+/)*[^/]+\\.md$|^\\.planning/INBOX-LEDGER\\.json$"))' "${WORK}/range.files.json" >/dev/null \
      || die "evidence range contains changes outside planning prose/INBOX-LEDGER.json"
    EQUIVALENCE="$(jq -n --arg merge "${FULL_SHA}" --arg sha "${CI_SHA}" \
      --slurpfile files "${WORK}/range.files.json" \
      '{policy:"planning-only-descendant-v1", merge_sha:$merge, evidence_sha:$sha, changed_files:$files[0]}')"
  fi
fi

# --- post-merge run ---------------------------------------------------------

# find_run SHA OUTFILE: writes the first push run for SHA (or "null").
find_run() {
  local p="repos/${REPO}/actions/workflows/ci.yml/runs?head_sha=$1&event=push&per_page=5"
  gh_get "${p}" | jq -S '(.workflow_runs // [])[0] // null' >"$2"
}

find_run "${CI_SHA}" "${WORK}/run.json"
if [ "$(jq -r '. == null' "${WORK}/run.json")" = true ]; then
  echo "dep_landing_evidence: no ci.yml push run for ${FULL_SHA} yet" >&2
  exit 75
fi
if [ "$(jq -r '.status' "${WORK}/run.json")" != completed ]; then
  echo "dep_landing_evidence: run $(jq -r '.id' "${WORK}/run.json") is $(jq -r '.status' "${WORK}/run.json"), not completed" >&2
  exit 75
fi
jq -e --arg sha "${CI_SHA}" --arg repo "${REPO}" '
  (.head_sha == $sha or (($sha|length) < 40 and (.head_sha|startswith($sha))))
  and .event == "push" and .head_branch == "main"
  and .repository.full_name == $repo and .path == ".github/workflows/ci.yml"
' "${WORK}/run.json" >/dev/null || die "CI run identity does not match repository, push/main, workflow and evidence SHA"
gh_jobs "$(jq -r '.id' "${WORK}/run.json")" >"${WORK}/jobs.json"

echo 'null' >"${WORK}/baseline_run.json"
echo '[]' >"${WORK}/baseline_jobs.json"
if [ -n "${BASELINE_SHA}" ]; then
  find_run "${BASELINE_SHA}" "${WORK}/baseline_run_raw.json"
  if [ "$(jq -r '. == null' "${WORK}/baseline_run_raw.json")" = false ]; then
    jq -S '{id, head_sha}' "${WORK}/baseline_run_raw.json" >"${WORK}/baseline_run.json"
    gh_jobs "$(jq -r '.id' "${WORK}/baseline_run_raw.json")" >"${WORK}/baseline_jobs.json"
  fi
fi

# --- gate evaluation --------------------------------------------------------

jq -S -n \
  --arg schema "${SCHEMA}" \
  --arg sha "${FULL_SHA}" \
  --arg evidence_sha "${CI_SHA}" \
  --argjson equivalence "${EQUIVALENCE}" \
  --arg group "${GROUP}" \
  --arg lock "${LOCK}" \
  --arg twin "${TWIN_LITERAL}" \
  --argjson lock_delta "${LOCK_DELTA}" \
  --argjson mix_exs_changed "${MIX_CHANGED}" \
  --argjson attributable "${ATTRIBUTABLE}" \
  --slurpfile run "${WORK}/run.json" \
  --slurpfile baseline_run "${WORK}/baseline_run.json" \
  --slurpfile jobs "${WORK}/jobs.json" \
  --slurpfile bjobs "${WORK}/baseline_jobs.json" '
  def gate_defs: [
    {gate: "supported_toolchain",
     exact: [], prefix: ["Quality (", "ADMIN-06 Optional Dependencies ("]},
    {gate: "public_contract",
     exact: ["Contract", "Proof", "Integration", "CI Script Tests"], prefix: []},
    {gate: "package_consumer",
     exact: ["Package Consumer Proof Matrix + Release Preflight", "Adopter", "Adoption Demo Unit",
             "Adoption Demo E2E Smoke", "Cohort Demo Smoke", "Adoption Demo E2E"],
     prefix: ["Package Consumer Full Matrix + Release Preflight ("]}
  ];
  def in_gate($g; $name):
    ($g.exact | index($name) != null) or ($g.prefix | map(. as $p | $name | startswith($p)) | any);
  def gate_of($name):
    ([gate_defs[] | select(in_gate(.; $name)) | .gate] | first // null);

  $jobs[0] as $J
  | $bjobs[0] as $B
  | ($baseline_run[0]) as $brun
  | ($run[0]) as $r
  | ($J | map(
      . as $j
      | gate_of($j.name) as $g
      | ($B | map(select(.name == $j.name)) | first // null) as $bj
      | { name: $j.name,
          conclusion: ($j.conclusion // "null"),
          gate: $g,
          baseline_conclusion: (if $bj == null then null else ($bj.conclusion // "null") end),
          class: (if $g == null then "n/a"
                  elif $j.conclusion == "success" then "ok"
                  elif $brun != null and $bj != null and $bj.conclusion == "success" then "regression"
                  elif $brun != null then "inherited_red"
                  else "regression" end) }
    )) as $jl
  | (gate_defs | map(
      . as $g
      | ($g.exact | map(. as $e | $jl | map(select(.name == $e)) | length == 0) | any) as $miss_exact
      | ($g.prefix | map(. as $p | $jl | map(select(.name | startswith($p))) | length == 0) | any) as $miss_prefix
      | ($jl | map(select(.gate == $g.gate))) as $gj
      | { key: $g.gate,
          value: (if $miss_exact or $miss_prefix then "missing"
                  elif ($gj | map(.class) | index("regression")) != null then "fail"
                  elif ($gj | map(.class) | index("inherited_red")) != null then "inherited_red"
                  else "pass" end) }
    ) | from_entries) as $gates
  | ([$gates[]] ) as $gv
  | { schema: $schema,
      sha: $sha,
      evidence_sha: $evidence_sha,
      equivalence: $equivalence,
      group: (if $group == "" then null else $group end),
      lock: $lock,
      lock_delta: $lock_delta,
      mix_exs_changed: $mix_exs_changed,
      attributable: $attributable,
      run: ($r | {id, head_sha, event, status, conclusion}),
      baseline_run: $brun,
      gates: ($gates + {twin: $twin}),
      jobs: $jl,
      verdict: (if $attributable == false then "attribution_failed"
                elif ($gv | index("missing")) != null then "missing_gate"
                elif ($gv | index("fail")) != null then "regression"
                elif ($gv | index("inherited_red")) != null then "inherited_red"
                else "pass" end) }
' >"${WORK}/evidence.json"

OUT_DIR="."
if [ -n "${OUT}" ]; then
  OUT_DIR="$(dirname "${OUT}")"
  mkdir -p "${OUT_DIR}"
  TMP_OUT="$(mktemp "${OUT_DIR}/.dep-landing.XXXXXX")"
  cp "${WORK}/evidence.json" "${TMP_OUT}"
  mv "${TMP_OUT}" "${OUT}"
  TMP_OUT=""
else
  cat "${WORK}/evidence.json"
fi

verdict="$(jq -r '.verdict' "${WORK}/evidence.json")"
case "${verdict}" in
  pass) exit 0 ;;
  inherited_red) exit 3 ;;
  *) exit 1 ;;
esac
