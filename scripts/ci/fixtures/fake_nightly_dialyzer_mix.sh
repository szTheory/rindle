#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$RINDLE_DIALYZER_COMMAND_LOG"
scenario="${RINDLE_DIALYZER_TEST_SCENARIO:?}"
attempts="$(grep -c '^dialyzer --format github$' "$RINDLE_DIALYZER_COMMAND_LOG" || true)"

if [ "$*" = "dialyzer --plt" ]; then
  case "$scenario" in
    build_failure|stale_build_failure)
      echo "PLT build failed" >&2
      exit 14
      ;;
    *)
      mkdir -p "$PLT_DIR"
      printf 'fresh fixture\n' > "$PLT_DIR/dialyzer.plt"
      exit 0
      ;;
  esac
fi

case "$scenario" in
  success|build_failure)
    echo "done (passed successfully)"
    exit 0
    ;;
  stale_then_success|stale_build_failure)
    if [ "$attempts" -eq 1 ]; then
      echo ":dialyzer.run error: Old PLT file $PLT_DIR/dialyzer.plt" >&2
      exit 11
    fi
    echo "done (passed successfully)"
    exit 0
    ;;
  stale_reanalysis_failure)
    if [ "$attempts" -eq 1 ]; then
      echo ":dialyzer.run error: Old PLT file $PLT_DIR/dialyzer.plt" >&2
      exit 11
    fi
    echo "post-rebuild analysis failed" >&2
    exit 17
    ;;
  missing)
    echo "No such file or directory: $PLT_DIR/dialyzer.plt" >&2
    exit 12
    ;;
  corrupt)
    echo "Could not read PLT file" >&2
    exit 13
    ;;
  genuine_warning)
    echo "lib/rindle/example.ex:1: Function broken/0 has no local return" >&2
    exit 15
    ;;
  unknown_failure)
    echo "unexpected analyzer failure" >&2
    exit 16
    ;;
  *)
    echo "unknown fake scenario: $scenario" >&2
    exit 99
    ;;
esac
