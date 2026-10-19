# Phase 135: Repository and Code-Craft Consolidation - Pattern Map

**Mapped:** 2026-10-18
**Files analyzed:** 22 new/modified file groups
**Analogs found:** 21 / 22 (one partial: public-surface snapshot)

All analog paths below were verified git-tracked (`git ls-files`). No gitignored mirror paths are used.
Line numbers refer to the worktree at baseline 4b7b8e33.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|
| `scripts/maintainer/artifact_ledger.json` | config (ledger) | batch/transform | `.planning/INBOX-LEDGER.json` shape + `scripts/maintainer/credo_complexity_baseline.json` | role-match |
| `scripts/maintainer/validate_artifact_ledger.sh` | utility (validator) | transform | `scripts/maintainer/validate_inbox_ledger.sh` | exact |
| `scripts/ci/test_validate_artifact_ledger.sh` | test (fixture harness) | request-response | `scripts/ci/test_validate_inbox_ledger.sh` | exact |
| `scripts/maintainer/validate_readability_trace.sh` (or inside artifact validator) | utility | transform | `validate_inbox_ledger.sh` | exact |
| `scripts/maintainer/craft_boundary_check.sh` | utility | transform (git diff) | `scripts/maintainer/refactor_contract.sh` + `validate_inbox_ledger.sh` arg parsing | role-match |
| `scripts/maintainer/readability_changes.json` | config (trace) | batch | `scripts/maintainer/credo_complexity_baseline.json` | role-match |
| `scripts/maintainer/scan_live_residue.exs` | utility (scanner) | batch/transform | `scripts/maintainer/credo_quality_normalize.exs` (+ `test/planning_path_hygiene_test.exs` regex-from-fragments) | role-match |
| `scripts/maintainer/live_residue_allowlist.json` | config (removal-only baseline) | batch | `scripts/maintainer/credo_complexity_baseline.json` + `credo_quality.sh` `cmp` | role-match |
| `test/install_smoke/live_residue_scan_test.exs` | test | batch | `test/planning_path_hygiene_test.exs` + `test/install_smoke/evidence_census_test.exs` (`run_script/2`) | exact |
| `test/install_smoke/artifact_package_set_test.exs` | test | file-I/O | `test/install_smoke/package_metadata_test.exs` (`build_package!/0`) | exact |
| `test/install_smoke/support/` package helper (extract) | utility | file-I/O | `package_metadata_test.exs:311-340` | exact |
| `test/rindle/public_surface_snapshot_test.exs` + `test/fixtures/public_surface.txt` | test (snapshot) | transform | `test/rindle/api_surface_boundary_test.exs` + `test/install_smoke/credo_policy_test.exs` | partial |
| `scripts/maintainer/repo_hygiene_check.sh` (rework) | utility | request-response | itself (276 lines) | self |
| `scripts/ci/test_repo_hygiene_check.sh` | test (real-git + PATH shim harness) | request-response | `scripts/ci/test_collect_inbox.sh` (shims) + `test_validate_inbox_ledger.sh` (verdict helpers) | role-match |
| `.github/workflows/ci.yml` `ci-script-tests` steps | config (workflow) | event-driven | `ci.yml:1459-1483` | exact |
| `.gitignore` (narrow `.env.*`), `.mcp.json` (delete) | config | n/a | n/a | n/a |
| `brandbook/src/admin-css-build.mjs` (+ regenerate/sync) | utility (generator) | transform | itself; `brandbook-tokens` job `ci.yml:1346-1370` | self |
| `scripts/ci/fixtures/<fingerprint>.json` + repoint `scripts/ci/test_nightly_dialyzer.sh:8` | fixture | file-I/O | `scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh` | role-match |
| Residue tranche edits (lib, workflows, scripts, tests, examples) | mixed (comment/test rename) | n/a | edit-in-place; policy tests listed under Pitfalls | n/a |
| `scripts/maintainer/credo_complexity_baseline.json` (shrink 5 entries) + 5 lib pilot modules | config + service | n/a | itself; `credo_quality.sh` cmp | self |
| `RUNNING.md` / `CONTRIBUTING.md` pointers | docs | n/a | existing sections | n/a |

## Pattern Assignments

### `scripts/maintainer/validate_artifact_ledger.sh` (validator, transform)

**Analog:** `scripts/maintainer/validate_inbox_ledger.sh` (357 lines)

