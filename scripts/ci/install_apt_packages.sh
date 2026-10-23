#!/usr/bin/env bash
# Install Ubuntu packages without allowing a slow mirror to hold a CI runner
# indefinitely. The network policy is persisted so tools such as Playwright
# that invoke apt internally inherit the same fail-fast mirror behavior.
set -euo pipefail

readonly apt_config=/etc/apt/apt.conf.d/99rindle-ci-network
readonly apt_mirrors="${RINDLE_APT_MIRRORS_FILE:-/etc/apt/apt-mirrors.txt}"

# Hosted runners randomly choose between their configured Ubuntu mirrors unless
# priority is explicit. Prefer the official HTTPS archive over the Azure mirror
# that can make steady progress too slowly to trigger the network timeout.
# Keep the runner's other mirrors available as fallbacks; signatures stay intact.
if [ -f "$apt_mirrors" ] &&
   grep -Eq '^https?://(azure\.archive|archive)\.ubuntu\.com/ubuntu/?([[:space:]]|$)' "$apt_mirrors"; then
  mirror_list="$(cat "$apt_mirrors")"
  {
    printf 'https://archive.ubuntu.com/ubuntu\tpriority:1\n'
    printf '%s\n' "$mirror_list" |
      awk '$1 !~ /^https?:\/\/archive\.ubuntu\.com\/ubuntu\/?$/'
  } | sudo tee "$apt_mirrors" >/dev/null
fi

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
