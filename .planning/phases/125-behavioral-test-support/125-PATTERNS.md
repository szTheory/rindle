# Phase 125: Behavioral Test Support - Pattern Map

**Mapped:** 2026-08-23
**Files analyzed:** 14 likely implementation, test, and CI-preservation surfaces
**Analogs found:** 13 / 14

The repository has no approved Phase 125 `CONTEXT.md` or `RESEARCH.md` yet. This map derives the
candidate file map from the Phase 125 roadmap/requirements and current shipped code. Candidate new
support-module names below are seams, not a mandate to create every named file. Preserve the
existing public test-facing `Rindle.InstallSmoke.GeneratedAppHelper` entrypoints until every caller
has been migrated.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/install_smoke/support/generated_app_helper.ex` | test-support facade/orchestrator | process, file-I/O, request-response | current helper public entrypoints | exact extraction seam |
| `test/install_smoke/support/generated_app/{contracts,workspace,patcher,migrations,smoke_source}.ex` | test-support utilities | transform, file-I/O, process | current helper private regions | extraction seam |
| `test/install_smoke/generated_app_smoke_test.exs` | behavior and structural-contract test | process, request-response, CRUD | current report assertions and `CaseTemplate` | exact |
| `test/install_smoke/phoenix_tus_truth_parity_test.exs` | public-contract parity test | file-I/O, request-response | compiled-doc/capability tests | role + flow |
| `test/install_smoke/support/docs_parity_helpers.ex` | test utility | file-I/O, transform | private helper block in `docs_parity_test.exs` | extraction seam |
| `test/install_smoke/docs_parity/{onboarding,migrations,operations}.exs` (or equivalent domain files) | docs-parity tests | file-I/O, transform | current `DocsParityTest` | exact |
| `test/install_smoke/docs_parity_test.exs` | compatibility loader or retired aggregate | file-I/O | current proof-lane entrypoint | role-match |
| `test/install_smoke/release_docs_parity_test.exs` | release-domain parity test | file-I/O | current `ReleaseDocsParityTest` | exact |
| `test/rindle/config/repo_override_isolation_test.exs` | concurrency/integration test | event-driven, transaction | current bare-process sandbox proof | exact |
| `test/support/counting_failing_txn_repo.ex` | deterministic repo double | request-response, transaction | current process-local override wrapper | exact |
| `lib/rindle/config.ex` | config/resolver (preservation surface) | request-response, process-local lookup | current `$callers` resolver | exact |
| `.github/workflows/ci.yml` | CI config | batch/process | current `proof` docs-parity step and quality coverage step | exact |
| `RUNNING.md` | CI contract documentation | transform | current coverage reproduction section | exact |
| `scripts/maintainer/refactor_contract.sh` + `test/install_smoke/refactor_contract_test.exs` | SAFE-01 runner/meta-test | batch | current one-foreground-process contract | exact |

## Pattern Assignments

### Generated-app support split

#### `test/install_smoke/support/generated_app_helper.ex` (test-support facade, process/file-I/O)

**Primary analog:** the current helper's public/private split:
[`generated_app_helper.ex`](../../../test/install_smoke/support/generated_app_helper.ex:23) lines
23-703 expose contracts/proof/cleanup; lines 711-3955 are private workspace generation, patching,
migration, process, and generated-test source mechanics.

Keep the loader path and the existing public API stable while extracting focused collaborators:

```elixir
def prove_package_install!(profile_mode \\ :image)
    when profile_mode in [:image, :video, :tus, :mux, :gcs] do
  prove_package_install!(profile_mode, [])
end

def cleanup(%{generated_app_root: generated_app_root} = report) do
  File.rm_rf!(Path.dirname(generated_app_root))
  report
