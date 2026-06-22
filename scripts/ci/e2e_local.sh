#!/usr/bin/env bash
# Faithful local repro of the adoption-demo Playwright E2E lane.
#
# "Faithful" == SAME pinned browser image both sides (D-10): this script and the
# ci.yml `adoption-demo-e2e` lane both run the browser inside
# `mcr.microsoft.com/playwright:v1.57.0-noble`. The container tag IS the font +
# browser pin (D-11), so there is no separate system-font install — the image
# carries the exact Chromium + fonts CI uses. Kills the "green in CI, red
# locally" class by construction.
#
# Networking (RESEARCH Open-Q1): the Phoenix demo server runs on the HOST; the
# browser-in-container reaches it over the host network. The demo's
# playwright.config.js fixes baseURL to `http://localhost:<port>`, so the
# container shares the host network namespace (`--network=host`) — container
# `localhost` then resolves to the host server with no baseURL edit. The demo's
# ADOPTION_DEMO_REUSE_SERVER knob keeps Playwright from spawning its own
# webServer (it reuses the host one). `--network=host` is a Linux/CI primitive;
# on Docker Desktop (macOS/Windows) it is best-effort — CI (the source of truth)
# runs on Linux runners.
#
# Run: bash scripts/ci/e2e_local.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
demo_dir="${repo_root}/examples/adoption_demo"

# Same pinned image used by the ci.yml adoption-demo-e2e lane (the invariant).
# CI exports PLAYWRIGHT_IMAGE with the identical tag; locally it defaults here.
PLAYWRIGHT_IMAGE="${PLAYWRIGHT_IMAGE:-mcr.microsoft.com/playwright:v1.57.0-noble}"
demo_port="${ADOPTION_DEMO_BROWSER_PORT:-4102}"

server_pid=""
cleanup() {
  if [[ -n "${server_pid}" ]]; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

cd "${repo_root}"

# --- Host-side demo bring-up (mirrors scripts/ci/adoption_demo_e2e.sh) ---------
export MIX_ENV=test
cd "${demo_dir}"
mix deps.get --only test
mix assets.vendor
mix ecto.drop --quiet || true
mix ecto.create
mix ecto.migrate
mix rindle.migrate
PHX_SERVER= mix run priv/repo/seeds.exs

npm ci
npm run vendor:js

# --- Start Phoenix on the host so the containerized browser can reach it ------
PORT="${demo_port}" PHX_SERVER=true MIX_ENV=test mix phx.server &
server_pid=$!

# Wait for the host server to accept connections before launching the browser.
for _ in $(seq 1 60); do
  if curl -sf "http://localhost:${demo_port}/" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# --- Browser-in-container against the SAME pinned image as CI (D-10) ----------
# --network=host: container localhost == host Phoenix server (no baseURL edit).
# The demo's reuse-server knob keeps Playwright from spawning its own webServer.
docker run --rm --ipc=host --network=host \
  -v "${repo_root}:/work" -w /work/examples/adoption_demo \
  -e CI=1 \
  -e ADOPTION_DEMO_PRESEEDED=1 \
  -e ADOPTION_DEMO_REUSE_SERVER=1 \
  -e ADOPTION_DEMO_BROWSER_PORT="${demo_port}" \
  "${PLAYWRIGHT_IMAGE}" \
  sh -c "npm ci && ADOPTION_DEMO_BROWSER_PORT=${demo_port} npx playwright test --config=playwright.config.js"
