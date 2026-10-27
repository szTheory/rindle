#!/usr/bin/env bash
# test_repo_hygiene_check.sh - fixture harness for scripts/maintainer/repo_hygiene_check.sh.
#
# Every case runs the real script against a real temp git repository cloned from a local
# bare origin, with fake `mix`, `node` and `gh` on PATH. No network, no Elixir, no gh
# login. Each case has its own directory (and its own TMPDIR) under one mktemp root that
# the EXIT trap removes. Bash 3.2 / jq 1.6 compatible.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/../maintainer/repo_hygiene_check.sh"
LEDGER_SRC="${HERE}/../maintainer/artifact_ledger.json"

ROOT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/test_repo_hygiene.XXXXXX")"
trap 'rm -rf "${ROOT_TMP}"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

# Git must not read the runner's global or system config (signing, hooks, default branch).
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="${ROOT_TMP}/gitconfig"
cat >"${GIT_CONFIG_GLOBAL}" <<'EOF'
[user]
	name = Hygiene Fixture
	email = hygiene-fixture@example.invalid
[init]
	defaultBranch = main
[commit]
	gpgsign = false
[advice]
	detachedHead = false
EOF

# --- fake binaries ---------------------------------------------------------------------------
BIN="${ROOT_TMP}/bin"
mkdir -p "${BIN}"
export HYGIENE_FIXTURE_REAL_PYTHON="$(command -v python3)"

cat >"${BIN}/mix" <<'FAKE_MIX'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"${FAKE_DIR}/mix.log"
case "${1-}" in
  hex.info)
    if [ -n "${FAKE_HEX_VERSION-}" ]; then
      printf 'Recent releases:\n  %s (2026-10-16)\n' "${FAKE_HEX_VERSION}"
      exit 0
    fi
    exit 1
    ;;
  ci)
    # FAKE_MIX_CI: ok | fail | partial | untracked | build | ignored | sleep
    credo='[credo-quality] blocking warnings, public contract, and complexity inventory passed'
    sync='synced rindle-admin.css -> priv/static/rindle_admin/rindle-admin.css (42 bytes)'
    summary='3 doctests, 120 tests, 0 failures, 2 excluded'
    case "${FAKE_MIX_CI:-ok}" in
      fail) echo "compile failed"; exit 2 ;;
      partial) printf '%s\n%s\n' "${credo}" "${sync}"; exit 0 ;;
      sleep)
        : >"${FAKE_DIR}/mix-ci-started"
        sleep 30
        exit 0
        ;;
      untracked) echo stray >stray-output.txt ;;
      build) mkdir -p _build/test && echo beam >_build/test/fixture.beam ;;
      ignored) echo stray >stray-output.cache ;;
    esac
    printf 'Compiling\n%s\n%s\nFinished in 1.0 seconds\n%s\n' "${credo}" "${sync}" "${summary}"
    exit 0
    ;;
esac
exit 0
FAKE_MIX

cat >"${BIN}/node" <<'FAKE_NODE'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"${FAKE_DIR}/node.log"
# FAKE_NODE: noop | rewrite | untracked
case "${FAKE_NODE:-noop}" in
  rewrite) echo '/* drift */' >>priv/static/rindle_admin/rindle-admin.css ;;
  untracked) echo '/* new */' >priv/static/rindle_admin/rindle-admin.extra.css ;;
esac
exit 0
FAKE_NODE

cat >"${BIN}/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"${FAKE_DIR}/gh.log"
case "${1-}" in
  auth) exit 0 ;;
  run)
    case "${2-}" in
      list)
        if [ "${FAKE_GH_CI:-success}" = pending ]; then
          echo '[{"conclusion":null,"status":"in_progress","url":"https://example.invalid/run/2"}]'
        else
          echo '[{"conclusion":"success","status":"completed","url":"https://example.invalid/run/1"}]'
        fi
        exit 0 ;;
    esac
    ;;
esac
case "${1-} ${2-}" in
  "pr list"|"pr view"|"run view"|"release list"|"release view") exit 0 ;;
esac
echo "$*" >>"${FAKE_DIR}/mutations"
exit 0
FAKE_GH

