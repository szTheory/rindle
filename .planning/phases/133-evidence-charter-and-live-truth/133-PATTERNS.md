# Phase 133: Evidence Charter and Live Truth - Pattern Map

**Mapped:** 2026-09-09
**Files analyzed:** 26 new or modified files
**Primary tracked analogs:** 5

## File Classification

The filenames below follow the recommended ownership split in `133-RESEARCH.md`. The context leaves
the exact helper names discretionary, but these boundaries are the most direct fit with existing code.

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/maintainer/evidence_census.exs` | utility/collector | batch, transform, file-I/O | `scripts/maintainer/credo_quality_normalize.exs` | exact role/flow |
| `scripts/maintainer/validate_evidence_census.exs` | utility/validator | batch, transform, file-I/O | `scripts/maintainer/credo_quality_normalize.exs` | exact role/flow |
| `scripts/maintainer/validate_live_truth.exs` | utility/validator | batch, transform, file-I/O | `test/install_smoke/release_docs_parity_test.exs` | flow-match |
| `scripts/ci/eval_nightly_summary.sh` | CI policy utility | request-response, transform | `scripts/ci/eval_ci_summary.sh` | exact role/flow; stricter policy |
| `scripts/ci/test_nightly_summary_gate.sh` | shell test | request-response | `scripts/ci/test_ci_summary_gate.sh` | exact role/flow |
| `scripts/ci/run_nightly_dialyzer.sh` | CI runner | batch, file-I/O | `scripts/ci/test_ci_summary_gate.sh` | role-match; use command seam |
| `scripts/ci/test_nightly_dialyzer.sh` | shell test | batch, file-I/O | `scripts/ci/test_ci_summary_gate.sh` | role-match |
| `scripts/ci/eval_nightly_incident.sh` | CI policy utility | event-driven, transform | `scripts/ci/eval_ci_summary.sh` | role-match |
| `scripts/ci/manage_nightly_incident.sh` | GitHub Issues adapter | event-driven, request-response | current incident block in `.github/workflows/nightly.yml` | in-place flow extracted behind tested boundary |
| `scripts/ci/test_nightly_incident.sh` | shell test | event-driven, request-response | `scripts/ci/test_ci_summary_gate.sh` | role-match |
| `test/install_smoke/evidence_census_test.exs` | contract test | batch, file-I/O | `test/install_smoke/release_docs_parity_test.exs` | role/flow match |
| `test/install_smoke/nightly_policy_test.exs` | structural workflow test | request-response, transform | `test/install_smoke/quality_signal_policy_test.exs` | exact role/flow |
| `test/install_smoke/live_truth_parity_test.exs` | parity test | batch, transform, file-I/O | `test/install_smoke/release_docs_parity_test.exs` | exact role/flow |
| `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json` | config/evidence ledger | batch, file-I/O | `scripts/maintainer/credo_complexity_baseline.json` via its normalizer | role-match |
| `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-FAILURE-FINGERPRINT.json` | immutable diagnostic receipt | batch, file-I/O | prior phase evidence receipts plus canonical JSON normalization | role/flow match |
| `.github/actions/setup-elixir/action.yml` | config/composite action | request-response | existing resolved deps/build outputs in the same file | in-place exact pattern |
| `.github/workflows/nightly.yml` | CI config | event-driven, batch | existing `ci-summary` topology in `.github/workflows/ci.yml` plus its current jobs | in-place/topology match |
| `.github/workflows/ci.yml` | CI config | event-driven, batch | existing `ci-script-tests` job in the same file | in-place exact pattern |
| `scripts/maintainer/check_adoption_proof_matrix.sh` | validator | batch, file-I/O | `scripts/maintainer/validate_live_truth.exs` (new owner), with `release_docs_parity_test.exs` as precedent | migration to derived authority |
| `examples/adoption_demo/docs/adoption-proof-matrix.md` | documentation | batch/read model | `RUNNING.md` lane table | content authority match |
| `RUNNING.md` | documentation | batch/read model | parsed `.github/workflows/ci.yml` and `.github/workflows/nightly.yml` | authority consumer |
| `.planning/INBOX-TRIAGE.md` | planning document | batch/read model | version authority consumed by `release_docs_parity_test.exs` | content match |
| `.planning/JTBD-MAP.md` | planning document | batch/read model | version authority consumed by `release_docs_parity_test.exs` | content match |
| `scripts/ci/verify_nightly_run.sh` | CI evidence collector | event-driven, request-response, file-I/O | `scripts/ci/manage_nightly_incident.sh` plus `scripts/ci/eval_nightly_summary.sh` | role/flow match; read-only remote adapter |
| `scripts/ci/test_verify_nightly_run.sh` | shell test | event-driven, request-response | `scripts/ci/test_nightly_incident.sh` | exact fake-`gh`/argv flow match |
| `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json` | immutable evidence receipt | batch, file-I/O | `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-FAILURE-FINGERPRINT.json` | exact receipt role; richer exact-run schema |

## Primary Analog Set

All five analogs below are Git-tracked (`git ls-files -- <path>` returned each path). No ignored
capability/plugin mirror is used.

1. `scripts/maintainer/credo_quality_normalize.exs`
2. `scripts/ci/eval_ci_summary.sh`
3. `scripts/ci/test_ci_summary_gate.sh`
4. `test/install_smoke/quality_signal_policy_test.exs`
5. `test/install_smoke/release_docs_parity_test.exs`

Existing modified targets (`.github/actions/setup-elixir/action.yml`, `.github/workflows/nightly.yml`,
and `.github/workflows/ci.yml`) are also quoted below where their current contract must be preserved.

## Pattern Assignments

### Census collector, validator, tests, and frozen ledger

**Apply to:**

- `scripts/maintainer/evidence_census.exs`
- `scripts/maintainer/validate_evidence_census.exs`
- `test/install_smoke/evidence_census_test.exs`
- `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json`

**Primary analog:** `scripts/maintainer/credo_quality_normalize.exs`

**Entrypoint and JSON I/O pattern** (lines 1-17):

```elixir
defmodule Rindle.CredoQualityNormalize do
  @identity_keys ["check", "file", "trigger", "observed_metric"]

  def run([kind]) do
    input = IO.read(:stdio, :eof) |> Jason.decode!()

    normalized =
      case kind do
        "issues" -> normalize_issues(input)
        "baseline" -> normalize_baseline(input)
        _ -> raise ArgumentError, "expected issues or baseline input"
      end

    IO.write(Jason.encode!(normalized))
  end

  def run(_), do: raise(ArgumentError, "expected one normalization kind")
