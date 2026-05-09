#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
cd "$ROOT_DIR"

VERSION="${1:-${RINDLE_INSTALL_SMOKE_NETWORK_VERSION:-}}"
PROFILE="${2:-${RINDLE_INSTALL_SMOKE_PROFILE:-all}}"

if [ -z "$VERSION" ]; then
  echo "public smoke test requires a published version as \$1 or RINDLE_INSTALL_SMOKE_NETWORK_VERSION" >&2
  exit 1
fi

case "$PROFILE" in
  all|image|video) ;;
  *)
    echo "unsupported RINDLE_INSTALL_SMOKE_PROFILE: $PROFILE" >&2
    exit 1
    ;;
esac

echo "Running public smoke test for published Hex.pm version: $VERSION (profile: $PROFILE)"

export MIX_ENV=test
unset RINDLE_INSTALL_SMOKE_PACKAGE_ROOT
export RINDLE_INSTALL_SMOKE_NETWORK_VERSION="$VERSION"
export RINDLE_INSTALL_SMOKE_PROFILE="$PROFILE"
export RINDLE_MINIO_RESET_BUCKET=1

if ! mix phx.new --version >/dev/null 2>&1; then
  echo "Installing Phoenix generator archive for install smoke..."
  mix archive.install hex phx_new --force
fi

bash "$SCRIPT_DIR/ensure_minio.sh"

mix test test/install_smoke/generated_app_smoke_test.exs --include minio
