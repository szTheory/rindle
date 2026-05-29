#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec docker compose -f "${repo_root}/docker/compose.cohort-demo.yml" down "$@"
