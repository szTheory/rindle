#!/usr/bin/env bash
# validate_artifact_ledger.sh - artifact ledger validator.
#
# Checks scripts/maintainer/artifact_ledger.json (schema rindle-artifact-ledger-v1) against
# the git index and work tree of a checkout:
#   partition   every tracked path is matched by exactly one class; no class matches nothing
#   fields      authority, consumer (tracked paths), package, disposition and reason per class;
#               regenerate exactly when authority is generated; hygiene drift commands come
#               only from the vetted set pinned below
#   receipt     a class with retained_receipt that matches nothing reports the receipt by name
#   package     shipped classes equal the tracked files under the mix.exs package files list
#   ignore      every effective .gitignore line is recorded once; no tracked file is ignored
#   junk        no tracked file matches tracked_junk_patterns
#   roots       every verification_ignored_roots entry is covered by a .gitignore rule
#   settled     with --require-settled, no class may still have disposition delete
#
# Usage:
#   validate_artifact_ledger.sh --offline [--ledger FILE] [--require-settled] [--root DIR]
#
# --ledger defaults to scripts/maintainer/artifact_ledger.json under --root (default: .).
#
# Exit codes: 0 valid | 1 rejected (each reason on stderr, prefixed REJECT:, sorted) | 64 usage.
#
# Safety: the validator is read-only. It writes only under its own mktemp directory, removed
# on exit. Pathspecs reach git as separate argv entries after `--`; every other ledger value
# reaches jq only through --slurpfile / --arg. Regenerate commands are compared as data and
# never executed. Bash 3.2 and jq 1.6 compatible (no mapfile, no jq 1.7-only builtins).

set -euo pipefail

LEDGER=""
OFFLINE=false
REQUIRE_SETTLED=false
ROOT_DIR="."

usage() {
  cat >&2 <<'USAGE'
usage: validate_artifact_ledger.sh --offline [--ledger FILE] [--require-settled] [--root DIR]
USAGE
  exit 64
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --ledger) [ "$#" -ge 2 ] || usage; LEDGER="$2"; shift 2 ;;
    --root) [ "$#" -ge 2 ] || usage; ROOT_DIR="$2"; shift 2 ;;
    --offline) OFFLINE=true; shift ;;
    --require-settled) REQUIRE_SETTLED=true; shift ;;
    -h|--help) usage ;;
    *) echo "validate_artifact_ledger: unknown argument: $1" >&2; usage ;;
  esac
done

[ "${OFFLINE}" = true ] || usage
[ -n "${LEDGER}" ] || LEDGER="${ROOT_DIR}/scripts/maintainer/artifact_ledger.json"

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

# Machine-local ignore sources (core.excludesFile) never count: only tracked .gitignore files.
g() { git -C "${ROOT_DIR}" -c core.quotePath=false -c core.excludesFile=/dev/null "$@"; }

# NUL-separated git output -> JSON array of strings.
nul_to_json() { tr '\0' '\n' | jq -R -s 'split("\n") | map(select(length > 0))'; }

# A usable pathspec is a non-empty single-line string; a usable list has at least one
# pathspec that is not an exclude (an exclude-only list matches the whole tree).
JQ_USABLE='def isexcl: test("^:(\\([^)]*exclude|[!^])");
           def usable: type == "array" and length > 0
                       and all(.[]; type == "string" and length > 0 and (test("\n") | not))
                       and any(.[]; isexcl | not);'

# --- tracked set ----------------------------------------------------------------------------
g ls-files -z | nul_to_json >"${WORK}/tracked.json"