end
```

Copy the small module plus `System.argv()` entrypoint shape. For Phase 133, expose explicit modes for
collection versus validation and accept the ledger/receipt paths as arguments; do not hard-code the
active phase directory because it will later archive.

**Normalize, deduplicate, and sort pattern** (lines 19-29, 101-110):

```elixir
defp normalize_issues(%{"issues" => issues}) when is_list(issues) do
  issues
  |> Enum.map(&issue_identity/1)
  |> Enum.group_by(&identity/1)
  |> Enum.map(fn {_identity, [issue | duplicates]} ->
    Map.put(issue, "count", length(duplicates) + 1)
  end)
  |> sort_identities()
end

defp ensure_unique!(entries) do
  if length(entries) == length(Enum.uniq_by(entries, &identity/1)) do
    entries
  else
    raise ArgumentError, "baseline identities must be unique"
  end
end

defp sort_identities(entries), do: Enum.sort_by(entries, &identity/1)
defp identity(entry), do: List.to_tuple(Enum.map(@identity_keys, &Map.fetch!(entry, &1)))
```

Preserve the normalize-before-compare discipline, but do not collapse distinct detector observations
into a candidate silently. The new validator must prove an exact observation-to-candidate assignment
and an exact set of the twelve locked taxonomy dimensions.

**Fail-closed validation pattern** (lines 74-91):

```elixir
defp baseline_identity(entry) when is_map(entry) do
  expected_keys = Enum.sort(@identity_keys ++ ["count", "owner", "removal_trigger"])

  if Enum.sort(Map.keys(entry)) != expected_keys or
       not Enum.all?(
         ["check", "file", "trigger", "owner", "removal_trigger"],
         &(is_binary(entry[&1]) and entry[&1] != "")
       ) or
       not is_number(entry["observed_metric"]) or
       not is_integer(entry["count"]) or entry["count"] <= 0 do
    raise ArgumentError,
          "baseline entries require stable identity, count, owner, and removal trigger"
  end

  Map.take(entry, @identity_keys ++ ["count"])
