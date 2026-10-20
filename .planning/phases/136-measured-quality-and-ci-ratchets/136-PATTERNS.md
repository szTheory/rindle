# Phase 136: Measured Quality and CI Ratchets - Pattern Map

**Mapped:** 2026-10-20
**Scope:** MAINT-04, TYPE-03, COV-06, TEST-08, CI-15, CI-16, DX-05
**Context:** No `136-CONTEXT.md`; the approved scope comes from `136-RESEARCH.md` and the seven requirements. Paths below are candidate owners, not a mandate to create every proposed file.
**Tracked-source gate:** Every existing analog named here was checked with `git ls-files -- <path>`; no install/runtime mirror is used.

## File Classification

| New/Modified File | Role | Data Flow | Closest Tracked Analog | Match |
|---|---|---|---|---|
| `scripts/maintainer/credo_quality_normalize.exs` | utility | transform | same file | exact |
| `scripts/maintainer/credo_quality.sh` | service/probe | batch, file I/O | same file | exact |
| `scripts/maintainer/credo_complexity_baseline.json` | config/ledger | batch | same file | exact |
| `test/install_smoke/credo_policy_test.exs` | test | request-response, file I/O | same file | exact |
| `.dialyzer_ignore.exs` | config/ledger | batch | `test/install_smoke/dialyzer_ignore_policy_test.exs` | role-adjacent |
| `test/install_smoke/dialyzer_ignore_policy_test.exs` | test | file I/O | same file | exact |
| `coveralls.json` | config | batch | same file; `.github/workflows/ci.yml` | exact |
| Focused behavioral tests for any complexity or type finding removed | test | request-response | owner-specific existing test, selected only after a finding is chosen | conditional |
| `scripts/maintainer/async_isolation_evidence.sh` | service/probe | batch, file I/O | same file | exact |
| `test/install_smoke/async_isolation_evidence_runner_test.exs` | test | file I/O | same file | exact |
| New async receipt validator (name TBD) | utility/probe | batch, file I/O | `scripts/maintainer/async_isolation_evidence.sh`; `scripts/ci/collect_pr_timing_receipt.sh` | data-flow match |
| New async receipt validator test (name TBD) | test | file I/O | `test/install_smoke/async_isolation_evidence_runner_test.exs` | exact role/flow |
| `.github/workflows/ci.yml` and affected `.github/workflows/nightly.yml` / `release.yml` | config | event-driven | current `ci.yml` | exact |
| `.github/actions/setup-minio/action.yml` | config | event-driven, download | same file | exact |
| `scripts/ci/install_ffmpeg.sh` | service/installer | request-response, file I/O | same file | exact |
| `test/install_smoke/quality_signal_policy_test.exs` plus any dedicated CI integrity test | test | event-driven configuration transform | same file | exact |
| `test/install_smoke/ci_cache_hygiene_test.exs` and `ci_lane_split_test.exs` | test | event-driven configuration transform | same files | exact |
| `CONTRIBUTING.md`, `RUNNING.md` | documentation | command map | same files | exact |
| New clean contributor bootstrap probe and test (names TBD) | utility/test | batch, file I/O | `scripts/ci/test_nightly_dialyzer.sh`; `test/install_smoke/docs_parity/onboarding_and_capabilities_test.exs` | partial |
| `scripts/ci/collect_pr_timing_receipt.sh` and `test/install_smoke/ci_timing_automation_test.exs` | service/test | live request-response, file I/O | same files | exact; reuse, likely no edit |

## Pattern Assignments

### Credo removal-only ledger: `credo_quality_normalize.exs`, `credo_quality.sh`, baseline JSON, `credo_policy_test.exs`

**Primary analog:** `test/install_smoke/dialyzer_ignore_policy_test.exs:48-75` already expresses the subset ratchet that Credo needs:

```elixir
assert valid_ignore_list?(List.delete_at(ignores, 0))
assert_invalid([{"lib/rindle.ex", :unapproved_atom}])
assert_invalid([{"lib/rindle.ex", "specific"}, {"lib/rindle.ex", "specific"}])
Enum.uniq(ignores) == ignores and
  Enum.all?(ignores, &valid_filter?/1) and
  MapSet.subset?(MapSet.new(ignores), MapSet.new(@approved_filters))
```

