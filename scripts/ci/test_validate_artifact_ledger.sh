#!/usr/bin/env bash
# test_validate_artifact_ledger.sh - real-git fixture harness for
# scripts/maintainer/validate_artifact_ledger.sh. Each case builds a small temp git repository,
# writes a ledger outside it and asserts the exit code and the exact REJECT reason. Needs only
# bash, jq, git, tar and coreutils: no network, no Elixir. Bash 3.2 / jq 1.6 compatible.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="${ROOT}/scripts/maintainer/validate_artifact_ledger.sh"
LIVE_LEDGER="${ROOT}/scripts/maintainer/artifact_ledger.json"
T="$(mktemp -d)"
trap 'chmod -R u+w "${T}" 2>/dev/null; rm -rf "${T}"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

gitq() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false "$@"; }

# --- base fixture repository --------------------------------------------------------------
BASE="${T}/base"
mkdir -p "${BASE}/lib" "${BASE}/docs" "${BASE}/receipts/fixture-receipt" "${BASE}/tools"
printf 'defmodule A do\nend\n' >"${BASE}/lib/a.ex"
printf 'defmodule B do\nend\n' >"${BASE}/lib/b.ex"
printf '# Fixture\n' >"${BASE}/README.md"
printf '# Guide\n' >"${BASE}/docs/guide.md"
printf '{"census": 1}\n' >"${BASE}/receipts/fixture-receipt/census.json"
printf 'export const x = 1;\n' >"${BASE}/tools/build.mjs"
printf ':root { --x: 1; }\n' >"${BASE}/tools/gen.css"
cat >"${BASE}/mix.exs" <<'EOF'
defmodule Fixture.MixProject do
  use Mix.Project

  defp package do
    [
      files:
        ~w(lib README.md mix.exs)
    ]
  end
end
EOF
printf '# build output\n/_build/\n\n*.log\n' >"${BASE}/.gitignore"
(
  cd "${BASE}" || exit 1
  gitq init -q .
  gitq add -A
  gitq commit -q -m fixture
) || { echo "FAIL - could not build the base fixture repository"; exit 1; }

cat >"${T}/base_ledger.json" <<'EOF'
{
  "schema": "rindle-artifact-ledger-v1",
  "classes": [
    {"id": "pkg-lib", "pathspecs": [":(glob)lib/**"], "authority": "hand-authored", "consumer": ["mix.exs"],
     "package": "shipped", "disposition": "retain", "reason": "library source"},
    {"id": "pkg-root", "pathspecs": ["README.md", "mix.exs"], "authority": "hand-authored", "consumer": ["lib/a.ex"],
     "package": "shipped", "disposition": "retain", "reason": "manifest and readme"},
    {"id": "docs", "pathspecs": [":(glob)docs/**"], "authority": "hand-authored", "consumer": ["README.md"],
     "package": "excluded", "disposition": "retain", "reason": "docs"},
    {"id": "receipt", "pathspecs": [":(glob)receipts/fixture-receipt/**"], "authority": "immutable-receipt",
     "consumer": ["tools/build.mjs"], "package": "excluded", "disposition": "retain", "reason": "frozen receipt",
     "retained_receipt": {"root": "receipts/fixture-receipt", "identity": "fixture census identity"}},
    {"id": "tools-src", "pathspecs": ["tools/build.mjs"], "authority": "hand-authored", "consumer": ["README.md"],
     "package": "excluded", "disposition": "retain", "reason": "generator"},
    {"id": "tools-gen", "pathspecs": ["tools/gen.css"], "authority": "generated", "consumer": ["README.md"],
     "package": "excluded", "disposition": "retain", "reason": "generated stylesheet",
     "regenerate": {"commands": ["node brandbook/src/tokens-build.mjs"], "drift_paths": ["tools/gen.css"], "drift_check": "hygiene"}},
    {"id": "vcs", "pathspecs": [".gitignore"], "authority": "hand-authored", "consumer": ["README.md"],
     "package": "excluded", "disposition": "retain", "reason": "ignore rules"}
  ],
  "ignore_rules": [
    {"file": ".gitignore", "rule": "/_build/", "produced_by": "mix compile", "disposition": "ignore"},
    {"file": ".gitignore", "rule": "*.log", "produced_by": "tools", "disposition": "ignore"}
  ],
  "tracked_junk_patterns": [":(glob)**/.DS_Store", ":(glob)**/*.orig"],
  "verification_ignored_roots": ["_build/"]
}
EOF