**Header/contract comment + flags** (lines 1-52). Copy the structure: purpose, modes, exit codes `0 valid | 1 rejected (REJECT: on stderr) | 64 usage`, safety note, bash 3.2/jq 1.6 note.
```bash
set -euo pipefail
LEDGER=""; OFFLINE=false
usage() { cat >&2 <<'USAGE' ... USAGE; exit 64; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ledger) [ "$#" -ge 2 ] || usage; LEDGER="$2"; shift 2 ;;
    --offline) OFFLINE=true; shift ;;
    -h|--help) usage ;;
    *) echo "validate_inbox_ledger: unknown argument: $1" >&2; usage ;;
  esac
done
```

**Unreadable ledger guard** (lines 62-65):
```bash
if [ ! -f "${LEDGER}" ] || ! jq -e . "${LEDGER}" >/dev/null 2>&1; then
  echo "REJECT: unreadable: ledger ${LEDGER} is missing or not valid JSON" >&2
  exit 1
fi
```

**jq rule program with `R()` reject helper and helper predicates** (lines 103-118):
```bash
read -r -d '' PROG <<'JQ' || true
def R($k; $m): "REJECT: \($k): \($m)";
def nestr: type == "string" and (test("^\\s*$") | not);
def objs: if type == "array" then map(select(type == "object")) else [] end;
def arr: if type == "array" then . else [] end;
def obj: if type == "object" then . else {} end;
```
Per-entry error list: `def itemerrs: ... [ (if COND then empty else R("item"; "\($lb): ...") end), ... ]` (lines 144-174). Closed-vocabulary enum check uses `IN(...)` (e.g. line 149). Map to: `package IN("shipped","excluded")`, `disposition IN("retain","delete","ignore")`, `authority` non-empty, `regenerate` present iff `authority == "generated"`.

**Evaluation + all-problems-in-one-run output** (lines 337-357). Rules emit a stream; script collects and prints every reason, never just the first:
```bash
if ! OUT=$(jq -n -r --slurpfile l "${LEDGER}" ... "${PROG}" 2>&1); then
  echo "REJECT: internal: validator could not evaluate the ledger: ${OUT}" >&2; exit 1
fi
if [ -n "${OUT}" ]; then printf '%s\n' "${OUT}" >&2; exit 1; fi
echo "validate_inbox_ledger: ok (${MODE})"; exit 0
```
**Difference to handle:** the artifact validator also needs git. Compute `git ls-files -- <pathspec>` per class in bash, pass the resulting multiset (`--argjson`/`--slurpfile`) into jq. Never build jq or shell from ledger strings (security rule: values reach jq only via `--arg/--slurpfile/--argjson`). Pathspec strings are passed as separate argv to `git ls-files --`, never `eval`. Prototype `:(glob)` + `:(exclude)` first (research assumption A1).

---

### `scripts/ci/test_validate_artifact_ledger.sh` (fixture harness)

**Analog:** `scripts/ci/test_validate_inbox_ledger.sh` (258 lines)

**Harness skeleton** (lines 7-20, 111-120):
```bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="${ROOT}/scripts/maintainer/validate_inbox_ledger.sh"
T="$(mktemp -d)"
trap 'chmod -R u+w "${T}" 2>/dev/null; rm -rf "${T}"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

verdict() {
  local name="$1" rc="$2" want="$3" pat="$4"
  if [ "${rc}" != "${want}" ]; then bad "${name} (exit ${rc}, want ${want}): $(tr '\n' '|' <"${T}/err")"
  elif [ -n "${pat}" ] && ! grep -qF -- "${pat}" "${T}/err"; then bad "${name} (missing reason text: ${pat}): ..."
  else ok "${name}"; fi
}
```
**Mutation style** (lines 102-109, 125-139): a clean base fixture plus a one-line jq filter per rejection, e.g.
```bash
offline "NAME" 'del(.items[] | select(.number == 105))' 1 "REJECT: missing: pr 105"
```
Run `jq -S "${filter}" base > l.json`, invoke the validator, `verdict`. Include the "all problems reported in one run" case (lines 131-139), CLI exit-64 cases (lines 226-233), malformed/missing ledger (234-238), and the injection test (lines 250-254: ledger text containing `$(touch FILE)` must not execute).
**Difference:** this harness needs a real temp git repo as the fixture tree (`git init` in `$T`, add files, commit) so `git ls-files` partitions can be exercised: uncovered file, double-classified file, stale ignore rule, tracked-ignored file, shipped class absent from `mix.exs files:`.
**Footer** (lines 256-258): `echo "${PASS} passed, ${FAIL} failed"; [ "${FAIL}" -eq 0 ]`.

