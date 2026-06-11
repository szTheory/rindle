#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

COHORT_DEMO_PORT="${COHORT_DEMO_PORT:-4102}"
COHORT_MINIO_PORT="${COHORT_MINIO_PORT:-9000}"
COHORT_MINIO_CONSOLE_PORT="${COHORT_MINIO_CONSOLE_PORT:-9001}"
export COHORT_DEMO_PORT COHORT_MINIO_PORT COHORT_MINIO_CONSOLE_PORT

print_urls() {
  printf '\n'
  printf 'app\n'
  printf 'http://localhost:%s\n' "${COHORT_DEMO_PORT}"
  printf 'admin console\n'
  printf 'http://localhost:%s/admin/rindle\n' "${COHORT_DEMO_PORT}"
  printf 'MinIO console\n'
  printf 'http://localhost:%s\n' "${COHORT_MINIO_CONSOLE_PORT}"
  printf '\n'
}

if [[ "${1:-}" == "--print-urls" ]]; then
  print_urls
  exit 0
fi

print_urls

exec docker compose -f "${repo_root}/docker/compose.cohort-demo.yml" up --build "$@"
