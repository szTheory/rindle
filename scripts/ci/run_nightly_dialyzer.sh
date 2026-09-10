#!/usr/bin/env bash
# Execute one independently attributable supported-cell Dialyzer mode.
set -euo pipefail

mode="${1:-}"
if [ "$#" -ne 1 ] || { [ "$mode" != "fresh" ] && [ "$mode" != "restored" ]; }; then
  echo "usage: $0 <fresh|restored>" >&2
  exit 2
fi

mix_bin="${MIX_BIN:-mix}"
plt_dir="${PLT_DIR:-priv/plts}"
cleanup_log=false

if [ -z "$plt_dir" ] || [ "$plt_dir" = "/" ] || [ "$plt_dir" = "." ]; then
  echo "refusing unsafe PLT_DIR: ${plt_dir:-<empty>}" >&2
  exit 2
fi

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

reset_plt() {
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
