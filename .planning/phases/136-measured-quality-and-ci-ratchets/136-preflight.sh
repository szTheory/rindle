#!/usr/bin/env bash
# Phase 136 must not begin until Phase 135 has machine-verifiable closure.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

fail() { printf '[phase136-preflight] blocked: %s\n' "$1" >&2; exit 1; }

rg -q '^- \[x\] \*\*Phase 135: Repository and Code-Craft Consolidation\*\*' .planning/ROADMAP.md || fail 'Phase 135 Roadmap entry is incomplete'

for requirement in CRAFT-03 CRAFT-04 CRAFT-05 CRAFT-06 HYGIENE-03; do
  rg -q "^- \[x\] \*\*${requirement}\*\*:" .planning/REQUIREMENTS.md || fail "${requirement} is incomplete"
done

shopt -s nullglob
phase135_dirs=(.planning/phases/135-*)
test "${#phase135_dirs[@]}" -eq 1 || fail 'Expected exactly one Phase 135 directory'
verification="${phase135_dirs[0]}/135-VERIFICATION.md"
test -s "$verification" || fail 'Phase 135 verification artifact is absent'
rg -q '^verified:[[:space:]]+[^[:space:]]+' "$verification" || fail 'Phase 135 verification has no timestamp'
status="$(awk '/^---$/ { boundaries++; next } boundaries == 1 && /^status:/ { sub(/^status:[[:space:]]*/, ""); print; exit }' "$verification")"
case "$status" in
  passed|complete) ;;
  *) fail "Phase 135 verification status is not passed/complete: ${status:-missing}" ;;
esac

git ls-files --error-unmatch "$verification" >/dev/null 2>&1 || fail 'Phase 135 verification artifact is not tracked'
git diff --quiet HEAD -- "$verification" || fail 'Phase 135 verification artifact has uncommitted changes'
verification_commit="$(git log -1 --format=%H -- "$verification")"
test -n "$verification_commit" || fail 'Phase 135 verification has no committed provenance'
summary_files=("${phase135_dirs[0]}"/135-*-SUMMARY.md)
test "${#summary_files[@]}" -gt 0 || fail 'Phase 135 has no plan summaries'
for summary in "${summary_files[@]}"; do
  git ls-files --error-unmatch "$summary" >/dev/null 2>&1 || fail "Phase 135 summary is not tracked: $summary"
  git diff --quiet HEAD -- "$summary" || fail "Phase 135 summary has uncommitted changes: $summary"
  summary_commit="$(git log -1 --format=%H -- "$summary")"
  git merge-base --is-ancestor "$summary_commit" "$verification_commit" || fail "Phase 135 verification predates summary: $summary"
done

printf '[phase136-preflight] Phase 135 closure accepted from %s\n' "$verification"
