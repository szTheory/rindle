#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

VERSION="${1:-${RINDLE_INSTALL_SMOKE_NETWORK_VERSION:-}}"

if [ -z "$VERSION" ]; then
  echo "public smoke test requires a published version as \$1 or RINDLE_INSTALL_SMOKE_NETWORK_VERSION" >&2
  exit 1
fi

echo "Running public smoke test for published Hex.pm version: $VERSION"

export RINDLE_INSTALL_SMOKE_NETWORK_VERSION="$VERSION"

bash scripts/ensure_minio.sh

mix test test/install_smoke/generated_app_smoke_test.exs --include minio