---

### `scripts/ci/test_repo_hygiene_check.sh` (real-git + PATH-shim harness)

**Analog:** `scripts/ci/test_collect_inbox.sh` (636 lines) for shims; `test_validate_inbox_ledger.sh` for `ok/bad` accounting.

**Temp root, trap, record/assert** (lines 8-39):
```bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/test_collect_inbox.XXXXXX")"
trap 'rm -rf "${ROOT_TMP}"' EXIT
record() { ... echo "ok   - ${name}" / echo "FAIL - ${name}: ${detail}" >&2 ... }
assert() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then record "${name}" true; else record "${name}" false "assertion command failed: $*"; fi; }
```
**Fake binary on PATH** (lines 41-79): `BIN="${ROOT_TMP}/bin"`, `cat >"${BIN}/gh" <<'FAKE_GH' ... FAKE_GH`, behavior steered by env (`FAKE_DIR`, `FAKE_GH_FAIL`), log invocations to `${FAKE_DIR}/gh.log`, record unexpected calls to `unexpected`. Reuse for fake `mix` (cases: exits non-zero; exits 0 without sentinel; exits 0 with sentinels `[credo-quality] blocking warnings, public contract, and complexity inventory passed`, `synced rindle-admin.css`, `N tests, 0 failures`), `node`, and `gh`.
**Difference (new, no analog):** real `git init --bare` origin + clone in the temp root; script run with `RINDLE_HYGIENE_ROOT` pointing at the clone, `RINDLE_HYGIENE_REMOTE` pointing at the bare repo. Fetch failure is forced by pointing the remote at a nonexistent path. Cases required by D-135-11: fetch failure, wrong branch, detached HEAD, behind, ahead, tracked junk, generated drift, `mix ci` non-zero, `mix ci` exit 0 with missing sentinel, post-verification untracked and non-allowlisted ignored path, hex-baseline race WARN in `--ci` vs BLOCK in release-prep.

---

### `scripts/maintainer/repo_hygiene_check.sh` (rework in place)

**Analog:** itself. Keep these pieces verbatim:

**Reporting contract** (lines 48-65, 262-276): `record_result LEVEL label detail`, `RESULTS` array, `PASS/WARN/BLOCK` counters; output `Rindle repo hygiene report (%s)`, `Summary: ...`, `Result: not ready` exit 1 / `proceed with caution` exit 0 / `safe to start release prep`.

**Defects to replace (exact lines):**
- line 204-205: `branch="$(git rev-parse --abbrev-ref HEAD)"; record_result "PASS" "current branch" "$branch"` (detached HEAD reads as `HEAD` PASS). Use `git symbolic-ref --quiet --short HEAD`.
- line 214: `git fetch "$REMOTE" --prune >/dev/null 2>&1 || true` (swallows failure). Replace per research sketch: BLOCK on failure in local/release-prep.
- line 216-229: compares local `refs/heads/main`, not HEAD, and ahead is only WARN. Compare `HEAD` to `$REMOTE/main`; BLOCK both directions.
- line 247-253: `if mix test >/dev/null` under `RUN_MIX_CI`. Replace with `mix ci` + `pipefail` tee + sentinels (research "Hygiene: incomplete mix ci" sketch).
- line 258: `if [[ "$MODE" != "ci" ]]; then local_checks`. `--ci` still skips fetch/branch/mix ci but must now run tracked-junk and artifact-ledger checks (pure git).
- lines 172-187 hex-baseline: the `version_gt "$mix_ver" "$baseline_ver"` branch at 178-182 BLOCKs when Hex already lists mix.exs version. Make this WARN when `MODE == ci`, BLOCK in release-prep (D-135-11).
- lines 45-46: `REPO_ROOT="$(git rev-parse --show-toplevel ...)"; cd` -> honor `RINDLE_HYGIENE_ROOT` first.

**Keep unchanged:** `release_train_has_required_lines` (109-114) phrase list, `repo_owned_checks` PASS/BLOCK labels used by RELEASE-TRAIN.md and AGENTS.md. Function-ize into `check_fetch`, `check_branch`, `check_tracked_junk`, `check_generated_drift`, `check_mix_ci`, `check_residue`.

---

