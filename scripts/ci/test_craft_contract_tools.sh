#!/usr/bin/env bash
# test_craft_contract_tools.sh - fixture harness for the readability contract tools:
#   scripts/maintainer/validate_readability_trace.sh
#   scripts/maintainer/craft_boundary_check.sh
# One failing fixture per rejection rule plus clean fixtures. Needs only bash, jq, git and
# coreutils: no network, no gh, no Elixir. Bash 3.2 / jq 1.6 compatible.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRACE_VALIDATOR="${ROOT}/scripts/maintainer/validate_readability_trace.sh"
TRACE="${ROOT}/scripts/maintainer/readability_changes.json"
T="$(mktemp -d)"
trap 'chmod -R u+w "${T}" 2>/dev/null; rm -rf "${T}"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

verdict() {
  local name="$1" rc="$2" want="$3" pat="$4"
  if [ "${rc}" != "${want}" ]; then
    bad "${name} (exit ${rc}, want ${want}): $(tr '\n' '|' <"${T}/err")"
  elif [ -n "${pat}" ] && ! grep -qF -- "${pat}" "${T}/err"; then
    bad "${name} (missing reason text: ${pat}): $(tr '\n' '|' <"${T}/err")"
  else
    ok "${name}"
  fi
}

gitq() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false "$@"; }

# --- trace fixtures -----------------------------------------------------------------------
ANCHOR='{"check": "Credo.Check.Refactor.CyclomaticComplexity", "file": "lib/sample/widget.ex", "trigger": "render", "observed_metric": 12}'
KEPT='{"check": "Credo.Check.Refactor.CyclomaticComplexity", "file": "lib/sample/other.ex", "trigger": "parse", "observed_metric": 11}'

jq -n --argjson a "${ANCHOR}" --argjson k "${KEPT}" \
  '{entries: [($a + {count: 1, owner: "sample", removal_trigger: "sample"}), ($k + {count: 1, owner: "sample", removal_trigger: "sample"})]}' \
  >"${T}/baseline_before.json"
jq -n --argjson k "${KEPT}" '{entries: [($k + {count: 1, owner: "sample", removal_trigger: "sample"})]}' \
  >"${T}/baseline_after.json"

jq -S --argjson a "${ANCHOR}" '.changes = [{
    id: "widget-render-split",
    candidate_id: "quality-maintainability-curated-complexity",
    detector: "credo complexity baseline",
    anchor: $a,
    files: ["lib/sample/widget.ex"],
    intent: "cohesion",
    proof: ["mix credo_quality", "bash scripts/maintainer/refactor_contract.sh"],
    pr: null
  }]' "${TRACE}" >"${T}/trace_one.json"

# trace NAME TRACE_FILTER BASELINE EXPECT_EXIT PATTERN
trace() {
  local name="$1" tf="$2" baseline="$3" want="$4" pat="$5"
  jq -S "${tf}" "${T}/trace_one.json" >"${T}/t.json"
  local rc=0
  bash "${TRACE_VALIDATOR}" --offline --trace "${T}/t.json" --baseline "${baseline}" >"${T}/out" 2>"${T}/err" || rc=$?
  verdict "${name}" "${rc}" "${want}" "${pat}"
}

AFTER="${T}/baseline_after.json"
BEFORE="${T}/baseline_before.json"

rc=0
bash "${TRACE_VALIDATOR}" --offline --trace "${TRACE}" \
  --baseline "${ROOT}/scripts/maintainer/credo_complexity_baseline.json" >"${T}/out" 2>"${T}/err" || rc=$?
verdict "trace: committed trace passes offline" "${rc}" 0 ""

trace "trace: one traced change passes offline" '.' "${AFTER}" 0 ""
trace "trace: sha256 altered" '.candidate_ledger.sha256 = ("0" * 64)' "${AFTER}" 1 "REJECT: ledger identity"
trace "trace: subject_sha altered" '.candidate_ledger.subject_sha = ("1" * 40)' "${AFTER}" 1 "REJECT: ledger identity"
trace "trace: candidate id list altered" '.candidate_ledger.candidate_ids += ["quality-invented"]' "${AFTER}" 1 "REJECT: ledger identity"
trace "trace: schema altered" '.schema = "other"' "${AFTER}" 1 "REJECT: schema"
trace "trace: candidate_id outside the pinned ids" '.changes[0].candidate_id = "quality-invented"' "${AFTER}" 1 "REJECT: candidate"
trace "trace: intent style" '.changes[0].intent = "style"' "${AFTER}" 1 "REJECT: intent"
trace "trace: empty proof" '.changes[0].proof = []' "${AFTER}" 1 "REJECT: proof"
trace "trace: empty files" '.changes[0].files = []' "${AFTER}" 1 "REJECT: files"
trace "trace: blank detector" '.changes[0].detector = " "' "${AFTER}" 1 "REJECT: detector"
trace "trace: pr not an integer" '.changes[0].pr = "42"' "${AFTER}" 1 "REJECT: pr"
trace "trace: pr integer accepted" '.changes[0].pr = 42' "${AFTER}" 0 ""
trace "trace: anchor missing a key" '.changes[0].anchor |= del(.trigger)' "${AFTER}" 1 "REJECT: anchor"
trace "trace: duplicate change id" '.changes += [.changes[0]]' "${AFTER}" 1 "REJECT: duplicate id"
trace "trace: anchor still present in the baseline" '.' "${BEFORE}" 1 "REJECT: anchor present"
trace "trace: changes not an array" '.changes = {}' "${AFTER}" 1 "REJECT: changes"

