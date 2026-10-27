#!/usr/bin/env bash
# repo_hygiene_check.sh - release-train hygiene gate.
#
# Reports PASS, WARN and BLOCK results and exits 0 (safe or caution), 1 (not ready) or
# 64 (usage). Bash 3.2 and jq 1.6 compatible. The script never mutates a remote: it may
# fetch, and it only reads GitHub and Hex.
set -euo pipefail

MODE="local"
RUN_MIX_CI=0
REMOTE="${RINDLE_HYGIENE_REMOTE:-origin}"
EXPECTED_BRANCH="${RINDLE_HYGIENE_BRANCH:-main}"
SNAPSHOT_SUBJECT=""
SNAPSHOT_REPO=""
SNAPSHOT_EVIDENCE=""

usage() {
  cat <<'EOF'
Usage: repo_hygiene_check.sh [--ci | --release-prep] [--with-mix-ci]
       repo_hygiene_check.sh --snapshot-subject FULL_SHA --repo OWNER/REPO [--snapshot-evidence DIR]

Checks whether the repo is in a disciplined release-prep state.

Modes:
  (default)       Local release-prep checks: fetch the remote; require the expected
                  branch with HEAD equal to REMOTE/BRANCH; repo-owned checks; the
                  artifact ledger; tracked junk; rerun the ledger's hygiene generators
                  and BLOCK on generated drift; BLOCK on paths that verification left
                  outside the ledger's verification ignored roots.
  --release-prep  The same checks as the default mode, named explicitly for release prep.
  --ci            Repo-owned checks, the artifact ledger and tracked junk. No fetch,
                  branch, generated drift, mix ci or residue checks (on PRs the
                  brandbook-tokens job proves generated drift). A Hex publish that is
                  ahead of the RELEASE-TRAIN baseline record is WARN here, BLOCK elsewhere.
  --with-mix-ci   Also run the full `mix ci` alias and require its completion
                  sentinels (slow; default and --release-prep only).
  --snapshot-subject  Qualify an authenticated previously-main source instead of
                  current-tip release eligibility. Requires --repo; preserves all
                  source, generator, artifact and residue checks. No release credit.
  --snapshot-evidence  New external directory retaining admission/API evidence.

Environment:
  RINDLE_HYGIENE_ROOT    checkout to check (default: git rev-parse --show-toplevel)
  RINDLE_HYGIENE_REMOTE  remote to fetch and compare with (default: origin)
  RINDLE_HYGIENE_BRANCH  expected branch (default: main)
EOF
}

while [[ "$#" -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    --ci)
      MODE="ci"
      ;;
    --release-prep)
      MODE="release-prep"
      ;;
    --with-mix-ci)
      RUN_MIX_CI=1
      ;;
    --snapshot-subject | --repo | --snapshot-evidence)
      [[ "$#" -ge 2 ]] || { usage >&2; exit 64; }
      case "$arg" in
        --snapshot-subject) SNAPSHOT_SUBJECT="$2" ;;
        --repo) SNAPSHOT_REPO="$2" ;;
        --snapshot-evidence) SNAPSHOT_EVIDENCE="$2" ;;
      esac
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

