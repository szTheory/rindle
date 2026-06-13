#!/usr/bin/env bash
# Copy to scripts/demo/down.sh and replace tokens (see TEMPLATE.md).
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

compose_files=(-f "${repo_root}/docker/compose.__app__.yml")
if [[ "${__APP_ENV___USE_TRAEFIK:-0}" == "1" ]] && docker network inspect proxy >/dev/null 2>&1; then
  compose_files+=(-f "${repo_root}/docker/compose.__app__.traefik.yml")
fi

exec docker compose "${compose_files[@]}" down "$@"
