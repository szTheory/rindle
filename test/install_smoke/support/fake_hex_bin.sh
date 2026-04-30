#!/usr/bin/env bash
set -euo pipefail

shim_dir="${1:?shim dir required}"
mkdir -p "$shim_dir"

cat >"$shim_dir/mix" <<'MIXEOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${SHIM_RECORD_MIX_PWD:-0}" = "1" ]; then
  printf '%s\n' "$PWD" > "${SHIM_MIX_PWD_FILE:?missing SHIM_MIX_PWD_FILE}"
fi

if [ -n "${SHIM_MIX_STDERR:-}" ]; then
  printf '%s\n' "$SHIM_MIX_STDERR" >&2
fi

if [ -n "${SHIM_MIX_STDOUT:-}" ]; then
  printf '%s\n' "$SHIM_MIX_STDOUT"
fi

exit "${SHIM_MIX_EXIT:-0}"
MIXEOF

cat >"$shim_dir/curl" <<'CURLEOF'
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${SHIM_CURL_STDERR:-}" ]; then
  printf '%s\n' "$SHIM_CURL_STDERR" >&2
fi

if [ "${SHIM_CURL_EXIT:-0}" -ne 0 ]; then
  exit "${SHIM_CURL_EXIT}"
fi

printf '%s' "${SHIM_CURL_HTTP_STATUS:-200}"
CURLEOF

chmod +x "$shim_dir/mix" "$shim_dir/curl"
