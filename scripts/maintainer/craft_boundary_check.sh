#!/usr/bin/env bash
# craft_boundary_check.sh - boundary guard for readability changes.
#
# A readability change must leave release, migration, lock, telemetry-contract and
# public-surface files untouched. This script rejects a change set that:
#   - touches priv/repo/migrations/, mix.lock, .release-please-manifest.json,
#     release-please-config.json, .github/workflows/release*.yml, CHANGELOG.md,
#     test/fixtures/public_surface.txt or test/rindle/contracts/telemetry_contract_test.exs
#   - changes the @version line, the `defp deps do` block or the `defp package do` block
#     of mix.exs (comments and other blocks may change).
#
# The change set is the committed diff from merge-base(BASE, HEAD) to HEAD plus any staged,
# unstaged or untracked (non-ignored) files in the working tree. mix.exs blocks are compared
# between merge-base(BASE, HEAD) and the working tree.
#
# Usage: craft_boundary_check.sh BASE      (run inside the repository to check)
# Exit codes: 0 clean | 1 rejected (each reason on stderr, prefixed REJECT:) | 64 usage.
#
# Safety: paths are read NUL-delimited and only compared as data; nothing from the diff or
# from file content is executed. Bash 3.2 compatible.

set -euo pipefail

usage() {
  echo "usage: craft_boundary_check.sh BASE" >&2
  exit 64
}

[ "$#" -eq 1 ] || usage
case "$1" in -h|--help|-*) usage ;; esac
BASE="$1"

if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "craft_boundary_check: not inside a git repository" >&2
  exit 64
fi
cd "${repo_root}"

if ! git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null; then
  echo "craft_boundary_check: unknown base ref: ${BASE}" >&2
  exit 64
fi
if ! MB="$(git merge-base "${BASE}" HEAD 2>/dev/null)"; then
  echo "craft_boundary_check: no merge base between ${BASE} and HEAD" >&2
  exit 64
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

forbidden() {
  case "$1" in
    priv/repo/migrations/*) return 0 ;;
    mix.lock|.release-please-manifest.json|release-please-config.json|CHANGELOG.md) return 0 ;;
    .github/workflows/release*.yml|.github/workflows/release*.yaml) return 0 ;;
    test/fixtures/public_surface.txt) return 0 ;;
    test/rindle/contracts/telemetry_contract_test.exs) return 0 ;;
  esac
  return 1
}

{
  git diff --no-renames --name-only -z "${MB}" HEAD --
  git diff --no-renames --name-only -z HEAD --
  git ls-files --others --exclude-standard -z
} >"${TMP}/paths"

REJECTS=0
reject() {
  echo "REJECT: $1: $2" >&2
  REJECTS=$((REJECTS + 1))
}

SEEN="${TMP}/seen"
: >"${SEEN}"
while IFS= read -r -d '' path; do
  if grep -qxF -- "${path}" "${SEEN}"; then continue; fi
  printf '%s\n' "${path}" >>"${SEEN}"
  if forbidden "${path}"; then
    reject "forbidden path" "${path}"
  fi
done <"${TMP}/paths"

# --- mix.exs guarded blocks -----------------------------------------------------------------
# block NAME prints the lines of `  defp NAME do` up to the first line that is exactly `  end`.
block() {
  awk -v open="  defp $1 do" '
    !inside && $0 == open { inside = 1 }
    inside { print }
    inside && $0 == "  end" { exit }
  '
}
version_line() {
  grep -E '^[[:space:]]*@version[[:space:]]' || true
}

if git cat-file -e "${MB}:mix.exs" 2>/dev/null; then
  git show "${MB}:mix.exs" >"${TMP}/mix_base.exs"
else
  : >"${TMP}/mix_base.exs"
fi
if [ -f mix.exs ]; then
  cp mix.exs "${TMP}/mix_head.exs"
else
  : >"${TMP}/mix_head.exs"
fi

for side in base head; do
  version_line <"${TMP}/mix_${side}.exs" >"${TMP}/version_${side}"
  block deps <"${TMP}/mix_${side}.exs" >"${TMP}/deps_${side}"
  block package <"${TMP}/mix_${side}.exs" >"${TMP}/package_${side}"
done

cmp -s "${TMP}/version_base" "${TMP}/version_head" || reject "mix.exs version" "the @version line changed"
cmp -s "${TMP}/deps_base" "${TMP}/deps_head" || reject "mix.exs deps" "the defp deps block changed"
cmp -s "${TMP}/package_base" "${TMP}/package_head" || reject "mix.exs package" "the defp package block changed"

if [ "${REJECTS}" -gt 0 ]; then
  exit 1
fi

echo "craft_boundary_check: ok (base ${BASE})"
exit 0