**Identity/import pattern:** `scripts/maintainer/credo_quality_normalize.exs:1-26,31-41` has no dependencies beyond Jason and Elixir stdlib. It groups raw issues by the stable `check/file/trigger/observed_metric` tuple and records occurrence `count`. Preserve that stable identity, explicit malformed-input errors (`:29,50,55,84-85,105`), sorting (`:109-110`), and owner/removal-trigger validation (`:74-89`). The current exact 27/31 check at `:61-64` must be revised for removal-only semantics.

**Call boundary:** `scripts/maintainer/credo_quality.sh:14-43` executes `mix credo suggest --config-name complexity_inventory --format json --mute-exit-status`, normalizes actual and baseline through `mix run --no-compile --no-start`, then `cmp -s` requires equality. Replace only the equality contract with a fail-closed subset/metric comparison; keep command failure and malformed JSON failures distinct. Avoid letting a changed metric or increased count pass under an identity-only subset.

**Ledger record:** `scripts/maintainer/credo_complexity_baseline.json:2-4` contains `check`, `file`, `trigger`, `observed_metric`, `count`, `owner`, `removal_trigger` in each entry. Keep these fields for retained findings. A removed entry requires a behavior-preservation test for its owner; choose that test once the actual finding is selected.

**Tests to change together:** `test/install_smoke/credo_policy_test.exs:47-76` freezes `27`, `31`, and four double occurrences; `:96-108` currently rejects deletion. Convert these to mutation fixtures: approved removal succeeds, new identity fails, changed/higher metric fails, count growth fails, duplicate identity fails, missing owner/trigger fails. Keep the temporary baseline injection at `:171-189` (`CREDO_QUALITY_BASELINE`) and its cleanup. Its `async: false` at `:2` is appropriate because the test runs the real aggregate and writes a temporary fixture under the tree.

### TYPE-03: `.dialyzer_ignore.exs`, policy test, supported Nightly runner

**Analog:** `test/install_smoke/dialyzer_ignore_policy_test.exs:4-46,48-95`. The allowlist is exact `{source_path, discriminator}` pairs. The live ignore list must be unique, owned by an existing `lib/` or `test/support/` source, and a `MapSet.subset?` of the approved list. `:54-67` already tests removal and rejection of new, duplicate, empty, regex, and malformed filters. Extend only for any narrower identity or newly chosen suppression behavior; do not substitute another toolchain or relax discriminators.

**Execution/error pattern:** `scripts/ci/run_nightly_dialyzer.sh:5-22,121-147` accepts only `fresh|restored`, refuses caller `PLT_DIR`, confines PLTs to `priv/plts`, and permits one restored-mode retry for the exact `Old PLT file` fingerprint. `scripts/ci/test_nightly_dialyzer.sh:64-95` copies the runner into a temporary repo fixture, injects fake Mix, and checks status plus command sequence. Reuse those fixtures for fast negative tests; supported-cell fresh/restored CI remains the final analysis authority.

### COV-06: `coveralls.json`, coverage command, behavior tests

**Analog:** `RUNNING.md:98-109` and `.github/workflows/ci.yml:214-227` both use one `mix coveralls.multiple --type local --type json` suite invocation. The `local` analyzer gates; JSON is the side artifact from that same execution. `coveralls.json:1-5` currently sets `minimum_coverage` to 69 and `treat_no_relevant_lines_as_covered` to true. The historical accepted exact result is 82.1343% (research); acquire fresh supported-cell covered/relevant counts on the immutable subject before choosing the representable configured threshold. A passing 69 gate alone does not establish COV-06. Add focused behavior tests for actual changed branches, not a percentage-only assertion.

### TEST-08: async runner, new receipt validator, fixtures

