#!/usr/bin/env bash
# Adopter-facing docs hygiene gate: broken HexDocs link patterns and planning artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

failures=0

scan() {
  local pattern="$1"
  shift
  local output
  local scan_status

  if output="$(git grep -n -E -e "$pattern" -- "$@" 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  else
    scan_status=$?
  fi

  if [[ "$scan_status" -eq 1 ]]; then
    return 0
  fi

  echo "check_docs_links: scanner failed (git grep exit $scan_status): $output" >&2
  exit "$scan_status"
}

report() {
  echo "check_docs_links: $1" >&2
  failures=$((failures + 1))
}

echo "Checking adopter docs for GitHub-only .md link patterns in guides/..."

while IFS= read -r match; do
  report "guides should link siblings as .html, not .md: $match"
done < <(
  scan '\]\([^)]*guides/[^)]+\.md[^)]*\)' guides README.md RUNNING.md
)

while IFS= read -r match; do
  report "use readme.html / running.html on HexDocs, not parent .md paths: $match"
done < <(
  scan '\]\(\.\./(README|RUNNING)\.md\)' guides
)

echo "Checking for planning artifacts in adopter-facing docs..."

for pattern in 'Phase [0-9]+' 'D-[0-9]+' '\.planning' 'GSD Hygiene' '\$gsd-'; do
  while IFS= read -r match; do
    file="${match%%:*}"
    case "$file" in
      CHANGELOG.md|mix.exs|test/*|.planning/*|.github/*)
        continue
        ;;
      guides/release_publish.md)
        # Maintainer doc may reference workflow history; still flag Phase refs in body
        if [[ "$pattern" == 'Phase [0-9]+' ]] && [[ "$match" == *"Deviation log"* ]]; then
          continue
        fi
        ;;
    esac
    report "planning artifact ($pattern): $match"
  done < <(scan "$pattern" README.md RUNNING.md guides)
done

if [[ "$failures" -gt 0 ]]; then
  echo "check_docs_links: $failures issue(s) found" >&2
  exit 1
fi

echo "check_docs_links: OK"
