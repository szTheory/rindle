#!/usr/bin/env bash
# Install Ubuntu packages without allowing a slow mirror to hold a CI runner
# indefinitely. The network policy is persisted so tools such as Playwright
# that invoke apt internally inherit the same fail-fast mirror behavior.
set -euo pipefail

readonly apt_config=/etc/apt/apt.conf.d/99rindle-ci-network

printf '%s\n' \
  'Acquire::Retries "2";' \
  'Acquire::http::Timeout "15";' \
  'Acquire::https::Timeout "15";' |
  sudo tee "$apt_config" >/dev/null

if [ "${1:-}" = "--configure-only" ]; then
  exit 0
fi

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <package> [<package> ...]" >&2
  exit 2
fi

echo "[install_apt_packages] attempt 1/2: $*"

if sudo env DEBIAN_FRONTEND=noninteractive \
  timeout --kill-after=15s 240s \
  apt-get install -y --no-install-recommends "$@"; then
  exit 0
fi

echo "[install_apt_packages] initial install failed or timed out; refreshing indexes before final attempt" >&2
sleep 5

if sudo timeout --kill-after=15s 240s apt-get update; then
  echo "[install_apt_packages] attempt 2/2: $*"

  if sudo env DEBIAN_FRONTEND=noninteractive \
    timeout --kill-after=15s 240s \
    apt-get install -y --no-install-recommends "$@"; then
    exit 0
  fi
fi

echo "[install_apt_packages] failed after two bounded attempts: $*" >&2
exit 1
