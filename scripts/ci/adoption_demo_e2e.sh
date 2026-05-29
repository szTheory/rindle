#!/usr/bin/env bash
# Adoption demo Playwright lane — merge-blocking CI wrapper.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
demo_dir="${repo_root}/examples/adoption_demo"
work_dir=""

cleanup() {
  if [[ -n "${work_dir}" && -z "${RINDLE_DEMO_RINDLE_PATH:-}" ]]; then
    rm -rf "${work_dir}"
  fi
}

trap cleanup EXIT

cd "${repo_root}"

if [[ -z "${RINDLE_DEMO_RINDLE_PATH:-}" ]]; then
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/rindle-adoption-demo-XXXXXX")"
  package_name="$(mix run --no-start -e 'p = Mix.Project.config(); IO.write("#{p[:app]}-#{p[:version]}")')"
  mix hex.build --unpack --output "${work_dir}/${package_name}"
  export RINDLE_DEMO_RINDLE_PATH="${work_dir}/${package_name}"
fi

export MIX_ENV=test
export PHX_SERVER=1
export RINDLE_MINIO_RESET_BUCKET="${RINDLE_MINIO_RESET_BUCKET:-1}"
bash "${repo_root}/scripts/ensure_minio.sh"

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
npx playwright install --with-deps chromium
export ADOPTION_DEMO_PRESEEDED=1
npm run e2e
