#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCAN_DIR="${ROOT_DIR}/lib/rindle"

if [ ! -d "$SCAN_DIR" ]; then
  echo "AV hygiene scan root missing: $SCAN_DIR" >&2
  exit 1
fi

search() {
  local pattern=$1

  if command -v rg >/dev/null 2>&1; then
    rg -n -U -P "$pattern" "$SCAN_DIR" || true
  else
    grep -RInE "$pattern" "$SCAN_DIR" || true
  fi
}

check_absent() {
  local label=$1
  local pattern=$2
  local matches

  matches=$(search "$pattern")

  if [ -n "$matches" ]; then
    echo "FAIL: banned AV invocation surface detected (${label})" >&2
    echo "Scan root: $SCAN_DIR" >&2
    echo "$matches" >&2
    exit 1
  fi
}

check_absent "System.shell/2" 'System\.shell\s*\('
check_absent ":os.cmd/1" ':os\.cmd\s*\('
check_absent "raw Port.open/2" 'Port\.open\s*\('
check_absent "string-interpolated ffmpeg/ffprobe argv" '"[^"\n]*(ffmpeg|ffprobe)[^"\n]*#\{[^"\n]*"|\"[^\"\n]*#\{[^\"\n]*(ffmpeg|ffprobe)[^\"\n]*\"'

echo "OK: AV hygiene gate passed for $SCAN_DIR"