if [[ -n "$SNAPSHOT_SUBJECT$SNAPSHOT_REPO$SNAPSHOT_EVIDENCE" ]]; then
  if [[ "$MODE" == "ci" || ! "$SNAPSHOT_SUBJECT" =~ ^[0-9a-f]{40}$ ||
        ! "$SNAPSHOT_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "Snapshot hygiene requires a full SHA and --repo, and cannot be combined with --ci" >&2
    exit 64
  fi
  MODE="snapshot"
fi

if [[ "$MODE" == "ci" && "$RUN_MIX_CI" == "1" ]]; then
  echo "--with-mix-ci cannot be combined with --ci" >&2
  usage >&2
  exit 64
fi

if ! command -v git >/dev/null 2>&1; then
  echo "[BLOCK] git: required command is not installed" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${RINDLE_HYGIENE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[BLOCK] repository: $REPO_ROOT is not a git work tree" >&2
  exit 1
fi
cd "$REPO_ROOT"

LEDGER="scripts/maintainer/artifact_ledger.json"

declare -a RESULTS=()
PASS_COUNT=0
WARN_COUNT=0
BLOCK_COUNT=0
FETCH_OK=0
MIX_PID=""

# Scratch files (residue snapshots, the mix ci log) live in a private mktemp directory
# outside the checkout. It is removed on exit and on INT or TERM, and an interrupted
# mix ci is stopped first so it cannot keep writing.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/repo-hygiene.XXXXXX")"

cleanup() {
  if [[ -n "$MIX_PID" ]]; then
    pkill -TERM -P "$MIX_PID" >/dev/null 2>&1 || true
    kill -TERM "$MIX_PID" >/dev/null 2>&1 || true
    MIX_PID=""
  fi
  rm -rf "$WORK"
}

on_signal() {
  cleanup
  trap - EXIT
  exit "$1"
}

trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

# Deterministic git: machine-local excludes never change a verdict.
g() { git -c core.quotePath=false -c core.excludesFile=/dev/null "$@"; }

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

  # Hex 2.2+ prints a "Recent releases:" list; retain the older "Version:"
  # parser as a compatibility fallback for maintainers with older Hex clients.
  mix hex.info rindle 2>/dev/null |
    sed -nE \
      -e 's/^[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+\(.*/\1/p' \
      -e 's/^.*Version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' |
    head -n 1
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

  if [[ -x scripts/maintainer/automation_first_contract.sh ]]; then
    if automation_output="$(scripts/maintainer/automation_first_contract.sh 2>&1)"; then
      record_result "PASS" "automation-first validation" "$automation_output"
    else
      record_result "BLOCK" "automation-first validation" "$automation_output"
    fi
  else
    record_result "BLOCK" "automation-first validation" "scripts/maintainer/automation_first_contract.sh is missing or not executable"
  fi

  if [[ -z "$baseline_ver" ]]; then
    record_result "WARN" "hex baseline" "RELEASE-TRAIN baseline version line missing"
  elif [[ "$mix_ver" == "$baseline_ver" ]]; then
    record_result "PASS" "hex baseline" "RELEASE-TRAIN baseline matches mix.exs ($baseline_ver)"
  elif version_gt "$baseline_ver" "$mix_ver"; then
    record_result "BLOCK" "hex baseline" "RELEASE-TRAIN baseline ($baseline_ver) is ahead of mix.exs ($mix_ver)"
  elif version_gt "$mix_ver" "$baseline_ver"; then
    hex_ver="$(hex_latest_version || true)"
    if [[ -n "$hex_ver" && "$hex_ver" == "$mix_ver" && "$MODE" == "ci" ]]; then
      # Publish race: the release workflow records the baseline after Public Verify, in a
      # later commit, so a CI run on an earlier commit sees Hex ahead of the record.
      record_result "WARN" "hex baseline" "Hex.pm ($hex_ver) matches mix.exs but RELEASE-TRAIN baseline is still $baseline_ver; the release workflow baseline record lands after publish"
    elif [[ -n "$hex_ver" ]] && ! version_gt "$mix_ver" "$hex_ver"; then
      record_result "BLOCK" "hex baseline" "Hex.pm ($hex_ver) matches mix.exs but RELEASE-TRAIN baseline is still $baseline_ver; record the baseline (release workflow baseline record) before release prep"
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

# Fetch the remote. A failed fetch is a BLOCK: without it HEAD cannot be compared with
# the remote branch.
check_fetch() {
  if git fetch "$REMOTE" --prune >/dev/null 2>&1; then
    FETCH_OK=1
    record_result "PASS" "fetch" "fetched $REMOTE"
  else
    FETCH_OK=0
    record_result "BLOCK" "fetch" "git fetch $REMOTE failed; cannot prove HEAD matches $REMOTE/$EXPECTED_BRANCH"
  fi
}

# Require the expected branch (a detached HEAD reads as DETACHED) and, after a successful
# fetch, HEAD equal to REMOTE/BRANCH.
check_branch() {
  local branch behind ahead counts

  local branch_ok=0
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo DETACHED)"
  if [[ "$branch" == "$EXPECTED_BRANCH" ]]; then
    branch_ok=1
    record_result "PASS" "branch" "$branch"
  else
    record_result "BLOCK" "branch" "on '$branch'; release prep requires '$EXPECTED_BRANCH'"
  fi

  if [[ "$FETCH_OK" != "1" ]]; then
    return 0
  fi

  if ! git rev-parse --verify --quiet "refs/remotes/$REMOTE/$EXPECTED_BRANCH^{commit}" >/dev/null; then
    record_result "BLOCK" "head vs origin" "$REMOTE/$EXPECTED_BRANCH does not exist after fetch"
    return 0
  fi

  counts="$(git rev-list --left-right --count "refs/remotes/$REMOTE/$EXPECTED_BRANCH...HEAD")"
  read -r behind ahead <<<"$counts"
  if [[ "$behind" == "0" && "$ahead" == "0" ]]; then
    record_result "PASS" "head vs origin" "HEAD matches $REMOTE/$EXPECTED_BRANCH"
    # Generators and mix ci run repository code: only on a verified checkout.
    if [[ "$branch_ok" == "1" ]]; then
      HEAD_VERIFIED=1
    fi
  else
    record_result "BLOCK" "head vs origin" "HEAD is behind=$behind ahead=$ahead of $REMOTE/$EXPECTED_BRANCH"
  fi
}

# This is separate from ordinary release prep: never pretend an older source is
# the current remote tip. Authenticate its actual protected-main provenance with
# the same versioned controller used by acceptance before running repository code.
check_snapshot_source() {
  local source_root head evidence
  source_root="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
  head="$(git rev-parse HEAD)"
  if [[ "$(pwd -P)" != "$source_root" || "$head" != "$SNAPSHOT_SUBJECT" || "$FETCH_OK" != "1" ||
        -n "$(git status --porcelain)" ]]; then
    record_result "BLOCK" "snapshot source" "checkout/controller/source identity or fetch differs"
    return 0
  fi
  evidence="${SNAPSHOT_EVIDENCE:-$WORK/snapshot-admission}"
  if PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT_DIR/readiness_acceptance.py" admit-snapshot --snapshot \
      --subject "$SNAPSHOT_SUBJECT" --repo "$SNAPSHOT_REPO" --output "$evidence" \
      >"$WORK/snapshot-admission.log" 2>&1 &&
      jq -e --arg sha "$SNAPSHOT_SUBJECT" --arg repo "$SNAPSHOT_REPO" '
        .schema == "rindle-readiness-snapshot-subject-v3" and .repository == $repo and
        .subject_sha == $sha and .authenticated == true and .requirements_credit == false and
        (.current_main_sha | type == "string" and test("^[0-9a-f]{40}$"))
      ' "$evidence/subject.json" >/dev/null 2>&1; then
    HEAD_VERIFIED=1
    record_result "PASS" "snapshot source" "authenticated previously-main $SNAPSHOT_SUBJECT; current main $(jq -r .current_main_sha "$evidence/subject.json")"
    record_result "PASS" "snapshot CI" "actual successful push-main provenance for $SNAPSHOT_SUBJECT"
  else
    record_result "BLOCK" "snapshot source" "protected-main admission failed; see retained admission evidence"
  fi
}

check_working_tree() {
  local status_output
  status_output="$(git status --porcelain)"
  if [[ -z "$status_output" ]]; then
    record_result "PASS" "working tree" "clean"
  else
    record_result "BLOCK" "working tree" "dirty state detected; commit, stash, or discard local changes first"
  fi
}

check_latest_ci() {
  if have_gh; then
    local latest_ci
    latest_ci="$(gh run list --workflow ci.yml --branch "$EXPECTED_BRANCH" --limit 1 --json conclusion,status,url 2>/dev/null || true)"
    if [[ "$latest_ci" == *'"conclusion":"success"'* ]]; then
      record_result "PASS" "latest CI" "latest $EXPECTED_BRANCH CI run succeeded"
    elif [[ "$latest_ci" == *'"status":"in_progress"'* || "$latest_ci" == *'"status":"queued"'* ]]; then
      record_result "WARN" "latest CI" "$EXPECTED_BRANCH CI is still in progress"
    elif [[ -n "$latest_ci" && "$latest_ci" != "[]" ]]; then
      record_result "BLOCK" "latest CI" "latest $EXPECTED_BRANCH CI run is not green"
    else
      record_result "WARN" "latest CI" "could not read recent $EXPECTED_BRANCH CI history"
    fi
  else
    record_result "WARN" "GitHub checks" "gh unavailable; skipped workflow status checks"
  fi
}

ledger_readable() {
  command -v jq >/dev/null 2>&1 && [[ -f "$LEDGER" ]] && jq -e 'type == "object"' "$LEDGER" >/dev/null 2>&1
}

# join_paths FILE: at most 20 lines of FILE on one line, with a count of the rest.
join_paths() {
  local total
  total="$(wc -l <"$1" | tr -d ' ')"
  head -n 20 "$1" | tr '\n' ' ' | sed 's/ $//'
  if [[ "$total" -gt 20 ]]; then
    printf ' (and %s more)' "$((total - 20))"
  fi
}

# The artifact ledger offline validator (partition, ignore rules, junk, roots).
check_artifact_ledger() {
  local out
  if ! ledger_readable; then
    record_result "BLOCK" "artifact ledger" "$LEDGER is missing or unreadable (jq required)"
    return 0
  fi
  if out="$(bash "$SCRIPT_DIR/validate_artifact_ledger.sh" --offline --root . --ledger "$LEDGER" 2>&1)"; then
    record_result "PASS" "artifact ledger" "$(printf '%s\n' "$out" | tail -n 1)"
  else
    record_result "BLOCK" "artifact ledger" "$(printf '%s\n' "$out" | head -n 5 | tr '\n' ' ')"
  fi
}

# Tracked paths matching the ledger tracked_junk_patterns, and tracked paths that a tracked
# .gitignore rule matches.
check_tracked_junk() {
  local pat found="$WORK/tracked-junk"
  : >"$found"
  if ! ledger_readable; then
    record_result "BLOCK" "tracked junk" "cannot read tracked_junk_patterns from $LEDGER"
    return 0
  fi
  while IFS= read -r pat; do
    if ! g ls-files -- "$pat" >>"$found" 2>/dev/null; then
      record_result "BLOCK" "tracked junk" "unusable tracked_junk_patterns entry: $pat"
    fi
  done < <(jq -r '(.tracked_junk_patterns // [])[] | select(type == "string" and length > 0 and (test("\n") | not))' "$LEDGER")
  if ! g ls-files -c -i --exclude-per-directory=.gitignore >>"$found" 2>/dev/null; then
    record_result "BLOCK" "tracked junk" "could not list tracked files that an ignore rule matches"
  fi
  LC_ALL=C sort -u "$found" -o "$found"
  if [[ -s "$found" ]]; then
    record_result "BLOCK" "tracked junk" "$(join_paths "$found")"
  else
    record_result "PASS" "tracked junk" "no tracked junk or ignored files"
  fi
}

# Generator commands hygiene may run, in pipeline order. Ledger text is compared with this
# list as data and never executed; each match runs as the argv array below.
VETTED_GENERATORS=(
  "node brandbook/src/tokens-build.mjs"
  "node brandbook/src/admin-css-build.mjs"
  "node brandbook/src/sync-admin-css.mjs"
)

run_vetted_generator() {
  case "$1" in
    "node brandbook/src/tokens-build.mjs") node brandbook/src/tokens-build.mjs ;;
    "node brandbook/src/admin-css-build.mjs") node brandbook/src/admin-css-build.mjs ;;
    "node brandbook/src/sync-admin-css.mjs") node brandbook/src/sync-admin-css.mjs ;;
    *) return 127 ;;
  esac
}

