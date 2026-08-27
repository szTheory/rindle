#!/usr/bin/env bash
# Reject active phase plans that depend on human verification or UAT.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
phase_dir=""

usage() {
  echo "usage: $0 [--phase-dir PATH]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase-dir)
      [ "$#" -ge 2 ] || { usage; exit 64; }
      phase_dir="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 64
      ;;
  esac
done

if [ -z "$phase_dir" ]; then
  state="$repo_root/.planning/STATE.md"
  [ -f "$state" ] || { echo "[automation-first] no active planning state; skipped"; exit 0; }
  phase="$(sed -nE 's/^current_phase:[[:space:]]*"?([^"[:space:]]+)"?.*$/\1/p' "$state" | head -1)"
  [ -n "$phase" ] || { echo "[automation-first] no current_phase; skipped"; exit 0; }
  phase_dir="$(find "$repo_root/.planning/phases" -maxdepth 1 -type d -name "${phase}-*" -print | head -1)"
  [ -n "$phase_dir" ] || { echo "[automation-first] phase $phase has no active directory; skipped"; exit 0; }
fi

[ -d "$phase_dir" ] || { echo "[automation-first] phase directory does not exist: $phase_dir" >&2; exit 1; }

failures="$(mktemp "${TMPDIR:-/tmp}/rindle-automation-first.XXXXXX")"
blocks="$(mktemp "${TMPDIR:-/tmp}/rindle-automation-blocks.XXXXXX")"
trap 'rm -f "$failures" "$blocks"' EXIT

record_failure() {
  printf '%s\n' "$1" >> "$failures"
}

for plan in "$phase_dir"/*-PLAN.md; do
  [ -f "$plan" ] || continue

  if grep -n 'checkpoint:human-verify' "$plan" >/dev/null 2>&1; then
    record_failure "$(basename "$plan"): checkpoint:human-verify is prohibited; automate the acceptance or leave the requirement open"
  fi

  # Plans use XML-like markup rather than XML.  This small state machine strips
  # comments, tokenizes tags across lines, and only examines a completed real
  # task opener.  It deliberately fails closed if a human-action task never
  # closes: an incomplete block must never hide acceptance-bearing content.
  awk '
    function is_human_action(tag) {
      return tag ~ /type[[:space:]]*=[[:space:]]*("checkpoint:human-action"|'"'"'checkpoint:human-action'"'"')/
    }
    function emit_block() {
      printf "%s%c", block, 0
      inside=0
      block=""
    }
    function consume_tag(tag) {
      if (inside) {
        block=block tag
        if (tag ~ /^<\/[[:space:]]*task[[:space:]]*>$/) emit_block()
      } else if (tag ~ /^<task([[:space:]]|>)/ && is_human_action(tag)) {
        inside=1
        block=tag
      }
    }
    {
      line=$0 ORS
      i=1
      while (i <= length(line)) {
        if (comment) {
          if (substr(line, i, 3) == "-->") { comment=0; i+=3 } else i++
          continue
        }
        if (substr(line, i, 4) == "<!--") { comment=1; i+=4; continue }
        ch=substr(line, i, 1)
        if (tag != "") {
          tag=tag ch
          i++
          if (ch == ">") { consume_tag(tag); tag="" }
        } else if (ch == "<") {
          tag="<"
          i++
        } else {
          if (inside) block=block ch
          i++
        }
      }
    }
    END {
      if (inside || (tag ~ /^<task([[:space:]]|>)/ && is_human_action(tag))) {
        printf "__RINDLE_UNCLOSED_HUMAN_ACTION__%c", 0
      }
    }
  ' "$plan" > "$blocks"

  while IFS= read -r -d '' block; do
    if [ "$block" = "__RINDLE_UNCLOSED_HUMAN_ACTION__" ]; then
      record_failure "$(basename "$plan"): unclosed human-action checkpoint fails closed"
    elif ! printf '%s' "$block" | grep -Eq '<purpose>(authorization|credential-bootstrap)</purpose>'; then
      record_failure "$(basename "$plan"): human-action checkpoint is not authorization-only"
    elif printf '%s' "$block" | grep -Eq '<(acceptance_criteria|verify|verification)>'; then
      record_failure "$(basename "$plan"): authorization checkpoint may not carry requirement acceptance or verification"
    fi
  done < "$blocks"
done

for validation in "$phase_dir"/*-VALIDATION.md; do
  [ -f "$validation" ] || continue

  if grep -n 'manual/external' "$validation" >/dev/null 2>&1; then
    record_failure "$(basename "$validation"): manual/external validation coverage is prohibited"
  fi

  manual_rows="$({
    awk '
      /^## Manual-Only Verifications/ {inside=1; next}
      inside && /^## / {exit}
      inside && /^\|/ {print}
    ' "$validation"
  } | grep -Ev '^\|[[:space:]]*(Behavior|[-: ]+)[[:space:]]*\|' || true)"

  if [ -n "$manual_rows" ]; then
    record_failure "$(basename "$validation"): manual-only verification row is prohibited"
  fi
done

if [ -s "$failures" ]; then
  echo "[automation-first] contract failed for $phase_dir" >&2
  while IFS= read -r failure; do echo "[BLOCK] $failure" >&2; done < "$failures"
  exit 1
fi

echo "[automation-first] automation-first contract passed for $phase_dir"
