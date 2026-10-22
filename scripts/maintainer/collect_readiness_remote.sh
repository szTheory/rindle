#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
export PYTHONDONTWRITEBYTECODE=1
exec python3 "$root/scripts/maintainer/collect_readiness_remote.py" "$@"