end
```

Use exact-key validation, non-empty rationales/evidence, the literal dispositions `fix`, `retain`, and
`defer`, and an executable/non-empty trigger for every defer. Add invalid fixtures for foreign SHA,
dirty state, missing dimension, duplicate ID/observation, unassigned observation, invalid disposition,
retain without evidence, defer without trigger, and nondeterministic ordering.

**Ledger precedent:** `.planning/milestones/v1.25-phases/127-evidence-charter-quality-census/127-QUALITY-CENSUS.md`
lines 36-59 supplies the reviewed candidate/disposition vocabulary, but it is prose evidence only. The
new JSON ledger must be machine authority and remain separate from the generated exact-head receipt to
avoid a self-referential commit SHA.

---

### Strict Nightly aggregate evaluator and truth table

**Apply to:**

- `scripts/ci/eval_nightly_summary.sh`
- `scripts/ci/test_nightly_summary_gate.sh`

**Evaluator analog:** `scripts/ci/eval_ci_summary.sh`

**Shell contract and defensive setup** (lines 14-33):

```bash
# CONTRACT
#   Input : NEEDS_JSON env var = the GitHub Actions `toJSON(needs)` object
#   Output: a `| Job | Result |` table appended to $GITHUB_STEP_SUMMARY (when set).
#   Exit  : 0 or 1 according to the pure policy.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "[eval-ci-summary] jq is required" >&2
  exit 1
fi

: "${NEEDS_JSON:?NEEDS_JSON must be set to toJSON(needs)}"
summary_file="${GITHUB_STEP_SUMMARY:-/dev/null}"
```

Retain pure environment input, no network, explicit dependency failure, local `/dev/null` summary,
collect-all diagnostics, and exit status as authority. Nightly must additionally receive a declared-job
policy and applicability/execution evidence, compare the exact declared and observed job sets, reject
malformed/empty JSON, and reject unknown states.

**Iteration and collect-all pattern** (lines 35-58):

```bash
failed=0
while IFS=$'\t' read -r job result; do
  echo "| ${job} | ${result} |" >> "${summary_file}"
  case "${result}" in
    success|skipped) ;;
    *)
      echo "Gating job '${job}': ${result}"
      failed=1
      ;;
  esac
done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.result)"' <<<"${NEEDS_JSON}")

if [ "${failed}" -ne 0 ]; then
  exit 1
fi
```

Do **not** copy `success|skipped` unchanged. Nightly permits skip/success-as-no-op only when a declared,
machine-checked applicability rule says the job is inapplicable and execution evidence says `not-run`
with a reason. Applicable/missing/unknown skips, `failure`, `cancelled`, missing/extra jobs, and unknown
results are red.

**Truth-table harness analog:** `scripts/ci/test_ci_summary_gate.sh` lines 18-36:

```bash
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval_script="${here}/eval_ci_summary.sh"

pass=0
fail=0

