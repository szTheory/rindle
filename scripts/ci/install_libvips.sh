#!/usr/bin/env bash
# Install the libvips development package without allowing a slow Ubuntu mirror
# to hold a CI runner indefinitely. GitHub's mirror list provides failover, but
# apt's default per-request timeout is long enough to stall every matrix cell.
set -euo pipefail

readonly -a apt_options=(
  -o Acquire::Retries=2
  -o Acquire::http::Timeout=15
  -o Acquire::https::Timeout=15
)

for attempt in 1 2; do
  echo "[install_libvips] attempt ${attempt}/2"

  if sudo timeout --kill-after=15s 240s \
      apt-get "${apt_options[@]}" update &&
    sudo env DEBIAN_FRONTEND=noninteractive \
      timeout --kill-after=15s 240s \
      apt-get "${apt_options[@]}" install -y --no-install-recommends libvips-dev; then
    pkg-config --modversion vips
    exit 0
  fi

  if [ "$attempt" -lt 2 ]; then
    echo "[install_libvips] apt failed or timed out; retrying once after mirror failover" >&2
    sleep 5
  fi
done

echo "[install_libvips] failed after two bounded attempts" >&2
exit 1
