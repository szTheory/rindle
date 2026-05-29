#!/usr/bin/env bash
set -euo pipefail

cd /app/examples/adoption_demo

wait_for() {
  local name="$1"
  local cmd="$2"
  local attempts="${3:-60}"

  for i in $(seq 1 "$attempts"); do
    if eval "$cmd"; then
      echo "[cohort-demo] ${name} ready"
      return 0
    fi
    echo "[cohort-demo] waiting for ${name} (${i}/${attempts})..."
    sleep 2
  done

  echo "[cohort-demo] timed out waiting for ${name}" >&2
  exit 1
}

wait_for postgres \
  "PGPASSWORD=postgres psql -h postgres -U postgres -d postgres -c '\\q'"

minio_health_url="${RINDLE_MINIO_URL:-http://localhost:9000}"
wait_for minio "curl -fsS '${minio_health_url%/}/minio/health/ready'"

mix ecto.create || true
mix ecto.migrate
mix rindle.migrate
mix run priv/repo/seeds.exs

exec mix phx.server
