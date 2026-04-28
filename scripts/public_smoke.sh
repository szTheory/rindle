#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

VERSION=$(mix run --no-start -e 'IO.write(Mix.Project.config()[:version])')

echo "Running public smoke test for network version: $VERSION"

export RINDLE_INSTALL_SMOKE_NETWORK_VERSION="$VERSION"

mix test test/install_smoke/generated_app_smoke_test.exs --include minio
