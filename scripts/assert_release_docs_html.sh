#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOC_DIR="${1:-$ROOT_DIR/doc}"

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

rg -n '<title>Release Publishing' "$RELEASE_DOC" >/dev/null
rg -n '"title":"Release Publishing"' "$SIDEBAR_FILE" >/dev/null
rg -n '"id":"release_publish"' "$SIDEBAR_FILE" >/dev/null
rg -n 'href="release_publish\.html"' "$OPERATIONS_DOC" >/dev/null
rg -n 'Release Publishing' "$OPERATIONS_DOC" >/dev/null

if rg -n 'HEX_API_KEY|mix hex\.user|mix hex\.owner' "$README_DOC" "$GETTING_STARTED_DOC" >/dev/null; then
  echo "maintainer-only Hex publish instructions leaked into generated adopter docs" >&2
  exit 1
fi
