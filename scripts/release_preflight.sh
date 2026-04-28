#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACKAGE_NAME=$(cd "$ROOT_DIR" && mix run --no-start -e 'project = Mix.Project.config(); IO.write("#{project[:app]}-#{project[:version]}")')
PACKAGE_ROOT="${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-$ROOT_DIR/$PACKAGE_NAME}"

cd "$ROOT_DIR"

MIX_ENV=dev mix hex.build --unpack --output "$PACKAGE_ROOT"

export RINDLE_INSTALL_SMOKE_PACKAGE_ROOT="$PACKAGE_ROOT"

MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs
MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs
MIX_ENV=test bash scripts/install_smoke.sh
MIX_ENV=dev mix docs --warnings-as-errors
bash scripts/assert_release_docs_html.sh
