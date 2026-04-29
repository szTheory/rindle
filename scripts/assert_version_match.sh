#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Change to root dir so mix can find mix.exs
cd "$ROOT_DIR"

MIX_VERSION=$(mix run --no-start -e 'IO.write(Mix.Project.config()[:version])')
EXPECTED_VERSION="${RINDLE_EXPECTED_VERSION:-}"
RELEASE_REF="${RINDLE_RELEASE_TAG:-${GITHUB_REF_NAME:-}}"

if [ -n "$RELEASE_REF" ]; then
  TAG_VERSION=${RELEASE_REF#v}

  if [ "$MIX_VERSION" != "$TAG_VERSION" ]; then
    echo "::error::Release ref version ($TAG_VERSION) does not match mix.exs version ($MIX_VERSION). Aborting publish." >&2
    exit 1
  fi
fi

if [ -z "$EXPECTED_VERSION" ] && [ -z "$RELEASE_REF" ]; then
  echo "::error::Set RINDLE_EXPECTED_VERSION or RINDLE_RELEASE_TAG (or run in GitHub Actions with GITHUB_REF_NAME)." >&2
  exit 1
fi

if [ -n "$EXPECTED_VERSION" ] && [ "$MIX_VERSION" != "$EXPECTED_VERSION" ]; then
  echo "::error::Expected release version ($EXPECTED_VERSION) does not match mix.exs version ($MIX_VERSION). Aborting publish." >&2
  exit 1
fi

echo "Version matches: $MIX_VERSION"
