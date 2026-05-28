#!/usr/bin/env bash
set -euo pipefail

MODE="local"
RUN_MIX_CI=0
REMOTE="${RINDLE_HYGIENE_REMOTE:-origin}"

usage() {
  cat <<'EOF'
Usage: repo_hygiene_check.sh [--ci] [--with-mix-ci]

Checks whether the repo is in a disciplined release-prep state.

Modes:
  --ci           Run only repo-owned drift checks that GitHub can prove.
  --with-mix-ci  Also run local mix test (slow; off by default).
EOF
}

for arg in "$@"; do
  case "$arg" in
    --ci)
      MODE="ci"
      ;;
    --with-mix-ci)
      RUN_MIX_CI=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "[BLOCK] git: required command is not installed" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

declare -a RESULTS=()
PASS_COUNT=0
WARN_COUNT=0
BLOCK_COUNT=0

record_result() {
  local level="$1"
  local label="$2"
  local detail="$3"

  RESULTS+=("[$level] $label: $detail")

  case "$level" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    BLOCK) BLOCK_COUNT=$((BLOCK_COUNT + 1)) ;;
  esac
}

have_gh() {
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

mix_version() {
  sed -nE 's/.*@version[[:space:]]+"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' mix.exs | head -n 1
}

manifest_version() {
  sed -nE 's/.*"\.":[[:space:]]*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' .release-please-manifest.json | head -n 1
}

changelog_version() {
  sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/p' CHANGELOG.md | head -n 1
}

release_train_baseline_version() {
  sed -nE 's/^- Latest released version: `([0-9]+\.[0-9]+\.[0-9]+)`.*/\1/p' .planning/RELEASE-TRAIN.md | head -n 1
}

version_gt() {
  local left="$1"
  local right="$2"
  local winner
  winner="$(printf '%s\n%s\n' "$right" "$left" | sort -V | tail -n 1)"
  [[ "$winner" == "$left" && "$left" != "$right" ]]
}

hex_latest_version() {
  if ! command -v mix >/dev/null 2>&1; then
    return 1
  fi

  mix hex.info rindle 2>/dev/null | sed -nE 's/^.*Version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n 1
}

release_train_has_required_lines() {
  grep -Fq 'Rindle is on a sustaining release train' .planning/RELEASE-TRAIN.md &&
    grep -Fq 'demand-gated-pause' .planning/RELEASE-TRAIN.md &&
    grep -Fq 'silence on the wire' .planning/RELEASE-TRAIN.md &&
    grep -Fq './scripts/maintainer/repo_hygiene_check.sh' .planning/RELEASE-TRAIN.md
}

repo_owned_checks() {
  local mix_ver manifest_ver changelog_ver baseline_ver
  mix_ver="$(mix_version)"
  manifest_ver="$(manifest_version)"
  changelog_ver="$(changelog_version)"
  baseline_ver="$(release_train_baseline_version)"

  if [[ -n "$mix_ver" && "$mix_ver" == "$manifest_ver" && "$mix_ver" == "$changelog_ver" ]]; then
    record_result "PASS" "release versions" "mix.exs, manifest, and top changelog entry all point at $mix_ver"
  else
    record_result "BLOCK" "release versions" "mix.exs=$mix_ver manifest=$manifest_ver changelog=$changelog_ver"
  fi

  if [[ -f .planning/RELEASE-TRAIN.md ]] && release_train_has_required_lines; then
    record_result "PASS" "release train ledger" "RELEASE-TRAIN.md preserves the standing train contract"
  else
    record_result "BLOCK" "release train ledger" "RELEASE-TRAIN.md is missing or malformed"
  fi

  if [[ -f .planning/DEVELOPMENT-TRAIN.md ]] &&
    grep -Fq 'milestone/vNEXT-short-slug' .planning/DEVELOPMENT-TRAIN.md; then
    record_result "PASS" "development train" "DEVELOPMENT-TRAIN.md defines milestone branch shape"
  else
    record_result "BLOCK" "development train" "DEVELOPMENT-TRAIN.md is missing or incomplete"
  fi

  if grep -Fq '"release-type": "elixir"' release-please-config.json &&
    grep -Fq '"include-v-in-tag": true' release-please-config.json; then
    record_result "PASS" "release-please config" "elixir release policy intact"
  else
    record_result "BLOCK" "release-please config" "release-please-config.json drifted"
  fi

  if grep -Fq 'skip-github-release: true' .github/workflows/release.yml &&
    grep -Fq 'Release Please Auto Merge' .github/workflows/release-please-automerge.yml; then
    record_result "PASS" "release automation" "automerge workflow and skip-github-release present"
  else
    record_result "BLOCK" "release automation" "release workflow no longer matches trusted train"
  fi

  if ! grep -Fq '(BYPASSED)' .github/workflows/release.yml; then
    record_result "PASS" "ci gate" "release workflow does not bypass CI failures"
  else
    record_result "BLOCK" "ci gate" "release workflow still contains CI bypass paths"
  fi

  if [[ -z "$baseline_ver" ]]; then
    record_result "WARN" "hex baseline" "RELEASE-TRAIN baseline version line missing"
  elif [[ "$mix_ver" == "$baseline_ver" ]]; then
    record_result "PASS" "hex baseline" "RELEASE-TRAIN baseline matches mix.exs ($baseline_ver)"
  elif version_gt "$baseline_ver" "$mix_ver"; then
    record_result "BLOCK" "hex baseline" "RELEASE-TRAIN baseline ($baseline_ver) is ahead of mix.exs ($mix_ver)"
  elif version_gt "$mix_ver" "$baseline_ver"; then
    hex_ver="$(hex_latest_version || true)"
    if [[ -n "$hex_ver" ]] && ! version_gt "$mix_ver" "$hex_ver"; then
      record_result "BLOCK" "hex baseline" "Hex.pm ($hex_ver) matches mix.exs but RELEASE-TRAIN baseline is still $baseline_ver"
    else
      record_result "PASS" "hex baseline" "mix.exs ($mix_ver) ahead of baseline ($baseline_ver) until publish completes"
    fi
  else
    record_result "PASS" "hex baseline" "RELEASE-TRAIN baseline documents $baseline_ver"
  fi

  if [[ "$MODE" == "ci" ]]; then
    hex_ver="$(hex_latest_version || true)"
    if [[ -n "$hex_ver" && -n "$baseline_ver" && "$hex_ver" != "$baseline_ver" ]]; then
      record_result "WARN" "hex.pm index" "Hex.pm latest ($hex_ver) differs from RELEASE-TRAIN baseline ($baseline_ver)"
    elif [[ -n "$hex_ver" && -n "$baseline_ver" ]]; then
      record_result "PASS" "hex.pm index" "Hex.pm latest matches RELEASE-TRAIN baseline ($baseline_ver)"
    else
      record_result "WARN" "hex.pm index" "could not read Hex.pm latest version for comparison"
    fi
  fi
}

local_checks() {
  local branch status_output

  branch="$(git rev-parse --abbrev-ref HEAD)"
  record_result "PASS" "current branch" "$branch"

  status_output="$(git status --porcelain)"
  if [[ -z "$status_output" ]]; then
    record_result "PASS" "working tree" "clean"
  else
    record_result "BLOCK" "working tree" "dirty state detected; commit, stash, or discard local changes first"
  fi

  git fetch "$REMOTE" --prune >/dev/null 2>&1 || true

  if git show-ref --verify --quiet "refs/heads/main" && git show-ref --verify --quiet "refs/remotes/$REMOTE/main"; then
    local ahead behind
    read -r behind ahead <<<"$(git rev-list --left-right --count "$REMOTE/main...main")"

    if [[ "$behind" == "0" && "$ahead" == "0" ]]; then
      record_result "PASS" "main divergence" "local main matches $REMOTE/main"
    elif [[ "$behind" != "0" ]]; then
      record_result "BLOCK" "main divergence" "local main is behind $REMOTE/main by $behind commit(s)"
    else
      record_result "WARN" "main divergence" "local main is ahead of $REMOTE/main by $ahead commit(s)"
    fi
  else
    record_result "WARN" "main divergence" "could not compare local main to $REMOTE/main"
  fi

  if have_gh; then
    local latest_ci
    latest_ci="$(gh run list --workflow ci.yml --branch main --limit 1 --json conclusion,status,url 2>/dev/null || true)"
    if [[ "$latest_ci" == *'"conclusion":"success"'* ]]; then
      record_result "PASS" "latest CI" "latest main CI run succeeded"
    elif [[ "$latest_ci" == *'"status":"in_progress"'* || "$latest_ci" == *'"status":"queued"'* ]]; then
      record_result "WARN" "latest CI" "main CI is still in progress"
    elif [[ -n "$latest_ci" && "$latest_ci" != "[]" ]]; then
      record_result "BLOCK" "latest CI" "latest main CI run is not green"
    else
      record_result "WARN" "latest CI" "could not read recent main CI history"
    fi
  else
    record_result "WARN" "GitHub checks" "gh unavailable; skipped workflow status checks"
  fi

  if [[ "$RUN_MIX_CI" == "1" ]]; then
    if mix test >/dev/null; then
      record_result "PASS" "mix test" "local test suite passed"
    else
      record_result "BLOCK" "mix test" "local test suite failed"
    fi
  fi
}

repo_owned_checks

if [[ "$MODE" != "ci" ]]; then
  local_checks
fi

printf 'Rindle repo hygiene report (%s)\n' "$MODE"
printf '%s\n' "${RESULTS[@]}"
printf 'Summary: %s PASS, %s WARN, %s BLOCK\n' "$PASS_COUNT" "$WARN_COUNT" "$BLOCK_COUNT"

if [[ "$BLOCK_COUNT" -gt 0 ]]; then
  echo "Result: not ready"
  exit 1
fi

if [[ "$WARN_COUNT" -gt 0 ]]; then
  echo "Result: proceed with caution"
  exit 0
fi

echo "Result: safe to start release prep"
