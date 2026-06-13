#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

compose_files=(-f "${repo_root}/docker/compose.cohort-demo.yml")
if [[ "${COHORT_USE_TRAEFIK:-0}" == "1" ]] && docker network inspect proxy >/dev/null 2>&1; then
  compose_files+=(-f "${repo_root}/docker/compose.cohort-demo.traefik.yml")
fi

exec docker compose "${compose_files[@]}" down "$@"
