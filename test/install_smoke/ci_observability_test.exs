defmodule Rindle.InstallSmoke.CiObservabilityTest do
  @moduledoc """
  Phase 103 (Observability Baseline) regression lock. Mirrors the
  ci_cache_hygiene_test / ci_lane_split_test `setup_all` + `File.read!`
  `=~`/`refute =~` style so the OBS-01/02/03 observability contract regresses
  inside the default `mix test` / `mix ci` suite (no exclude tag — same as the
  sibling install_smoke parity tests).

  ASSERTS CURRENT SHIPPED STATE. Every literal asserted below was grep-confirmed
  against the live files on disk (ci.yml, setup-elixir composite, test_helper.exs,
  mix.exs, the two read-only baseline collectors, and the committed baseline doc) —
  NOT a planned/SUMMARY-era layout.

  Scope note: the cache `id:`s that back the OBS-01 hit/miss summary live as
  `id: deps_cache` / `id: build_cache` (underscored) inside the setup-elixir
  COMPOSITE; ci.yml consumes them only via the composite's `deps-cache-hit` /
  `build-cache-hit` OUTPUTS (3 + 3 = 6 references across quality / integration /
  package-consumer). This file asserts that real contract — the composite cache
  step ids AND the six output references — rather than a non-existent literal
  `id: deps-cache` in ci.yml.

  Out of scope (Manual-Only, per 103-VALIDATION.md): the live required-check diff
  vs the pre-phase baseline genuinely needs a maintainer `gh` admin
  branch-protection read and is not automatable here.
  """
  use ExUnit.Case, async: true

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @setup_elixir_path Path.expand("../../.github/actions/setup-elixir/action.yml", __DIR__)
  @test_helper_path Path.expand("../../test/test_helper.exs", __DIR__)
  @mix_exs_path Path.expand("../../mix.exs", __DIR__)
  @collect_baseline_path Path.expand("../../scripts/ci/collect_ci_baseline.sh", __DIR__)
  @check_required_path Path.expand("../../scripts/ci/check_required_checks.sh", __DIR__)
  @baseline_doc_path Path.expand(
                       "../../.planning/milestones/v1.20-phases/103-observability-baseline/103-BASELINE.md",
                       __DIR__
                     )

  setup_all do
    {:ok,
     %{
       ci: File.read!(@ci_path),
       setup_elixir: File.read!(@setup_elixir_path),
       test_helper: File.read!(@test_helper_path),
       mix_exs: File.read!(@mix_exs_path),
       collect_baseline: File.read!(@collect_baseline_path),
       check_required: File.read!(@check_required_path)
     }}
  end

  # ------------------------------------------------------------------
  # OBS-01: per-job + per-step timing + cache hit/miss summary; gate unchanged.
  # ------------------------------------------------------------------
  test "OBS-01: ci.yml has a ci-observability aggregator job with if: always() and JOB-level actions: read",
       %{ci: ci} do
    assert ci =~ "\n  ci-observability:\n",
           "ci.yml must declare a `ci-observability` aggregator job (OBS-01)"

    obs = ci_observability_block(ci)

    assert obs =~ "if: always()",
           "ci-observability must run `if: always()` so timing is summarized even when an upstream job failed (OBS-01)"

    assert obs =~ "permissions:",
           "ci-observability must declare a JOB-LEVEL permissions block (OBS-01)"

    assert obs =~ "actions: read",
           "ci-observability must carry `actions: read` at JOB level to read the runs/jobs API (OBS-01)"
  end

  test "OBS-01: the OBS-01 cache hit/miss summary is backed by the composite's deps/build cache ids and six output references",
       %{ci: ci, setup_elixir: setup_elixir} do
    # The cache `id:`s that the OBS-01 summary reads live in the setup-elixir
    # COMPOSITE (underscored), not inline in ci.yml.
    assert setup_elixir =~ "id: deps_cache",
           "setup-elixir composite must give the deps cache step `id: deps_cache` (backs the OBS-01 hit/miss summary)"

    assert setup_elixir =~ "id: build_cache",
           "setup-elixir composite must give the build cache step `id: build_cache` (backs the OBS-01 hit/miss summary)"

    # ci.yml consumes them via the composite OUTPUTS — exactly 3 deps + 3 build
    # references (quality / integration / package-consumer). `==` so dropping a
    # cache-summary site (or a job's cache wiring) regresses this lock.
    assert count(ci, "deps-cache-hit") == 3,
           "ci.yml must reference the composite `deps-cache-hit` output 3× (quality/integration/package-consumer, OBS-01)"

    assert count(ci, "build-cache-hit") == 3,
           "ci.yml must reference the composite `build-cache-hit` output 3× (quality/integration/package-consumer, OBS-01)"
  end

  test "OBS-01: ci.yml appends a cache hit/miss table to $GITHUB_STEP_SUMMARY with cache-hit coalesced to 'false'",
       %{ci: ci} do
    assert ci =~ "Summarize cache hit/miss",
           "ci.yml must carry a `Summarize cache hit/miss` step that writes the OBS-01 table (OBS-01)"

    assert ci =~ "$GITHUB_STEP_SUMMARY",
           "the cache hit/miss table must be appended to $GITHUB_STEP_SUMMARY (OBS-01)"

    # An empty cache-hit output (restore-keys partial hit) must coalesce to 'false'
    # so the table never renders a blank cell.
    assert ci =~ "deps-cache-hit || 'false'",
           "deps cache-hit must be coalesced `|| 'false'` so a partial/empty hit renders as false (OBS-01)"

    assert ci =~ "build-cache-hit || 'false'",
           "build cache-hit must be coalesced `|| 'false'` so a partial/empty hit renders as false (OBS-01)"
  end

  test "OBS-01 GATE-UNCHANGED: name: CI on line 1 and the WORKFLOW-level permissions is contents: read (not actions: read)",
       %{ci: ci} do
    [first_line | _] = String.split(ci, "\n", parts: 2)

    assert first_line == "name: CI",
           "ci.yml line 1 must stay exactly `name: CI` — release coupling must not regress (OBS-01 gate-unchanged)"

    # The workflow-level permissions block is the FIRST `permissions:` occurrence
    # (before any job). Scope the assertion to that first block so the legitimate
    # JOB-level `actions: read` on ci-observability does not produce a false read.
    workflow_perms = workflow_level_permissions(ci)

    assert workflow_perms =~ "contents: read",
           "the WORKFLOW-level permissions must stay `contents: read` (OBS-01 gate-unchanged, D-03)"

    refute workflow_perms =~ "actions: read",
           "the WORKFLOW-level default must NOT become `actions: read` — that scope is granted only at the ci-observability JOB level (OBS-01 gate-unchanged, D-03)"
  end

  # ------------------------------------------------------------------
  # OBS-02: --slowest 20, compile profile, schedulers, seed, JUnit + coverage.
  # ------------------------------------------------------------------
  test "OBS-02: ci.yml surfaces slowest tests, compile profile, schedulers, seed, coverage json, and uploads JUnit + coverage artifacts",
       %{ci: ci} do
    for fragment <- [
          "--slowest 20",
          "mix compile --profile time",
          "schedulers_online",
          "Randomized with seed",
          "mix coveralls.json",
          "actions/upload-artifact@",
          "_build/test/junit/rindle-junit.xml"
        ] do
      assert ci =~ fragment,
             "ci.yml must surface #{inspect(fragment)} (OBS-02)"
    end
  end

  test "OBS-02: the gating step STAYS `mix coveralls --slowest 20` (coveralls.json is additive, never the gate)",
       %{ci: ci} do
    assert ci =~ "mix coveralls --slowest 20",
           "the gating unit step must stay `mix coveralls --slowest 20` — coveralls.json must NOT replace the gate (OBS-02)"
  end

  test "OBS-02: test_helper.exs wires JUnitFormatter CI-gated, mkdir_p's the report dir, and binds report_dir to _build/test/junit",
       %{test_helper: test_helper} do
    assert test_helper =~ "JUnitFormatter",
           "test_helper.exs must add JUnitFormatter to the formatters list (OBS-02)"

    assert test_helper =~ ~s|System.get_env("CI")|,
           "the JUnit formatter wiring must be gated on `System.get_env(\"CI\")` so local runs stay quiet (OBS-02)"

    assert test_helper =~ "File.mkdir_p!",
           "test_helper.exs must `File.mkdir_p!` the junit report dir (junit_formatter does not create it) (OBS-02)"

    assert test_helper =~ ~s|"_build/test/junit"|,
           "the junit report_dir must be bound to `_build/test/junit` (deterministic, upload-friendly) (OBS-02)"
  end

  test "OBS-02: mix.exs carries junit_formatter as a TEST-ONLY dep so it cannot ship in the Hex package",
       %{mix_exs: mix_exs} do
    assert mix_exs =~ ~s({:junit_formatter, "~> 3.4", only: :test}),
           "mix.exs must declare `{:junit_formatter, \"~> 3.4\", only: :test}` — test-only scope keeps it out of the Hex package (OBS-02)"
  end

  # ------------------------------------------------------------------
  # OBS-03: read-only baseline collectors + committed baseline doc.
  # ------------------------------------------------------------------
  test "OBS-03: both baseline scripts exist and carry `set -euo pipefail`", %{
    collect_baseline: collect_baseline,
    check_required: check_required
  } do
    assert collect_baseline =~ "set -euo pipefail",
           "collect_ci_baseline.sh must run under `set -euo pipefail` (OBS-03)"

    assert check_required =~ "set -euo pipefail",
           "check_required_checks.sh must run under `set -euo pipefail` (OBS-03)"
  end

  test "OBS-03 READ-ONLY: NEITHER baseline script contains a branch-protection mutation verb (T-103-03 threat mitigation)",
       %{collect_baseline: collect_baseline, check_required: check_required} do
    # Mirror the SUMMARY's acceptance grep: no `gh api -X PUT|POST|PATCH|DELETE`
    # may appear in either collector — a write request would be a silent
    # gate-behavior change (threat T-103-03 / T-103-05).
    mutation = ~r/gh api -X (PUT|POST|PATCH|DELETE)/

    refute collect_baseline =~ mutation,
           "collect_ci_baseline.sh must be READ-ONLY — no `gh api -X PUT/POST/PATCH/DELETE` (T-103-03, OBS-03)"

    refute check_required =~ mutation,
           "check_required_checks.sh must be READ-ONLY — no `gh api -X PUT/POST/PATCH/DELETE` (T-103-03, OBS-03)"
  end

  test "OBS-03: collect_ci_baseline.sh reads the ci.yml runs endpoint and derives rerun from run_attempt",
       %{collect_baseline: collect_baseline} do
    assert collect_baseline =~ "actions/workflows/ci.yml/runs",
           "collect_ci_baseline.sh must read the `actions/workflows/ci.yml/runs` endpoint (OBS-03)"

    assert collect_baseline =~ "run_attempt",
           "collect_ci_baseline.sh must derive rerun rate from `run_attempt` (no native rerun_count field, OBS-03)"
  end

  test "OBS-03: check_required_checks.sh reads required_status_checks/.contexts and reuses the --print-expected single source",
       %{check_required: check_required} do
    assert check_required =~ "required_status_checks",
           "check_required_checks.sh must GET `/required_status_checks` (OBS-03)"

    assert check_required =~ ".contexts",
           "check_required_checks.sh must read the legacy flat `.contexts[]` verbatim names (OBS-03)"

    assert check_required =~ "print-expected",
           "check_required_checks.sh must reuse setup_branch_protection.sh `--print-expected` as the single source of truth (no re-encoded names, OBS-03)"
  end

  test "OBS-03: the committed internal baseline doc 103-BASELINE.md exists" do
    assert File.exists?(@baseline_doc_path),
           "103-BASELINE.md must be committed under .planning/milestones/v1.20-phases/103-observability-baseline/ (OBS-03)"
  end

  # ------------------------------------------------------------------
  # Block / scope isolators.
  # ------------------------------------------------------------------

  # `ci-observability:` job body, from its job key up to the next top-level
  # (2-space-indented) job key (`ci-script-tests:`).
  defp ci_observability_block(ci) do
    [_, after_key] = String.split(ci, "\n  ci-observability:\n", parts: 2)
    [block | _] = String.split(after_key, "\n  ci-script-tests:\n", parts: 2)
    block
  end

  # The WORKFLOW-level permissions block: the FIRST `permissions:` occurrence in
  # the file (declared before any job), isolated up to the next blank-line/`on:`/
  # job boundary so a later JOB-level `permissions:` is never scanned.
  defp workflow_level_permissions(ci) do
    [_, after_perms] = String.split(ci, "\npermissions:\n", parts: 2)
    # The workflow-level block sits at column 0/2 before the first 2-space job map;
    # take just the indented lines immediately following it.
    after_perms
    |> String.split("\n")
    |> Enum.take_while(fn line -> line == "" or String.starts_with?(line, "  ") end)
    |> Enum.join("\n")
  end

  defp count(haystack, needle) do
    haystack
    |> String.split(needle)
    |> length()
    |> Kernel.-(1)
  end
end
