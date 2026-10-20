#!/usr/bin/env bash
set -euo pipefail

MINIO_URL="${RINDLE_MINIO_URL:-http://localhost:9000}"
MINIO_BUCKET="${RINDLE_MINIO_BUCKET:-rindle-test}"
MINIO_ACCESS_KEY="${RINDLE_MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${RINDLE_MINIO_SECRET_KEY:-minioadmin}"
MINIO_RESET_BUCKET="${RINDLE_MINIO_RESET_BUCKET:-}"

# Upstream MinIO does not publish container images or download-site
# binaries. This digest-pinned image provides both the server and the `mc`
# client.
MINIO_IMAGE="cgr.dev/chainguard/minio@sha256:2136d593beacf4461187035eca949fe49abd589d5079735025c711ca58fee0c8"
MINIO_CONTAINER="${RINDLE_MINIO_CONTAINER:-rindle-minio-local}"

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
  local remainder hostport

  case "$MINIO_URL" in
    http://*)
      MINIO_SCHEME="http"
      remainder="${MINIO_URL#http://}"
      ;;
    https://*)
      MINIO_SCHEME="https"
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
    if [ "$MINIO_SCHEME" = "https" ]; then
      MINIO_PORT="443"
    else
      MINIO_PORT="80"
    fi
  fi
}

is_local_host() {
  case "$MINIO_HOST" in
    localhost|127.0.0.1) return 0 ;;
    *) return 1 ;;
  esac
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "$1 needs either a MinIO \`mc\` client on PATH or Docker to run $MINIO_IMAGE." >&2
    exit 1
  fi
}

# Prefer a MinIO client already on PATH (CI installs one from MINIO_IMAGE);
# otherwise run the client from the pinned image.
resolve_mc() {
  if command -v mc >/dev/null 2>&1 && mc --version 2>/dev/null | grep -q '^mc version'; then
    MC_MODE="host"
    MC_ENDPOINT="$MINIO_URL"
    return 0
  fi

  require_docker "Creating the MinIO bucket"
  MC_MODE="docker"
  MC_DOCKER_NET=(--network host)
  MC_ENDPOINT="$MINIO_URL"

  # Docker Desktop containers reach the host through host.docker.internal.
  if [ "$(uname -s)" = "Darwin" ] && is_local_host; then
    MC_DOCKER_NET=()
    MC_ENDPOINT="${MINIO_SCHEME}://host.docker.internal:${MINIO_PORT}"
  fi
}

mc_host_env() {
  local rest="${MC_ENDPOINT#*://}"
  printf '%s://%s:%s@%s' "${MC_ENDPOINT%%://*}" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" "${rest%%/*}"
}

# Runs `mc` against the `local` alias. An optional MC_MOUNT=<host file> is made
# readable at the same path inside the client container.
mc_run() {
  if [ "$MC_MODE" = "host" ]; then
    MC_HOST_local="$(mc_host_env)" mc "$@"
  else
    local mount=()
    if [ -n "${MC_MOUNT:-}" ]; then
      mount=(-v "${MC_MOUNT}:${MC_MOUNT}:ro")
    fi
    docker run --rm ${MC_DOCKER_NET[@]+"${MC_DOCKER_NET[@]}"} ${mount[@]+"${mount[@]}"} \
      -e "MC_HOST_local=$(mc_host_env)" --entrypoint mc "$MINIO_IMAGE" "$@"
  fi
}

ensure_bucket() {
  resolve_mc
  mc_run mb --ignore-existing "local/$MINIO_BUCKET" >/dev/null

  if [ -n "$MINIO_RESET_BUCKET" ]; then
    mc_run rm --recursive --force "local/$MINIO_BUCKET" >/dev/null 2>&1 || true
  fi

  ensure_bucket_cors
}

ensure_bucket_cors() {
  local cors_file
  cors_file="$(mktemp "${TMPDIR:-/tmp}/rindle-minio-cors.XXXXXX")"

  cat >"$cors_file" <<'EOF'
[
  {
    "AllowedOrigin": ["*"],
    "AllowedMethod": ["GET", "PUT", "POST", "HEAD", "DELETE", "PATCH", "OPTIONS"],
    "AllowedHeader": ["*"],
    "ExposeHeader": ["ETag", "x-amz-request-id", "x-amz-version-id"]
  }
]
EOF

  MC_MOUNT="$cors_file" mc_run cors set "local/$MINIO_BUCKET" "$cors_file" >/dev/null 2>&1 || true
  rm -f "$cors_file"
}

start_container_minio() {
  require_docker "Starting a local MinIO"

  if docker container inspect "$MINIO_CONTAINER" >/dev/null 2>&1; then
    docker start "$MINIO_CONTAINER" >/dev/null
  else
    docker run -d --name "$MINIO_CONTAINER" \
      -p "127.0.0.1:${MINIO_PORT}:9000" \
      -e MINIO_ROOT_USER="$MINIO_ACCESS_KEY" \
      -e MINIO_ROOT_PASSWORD="$MINIO_SECRET_KEY" \
      -e MINIO_API_CORS_ALLOW_ORIGIN='*' \
      "$MINIO_IMAGE" server /data >/dev/null
  fi

  if ! wait_for_minio 30; then
    echo "Failed to start local MinIO at $MINIO_URL" >&2
    docker logs --tail 40 "$MINIO_CONTAINER" >&2 || true
    exit 1
  fi

  ensure_bucket
}

parse_minio_endpoint

if wait_for_minio 1; then
  ensure_bucket
  exit 0
fi

if ! is_local_host; then
  echo "MinIO is unreachable at $MINIO_URL and auto-bootstrap only supports local endpoints." >&2
  exit 1
fi

start_container_minio
