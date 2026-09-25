#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
guard_root=$(mktemp -d "${TMPDIR:-/tmp}/phase133-package-guard.XXXXXX")
guard_bin="$guard_root/bin"
guard_log="$guard_root/invocations.log"
real_mix=$(command -v mix)
cleanup() { rm -rf -- "$guard_root"; }
trap cleanup EXIT HUP INT TERM
mkdir -p "$guard_bin"
: > "$guard_log"

cat > "$guard_bin/package-manager-blocked" <<'SH'
#!/usr/bin/env bash
set -eu
printf '%s %s\n' "${0##*/}" "$*" >> "$GSD_PHASE133_PACKAGE_GUARD_LOG"
echo "blocked unexpected package-manager invocation: ${0##*/} $*" >&2
exit 97
SH
chmod +x "$guard_bin/package-manager-blocked"

for name in npm npx pnpm yarn bun pip pip3 uv poetry cargo hex; do
  ln -s package-manager-blocked "$guard_bin/$name"
done

cat > "$guard_bin/mix" <<'SH'
#!/usr/bin/env bash
set -eu
case "${1:-}" in
  deps.get|deps.update|local.hex|local.rebar|archive.install)
    printf 'mix %s\n' "$*" >> "$GSD_PHASE133_PACKAGE_GUARD_LOG"
    echo "blocked unexpected Mix dependency installation: $*" >&2
    exit 97
    ;;
esac
exec "$GSD_PHASE133_REAL_MIX" "$@"
SH
chmod +x "$guard_bin/mix"

export PATH="$guard_bin:$PATH"
export GSD_PHASE133_PACKAGE_GUARD_LOG="$guard_log"
export GSD_PHASE133_REAL_MIX="$real_mix"
export ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-27.3}"
export ASDF_ELIXIR_VERSION="${ASDF_ELIXIR_VERSION:-1.17.3-otp-27}"
export MIX_ENV=test

# Prove the shims fail closed before using them as a guard around the safe,
# repository-native suites tied to Plans 33–42.
if npm install phase133-canary >/dev/null 2>&1; then
  echo "package-manager guard failed to block npm install" >&2
  exit 1
fi
if mix deps.get >/dev/null 2>&1; then
  echo "package-manager guard failed to block mix deps.get" >&2
  exit 1
fi
: > "$guard_log"

cd "$repo_root"

# Plans 33, 35, 37, 38, 40, 41, and 42 exercise the shell collectors. Census
# generation and validation are covered by the focused ExUnit test below.
bash scripts/ci/test_verify_nightly_run.sh

# Plans 34–42 exercise reconciliation, disclosure surfaces, package authority,
# and terminal-summary handling without remote lookup or remote mutation.
# The review/inventory gate suites bind to the live census written after this
# exact source subject; they run separately and cannot be nested in this
# subject-bound package proof without reading stale post-subject artifacts.
mix test \
  test/install_smoke/phase_133_reconciliation_test.exs \
  test/install_smoke/phase_133_completed_validation_test.exs \
  test/install_smoke/package_metadata_test.exs \
  test/install_smoke/phase_133_incident_atomicity_test.exs \
  test/install_smoke/evidence_census_test.exs \
  test/install_smoke/live_truth_parity_test.exs \
  test/install_smoke/phase_133_security_disclosure_test.exs \
  --exclude requires_verified_security_report \
  --seed 0

if [[ -s "$guard_log" ]]; then
  echo "package-manager guard observed forbidden invocations:" >&2
  cat "$guard_log" >&2
  exit 1
fi

printf '%s\n' \
  "package-manager invocation proof passed (Plans 33–42 local suites; remote commands excluded)" \
  "mapped findings: T-133-33-SC,T-133-34-SC,T-133-35-SC,T-133-36-SC,T-133-37-SC,T-133-38-SC,T-133-39-SC,T-133-40-SC,T-133-41-SC,T-133-42-SC"