# all reasons in one run
jq -S '.changes[0].intent = "style" | .changes[0].candidate_id = "x" | .candidate_ledger.sha256 = "y"' \
  "${T}/trace_one.json" >"${T}/t.json"
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${T}/t.json" --baseline "${AFTER}" >/dev/null 2>"${T}/err" || rc=$?
if [ "${rc}" = 1 ] && [ "$(grep -c '^REJECT: ' "${T}/err")" -ge 3 ]; then ok "trace: every reason reported in one run"; else bad "trace: all reasons (rc ${rc}): $(tr '\n' '|' <"${T}/err")"; fi

# unreadable and usage
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${T}/absent.json" --baseline "${AFTER}" >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: missing trace file" "${rc}" 1 "REJECT: unreadable"
printf '{not json' >"${T}/broken.json"
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${T}/broken.json" --baseline "${AFTER}" >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: invalid JSON trace" "${rc}" 1 "REJECT: unreadable"
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${TRACE}" --baseline "${AFTER}" --bogus >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: unknown flag is a usage error" "${rc}" 64 "unknown argument"
rc=0; bash "${TRACE_VALIDATOR}" --trace "${TRACE}" --baseline "${AFTER}" >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: missing mode is a usage error" "${rc}" 64 ""

# --verify-source
printf 'not the ledger\n' >"${T}/ledger_copy.json"
rc=0; bash "${TRACE_VALIDATOR}" --verify-source "${T}/ledger_copy.json" --trace "${TRACE}" >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: verify-source rejects a different file" "${rc}" 1 "REJECT: source sha256"

# --- --base against a real git history ----------------------------------------------------
R="${T}/repo"
mkdir -p "${R}/scripts/maintainer"
gitq -C "${R}" init -q
cp "${BEFORE}" "${R}/scripts/maintainer/credo_complexity_baseline.json"
gitq -C "${R}" add scripts/maintainer/credo_complexity_baseline.json
gitq -C "${R}" commit -q -m base
cp "${AFTER}" "${R}/scripts/maintainer/credo_complexity_baseline.json"

rc=0
(cd "${R}" && bash "${TRACE_VALIDATOR}" --base HEAD --trace "${T}/trace_one.json" \
  --baseline scripts/maintainer/credo_complexity_baseline.json) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "trace --base: anchor removed since base passes" "${rc}" 0 ""

jq -S '.changes[0].anchor.observed_metric = 99' "${T}/trace_one.json" >"${T}/t.json"
rc=0
(cd "${R}" && bash "${TRACE_VALIDATOR}" --base HEAD --trace "${T}/t.json" \
  --baseline scripts/maintainer/credo_complexity_baseline.json) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "trace --base: anchor absent at base" "${rc}" 1 "REJECT: anchor not in base"

rc=0
(cd "${R}" && bash "${TRACE_VALIDATOR}" --base no-such-ref --trace "${T}/trace_one.json" \
  --baseline scripts/maintainer/credo_complexity_baseline.json) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "trace --base: unknown ref is rejected" "${rc}" 1 "REJECT: base"

# --- untrusted text is never executed -----------------------------------------------------
INJ="${T}/pwned"
jq -S --arg c "\$(touch ${INJ})" \
  '.changes[0].id = $c | .changes[0].detector = ("`touch " + $c + "`") | .changes[0].intent = $c | .changes[0].proof = [$c]' \
  "${T}/trace_one.json" >"${T}/t.json"
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${T}/t.json" --baseline "${AFTER}" >/dev/null 2>&1 || rc=$?
if [ ! -e "${INJ}" ] && [ "${rc}" = 1 ]; then ok "trace: shell substitution text is data, never executed"; else bad "trace injection (rc ${rc}, file exists: $([ -e "${INJ}" ] && echo yes || echo no))"; fi

