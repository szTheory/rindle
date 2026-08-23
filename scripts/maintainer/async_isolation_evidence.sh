#!/usr/bin/env bash
# Local-only evidence runner for issue #42. It deliberately never changes CI topology.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="${repo_root}/.planning/phases/125-behavioral-test-support"
seeds=(0 17 43 71 101 131 173 211 257 307 353 401 449 503 557 601 653 701 757 809 863 911 967 1013 1061)
coverage_argv=(mix coveralls.multiple --type local --type json --seed SEED --slowest 20)
report_schema=(iteration seed sha toolchain argv exit_status failure_location)

usage() {
  echo "usage: $0 --validate | --report .planning/phases/125-behavioral-test-support/<new-report>.jsonl" >&2
  exit 64
}

validate() {
  local joined_seeds
  joined_seeds="$(IFS=,; echo "${seeds[*]}")"

  printf '{"kind":"matrix","seeds":[%s]}\n' "${joined_seeds}"
  printf '{"kind":"argv","argv":["mix","coveralls.multiple","--type","local","--type","json","--seed","SEED","--slowest","20"]}\n'
  printf '{"kind":"report_schema","fields":["iteration","seed","sha","toolchain","argv","exit_status","failure_location"]}\n'
}

failure_location() {
  local output_file="$1"
  local exception location

  exception="$(grep -Eom1 '\*\* \([A-Za-z0-9_.]+\)' "${output_file}" | sed -E 's/.*\(([A-Za-z0-9_.]+)\).*/\1/' || true)"
  location="$(grep -Eom1 '[[:alnum:]_./-]+\.exs?:[0-9]+' "${output_file}" | sed -E 's#.*/##' || true)"

  if [ -n "${exception}" ] && [ -n "${location}" ]; then
    printf '%s:%s' "${exception}" "${location}"
  elif [ -n "${exception}" ]; then
    printf '%s' "${exception}"
  elif [ -n "${location}" ]; then
    printf '%s' "${location}"
  else
    printf 'command_failed'
  fi
}

if [ "$#" -eq 1 ] && [ "$1" = "--validate" ]; then
  validate
  exit 0
fi

if [ "$#" -ne 2 ] || [ "$1" != "--report" ]; then
  usage
fi

report_path="$2"
cd "${repo_root}"

case "${report_path}" in
  /*) ;;
  *) report_path="${repo_root}/${report_path}" ;;
esac

case "${report_path}" in
  "${phase_dir}"/*.jsonl) ;;
  *)
    echo "report target must be a new .jsonl file under ${phase_dir}" >&2
    exit 64
    ;;
esac

if [ -e "${report_path}" ]; then
  echo "report target already exists: ${report_path}" >&2
  exit 64
fi

if [ ! -d "${phase_dir}" ]; then
  echo "phase directory is missing: ${phase_dir}" >&2
  exit 64
fi

umask 077
sha="$(git rev-parse HEAD)"
toolchain="$(elixir -v | awk '/Elixir / { print "elixir-" $2; exit }')"
command='mix coveralls.multiple --type local --type json --seed SEED --slowest 20'
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/rindle-async-isolation.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

printf '{"kind":"async_isolation_evidence","schema":["iteration","seed","sha","toolchain","argv","exit_status","failure_location"]}\n' > "${report_path}"

for index in "${!seeds[@]}"; do
  iteration=$((index + 1))
  seed="${seeds[${index}]}"
  output_file="${tmp_dir}/iteration-${iteration}.out"

  if mix coveralls.multiple --type local --type json --seed "${seed}" --slowest 20 > "${output_file}" 2>&1; then
    status=0
    location=null
  else
    status=$?
    location="$(failure_location "${output_file}")"
  fi

  if [ "${location}" = null ]; then
    printf '{"iteration":%s,"seed":%s,"sha":"%s","toolchain":"%s","argv":"%s","exit_status":%s,"failure_location":null}\n' \
      "${iteration}" "${seed}" "${sha}" "${toolchain}" "${command/SEED/${seed}}" "${status}" >> "${report_path}"
  else
    printf '{"iteration":%s,"seed":%s,"sha":"%s","toolchain":"%s","argv":"%s","exit_status":%s,"failure_location":"%s"}\n' \
      "${iteration}" "${seed}" "${sha}" "${toolchain}" "${command/SEED/${seed}}" "${status}" "${location}" >> "${report_path}"
  fi

  if [ "${status}" -ne 0 ]; then
    echo "async isolation evidence failed at iteration ${iteration} (seed ${seed}); see sanitized report ${report_path}" >&2
    exit "${status}"
  fi
done