# --- per-class matches ----------------------------------------------------------------------
# One JSON object per class index: {"i": N, "paths": [...]}. Unusable pathspec lists are never
# passed to git; jq rejects them.
: >"${WORK}/matches.jsonl"
N_CLASSES="$(jq -r 'if (.classes | type) == "array" then (.classes | length) else 0 end' "${LEDGER}")"
i=0
while [ "${i}" -lt "${N_CLASSES}" ]; do
  specs=()
  while IFS= read -r spec; do
    specs+=("${spec}")
  done < <(jq -r --argjson i "${i}" "${JQ_USABLE}"'
    .classes[$i] | if type == "object" and (.pathspecs | usable) then .pathspecs[] else empty end' "${LEDGER}")
  if [ "${#specs[@]}" -gt 0 ]; then
    g ls-files -z -- "${specs[@]}" | nul_to_json \
      | jq -c --argjson i "${i}" '{i: $i, paths: .}' >>"${WORK}/matches.jsonl"
  else
    jq -n -c --argjson i "${i}" '{i: $i, paths: [], unusable: true}' >>"${WORK}/matches.jsonl"
  fi
  i=$((i + 1))
done

# --- tracked junk ---------------------------------------------------------------------------
: >"${WORK}/junk.jsonl"
N_JUNK="$(jq -r 'if (.tracked_junk_patterns | type) == "array" then (.tracked_junk_patterns | length) else 0 end' "${LEDGER}")"
i=0
while [ "${i}" -lt "${N_JUNK}" ]; do
  pat="$(jq -r --argjson i "${i}" "${JQ_USABLE}"'
    .tracked_junk_patterns[$i] | if ([.] | usable) then . else "" end' "${LEDGER}")"
  if [ -n "${pat}" ]; then
    g ls-files -z -- "${pat}" | nul_to_json \
      | jq -c --argjson i "${i}" '{i: $i, paths: .}' >>"${WORK}/junk.jsonl"
  else
    jq -n -c --argjson i "${i}" '{i: $i, paths: [], unusable: true}' >>"${WORK}/junk.jsonl"
  fi
  i=$((i + 1))
done

# --- mix.exs package files list -------------------------------------------------------------
# Parsed with sed from the `files:` keyword list; a parse failure is reported, never a pass.
PREFIXES=""
if [ -f "${ROOT_DIR}/mix.exs" ]; then
  PREFIXES="$(awk '/(^|[^A-Za-z_])files:/ { f = 1 } f { print } f && /\)/ { exit }' "${ROOT_DIR}/mix.exs" \
    | tr '\n' ' ' | sed -n 's/.*files:[[:space:]]*~w(\([^)]*\)).*/\1/p')"
fi
: >"${WORK}/prefixes.txt"
for p in ${PREFIXES}; do printf '%s\n' "${p}" >>"${WORK}/prefixes.txt"; done
jq -R -s 'split("\n") | map(select(length > 0))' "${WORK}/prefixes.txt" >"${WORK}/prefixes.json"
if [ -s "${WORK}/prefixes.txt" ] && ! grep -q '[][*?{}]' "${WORK}/prefixes.txt"; then
  lit=()
  while IFS= read -r p; do lit+=(":(literal)${p}"); done <"${WORK}/prefixes.txt"
  g ls-files -z -- "${lit[@]}" | nul_to_json >"${WORK}/shipped.json"
else
  echo '[]' >"${WORK}/shipped.json"
fi

# --- tracked .gitignore effective rules -----------------------------------------------------
: >"${WORK}/effective.jsonl"
while IFS= read -r gi; do
  [ -f "${ROOT_DIR}/${gi}" ] || continue
  awk 'NF > 0 && $0 !~ /^#/' "${ROOT_DIR}/${gi}" \
    | jq -R -c --arg file "${gi}" '{file: $file, rule: .}' >>"${WORK}/effective.jsonl"
done < <(jq -r '.[] | select(. == ".gitignore" or endswith("/.gitignore"))' "${WORK}/tracked.json")

# --- tracked files that an ignore rule matches ----------------------------------------------
g ls-files -z -c -i --exclude-per-directory=.gitignore | nul_to_json >"${WORK}/tracked_ignored.json"

# --- verification ignored roots -------------------------------------------------------------
: >"${WORK}/roots.jsonl"
N_ROOTS="$(jq -r 'if (.verification_ignored_roots | type) == "array" then (.verification_ignored_roots | length) else 0 end' "${LEDGER}")"
i=0
while [ "${i}" -lt "${N_ROOTS}" ]; do
  r="$(jq -r --argjson i "${i}" '.verification_ignored_roots[$i]
        | if type == "string" and length > 0 and (test("\n|^/|(^|/)\\.\\.(/|$)") | not) then . else "" end' "${LEDGER}")"
  covered=false
  if [ -n "${r}" ]; then
    # -v names the deciding pattern; a negation or a non-.gitignore source does not count.
    line="$(g check-ignore -v --no-index -- "${r}" 2>/dev/null || true)"
    if [ -n "${line}" ]; then
      src="${line%%:*}"
      rest="${line#*:}"
      rest="${rest#*:}"
      pattern="${rest%%	*}"
      case "${src}" in
        .gitignore|*/.gitignore) case "${pattern}" in '!'*) ;; *) covered=true ;; esac ;;
      esac
    fi
  fi
  jq -n -c --argjson i "${i}" --argjson ok "$([ -n "${r}" ] && echo true || echo false)" \
    --argjson covered "${covered}" '{i: $i, usable: $ok, covered: $covered}' >>"${WORK}/roots.jsonl"
  i=$((i + 1))
