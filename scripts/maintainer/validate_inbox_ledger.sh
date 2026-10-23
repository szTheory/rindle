#!/usr/bin/env bash
# validate_inbox_ledger.sh - maintainer inbox, security advisory and dependency
# landing ledger validator.
#
# Checks .planning/INBOX-LEDGER.json (schema rindle-inbox-ledger-v1) either
#   --offline            shape only: schema, enums, required fields, trigger vocabulary,
#                        landing shape. Reads NO clock and NO inventory (merge-blocking safe).
#   --inventory FILE     live: against a fresh collect_inbox.sh inventory, plus the
#                        clock (INBOX_NOW_EPOCH, default now). Fails on stale data.
# and prints collector flags derived from the ledger with --print-collector-args.
#
# Usage:
#   validate_inbox_ledger.sh --ledger FILE (--offline | --inventory FILE [--max-age-seconds N])
#   validate_inbox_ledger.sh --print-collector-args --ledger FILE
#
# Exit codes: 0 valid | 1 rejected (each reason on stderr, prefixed REJECT:) | 64 usage.
#
# Safety: every rule is evaluated by jq. Ledger and inventory values reach jq only through
# --slurpfile / --arg / --argjson; nothing from either file is ever executed as code.
# Triggers are a CLOSED vocabulary (date, hex_version_gte, gh_issue_closed).
# Bash 3.2 and jq 1.6 compatible (no mapfile, no jq 1.7-only builtins, no GNU-only date flags).

set -euo pipefail

LEDGER=""
INVENTORY=""
OFFLINE=false
PRINT_ARGS=false
MAX_AGE=86400

usage() {
  cat >&2 <<'USAGE'
usage: validate_inbox_ledger.sh --ledger FILE (--offline | --inventory FILE [--max-age-seconds N])
       validate_inbox_ledger.sh --print-collector-args --ledger FILE
USAGE
  exit 64
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --ledger) [ "$#" -ge 2 ] || usage; LEDGER="$2"; shift 2 ;;
    --inventory) [ "$#" -ge 2 ] || usage; INVENTORY="$2"; shift 2 ;;
    --offline) OFFLINE=true; shift ;;
    --print-collector-args) PRINT_ARGS=true; shift ;;
    --max-age-seconds)
      [ "$#" -ge 2 ] || usage
      case "$2" in ''|*[!0-9]*) echo "validate_inbox_ledger: --max-age-seconds needs a number" >&2; exit 64 ;; esac
      MAX_AGE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "validate_inbox_ledger: unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "${LEDGER}" ] || usage
if [ "${PRINT_ARGS}" = true ]; then
  if [ "${OFFLINE}" = true ] || [ -n "${INVENTORY}" ]; then usage; fi
else
  if [ "${OFFLINE}" = true ] && [ -n "${INVENTORY}" ]; then usage; fi
  if [ "${OFFLINE}" = false ] && [ -z "${INVENTORY}" ]; then usage; fi
fi

if [ ! -f "${LEDGER}" ] || ! jq -e . "${LEDGER}" >/dev/null 2>&1; then
  echo "REJECT: unreadable: ledger ${LEDGER} is missing or not valid JSON" >&2
  exit 1
fi

