#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [ -z "${GITHUB_REF_NAME:-}" ]; then
  echo "::error::GITHUB_REF_NAME is not set. This script must run in a GitHub Actions context." >&2
  exit 1
fi

# Change to root dir so mix can find mix.exs
cd "$ROOT_DIR"

MIX_VERSION=$(mix run --no-start -e 'IO.write(Mix.Project.config()[:version])')
TAG_VERSION=${GITHUB_REF_NAME#v}

if [ "$MIX_VERSION" != "$TAG_VERSION" ]; then
  echo "::error::Git tag ($TAG_VERSION) does not match mix.exs version ($MIX_VERSION). Aborting publish." >&2
  exit 1
fi

echo "Version matches: $MIX_VERSION"