done

read -r -d '' PROG <<'JQ' || true
def R($k; $m): "REJECT: \($k): \($m)";
def nestr: type == "string" and (test("^\\s*$") | not);
def cid: if (.id | nestr) then .id else "<unnamed>" end;
def arr: if type == "array" then . else [] end;

# Hygiene may run only these generator commands; anything else is rejected as data.
def vetted: ["node brandbook/src/tokens-build.mjs",
             "node brandbook/src/admin-css-build.mjs",
             "node brandbook/src/sync-admin-css.mjs"];
def authorities: ["hand-authored", "generated", "tool-lockfile", "history",
                  "immutable-receipt", "third-party", "fixture", "agent-tooling"];

$l[0] as $L
| $t[0] as $T
| ($T | map({key: ., value: true}) | from_entries) as $TS
| ($m | map({key: (.i | tostring), value: .}) | from_entries) as $M
| ($L.classes | arr) as $C
| $sh[0] as $SH
| ($SH | map({key: ., value: true}) | from_entries) as $SHS
| ( [ $m[] | .i as $i | .paths[] | {p: ., c: ($C[$i] | cid)} ]
    | group_by(.p) | map({key: .[0].p, value: map(.c)}) | from_entries ) as $owners
| [
    # schema and top-level shape
    (if $L.schema != "rindle-artifact-ledger-v1" then R("schema"; "schema must be rindle-artifact-ledger-v1") else empty end),
    (if ($L.classes | type) != "array" or ($C | length) == 0 then R("classes"; "ledger has no classes") else empty end),
    (["ignore_rules", "tracked_junk_patterns", "verification_ignored_roots"][] as $k
      | select(($L[$k] | type) != "array") | R("schema"; "\($k) must be an array")),

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
            ($c.pathspecs | arr | .[] | select(type == "string")
              | select(test("^:(\\([^)]*exclude[^)]*\\)|[!^])"))
              | select(sub("^:(\\([^)]*\\)|[!^]+)"; "") | test("^[*?\\[]"))
              | R("pathspecs"; "class \($c | cid): exclude pathspec \(.) must start with a literal path")) )
        end),
    ([$C[] | select(type == "object") | .id | select(nestr)] | group_by(.) | map(select(length > 1) | .[0])[]
      | R("duplicate class id"; .)),

    # class fields
    ($C[] | select(type == "object") | . as $c | ($c | cid) as $id
      | ( (if ($c.authority | IN(authorities[])) | not then R("authority"; "class \($id): authority must be one of \(authorities | join(", "))") else empty end),
          (if ($c.package | IN("shipped", "excluded")) | not then R("package"; "class \($id): package must be shipped or excluded") else empty end),
          (if ($c.disposition | IN("retain", "delete", "ignore")) | not then R("disposition"; "class \($id): disposition must be retain, delete or ignore") else empty end),
          (if ($c.reason | nestr) | not then R("reason"; "class \($id): reason is required") else empty end),
          (if ($c.consumer | type) != "array" then R("consumer"; "class \($id): consumer must be a list of tracked paths")
           elif ($c.consumer | length) == 0 and $c.disposition != "delete" then R("consumer"; "class \($id): consumer is empty")
           else ($c.consumer[] | if (type == "string" and $TS[.] == true) then empty
                                 else R("consumer"; "class \($id): \(tojson) is not a tracked path") end) end),

          # regenerate exactly when generated
          (if $c.authority == "generated" and ($c | has("regenerate") | not) then R("regenerate"; "class \($id): generated class needs regenerate")
           elif $c.authority != "generated" and ($c | has("regenerate")) then R("regenerate"; "class \($id): regenerate is only for generated classes")
           elif ($c | has("regenerate")) then
             ($c.regenerate as $g
              | if ($g | type) != "object" then R("regenerate"; "class \($id): regenerate must be an object")
                else
                  ( (if ($g.commands | type) != "array" or ($g.commands | length) == 0 or (all($g.commands[]; nestr) | not)
                     then R("regenerate"; "class \($id): commands must be a non-empty list of strings") else empty end),
                    (if ($g.drift_paths | type) != "array" or ($g.drift_paths | length) == 0
                     then R("regenerate"; "class \($id): drift_paths must be a non-empty list")
                     else ($g.drift_paths[] | select((type == "string" and $TS[.] == true) | not)
                           | R("regenerate"; "class \($id): drift path \(tojson) is not tracked")) end),
                    (if $g.drift_check == "hygiene" then
                       ($g.commands | arr | .[] | select((IN(vetted[])) | not)
                        | R("regenerate"; "class \($id): \(tojson) is not a vetted hygiene command"))
                     elif $g.drift_check == "none" then
                       (if ($g.reason | nestr) | not then R("regenerate"; "class \($id): drift_check none needs a reason") else empty end)
                     else R("regenerate"; "class \($id): drift_check must be hygiene or none") end) )
                end)
           else empty end),

          # retained receipt shape
          (if ($c | has("retained_receipt")) then
             (if ($c.retained_receipt | type) != "object" or (($c.retained_receipt.root | nestr) | not)
                 or (($c.retained_receipt.identity | nestr) | not)
              then R("retained_receipt"; "class \($id): retained_receipt needs a root and an identity") else empty end),
             (if $c.authority != "immutable-receipt" or $c.disposition != "retain"
              then R("retained_receipt"; "class \($id): retained_receipt needs authority immutable-receipt and disposition retain") else empty end)
           else empty end) )),

    # stale classes; a retained receipt that matches nothing names the receipt instead
    ($C | to_entries[] | .key as $i | .value as $c
      | select(($c | type) == "object" and ($M[$i | tostring].unusable | not))
      | select(($M[$i | tostring].paths | length) == 0)
      | if ($c.retained_receipt | type) == "object" and ($c.retained_receipt.root | nestr)
           and ($c.retained_receipt.identity | nestr) then
          R("retained receipt"; "\($c.retained_receipt.root) must not be archived (\($c.retained_receipt.identity))")
        else R("stale class"; "\($c | cid) matches no tracked file") end),

    # partition: every tracked path in exactly one class
    ($T[] | select($owners[.] == null) | R("uncovered"; .)),
    ($owners | to_entries[] | select((.value | length) > 1)
      | R("double-classified"; "\(.key) (\(.value | join(", ")))")),

    # package: shipped classes equal the mix.exs files list
    (if ($pre[0] | length) == 0 then R("package"; "cannot read the files list from mix.exs")
     elif any($pre[0][]; test("[\\[\\]*?{}]")) then R("package"; "mix.exs files list uses a wildcard; list literal paths")
     else
       ($C | to_entries[] | .key as $i | .value as $c | select(($c | type) == "object")
        | ($M[$i | tostring].paths // [])[] as $p
        | if $c.package == "shipped" and $SHS[$p] != true then
            R("package"; "\($p) is in shipped class \($c | cid) but outside the mix.exs files list")
          elif $c.package != "shipped" and $SHS[$p] == true then
            R("package"; "\($p) is inside the mix.exs files list but class \($c | cid) is not shipped")
          else empty end)
     end),

    # ignore rules
    ($L.ignore_rules | arr | to_entries[] | .key as $i | .value as $r
      | if ($r | type) != "object" or (($r.file | nestr) | not) or (($r.rule | type) != "string")
          then R("ignore rule"; "ignore_rules[\($i)] needs file and rule")
        else
          ( (if ($r.produced_by | nestr) | not then R("ignore rule"; "\($r.file): \($r.rule): produced_by is required") else empty end),
            (if $r.disposition != "ignore" then R("ignore rule"; "\($r.file): \($r.rule): disposition must be ignore") else empty end) )
        end),
    ( ($e | map({file, rule})) as $E
      | ($L.ignore_rules | arr | map(select(type == "object") | {file, rule})) as $IR
      | ( ($E | group_by([.file, .rule])[] | select(length > 1) | .[0]
            | R("ignore rule"; "\(.file): \(.rule) appears more than once in the file")),
          ($E | unique[] | . as $x | ($IR | map(select(. == $x)) | length) as $n
            | if $n == 0 then R("ignore rule"; "\($x.file): \($x.rule) is missing from ignore_rules")
              elif $n > 1 then R("ignore rule"; "\($x.file): \($x.rule) is listed \($n) times in ignore_rules")
              else empty end),
          ($IR | unique[] | . as $x | select(($E | map(select(. == $x)) | length) == 0)
            | R("ignore rule"; "\($x.file): \($x.rule) is not an effective rule of a tracked .gitignore")) )),
    ($ti[0][] | R("tracked ignored"; .)),

    # tracked junk
    ($j[] | .i as $i | ($L.tracked_junk_patterns[$i]) as $pat
      | if .unusable then R("tracked junk"; "pattern \($pat | tojson) is not a usable pathspec")
        else .paths[] | R("tracked junk"; "\(.) (\($pat))") end),

    # verification ignored roots
    ($r[] | .i as $i | ($L.verification_ignored_roots[$i]) as $root
      | if .usable | not then R("verification root"; "\($root | tojson) must be a relative path")
        elif .covered | not then R("verification root"; "\($root) is not covered by a .gitignore rule")
        else empty end),

    # settled
    (if $settled then ($C[] | select(type == "object" and .disposition == "delete") | R("unsettled delete"; "class \(cid)"))
     else empty end)
  ]
| unique
| .[]
JQ

if ! OUT=$(jq -n -r --slurpfile l "${LEDGER}" --slurpfile t "${WORK}/tracked.json" \
      --slurpfile m "${WORK}/matches.jsonl" --slurpfile j "${WORK}/junk.jsonl" \
      --slurpfile pre "${WORK}/prefixes.json" --slurpfile sh "${WORK}/shipped.json" \
      --slurpfile e "${WORK}/effective.jsonl" --slurpfile ti "${WORK}/tracked_ignored.json" \
      --slurpfile r "${WORK}/roots.jsonl" --argjson settled "${REQUIRE_SETTLED}" \
      "${PROG}" 2>&1); then
  echo "REJECT: internal: validator could not evaluate the ledger: ${OUT}" >&2
  exit 1
fi

if [ -n "${OUT}" ]; then
  printf '%s\n' "${OUT}" >&2
  exit 1
fi

echo "validate_artifact_ledger: ok (offline, $(jq 'length' "${WORK}/tracked.json") files, ${N_CLASSES} classes)"
exit 0