**Runner analog:** `scripts/maintainer/async_isolation_evidence.sh:5-23,43-76,80-114` declares the 25 ordered seeds and one coverage argv, emits read-only `--validate` JSON lines, requires a new `.jsonl` under the evidence directory, records SHA/toolchain/argv/status/failure location, and stops at first red. Preserve the seed order and no-clobber guard. A validator should parse the JSONL, require the declared header and fields, contiguous iterations matching the fixed seed prefix, one immutable SHA and supported toolchain, exit zero through a complete 25 runs or one terminal nonzero record, and an explicit unresolved result/next trigger when red. Verification should never launch Mix or replace an existing receipt.

**Fixture/test analog:** `test/install_smoke/async_isolation_evidence_runner_test.exs:9-62,72-115` invokes `--validate`, injects a fake `mix` via `PATH`, checks all 25 invocations in order, and checks first-red stop/status/redaction. Extend with existing-target byte preservation, malformed/truncated/foreign-SHA/seed-order receipt fixtures, and validator pass/fail cases. Use `on_exit` cleanup (`:77-100`). For a separate receipt verifier, copy the strict machine-readable shape and exact-subject checks in `scripts/ci/collect_pr_timing_receipt.sh:147-166,187-218`, without borrowing its Phase 132 transition-manifest mode.

### CI-15/CI-16: semantic workflow and input-integrity tests

**Best semantic analog:** `test/install_smoke/quality_signal_policy_test.exs:4-10,86-101,119-140`:

```elixir
setup_all do
  {:ok, %{workflow: YamlElixir.read_from_file!(@ci_path), mix: File.read!(@mix_path)}}
end

summary = job(workflow, "ci-summary")
assert workflow["name"] == "CI"
assert summary["name"] == "CI Summary"
assert "quality" in summary["needs"]
refute "package-consumer-full" in summary["needs"]

defp job(workflow, name), do: workflow |> Map.fetch!("jobs") |> Map.fetch!(name)
defp steps(workflow, job_name), do: job(workflow, job_name) |> Map.fetch!("steps")
```

Extend this parsed map approach to assert the correct job's `timeout-minutes`, `needs`, `if`, permissions, cache step, action ref, image and download/install step. Mutate a parsed workflow fixture in memory (`put_in`/`update_in`) and assert the policy rejects a wrong value in the relevant job; a matching literal in a comment or unrelated job must not pass. `quality_signal_policy_test.exs:119-129` is the step helper pattern for exact command, condition, and no `continue-on-error`. For executable download scripts, use the file-fixture execution style in `test/install_smoke/ci_cache_hygiene_test.exs:179-215` and fake-command approach in `scripts/ci/test_nightly_dialyzer.sh:64-95` to prove checksum mismatch fails before install. Existing `ci_cache_hygiene_test.exs:169-176` explicitly approves the rolling FFmpeg URL and must change with any pin/checksum policy. `.github/actions/setup-minio/action.yml:20-43` currently uses `minio/minio` and a mutable `mc` URL; `scripts/ci/install_ffmpeg.sh:20-69` resolves a latest release and installs an unauthenticated archive. These are the primary integrity edit points.

**Topology authority:** `config/ci_required_checks.json:1-11` fixes `ci.yml` / `CI` / `ci-summary` / sole `CI Summary` context. `.github/workflows/ci.yml:1-35,37-46,1441-1480` contains PR/push trigger, workflow concurrency, read-only default permission, a bounded Quality job, and the required summary's `needs`/`if: always()`/evaluation step. `test/install_smoke/ci_lane_split_test.exs:141-150,443-471` locks the required graph and release coupling. Preserve fork safety and exact-SHA release gating while adding timeout/input checks; do not create a second required context.

**Timing:** `scripts/ci/collect_pr_timing_receipt.sh:29-50` defaults to exactly 10 samples, median 480 seconds, p95 600 seconds. Its verifier at `:147-235` requires one source/table marker pair, 10 unique run IDs, a full SHA, live GitHub run and `CI Summary` identity, complete eligible population, sequential chronology, recomputed median/p95, and inclusive limits. `test/install_smoke/ci_timing_automation_test.exs:6-67,80-107` uses isolated fake `gh` state, then verifies the result and preserves failed-state bytes. Reuse the existing controller after topology settles; a source projection or an old receipt cannot close CI-16.

