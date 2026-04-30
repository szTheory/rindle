#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

if [ "${RINDLE_PROBE_DEBUG:-0}" = "1" ]; then
  echo "hex_release_exists: cd: $(pwd)" >&2
fi

VERSION="${VERSION:?VERSION env var required (e.g., 0.1.4)}"
URL="https://hex.pm/api/packages/rindle/releases/$VERSION"
MIX_LOG="$(mktemp "${TMPDIR:-/tmp}/hex_release_exists_mix.XXXXXX")"
CURL_LOG="$(mktemp "${TMPDIR:-/tmp}/hex_release_exists_curl.XXXXXX")"

cleanup() {
  rm -f "$MIX_LOG" "$CURL_LOG"
}

trap cleanup EXIT

emit_result() {
  local value="$1"
  printf 'already_published=%s\n' "$value"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf 'already_published=%s\n' "$value" >> "$GITHUB_OUTPUT"
  fi
}

if mix hex.info rindle "$VERSION" >/dev/null 2>"$MIX_LOG"; then
  echo "hex_release_exists: mix hex.info rindle $VERSION exited 0 (published)" >&2
  emit_result true
  exit 0
else
  mix_exit=$?
fi
mix_stderr="$(cat "$MIX_LOG" 2>/dev/null || true)"

http_status=""
if http_status="$(curl -fsS -o /dev/null -w '%{http_code}' "$URL" 2>"$CURL_LOG")"; then
  curl_exit=0
else
  curl_exit=$?
fi
curl_stderr="$(cat "$CURL_LOG" 2>/dev/null || true)"

if [ "$curl_exit" -eq 0 ] && [ "$http_status" = "200" ]; then
  echo "hex_release_exists: curl returned HTTP 200 - fallback says published" >&2
  emit_result true
  exit 0
fi

if [ "$curl_exit" -eq 0 ] && [ "$http_status" = "404" ]; then
  if [ "$mix_exit" -eq 1 ]; then
    echo "hex_release_exists: mix exit 1 + curl 404 - version not published" >&2
  else
    echo "hex_release_exists: mix exit $mix_exit + curl 404 - version not published" >&2
  fi
  emit_result false
  exit 0
fi

echo "::error::hex_release_exists: both probes inconclusive - mix hex.info exited $mix_exit and curl probe for $URL was inconclusive." >&2
if [ -n "$mix_stderr" ]; then
  echo "mix hex.info stderr: $mix_stderr" >&2
fi
if [ -n "$curl_stderr" ]; then
  echo "curl stderr: $curl_stderr" >&2
fi
exit 1
