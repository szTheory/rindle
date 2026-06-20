#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# BuildKit is required for the Dockerfile cache mounts (--mount=type=cache).
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# --- port helpers -------------------------------------------------------------
# The demo coexists with sibling lib demos and any native services (e.g. a local
# MinIO already holding :9000). We auto-bump to the next free loopback port so
# `up.sh` "just works" without manual env juggling. An explicitly-set env var is
# always respected verbatim.

# Ports already handed out during this run, so two services never collide on the
# same auto-bumped port (e.g. MinIO API and console both rolling off 9000/9001).
CLAIMED_PORTS=" "

# True if something is already LISTENing on 127.0.0.1:<port>.
port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP@127.0.0.1:"${port}" -sTCP:LISTEN >/dev/null 2>&1
  else
    # Fallback: a successful TCP connect means something is listening.
    (exec 3<>"/dev/tcp/127.0.0.1/${port}") >/dev/null 2>&1 && { exec 3>&- 3<&-; return 0; }
    return 1
  fi
}

# Resolve <var>: honor an explicit env value (claimed verbatim), else auto-bump
# from <default> to the first port that is neither listening nor already claimed.
# Assigns directly into <var> in the current shell so CLAIMED_PORTS state persists
# across calls (a command-substitution subshell would discard it).
resolve_port() {
  local var="$1" default="$2" current="${!1:-}" p
  if [[ -n "${current}" ]]; then
    CLAIMED_PORTS+="${current} "
    printf -v "${var}" '%s' "${current}"
    return 0
  fi
  for ((p = default; p < default + 50; p++)); do
    if [[ "${CLAIMED_PORTS}" != *" ${p} "* ]] && ! port_in_use "${p}"; then
      CLAIMED_PORTS+="${p} "
      printf -v "${var}" '%s' "${p}"
      return 0
    fi
  done
  printf 'demo: could not find a free port near %s\n' "${default}" >&2
  return 1
}

resolve_port COHORT_DEMO_PORT 4102
resolve_port COHORT_MINIO_PORT 9000
resolve_port COHORT_MINIO_CONSOLE_PORT 9001
export COHORT_DEMO_PORT COHORT_MINIO_PORT COHORT_MINIO_CONSOLE_PORT

# --- traefik (auto by default) ------------------------------------------------
# When a shared `proxy` network is present the app attaches to it and is reachable
# at http://<host> (default cohort.localhost) alongside sibling demos with no
# per-project port juggling. The app's loopback port stays published too, so a
# missing/stopped proxy never locks you out.
#
# COHORT_USE_TRAEFIK:
#   unset (default) -> AUTO: enable iff the shared `proxy` network already exists.
#   1               -> force on (warn + fall back to loopback if `proxy` absent).
#   0               -> force off (pure loopback ports).

TRAEFIK_HOST="${COHORT_TRAEFIK_HOST:-cohort.localhost}"
compose_files=(-f "${repo_root}/docker/compose.cohort-demo.yml")
USE_TRAEFIK=0

proxy_present() { docker network inspect proxy >/dev/null 2>&1; }

case "${COHORT_USE_TRAEFIK:-auto}" in
  1)
    if proxy_present; then
      USE_TRAEFIK=1
    else
      printf 'demo: COHORT_USE_TRAEFIK=1 but the shared "proxy" network is not present.\n' >&2
      printf '      Start your dev-proxy, or create it with:  docker network create proxy\n' >&2
      printf '      Falling back to fixed host ports.\n' >&2
    fi
    ;;
  0)
    # Explicit opt-out: pure loopback even if a proxy is running.
    USE_TRAEFIK=0
    ;;
  *)
    # auto (default): silently opt in when a shared proxy is already up.
    if proxy_present; then
      USE_TRAEFIK=1
    fi
    ;;
esac

if [[ "${USE_TRAEFIK}" == "1" ]]; then
  compose_files+=(-f "${repo_root}/docker/compose.cohort-demo.traefik.yml")
  export COHORT_TRAEFIK_HOST="${TRAEFIK_HOST}"
fi

# --- url map ------------------------------------------------------------------

print_urls() {
  printf '\n'
  printf 'app\n'
  if [[ "${USE_TRAEFIK}" == "1" ]]; then
    printf 'http://%s            (shared Traefik proxy)\n' "${TRAEFIK_HOST}"
    printf 'http://localhost:%s   (direct, fallback)\n' "${COHORT_DEMO_PORT}"
    printf 'admin console\n'
    printf 'http://%s/admin/rindle\n' "${TRAEFIK_HOST}"
  else
    printf 'http://localhost:%s\n' "${COHORT_DEMO_PORT}"
    printf 'admin console\n'
    printf 'http://localhost:%s/admin/rindle\n' "${COHORT_DEMO_PORT}"
  fi
  printf 'MinIO console\n'
  printf 'http://localhost:%s\n' "${COHORT_MINIO_CONSOLE_PORT}"
  if [[ "${USE_TRAEFIK}" == "1" ]]; then
    printf '\nTraefik auto-enabled (shared "proxy" network detected). COHORT_USE_TRAEFIK=0 to disable.\n'
  fi
  printf '\n'
}

if [[ "${1:-}" == "--print-urls" ]]; then
  print_urls
  exit 0
fi

print_urls

exec docker compose "${compose_files[@]}" up --build "$@"
