#!/usr/bin/env bash
set -euo pipefail

MINIO_URL="${RINDLE_MINIO_URL:-http://localhost:9000}"
MINIO_BUCKET="${RINDLE_MINIO_BUCKET:-rindle-test}"
MINIO_ACCESS_KEY="${RINDLE_MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${RINDLE_MINIO_SECRET_KEY:-minioadmin}"

healthcheck_url() {
  printf '%s/minio/health/ready' "${MINIO_URL%/}"
}

wait_for_minio() {
  local attempts="${1:-30}"

  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$(healthcheck_url)" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

parse_minio_endpoint() {
  local scheme hostport remainder

  case "$MINIO_URL" in
    http://*)
      scheme="http"
      remainder="${MINIO_URL#http://}"
      ;;
    https://*)
      scheme="https"
      remainder="${MINIO_URL#https://}"
      ;;
    *)
      echo "Unsupported RINDLE_MINIO_URL: $MINIO_URL" >&2
      exit 1
      ;;
  esac

  hostport="${remainder%%/*}"

  if [[ "$hostport" == *:* ]]; then
    MINIO_HOST="${hostport%%:*}"
    MINIO_PORT="${hostport##*:}"
  else
    MINIO_HOST="$hostport"
    if [ "$scheme" = "https" ]; then
      MINIO_PORT="443"
    else
      MINIO_PORT="80"
    fi
  fi
}

platform_triplet() {
  local os arch

  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$arch" in
    arm64|aarch64)
      arch="arm64"
      ;;
    x86_64)
      arch="amd64"
      ;;
    *)
      echo "Unsupported architecture for local MinIO bootstrap: $arch" >&2
      exit 1
      ;;
  esac

  case "$os" in
    darwin|linux)
      printf '%s-%s' "$os" "$arch"
      ;;
    *)
      echo "Unsupported OS for local MinIO bootstrap: $os" >&2
      exit 1
      ;;
  esac
}

ensure_binary() {
  local target="$1"
  local url="$2"

  if [ -x "$target" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  curl -fsSLo "$target" "$url"
  chmod +x "$target"
}

ensure_bucket() {
  "$MC_BIN" alias set local "$MINIO_URL" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null
  "$MC_BIN" mb --ignore-existing "local/$MINIO_BUCKET" >/dev/null
}

start_embedded_minio() {
  local state_root pid_file log_file data_dir

  state_root="${TMPDIR:-/tmp}/rindle-minio"
  pid_file="$state_root/minio.pid"
  log_file="$state_root/minio.log"
  data_dir="$state_root/data"

  mkdir -p "$state_root" "$data_dir"

  if [ -f "$pid_file" ]; then
    local existing_pid
    existing_pid="$(cat "$pid_file")"
    if kill -0 "$existing_pid" >/dev/null 2>&1; then
      if wait_for_minio 5; then
        ensure_bucket
        return 0
      fi
    fi
    rm -f "$pid_file"
  fi

  MINIO_ROOT_USER="$MINIO_ACCESS_KEY" \
    MINIO_ROOT_PASSWORD="$MINIO_SECRET_KEY" \
    "$MINIO_BIN" server "$data_dir" --address "${MINIO_HOST}:${MINIO_PORT}" \
    >"$log_file" 2>&1 &

  echo "$!" >"$pid_file"

  if ! wait_for_minio 30; then
    echo "Failed to start local MinIO at $MINIO_URL" >&2
    tail -n 40 "$log_file" >&2 || true
    exit 1
  fi

  ensure_bucket
}

parse_minio_endpoint

if wait_for_minio 1; then
  triplet="$(platform_triplet)"
  tool_root="${TMPDIR:-/tmp}/rindle-minio-tools/$triplet"
  MC_BIN="${tool_root}/mc"
  ensure_binary "$MC_BIN" "https://dl.min.io/client/mc/release/${triplet}/mc"
  ensure_bucket
  exit 0
fi

case "$MINIO_HOST" in
  localhost|127.0.0.1)
    ;;
  *)
    echo "MinIO is unreachable at $MINIO_URL and auto-bootstrap only supports local endpoints." >&2
    exit 1
    ;;
esac

triplet="$(platform_triplet)"
tool_root="${TMPDIR:-/tmp}/rindle-minio-tools/$triplet"
MINIO_BIN="${tool_root}/minio"
MC_BIN="${tool_root}/mc"

ensure_binary "$MINIO_BIN" "https://dl.min.io/server/minio/release/${triplet}/minio"
ensure_binary "$MC_BIN" "https://dl.min.io/client/mc/release/${triplet}/mc"
start_embedded_minio
