#!/usr/bin/env bash
# validate_artifact_ledger.sh - artifact ledger partition validator.
#
# Checks scripts/maintainer/artifact_ledger.json (schema rindle-artifact-ledger-v1) against
# the git index of a checkout:
#   - every tracked path is matched by exactly one ledger class (no uncovered path, no
#     double-classified path, no class that matches nothing)
#
# Usage:
#   validate_artifact_ledger.sh --ledger FILE --offline [--root DIR]
#
# Exit codes: 0 valid | 1 rejected (each reason on stderr, prefixed REJECT:, sorted) | 64 usage.
#
# Safety: the validator is read-only. It writes only under its own mktemp directory, removed
# on exit. Pathspecs reach git as separate argv entries after `--`; every other ledger value
# reaches jq only through --slurpfile / --arg. Nothing from the ledger is ever executed.
# Bash 3.2 and jq 1.6 compatible (no mapfile, no jq 1.7-only builtins).

set -euo pipefail

LEDGER=""
OFFLINE=false
ROOT_DIR="."

usage() {
  cat >&2 <<'USAGE'
usage: validate_artifact_ledger.sh --ledger FILE --offline [--root DIR]
USAGE
  exit 64
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --ledger) [ "$#" -ge 2 ] || usage; LEDGER="$2"; shift 2 ;;
    --root) [ "$#" -ge 2 ] || usage; ROOT_DIR="$2"; shift 2 ;;
    --offline) OFFLINE=true; shift ;;
    -h|--help) usage ;;
    *) echo "validate_artifact_ledger: unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "${LEDGER}" ] || usage
[ "${OFFLINE}" = true ] || usage

if [ ! -f "${LEDGER}" ] || ! jq -e 'type == "object"' "${LEDGER}" >/dev/null 2>&1; then
  echo "REJECT: unreadable: ledger ${LEDGER} is missing or not a JSON object" >&2
  exit 1
fi

if ! git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "validate_artifact_ledger: --root ${ROOT_DIR} is not a git work tree" >&2
  exit 64
fi

# Pathspec interpretation must not depend on the caller's environment.
unset GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS

WORK="$(mktemp -d "${TMPDIR:-/tmp}/artifact-ledger.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

g() { git -C "${ROOT_DIR}" -c core.quotePath=false "$@"; }

# NUL-separated git output -> JSON array of strings.
nul_to_json() { tr '\0' '\n' | jq -R -s 'split("\n") | map(select(length > 0))'; }

# --- tracked set ---------------------------------------------------------------------------
g ls-files -z | nul_to_json >"${WORK}/tracked.json"

# --- per-class matches ---------------------------------------------------------------------
# One JSON object per class index: {"i": N, "paths": [...]}. Classes without a usable pathspec
# list are not passed to git (an empty argv would match the whole tree); jq rejects them.
: >"${WORK}/matches.jsonl"
N_CLASSES="$(jq -r 'if (.classes | type) == "array" then (.classes | length) else 0 end' "${LEDGER}")"
i=0
while [ "${i}" -lt "${N_CLASSES}" ]; do
  specs=()
  while IFS= read -r -d '' spec; do
    specs+=("${spec}")
  done < <(jq -j --argjson i "${i}" '
    .classes[$i] | if type == "object" and (.pathspecs | type) == "array"
                      and (.pathspecs | length) > 0
                      and all(.pathspecs[]; type == "string" and length > 0)
                      and any(.pathspecs[]; test("^:(\\([^)]*exclude|[!^])") | not)
                   then .pathspecs[] + "\u0000" else empty end' "${LEDGER}")
  if [ "${#specs[@]}" -gt 0 ]; then
    g ls-files -z -- "${specs[@]}" | nul_to_json \
      | jq -c --argjson i "${i}" '{i: $i, paths: .}' >>"${WORK}/matches.jsonl"
  else
    jq -n -c --argjson i "${i}" '{i: $i, paths: [], unusable: true}' >>"${WORK}/matches.jsonl"
  fi
  i=$((i + 1))
done

read -r -d '' PROG <<'JQ' || true
def R($k; $m): "REJECT: \($k): \($m)";
def nestr: type == "string" and (test("^\\s*$") | not);
def cid: if (.id | nestr) then .id else "<unnamed>" end;

$l[0] as $L
| $t[0] as $T
| ($m | map({key: (.i | tostring), value: .}) | from_entries) as $M
| (if ($L.classes | type) == "array" then $L.classes else [] end) as $C
| [
    # schema and class list
    (if $L.schema != "rindle-artifact-ledger-v1" then R("schema"; "schema must be rindle-artifact-ledger-v1") else empty end),
    (if ($L.classes | type) != "array" or ($C | length) == 0 then R("classes"; "ledger has no classes") else empty end),

    # class identity and pathspecs
    ($C | to_entries[] | .key as $i | .value as $c
      | if ($c | type) != "object" then R("class"; "classes[\($i)] is not an object")
        else
          ( (if ($c.id | nestr) | not then R("class"; "classes[\($i)] needs a non-empty id") else empty end),
            (if $M[$i | tostring].unusable then
               R("pathspecs"; "class \($c | cid) needs a non-empty pathspecs list of non-empty strings with at least one non-exclude pathspec")
             else empty end),
            # git does not combine an exclude pathspec that starts with a wildcard
            # (":(glob,exclude)**/x") reliably with other pathspecs: anchor it instead.
            ($c.pathspecs | if type == "array" then .[] else empty end | select(type == "string")
              | select(test("^:(\\([^)]*exclude[^)]*\\)|[!^])"))
              | select(sub("^:(\\([^)]*\\)|[!^]+)"; "") | test("^[*?\\[]"))
              | R("pathspecs"; "class \($c | cid): exclude pathspec \(.) must start with a literal path")) )
        end),
    ([$C[] | select(type == "object") | .id | select(nestr)] | group_by(.) | map(select(length > 1) | .[0])[]
      | R("duplicate class id"; .)),

    # stale classes
    ($C | to_entries[] | .key as $i | .value as $c
      | select(($c | type) == "object" and ($M[$i | tostring].unusable | not))
      | select(($M[$i | tostring].paths | length) == 0)
      | R("stale class"; "\($c | cid) matches no tracked file")),

    # partition: every tracked path in exactly one class
    ( [ $m[] | .i as $i | .paths[] | {p: ., c: ($C[$i] | cid)} ]
      | group_by(.p) | map({key: .[0].p, value: map(.c)}) | from_entries ) as $owners
    | ( ($T[] | select($owners[.] == null) | R("uncovered"; .)),
        ($owners | to_entries[] | select((.value | length) > 1)
          | R("double-classified"; "\(.key) (\(.value | join(", ")))")) )
  ]
| unique
| .[]
JQ

if ! OUT=$(jq -n -r --slurpfile l "${LEDGER}" --slurpfile t "${WORK}/tracked.json" \
      --slurpfile m "${WORK}/matches.jsonl" "${PROG}" 2>&1); then
  echo "REJECT: internal: validator could not evaluate the ledger: ${OUT}" >&2
  exit 1
fi

if [ -n "${OUT}" ]; then
  printf '%s\n' "${OUT}" >&2
  exit 1
fi

echo "validate_artifact_ledger: ok (offline, $(jq 'length' "${WORK}/tracked.json") files, ${N_CLASSES} classes)"
exit 0