# newcase: fresh copy of the base repository; prints its path.
newcase() {
  local d
  d="$(mktemp -d "${T}/case.XXXXXX")"
  cp -R "${BASE}/." "${d}"
  echo "${d}"
}

# run REPO LEDGER [extra args...] -> sets RC, writes ${T}/out and ${T}/err
run() {
  local repo="$1" ledger="$2"
  shift 2
  RC=0
  bash "${VALIDATOR}" --offline --ledger "${ledger}" --root "${repo}" "$@" >"${T}/out" 2>"${T}/err" || RC=$?
}

verdict() {
  local name="$1" want="$2" pat="$3"
  if [ "${RC}" != "${want}" ]; then
    bad "${name} (exit ${RC}, want ${want}): $(tr '\n' '|' <"${T}/err")"
  elif [ -n "${pat}" ] && ! grep -qF -- "${pat}" "${T}/err"; then
    bad "${name} (missing reason text: ${pat}): $(tr '\n' '|' <"${T}/err")"
  else
    ok "${name}"
  fi
}

# case NAME LEDGER_FILTER EXPECT_EXIT PATTERN [SETUP_SHELL_FN]
case_() {
  local name="$1" lf="$2" want="$3" pat="$4" setup="${5:-}"
  local repo
  repo="$(newcase)"
  if [ -n "${setup}" ]; then (cd "${repo}" && "${setup}") >/dev/null 2>&1 || { bad "${name} (setup failed)"; return; }; fi
  jq -S "${lf}" "${T}/base_ledger.json" >"${T}/l.json"
  run "${repo}" "${T}/l.json"
  verdict "${name}" "${want}" "${pat}"
}

ID='.'

add_uncovered() { printf 'x\n' >notes.txt && gitq add notes.txt && gitq commit -q -m notes; }

# --- partition ----------------------------------------------------------------------------
case_ "partition: clean fixture exits 0" "${ID}" 0 ""
case_ "partition: file no class covers is uncovered" "${ID}" 1 "REJECT: uncovered: notes.txt" add_uncovered
case_ "adjacency: overlapping classes double-classify" \
  '.classes += [{"id":"overlap","pathspecs":["lib/a.ex"],"authority":"hand-authored","consumer":["mix.exs"],"package":"shipped","disposition":"retain","reason":"overlap"}]' \
  1 "REJECT: double-classified: lib/a.ex (pkg-lib, overlap)"
case_ "adjacency: identical pathspecs double-classify, never merge" \
  '.classes += [(.classes[2] | .id = "docs-twin")]' 1 "REJECT: double-classified: docs/guide.md (docs, docs-twin)"
case_ "partition: exclude carves a sub-tree out of a class" \
  '(.classes[0].pathspecs) += [":(exclude)lib/b.ex"] | .classes += [{"id":"lib-b","pathspecs":["lib/b.ex"],"authority":"hand-authored","consumer":["mix.exs"],"package":"shipped","disposition":"retain","reason":"carved"}]' \
  0 ""

# --- empty input --------------------------------------------------------------------------
case_ "empty: class matching no tracked file is stale" \
  '.classes += [{"id":"ghost","pathspecs":[":(glob)ghost/**"],"authority":"hand-authored","consumer":["mix.exs"],"package":"excluded","disposition":"retain","reason":"none"}]' \
  1 "REJECT: stale class: ghost matches no tracked file"
case_ "empty: no classes rejected" '.classes = []' 1 "REJECT: classes: ledger has no classes"
case_ "empty: class with no pathspecs rejected" '.classes[2].pathspecs = []' 1 "REJECT: pathspecs: class docs needs a non-empty pathspecs list"
case_ "empty: exclude-only pathspecs rejected (would match the whole tree)" '.classes[2].pathspecs = [":(exclude)lib/a.ex"]' 1 "REJECT: pathspecs: class docs needs"
case_ "empty: short-form exclude-only pathspecs rejected" '.classes[2].pathspecs = [":!lib/a.ex"]' 1 "REJECT: pathspecs: class docs needs"
case_ "pathspecs: unanchored wildcard exclude rejected" '(.classes[0].pathspecs) += [":(glob,exclude)**/b.ex"]' 1 "must start with a literal path"
case_ "schema: wrong schema id rejected" '.schema = "v0"' 1 "REJECT: schema"
case_ "identity: duplicate class id rejected" '.classes[2].id = "pkg-lib"' 1 "REJECT: duplicate class id: pkg-lib"