### `scripts/maintainer/scan_live_residue.exs` + `test/install_smoke/live_residue_scan_test.exs`

**Scanner analog (script style):** `scripts/maintainer/credo_quality_normalize.exs` (Jason via `mix run --no-compile --no-start`, `run/1` entry, pure functions, `raise ArgumentError`). Keep scanner self-contained with an explicit `--list | --check | --regen-baseline` arg dispatch.

**ExUnit wrapper analog:** `test/planning_path_hygiene_test.exs`

Anti-vacuous guard and file walk (lines 36-48, 50-70):
```elixir
use ExUnit.Case, async: true
@test_root Path.expand("..", __DIR__)
setup_all do
  files = Path.wildcard(@glob)
  assert files != [], "expected test/**/*.exs glob to match files, got none"
  {:ok, files: files}
end
...
|> Enum.map(fn {line, n} -> "#{relpath}:#{n}: #{String.trim(line)}" end)
assert offenders == [], failure_message(offenders)
```
**Self-flag avoidance** (lines 24-34): build the offending regex from fragments so the file does not match itself:
```elixir
@planning_dir_token "." <> "planning"
@planning_read_regex Regex.compile!("(File\\.(read!|exists\\?)|Path\\.expand)[^)]*" <> Regex.escape(@planning_dir_token))
```
Apply to every scanner class pattern (and to the intentional mojibake regression literal in `test/install_smoke/docs_parity/onboarding_and_capabilities_test.exs:201-202`: rewrite with `\x{00C3}\x{00A2}...` escapes). Include a "distinguishes live vs fixture" positive/negative test as in lines 72-80 (one planted violation per class).

**Invoking the scanner script from ExUnit:** `test/install_smoke/evidence_census_test.exs:783-793`
```elixir
defp run_script(script, args) do
  System.cmd("mix", ["run", "--no-compile", "--no-start", script | args],
    cd: @repo_root,
    env: [{"MIX_ENV", Atom.to_string(Mix.env())},
          {"MIX_BUILD_PATH", Mix.Project.build_path()},
          {"MIX_DEPS_PATH", Mix.Project.deps_path()}],
    stderr_to_stdout: true)
end
```
Header idiom for tests that mutate temp fixture trees (line 3-5): `@moduletag async_safety_allow: [:file_mutation]` with a comment justifying per-test unique roots. Static scans that only read need no tag.

**Constraint:** test files must not read any live `.planning` path (LOCK-05, `test/planning_path_hygiene_test.exs`); scanner, allowlist and test live under `scripts/maintainer/` and `test/`. Scanner must exclude exactly itself, its allowlist and its test (assert the exclusion list has exactly three paths).

---

### `scripts/maintainer/live_residue_allowlist.json` (removal-only baseline)

**Analog:** `scripts/maintainer/credo_complexity_baseline.json` entries (keyed by identity, never line numbers; each with `owner` and `removal_trigger`) and the stale-entry rule in `scripts/maintainer/credo_quality.sh:40-43`:
```bash
cmp -s "$expected_json" "$actual_json" || {
  diff -u "$expected_json" "$actual_json" >&2 || true
  fail "complexity/nesting identity multiset differs from the reviewed baseline"
}
```
Baseline entry shape to mirror:
```json
{"check":"...","file":"lib/...","trigger":"...","observed_metric":10,"count":1,"owner":"...","removal_trigger":"..."}
```
Scanner entry: `{"path","class","text" (normalized line),"reason_class" in pending-removal|policy|contract|immutable-receipt|fixture,"count","reason"}`. Shrink-only: any entry matching no hit is an error (research "stale-allowlist rule" sketch). Final plan asserts zero `pending-removal`.
**Shape tests to copy:** `test/install_smoke/credo_policy_test.exs:64-92` (schema key set sorted equality, non-empty strings, identities unique, deliberate-drift cases `assert_fails_with_baseline`) and the "add, delete, change, count-drift" mutation matrix (lines 94-102).

---

### `scripts/maintainer/readability_changes.json` + trace validator (CRAFT-05)