end
```

The main suite loads this file directly at
[`generated_app_smoke_test.exs`](../../../test/install_smoke/generated_app_smoke_test.exs:1), and
the aggregate docs suite aliases it at
[`docs_parity_test.exs`](../../../test/install_smoke/docs_parity_test.exs:3-4). Either retain a
thin facade at this exact path or update both loaders atomically. Do not expose the new modules as
library API: use `@moduledoc false`; callable support seams should be `@doc false`.

**Suggested ownership boundaries (all private today):**

| Candidate collaborator | Move from current helper | Preserve |
|---|---|---|
| `GeneratedApp.Contracts` | lines 23-201 (`*_contract`, catalog predicate) | contract keys, atom/string JSON shape, reject semantics |
| `GeneratedApp.Workspace` | lines 711-753, 1932-2177 | `mktemp` OS-global allocation, unpacked-package provenance, package/network source rules, stage-labelled timeout diagnostics |
| `GeneratedApp.Patcher` | lines 754-1311 | exact generated Phoenix config/router/application/profile behavior and profile gates |
| `GeneratedApp.Migrations` | lines 1312-1804 | host-owned Oban vs pinned `Rindle.Migration` ownership, migration ordering, catalog snapshots |
| `GeneratedApp.SmokeSource` | lines 1805-1922, 2181-3929 | generated lifecycle behavior and emitted JSON report fields for image/video/tus/gcs/mux/upgrade |

**Critical command pattern** (current helper lines 1952-1998): commands return a structured result
and the caller supplies the stage label. Keep this boundary rather than raising anonymous shell
failures:

```elixir
case run_cmd(cwd, argv, env) do
  %{exit_code: 0} = result -> result
  result -> raise "generated-app command failed: stage=#{stage} ..."
end
```

Do not move test bodies into the orchestrator's source string merely to reduce module count. The
generated app must still compile/boot/run as the observer; preserve each profile's
`lifecycle_test_source/2` branch at lines 2181-2847 and profile helper branch at lines 3059-3929.

#### `test/install_smoke/generated_app_smoke_test.exs` (behavior + explicit structural contract)

**Analog:** [`generated_app_smoke_test.exs`](../../../test/install_smoke/generated_app_smoke_test.exs:3),
lines 3-106 uses a `CaseTemplate` to share report assertions; its generated-install modules later
assert report fields after `setup_all` runs the real proof.

```elixir
use ExUnit.CaseTemplate

using do
  quote do
    defp assert_install_source!(report) do
      assert File.dir?(report.generated_app_root)
      assert report.install_mode in [:package, :network]
      assert report.compile_exit_code == 0
      assert report.boot_exit_code == 0
    end
  end
