#!/usr/bin/env bash
# collect_phase_gate_evidence.sh - read-only evidence collector for a closed set of
# squash commits on main.
#
# For every SHA in --shas-file it records the commit subject, the newest main push run
# of ci.yml for that SHA with its conclusion, and the conclusion of that run's
# `CI Summary` job. It also parses a repo_hygiene_check.sh log and its exit status, and
# records the newest scheduled nightly.yml run whose head descends from --nightly-after.
#
# Verdict pass (exit 0) needs, for every SHA: a push run concluded success, a CI Summary
# job concluded success, and a subject that does not start with fix: or feat: (those cut
# a release). It also needs the hygiene log to contain `Result: safe to start release
# prep` with exit status 0. Anything else is verdict fail (exit 1) with named causes.
# The Nightly follow-up is recorded only; it never changes the verdict.
#
# Usage:
#   collect_phase_gate_evidence.sh --repo OWNER/NAME --shas-file FILE \
#     --hygiene-log FILE --hygiene-exit N [--nightly-after SHA] [--root DIR]
#
#   --shas-file   one 40-character hex SHA per line; blank lines and # comments skipped.
#   --root        git checkout that holds every listed commit (default: current dir).
#                 Nightly ancestry is checked there, so fetch origin/main first.
#
# Output: one rindle-phase-gate-evidence-v1 JSON document on stdout (jq -S); causes
# are also printed to stderr.
#
# Exit codes: 0 verdict pass | 1 verdict fail | 64 usage.
#
# Safety: GitHub is read only through `gh api -X GET`; the script never reruns, merges,
# pushes, tags, labels or comments. --repo and every SHA or run id are validated before
# they reach a request path, and values reach jq only through --arg / --argjson.
# Bash 3.2 and jq 1.6 compatible.

set -euo pipefail

SCHEMA="rindle-phase-gate-evidence-v1"
SAFE_LINE="Result: safe to start release prep"

usage() {
  sed -n '16,27p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 64
}

die_usage() {
  echo "collect_phase_gate_evidence: $1" >&2
  usage
}

REPO=""
SHAS_FILE=""
HYGIENE_LOG=""
HYGIENE_EXIT=""
NIGHTLY_AFTER=""
ROOT="."

while [ $# -gt 0 ]; do
  case "$1" in
    --repo | --shas-file | --hygiene-log | --hygiene-exit | --nightly-after | --root)
      [ $# -ge 2 ] || die_usage "$1 needs a value"
      case "$1" in
        --repo) REPO="$2" ;;
        --shas-file) SHAS_FILE="$2" ;;
        --hygiene-log) HYGIENE_LOG="$2" ;;
        --hygiene-exit) HYGIENE_EXIT="$2" ;;
        --nightly-after) NIGHTLY_AFTER="$2" ;;
        --root) ROOT="$2" ;;
      esac
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    *)
      die_usage "unknown argument: $1"
      ;;
  esac
done

[ -n "$REPO" ] || die_usage "--repo is required"
[ -n "$SHAS_FILE" ] || die_usage "--shas-file is required"
[ -n "$HYGIENE_LOG" ] || die_usage "--hygiene-log is required"
[ -n "$HYGIENE_EXIT" ] || die_usage "--hygiene-exit is required"

printf '%s' "$REPO" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' ||
  die_usage "--repo must be OWNER/NAME"
printf '%s' "$HYGIENE_EXIT" | grep -Eq '^(0|[1-9][0-9]{0,2})$' ||
  die_usage "--hygiene-exit must be a non-negative integer"
[ -f "$SHAS_FILE" ] || die_usage "--shas-file not found: $SHAS_FILE"
[ -f "$HYGIENE_LOG" ] || die_usage "--hygiene-log not found: $HYGIENE_LOG"
[ -d "$ROOT" ] || die_usage "--root not found: $ROOT"

is_sha() {
  printf '%s' "$1" | grep -Eq '^[0-9a-f]{40}$'
}

if [ -n "$NIGHTLY_AFTER" ]; then
  is_sha "$NIGHTLY_AFTER" || die_usage "--nightly-after must be a 40-character hex SHA"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/phase_gate_evidence.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

SHAS="$WORK/shas"
: >"$SHAS"
while IFS= read -r line || [ -n "$line" ]; do
  line="$(printf '%s' "$line" | tr -d '[:space:]')"
  case "$line" in
    "" | "#"*) continue ;;
  esac
  is_sha "$line" || die_usage "not a 40-character hex SHA in --shas-file: $line"
  printf '%s\n' "$line" >>"$SHAS"
done <"$SHAS_FILE"

# The only GitHub access path. Prints the response body; returns gh's status.
gh_get() {
  gh api -X GET "$1"
}

ENTRIES="$WORK/entries"
: >"$ENTRIES"

causes="[]"
add_cause() {
  causes="$(jq -cn --argjson c "$causes" --arg m "$1" '$c + [$m]')"
}