# Admission is a tested read-only Python boundary. This seam isolates the real
# Bash/git/generator behavior; snapshot identity/API negatives also run through
# the actual controller in test_readiness_snapshot.py. No fixture grants credit.
cat >"${BIN}/python3" <<'FAKE_PY'
#!/usr/bin/env bash
set -eu
if [[ "${1:-}" == */readiness_acceptance.py && "${2:-}" == admit-snapshot ]]; then
  printf '%s\n' "$*" >>"${FAKE_DIR}/admission.log"
  [[ "${FAKE_SNAPSHOT_ADMIT:-ok}" != fail ]] || exit 1
  shift 2
  subject=""; repo=""; output=""
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --subject) subject="$2"; shift ;;
      --repo) repo="$2"; shift ;;
      --output) output="$2"; shift ;;
    esac
    shift
  done
  if [[ "${FAKE_SNAPSHOT_ADMIT:-ok}" == foreign ]]; then subject="0000000000000000000000000000000000000000"; fi
  mkdir -p "$output"
  current="$(git rev-parse refs/remotes/origin/main)"
  jq -n --arg subject "$subject" --arg repo "$repo" --arg current "$current" \
    '{schema:"rindle-readiness-snapshot-subject-v3",subject_sha:$subject,repository:$repo,
      current_main_sha:$current,authenticated:true,requirements_credit:false}' >"$output/subject.json"
  echo snapshot_admitted
  exit 0
fi
exec "$HYGIENE_FIXTURE_REAL_PYTHON" "$@"
FAKE_PY

chmod +x "${BIN}/mix" "${BIN}/node" "${BIN}/gh" "${BIN}/python3"

# --- seed tree -------------------------------------------------------------------------------
# A minimal maintainer tree: version files, train documents, release workflows, a stub
# automation-first contract, one generated drift path, and an artifact ledger trimmed to it.
SEED="${ROOT_TMP}/seed"

