# Phase 132: Measured Closure - Pattern Map

**Mapped:** 2026-08-25  
**Files analyzed:** 3  
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/install_smoke/support/generated_app/workspace.ex` | utility / process wrapper | file-I/O / request-response | same file: `fetch_deps!/3` | exact |
| `test/install_smoke/generated_app_smoke_test.exs` | test | event-driven integration | same file: image smoke module and fast contracts | exact |
| `.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md` | evidence artifact | batch / transform | same file: failed-baseline receipt | exact |

`.github/workflows/ci.yml`, `scripts/ci/eval_ci_summary.sh`, and the CI topology tests are preservation sources only. The phase contract expressly rules them out as edit targets.

## Pattern Assignments

### `test/install_smoke/support/generated_app/workspace.ex` (utility / process wrapper, file-I/O)

**Analog:** `test/install_smoke/support/generated_app/workspace.ex` lines 27-50.

**Imports and command-runner boundary** (lines 1-4):

```elixir
defmodule Rindle.InstallSmoke.GeneratedApp.Workspace do
  @moduledoc false

  alias Rindle.InstallSmoke.GeneratedApp.CommandRunner
```

**Generator argv pattern** (lines 27-41): preserve the `CommandRunner.run!/3` call, working directory, generated root argument, feature omissions, and `MIX_ENV`; make the smallest argv-only correction by removing `"--install"`.

```elixir
def generate_phoenix_app!(workspace_root, generated_app_root) do
  CommandRunner.run!(
    workspace_root,
    ["mix", "phx.new", generated_app_root,
     "--no-assets", "--no-dashboard", "--no-mailer", "--no-gettext", "--install"],
    [{"MIX_ENV", "dev"}]
  )
end
```

**Post-patch dependency authority** (lines 45-50): do not move or delete this later `deps.get`; it is the single dependency installation after `Patcher.patch!/9` has inserted the package source.

```elixir
def fetch_deps!(generated_app_root, shared_env, network_version) do
  if network_version do
    retry_network_deps_get!(generated_app_root, shared_env)
  else
    CommandRunner.run!(generated_app_root, ["mix", "deps.get"], shared_env)
  end
end
```

**Failure/retry pattern** (lines 119-132): retain the bounded network-only retry and its loud terminal error; the package path remains one direct `run!/3` call.

### `test/install_smoke/generated_app_smoke_test.exs` (test, event-driven integration)

**Analog:** `test/install_smoke/generated_app_smoke_test.exs` lines 744-784.

**Image-proof fixture pattern** (lines 746-755): image work is serialized, tagged `:minio`, builds one report in `setup_all`, and cleans the temporary workspace on exit.

```elixir
defmodule Rindle.InstallSmoke.GeneratedAppSmokeImageTest do
  use ExUnit.Case, async: false
  use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
  @moduletag :minio

  setup_all do
    report = GeneratedAppHelper.prove_package_install!(:image)
    on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
    {:ok, report: report}
  end
end
```

**Preservation assertions** (lines 757-783): add the focused generator-argv contract near the existing fast contracts (lines 123-153), then retain the integration assertions below. The focused contract should read the workspace source and assert generation does *not* contain `"--install"`, while the image integration proof continues checking package provenance, compilation, boot, migrations, and lifecycle.

```elixir
assert_install_source!(report)
assert report.compile_exit_code == 0
assert report.boot_exit_code == 0
assert report.smoke_exit_code == 0
assert report.lifecycle_proved?
assert_host_owned_migrations!(report)
assert_default_schema_ownership!(report)
```

**Shared assertion contract** (lines 10-40): package mode must keep using the unpacked package and must not create `deps/rindle`; compilation and boot must succeed.

```elixir
if report.install_mode == :package do
  refute report.deps_rindle_present?
end

assert report.compile_exit_code == 0
assert report.boot_exit_code == 0
```

### `.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md` (evidence artifact, batch / transform)

**Analog:** `.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md` lines 7-50.

**Receipt table pattern** (lines 7-18): preserve the failed baseline; append a distinct final-receipt section/table keyed to the corrected immutable SHA. Each row needs sequence, short SHA, UTC start, seconds and human duration, linked Actions run, attempt, and exception disposition.

```markdown
| Run | Commit | Started (UTC) | Required-gate duration | Result | Exception evidence |
|-----|--------|---------------|------------------------|--------|--------------------|
| 1 | `005beae` | 2026-08-25 14:17:24 | 8m54s (534s) | [success](...), attempt 1 | None |
```

**Method and statistical convention** (lines 22-29): require one PR head, sequential `pull_request` executions, successful non-cancelled `run_attempt: 1` results, and duration from workflow `startedAt` through `CI Summary.completedAt`. Sort ten values, average ranks 5 and 6 for median, and take `ceil(N * 0.95)` for p95.

**Outcome pattern** (lines 31-50): add a target/observed/verdict table for median, p95, run integrity, and required gate; do not overwrite the existing failed conclusion until the fresh qualifying receipt exists.

## Shared Patterns

### Patch before dependency resolution

**Sources:** `test/install_smoke/support/generated_app_helper.ex` lines 181-203 and 540-569.  
**Apply to:** the `workspace.ex` argv correction and its test.

```elixir
generate_phoenix_app!(workspace_root, generated_app_root)
patch_generated_app!(generated_app_root, app_name, app_module, package_root,
  network_version, profile_mode, options)
fetch_deps!(generated_app_root, shared_env, network_version)
compile_result = run_cmd!(generated_app_root, ["mix", "compile"], shared_env)
_ = run_cmd!(generated_app_root, ["mix", "ecto.create"], shared_env)
```

### Required-gate preservation

**Sources:** `.github/workflows/ci.yml` lines 563-568; `scripts/ci/eval_ci_summary.sh` lines 42-59.  
**Apply to:** verification only; do not change the package-consumer job, `ci-summary.needs`, the check name, or skip-as-pass behavior.

```bash
case "${result}" in
  success|skipped) ;;
  *) failed=1 ;;
esac
```

### Read-only timing collection

**Source:** `scripts/ci/collect_ci_baseline.sh` lines 28-79.  
**Apply to:** final live receipt collection.

```bash
set -euo pipefail
gh api --paginate --slurp \
  "repos/${REPO}/actions/workflows/ci.yml/runs?branch=${BRANCH}&per_page=100"
```

Keep the receipt collector/readout free of `gh api -X PUT|POST|PATCH|DELETE`, matching the executable observability contract in `test/install_smoke/ci_observability_test.exs` lines 190-211.

## No Analog Found

None. The focused generator-command assertion is new in intent, but belongs in the existing fast-contract block of `generated_app_smoke_test.exs`; the command construction, lifecycle proof, and receipt format all have direct local precedents.

## Metadata

**Analog search scope:** `test/install_smoke/support/generated_app/`, `test/install_smoke/`, `scripts/ci/`, `.github/workflows/`, and Phase 132 artifacts.  
**Files scanned:** 10  
**Pattern extraction date:** 2026-08-25
