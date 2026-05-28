#!/usr/bin/env bash
# Adopter-facing docs hygiene gate: broken HexDocs link patterns and planning artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

failures=0

report() {
  echo "check_docs_links: $1" >&2
  failures=$((failures + 1))
}

echo "Checking adopter docs for GitHub-only .md link patterns in guides/..."

while IFS= read -r match; do
  report "guides should link siblings as .html, not .md: $match"
done < <(
  rg -n '\]\([^)]*guides/[^)]+\.md[^)]*\)' guides/ README.md RUNNING.md 2>/dev/null || true
)

while IFS= read -r match; do
  report "use readme.html / running.html on HexDocs, not parent .md paths: $match"
done < <(
  rg -n '\]\(\.\./(README|RUNNING)\.md\)' guides/ 2>/dev/null || true
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
  done < <(
    rg -n "$pattern" README.md RUNNING.md guides/*.md 2>/dev/null | rg -v 'guides/release_publish.md' || true
  )
done

if [[ "$failures" -gt 0 ]]; then
  echo "check_docs_links: $failures issue(s) found" >&2
  exit 1
fi

echo "check_docs_links: OK"