write_seed() {
  local d="$1" version="$2" baseline="$3"
  mkdir -p "${d}/lib" "${d}/.planning" "${d}/.github/workflows" "${d}/scripts/maintainer" \
    "${d}/brandbook/src" "${d}/priv/static/rindle_admin"

  cat >"${d}/mix.exs" <<EOF
defmodule Fixture.MixProject do
  use Mix.Project

  @version "${version}"

  def project do
    [app: :fixture, version: @version, package: package()]
  end

  defp package do
    [files: ~w(lib priv/static/rindle_admin/rindle-admin.css mix.exs CHANGELOG.md)]
  end
end
EOF
  printf 'defmodule Fixture do\nend\n' >"${d}/lib/fixture.ex"
  printf '# Changelog\n\n## [%s] (2026-10-16)\n\n- fixture release\n' "${version}" >"${d}/CHANGELOG.md"
  printf '{\n  ".": "%s"\n}\n' "${version}" >"${d}/.release-please-manifest.json"
  cat >"${d}/release-please-config.json" <<'EOF'
{
  "packages": { ".": { "release-type": "elixir", "include-v-in-tag": true } }
}
EOF
  printf 'name: Release\n# skip-github-release: true\n' >"${d}/.github/workflows/release.yml"
  printf 'name: Release Please Auto Merge\n' >"${d}/.github/workflows/release-please-automerge.yml"
  cat >"${d}/.planning/RELEASE-TRAIN.md" <<EOF
# Release train

Rindle is on a sustaining release train in demand-gated-pause; silence on the wire.

- Latest released version: \`${baseline}\` (Hex.pm, 2026-10-16)

Before release prep, \`./scripts/maintainer/repo_hygiene_check.sh\` passes without BLOCK.
EOF
  printf '# Development train\n\nBranch shape: milestone/vNEXT-short-slug\n' >"${d}/.planning/DEVELOPMENT-TRAIN.md"
  printf '#!/usr/bin/env bash\necho "automation-first contract: ok"\n' >"${d}/scripts/maintainer/automation_first_contract.sh"
  chmod +x "${d}/scripts/maintainer/automation_first_contract.sh"
  cp "$SCRIPT" "${d}/scripts/maintainer/repo_hygiene_check.sh"
  cp "${HERE}/../maintainer/readiness_acceptance.py" "${d}/scripts/maintainer/readiness_acceptance.py"
  cp "${HERE}/../maintainer/validate_artifact_ledger.sh" "${d}/scripts/maintainer/validate_artifact_ledger.sh"
  printf 'console.log("fixture generator");\n' >"${d}/brandbook/src/sync-admin-css.mjs"
  printf '.rindle-admin { color: black; }\n' >"${d}/priv/static/rindle_admin/rindle-admin.css"
  cat >"${d}/.gitignore" <<'EOF'
/_build/
/deps/
/tmp/
*.cache
.DS_Store
EOF
  write_ledger "${d}/scripts/maintainer/artifact_ledger.json" "node brandbook/src/sync-admin-css.mjs"
}

# write_ledger FILE COMMAND: the fixture ledger, with COMMAND as the hygiene generator and
# tracked_junk_patterns copied from the committed ledger.
write_ledger() {
  local out="$1" cmd="$2"
  jq -S --arg cmd "${cmd}" --slurpfile src "${LEDGER_SRC}" '
    def cls($id; $auth; $pkg; $specs):
      {id: $id, authority: $auth, package: $pkg, disposition: "retain", consumer: ["mix.exs"],
       pathspecs: $specs, reason: "fixture class"};
    def rule($r): {file: ".gitignore", rule: $r, disposition: "ignore", produced_by: "fixture"};
    {
      schema: "rindle-artifact-ledger-v1",
      classes: [
        cls("lib"; "hand-authored"; "shipped"; [":(glob)lib/**"]),
        (cls("admin-css"; "generated"; "shipped"; ["priv/static/rindle_admin/rindle-admin.css"])
          + {regenerate: {commands: [$cmd], drift_check: "hygiene",
                          drift_paths: ["priv/static/rindle_admin/rindle-admin.css"]}}),
        cls("manifest"; "hand-authored"; "shipped"; ["mix.exs"]),
        cls("changelog"; "history"; "shipped"; ["CHANGELOG.md"]),
        cls("config"; "hand-authored"; "excluded";
            [".gitignore", ".release-please-manifest.json", "release-please-config.json",
             ":(glob).github/**"]),
        cls("planning"; "hand-authored"; "excluded"; [":(glob).planning/**"]),
        cls("scripts"; "hand-authored"; "excluded"; [":(glob)scripts/**"]),
        cls("brandbook"; "hand-authored"; "excluded"; [":(glob)brandbook/**"])
      ],
      ignore_rules: [rule("/_build/"), rule("/deps/"), rule("/tmp/"), rule("*.cache"), rule(".DS_Store")],
      tracked_junk_patterns: $src[0].tracked_junk_patterns,
      verification_ignored_roots: ["_build/", "deps/", "tmp/"]
    }' -n >"${out}"
}

git_q() { git "$@" >/dev/null 2>&1; }

build_seed() {
  local version="$1" baseline="$2"
  rm -rf "${SEED}"
  mkdir -p "${SEED}"
  write_seed "${SEED}" "${version}" "${baseline}"
  git_q -C "${SEED}" init -q -b main
  git_q -C "${SEED}" add -A
  git_q -C "${SEED}" commit -q -m "fixture seed"
}

# new_case NAME: a bare origin cloned from the seed, a work clone on main, a fake-bin log
# directory and a private TMPDIR. Sets C to the case directory.
CASE_N=0
new_case() {
  CASE_N=$((CASE_N + 1))
  C="${ROOT_TMP}/case${CASE_N}"
  mkdir -p "${C}/fake" "${C}/tmpdir"
  git_q clone -q --bare "${SEED}" "${C}/origin.git"
  git_q clone -q "${C}/origin.git" "${C}/work"
}

# run_hygiene ARGS...: runs the script for case C; sets RC and writes ${C}/out.
run_hygiene() {
  RC=0
  (
    cd "${C}/work" &&
      RINDLE_HYGIENE_ROOT="${C}/work" FAKE_DIR="${C}/fake" TMPDIR="${C}/tmpdir" \
        PATH="${BIN}:${PATH}" bash "${HYGIENE_SCRIPT_UNDER_TEST:-$SCRIPT}" "$@"
  ) >"${C}/out" 2>&1 || RC=$?
}

has() { grep -Fq -- "$1" "${C}/out"; }

# expect NAME RC [present TEXT]... [absent TEXT]...
expect() {
  local name="$1" want_rc="$2"
  shift 2
  local why=""
  [ "${RC}" = "${want_rc}" ] || why="exit ${RC}, wanted ${want_rc}"
  while [ "$#" -ge 2 ]; do
    case "$1" in
      present) has "$2" || why="${why:+${why}; }missing '$2'" ;;
      absent) ! has "$2" || why="${why:+${why}; }unexpected '$2'" ;;
    esac
    shift 2
  done
  if [ -s "${C}/fake/mutations" ]; then
    why="${why:+${why}; }gh write call: $(tr '\n' ' ' <"${C}/fake/mutations")"
  fi
  if [ -z "${why}" ]; then
    ok "${name}"
  else
    bad "${name}: ${why}"
    sed 's/^/      | /' "${C}/out"
  fi
}

# commit_in DIR MESSAGE FILE: writes FILE in DIR and commits it.
commit_in() {
  printf '%s\n' "$2" >>"$1/$3"
  git_q -C "$1" add -- "$3"
  git_q -C "$1" commit -q -m "$2"
}

build_seed "0.5.0" "0.5.0"

# --- fetch, branch and head ------------------------------------------------------------------
new_case
run_hygiene
expect "clean clone on main equal to origin/main: safe" 0 \
  present "[PASS] fetch" present "[PASS] branch: main" present "[PASS] head vs origin" \
  present "[PASS] artifact ledger" present "[PASS] tracked junk" \
  present "[PASS] generated drift: 1 generator(s) rerun" present "[PASS] post-verification residue" \
  absent "[BLOCK]" present "Result: safe to start release prep"
if grep -Fxq "brandbook/src/sync-admin-css.mjs" "${C}/fake/node.log" 2>/dev/null && [ ! -e "${C}/fake/mix-ci-started" ] &&
  ! grep -q '^ci' "${C}/fake/mix.log" 2>/dev/null; then
  ok "clean clone: the vetted generator ran as argv and mix ci did not run without --with-mix-ci"
else
  bad "clean clone generator/mix ci calls: node=$(tr '\n' ' ' <"${C}/fake/node.log" 2>/dev/null) mix=$(tr '\n' ' ' <"${C}/fake/mix.log" 2>/dev/null)"
fi

new_case
run_hygiene --release-prep
expect "release-prep on a clean clone: safe" 0 \
  present "Rindle repo hygiene report (release-prep)" absent "[BLOCK]"

new_case
git_q -C "${C}/work" remote set-url origin "${C}/missing-origin.git"
run_hygiene
expect "unreachable remote: BLOCK fetch" 1 present "[BLOCK] fetch" present "Result: not ready" \
  absent "[PASS] head vs origin"

new_case
git_q -C "${C}/work" remote set-url origin "${C}/missing-origin.git"
run_hygiene --release-prep
expect "unreachable remote in release-prep: BLOCK fetch" 1 present "[BLOCK] fetch"

new_case
git_q -C "${C}/work" remote set-url origin "${C}/missing-origin.git"
run_hygiene --ci
expect "--ci does not fetch: unreachable remote is not a BLOCK" 0 \
  absent "fetch" absent "[BLOCK]" absent "branch:"

new_case
git_q -C "${C}/work" checkout -q -b feature
run_hygiene
expect "feature branch: BLOCK branch" 1 present "[BLOCK] branch: on 'feature'" \
  present "[PASS] head vs origin"

new_case
git_q -C "${C}/work" checkout -q --detach
run_hygiene
expect "detached HEAD: BLOCK branch, never PASS HEAD" 1 \
  present "[BLOCK] branch: on 'DETACHED'" absent "[PASS] branch"

new_case
git_q clone -q "${C}/origin.git" "${C}/other"
commit_in "${C}/other" "upstream change" lib/upstream.txt
git_q -C "${C}/other" push -q origin main
run_hygiene
expect "origin has a newer commit: BLOCK head vs origin behind=1" 1 \
  present "[BLOCK] head vs origin: HEAD is behind=1 ahead=0"

new_case
snapshot_sha="$(git -C "${C}/work" rev-parse HEAD)"
git_q clone -q "${C}/origin.git" "${C}/other"
commit_in "${C}/other" "metadata advancement" .planning/metadata-note.md
git_q -C "${C}/other" push -q origin main
HYGIENE_SCRIPT_UNDER_TEST="${C}/work/scripts/maintainer/repo_hygiene_check.sh" FAKE_GH_CI=pending \
  run_hygiene --release-prep --snapshot-subject "$snapshot_sha" --repo fixture/rindle --snapshot-evidence "${C}/retained-admission"
expect "admitted snapshot survives metadata advancement and newer pending main CI" 0 \
  present "Rindle repo hygiene report (snapshot)" present "[PASS] snapshot source" \
  present "[PASS] snapshot CI" present "[PASS] generated drift" absent "[WARN]" absent "[BLOCK]" \
  present "no current-main or release eligibility"
if [[ -f "${C}/retained-admission/subject.json" && -s "${C}/fake/admission.log" ]]; then
  ok "snapshot admission is retained separately from source checkout"
else bad "snapshot admission was not retained"; fi

new_case
snapshot_sha="$(git -C "${C}/work" rev-parse HEAD)"
HYGIENE_SCRIPT_UNDER_TEST="${C}/work/scripts/maintainer/repo_hygiene_check.sh" FAKE_SNAPSHOT_ADMIT=fail \
  run_hygiene --snapshot-subject "$snapshot_sha" --repo fixture/rindle
expect "failed protected-main admission refuses repository execution" 1 \
  present "[BLOCK] snapshot source" present "repository execution refused" absent "[PASS] generated drift"
if [[ ! -s "${C}/fake/node.log" ]]; then ok "failed admission never runs generators"; else bad "failed admission executed generator"; fi

new_case
snapshot_sha="$(git -C "${C}/work" rev-parse HEAD)"
HYGIENE_SCRIPT_UNDER_TEST="${C}/work/scripts/maintainer/repo_hygiene_check.sh" FAKE_SNAPSHOT_ADMIT=foreign \
  run_hygiene --snapshot-subject "$snapshot_sha" --repo fixture/rindle
expect "foreign admission subject fails closed" 1 present "[BLOCK] snapshot source" absent "[PASS] generated drift"

new_case
snapshot_sha="$(git -C "${C}/work" rev-parse HEAD)"
commit_in "${C}/work" "unpublished local change" lib/local.txt
HYGIENE_SCRIPT_UNDER_TEST="${C}/work/scripts/maintainer/repo_hygiene_check.sh" \
  run_hygiene --snapshot-subject "$snapshot_sha" --repo fixture/rindle
expect "snapshot request cannot substitute another local HEAD" 1 present "checkout/controller/source identity" absent "[PASS] generated drift"

new_case
snapshot_sha="$(git -C "${C}/work" rev-parse HEAD)"
echo dirty >>"${C}/work/lib/fixture.ex"
HYGIENE_SCRIPT_UNDER_TEST="${C}/work/scripts/maintainer/repo_hygiene_check.sh" \
  run_hygiene --snapshot-subject "$snapshot_sha" --repo fixture/rindle
expect "dirty snapshot refuses repository execution" 1 present "checkout/controller/source identity" absent "[PASS] generated drift"

new_case
snapshot_sha="$(git -C "${C}/work" rev-parse HEAD)"
run_hygiene --snapshot-subject "$snapshot_sha" --repo fixture/rindle
expect "snapshot controller must belong to the checked source root" 1 present "checkout/controller/source identity"

new_case
run_hygiene --ci --snapshot-subject 0000000000000000000000000000000000000000 --repo fixture/rindle
expect "snapshot and CI-only modes cannot mix" 64 present "cannot be combined"

new_case
commit_in "${C}/work" "local change" lib/local.txt
run_hygiene --release-prep
expect "local unpushed commit: BLOCK head vs origin ahead=1" 1 \
  present "[BLOCK] head vs origin: HEAD is behind=0 ahead=1"

new_case
git_q -C "${C}/work" checkout -q -b release
git_q -C "${C}/work" push -q origin release
RINDLE_HYGIENE_BRANCH=release run_hygiene
expect "RINDLE_HYGIENE_BRANCH selects the expected branch" 0 \
  present "[PASS] branch: release" present "[PASS] head vs origin: HEAD matches origin/release"

new_case
run_hygiene --bogus
expect "unknown argument: usage exit 64" 64 present "Unknown argument: --bogus"

new_case
run_hygiene --ci --with-mix-ci
expect "--ci with --with-mix-ci: usage exit 64" 64 present "cannot be combined"

# --- tracked junk ------------------------------------------------------------------------------
# force_commit_push FILE CONTENT: commits FILE (even when ignored) on main and pushes it, so
# HEAD still equals origin/main.
force_commit_push() {
  mkdir -p "$(dirname "${C}/work/$1")"
  printf '%s\n' "$2" >"${C}/work/$1"
  git_q -C "${C}/work" add -f -- "$1"
  git_q -C "${C}/work" commit -q -m "add $1"
  git_q -C "${C}/work" push -q origin main
}

new_case
force_commit_push lib/.DS_Store junk
run_hygiene
expect "committed .DS_Store: BLOCK tracked junk" 1 present "[BLOCK] tracked junk: lib/.DS_Store"

new_case
force_commit_push lib/.DS_Store junk
run_hygiene --ci
expect "committed .DS_Store under --ci: BLOCK tracked junk" 1 present "[BLOCK] tracked junk: lib/.DS_Store"

new_case
force_commit_push lib/data.cache cached
run_hygiene --ci
expect "committed file an ignore rule matches: BLOCK tracked junk" 1 \
  present "[BLOCK] tracked junk: lib/data.cache"

new_case
force_commit_push lib/debug.log "log line"
run_hygiene --ci
expect "committed file matching a ledger junk pattern only: BLOCK tracked junk" 1 \
  present "[BLOCK] tracked junk: lib/debug.log"

# --- generated drift ---------------------------------------------------------------------------
new_case
FAKE_NODE=rewrite run_hygiene
expect "generator rewrites a drift path: BLOCK generated drift" 1 \
  present "[BLOCK] generated drift: regenerated files differ from HEAD: priv/static/rindle_admin/rindle-admin.css"

new_case
FAKE_NODE=rewrite run_hygiene --release-prep
expect "generator rewrites a drift path in release-prep: BLOCK generated drift" 1 \
  present "[BLOCK] generated drift: regenerated files differ from HEAD"

new_case
FAKE_NODE=untracked run_hygiene
expect "generator creates an untracked file beside a drift path: BLOCK generated drift" 1 \
  present "[BLOCK] generated drift: generators created untracked files: priv/static/rindle_admin/rindle-admin.extra.css"

new_case
FAKE_NODE=rewrite run_hygiene --ci
expect "--ci skips generated drift (brandbook-tokens proves it on PRs)" 0 \
  absent "generated drift" absent "[BLOCK]"
if [ ! -s "${C}/fake/node.log" ]; then ok "--ci runs no generator"; else bad "--ci ran node: $(tr '\n' ' ' <"${C}/fake/node.log")"; fi

new_case
git_q -C "${C}/work" checkout -q -b feature
FAKE_NODE=rewrite run_hygiene
expect "unverified branch: generators are not run" 1 \
  present "[BLOCK] generated drift: not run" absent "regenerated files differ"
if [ ! -s "${C}/fake/node.log" ]; then ok "unverified branch runs no generator"; else bad "unverified branch ran node"; fi

new_case
INJ="${C}/pwned"
write_ledger "${C}/work/scripts/maintainer/artifact_ledger.json" "node brandbook/src/sync-admin-css.mjs; touch ${INJ}"
git_q -C "${C}/work" commit -q -am "unvetted generator"
git_q -C "${C}/work" push -q origin main
run_hygiene
expect "ledger lists an unvetted generator command: BLOCK generated drift" 1 \
  present "[BLOCK] generated drift: class admin-css lists a command outside the vetted set; it was not run"
if [ ! -e "${INJ}" ] && [ ! -s "${C}/fake/node.log" ]; then
  ok "unvetted ledger command is data: not executed"
else
  bad "unvetted ledger command ran (pwned: $([ -e "${INJ}" ] && echo yes || echo no))"
fi

# --- mix ci ------------------------------------------------------------------------------------
new_case
FAKE_MIX_CI=fail run_hygiene --with-mix-ci
expect "mix ci exits non-zero: BLOCK mix ci" 1 present "[BLOCK] mix ci: mix ci exited 2" \
  absent "compile failed"

new_case
FAKE_MIX_CI=partial run_hygiene --with-mix-ci
expect "mix ci exits 0 with two of three sentinels: BLOCK mix ci incomplete" 1 \
  present "[BLOCK] mix ci incomplete: mix ci exited 0 without completion sentinel(s): exunit-summary"

new_case
FAKE_MIX_CI=ok run_hygiene --with-mix-ci
expect "mix ci with every sentinel: PASS mix ci, log not printed" 0 \
  present "[PASS] mix ci: full alias completed" absent "[BLOCK]" absent "Compiling" absent "doctests"

new_case
FAKE_MIX_CI=ok run_hygiene --release-prep --with-mix-ci
expect "release-prep with mix ci: PASS mix ci" 0 present "[PASS] mix ci" absent "[BLOCK]"

# --- post-verification residue -----------------------------------------------------------------
new_case
FAKE_MIX_CI=untracked run_hygiene --with-mix-ci
expect "verification leaves an untracked file: BLOCK post-verification residue" 1 \
  present "[BLOCK] post-verification residue: stray-output.txt"

new_case
FAKE_MIX_CI=build run_hygiene --with-mix-ci
expect "verification writes under _build/: no residue BLOCK" 0 \
  present "[PASS] post-verification residue" absent "[BLOCK]"

new_case
FAKE_MIX_CI=ignored run_hygiene --with-mix-ci
expect "verification leaves an ignored file outside the roots: BLOCK post-verification residue" 1 \
  present "[BLOCK] post-verification residue: stray-output.cache"

# --- interruption ------------------------------------------------------------------------------
new_case
git -C "${C}/work" -c core.excludesFile=/dev/null status --porcelain=v1 -uall --ignored >"${C}/status-before"
(
  cd "${C}/work" &&
    exec env RINDLE_HYGIENE_ROOT="${C}/work" FAKE_DIR="${C}/fake" TMPDIR="${C}/tmpdir" \
      FAKE_MIX_CI=sleep PATH="${BIN}:${PATH}" bash "${SCRIPT}" --with-mix-ci
) >"${C}/out" 2>&1 &
PID=$!
n=0
while [ ! -e "${C}/fake/mix-ci-started" ] && [ "${n}" -lt 200 ]; do
  sleep 0.1
  n=$((n + 1))
done
START="$(date +%s)"
kill -TERM "${PID}" 2>/dev/null
RC=0
wait "${PID}" || RC=$?
ELAPSED=$(($(date +%s) - START))
git -C "${C}/work" -c core.excludesFile=/dev/null status --porcelain=v1 -uall --ignored >"${C}/status-after"
LEFT="$(ls -A "${C}/tmpdir")"
if [ -e "${C}/fake/mix-ci-started" ] && [ "${RC}" = 143 ] && [ -z "${LEFT}" ] && [ "${ELAPSED}" -lt 10 ] &&
  cmp -s "${C}/status-before" "${C}/status-after"; then
  ok "SIGTERM during mix ci: exits 143 promptly, no log left in TMPDIR, checkout unchanged"
else
  bad "SIGTERM during mix ci: rc=${RC} elapsed=${ELAPSED}s left='${LEFT}' status-diff=$(diff "${C}/status-before" "${C}/status-after" | tr '\n' ' ')"
fi

# --- hex baseline publish race -----------------------------------------------------------------
# mix.exs is 0.5.1 and Hex already lists it; RELEASE-TRAIN still records 0.5.0.
build_seed "0.5.1" "0.5.0"

new_case
FAKE_HEX_VERSION=0.5.1 run_hygiene --ci
expect "publish race under --ci: WARN hex baseline, exit 0" 0 \
  present "[WARN] hex baseline: Hex.pm (0.5.1) matches mix.exs" present "release workflow baseline record" \
  absent "[BLOCK]" present "Result: proceed with caution"

new_case
FAKE_HEX_VERSION=0.5.1 run_hygiene --release-prep
expect "publish race under --release-prep: BLOCK hex baseline" 1 \
  present "[BLOCK] hex baseline: Hex.pm (0.5.1) matches mix.exs"

new_case
FAKE_HEX_VERSION=0.5.0 run_hygiene --ci
expect "before publish under --ci: PASS hex baseline" 0 \
  present "[PASS] hex baseline: mix.exs (0.5.1) ahead of baseline (0.5.0) until publish completes"

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
