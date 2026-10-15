#!/usr/bin/env bash
set -euo pipefail

expected_elixir='1.15.8'
expected_otp_release='26'
expected_erts=14.2.5.15
image='hexpm/elixir:1.15.8-erlang-26.2.5.21-debian-bookworm-20260824'
host_arch=$(uname -m)
case "$host_arch" in
  arm64|aarch64) container_platform='linux/arm64' ;;
  x86_64|amd64) container_platform='linux/amd64' ;;
  *) echo "Unsupported host architecture for the compatibility probe: $host_arch" >&2; exit 2 ;;
esac

assert_toolchain() {
  local actual_elixir actual_otp actual_erts
  actual_elixir=$(elixir -e 'IO.write(System.version())' 2>/dev/null || true)
  actual_otp=$(elixir -e 'IO.write(:erlang.system_info(:otp_release))' 2>/dev/null || true)
  actual_erts=$(elixir -e 'IO.write(:erlang.system_info(:version))' 2>/dev/null || true)
  actual_elixir=${actual_elixir%%$'\n'*}
  actual_otp=${actual_otp%%$'\n'*}
  actual_erts=${actual_erts%%$'\n'*}

  if [[ "$actual_elixir" != "$expected_elixir" || "$actual_otp" != "$expected_otp_release" || "$actual_erts" != "$expected_erts" ]]; then
    printf 'Expected Elixir %s / OTP %s / ERTS %s; found Elixir %s / OTP %s / ERTS %s\n' \
      "$expected_elixir" "$expected_otp_release" "$expected_erts" \
      "$actual_elixir" "$actual_otp" "$actual_erts" >&2
    return 1
  fi
}

run_coverage() {
  printf 'Reproducing Nightly coverage command on Elixir %s / OTP %s / ERTS %s\n' \
    "$expected_elixir" "$expected_otp_release" "$expected_erts"
  export MIX_ENV=test
  mix coveralls
}

if [[ "${1:-}" == '--inside-container' ]]; then
  shift
  [[ "$#" -eq 0 ]] || { echo 'usage: test_compat_115_26.sh [--inside-container]' >&2; exit 2; }
  assert_toolchain
  run_coverage
  exit
fi

if assert_toolchain; then
  [[ "$#" -eq 0 ]] || { echo 'usage: test_compat_115_26.sh' >&2; exit 2; }
  run_coverage
  exit
fi

if ! command -v docker >/dev/null 2>&1; then
  echo 'Docker is required to reproduce the Elixir 1.15.8 / OTP 26 coverage cell on this host.' >&2
  exit 2
fi
[[ "$#" -eq 0 ]] || { echo 'usage: test_compat_115_26.sh' >&2; exit 2; }

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
run_id="compat-115-26-$$"
network="${run_id}-network"
database="${run_id}-postgres"
cleanup() {
  docker rm -f "$database" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker network create "$network" >/dev/null
docker run -d --name "$database" --network "$network" --network-alias postgres \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=rindle_test \
  postgres:16-alpine >/dev/null

ready=0
for attempt in $(seq 1 60); do
  if docker run --rm --network "$network" postgres:16-alpine \
    pg_isready -h postgres -U postgres -d rindle_test >/dev/null 2>&1; then
    ready=1
    break
  fi
  if [[ "$attempt" == 60 ]]; then
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo 'PostgreSQL service did not become ready within 60 seconds.' >&2
  exit 1
fi

docker run --platform "$container_platform" --rm --network "$network" \
  -v "$repo_root:/workspace" -w /workspace \
  -e PGUSER=postgres -e PGPASSWORD=postgres -e PGHOST=postgres -e PGPORT=5432 \
  "$image" bash -euo pipefail -c '
    lock_backup=$(mktemp)
    cp mix.lock "$lock_backup"
    restore_mix_lock() { cp "$lock_backup" mix.lock; rm -f "$lock_backup"; }
    trap restore_mix_lock EXIT
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends sudo curl jq git ca-certificates xz-utils build-essential
    bash scripts/ci/install_apt_packages.sh libvips-dev >/dev/null
    if [[ "$(uname -m)" == aarch64 ]]; then
      ffmpeg_url=$(curl -fsSL https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest | jq -er ".assets[] | select(.name | contains(\"linuxarm64-gpl-9.0.tar.xz\")) | .browser_download_url")
      temp_ffmpeg=$(mktemp -d)
      curl -fsSL --retry 5 --retry-all-errors -o "$temp_ffmpeg/ffmpeg.tar.xz" "$ffmpeg_url"
      tar -xf "$temp_ffmpeg/ffmpeg.tar.xz" -C "$temp_ffmpeg" --strip-components=1
      install -m 0755 "$temp_ffmpeg/bin/ffmpeg" /usr/local/bin/ffmpeg
      install -m 0755 "$temp_ffmpeg/bin/ffprobe" /usr/local/bin/ffprobe
      rm -rf "$temp_ffmpeg"
    else
      bash scripts/ci/install_ffmpeg.sh
    fi
    export MIX_BUILD_PATH=/tmp/rindle-compat-115-26-build
    mix deps.get
    bash scripts/ci/test_compat_115_26.sh --inside-container
  '