**Analogs:** `credo_complexity_baseline.json` (identity fields `check,file,trigger,observed_metric`) and `validate_inbox_ledger.sh` (offline shape mode, no clock, no `.planning` read).
Trace validator: embed `candidate_ledger.sha256` (`a56c8b6e68e68a84c1355247359733e60be9596a6582a4525488b5d23880bde4`, subject `3858267b...`) and the 12 candidate ids; every change's `candidate_id` IN the embedded list; `anchor` identity must be ABSENT from the post-change `credo_complexity_baseline.json` (and, with `--base REF`, present in `git show REF:scripts/maintainer/credo_complexity_baseline.json`). `--verify-source` (maintainer-only, never CI) compares sha256 to the phase file via `shasum -a 256`.
Normalizer to reuse for identity comparison: `scripts/maintainer/credo_quality_normalize.exs` identity keys (`@identity_keys ["check","file","trigger","observed_metric"]`).

---

### `scripts/maintainer/craft_boundary_check.sh`

**Analog (script frame):** `scripts/maintainer/refactor_contract.sh` lines 1-6:
```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"
```
Arg parsing and REJECT output: copy from `validate_inbox_ledger.sh` (exit 64 usage, `REJECT:` lines). Core: `git diff --name-only "$base"...HEAD` filtered against forbidden pathspecs (`priv/repo/migrations/**`, `mix.lock`, `.release-please-manifest.json`, `release-please-config.json`, `.github/workflows/release*.yml`, `CHANGELOG.md`, telemetry contract test) plus a `mix.exs` diff restricted to `version`/`deps`/`package`. Tested by a fixture harness using a temp git repo (same recipe as the hygiene harness); wire as an extra `ci-script-tests` step.

---

### `test/install_smoke/artifact_package_set_test.exs` (+ extracted `build_package!`)

**Analog:** `test/install_smoke/package_metadata_test.exs`

**Async-safety header + env override** (lines 1-13, 311-340):
```elixir
use ExUnit.Case, async: true
@async_safety_allow [:file_mutation]
def __async_safety_allow__, do: @async_safety_allow
@repo_root Path.expand("../..", __DIR__)
...
defp build_package! do
  case System.get_env("RINDLE_INSTALL_SMOKE_PACKAGE_ROOT") do
    package_root when is_binary(package_root) and package_root != "" -> {package_root, nil}
    _ ->
      output_root = Path.join(System.tmp_dir!(), "rindle-package-metadata-#{System.unique_integer([:positive])}")
      package_root = Path.join(output_root, "rindle-#{Mix.Project.config()[:version]}")
      File.mkdir_p!(output_root)
      {output, 0} = System.cmd("mix", ["hex.build", "--unpack", "--output", package_root],
        cd: @repo_root, env: [{"MIX_ENV", "dev"}], stderr_to_stdout: true)
      assert output =~ "Building rindle"
      {package_root, output_root}
  end
end
```
`setup_all` with `on_exit(fn -> File.rm_rf(cleanup_root) end)` (lines 39-47). The new test extracts this into `test/install_smoke/support/` and keeps `package_metadata_test.exs` behavior identical. New assertion: ledger classes with `package: shipped` expanded by `git ls-files` (restricted to `mix.exs` `files:` prefixes: `lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides`) plus `hex_metadata.config` must equal the unpacked file set (183 files today). Existing `@prohibited_paths ["_build", ".planning", "test", ".github", "coveralls.json"]` (line 37) stays. Ledger `regenerate.commands` parity against the `brandbook-tokens` job steps: parse `ci.yml` with `YamlElixir.read_from_file!` (same as `quality_signal_policy_test.exs:4-9`). Reading `ci.yml` is allowed (not `.planning`).

---

### `.github/workflows/ci.yml` new steps (CRAFT-03/HYGIENE-03/CRAFT-05)

**Analog:** `ci-script-tests` job, `ci.yml:1459-1483`. Append steps at the END of the job (Pitfall 6; serialize merges):
```yaml
      - name: Inbox ledger validator harness
        run: bash scripts/ci/test_validate_inbox_ledger.sh
      - name: Dependency landing evidence harness
        run: bash scripts/ci/test_dep_landing_evidence.sh
      - name: Inbox ledger shape (offline)
        run: bash scripts/maintainer/validate_inbox_ledger.sh --offline --ledger .planning/INBOX-LEDGER.json
```
New steps follow the same `- name:` / `run: bash scripts/...` form: `Artifact ledger validator harness`, `Artifact ledger shape (offline)`, `Repo hygiene harness`, `Craft boundary harness`, `Readability trace shape`. The job has no toolchain (pure bash + jq; checkout step only), so no step may call `mix`. The job is gated through `ci-summary` `needs:` (line 1509); do not rename `ci.yml`, workflow `CI`, or `CI Summary`. Workflow literals are asserted by `test/install_smoke/ci_lane_split_test.exs`, `ci_observability_test.exs`, `ci_cache_hygiene_test.exs`, `quality_signal_policy_test.exs`: grep `test/install_smoke/` for any changed literal and edit both in the same PR (Pitfall 1; memory `reference_obs02_metatest_content_drift`).

