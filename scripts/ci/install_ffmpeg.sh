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
#     which returns HTTP 415 to CI runners). The rolling release removes old
#     major assets, so resolve the highest stable build instead of pinning a
#     filename that eventually becomes a permanent 404.
#   * apt on ubuntu-22.04 only ships ffmpeg 4.4 — below the hard >= 6.0 gate in
#     lib/rindle/av/probe.ex.
#   * BtbN's `ffmpeg -version` reports the git tag (e.g. "ffmpeg version n7.1-...");
#     Rindle's probe accepts the optional `n` prefix.
set -euo pipefail

release_api="https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest"

asset=$(
  curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 "$release_api" |
    jq -er '
      [
        .assets[].name
        | capture("^ffmpeg-n(?<major>[0-9]+)\\.(?<minor>[0-9]+)-latest-linux64-gpl-(?<version>[0-9]+\\.[0-9]+)\\.tar\\.xz$")
        | . as $asset
        | select($asset.version == ($asset.major + "." + $asset.minor))
      ]
      | max_by([(.major | tonumber), (.minor | tonumber)])
      | "ffmpeg-n\(.version)-latest-linux64-gpl-\(.version).tar.xz"
    '
)

url="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/${asset}"

if [ "${RINDLE_FFMPEG_RESOLVE_ONLY:-0}" = "1" ]; then
  printf '%s\n' "$asset"
  exit 0
fi

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
