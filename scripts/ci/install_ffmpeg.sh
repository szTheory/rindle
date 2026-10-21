#!/usr/bin/env bash
# Install a static ffmpeg >= 6 for CI from BtbN/FFmpeg-Builds GitHub releases.
#
# Replaces FedericoCarboni/setup-ffmpeg@v3, which fetched ffmpeg from
# johnvansickle.com and intermittently failed with "Failed to get latest
# johnvansickle ffmpeg release", blocking merges.
#
# Source choice:
#   * BtbN publishes versioned static linux64 builds as GitHub release assets,
#     served from GitHub's CDN. A dated release plus a reviewed SHA-256 pins
#     the consumed bytes; disappearance fails closed and requires a pin update.
#   * apt on ubuntu-22.04 only ships ffmpeg 4.4 — below the hard >= 6.0 gate in
#     lib/rindle/av/probe.ex.
#   * BtbN's `ffmpeg -version` reports the git tag (e.g. "ffmpeg version n7.1-...");
#     Rindle's probe accepts the optional `n` prefix.
set -euo pipefail

# Source: BtbN dated release and its checksums.sha256, independently matched
# to GitHub asset 659366397 digest on 2026-10-20. Update URL + digest together.
# No latest fallback: expired/replaced upstream assets must fail closed.
asset="ffmpeg-n9.0.2-29-g6dfaba896f-linux64-gpl-9.0.tar.xz"
url="https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-20-13-08/$asset"
archive_sha256="6a40dd0b5a020854573aa8bf11449694fabd4fdff1be09b43f6713ca8a2abab1"
if [ -n "${RINDLE_FFMPEG_RELEASE_API:-}" ]; then
  echo "[install_ffmpeg] release lookup overrides are not supported; update the reviewed pin" >&2
  exit 64
fi
if [ "${RINDLE_FFMPEG_RESOLVE_ONLY:-0}" = "1" ]; then
  printf '%s\n' "$asset" "$url" "$archive_sha256"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "[install_ffmpeg] downloading ${asset} ..."
curl -fL --retry 5 --retry-all-errors --retry-delay 5 -o "$tmp/ffmpeg.tar.xz" "$url"
printf '%s  %s\n' "$archive_sha256" "$tmp/ffmpeg.tar.xz" > "$tmp/checksums.sha256"
sha256sum -c "$tmp/checksums.sha256" >/dev/null
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