# --- ordering, idempotency, concurrency ----------------------------------------------------
repo="$(newcase)"
(cd "${repo}" && printf 'z\n' >zz.txt && printf 'a\n' >aa.txt && gitq add zz.txt aa.txt && gitq commit -q -m two) >/dev/null 2>&1
jq -S '.classes += [{"id":"ghost","pathspecs":["ghost.txt"],"authority":"hand-authored","consumer":["mix.exs"],"package":"excluded","disposition":"retain","reason":"none"}]' \
  "${T}/base_ledger.json" >"${T}/multi.json"
run "${repo}" "${T}/multi.json"
cp "${T}/err" "${T}/err1"
if [ "${RC}" = 1 ] && [ "$(LC_ALL=C sort "${T}/err1")" = "$(cat "${T}/err1")" ] && [ "$(wc -l <"${T}/err1" | tr -d ' ')" = 3 ]; then
  ok "ordering: all reasons reported in one run, sorted by rule then path"
else
  bad "ordering: $(tr '\n' '|' <"${T}/err1")"
fi
status_before="$(git -C "${repo}" status --porcelain --ignored)"
run "${repo}" "${T}/multi.json"
status_after="$(git -C "${repo}" status --porcelain --ignored)"
if cmp -s "${T}/err1" "${T}/err" && [ "${status_before}" = "${status_after}" ]; then
  ok "idempotency: second run yields identical output and leaves git status unchanged"
else
  bad "idempotency: output or git status changed between runs"
fi

repo="$(newcase)"
jq -S . "${T}/base_ledger.json" >"${T}/conc.json"
( bash "${VALIDATOR}" --offline --ledger "${T}/conc.json" --root "${repo}" >"${T}/c1.out" 2>"${T}/c1.err"; echo $? >"${T}/c1.rc" ) &
( bash "${VALIDATOR}" --offline --ledger "${T}/conc.json" --root "${repo}" >"${T}/c2.out" 2>"${T}/c2.err"; echo $? >"${T}/c2.rc" ) &
wait
if [ "$(cat "${T}/c1.rc")" = 0 ] && [ "$(cat "${T}/c2.rc")" = 0 ] && cmp -s "${T}/c1.out" "${T}/c2.out" && cmp -s "${T}/c1.err" "${T}/c2.err"; then
  ok "concurrency: two concurrent runs both exit 0 with identical output"
else
  bad "concurrency: rc $(cat "${T}/c1.rc")/$(cat "${T}/c2.rc")"
fi

# --- CLI ----------------------------------------------------------------------------------
RC=0; bash "${VALIDATOR}" >/dev/null 2>&1 || RC=$?
[ "${RC}" = 64 ] && ok "cli: no arguments exits 64" || bad "cli: no arguments exits 64 (got ${RC})"
RC=0; bash "${VALIDATOR}" --ledger "${T}/base_ledger.json" >/dev/null 2>&1 || RC=$?
[ "${RC}" = 64 ] && ok "cli: missing --offline exits 64" || bad "cli: missing --offline exits 64 (got ${RC})"
RC=0; bash "${VALIDATOR}" --offline --ledger "${T}/base_ledger.json" --bogus >/dev/null 2>&1 || RC=$?
[ "${RC}" = 64 ] && ok "cli: unknown flag exits 64" || bad "cli: unknown flag exits 64 (got ${RC})"
echo "{ not json" >"${T}/broken.json"
run "${BASE}" "${T}/broken.json"
verdict "cli: malformed ledger rejected" 1 "REJECT: unreadable"

# --- live ledger --------------------------------------------------------------------------
RC=0
bash "${VALIDATOR}" --offline --ledger "${LIVE_LEDGER}" --root "${ROOT}" >"${T}/out" 2>"${T}/err" || RC=$?
verdict "live: committed ledger partitions the repository" 0 ""

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