end
```

Replace the self-reading assertions at lines 294-349 with one of these objective forms:

1. Assert generated report/catalog facts from `prove_isolation_upgrade!/0` (before/after
   `oban_jobs` snapshots, selected/decoy relations, migration marker, and `doctor_ready?`).
2. Assert explicit contract data returned by a narrow support API, such as deterministic
   `required_report_keys` or normalized catalog-policy inputs/outputs, rather than text inside the
   helper implementation.
3. For public library claims, use compiled metadata (`function_exported?/3`, `Code.fetch_docs/1`,
   capability functions) or a deliberately scoped AST/structural contract. `schema_prefix_contract_test.exs`
   is the local precedent for a structural contract; it parses a source AST and then validates
   runtime schema metadata, rather than asserting free-form implementation strings.

The existing catalog mutation matrix at lines 353-527 is the strongest immediate analog: it calls
`isolation_upgrade_catalog_preserved?/1` with missing/changed facts and observes accept/reject
behavior. Keep it and extend report-backed behavior rather than grepping SQL aliases or task
internals.

#### `test/install_smoke/phoenix_tus_truth_parity_test.exs` (public contract parity)

**Primary analog:** [`test/rindle/live_view_test.exs`](../../../test/rindle/live_view_test.exs:364),
lines 364-388 uses `Code.fetch_docs/1`; the same file uses runtime helpers where LiveView is
available. [`phoenix_tus_truth_parity_test.exs`](../../../test/install_smoke/phoenix_tus_truth_parity_test.exs:86-90)
already correctly observes adapter capabilities.

Preserve guide-to-public-source parity, but eliminate the helper text read at lines 20-70. Assert
the generated-app outcome instead: the real tus profile report should expose endpoint, uploader,
session/asset identifiers, completion surface, state sequence, and error state. Assert the public
`Rindle.LiveView` API/docs with `Code.fetch_docs/1`/`function_exported?/3`, then verify the
generated Phoenix app reached the same observable lifecycle. Do not assert that an internal
support file contains `allow_tus_upload(` or a particular local variable name.

### Documentation parity split

#### `test/install_smoke/support/docs_parity_helpers.ex` (test helper, file-I/O/transform)

**Analog:** [`docs_parity_test.exs`](../../../test/install_smoke/docs_parity_test.exs:1026), lines
1026-1118. Extract only genuinely shared data and mechanics: path/read setup, normalized ordering,
section extraction, fenced Elixir extraction, migration-call parsing, and compiled-doc lookup.

```elixir
defp assert_in_order!(doc, snippets) do
  normalized_doc = String.downcase(doc)

  snippets
  |> Enum.map(&string_index(normalized_doc, String.downcase(&1)))
  |> Enum.chunk_every(2, 1, :discard)
  |> Enum.each(fn [left, right] -> assert left < right end)
end

defp fetch_docs!(module) do
  assert Code.ensure_loaded?(module), "#{inspect(module)} must be loadable for docs parity checks"
  Code.fetch_docs(module)
end
```

Use a normal support module with `@moduledoc false` and explicit helper names, then require it
from each domain suite. Do not create a generic whole-document snapshot helper: each suite must
name the public contract it owns in its module/test names and failure messages.

#### `test/install_smoke/docs_parity/{onboarding,migrations,operations}.exs` (docs-parity tests)

**Primary analog:** the current aggregate [`docs_parity_test.exs`](../../../test/install_smoke/docs_parity_test.exs:39-1024).
It already has a correct read-once `setup_all` pattern and narrow public-domain assertions.

```elixir
setup_all do
  {:ok,
   %{
     readme: File.read!(@readme_path),
     getting_started: File.read!(@guide_path),
     migration_module: File.read!(@migration_module_path)
   }}
end
```

Split by contract domain, not by arbitrary line count:

| Domain suite | Move current aggregate assertions | Main dependency boundary |
|---|---|---|
| onboarding/profile/AV | lines 57-175, 528-635, 739-803 | README, getting-started, RUNNING, public profile/AV claims |
| migration/upgrade | lines 176-527, 653-738 | `Rindle.Migration`, host-owned Oban, generated-app migration contract |
| operations/owner-erasure/admin | lines 804-1024 | public Mix tasks, doctor/runtime split, user flows, admin guide |

Keep [`release_docs_parity_test.exs`](../../../test/install_smoke/release_docs_parity_test.exs:15-28)
as its own release domain: it has a dedicated `setup_all` map and release-workflow/manifest
dependencies. Keep the smaller streaming-cancel suite separate because it owns the streaming
provider contract. Files explicitly read by a docs test are valid shipped-document parity inputs;
the prohibition here is self-reading *internal helper/source text* to prove implementation wording.

**CI dependency:** proof currently executes exactly
`mix test test/install_smoke/docs_parity_test.exs` in
[`ci.yml`](../../../.github/workflows/ci.yml:551-552). If the aggregate file is removed, update
this one exact focused command to list all new domain files (or retain it as a compatibility loader
that requires them). Do not rely on default-suite discovery alone; proof must continue to run every
docs-parity domain before `check_docs_links.sh`.

### Issue #42 async-isolation stress evidence

#### `test/rindle/config/repo_override_isolation_test.exs` (concurrency/integration)

**Analog:** current exact proof at
[`repo_override_isolation_test.exs`](../../../test/rindle/config/repo_override_isolation_test.exs:31-66).
It deliberately uses `spawn`, not `Task.async`, so the reader has no `:"$callers"` inheritance;
it blocks B, grants the Sandbox connection, opens the process-A override window, then releases B.

```elixir
reader =
  spawn(fn ->
    receive do :go -> :ok end
    result = {Config.repo(), Config.repo().transaction(fn -> :ok end)}
    send(test_pid, {:reader_result, self(), result})
  end)

Sandbox.allow(Rindle.Repo, test_pid, reader)

CountingFailingTxnRepo.with_counting_repo(1, fn ->
  assert Config.repo() == Rindle.Test.CountingFailingTxnRepo
  send(reader, :go)
  assert_receive {:reader_result, ^reader, {Rindle.Repo, {:ok, :ok}}}
end)
```

Stress the existing causal property, rather than changing the resolver first. Add a bounded,
deterministic repetition/coordination layer only if it keeps one run diagnostically useful: each
iteration must prove A sees the double and force-fails, while unrelated B resolves `Rindle.Repo`
and commits. Include an explicit assertion that B was released while A's override callback remains
open. Avoid `Task.async` for the unrelated-reader leg: it makes B a `$callers` descendant and
inverts the contract.

#### `test/support/counting_failing_txn_repo.ex` and `lib/rindle/config.ex` (preservation surfaces)

**Analog:** the current install/cleanup wrapper at
[`counting_failing_txn_repo.ex`](../../../test/support/counting_failing_txn_repo.ex:7-17):

```elixir
Rindle.Config.put_repo_override(__MODULE__)
Process.put(@config_key, fail_after: fail_after)
reset_count()

try do
  fun.()
after
  Rindle.Config.delete_repo_override()
  Process.delete(@config_key)
  reset_count()
end
```

Do not reintroduce `Application.put_env(:rindle, :repo, ...)`. The resolver's public fallback must
stay unchanged, while its private path walks the `$callers` tree:

```elixir
def repo do
  with nil <- repo_override(self()) do
    Application.get_env(:rindle, :repo, Rindle.Repo)
  end
end

defp caller_repo_override(pid) do
  pid
  |> process_get(:"$callers")
  |> List.wrap()
  |> Enum.find_value(fn caller -> caller != pid && repo_override(caller) end)
end
```

The tuple process-dictionary key requires `List.keyfind(dict, key, 0)` in
[`config.ex`](../../../lib/rindle/config.ex:119-133), not `Keyword.get/3`. Preserve that fix under
stress; it was the latent defect the original issue proof exposed.

#### Single-run coverage evidence (`.github/workflows/ci.yml`, `RUNNING.md`)

**Analog:** [`ci.yml`](../../../.github/workflows/ci.yml:212-240), especially the sole quality
command at line 225:

```sh
mix coveralls.multiple --type local --type json --slowest 20 2>&1 | tee /tmp/test.out
```

Issue #42 is not closed merely by a focused test or YAML string assertion. Run the stressed
isolation test as part of the actual single ExUnit execution behind this command, and retain the
two outputs: `--type local` is the blocking analyzer, `--type json` is a side artifact. The written
operator contract is in [`RUNNING.md`](../../../RUNNING.md:82-97); preserve it and do not add a
second test/coverage pass for the stress test.

### SAFE-01 runner/meta-test

**Analog:** [`scripts/maintainer/refactor_contract.sh`](../../../scripts/maintainer/refactor_contract.sh:1-18)
plus [`refactor_contract_test.exs`](../../../test/install_smoke/refactor_contract_test.exs:4-82).

```sh
MIX_ENV=test mix compile --force
MIX_ENV=test mix xref graph --format cycles --label compile-connected --fail-above 0

exec mix test --include contract --seed 0 \
  test/rindle/api_surface_boundary_test.exs \
  ...
```

If a new Phase 125 structural/compiled-boundary contract genuinely protects SAFE-01, add it to the
runner and the meta-test's `@required_suites` in the same commit. Keep exactly one foreground Mix
test process, no backgrounding/output masking, a planning-independent script, and compile-cycle
check before all preservation tests. A regular generated-app smoke or high-cost repeated DB stress
test should remain a focused/CI proof unless it is explicitly promoted into this fast preservation
contract.

## Shared Patterns

### Observable proof hierarchy

Use the strongest available observer in this order:

1. Real generated-app process/report or adapter/integration behavior.
2. Public compiled metadata (`Code.fetch_docs/1`, `function_exported?/3`, capabilities, runtime schema metadata).
3. A deliberately narrow structural contract (AST/compiled boundary) for a non-observable invariant.

Do not read a helper/module file and assert local strings, SQL aliases, local variable names,
timeout implementation calls, or source ordering. That creates a passing test for the code it is
supposed to independently validate.

### Read once, pass explicit facts

Docs suites use module path attributes and `setup_all` to read each owned document once; generated
support should resolve package source, environment, root, profile, and report ownership once at the
facade and pass explicit values to collaborators. A new collaborator must not reread config or
silently derive a different package/profile root.

### Test naming and failures

The test name should identify the public contract domain (`migration ownership`, `onboarding AV`,
`operations/doctor`, `release`, `streaming`) rather than a phase number or extraction detail.
Failures should name the missing/contradictory public claim, not an internal file split.

## Dependency Boundaries and Preserved Surfaces

| Boundary | Must remain true |
|---|---|
| Test loader | `generated_app_smoke_test.exs` and any surviving docs contract load all required support before their modules compile. |
| Generated-app profiles | image, video, tus, mux, gcs, public compatibility, isolation upgrade, and legacy upgrade retain current tags/profile gates and report shapes. |
| Packaged adopter proof | `scripts/install_smoke.sh` still invokes `generated_app_smoke_test.exs`; package/network provenance and no repo-local fallback remain covered. |
| Docs CI | `proof` runs every split docs domain plus link hygiene, rather than only a now-empty legacy aggregate path. |
| Async isolation | unrelated bare B sees `Rindle.Repo`; A and `$callers` descendants see the double; cleanup removes both override and process-local failure state. |
| Coverage | default suite executes once through `coveralls.multiple --type local --type json`; no standalone repeat added. |
| SAFE-01 | API/schema/migration/telemetry/error/CI-release contracts stay in the one foreground runner; new contract registration is dual-maintained with its meta-test. |

## Test Commands

Run focused checks while extracting (with the repo's normal PostgreSQL test prerequisites):

```sh
MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --include minio
MIX_ENV=test mix test test/rindle/config/repo_override_isolation_test.exs --seed 0
MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs
bash scripts/maintainer/refactor_contract.sh
```

After docs are split, replace the third command with the exact domain-file list wired into the
`proof` job. For final Issue #42 evidence, run the shipped coverage command once, not a second
ad-hoc suite:

```sh
mix coveralls.multiple --type local --type json --slowest 20
```

Generated-app smoke additionally needs the Phoenix generator archive and, except for GCS, MinIO;
[`scripts/install_smoke.sh`](../../../scripts/install_smoke.sh:25-82) is the canonical provisioned
entrypoint. Do not claim the issue non-reproducible without recording seed/repetition count, exact
single-run command, and its exit/output evidence in the phase verification artifact.

## No Analog Found

| File/decision | Role | Data Flow | Reason |
|---|---|---|---|
| Exact new generated-support module layout | test-support modules | process/file-I/O | No earlier test-support decomposition exists; use the current helper's cohesive private regions and retain the facade. |

## Pitfalls

- Do not delete or rename `test/install_smoke/support/generated_app_helper.ex` before both current loaders and packaged install-smoke references are accounted for.
- Do not replace one 3,955-line helper with a new generic mega-helper; each extracted module needs a single discoverable responsibility and explicit data input.
- Source reads remain appropriate for shipped documentation parity and narrow AST contracts, but not for proving helper implementation text.
- Keep public guides and release truth in their dedicated parity domains; do not mix release workflow assertions into adopter onboarding tests.
- `spawn` is intentional in the isolation proof. `Task.async` and an inherited `$callers` chain test a different, opposite property.
- Never use global repo configuration mutation in an `async: true` test; the async safety guard forbids the reintroduced footgun.
- Do not turn a JSON coverage artifact into the gate or add a second coverage execution; local analyzer + ExUnit exit remain authoritative.

## Metadata

**Analog search scope:** Phase 125 roadmap/requirements; generated-app helper and smoke suite; all current docs parity suites; compiled-doc/structural contract tests; repo override resolver/double/proof; CI workflow, RUNNING, install-smoke, and SAFE-01 runner/meta-test.
**Files scanned:** 20 primary code/test/config artifacts plus Phase 122/124 precedent maps.
**Pattern extraction date:** 2026-08-23
