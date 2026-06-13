#!/usr/bin/env bash
# Reusable demo launcher: auto-free-port selection, URL map, opt-in Traefik.
# Copy to scripts/demo/up.sh in your lib and replace the __TOKENS__ (see TEMPLATE.md).
set -euo pipefail

# Adjust the `../..` depth to reach your repo root from this script's location.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# ---- per-lib config (replace tokens) -----------------------------------------
APP="__APP__"                                            # project + hostname base
COMPOSE_FILE="${repo_root}/docker/compose.__app__.yml"
TRAEFIK_FILE="${repo_root}/docker/compose.__app__.traefik.yml"
# "ENV_VAR_NAME:PREFERRED_PORT" — first is the app, rest are auxiliary services.
PORT_SPECS=(
  "__APP_ENV___PORT:__APP_PORT__"
  "__APP_ENV___MINIO_PORT:__MINIO_PORT__"
  "__APP_ENV___MINIO_CONSOLE_PORT:__MINIO_CONSOLE_PORT__"
)
USE_TRAEFIK="${__APP_ENV___USE_TRAEFIK:-0}"
TRAEFIK_HOST="${__APP_ENV___TRAEFIK_HOST:-__APP__.localhost}"
# ------------------------------------------------------------------------------

CLAIMED=" "
port_in_use() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP@127.0.0.1:"$1" -sTCP:LISTEN >/dev/null 2>&1
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1 && { exec 3>&- 3<&-; return 0; }
    return 1
  fi
}

# Resolve and EXPORT <var>: explicit env wins; else auto-bump from <default>.
resolve_port() {
  local var="$1" default="$2" cur="${!1:-}" p
  if [[ -n "${cur}" ]]; then CLAIMED+="${cur} "; export "${var}=${cur}"; return 0; fi
  for ((p = default; p < default + 50; p++)); do
    if [[ "${CLAIMED}" != *" ${p} "* ]] && ! port_in_use "${p}"; then
      CLAIMED+="${p} "; export "${var}=${p}"; return 0
    fi
  done
  printf 'demo: no free port near %s\n' "${default}" >&2; exit 1
}

for spec in "${PORT_SPECS[@]}"; do resolve_port "${spec%%:*}" "${spec##*:}"; done

compose_files=(-f "${COMPOSE_FILE}")
if [[ "${USE_TRAEFIK}" == "1" ]]; then
  if docker network inspect proxy >/dev/null 2>&1; then
    compose_files+=(-f "${TRAEFIK_FILE}")
    export __APP_ENV___TRAEFIK_HOST="${TRAEFIK_HOST}"
  else
    printf 'demo: __APP_ENV___USE_TRAEFIK=1 but the shared "proxy" network is missing.\n' >&2
    printf '      Create it (docker network create proxy) or start your dev-proxy.\n' >&2
    printf '      Falling back to fixed host ports.\n' >&2
    USE_TRAEFIK=0
  fi
fi

app_port_var="${PORT_SPECS[0]%%:*}"
print_urls() {
  printf '\napp\n'
  if [[ "${USE_TRAEFIK}" == "1" ]]; then
    printf 'http://%s\n' "${TRAEFIK_HOST}"
  else
    printf 'http://localhost:%s\n' "${!app_port_var}"
  fi
  printf '\n'
}

[[ "${1:-}" == "--print-urls" ]] && { print_urls; exit 0; }
print_urls
exec docker compose "${compose_files[@]}" up --build "$@"