---

### `brandbook/src/admin-css-build.mjs` (generator fix, D-135-10)

**Analog:** itself plus `brandbook-tokens` job (`ci.yml:1346-1370`): the regeneration chain and drift gate to mirror exactly:
```yaml
- run: node brandbook/src/tokens-build.mjs
- run: node brandbook/src/admin-css-build.mjs
- run: node brandbook/src/admin-contrast.mjs
- run: node brandbook/src/admin-gallery-check.mjs
- run: node brandbook/src/sync-admin-css.mjs
- run: git diff --exit-code
```
Local equivalent is in `mix.exs` `ci` alias (lines 310-321): `"cmd node brandbook/src/tokens-build.mjs"`, `admin-css-build.mjs`, `admin-contrast.mjs`, `sync-admin-css.mjs`. Edit only the generator, run `admin-css-build.mjs` then `sync-admin-css.mjs`, commit all three outputs (`brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`). Equality of the copy is asserted by `test/brandbook/admin_design_system_validation_test.exs`. Hex-shipped bytes change (comment-only): ensure `chore:`/`ci:`/`refactor:` prefix.

---

### `test_nightly_dialyzer.sh` fingerprint repoint (D-135-03)

**Analog:** `scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh` (existing fixtures directory, tracked). Current coupling, `scripts/ci/test_nightly_dialyzer.sh:5-8`:
```bash
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runner="${repo_root}/scripts/ci/run_nightly_dialyzer.sh"
fingerprint="${repo_root}/.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-FAILURE-FINGERPRINT.json"
```
Copy the JSON byte-for-byte to `scripts/ci/fixtures/` and repoint line 8 to `"${repo_root}/scripts/ci/fixtures/<name>.json"`. Do NOT touch `verify_nightly_run.sh:260/290` or `test_verify_nightly_run.sh` (receipt-baked census path; allowlist as `immutable-receipt`, ledger entry `retain`, authority "immutable receipt").

---

### CRAFT-05 pilot (5 baseline entries, `refactor:` PRs)

**Analog:** `scripts/maintainer/credo_quality.sh` + `credo_complexity_baseline.json` + `test/install_smoke/credo_policy_test.exs`.
Proof loop per PR (copy from research and the scripts): edit one module, delete exactly its removed identities from the baseline JSON (never raise a metric), then `bash scripts/maintainer/credo_quality.sh` (the `cmp` at lines 40-43 verifies mechanically), `bash scripts/maintainer/refactor_contract.sh` (SAFE-01: compile `--force`, `xref graph --label compile-connected --fail-above 0`, then `mix test --include contract --seed 0` on 8 files, lines 8-19), `MIX_ENV=dev mix doctor --full --raise`, focused tests.
Note `credo_policy_test.exs:67-68` hard-codes `assert length(entries) == 27` and `Enum.sum(counts) == 31` and line 82 `Enum.count(entries, &(&1["count"] == 2)) == 4`: **shrinking the baseline requires updating these literals in the same PR** (they will go red otherwise).
Pilot modules and tests: `lib/rindle/ops/sweep_orphaned_temp_files.ex` / `test/rindle/ops/sweep_orphaned_temp_files_test.exs`; `lib/rindle/ops/lifecycle_repair.ex` / `lifecycle_repair_test.exs`; `lib/rindle/ops/runtime_checks/core_checks.ex` and `lib/rindle/ops/runtime_checks.ex` / `runtime_checks_test.exs` (+ `_gcs_`, `_streaming_`); `lib/rindle/upload/tus_protocol.ex` / `test/rindle/upload/tus_plug_test.exs`. Avoid `Migration preflight` entries, any "Developer-approved" trigger, `upload_maintenance`.

---

### `test/rindle/public_surface_snapshot_test.exs` (partial analog)

**Closest:** `test/rindle/api_surface_boundary_test.exs` (visibility + selected exports; not read in full here, 425 lines) and `credo_policy_test.exs` (deterministic fixture-comparison with regenerate instructions). No existing full-export snapshot. Use `Code.fetch_docs/1` over `:rindle` modules; fall back to `__info__(:functions)` on `@public_modules` if OTP26/27 docs chunks differ (assumption A3). Fixture at `test/fixtures/public_surface.txt`. Reading `priv/repo/migrations` sha256 is allowed (not `.planning`).

