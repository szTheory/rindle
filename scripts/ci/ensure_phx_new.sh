#!/usr/bin/env bash
set -euo pipefail

PHX_NEW_VERSION="1.8.9"
EXPECTED_VERSION="Phoenix installer v${PHX_NEW_VERSION}"

installed_version=$(mix phx.new --version 2>/dev/null || true)

if [ "$installed_version" = "$EXPECTED_VERSION" ]; then
  exit 0
fi

if [ -n "$installed_version" ]; then
  echo "Replacing incompatible Phoenix generator: ${installed_version}" >&2
fi

echo "Installing ${EXPECTED_VERSION} for generated-app proof..."
MIX_ENV=dev mix archive.install hex phx_new "$PHX_NEW_VERSION" --force

installed_version=$(mix phx.new --version 2>/dev/null || true)

if [ "$installed_version" != "$EXPECTED_VERSION" ]; then
  echo "Phoenix generator mismatch: expected '${EXPECTED_VERSION}', got '${installed_version:-missing}'" >&2
  exit 1
fi
