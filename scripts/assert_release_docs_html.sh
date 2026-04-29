#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DOC_DIR="${1:-$ROOT_DIR/doc}"

search() {
  local pattern=$1
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@" >/dev/null
  else
    grep -nE "$pattern" "$@" >/dev/null
  fi
}

if [ ! -d "$DOC_DIR" ]; then
  echo "docs output missing: $DOC_DIR" >&2
  exit 1
fi

RELEASE_DOC="$DOC_DIR/release_publish.html"
OPERATIONS_DOC="$DOC_DIR/operations.html"
README_DOC="$DOC_DIR/readme.html"
GETTING_STARTED_DOC="$DOC_DIR/getting_started.html"
SIDEBAR_FILE=$(find "$DOC_DIR/dist" -maxdepth 1 -name 'sidebar_items-*.js' | head -n 1)

if [ ! -f "$RELEASE_DOC" ]; then
  echo "release guide HTML missing: $RELEASE_DOC" >&2
  exit 1
fi

if [ ! -f "$OPERATIONS_DOC" ]; then
  echo "operations HTML missing: $OPERATIONS_DOC" >&2
  exit 1
fi

if [ ! -f "$README_DOC" ] || [ ! -f "$GETTING_STARTED_DOC" ]; then
  echo "canonical adopter docs HTML missing in $DOC_DIR" >&2
  exit 1
fi

if [ -z "$SIDEBAR_FILE" ]; then
  echo "sidebar metadata JS missing under $DOC_DIR/dist" >&2
  exit 1
fi

search '<title>Release Publishing' "$RELEASE_DOC"
search '"title":"Release Publishing"' "$SIDEBAR_FILE"
search '"id":"release_publish"' "$SIDEBAR_FILE"
search 'href="release_publish\.html"' "$OPERATIONS_DOC"
search 'Release Publishing' "$OPERATIONS_DOC"

if search 'HEX_API_KEY|mix hex\.user|mix hex\.owner' "$README_DOC" "$GETTING_STARTED_DOC"; then
  echo "maintainer-only Hex publish instructions leaked into generated adopter docs" >&2
  exit 1
fi