is_vetted_generator() {
  local v
  for v in "${VETTED_GENERATORS[@]}"; do
    [[ "$1" == "$v" ]] && return 0
  done
  return 1
}

# Rerun the ledger's drift_check hygiene generators, then require their drift paths to be
# unchanged and no new untracked file beside them.
check_generated_drift() {
  local id cmd p v ok=1 ran=0
  local -a paths=() dirs=()
  local wanted="$WORK/generators-wanted"
  : >"$wanted"

  if [[ "$HEAD_VERIFIED" != "1" ]]; then
    record_result "BLOCK" "generated drift" "not run: HEAD is not a verified $REMOTE/$EXPECTED_BRANCH checkout"
    return 0
  fi
  if ! ledger_readable; then
    record_result "BLOCK" "generated drift" "cannot read regenerate entries from $LEDGER"
    return 0
  fi

  while IFS="$(printf '\t')" read -r id cmd; do
    if is_vetted_generator "$cmd"; then
      printf '%s\n' "$cmd" >>"$wanted"
    else
      record_result "BLOCK" "generated drift" "class $id lists a command outside the vetted set; it was not run"
      ok=0
    fi
  done < <(jq -r '.classes[]? | select(type == "object" and (.regenerate | type) == "object"
                    and .regenerate.drift_check == "hygiene")
                  | .id as $id | (.regenerate.commands // [])[] | [($id | tostring), tostring] | @tsv' "$LEDGER")

  while IFS= read -r p; do
    paths+=(":(literal)$p")
    dirs+=(":(literal)$(dirname "$p")")
  done < <(jq -r '.classes[]? | select(type == "object" and (.regenerate | type) == "object"
                    and .regenerate.drift_check == "hygiene")
                  | (.regenerate.drift_paths // [])[] | select(type == "string" and length > 0 and (test("\n") | not))' "$LEDGER")

  if [[ "${#paths[@]}" -eq 0 ]]; then
    record_result "BLOCK" "generated drift" "the ledger lists no hygiene drift paths"
    return 0
  fi

  g ls-files --others --exclude-standard -- "${dirs[@]}" | LC_ALL=C sort -u >"$WORK/drift-untracked-before"

  for v in "${VETTED_GENERATORS[@]}"; do
    grep -Fxq -- "$v" "$wanted" || continue
    if ! command -v node >/dev/null 2>&1; then
      record_result "BLOCK" "generated drift" "node is not installed; cannot rerun '$v'"
      ok=0
      break
    fi
    ran=$((ran + 1))
    if ! run_vetted_generator "$v" >>"$WORK/generators.log" 2>&1; then
      record_result "BLOCK" "generated drift" "'$v' exited non-zero"
      ok=0
    fi
  done

  g diff --name-only -- "${paths[@]}" >"$WORK/drift-changed"
  if [[ -s "$WORK/drift-changed" ]]; then
    record_result "BLOCK" "generated drift" "regenerated files differ from HEAD: $(join_paths "$WORK/drift-changed")"
    ok=0
  fi

  g ls-files --others --exclude-standard -- "${dirs[@]}" | LC_ALL=C sort -u >"$WORK/drift-untracked-after"
  LC_ALL=C comm -13 "$WORK/drift-untracked-before" "$WORK/drift-untracked-after" >"$WORK/drift-new"
  if [[ -s "$WORK/drift-new" ]]; then
    record_result "BLOCK" "generated drift" "generators created untracked files: $(join_paths "$WORK/drift-new")"
    ok=0
  fi

  if [[ "$ok" == "1" ]]; then
    record_result "PASS" "generated drift" "$ran generator(s) rerun; drift paths unchanged"
  fi
}

# Completion sentinels of the mix ci alias. A stage removed from the alias, or one that
# exits 0 without finishing, leaves its sentinel out of the log.
SENTINEL_CREDO='[credo-quality] blocking warnings, public contract, and complexity inventory passed'
SENTINEL_SYNC='synced rindle-admin.css -> priv/static/rindle_admin/rindle-admin.css ('
# ExUnit summary; doctest and property counts precede the test count when present.
SENTINEL_EXUNIT='^([0-9]+ (doctests?|propert(y|ies)), )*[0-9]+ tests?, 0 failures'

# Run the full mix ci alias. The log stays in the private scratch directory and is never
# printed; only the names of missing sentinels are reported.
check_mix_ci() {
  local log="$WORK/mix-ci.log" status=0 missing=""

  if [[ "$HEAD_VERIFIED" != "1" ]]; then
    record_result "BLOCK" "mix ci" "not run: HEAD is not a verified $REMOTE/$EXPECTED_BRANCH checkout"
    return 0
  fi
  if ! command -v mix >/dev/null 2>&1; then
    record_result "BLOCK" "mix ci" "mix is not installed"
    return 0
  fi

  # Run in the background and wait, so INT or TERM reaches the trap at once.
  mix ci >"$log" 2>&1 </dev/null &
  MIX_PID=$!
  wait "$MIX_PID" || status=$?
  MIX_PID=""

  if [[ "$status" != "0" ]]; then
    rm -f "$log"
    record_result "BLOCK" "mix ci" "mix ci exited $status"
    return 0
  fi

  grep -Fq -- "$SENTINEL_CREDO" "$log" || missing="$missing credo-quality"
  grep -Fq -- "$SENTINEL_SYNC" "$log" || missing="$missing admin-css-sync"
  grep -Eq -- "$SENTINEL_EXUNIT" "$log" || missing="$missing exunit-summary"
  rm -f "$log"

  if [[ -n "$missing" ]]; then
    record_result "BLOCK" "mix ci incomplete" "mix ci exited 0 without completion sentinel(s):$missing"
  else
    record_result "PASS" "mix ci" "full alias completed with every completion sentinel"
  fi
}

# snapshot_status FILE: every untracked and ignored path, one per line, sorted.
snapshot_status() {
  g status --porcelain=v1 -uall --ignored >"$1.raw" 2>/dev/null || return 1
  LC_ALL=C sort "$1.raw" >"$1"
  rm -f "$1.raw"
}

# Paths that appeared during verification. Ignored paths under the ledger
# verification_ignored_roots are expected build and test output; anything else is residue.
check_residue() {
  local line path root allowed
  local -a roots=()

  if [[ "$SNAPSHOT_OK" != "1" ]] || ! snapshot_status "$WORK/status-after"; then
    record_result "BLOCK" "post-verification residue" "git status snapshot failed"
    return 0
  fi
  if ledger_readable; then
    while IFS= read -r root; do
      roots+=("$root")
    done < <(jq -r '(.verification_ignored_roots // [])[] | select(type == "string" and length > 0)' "$LEDGER")
  fi

  : >"$WORK/residue"
  while IFS= read -r line; do
    path="${line:3}"
    allowed=0
    if [[ "${line:0:2}" == "!!" && "${#roots[@]}" -gt 0 ]]; then
      for root in "${roots[@]}"; do
        if [[ "$path" == "$root"* ]]; then
          allowed=1
          break
        fi
      done
    fi
    [[ "$allowed" == "1" ]] || printf '%s\n' "$path" >>"$WORK/residue"
  done < <(LC_ALL=C comm -13 "$WORK/status-before" "$WORK/status-after")

  if [[ -s "$WORK/residue" ]]; then
    record_result "BLOCK" "post-verification residue" "$(join_paths "$WORK/residue")"
  else
    record_result "PASS" "post-verification residue" "no new path outside the verification ignored roots"
  fi
}

HEAD_VERIFIED=0
SNAPSHOT_OK=0

if [[ "$MODE" == "ci" ]]; then
  repo_owned_checks
  check_artifact_ledger
  check_tracked_junk
else
  if snapshot_status "$WORK/status-before"; then
    SNAPSHOT_OK=1
  fi
  check_fetch
  if [[ "$MODE" == "snapshot" ]]; then check_snapshot_source; else check_branch; fi
  check_working_tree
  if [[ "$MODE" == "snapshot" && "$HEAD_VERIFIED" != "1" ]]; then
    record_result "BLOCK" "snapshot checks" "repository execution refused without admitted source"
  else
    repo_owned_checks
    if [[ "$MODE" != "snapshot" ]]; then check_latest_ci; fi
    check_artifact_ledger
    check_tracked_junk
    check_generated_drift
    if [[ "$RUN_MIX_CI" == "1" ]]; then
      check_mix_ci
    fi
  fi
  check_residue
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

if [[ "$MODE" == "snapshot" ]]; then
  echo "Result: snapshot source hygiene verified; no current-main or release eligibility"
else
  echo "Result: safe to start release prep"
fi