expect_exit() {
  local name="$1" want="$2" needs="$3" got=0
  NEEDS_JSON="${needs}" GITHUB_STEP_SUMMARY=/dev/null bash "${eval_script}" >/dev/null 2>&1 || got=$?
  if [ "${got}" -eq "${want}" ]; then
    echo "ok   — ${name} (exit ${got})"
    pass=$((pass + 1))
  else
    echo "FAIL — ${name}: expected exit ${want}, got ${got}" >&2
    fail=$((fail + 1))
  fi
}
```

Expand this table to every supported result, applicable skip, allowlisted inapplicable skip, missing
execution marker, missing/extra job, malformed JSON, and empty object. Keep the final aggregate assertion
from lines 85-87 so all cases run before the test script fails.

---

### Dialyzer fresh/restored runner and fixtures

**Apply to:**

- `scripts/ci/run_nightly_dialyzer.sh`
- `scripts/ci/test_nightly_dialyzer.sh`
- `.github/actions/setup-elixir/action.yml`
- Dialyzer portion of `.github/workflows/nightly.yml`

**Runner/test analog:** the environment-driven command seam and exit capture in
`scripts/ci/test_ci_summary_gate.sh` lines 24-35. Keep the runner independently executable and test it
with a fake `mix` earlier on `PATH`; fixtures should assert the exact commands and filesystem effects.

**Resolved toolchain cache identity already used by the composite**
(`.github/actions/setup-elixir/action.yml` lines 40-46, 72-92):

```yaml
outputs:
  deps-cache-hit:
    value: ${{ steps.deps_cache.outputs.cache-hit }}
  build-cache-hit:
    value: ${{ steps.build_cache.outputs.cache-hit }}

# existing resolved-version key pattern
key: ${{ steps.ns.outputs.build_ns }}-v1-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-elixir${{ steps.beam.outputs.elixir-version }}-${{ inputs.mix-env }}-${{ hashFiles('mix.lock') }}
```

Add composite outputs that forward `steps.beam.outputs.otp-version` and
`steps.beam.outputs.elixir-version`, then use those exact patch-level outputs in the PLT key. Preserve
the lock/config hash and never fall back across toolchains.

**Current defective in-place block** (`.github/workflows/nightly.yml` lines 194-222):

```yaml
- name: Restore PLT cache
  id: plt_cache
  with:
    path: priv/plts
    key: plt-v2-${{ runner.os }}-${{ runner.arch }}-otp27-elixir1.17-${{ hashFiles('mix.exs', 'mix.lock', '.dialyzer_ignore.exs') }}

- name: Build PLT
  if: steps.plt_cache.outputs.cache-hit != 'true'
  run: mix dialyzer --plt

- name: Dialyzer
  run: mix dialyzer --format github
```

Replace the literal major-only identity with resolved versions and call the runner in two independent
modes: always-fresh build+analysis and restored analysis. In restored mode, only the proven stale/old
PLT fingerprint may trigger one rebuild; real warnings, build failures, corrupt/unknown failures, and a
failed rebuild must propagate. Do not modify `.dialyzer_ignore.exs`.

---

### Incident lifecycle evaluator, adapter, and fixtures

**Apply to:**

- `scripts/ci/eval_nightly_incident.sh`
- `scripts/ci/test_nightly_incident.sh`
- incident portion of `.github/workflows/nightly.yml`

**Policy analog:** `scripts/ci/eval_ci_summary.sh` lines 23-58 for a pure, fail-closed evaluator.
The evaluator should consume bounded environment/JSON facts and emit exactly one of `open`, `update`,
`close`, or `noop`; an invalid or incomplete input exits nonzero instead of selecting an action.

**Mutation adapter pattern to retain** (`.github/workflows/nightly.yml` lines 453-465, 481-497):

```yaml
permissions:
  issues: write
steps:
  - name: Open or update the nightly-failure tracking issue
    env:
      GH_TOKEN: ${{ github.token }}
      GH_REPO: ${{ github.repository }}
      RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

