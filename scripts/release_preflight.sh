#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACKAGE_ROOT="${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-}"
WORK_DIR=""
KEEP_ARTIFACT="${RINDLE_RELEASE_PREFLIGHT_KEEP_ARTIFACT:-}"

cleanup() {
  if [ -n "$WORK_DIR" ] && [ -z "$KEEP_ARTIFACT" ]; then
    rm -rf "$WORK_DIR"
  elif [ -n "$WORK_DIR" ]; then
    echo "Keeping unpacked artifact at $PACKAGE_ROOT"
  fi
}

trap cleanup EXIT

if [ -z "$PACKAGE_ROOT" ]; then
  WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rp-XXXXXX")
  PACKAGE_ROOT="$WORK_DIR/pkg"
fi

cd "$ROOT_DIR"

if ! mix phx.new --version >/dev/null 2>&1; then
  echo "Installing Phoenix generator archive for install smoke..."
  MIX_ENV=dev mix archive.install hex phx_new --force
fi

MIX_ENV=dev mix hex.build --unpack --output "$PACKAGE_ROOT"

export RINDLE_INSTALL_SMOKE_PACKAGE_ROOT="$PACKAGE_ROOT"

MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs
MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs
MIX_ENV=test bash scripts/install_smoke.sh
MIX_ENV=dev mix docs --warnings-as-errors
bash scripts/assert_release_docs_html.sh
