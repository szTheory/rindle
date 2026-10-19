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
esac
exit 0
FAKE_MIX

cat >"${BIN}/node" <<'FAKE_NODE'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"${FAKE_DIR}/node.log"
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
      list) echo '[{"conclusion":"success","status":"completed","url":"https://example.invalid/run/1"}]'; exit 0 ;;
    esac
    ;;
esac
case "${1-} ${2-}" in
  "pr list"|"pr view"|"run view"|"release list"|"release view") exit 0 ;;
esac
echo "$*" >>"${FAKE_DIR}/mutations"
exit 0
FAKE_GH

chmod +x "${BIN}/mix" "${BIN}/node" "${BIN}/gh"

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
        PATH="${BIN}:${PATH}" bash "${SCRIPT}" "$@"
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
  absent "[BLOCK]" present "Result: safe to start release prep"

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

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