```bash
existing="$(
  gh issue list --state open --label "$label" --search "$title in:title" \
    --json number --jq '.[0].number // ""'
)"

if [ -n "$existing" ]; then
  gh issue comment "$existing" --body "$body"
else
  gh issue create --title "$title" --label "$label" --body "$body"
fi
```

Keep job-local `issues: write`, the workflow-level `contents: read`, and context passed through quoted
environment values. Change the query to inspect the full exact-label cardinality and fail on duplicates.
The thin adapter applies the pure decision, appends exact run URL/ID/attempt/SHA evidence, comments
before close, and never mutates on `workflow_dispatch`. Closure additionally requires a scheduled green
run on the default branch whose run SHA equals current remote `main`; an API lookup failure cannot close.

Use the `expect_exit`/counter harness from `test_ci_summary_gate.sh` and a fake `gh` executable recording
argv. Cover schedule/dispatch, no/one/multiple open issues, current/stale main SHA, every strict verdict,
API failure, mutation failure, and recovery-comment-before-close ordering.

---

### Parsed Nightly workflow policy test

**Apply to:** `test/install_smoke/nightly_policy_test.exs`

**Analog:** `test/install_smoke/quality_signal_policy_test.exs`

**Imports/setup pattern** (lines 1-10):

```elixir
defmodule Rindle.InstallSmoke.QualitySignalPolicyTest do
  use ExUnit.Case, async: true

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)

  setup_all do
    {:ok, %{workflow: YamlElixir.read_from_file!(@ci_path)}}
  end
end
```

Parse YAML once in `setup_all`; assert maps, job topology, outputs, `needs`, `if`, permissions, and exact
runner commands structurally. Avoid line-oriented string presence as authority.

**Reusable structural helpers** (lines 119-142):

```elixir
defp assert_required_step!(workflow, job_name, step_name, run, condition \\ nil) do
  required_step = step(workflow, job_name, step_name)
  assert required_step["run"] == run
  assert required_step["if"] == condition
  refute required_step["continue-on-error"]
end

defp job(workflow, name), do: workflow |> Map.fetch!("jobs") |> Map.fetch!(name)
defp steps(workflow, job_name), do: job(workflow, job_name) |> Map.fetch!("steps")

defp step(workflow, job_name, name) do
  Enum.find(steps(workflow, job_name), &(Map.get(&1, "name") == name)) ||
    flunk("missing #{job_name} step: #{name}")
end
```

Lock these Phase 133 facts: `schedule` and diagnostic `workflow_dispatch`; exactly the supported
Elixir 1.17/OTP 27 Dialyzer authority; fresh and restored commands; strict summary has all declared jobs
in `needs`, `if: always()`, and controls workflow failure; lifecycle also inspects all results under
scheduled-only mutation; only it has `issues: write`; secret/repository applicability outputs are
consumed by the summary; no `continue-on-error` masks a gating proof.

---

### CI wiring for pure shell tests

**Apply to:** `.github/workflows/ci.yml`

**In-place pattern** (lines 1415-1425):

```yaml
ci-script-tests:
  name: CI Script Tests
  runs-on: ubuntu-22.04
  steps:
    - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
    - name: CI Summary gate logic
      run: bash scripts/ci/test_ci_summary_gate.sh
```

Add the Phase 133 pure shell suites as steps in this existing root job. Do not create another required
context or change workflow name/filename. Preserve `ci-script-tests` in the sole `ci-summary.needs`
join and keep `CI Summary` as the sole required check.

---

### Derived live-truth model, parity tests, and content reconciliation

**Apply to:**

- `scripts/maintainer/validate_live_truth.exs`
- `test/install_smoke/live_truth_parity_test.exs`
- `scripts/maintainer/check_adoption_proof_matrix.sh`
- `examples/adoption_demo/docs/adoption-proof-matrix.md`
- `RUNNING.md`
- `.planning/INBOX-TRIAGE.md`
- `.planning/JTBD-MAP.md`