while IFS= read -r sha <&3; do
  causes="[]"

  subject=""
  if subject="$(git -C "$ROOT" log -1 --format=%s "$sha" 2>/dev/null)"; then
    if printf '%s' "$subject" | grep -Eq '^(fix|feat)(\([^)]*\))?!?:'; then
      add_cause "releasing subject"
    fi
    subject_json="$(jq -cn --arg s "$subject" '$s')"
  else
    subject_json="null"
    add_cause "commit not found"
  fi

  run_id="null"
  run_conclusion="null"
  summary_conclusion="null"

  runs_path="repos/${REPO}/actions/workflows/ci.yml/runs?head_sha=${sha}&event=push&branch=main&per_page=20"
  if runs="$(gh_get "$runs_path" 2>"$WORK/gh.err")" &&
    run="$(printf '%s' "$runs" | jq -c '[(.workflow_runs // [])[]] | sort_by(.created_at, .id) | last')"; then
    if [ "$run" = "null" ]; then
      add_cause "ci_push missing"
    else
      run_id="$(printf '%s' "$run" | jq -c '.id')"
      run_conclusion="$(printf '%s' "$run" | jq -c '.conclusion')"
      case "$run_conclusion" in
        '"success"') ;;
        null) add_cause "ci_push pending" ;;
        *) add_cause "ci_push $(printf '%s' "$run_conclusion" | jq -r '.')" ;;
      esac

      if printf '%s' "$run_id" | grep -Eq '^[0-9]+$'; then
        jobs_path="repos/${REPO}/actions/runs/${run_id}/jobs?per_page=100"
        if jobs="$(gh_get "$jobs_path" 2>"$WORK/gh.err")" &&
          job="$(printf '%s' "$jobs" | jq -c '[(.jobs // [])[] | select(.name == "CI Summary")] | last')"; then
          if [ "$job" = "null" ]; then
            add_cause "ci_summary missing"
          else
            summary_conclusion="$(printf '%s' "$job" | jq -c '.conclusion')"
            case "$summary_conclusion" in
              '"success"') ;;
              null) add_cause "ci_summary pending" ;;
              *) add_cause "ci_summary $(printf '%s' "$summary_conclusion" | jq -r '.')" ;;
            esac
          fi
        else
          add_cause "ci_summary lookup failed"
        fi
      else
        run_id="null"
        add_cause "ci_push run id invalid"
      fi
    fi
  else
    add_cause "ci_push lookup failed"
  fi

  jq -cn \
    --arg sha "$sha" \
    --argjson subject "$subject_json" \
    --argjson run_id "$run_id" \
    --argjson run_conclusion "$run_conclusion" \
    --argjson summary_conclusion "$summary_conclusion" \
    --argjson causes "$causes" \
    '{sha: $sha, subject: $subject,
      ci_push: {run_id: $run_id, conclusion: $run_conclusion},
      ci_summary: {conclusion: $summary_conclusion},
      ok: ($causes | length == 0), causes: $causes}' >>"$ENTRIES"
done 3<"$SHAS"

# Hygiene: the last Result: line of the supplied log, and the supplied exit status.
result_line="$(grep -E '^Result: ' "$HYGIENE_LOG" | tail -n 1 | sed 's/[[:space:]]*$//' || true)"
if [ -n "$result_line" ]; then
  result_json="$(jq -cn --arg r "$result_line" '$r')"
else
  result_json="null"
fi
hygiene_ok=false
if [ "$result_line" = "$SAFE_LINE" ] && [ "$HYGIENE_EXIT" -eq 0 ]; then
  hygiene_ok=true
fi

# Nightly follow-up: recorded only, never part of the verdict.
nightly='{"status":"pending","run_id":null,"head_sha":null,"conclusion":null}'
if [ -n "$NIGHTLY_AFTER" ]; then
  nightly_path="repos/${REPO}/actions/workflows/nightly.yml/runs?event=schedule&per_page=10"
  if nruns="$(gh_get "$nightly_path" 2>"$WORK/gh.err")"; then
    printf '%s' "$nruns" |
      jq -c '[(.workflow_runs // [])[]] | sort_by(.created_at, .id) | reverse | .[]
             | {id, head_sha, conclusion}' >"$WORK/nightly" 2>/dev/null || : >"$WORK/nightly"
    while IFS= read -r nrun <&3; do
      head="$(printf '%s' "$nrun" | jq -r '.head_sha // ""')"
      is_sha "$head" || continue
      if git -C "$ROOT" merge-base --is-ancestor "$NIGHTLY_AFTER" "$head" 2>/dev/null; then
        nightly="$(printf '%s' "$nrun" |
          jq -c '{status: "observed", run_id: .id, head_sha: .head_sha, conclusion: .conclusion}')"
        break
      fi
    done 3<"$WORK/nightly"
  fi
fi

document="$(jq -S -s \
  --arg schema "$SCHEMA" \
  --arg repo "$REPO" \
  --argjson result_line "$result_json" \
  --argjson hygiene_exit "$HYGIENE_EXIT" \
  --argjson hygiene_ok "$hygiene_ok" \
  --argjson nightly "$nightly" \
  '. as $shas
   | ([$shas[] | .sha as $s | .causes[] | "\($s): \(.)"]
      + (if $hygiene_ok then [] else ["hygiene: not safe to start release prep"] end)
      + (if ($shas | length) == 0 then ["no SHAs listed"] else [] end)) as $causes
   | {schema: $schema, repo: $repo, shas: $shas,
      hygiene: {result_line: $result_line, exit: $hygiene_exit, ok: $hygiene_ok},
      nightly_followup: $nightly,
      causes: $causes,
      verdict: (if ($causes | length) == 0 then "pass" else "fail" end)}' "$ENTRIES")"

printf '%s\n' "$document"

verdict="$(printf '%s' "$document" | jq -r '.verdict')"
printf '%s' "$document" | jq -r '.causes[] | "cause: \(.)"' >&2
echo "collect_phase_gate_evidence: verdict $verdict" >&2

[ "$verdict" = "pass" ]
