#!/usr/bin/env bash
# validate_readability_trace.sh - validator for scripts/maintainer/readability_changes.json.
#
# Every readability change must trace to a candidate in the frozen quality candidate ledger
# and must remove a real identity from the Credo complexity baseline. The ledger identity
# (subject sha, file sha256 and the 12 candidate ids) is pinned as constants below, so
# editing only the trace JSON can never change what counts as a valid candidate.
#
# Modes:
#   --offline            shape and traceability against the --baseline file only.
#   --base REF           as --offline, plus every change anchor must have been present in
#                        REF's scripts/maintainer/credo_complexity_baseline.json (read with
#                        `git show` from the current working directory's repository).
#   --verify-source PATH maintainer-only: compares `shasum -a 256 PATH` to the pinned sha256.
#                        CI never runs this mode and no default PATH is built in.
#
# Usage:
#   validate_readability_trace.sh --trace FILE --baseline FILE (--offline | --base REF)
#   validate_readability_trace.sh --verify-source PATH --trace FILE
#
# Exit codes: 0 valid | 1 rejected (each reason on stderr, prefixed REJECT:) | 64 usage.
#
# Safety: every rule is evaluated by jq. Trace and baseline values reach jq only through
# --slurpfile / --arg / --argjson; nothing from either file is ever executed as code.
# Bash 3.2 and jq 1.6 compatible.

set -euo pipefail

PINNED_SUBJECT_SHA="3858267b4837d04367f1d26b1ee74651e507ea77"
PINNED_SHA256="a56c8b6e68e68a84c1355247359733e60be9596a6582a4525488b5d23880bde4"
PINNED_IDS='[
  "quality-ci-required-topology",
  "quality-compatibility-supported-toolchain",
  "quality-correctness-default-suite",
  "quality-documentation-accessibility",
  "quality-maintainability-curated-complexity",
  "quality-packaging-generated-consumer",
  "quality-performance-required-pr-timing",
  "quality-release-exact-sha",
  "quality-reliability-nightly",
  "quality-repository-hygiene",
  "quality-security-dependency-policy",
  "quality-testing-automation-first"
]'
BASELINE_REL="scripts/maintainer/credo_complexity_baseline.json"

TRACE=""
BASELINE=""
BASE_REF=""
OFFLINE=false
VERIFY_SOURCE=""

usage() {
  cat >&2 <<'USAGE'
usage: validate_readability_trace.sh --trace FILE --baseline FILE (--offline | --base REF)
       validate_readability_trace.sh --verify-source PATH --trace FILE
USAGE
  exit 64
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --trace) [ "$#" -ge 2 ] || usage; TRACE="$2"; shift 2 ;;
    --baseline) [ "$#" -ge 2 ] || usage; BASELINE="$2"; shift 2 ;;
    --base) [ "$#" -ge 2 ] || usage; BASE_REF="$2"; shift 2 ;;
    --offline) OFFLINE=true; shift ;;
    --verify-source) [ "$#" -ge 2 ] || usage; VERIFY_SOURCE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "validate_readability_trace: unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "${TRACE}" ] || usage

if [ ! -f "${TRACE}" ] || ! jq -e . "${TRACE}" >/dev/null 2>&1; then
  echo "REJECT: unreadable: trace ${TRACE} is missing or not valid JSON" >&2
  exit 1
fi

# --- maintainer-only source check ---------------------------------------------------------
if [ -n "${VERIFY_SOURCE}" ]; then
  if [ "${OFFLINE}" = true ] || [ -n "${BASE_REF}" ] || [ -n "${BASELINE}" ]; then usage; fi
  if [ ! -f "${VERIFY_SOURCE}" ]; then
    echo "REJECT: unreadable: source ${VERIFY_SOURCE} is missing" >&2
    exit 1
  fi
  actual="$(shasum -a 256 -- "${VERIFY_SOURCE}" | awk '{print $1}')"
  recorded="$(jq -r '.candidate_ledger.sha256? // ""' "${TRACE}")"
  rc=0
  if [ "${actual}" != "${PINNED_SHA256}" ]; then
    echo "REJECT: source sha256: ${VERIFY_SOURCE} hashes to ${actual}, pinned ${PINNED_SHA256}" >&2
    rc=1
  fi
  if [ "${recorded}" != "${PINNED_SHA256}" ]; then
    echo "REJECT: ledger identity: trace sha256 ${recorded} differs from pinned ${PINNED_SHA256}" >&2
    rc=1
  fi
  [ "${rc}" -eq 0 ] && echo "validate_readability_trace: ok (verify-source)"
  exit "${rc}"
fi

# --- trace checks -------------------------------------------------------------------------
[ -n "${BASELINE}" ] || usage
if [ "${OFFLINE}" = true ] && [ -n "${BASE_REF}" ]; then usage; fi
if [ "${OFFLINE}" = false ] && [ -z "${BASE_REF}" ]; then usage; fi

if [ ! -f "${BASELINE}" ] || ! jq -e . "${BASELINE}" >/dev/null 2>&1; then
  echo "REJECT: unreadable: baseline ${BASELINE} is missing or not valid JSON" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