### DX-05: contributor command map and clean bootstrap probe

**Documentation analog:** `CONTRIBUTING.md:15-61,152-166` already describes `mix ci`, prerequisites, and a change-to-proof table. `RUNNING.md:98-149` gives the canonical coverage, async validation, Credo, Doctor, and focused AV commands. Add an ordered clean setup path tied to `.tool-versions:1-2` (Elixir 1.17.3/OTP 27.2) and CI's actual Node setup, then map focused versus full proof with copyable commands. `test/install_smoke/docs_parity/onboarding_and_capabilities_test.exs:1-30` provides the default-suite docs parity style; a new test should check executable commands and their intended owners, not only prose substrings.

**Executable probe analog:** `scripts/ci/test_nightly_dialyzer.sh:64-95` builds a temporary copied repo fixture, injects fake binaries, verifies command order/status, and cleans up. Use an isolated clean checkout or copy for the bootstrap probe, with separate supported-runtime qualification when available. No existing tracked script is a full clean-contributor bootstrap verifier; this is a deliberate new capability. Current `.tool-versions` has only Elixir and Erlang, while `test/install_smoke/ci_cache_hygiene_test.exs:145-157` still expects `nodejs 20.18.1`; reconcile the test, documented Node version, and actual CI setup rather than copying that stale assertion.

## Shared Patterns

- **Fail closed and preserve evidence.** Shell scripts use `set -euo pipefail`, bounded temp directories with `trap`, distinct failure messages, and no-clobber output guards (`async_isolation_evidence.sh:1-3,65-85`). Tests compare prior bytes on rejected mutations (`ci_timing_automation_test.exs:80-107`).
- **Structural policy rather than text presence.** `YamlElixir.read_from_file!` and job/step navigation are available in `quality_signal_policy_test.exs:8-10,119-140`. Text checks in older cache/lane tests should not be copied for new job-specific semantic claims.
- **One source of required-check truth.** `config/ci_required_checks.json:1-11`, `quality_signal_policy_test.exs:86-98`, and `RUNNING.md:177-197` all identify the same sole context and release coupling.
- **Fresh evidence on supported subject.** Coverage, fresh/restored Dialyzer, async matrix, and live timing need the pinned supported runtime and exact source SHA. Fast fixture tests establish policy behavior, not those measured outcomes.
- **No application auth layer.** These are maintainer/CI probes. GitHub token scope and job `permissions` are the relevant guard; avoid putting secrets in receipts or fixture output.

## No Close Analog Found

| Proposed File | Role / Flow | Gap |
|---|---|---|
| Clean contributor bootstrap probe (name TBD) | utility / batch, file I/O | Existing fixture runners test CI scripts, but none exercises the complete documented clean setup with the supported runtime. |
| Exact coverage measurement receipt (only if planner chooses a new artifact) | evidence/config / batch | Existing JSON output and timing receipts give pieces; no Phase 136 exact covered/relevant baseline receipt exists yet. |

## Verification Commands for Plans

Use focused fixtures before supported-cell or live evidence. Existing commands: `mix test test/install_smoke/credo_policy_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs`, `mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/async_isolation_evidence_runner_test.exs`, `bash scripts/ci/test_nightly_dialyzer.sh`, `bash scripts/maintainer/async_isolation_evidence.sh --validate`, `mix credo_quality`, and one `mix coveralls.multiple --type local --type json`. The async `--report` loop, fresh PLT analysis, and exact-ten live PR sample belong to execution on the final subject, not planning. Run `./scripts/maintainer/automation_first_contract.sh` after active planning artifact edits per `AGENTS.md`.

## Metadata

**Analog search scope:** `scripts/maintainer/`, `scripts/ci/`, `test/install_smoke/`, `.github/actions/`, `.github/workflows/`, root config/docs.
**Primary strong analogs:** Credo policy/normalizer, Dialyzer policy, async runner/test, parsed workflow policy, CI timing controller/test.
**Important planning gate:** Phase 136 depends on Phase 135; mapping here does not treat unfinished earlier phase evidence as acceptance.