# --- collector flags derived from the ledger --------------------------------------------
if [ "${PRINT_ARGS}" = true ]; then
  jq -r '
    def trigs: [ (.items // [])[]?  | select(type == "object") | .trigger? ],
               [ (.advisories // [])[]? | select(type == "object") | .exception?.trigger? ];
    ( [ (.items // [])[] | select(type == "object" and has("terminal")) | .number ]
      + [ (trigs[]) | select(type == "object" and .type == "gh_issue_closed") | .number ] )
      | map(select(type == "number")) | unique | .[] | "--include\n\(.)"
  ' "${LEDGER}"
  jq -r '
    def trigs: [ (.items // [])[]?  | select(type == "object") | .trigger? ],
               [ (.advisories // [])[]? | select(type == "object") | .exception?.trigger? ];
    [ (trigs[]) | select(type == "object" and .type == "hex_version_gte") | .package ]
      | map(select(type == "string")) | unique | .[] | "--hex-package\n\(.)"
  ' "${LEDGER}"
  printf '%s\n' --landing-ledger "${LEDGER}"
  exit 0
fi

# --- mode inputs -------------------------------------------------------------------------
MODE=offline
INV_FILE=/dev/null
NOW=0
if [ "${OFFLINE}" = false ]; then
  MODE=live
  INV_FILE="${INVENTORY}"
  if [ ! -f "${INV_FILE}" ] || ! jq -e . "${INV_FILE}" >/dev/null 2>&1; then
    echo "REJECT: unreadable: inventory ${INV_FILE} is missing or not valid JSON" >&2
    exit 1
  fi
  # Clock is read ONLY in live mode. Tests inject INBOX_NOW_EPOCH.
  NOW="${INBOX_NOW_EPOCH:-$(date +%s)}"
  case "${NOW}" in ''|*[!0-9]*) echo "validate_inbox_ledger: INBOX_NOW_EPOCH must be seconds" >&2; exit 64 ;; esac
fi

TWIN_LITERAL='not-applicable: twin not built (Phase 137)'

read -r -d '' PROG <<'JQ' || true
def R($k; $m): "REJECT: \($k): \($m)";
def nestr: type == "string" and (test("^\\s*$") | not);
def hex40: type == "string" and test("^[0-9a-f]{40}$");
def posint: type == "number" and . == floor and . > 0;
def dateok: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
            and ((try ((. + "T00:00:00Z") | fromdateiso8601) catch null) != null);
def depoch: (. + "T00:00:00Z") | fromdateiso8601;
# "after the date": the whole named day has passed.
def dayend: depoch + 86400;
def vkey: tostring | split("-") as $p
          | (($p[0] | split(".") | map(tonumber? // 0)) + [0,0,0,0])[0:4] as $n
          | [$n, (if ($p | length) > 1 then 0 else 1 end)];
def objs: if type == "array" then map(select(type == "object")) else [] end;
def arr: if type == "array" then . else [] end;
def obj: if type == "object" then . else {} end;

def trigerrs:
  if type != "object" then ["trigger must be an object"]
  elif .type == "date" then (if (.not_after | dateok) then [] else ["date trigger needs not_after YYYY-MM-DD"] end)
  elif .type == "hex_version_gte" then
    (if (.package | nestr) and (.version | nestr) then [] else ["hex_version_gte trigger needs package and version"] end)
  elif .type == "gh_issue_closed" then
    (if (.number | posint) then [] else ["gh_issue_closed trigger needs a positive number"] end)
  else ["trigger type outside the closed vocabulary (date, hex_version_gte, gh_issue_closed): \(.type | tojson)"] end;

# fired | pending | unevaluable   (live only)
def trigstate($I; $now):
  if .type == "date" then (if $now >= (.not_after | dayend) then "fired" else "pending" end)
  elif .type == "hex_version_gte" then
    (($I.hex_latest | obj)[.package]) as $h
    | if $h == null then "unevaluable"
      elif ($h | vkey) >= (.version | vkey) then "fired" else "pending" end
  elif .type == "gh_issue_closed" then
    (.number) as $n
    | (($I.terminal | arr) | map(select(.number == $n)) | .[0]) as $t
    | if $t == null then "unevaluable" elif $t.state == "closed" then "fired" else "pending" end
  else "unevaluable" end;

def ikey: "\(.kind) \(.number)";

def itemerrs:
  if type != "object" then [R("item"; "entry is not an object")] else
  . as $i | ($i | ikey) as $lb
  | [ (if ($i.kind | IN("issue", "pr")) then empty else R("item"; "\($lb): kind must be issue or pr") end),
      (if ($i.number | posint) then empty else R("item"; "\($lb): number must be a positive integer") end),
      (if ($i.disposition | IN("merge", "close", "retain", "supersede", "defer")) then empty
       else R("unknown disposition"; "\($lb): \($i.disposition | tojson) is not merge|close|retain|supersede|defer") end),
      (if ($i.rationale | nestr) then empty else R("item"; "\($lb): rationale is required") end),
      (if ($i | has("terminal")) then
         ($i.terminal as $t
          | if ($t | type) != "object" then R("terminal"; "\($lb): terminal must be an object")
            elif $t.state != "closed" or (($t.merged | type) != "boolean") then R("terminal"; "\($lb): terminal needs state closed and boolean merged")
            else empty end)
       elif $i.kind == "pr" then
         (if ($i.head_sha | hex40) then empty else R("item"; "\($lb): PR item needs a 40-hex head_sha (or a terminal record)") end)
       else empty end),
      (if ($i | has("pending_action")) and (($i.pending_action | IN("rebase", "close", "merge")) | not)
       then R("item"; "\($lb): pending_action must be rebase|close|merge") else empty end),
      (if $i.disposition == "supersede" and
          (((($i.successor | posint)) or (($i.successor | type) == "string" and ($i.successor | test("^#[0-9]+$")))) | not)
       then R("supersede requires successor"; "\($lb): successor must be a number or #N") else empty end),
      (if $i.disposition == "defer" then
         ( (if ($i.gate | nestr) then empty else R("defer requires gate"; "\($lb): gate is required") end),
           (if ($i | has("trigger")) then ($i.trigger | trigerrs | map(R("defer trigger"; "\($lb): \(.)")) | .[])
            else R("defer requires trigger"; "\($lb): trigger is required") end) )
       else empty end),
      (if ($i | has("risk_group")) != ($i | has("group_packages")) then R("item"; "\($lb): risk_group and group_packages go together")
       elif ($i | has("group_packages")) and ((($i.group_packages | type) != "array") or (($i.risk_group | nestr) | not)
             or (($i.group_packages | map(nestr) | all) | not))
       then R("item"; "\($lb): risk_group must be a string and group_packages an array of package names") else empty end)
    ] end;

def advkey: "\(.id) (\(.scope))";

def adverrs:
  if type != "object" then [R("advisory"; "entry is not an object")] else
  . as $a | ($a | advkey) as $lb
  | [ (if ($a.id | nestr) then empty else R("advisory"; "\($lb): id is required") end),
      (if ($a.package | nestr) then empty else R("advisory"; "\($lb): package is required") end),
      (if ($a.locked | nestr) then empty else R("advisory"; "\($lb): locked is required") end),
      (if ($a.scope | IN("root", "examples/adoption_demo", "github")) then empty
       else R("advisory"; "\($lb): scope must be root|examples/adoption_demo|github") end),
      (if (($a.path | type) == "array" and ($a.path | length) > 0 and ($a.path | map(nestr) | all)) then empty
       else R("advisory"; "\($lb): path must be a non-empty array of package names") end),
      (if ($a.reachability | IN("runtime", "dev-test-only", "optional-dep")) then empty
       else R("advisory"; "\($lb): reachability must be runtime|dev-test-only|optional-dep") end),
      (if ($a.fix_version == null or ($a.fix_version | nestr)) and ($a | has("fix_version")) then empty
       else R("advisory"; "\($lb): fix_version must be a string or null") end),
      (if ($a.status | IN("resolved", "exception", "open")) then empty
       else R("advisory"; "\($lb): status must be resolved|exception|open") end),
      (if $a.status == "exception" then
         ( ($a.exception | obj) as $e
           | (if ($e.expires | dateok) then empty else R("exception"; "\($lb): expires must be YYYY-MM-DD") end),
             (if ($e | has("trigger")) then ($e.trigger | trigerrs | map(R("exception"; "\($lb): \(.)")) | .[])
              else R("exception"; "\($lb): trigger is required") end),
             (if ($e.rationale | nestr) then empty else R("exception"; "\($lb): rationale is required") end) )
       else empty end)
    ] end;

def landerrs:
  if type != "object" then [R("landing"; "entry is not an object")] else
  . as $l | "landing \($l.number)" as $lb
  | [ (if ($l.number | posint) then empty else R("landing"; "\($lb): number must be a positive integer") end),
      (if ($l.group | nestr) then empty else R("landing"; "\($lb): group is required") end),
      (if (($l.group_packages | type) == "array" and ($l.group_packages | map(nestr) | all)) then empty
       else R("landing"; "\($lb): group_packages must be an array of package names") end),
      (if ($l.lock | IN("mix.lock", "examples/adoption_demo/mix.lock")) then empty else R("landing"; "\($lb): lock must be a supported mix.lock path") end),
      (if ($l.merge_sha | hex40) then empty else R("landing"; "\($lb): merge_sha must be 40-hex") end),
      (if ($l | has("evidence_sha")) and (($l.evidence_sha | hex40) | not)
       then R("landing"; "\($lb): evidence_sha must be 40-hex") else empty end),
      (if ($l.ci_run_id | posint) then empty else R("landing"; "\($lb): ci_run_id must be a positive integer") end),
      (if ($l.baseline_run_id | posint) then empty else R("landing"; "\($lb): baseline_run_id must be a positive integer") end),
      (if ($l.subject | nestr) then empty else R("landing"; "\($lb): subject is required") end),
      (if (($l.lock_delta | type) == "array") then
         (($l.group_packages | arr) as $gp
          | $l.lock_delta | map(select(type == "object" and (.package as $p | ($gp | index($p)) == null)) | .package)
          | map(R("landing"; "\($lb): lock_delta package \(.) is outside group_packages")) | .[])
       else R("landing"; "\($lb): lock_delta must be an array") end),
      (($l.gates | obj) as $g
       | (["supported_toolchain", "public_contract", "package_consumer"]
          | map(. as $n | select($g[$n] != "pass") | R("landing gate"; "\($lb): \($n) must be pass, got \($g[$n] | tojson)")) | .[]),
         (if $g.twin == $twin then empty
          else R("landing twin"; "\($lb): twin must be the literal \($twin | tojson) and never counts as pass, got \($g.twin | tojson)") end))
    ] end;

def shape:
  . as $L
  | if type != "object" then [R("schema"; "ledger is not a JSON object")] else
    [ (if $L.schema == "rindle-inbox-ledger-v1" then empty else R("schema"; "ledger schema must be rindle-inbox-ledger-v1") end),
      (if ($L.repo | nestr) then empty else R("schema"; "ledger repo is required") end),
      (["items", "advisories", "landings"][] | . as $k | select(($L[$k] | type) != "array") | R("schema"; "\($k) must be an array")),
      (if ($L.sources | type) == "object" then empty else R("schema"; "sources must be an object") end),
      (($L.sources | obj | .dependabot_alerts) as $d
       | if $d == null then empty
         elif ($d | type) != "object" or (($d.status | IN("source_disabled", "unreadable")) | not) or (($d.rationale | nestr) | not)
         then R("source"; "sources.dependabot_alerts needs status source_disabled|unreadable and a non-empty rationale")
         else empty end),
      (($L.items | arr | map(itemerrs) | add // [])[]),
      (($L.advisories | arr | map(adverrs) | add // [])[]),
      (($L.landings | arr | map(landerrs) | add // [])[]),
      (($L.advisories | objs | group_by(advkey) | map(select(length > 1) | .[0] | R("duplicate"; "advisory \(advkey) appears more than once")))[])
    ] end;

def live($I; $now; $maxage):
  . as $L
  | (try ($I.collected_at | fromdateiso8601) catch null) as $ct
  | ($L.items | objs) as $items
  | (($I.issues | arr | map("issue \(.number)")) + ($I.prs | arr | map("pr \(.number)"))) as $open
  | ($items | map(ikey)) as $have
  | [ (if $I.schema == "rindle-inbox-inventory-v1" then empty else R("inventory"; "schema must be rindle-inbox-inventory-v1") end),
      (if $I.repo == $L.repo then empty else R("repo"; "ledger repo \($L.repo | tojson) != inventory repo \($I.repo | tojson)") end),
      (if $ct == null then R("inventory"; "collected_at missing or unparseable")
       elif ($now - $ct) < 0 then R("inventory"; "collected_at is in the future")
       elif ($now - $ct) > $maxage then R("stale inventory"; "collected \($now - $ct)s ago, bound \($maxage)s")
       else empty end),

      # exactly one item per open number
      (($items | group_by(ikey) | map(select(length > 1) | .[0] | R("duplicate"; "\(ikey) has more than one ledger item")))[]),
      (($open - $have)[] | R("missing"; "\(.) is open and has no ledger item")),

      # items whose number is not open need a matching terminal record
      ($items[] | . as $it | ($it | ikey) as $k
        | if ($open | index($k)) != null then
            (if ($it | has("terminal")) then R("terminal mismatch"; "\($k) is still open but the ledger records it terminal") else empty end)
          elif ($it | has("terminal") | not) then R("not-open"; "\($k) is not open and has no terminal record")
          else
            (($I.terminal | arr | map(select(.kind == $it.kind and .number == $it.number)) | .[0]) as $t
             | if $t == null then R("terminal mismatch"; "\($k) has no inventory terminal lookup (collect with --include)")
               elif $t.state != $it.terminal.state or $t.merged != $it.terminal.merged
                    or (($it.terminal | has("state_reason")) and $t.state_reason != $it.terminal.state_reason)
               then R("terminal mismatch"; "\($k) ledger terminal differs from inventory (state \($t.state), merged \($t.merged | tojson))")
               else empty end)
          end),

      # A merged lock-changing PR needs one machine-checked landing per lock.
      # changed_files is collected from GitHub even when the ledger omits a hint.
      ($items[] | select(.kind == "pr" and .terminal.merged == true) | . as $it
       | (($I.terminal | arr | map(select(.kind == "pr" and .number == $it.number)) | .[0]) // {}) as $t
       | if ($t.changed_files | type) != "array" or (($t.merge_sha | hex40) | not)
         then R("landing source"; "pr \($it.number): missing authoritative changed_files or merge_sha")
         else
           (($t.changed_files | map(select(. == "mix.lock" or . == "examples/adoption_demo/mix.lock")))
            + [$L.landings[] | select(.number == $it.number) | .lock] | unique)[] as $lock
           | [$L.landings[] | select(.number == $it.number and .lock == $lock)] as $ls
           | if ($ls | length) != 1 then R("landing required"; "pr \($it.number): exactly one landing required for \($lock)")
             else $ls[0] as $l
               | [$t.landing_evidence[]? | select(.lock == $lock)] as $es
               | if ($es | length) != 1 then R("landing evidence"; "pr \($it.number): exactly one fresh evidence record required for \($lock)")
                 else $es[0] as $e
                   | if $l.merge_sha != $t.merge_sha or $e.sha != $t.merge_sha
                       or $e.schema != "rindle-dep-landing-v1" or $e.verdict != "pass"
                       or $e.attributable != true or $e.mix_exs_changed != false
                       or $l.group != $e.group
                       or (($it | has("risk_group")) and ($l.group != $it.risk_group or ($l.group_packages|sort) != ($it.group_packages|sort)))
                       or ($l.lock_delta | sort_by(.package)) != ($e.lock_delta | sort_by(.package))
                       or $l.gates != $e.gates or $l.ci_run_id != $e.run.id
                       or $e.run.head_sha != ($l.evidence_sha // $l.merge_sha)
                       or $e.evidence_sha != ($l.evidence_sha // $l.merge_sha)
                       or $e.run.event != "push" or $e.run.status != "completed"
                       or (($e.lock_delta | map(.package)) - $l.group_packages | length) != 0
                     then R("landing mismatch"; "pr \($it.number): landing differs from freshly collected attribution/CI")
                     elif ($l.evidence_sha // $l.merge_sha) != $l.merge_sha and
                       ($e.equivalence.policy != "planning-only-descendant-v1"
                        or $e.equivalence.merge_sha != $l.merge_sha
                        or $e.equivalence.evidence_sha != $l.evidence_sha
                        or ($e.equivalence.changed_files|type) != "array"
                        or ($e.equivalence.changed_files|all(.[]; test("^\\.planning/([^/]+/)*[^/]+\\.md$|^\\.planning/INBOX-LEDGER\\.json$"))|not))
                     then R("landing equivalence"; "pr \($it.number): descendant lacks verified planning-only history")
                     else empty end
                 end
             end
         end),

      # open PR items: head binding, mergeability, attribution
      ($items[] | select(.kind == "pr" and (has("terminal") | not)) | . as $it
        | (($I.prs | arr | map(select(.number == $it.number)) | .[0]) as $p
           | if $p == null then empty else
               ( (if $it.head_sha != $p.head_sha then R("stale"; "pr \($it.number) head_sha \($it.head_sha | tojson) != inventory head \($p.head_sha | tojson)") else empty end),
                 (if $it.disposition == "merge" and (($it | has("pending_action")) | not) then
                    ( (if ($p.ci_summary.conclusion == "success") and ($p.behind == false) then empty
                       else R("not mergeable"; "pr \($it.number) merge needs a successful CI Summary and not behind main (conclusion \($p.ci_summary.conclusion | tojson), behind \($p.behind | tojson)); record pending_action to defer") end),
                      (($it.group_packages | arr) as $gp
                       | (($p.lock_delta | arr | map(.package) | unique) - $gp) as $extra
                       | if ($it | has("group_packages")) and ($extra | length) > 0
                         then R("attribution"; "pr \($it.number) lock delta has packages outside group_packages: \($extra | join(","))")
                         else empty end) )
                  else empty end) )
             end)),

      # deferred items: a fired trigger forces a re-decision
      ($items[] | select(.disposition == "defer" and (has("terminal") | not) and ((.trigger | trigerrs | length) == 0)) | . as $it
        | ($it.trigger | trigstate($I; $now)) as $s
        | if $s == "fired" then R("trigger fired"; "\($it | ikey) deferral trigger fired: re-decide")
          elif $s == "unevaluable" then R("trigger unevaluable"; "\($it | ikey) trigger cannot be evaluated from the inventory (collect with the flags from --print-collector-args)")
          else empty end),

      # advisories
      (($I.advisories | obj | .findings | arr) as $f
       | ($L.advisories | objs) as $recs
       | ($f | map("\(.id)|\(.scope)")) as $fk
       | ($recs | map("\(.id)|\(.scope)")) as $rk
       | ( ($f[] | select(("\(.id)|\(.scope)" | IN($rk[])) | not) | R("advisory missing"; "inventory reports \(.id) (\(.scope)) with no ledger record")),
           ($f[] | select(.ignored == true) | . as $x
              | select(($recs | map(select(.id == $x.id and .scope == $x.scope and .status == "exception")) | length) == 0)
              | R("advisory ignored"; "\($x.id) (\($x.scope)) is ignored in the inventory and needs an unexpired exception record")),
           ($recs[] | . as $a | ("\($a.id)|\($a.scope)") as $k | ($fk | index($k)) as $present
              | if $a.status == "resolved" then
                  (if $present != null then R("advisory not resolved"; "\($a | advkey) is marked resolved but is still reported") else empty end)
                elif $a.status == "open" then R("advisory open"; "\($a | advkey) is still open")
                elif $a.status == "exception" then
                  ( (if $present == null then R("advisory stale"; "\($a | advkey) is no longer reported: mark it resolved") else empty end),
                    (if ($a.exception.expires | dateok) and ($now >= ($a.exception.expires | dayend)) then R("exception expired"; "\($a | advkey) expired \($a.exception.expires)") else empty end),
                    (if (($a.exception.trigger | trigerrs | length) == 0) then
                       (($a.exception.trigger | trigstate($I; $now)) as $s
                        | if $s == "fired" then R("trigger fired"; "\($a | advkey) exception trigger fired: re-decide")
                          elif $s == "unevaluable" then R("trigger unevaluable"; "\($a | advkey) exception trigger cannot be evaluated from the inventory")
                          else empty end)
                     else empty end) )
                else empty end) )),

      # advisory sources
      (($I.advisories | obj | .sources | obj) as $src
       | (["hex_audit_root", "hex_audit_demo"][] | . as $n | ($src[$n].status) as $s
          | select(($s | IN("clean", "findings")) | not)
          | R("source unreadable"; "\($n) status \($s | tojson) cannot be accepted")),
         (($src.dependabot_alerts.status) as $ds
          | ($L.sources | obj | .dependabot_alerts | obj) as $ls
          | if $ds == null then R("source missing"; "inventory has no dependabot_alerts source record")
            elif ($ds | IN("source_disabled", "unreadable")) then
              (if $ls.status == $ds and ($ls.rationale | nestr) then empty
               else R("source"; "dependabot_alerts is \($ds) in the inventory and needs a matching ledger source record with a non-empty rationale") end)
            else empty end))
    ];

$l[0] as $L
| ($L | shape) as $s
| (if $mode == "live" then ($L | live($i[0]; $now; $maxage)) else [] end) as $v
| ($s + $v)[]
JQ

if ! OUT=$(jq -n -r --slurpfile l "${LEDGER}" --slurpfile i "${INV_FILE}" \
      --arg mode "${MODE}" --argjson now "${NOW}" --argjson maxage "${MAX_AGE}" \
      --arg twin "${TWIN_LITERAL}" \
      "${PROG}" 2>&1); then
  echo "REJECT: internal: validator could not evaluate the ledger: ${OUT}" >&2
  exit 1
fi

if [ -n "${OUT}" ]; then
  printf '%s\n' "${OUT}" >&2
  exit 1
fi

echo "validate_inbox_ledger: ok (${MODE})"
exit 0
