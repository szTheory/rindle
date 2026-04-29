#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rindle-install-smoke-script-XXXXXX")
PACKAGE_NAME=$(cd "$ROOT_DIR" && mix run --no-start -e 'project = Mix.Project.config(); IO.write("#{project[:app]}-#{project[:version]}")')
PACKAGE_ROOT="${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-$WORK_DIR/$PACKAGE_NAME}"

cleanup() {
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

cd "$ROOT_DIR"

if [ -z "${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-}" ]; then
  mix hex.build --unpack --output "$PACKAGE_ROOT"
fi

bash "$SCRIPT_DIR/ensure_minio.sh"

if [ ! -d "$PACKAGE_ROOT" ]; then
  echo "install smoke package missing: $PACKAGE_ROOT" >&2
  exit 1
fi

export RINDLE_INSTALL_SMOKE_PACKAGE_ROOT="$PACKAGE_ROOT"

mix test test/install_smoke/generated_app_smoke_test.exs --include minio