---

## Shared Patterns

### No `.planning/` reads from new live code (D-135-02)
**Source:** `test/planning_path_hygiene_test.exs` (LOCK-05). **Apply to:** every new `.exs`/test and the scanner, allowlist, ledgers. Bash validators in `ci-script-tests` may read `.planning` (precedent `ci.yml:1483`) but the new ledgers do not need to. Any path under `.planning/phases/135-*` read at runtime is a defect.

### REJECT-style validators
**Source:** `scripts/maintainer/validate_inbox_ledger.sh:103-118,337-357`. **Apply to:** artifact ledger, readability trace, boundary check. Format `REJECT: <rule>: <detail>` on stderr, exit 1; usage exit 64; all violations in one run.

### Fixture harness accounting
**Source:** `scripts/ci/test_validate_inbox_ledger.sh:14-20,111-120,256-258`. **Apply to:** every new `scripts/ci/test_*.sh`. `ok`/`bad`, `verdict NAME RC WANT PATTERN`, final `N passed, M failed`, exit non-zero on any failure. Needs only bash + jq + coreutils + git.

### Removal-only baselines (shrink, never grow)
**Source:** `credo_quality.sh:40-43`, `credo_policy_test.exs:64-102`. **Apply to:** residue allowlist, readability trace, artifact ledger ignore-rule list.

### Self-excluding static scans
**Source:** `test/planning_path_hygiene_test.exs:24-34,52-70`. **Apply to:** `live_residue_scan_test.exs` and scanner patterns. Build patterns from fragments; keep anti-vacuous `assert files != []` (scanner: file count > 500).

### Injection safety
**Source:** `validate_inbox_ledger.sh:18-21` and `test_validate_inbox_ledger.sh:250-254`. **Apply to:** all ledger/allowlist consumers, including hygiene `regenerate.commands` (only exact allowlisted strings run, never `eval`).

### Commit prefix and merge discipline
`ci:`, `test:`, `refactor:`, `chore:`, `docs(135):` only (never `fix:`/`feat:`). Squash merge, PR branch tree-identical to main. Serialize `ci.yml` PRs. After each tranche touching `examples/`, scripts or workflows, confirm the post-merge main-push run (main-only lanes) before the next tranche.

## Pitfalls tied to specific files (from reading analogs)

- `credo_policy_test.exs:67-68,82` hard-codes baseline cardinalities (27 entries, count sum 31, four with count 2). Each pilot PR must update them.
- `package_metadata_test.exs` constants (`@required_paths`, `@prohibited_paths`) and the `@async_safety_allow` idiom must survive the `build_package!` extraction; the async-safety guard reads the attribute from the source AST, so the extracted helper must keep the allow-list justification wherever `File.rm_rf` remains.
- `repo_hygiene_check.sh` phrases checked at line 110-113 must keep matching `.planning/RELEASE-TRAIN.md`.
- `test/install_smoke/docs_parity/onboarding_and_capabilities_test.exs:201-202` intentionally contains mojibake; `operations_test.exs:216,221` contains real mojibake to fix.
- `mix.exs:301-306` duplicated clause and `296-297` broken wrap are CRAFT-06 targets; `mix.exs` edits must not touch `version`, `deps`, `package` (boundary check).

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| Real-git bare-origin fixture setup in `test_repo_hygiene_check.sh` | test harness | request-response | `test_collect_inbox.sh` fakes `gh` only; no existing harness creates real git origins/clones. Planner uses RESEARCH "Pattern 3" and the Code Examples sketches |
| Full public export snapshot | test | transform | Only partial visibility checks exist (`api_surface_boundary_test.exs`); prototype first |
| Pathspec-partition ledger check (`git ls-files` with `:(glob)`/`:(exclude)`) | validator | transform | No existing validator partitions the git tree; prototype in 135-01 task 1 |

## Metadata

**Analog search scope:** `scripts/maintainer/`, `scripts/ci/`, `test/install_smoke/`, `test/` root, `.github/workflows/ci.yml`, `mix.exs`, `brandbook/src/`
**Files read:** 13 (plus 135-CONTEXT.md and 135-RESEARCH.md in full)
**Pattern extraction date:** 2026-10-18