MODE=offline
BASE_FILE="${TMP}/base.json"
printf '%s\n' '{"entries": []}' >"${BASE_FILE}"
if [ -n "${BASE_REF}" ]; then
  MODE=base
  if ! git show "${BASE_REF}:${BASELINE_REL}" >"${BASE_FILE}" 2>"${TMP}/git.err"; then
    echo "REJECT: base: cannot read ${BASELINE_REL} at ${BASE_REF}: $(tr '\n' ' ' <"${TMP}/git.err")" >&2
    exit 1
  fi
  if ! jq -e . "${BASE_FILE}" >/dev/null 2>&1; then
    echo "REJECT: base: ${BASELINE_REL} at ${BASE_REF} is not valid JSON" >&2
    exit 1
  fi
fi

read -r -d '' PROG <<'JQ' || true
def R($k; $m): "REJECT: \($k): \($m)";
def nestr: type == "string" and (test("^\\s*$") | not);
def nestrs: type == "array" and length > 0 and all(.[]; nestr);
def obj: if type == "object" then . else {} end;
def ident: {check: .check, file: .file, trigger: .trigger, observed_metric: .observed_metric};
def entries: (obj | .entries) as $e | if ($e | type) == "array" then [$e[] | select(type == "object") | ident] else [] end;
def intents: ["naming", "cohesion", "ownership", "failure-semantics"];

def ledger($T):
  ($T.candidate_ledger | obj) as $L
  | (if $T.schema == "rindle-readability-changes-v1" then empty
     else R("schema"; "expected rindle-readability-changes-v1, got \($T.schema | tojson)") end),
    (if $L.subject_sha == $sha then empty
     else R("ledger identity"; "subject_sha \($L.subject_sha | tojson) differs from the pinned \($sha)") end),
    (if $L.sha256 == $sum then empty
     else R("ledger identity"; "sha256 \($L.sha256 | tojson) differs from the pinned \($sum)") end),
    (if ($L.candidate_ids | type) == "array" and ($L.candidate_ids | sort) == ($ids | sort) then empty
     else R("ledger identity"; "candidate_ids differ from the 12 pinned ids") end);

def change($i; $B; $P):
  (if type == "object" then . else {} end) as $c
  | ("change[\($i)] \($c.id // "?" | tojson)") as $at
  | (if ($c.id | nestr) then empty else R("id"; "\($at) needs a non-empty string id") end),
    (if ($c.candidate_id | type) == "string" and ($ids | index([$c.candidate_id])) != null then empty
     else R("candidate"; "\($at) candidate_id \($c.candidate_id | tojson) is not a pinned candidate id") end),
    (if ($c.detector | nestr) then empty else R("detector"; "\($at) needs a non-empty detector") end),
    (if ($c.intent | type) == "string" and (intents | index([$c.intent])) != null then empty
     else R("intent"; "\($at) intent \($c.intent | tojson) is not one of \(intents | join("|"))") end),
    (if ($c.files | nestrs) then empty else R("files"; "\($at) needs a non-empty list of file paths") end),
    (if ($c.proof | nestrs) then empty else R("proof"; "\($at) needs a non-empty list of proof commands") end),
    (if $c.pr == null or (($c.pr | type) == "number" and $c.pr == ($c.pr | floor) and $c.pr > 0) then empty
     else R("pr"; "\($at) pr must be a positive integer or null") end),
    (($c.anchor) as $a
     | if ($a | type) != "object"
          or (($a.check | nestr) and ($a.file | nestr) and ($a.trigger | nestr)
              and (($a.observed_metric | type) == "number") | not) then
         R("anchor"; "\($at) anchor needs check, file, trigger and a numeric observed_metric")
       else
         ($a | ident) as $id
         | (if ($B | index([$id])) != null then
              R("anchor present"; "\($at) anchor \($id | tojson) is still in the complexity baseline")
            else empty end),
           (if $mode == "base" and ($P | index([$id])) == null then
              R("anchor not in base"; "\($at) anchor \($id | tojson) was not in the base complexity baseline")
            else empty end)
       end);

$t[0] as $T
| ($b[0] | entries) as $B
| ($p[0] | entries) as $P
| [
    ledger($T),
    (if ($T.changes | type) != "array" then R("changes"; "changes must be an array")
     else
       ($T.changes | to_entries[] | .key as $i | .value | change($i; $B; $P)),
       ([$T.changes[] | select(type == "object") | .id | select(type == "string")]
        | group_by(.) | map(select(length > 1) | .[0])[]
        | R("duplicate id"; "change id \(tojson) appears more than once"))
     end)
  ][]
JQ

if ! OUT=$(jq -n -r --slurpfile t "${TRACE}" --slurpfile b "${BASELINE}" --slurpfile p "${BASE_FILE}" \
      --arg mode "${MODE}" --arg sha "${PINNED_SUBJECT_SHA}" --arg sum "${PINNED_SHA256}" \
      --argjson ids "${PINNED_IDS}" \
      "${PROG}" 2>&1); then
  echo "REJECT: internal: validator could not evaluate the trace: ${OUT}" >&2
  exit 1
fi

if [ -n "${OUT}" ]; then
  printf '%s\n' "${OUT}" >&2
  exit 1
fi

echo "validate_readability_trace: ok (${MODE})"
exit 0
