#!/usr/bin/env bash
# Install a static ffmpeg >= 6 for CI from BtbN/FFmpeg-Builds GitHub releases.
#
# Replaces FedericoCarboni/setup-ffmpeg@v3, which fetched ffmpeg from
# johnvansickle.com and intermittently failed with "Failed to get latest
# johnvansickle ffmpeg release", blocking merges.
#
# Source choice:
#   * BtbN publishes versioned static linux64 builds as GitHub release assets,
#     served from GitHub's CDN — reliable and retryable (unlike johnvansickle,
#     which returns HTTP 415 to CI runners).
#   * apt on ubuntu-22.04 only ships ffmpeg 4.4 — below the hard >= 6.0 gate in
#     lib/rindle/av/probe.ex.
#   * BtbN's `ffmpeg -version` reports the git tag (e.g. "ffmpeg version n7.1-...");
#     Rindle's probe accepts the optional `n` prefix.
set -euo pipefail

asset="ffmpeg-n7.1-latest-linux64-gpl-7.1.tar.xz"
url="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/${asset}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "[install_ffmpeg] downloading ${asset} ..."
curl -fL --retry 5 --retry-all-errors --retry-delay 5 -o "$tmp/ffmpeg.tar.xz" "$url"
tar -xf "$tmp/ffmpeg.tar.xz" -C "$tmp" --strip-components=1
sudo install -m 0755 "$tmp/bin/ffmpeg" /usr/local/bin/ffmpeg
sudo install -m 0755 "$tmp/bin/ffprobe" /usr/local/bin/ffprobe
hash -r

# Fail loudly if the build ever regresses below the required major version,
# instead of surfacing as a confusing AV-test failure deep in the run.
v=$(ffmpeg -version | sed -nE 's/^ffmpeg version n?([0-9]+).*/\1/p')
if [ "${v:-0}" -lt 6 ]; then
  echo "[install_ffmpeg] ffmpeg major ${v:-?} < 6 — Rindle requires >= 6.0 (lib/rindle/av/probe.ex)" >&2
  exit 1
fi
ffmpeg -version | head -1
