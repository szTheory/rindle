#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rindle-install-smoke-script-XXXXXX")
PACKAGE_NAME=$(cd "$ROOT_DIR" && mix run --no-start -e 'project = Mix.Project.config(); IO.write("#{project[:app]}-#{project[:version]}")')
PACKAGE_ROOT="${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-$WORK_DIR/$PACKAGE_NAME}"
PROFILE="${1:-${RINDLE_INSTALL_SMOKE_PROFILE:-image}}"

cleanup() {
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

cd "$ROOT_DIR"

case "$PROFILE" in
  all|image|video|tus|mux|gcs) ;;
  *)
    echo "unsupported install smoke profile: $PROFILE" >&2
    exit 1
    ;;
esac

if [ -z "${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-}" ]; then
  mix hex.build --unpack --output "$PACKAGE_ROOT"
fi

unset RINDLE_INSTALL_SMOKE_NETWORK_VERSION
export RINDLE_INSTALL_SMOKE_PROFILE="$PROFILE"

if [ "$PROFILE" != "gcs" ]; then
  export RINDLE_MINIO_RESET_BUCKET=1
  bash "$SCRIPT_DIR/ensure_minio.sh"
fi

if [ ! -d "$PACKAGE_ROOT" ]; then
  echo "install smoke package missing: $PACKAGE_ROOT" >&2
  exit 1
fi

export RINDLE_INSTALL_SMOKE_PACKAGE_ROOT="$PACKAGE_ROOT"

if [ "$PROFILE" = "gcs" ]; then
  mix test test/install_smoke/generated_app_smoke_test.exs
  status=$?
else
  mix test test/install_smoke/generated_app_smoke_test.exs --include minio
  status=$?
fi

if [ "$status" -ne 0 ] && [ "$PROFILE" = "tus" ]; then
  hint_file="$ROOT_DIR/tmp/install_smoke_tus_last_run.json"

  if [ -f "$hint_file" ]; then
    echo "tus install-smoke artifacts:" >&2
    cat "$hint_file" >&2
  fi
fi

exit "$status"