**Analog:** `test/install_smoke/release_docs_parity_test.exs`

**Authority loading and JSON derivation pattern** (lines 4-28, 31-39):

```elixir
@mix_exs_path Path.expand("../../mix.exs", __DIR__)
@release_manifest_path Path.expand("../../.release-please-manifest.json", __DIR__)
@ci_workflow_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
@running_path Path.expand("../../RUNNING.md", __DIR__)

setup_all do
  {:ok,
   %{
     mix_exs: File.read!(@mix_exs_path),
     release_manifest: File.read!(@release_manifest_path),
     ci_workflow: File.read!(@ci_workflow_path),
     running: File.read!(@running_path)
   }}
end

test "current package and manifest stay aligned", context do
  assert {:ok, %{"." => version}} = Jason.decode(context.release_manifest)
  assert context.mix_exs =~ ~s(@version "#{version}")
end
```

Move derivation into `validate_live_truth.exs`: obtain current version from both release authorities,
parse CI/Nightly topology with `YamlElixir`, and consume package provenance facts. The parity test should
compare active claims to that one model, rather than independently hard-coding the expected prose.

**Historical-boundary precedent** (`release_docs_parity_test.exs` lines 42-73):

```elixir
generated_notes = changelog_section(changelog, "[0.4.0]")

defp changelog_section(changelog, heading) do
  escaped_heading = Regex.escape(heading)
  pattern = ~r/^## #{escaped_heading}.*$([\s\S]*?)(?=^## |\z)/m

  case Regex.run(pattern, changelog) do
    [_, section] -> section
    nil -> flunk("missing changelog section: #{heading}")
  end
end
```

Make exemptions explicit: `.planning/milestones/**` and clearly marked historical receipt sections are
immutable; an old version outside those boundaries fails. Test both a permitted marked-history fixture
and a rejected unmarked fixture.

**Package provenance authority** (`test/install_smoke/generated_app_smoke_test.exs` lines 10-30,
43-46, 231-279; tracked producer, not a sixth pattern analog):

```elixir
assert report.install_mode in [:package, :network]
assert report.install_source

if report.install_mode == :package do
  assert File.dir?(report.package_root)
  assert report.install_source == report.package_root
  refute report.deps_rindle_present?
end

assert report.package_root_provenance.unpacked?
refute report.package_root_provenance.repository_path_fallback?
assert File.dir?(report.package_root_provenance.path)
```

Do not reduce package truth to a substring. `check_adoption_proof_matrix.sh` currently only uses
`grep -Fq` and file existence (lines 13-29); convert it to call the derived validator or keep its string
checks supplementary. A claim is authoritative only when backed by built/unpacked consumer provenance
and no repository/prebuilt fallback.

**Concrete reconciliation targets:**

- `.planning/INBOX-TRIAGE.md:28` says the live anchor is Hex `0.4.5`.
- `.planning/JTBD-MAP.md:3` and `:176` say the live anchor is Hex `0.4.5`.
- `examples/adoption_demo/docs/adoption-proof-matrix.md:5-7`, `:20`, and `:37-38` call the full
  `adoption-demo-e2e` lane merge-blocking.
- `RUNNING.md:72-80` is the maintained correct lane classification: lean
  `adoption-demo-e2e-smoke` is merge-blocking; full `adoption-demo-e2e` is push-main/off-critical-path;
  Nightly provider work may be explicitly not-run when secrets are absent and must not be called passed
  live proof.

Current version must derive as `0.4.6` from both `mix.exs` and `.release-please-manifest.json`. Preserve
valid older-version history instead of globally replacing version strings.

## Live Nightly Collector, Fake-GitHub Contract, and Exact-Run Receipt

**Apply to:**

- `scripts/ci/verify_nightly_run.sh`
- `scripts/ci/test_verify_nightly_run.sh`
- `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json`