# --- craft_boundary_check.sh against a real git history -------------------------------------
B="${T}/boundary"
mkdir -p "${B}/lib/sample" "${B}/priv/repo/migrations" "${B}/.github/workflows" \
  "${B}/test/fixtures" "${B}/test/rindle/contracts"
cat >"${B}/mix.exs" <<'EOF'
defmodule Sample.MixProject do
  use Mix.Project

  @version "1.2.3"

  def project do
    [app: :sample, version: @version, deps: deps(), package: package(), aliases: aliases()]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md)
    ]
  end

  defp aliases do
    [
      # run the sample checks
      check: ["format --check-formatted"]
    ]
  end
end
EOF
printf 'defmodule Sample.Widget do\n  # renders a widget\n  def render, do: :ok\nend\n' >"${B}/lib/sample/widget.ex"
printf '%%{"jason": {:hex, :jason, "1.4.0"}}\n' >"${B}/mix.lock"
printf '# Changelog\n' >"${B}/CHANGELOG.md"
printf '{}\n' >"${B}/release-please-config.json"
printf '{".": "1.2.3"}\n' >"${B}/.release-please-manifest.json"
printf 'name: Release\n' >"${B}/.github/workflows/release.yml"
printf 'name: CI\n' >"${B}/.github/workflows/ci.yml"
printf 'defmodule Sample.Repo.Migrations.Create do\nend\n' >"${B}/priv/repo/migrations/20200101000000_create.exs"
printf 'module Sample.Widget\n' >"${B}/test/fixtures/public_surface.txt"
printf 'defmodule Sample.TelemetryContractTest do\nend\n' >"${B}/test/rindle/contracts/telemetry_contract_test.exs"
gitq -C "${B}" init -q
gitq -C "${B}" add -A
gitq -C "${B}" commit -q -m base
gitq -C "${B}" tag base

BOUNDARY="${ROOT}/scripts/maintainer/craft_boundary_check.sh"

# boundary NAME EXPECT_EXIT PATTERN MUTATION_FUNCTION
boundary() {
  local name="$1" want="$2" pat="$3" mutate="$4"
  gitq -C "${B}" checkout -q -f -B "case" base
  (cd "${B}" && "${mutate}")
  gitq -C "${B}" add -A
  gitq -C "${B}" commit -q --allow-empty -m change
  local rc=0
  (cd "${B}" && bash "${BOUNDARY}" base) >"${T}/out" 2>"${T}/err" || rc=$?
  verdict "${name}" "${rc}" "${want}" "${pat}"
}

m_lib_comment() { printf 'defmodule Sample.Widget do\n  # renders one widget\n  def render, do: :ok\nend\n' >lib/sample/widget.ex; }
m_nothing() { :; }
m_migration() { printf '# note\n' >>priv/repo/migrations/20200101000000_create.exs; }
m_new_migration() { printf 'defmodule M do\nend\n' >priv/repo/migrations/20300101000000_more.exs; }
m_lock() { printf '%%{}\n' >mix.lock; }
m_changelog() { printf '## 1.2.4\n' >>CHANGELOG.md; }
m_rp_config() { printf '{"a": 1}\n' >release-please-config.json; }
m_rp_manifest() { printf '{".": "1.2.4"}\n' >.release-please-manifest.json; }
m_release_wf() { printf 'on: push\n' >>.github/workflows/release.yml; }
m_release_wf_new() { printf 'name: Release Extra\n' >.github/workflows/release-extra.yml; }
m_ci_wf() { printf 'on: push\n' >>.github/workflows/ci.yml; }
m_surface() { printf 'module Sample.Other\n' >>test/fixtures/public_surface.txt; }
m_telemetry() { printf '# note\n' >>test/rindle/contracts/telemetry_contract_test.exs; }
m_version() { sed 's/@version "1.2.3"/@version "1.2.4"/' mix.exs >mix.tmp && mv mix.tmp mix.exs; }
m_dep() { sed 's/{:jason, "~> 1.4"}/{:jason, "~> 1.5"}/' mix.exs >mix.tmp && mv mix.tmp mix.exs; }
m_package() { sed 's/files: ~w(lib mix.exs README.md)/files: ~w(lib priv mix.exs README.md)/' mix.exs >mix.tmp && mv mix.tmp mix.exs; }
m_aliases_comment() { sed 's/# run the sample checks/# run every sample check/' mix.exs >mix.tmp && mv mix.tmp mix.exs; }
m_rename_migration() { git -c user.name=fixture -c user.email=fixture@example.invalid mv priv/repo/migrations/20200101000000_create.exs lib/sample/moved.exs; }

