#!/usr/bin/env bash
# Execute one independently attributable supported-cell Dialyzer mode.
set -euo pipefail

mode="${1:-}"
if [ "$#" -ne 1 ] || { [ "$mode" != "fresh" ] && [ "$mode" != "restored" ]; }; then
  echo "usage: $0 <fresh|restored>" >&2
  exit 2
fi

mix_bin="${MIX_BIN:-mix}"
cleanup_log=false

if [ "${PLT_DIR+x}" = "x" ]; then
  echo "refusing caller-supplied PLT_DIR" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
approved_plt_root="${repo_root}/priv"
plt_dir="${approved_plt_root}/plts"
export PLT_DIR="$plt_dir"
cd "$repo_root"

if [ -n "${DIALYZER_LOG:-}" ]; then
  dialyzer_log="$DIALYZER_LOG"
else
  dialyzer_log="$(mktemp "${TMPDIR:-/tmp}/rindle-dialyzer.XXXXXX")"
  cleanup_log=true
fi

cleanup() {
  if [ "$cleanup_log" = true ]; then
    rm -f -- "$dialyzer_log"
  fi
}
trap cleanup EXIT

resolve_physical_path() {
  local path="$1" parent base

  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
    return
  fi

  parent="$(dirname "$path")"
  base="$(basename "$path")"
  [ -d "$parent" ] || return 1
  printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$base"
}

require_contained_plt_dir() {
  local physical_repo physical_root physical_candidate

  if [ "$plt_dir" != "${repo_root}/priv/plts" ]; then
    echo "refusing unsafe PLT directory: priv/plts" >&2
    return 2
  fi

  physical_repo="$(resolve_physical_path "$repo_root")" || {
    echo "refusing unsafe PLT directory: repository" >&2
    return 2
  }
  physical_root="$(resolve_physical_path "$approved_plt_root")" || {
    echo "refusing unsafe PLT directory: priv" >&2
    return 2
  }
  physical_candidate="$(resolve_physical_path "$plt_dir")" || {
    echo "refusing unsafe PLT directory: priv/plts" >&2
    return 2
  }

  case "$physical_root" in
    "$physical_repo"/*) ;;
    *)
      echo "refusing unsafe PLT directory: priv" >&2
      return 2
      ;;
  esac

  if [ "$physical_candidate" != "${physical_root}/plts" ]; then
    echo "refusing unsafe PLT directory: priv/plts" >&2
    return 2
  fi

  case "$physical_candidate" in
    "$physical_repo"/*) ;;
    *)
      echo "refusing unsafe PLT directory: priv/plts" >&2
      return 2
      ;;
  esac
}

reset_plt() {
  require_contained_plt_dir
  rm -rf -- "$plt_dir"
  mkdir -p -- "$plt_dir"
}

build_plt() {
  echo "nightly-dialyzer mode=${mode} action=build-plt"
  "$mix_bin" dialyzer --plt
}

run_analysis() {
  local attempt="$1" append_flag=""
  if [ "$attempt" -gt 1 ]; then
    append_flag="-a"
  fi

  echo "nightly-dialyzer mode=${mode} attempt=${attempt} action=analyze"
  if "$mix_bin" dialyzer --format github 2>&1 | tee $append_flag "$dialyzer_log"; then
    return 0
  else
    return "${PIPESTATUS[0]}"
  fi
}

# Reject an escaped physical PLT path before either mode can invoke Mix. The
# reset helper repeats the same guard immediately before recursive deletion.
require_contained_plt_dir

if [ "$mode" = "fresh" ]; then
  reset_plt
  build_plt
  run_analysis 1
  exit $?
fi

analysis_status=0
run_analysis 1 || analysis_status=$?
if [ "$analysis_status" -eq 0 ]; then
  exit 0
fi

# This is intentionally the one recovery fingerprint. Missing/corrupt PLTs,
# ordinary warnings, and unknown failures retain their original nonzero status.
if ! grep -Eq '^:dialyzer\.run error: Old PLT file .+$' "$dialyzer_log"; then
  exit "$analysis_status"
fi

echo "nightly-dialyzer mode=restored attempt=1 fingerprint=old-plt recovery=rebuild-once"
reset_plt
build_plt
run_analysis 2