Use `scripts/ci/test_nightly_incident.sh` as the fake-`gh`, argv-capture, bounded-input, all-cases-before-failure analog and `scripts/ci/eval_nightly_summary.sh` as the canonical fail-closed JSON/result analog. Split the collector into `preflight`, `dispatch-and-record`, and `verify-receipt`: the first proves exact repository/workflow/ref/SHA identity, the second performs one authorized diagnostic dispatch and read-only run/issue observation, and the third revalidates the canonical receipt without causing another run. Reuse the shared least-privilege rules: no issue mutation, rerun, cancellation, deletion, force-push, secret/raw-log capture, or unbounded polling; exact first attempt, complete job/mode set, supported toolchain, strict green verdict, and byte-identical incident snapshots are mandatory. The receipt follows the research-resolved canonical serialization contract and records the tested subject SHA rather than the later receipt commit.

## Shared Patterns

### Fail-closed machine verdicts

**Source:** `scripts/ci/eval_ci_summary.sh:23-58` and
`scripts/maintainer/credo_quality_normalize.exs:74-110`

Apply to every new validator/evaluator. Missing tools, environment, keys, declared jobs, taxonomy
members, unknown states, duplicate identities, malformed JSON, or external lookup failures must return
nonzero. Human-readable summaries are downstream rendering, never the verdict authority.

### Deterministic evidence

**Source:** `scripts/maintainer/credo_quality_normalize.exs:19-27,101-110`

Normalize repository-relative identities, explicitly deduplicate, sort canonically, and serialize
deterministically. Do not include absolute temp paths, timestamps in stable identity, line numbers, or
raw prose. Record exact Git SHA, dirty state, resolved toolchain versions, and detector/config hashes in
the generated receipt.

### Structural workflow assertions

**Source:** `test/install_smoke/quality_signal_policy_test.exs:8-10,86-98,119-142`

Use `YamlElixir.read_from_file!/1`, map access, and exact job/step assertions. Assert `needs`, `if`,
outputs, permissions, masking, and commands structurally; reserve substring checks for supplementary
human-copy expectations.

### Least privilege and safe workflow inputs

**Source:** `.github/workflows/nightly.yml:27-29,453-465`

Keep default `contents: read`; grant only the lifecycle job `issues: write`. Pass GitHub context through
environment variables, quote all shell expansions, validate bounded state/SHA/URL values, and never
interpolate untrusted context directly into shell source.

### Test organization

**Source:** `scripts/ci/test_ci_summary_gate.sh:21-36,85-87` and
`test/install_smoke/quality_signal_policy_test.exs:8-10`

Shell tests collect all cases and fail once at the end. ExUnit structural/parity tests use `async: true`
when they only read immutable files, load shared fixtures once in `setup_all`, and produce a specific
failure message for a missing job/step/section.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| None | — | — | Every proposed file has a strong role/flow analog or an existing in-place contract. Incident recovery and stale-only PLT rebuilding are new semantics, but their helper shapes are covered by the pure Bash evaluator/test pattern. |

## Metadata

**Analog search scope:** `scripts/ci/`, `scripts/maintainer/`, `test/install_smoke/`,
`.github/actions/`, `.github/workflows/`, active `.planning/`, `RUNNING.md`, and
`examples/adoption_demo/docs/`

**Tracked-source gate:** Passed for every named analog and in-place source.

**Primary analogs read:** 5

**Additional in-place/source-of-truth files inspected:** 9

**Pattern extraction date:** 2026-09-09

**Important boundary:** Do not change `.dialyzer_ignore.exs`, PR skip-as-pass behavior, `ci.yml`,
workflow name `CI`, sole check name `CI Summary`, exact-SHA release coupling, fork safety, public
contracts, or the accepted PR timing envelope except for additive execution of the new pure tests in the
existing `ci-script-tests` root.
