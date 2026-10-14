#!/usr/bin/env bash
# Closure gate for the Phase 133 landing branch (133-RESCOPE.md D-133-R4).
#
# Proves that a landing worktree carries exactly the manifest product files,
# byte-identical to the source branch, plus the source .planning/ tree; that no
# landed product file references excluded qualification tooling; and that every
# repo path a kept file references is in the manifest or unchanged from base.
#
# Usage:
#   check_phase_133_landing_closure.sh --source REF --landing DIR [--base REF] [--manifest PATH]
#   check_phase_133_landing_closure.sh --self-test
set -euo pipefail

default_manifest=".planning/phases/133-evidence-charter-and-live-truth/133-LANDING-MANIFEST.txt"

usage() {
  echo "usage: check_phase_133_landing_closure.sh --source REF --landing DIR [--base REF] [--manifest PATH] | --self-test" >&2
  exit 2
}

fail_count=0
fail() {
  echo "check_phase_133_landing_closure: $*" >&2
  fail_count=$((fail_count + 1))
}

blob_id() {
  # Prints the blob id of PATH at REF, or nothing when PATH is absent or not a blob.
  local repo="$1" ref="$2" path="$3"
  if [[ "$(git -C "${repo}" cat-file -t "${ref}:${path}" 2>/dev/null || true)" == "blob" ]]; then
    git -C "${repo}" rev-parse "${ref}:${path}"
  fi
}