boundary "boundary: comment-only lib change passes" 0 "" m_lib_comment
boundary "boundary: empty change passes" 0 "" m_nothing
boundary "boundary: non-release workflow change passes" 0 "" m_ci_wf
boundary "boundary: aliases comment in mix.exs passes" 0 "" m_aliases_comment
boundary "boundary: migration edit" 1 "REJECT: forbidden path: priv/repo/migrations/20200101000000_create.exs" m_migration
boundary "boundary: new migration" 1 "REJECT: forbidden path: priv/repo/migrations/20300101000000_more.exs" m_new_migration
boundary "boundary: migration moved out" 1 "REJECT: forbidden path: priv/repo/migrations/20200101000000_create.exs" m_rename_migration
boundary "boundary: mix.lock" 1 "REJECT: forbidden path: mix.lock" m_lock
boundary "boundary: CHANGELOG.md" 1 "REJECT: forbidden path: CHANGELOG.md" m_changelog
boundary "boundary: release-please-config.json" 1 "REJECT: forbidden path: release-please-config.json" m_rp_config
boundary "boundary: .release-please-manifest.json" 1 "REJECT: forbidden path: .release-please-manifest.json" m_rp_manifest
boundary "boundary: release workflow" 1 "REJECT: forbidden path: .github/workflows/release.yml" m_release_wf
boundary "boundary: new release workflow" 1 "REJECT: forbidden path: .github/workflows/release-extra.yml" m_release_wf_new
boundary "boundary: public surface fixture" 1 "REJECT: forbidden path: test/fixtures/public_surface.txt" m_surface
boundary "boundary: telemetry contract test" 1 "REJECT: forbidden path: test/rindle/contracts/telemetry_contract_test.exs" m_telemetry
boundary "boundary: mix.exs @version" 1 "REJECT: mix.exs version" m_version
boundary "boundary: mix.exs dep line" 1 "REJECT: mix.exs deps" m_dep
boundary "boundary: mix.exs package files" 1 "REJECT: mix.exs package" m_package

# uncommitted working-tree change is part of the change set
gitq -C "${B}" checkout -q -f -B "case" base
printf '%%{}\n' >"${B}/mix.lock"
rc=0; (cd "${B}" && bash "${BOUNDARY}" base) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "boundary: uncommitted mix.lock edit" "${rc}" 1 "REJECT: forbidden path: mix.lock"
gitq -C "${B}" checkout -q -- mix.lock

# all reasons in one run
gitq -C "${B}" checkout -q -f -B "case" base
(cd "${B}" && m_lock && m_changelog && m_version)
gitq -C "${B}" add -A
gitq -C "${B}" commit -q -m multi
rc=0; (cd "${B}" && bash "${BOUNDARY}" base) >"${T}/out" 2>"${T}/err" || rc=$?
if [ "${rc}" = 1 ] && [ "$(grep -c '^REJECT: ' "${T}/err")" -ge 3 ]; then ok "boundary: every reason reported in one run"; else bad "boundary: all reasons (rc ${rc}): $(tr '\n' '|' <"${T}/err")"; fi

# base moved forward after branching: only this branch's changes count
gitq -C "${B}" checkout -q -f -B "moved" base
(cd "${B}" && m_version && m_lock)
gitq -C "${B}" add -A
gitq -C "${B}" commit -q -m release
gitq -C "${B}" checkout -q -f -B "case" base
(cd "${B}" && m_lib_comment)
gitq -C "${B}" add -A
gitq -C "${B}" commit -q -m comment
rc=0; (cd "${B}" && bash "${BOUNDARY}" moved) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "boundary: base that moved on is compared at the merge base" "${rc}" 0 ""

# usage and unknown base
rc=0; (cd "${B}" && bash "${BOUNDARY}" no-such-ref) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "boundary: unknown base ref" "${rc}" 64 "unknown base ref"
rc=0; (cd "${B}" && bash "${BOUNDARY}") >"${T}/out" 2>"${T}/err" || rc=$?
verdict "boundary: missing base is a usage error" "${rc}" 64 "usage"
rc=0; (cd "${B}" && bash "${BOUNDARY}" --output=/tmp/x) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "boundary: option-shaped base is a usage error" "${rc}" 64 "usage"

# a path containing shell syntax is data
gitq -C "${B}" checkout -q -f -B "case" base
INJB="${T}/pwned_boundary"
mkdir -p "${B}/priv/repo/migrations"
: >"${B}/priv/repo/migrations/\$(touch ${INJB##*/})"
rc=0; (cd "${B}" && bash "${BOUNDARY}" base) >"${T}/out" 2>"${T}/err" || rc=$?
if [ ! -e "${INJB}" ] && [ ! -e "${B}/${INJB##*/}" ] && [ "${rc}" = 1 ]; then ok "boundary: path text is data, never executed"; else bad "boundary injection (rc ${rc})"; fi

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
