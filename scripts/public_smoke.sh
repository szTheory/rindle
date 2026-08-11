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
  all|image|video|tus|mux|gcs) ;;
  *)
    echo "unsupported RINDLE_INSTALL_SMOKE_PROFILE: $PROFILE" >&2
    exit 1
    ;;
esac

echo "Running public smoke test for published Hex.pm version: $VERSION (profile: $PROFILE)"

export MIX_ENV=test
export RINDLE_AV_USE_CGROUPS="${RINDLE_AV_USE_CGROUPS:-false}"
unset RINDLE_INSTALL_SMOKE_PACKAGE_ROOT
export RINDLE_INSTALL_SMOKE_NETWORK_VERSION="$VERSION"
export RINDLE_MINIO_RESET_BUCKET=1

if ! mix phx.new --version >/dev/null 2>&1; then
  echo "Installing Phoenix generator archive for install smoke..."
  mix archive.install hex phx_new --force
fi

bash "$SCRIPT_DIR/ensure_minio.sh"

run_install_smoke_profile() {
  local profile="$1"
  echo "Public smoke: profile=${profile}"
  export RINDLE_INSTALL_SMOKE_PROFILE="$profile"
  # D-08: Run the parent install-smoke suite with CI UNSET so test_helper.exs does
  # NOT engage JUnitFormatter for this crash-prone clean-room shell-out. On an
  # abnormal exit (e.g. an :epipe child crash), JUnitFormatter.handle_suite_finished/1
  # would try to write rindle-junit.xml during a teardown and surface an opaque
  # `File.Error ... bad argument` that MASKS the real crash (Pitfall 3, run 28246413418).
  # With CI unset the suite emits a CLEAN failure (the actual crash) instead. The child
  # generated app's own JUnit behavior and the normal CI JUnit suite are unaffected.
  env -u CI mix test test/install_smoke/generated_app_smoke_test.exs --include minio
}

if [ "$PROFILE" = "all" ]; then
  # Post-publish proof mirrors merge-blocking package-consumer lanes (image + AV).
  for profile in image video; do
    run_install_smoke_profile "$profile"
  done
else
  run_install_smoke_profile "$PROFILE"
fi