run_check() {
  local source="" landing="" base="origin/main" manifest_rel="${default_manifest}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="${2:-}"; shift 2 ;;
      --landing) landing="${2:-}"; shift 2 ;;
      --base) base="${2:-}"; shift 2 ;;
      --manifest) manifest_rel="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -n "${source}" && -n "${landing}" ]] || usage
  git -C "${landing}" rev-parse --verify -q "${source}^{commit}" >/dev/null || { echo "check_phase_133_landing_closure: unknown source ${source}" >&2; exit 2; }
  git -C "${landing}" rev-parse --verify -q "${base}^{commit}" >/dev/null || { echo "check_phase_133_landing_closure: unknown base ${base}" >&2; exit 2; }

  local manifest="${landing}/${manifest_rel}"
  [[ -f "${manifest}" ]] || { echo "check_phase_133_landing_closure: missing manifest ${manifest}" >&2; exit 2; }

  local work
  work="$(mktemp -d)"
  trap 'rm -rf "${work}"' RETURN

  grep -Ev '^[[:space:]]*(#|$)' "${manifest}" | sed 's/[[:space:]]*$//' | sort -u >"${work}/manifest"

  # 1. Every manifest file is committed on the landing HEAD, byte-identical to source.
  local path landing_blob source_blob
  while IFS= read -r path; do
    source_blob="$(blob_id "${landing}" "${source}" "${path}")"
    landing_blob="$(blob_id "${landing}" HEAD "${path}")"
    if [[ -z "${source_blob}" ]]; then
      fail "manifest path absent on source: ${path}"
    elif [[ -z "${landing_blob}" ]]; then
      fail "manifest path missing on landing: ${path}"
    elif [[ "${landing_blob}" != "${source_blob}" ]]; then
      fail "manifest path differs from source: ${path}"
    fi
  done <"${work}/manifest"

  # 2. The landing .planning/ tree equals the source .planning/ tree.
  if ! git -C "${landing}" diff --quiet "${source}" HEAD -- .planning; then
    fail ".planning differs from source: $(git -C "${landing}" diff --name-only "${source}" HEAD -- .planning | head -5 | tr '\n' ' ')"
  fi

  # 3. Landed product changes are exactly manifest paths.
  git -C "${landing}" diff --name-only "${base}" HEAD -- . ':!.planning' | sort -u >"${work}/landed"
  while IFS= read -r path; do
    grep -Fxq -- "${path}" "${work}/manifest" || fail "landed path not in manifest: ${path}"
  done <"${work}/landed"

  # 4. No landed product file references an excluded basename. Excluded files are
  #    those the source adds over base outside the manifest and .planning/.
  git -C "${landing}" diff --name-only --diff-filter=A "${base}" "${source}" -- . ':!.planning' | sort -u >"${work}/added"
  : >"${work}/excluded"
  while IFS= read -r path; do
    grep -Fxq -- "${path}" "${work}/manifest" || basename "${path}" >>"${work}/excluded"
  done <"${work}/added"
  sort -u -o "${work}/excluded" "${work}/excluded"
  local name
  while IFS= read -r path; do
    git -C "${landing}" show "HEAD:${path}" >"${work}/content" 2>/dev/null || continue
    while IFS= read -r name; do
      [[ -n "${name}" ]] || continue
      if grep -Eq "(^|[^A-Za-z0-9_.-])$(printf '%s' "${name}" | sed 's/[.[\*^$+?(){}|]/\\&/g')([^A-Za-z0-9_-]|$)" "${work}/content"; then
        fail "landed ${path} references excluded ${name}"
      fi
    done <"${work}/excluded"
  done <"${work}/landed"

  # 5. Every repo path a kept file references is in the manifest or unchanged from base.
  local token base_blob
  while IFS= read -r path; do
    git -C "${landing}" show "HEAD:${path}" 2>/dev/null |
      grep -Eo '[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+' | sed 's#^\./##' | sort -u >"${work}/refs" || true
    while IFS= read -r token; do
      [[ "${token}" == .planning/* ]] && continue
      grep -Fxq -- "${token}" "${work}/manifest" && continue
      source_blob="$(blob_id "${landing}" "${source}" "${token}")"
      [[ -n "${source_blob}" ]] || continue
      base_blob="$(blob_id "${landing}" "${base}" "${token}")"
      if [[ "${source_blob}" != "${base_blob}" ]]; then
        fail "${path} references ${token}, changed on source but not in manifest"
      fi
    done <"${work}/refs"
  done <"${work}/manifest"

  if [[ "${fail_count}" -gt 0 ]]; then
    echo "check_phase_133_landing_closure: FAIL (${fail_count})" >&2
    return 1
  fi
  echo "check_phase_133_landing_closure: OK ($(wc -l <"${work}/manifest" | tr -d ' ') manifest paths, $(wc -l <"${work}/excluded" | tr -d ' ') excluded basenames)"
}

self_test() {
  local self tmp
  self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN
  local repo="${tmp}/repo" landing="${tmp}/landing"
  local m=".planning/manifest.txt"
  local g=(git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false)

  mkdir -p "${repo}"
  git -C "${repo}" init -q -b main
  mkdir -p "${repo}/scripts/ci" "${repo}/lib"
  printf 'echo protect v1\n' >"${repo}/scripts/setup_branch_protection.sh"
  printf 'defmodule A do end\n' >"${repo}/lib/a.ex"
  "${g[@]}" -C "${repo}" add -A && "${g[@]}" -C "${repo}" commit -qm base

  "${g[@]}" -C "${repo}" checkout -qb source
  mkdir -p "${repo}/.planning" "${repo}/scripts/maintainer"
  printf 'echo protect v2\n' >"${repo}/scripts/setup_branch_protection.sh"
  printf 'bash scripts/setup_branch_protection.sh\ncat lib/a.ex\n# json key phase_133_tool is not a file reference\n' >"${repo}/scripts/ci/kept.sh"
  printf 'console.log(1)\n' >"${repo}/scripts/maintainer/phase_133_tool.mjs"
  printf 'scripts/ci/kept.sh\nscripts/setup_branch_protection.sh\n' >"${repo}/${m}"
  "${g[@]}" -C "${repo}" add -A && "${g[@]}" -C "${repo}" commit -qm source

  local passed=0 failed=0
  expect() {
    local want="$1" label="$2"; shift 2
    local got=0 reason
    reason="$("${self}" --source source --landing "${landing}" --base main --manifest "${m}" 2>&1 >/dev/null | head -1)" || true
    [[ -z "${reason}" ]] || got=1
    if [[ "${want}" == pass && "${got}" == 0 ]] || [[ "${want}" == fail && "${got}" == 1 ]]; then
      passed=$((passed + 1)); echo "  ok   ${label}${reason:+ -> ${reason#check_phase_133_landing_closure: }}"
    else
      failed=$((failed + 1)); echo "  FAIL ${label} (expected ${want})"
    fi
  }
  reset_landing() {
    rm -rf "${landing}"
    git -C "${repo}" worktree prune
    git -C "${repo}" worktree add -q -b "landing-$1" "${landing}" main
    git -C "${landing}" checkout -q source -- scripts/ci/kept.sh scripts/setup_branch_protection.sh .planning
  }
  commit_landing() { "${g[@]}" -C "${landing}" add -A && "${g[@]}" -C "${landing}" commit -qm landing; }

  reset_landing good; commit_landing
  expect pass "faithful landing passes"

  reset_landing missing; git -C "${landing}" rm -q --cached scripts/ci/kept.sh; rm "${landing}/scripts/ci/kept.sh"; commit_landing
  expect fail "missing manifest file fails"

  reset_landing bytes; printf 'echo drift\n' >>"${landing}/scripts/ci/kept.sh"; commit_landing
  expect fail "byte drift fails"

  reset_landing excluded; printf 'node scripts/maintainer/phase_133_tool.mjs\n' >>"${landing}/scripts/ci/kept.sh"
  printf 'node scripts/maintainer/phase_133_tool.mjs\n' >>"${repo}/scripts/ci/kept.sh"
  "${g[@]}" -C "${repo}" commit -qam "source ref"; commit_landing
  expect fail "reference to excluded basename fails"
  "${g[@]}" -C "${repo}" revert --no-edit HEAD >/dev/null

  reset_landing absent
  printf 'scripts/ci/kept.sh\n' >"${landing}/${m}"
  git -C "${landing}" checkout -q main -- scripts/setup_branch_protection.sh
  printf 'scripts/ci/kept.sh\n' >"${repo}/${m}"; "${g[@]}" -C "${repo}" commit -qam "drop protection from manifest"
  commit_landing
  expect fail "referenced setup_branch_protection.sh changed on source but absent from manifest fails"
  "${g[@]}" -C "${repo}" revert --no-edit HEAD >/dev/null

  reset_landing stray; printf 'x\n' >"${landing}/lib/stray.ex"; commit_landing
  expect fail "landed path outside manifest fails"

  reset_landing planning; printf 'drift\n' >>"${landing}/${m}.extra"; commit_landing
  expect fail ".planning drift fails"

  echo "self-test: ${passed} passed, ${failed} failed"
  [[ "${failed}" -eq 0 ]]
}

case "${1:-}" in
  --self-test) self_test ;;
  "") usage ;;
  *) run_check "$@" ;;
esac
