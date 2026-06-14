#!/usr/bin/env bash
# Cold-start smoke for the Cohort Docker-compose demo stack.
#
# Phase 91 UAT discharge. The docker-compose boot path
# (scripts/demo/up.sh -> docker/compose.cohort-demo.yml -> docker/Dockerfile.cohort-demo)
# is the path that broke twice across phases — a prod-auth-guard compile failure
# and a stale Elixir pin — and was previously caught only by human UAT. Nothing
# in CI exercised it: the native e2e lane boots the app directly, never through
# Compose or the demo image build.
#
# This gate builds the demo image from a clean context, boots the full stack, and
# proves:
#   * the homepage serves HTTP 200 (the app actually compiled and booted), and
#   * the admin console + assets surface serve 200 with seeded rows (the
#     entrypoint runs migrations + seeds under `set -e` before `phx.server`, so a
#     seed failure means no server and this fails).
#
# Note on ports: CI runners start clean, so the default published ports apply
# (4102 / 9000 / 9001). The auto-bump port-contention case that `up.sh` solves is
# a local-dev concern and is not reproduced here; the build/boot/seed regression
# classes are.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# The CI override points the app at MinIO by service name (minio:9000) so the
# stack boots identically on Linux CI runners and Docker Desktop — the base
# compose's host.docker.internal path is Mac/Windows-only. See the override file.
compose=(docker compose -f docker/compose.cohort-demo.yml -f docker/compose.cohort-demo.ci.yml)
app_port="${COHORT_DEMO_PORT:-4102}"
base="http://localhost:${app_port}"

cleanup() {
  status=$?
  if [[ "${status}" -ne 0 ]]; then
    echo "::group::cohort-demo compose logs (failure)"
    "${compose[@]}" logs --no-color || true
    echo "::endgroup::"
  fi
  "${compose[@]}" down -v || true
  exit "${status}"
}
trap cleanup EXIT

echo "[smoke] building + starting the cohort-demo stack..."
"${compose[@]}" up -d --build

# The entrypoint waits for postgres + minio, migrates, seeds, then serves. Seeds
# take a moment, so poll the homepage until it answers (or time out).
echo "[smoke] waiting for the homepage to serve at ${base}/ ..."
ok=0
for _ in $(seq 1 90); do
  if curl -fsS -o /dev/null "${base}/"; then
    ok=1
    break
  fi
  sleep 2
done
if [[ "${ok}" -ne 1 ]]; then
  echo "[smoke] homepage did not come up at ${base}/ within timeout" >&2
  exit 1
fi

assert_200() {
  local path="$1" code
  code="$(curl -s -o /dev/null -w '%{http_code}' "${base}${path}")"
  if [[ "${code}" != "200" ]]; then
    echo "[smoke] expected 200 at ${path}, got ${code}" >&2
    exit 1
  fi
  echo "[smoke] ${path} -> 200"
}

assert_200 "/"
assert_200 "/admin/rindle"
assert_200 "/admin/rindle/assets"

# Seed proof: the assets surface must render at least one seeded asset row.
echo "[smoke] verifying seeded data on the admin assets surface..."
if ! curl -fsS "${base}/admin/rindle/assets" | grep -q 'data-rindle-admin-row="asset"'; then
  echo "[smoke] no seeded asset rows on /admin/rindle/assets — seed may have failed" >&2
  exit 1
fi

echo "[smoke] cohort-demo cold-start smoke passed."
