Code.require_file("../../scripts/maintainer/readiness_workflow.exs", __DIR__)

defmodule Rindle.InstallSmoke.CiLaneSplitTest do
  @moduledoc """
  CI lane-topology regression lock (trigger split, matrix and lane
  placement). Mirrors the release_docs_parity_test / ci_cache_hygiene_test
  `setup_all` + `File.read!` `=~`/`refute =~` style so the trigger-split lane
  contract regresses inside the default `mix test` / `mix ci` suite (no exclude
  tag — same as the sibling install_smoke parity tests).

  ASSERTS CURRENT SHIPPED STATE. Every `uses:` is SHA-pinned and jobs carry
  explicit permissions, so NOTHING here asserts a mutable `@vX` action tag —
  only the lane topology facts (triggers,
  concurrency expression, the package-consumer lean/full split, the nightly
  lane placement, and the release-coupling invariants) that are true on disk
  right now. Every literal asserted below was grep-confirmed against the live
  files.

  Deliberately asserts SHIPPED artifacts ONLY (workflows, scripts, CONTRIBUTING).
  It does NOT couple to internal planning doc paths: those move when a
  milestone is archived (gsd-cleanup), which would break this suite for a
  non-shipped reason. The PR feedback contract is locked via the
  CONTRIBUTING.md trust/speed-label assertion below.

  Deliberately does NOT duplicate ci_cache_hygiene_test.exs: composite adoption
  counts, the cache-key schema, .tool-versions, ffmpeg, and the PLT
  restore/save *split* are owned there. This file owns LANE
  *placement* only.
  """
  use ExUnit.Case, async: true

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @nightly_path Path.expand("../../.github/workflows/nightly.yml", __DIR__)
  @release_path Path.expand("../../.github/workflows/release.yml", __DIR__)
  @epipe_regression_path Path.expand("../rindle/av/subprocess_epipe_test.exs", __DIR__)
  @automerge_path Path.expand(
                    "../../.github/workflows/release-please-automerge.yml",
                    __DIR__
                  )
  @branch_protection_path Path.expand("../../scripts/setup_branch_protection.sh", __DIR__)
  @required_checks_policy_path Path.expand("../../config/ci_required_checks.json", __DIR__)
  @contributing_path Path.expand("../../CONTRIBUTING.md", __DIR__)
  @running_path Path.expand("../../RUNNING.md", __DIR__)
  @required_summary_needs [
    "quality",
    "optional-dependencies",
    "integration",
    "contract",
    "proof",
    "package-consumer",
    "adoption-demo-unit",
    "adoption-demo-e2e-smoke",
    "adopter",
    "brandbook-tokens",
    "ci-script-tests"
  ]
  @topology_projection_path Path.expand(
                              "../fixtures/ci_timing/topology_projection.json",
                              __DIR__
                            )

  setup_all do
    {:ok,
     %{
       ci: File.read!(@ci_path),
       nightly: File.read!(@nightly_path),
       epipe_regression: File.read!(@epipe_regression_path),
       release: File.read!(@release_path),
       automerge: File.read!(@automerge_path),
       branch_protection: File.read!(@branch_protection_path),
       required_checks_policy: @required_checks_policy_path |> File.read!() |> Jason.decode!(),
       contributing: File.read!(@contributing_path),
       running: File.read!(@running_path)
     }}
  end

  # ------------------------------------------------------------------
  # Concurrency — open PRs supersede; merged PR labels cannot cancel main.
  # ------------------------------------------------------------------
  test "PR numbers isolate merged PR label events from the main ref group", %{ci: ci} do
    assert ci =~ "concurrency:",
           "ci.yml must declare a top-level concurrency block"

    assert ci =~
             "group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && format('pr-{0}', github.event.pull_request.number) || format('ref-{0}', github.ref) }}",
           "PR identity must precede ref; the ref- namespace must also isolate main from historical PR workflows"
  end

  test "only open PRs cancel; main pushes and manual main runs serialize", %{ci: ci} do
    # Release automation labels merged PRs after publication. They must neither
    # share main's group nor request cancellation inside their own PR group.
    assert ci =~
             "cancel-in-progress: ${{ github.event_name == 'pull_request' && github.event.pull_request.state == 'open' }}",
           "only open pull_request events may cancel earlier runs"

    # Guard against the footgun: a bare `cancel-in-progress: true` would
    # cancel push:main runs and destroy the full-matrix release evidence.
    refute ci =~ "cancel-in-progress: true",
           "cancel-in-progress must NOT be an unconditional `true` (would cancel push:main runs)"
  end

  # ------------------------------------------------------------------
  # Package-consumer lean (PR) + package-consumer-full (off-PR) split.
  # ------------------------------------------------------------------
  test "both the lean package-consumer and the off-PR package-consumer-full jobs exist",
       %{ci: ci} do
    assert ci =~ "\n  package-consumer:\n",
           "the lean PR `package-consumer` job must exist"

    assert ci =~ "\n  package-consumer-full:\n",
           "the off-PR `package-consumer-full` job must exist"
  end

  test "the required image consumer starts independently and carries only image prerequisites",
       %{ci: ci} do
    consumer = package_consumer_block(ci)

    refute yaml_keys_only(consumer) =~ "needs:"
    refute consumer =~ "name: Set up Node"
    refute consumer =~ "name: Set up FFmpeg"
    assert consumer =~ "name: Install libvips"
    assert consumer =~ "bash scripts/install_smoke.sh image"
    assert consumer =~ "mix run --no-start --no-compile"
  end

  test "package-consumer-full is off-PR (event gate) with a fail-fast:false 5-profile matrix and NO continue-on-error",
       %{ci: ci} do
    full = package_consumer_full_block(ci)

    assert full =~ "if: github.event_name != 'pull_request'",
           "package-consumer-full must be gated `if: github.event_name != 'pull_request'` to stay off the PR critical path"

    assert full =~ "fail-fast: false",
           "package-consumer-full matrix must be `fail-fast: false` so one red profile never masks the others"

    assert full =~ "profile: [video, image, tus, mux, gcs]",
           "package-consumer-full must carry the full 5-profile matrix video/image/tus/mux/gcs"

    refute yaml_keys_only(full) =~ "continue-on-error",
           "package-consumer-full must have NO continue-on-error key — a failed leg must make the push:main conclusion non-success so the release gate blocks"
  end

  @tag :tmp_dir
  @tag :docs_truth_guard
  test "docs truth accepts valid current wording and scopes historical Rambo text", %{
    ci: ci,
    tmp_dir: dir
  } do
    valid = "MuonTrap is the sole subprocess runner on every platform\nparent-death subprocess\n"

    for {name, content} <- [{"valid", valid}, {"historical", "Rambo on macOS\n" <> valid}] do
      assert {output, 0} = run_docs_truth_fixture(ci, Path.join(dir, name), content)
      assert output =~ "TRUTH-01-OK"
    end
  end

  @tag :tmp_dir
  @tag :docs_truth_guard
  test "docs truth rejects missing and forbidden invariant wording", %{ci: ci, tmp_dir: dir} do
    valid = "MuonTrap is the sole subprocess runner on every platform\nparent-death subprocess\n"

    for {name, content} <- [
          {"missing-file", nil},
          {"missing-positive", "parent-death subprocess\n"},
          {"missing-region", "MuonTrap is the sole subprocess runner on every platform\n"},
          {"deprecated-combination", valid <> "FFmpex + MuonTrap\n"},
          {"deprecated-runner", valid <> "Rambo on macOS\n"}
        ] do
      {output, status} = run_docs_truth_fixture(ci, Path.join(dir, name), content)
      refute status == 0, "guard accepted #{name}: #{output}"
      refute output =~ "TRUTH-01-OK"
    end
  end

  @tag :tmp_dir
  @tag :docs_truth_guard
  test "docs truth fails closed on each grep read error", %{ci: ci, tmp_dir: dir} do
    valid = "MuonTrap is the sole subprocess runner on every platform\nparent-death subprocess\n"

    for {pattern, index} <-
          Enum.with_index([
            "MuonTrap is the sole subprocess runner on every platform",
            "FFmpex + MuonTrap",
            "parent-death subprocess",
            "Rambo on macOS"
          ]) do
      {output, status} =
        run_docs_truth_fixture(ci, Path.join(dir, Integer.to_string(index)), valid, pattern)

      refute status == 0, "guard ignored grep error for #{pattern}: #{output}"
      refute output =~ "TRUTH-01-OK"
    end
  end

  test "common preflight runs on exactly one full-matrix profile", %{ci: ci} do
    {profiles, preflight, consumer} = full_matrix_commands(ci)
    assert profiles == ["video", "image", "tus", "mux", "gcs"]
    assert preflight["run"] == "bash scripts/release_preflight.sh"
    assert consumer["run"] == "bash scripts/install_smoke.sh ${{ matrix.profile }}"
    assert Enum.filter(profiles, &preflight_applies?(preflight, &1)) == ["image"]

    {results, calls} = execute_matrix_fixture(profiles, preflight, consumer, "none")
    assert Enum.all?(results, fn {_profile, status} -> status == 0 end)
    assert Enum.count(calls, &(&1 == "preflight")) == 1
    assert Enum.sort(Enum.reject(calls, &(&1 == "preflight"))) == Enum.sort(profiles)
  end

  test "preflight and every profile failure keep the full main workflow non-green", %{ci: ci} do
    {profiles, preflight, consumer} = full_matrix_commands(ci)

    for failure <- ["preflight" | profiles] do
      {results, calls} = execute_matrix_fixture(profiles, preflight, consumer, failure)
      failed_profile = if failure == "preflight", do: "image", else: failure

      assert Enum.filter(results, fn {_profile, status} -> status != 0 end) == [
               {failed_profile, 1}
             ]

      assert Enum.count(calls, &(&1 == "preflight")) == 1
      if failure == "preflight", do: refute("image" in calls)
    end
  end

  test "ci-summary needs the lean package-consumer but OMITS package-consumer-full",
       %{ci: ci} do
    needs = ci_summary_needs_block(ci)

    assert needs =~ "- package-consumer\n",
           "ci-summary.needs must include the lean `package-consumer` (the always-running PR representative)"

    refute needs =~ "package-consumer-full",
           "ci-summary.needs must OMIT `package-consumer-full` — it is `if: != pull_request`, so listing it would emit a green-checkmark lie about a skipped lane"
  end

  # ------------------------------------------------------------------
  # The lean `adoption-demo-e2e-smoke` PR-side browser-render proxy is wired
  # into the merge gate transitively via `CI Summary`. These assert SHIPPED
  # ci.yml topology ONLY (no planning doc path, no mutable `@vX` tag): the job exists, runs on EVERY PR (no repo/event
  # `if:` gate, so it never skips-as-pass), carries the deterministic 2-spec
  # subset (excluding the screenshot spec), and is present in BOTH
  # `ci-summary.needs` and `ci-observability.needs`.
  # ------------------------------------------------------------------
  test "the adoption-demo-e2e-smoke job exists in ci.yml", %{ci: ci} do
    assert ci =~ "\n  adoption-demo-e2e-smoke:\n",
           "the lean PR `adoption-demo-e2e-smoke` browser-render proxy job must exist"
  end

  test "the smoke job runs on EVERY PR (no repo/event if: gate) with the 2-spec subset, screenshot spec excluded",
       %{ci: ci} do
    smoke = adoption_demo_e2e_smoke_block(ci)

    # No repo/event gate — a gated lane would resolve to `skipped` on forks and
    # skip==pass would emit a green lie for the exact regression class this lane
    # exists to catch.
    refute smoke =~ "if: github.repository",
           "the smoke job must have NO `if: github.repository` gate — it must run on every PR incl forks (skip==pass safety)"

    refute smoke =~ "github.event_name != 'pull_request'",
           "the smoke job must have NO event gate — it must never be skipped on a PR (skip==pass safety)"

    assert smoke =~ ~s(ADOPTION_DEMO_E2E_SPECS:),
           "the smoke job must set ADOPTION_DEMO_E2E_SPECS to scope the lean run"

    assert smoke =~ "e2e/smoke.spec.js e2e/admin-console.spec.js",
           "ADOPTION_DEMO_E2E_SPECS must be the deterministic 2-spec subset smoke + admin-console"

    refute smoke =~ "admin-screenshots.spec.js",
           "the smoke job must EXCLUDE the screenshot spec — it is not a browser-render regression check"
  end

  test "the smoke lane is present in BOTH ci-summary.needs and ci-observability.needs",
       %{ci: ci} do
    summary_needs = ci_summary_needs_block(ci)
    observability_needs = ci_observability_needs_block(ci)

    assert summary_needs =~ "- adoption-demo-e2e-smoke\n",
           "ci-summary.needs must include `adoption-demo-e2e-smoke` — the lane is merge-blocking transitively via CI Summary"

    assert observability_needs =~ "- adoption-demo-e2e-smoke\n",
           "ci-observability.needs must include `adoption-demo-e2e-smoke` for timing parity with the gate"
  end

  @tag :required_job_topology
  test "integration, contract and the e2e smoke lane have no prerequisites", %{ci: ci} do
    for job <- ["integration", "contract", "adoption-demo-e2e-smoke"] do
      assert job_needs(ci, job) == [],
             "#{job} must have no prerequisites: it must not wait on quality or optional-dependencies"
    end
  end

  @tag :required_job_topology
  test "RUNNING.md and ci.yml document the three independent required jobs in present tense", %{
    ci: ci,
    running: running
  } do
    for job <- ["integration", "contract", "adoption-demo-e2e-smoke"] do
      assert job_needs(ci, job) == []

      row =
        running
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "| `#{job}`"))

      assert row, "RUNNING.md must document the #{job} lane"
      assert row =~ "Starts independently" or row =~ "starts independently"
      refute row =~ "needs: [quality, optional-dependencies]"
    end

    smoke = adoption_demo_e2e_smoke_block(ci)
    refute smoke =~ "NOT YET WIRED"
    assert smoke =~ "wired into both ci-summary.needs and ci-observability.needs"

    contract = job_block(ci, "contract")
    refute contract =~ "`needs: quality` waits"
    assert contract =~ "Starts independently from the quality matrix"
  end

  @tag :required_job_topology
  test "Proof overlaps Quality and both remain required by the final gate", %{ci: ci} do
    assert job_needs(ci, "proof") == ["optional-dependencies"]
    assert "proof" in job_needs(ci, "ci-summary")
    assert "quality" in job_needs(ci, "ci-summary")
    assert job_block(ci, "ci-summary") =~ "if: always()"
    refute job_block(ci, "proof") =~ "continue-on-error: true"
  end

  @tag :required_job_topology
  test "required jobs keep their runner authorities and the aggregation graph", %{
    ci: ci
  } do
    for {job, tokens} <- [
          {"integration",
           [
             "runs-on: ubuntu-22.04",
             "postgres:",
             "actions/checkout@",
             "setup-elixir",
             "mix deps.get",
             "mix test"
           ]},
          {"contract",
           [
             "runs-on: ubuntu-22.04",
             "postgres:",
             "actions/checkout@",
             "setup-elixir",
             "mix deps.get",
             "mix test"
           ]},
          {"adoption-demo-e2e-smoke",
           [
             "runs-on: ubuntu-22.04",
             "postgres:",
             "actions/checkout@",
             "setup-elixir",
             "mix deps.get",
             "ADOPTION_DEMO_E2E_SPECS"
           ]}
        ],
        token <- tokens do
      assert job_block(ci, job) =~ token, "#{job} must retain #{inspect(token)}"
    end

    assert job_needs(ci, "adopter") == [
             "quality",
             "optional-dependencies",
             "integration",
             "contract"
           ]

    assert job_needs(ci, "ci-summary") == @required_summary_needs
    assert job_needs(ci, "ci-observability") == Enum.drop(@required_summary_needs, -1)
    assert job_block(ci, "ci-summary") =~ "name: CI Summary"
    assert job_block(ci, "ci-summary") =~ "if: always()"
    assert job_block(ci, "ci-summary") =~ "run: bash scripts/ci/eval_ci_summary.sh"
  end

  @tag :required_job_topology
  test "the deterministic topology projection is source-attributed and non-accepting" do
    fixture = @topology_projection_path |> File.read!() |> Jason.decode!()
    runs = fixture["runs"]

    assert fixture["immutable_head"] == "394550944bbff63c0e61c258528c8f8764298745"

    assert Enum.map(runs, & &1["id"]) == [
             33_003_369_940,
             33_004_281_315,
             33_005_105_221,
             33_005_882_907,
             33_006_773_326
           ]

    assert Enum.sort(Enum.map(runs, & &1["baseline_seconds"])) == [510, 548, 591, 592, 612]
    assert median(runs, "baseline_seconds") == 591
    assert nearest_rank_p95(runs, "baseline_seconds") == 612
    assert median(runs, "partial_seconds") == 486
    assert median(runs, "exact_seconds") < 480
    assert Enum.all?(runs, &(&1["exact_seconds"] < &1["partial_seconds"]))
    assert fixture["acceptance_note"] =~ "CI-14 acceptance requires"
  end

  # ------------------------------------------------------------------
  # nightly.yml lane placement (invisible to release-please-automerge).
  # ------------------------------------------------------------------
  test "nightly.yml is a separate `name: Nightly` workflow with schedule + dispatch and NO pull_request/push triggers",
       %{nightly: nightly} do
    assert nightly =~ "name: Nightly",
           "nightly.yml must be `name: Nightly` (a separate workflow id, invisible to release-please-automerge workflows:[CI])"

    assert nightly =~ "schedule:",
           "nightly.yml must carry a `schedule:` trigger"

    assert nightly =~ "cron:",
           "nightly.yml schedule must declare a cron expression"

    assert nightly =~ "workflow_dispatch:",
           "nightly.yml must allow manual workflow_dispatch"

    # Structural invisibility to release consumers: a pull_request OR push
    # trigger would re-expose the nightly lane to the release/automerge train.
    refute nightly =~ "pull_request",
           "nightly.yml must have NO pull_request trigger — it must never become a PR-required check"

    refute nightly =~ "push:",
           "nightly.yml must have NO push trigger — a `CI`/push run would fire release-please-automerge"
  end

  test "nightly.yml carries the broad OTP×Elixir compat matrix (multiple cells)", %{
    nightly: nightly
  } do
    assert nightly =~ "compat-matrix:",
           "nightly.yml must declare the broad compat-matrix job"

    # Multiple cells straddling the OTP-27 json_polyfill branch. OTP 25 is not a
    # supported cell because the current JOSE dependency requires OTP 26+.
    for cell <- [
          ~s(elixir: "1.15"),
          ~s(otp: "26"),
          ~s(elixir: "1.18"),
          ~s(otp: "28")
        ] do
      assert nightly =~ cell,
             "compat-matrix must include the #{inspect(cell)} cell (broad OTP×Elixir breadth)"
    end

    refute nightly =~ ~s(otp: "25"),
           "compat-matrix must not claim the unsupported OTP 25 toolchain"
  end

  test "the owned nightly Dialyzer job runs gating (no continue-on-error YAML key in its block)",
       %{nightly: nightly} do
    dialyzer = nightly_dialyzer_block(nightly)

    assert dialyzer =~ "bash scripts/ci/run_nightly_dialyzer.sh fresh",
           "the nightly Dialyzer job must run the owned fresh-PLT analyzer"

    assert dialyzer =~ "bash scripts/ci/run_nightly_dialyzer.sh restored",
           "the nightly Dialyzer job must run the owned restored-PLT analyzer"

    # Scope to actual YAML keys, not the `# ... NO continue-on-error` doc comment
    # that legitimately appears inside the block (the verifier flagged these 5
    # grep hits as comment text, not keys). Strip comment lines, then refute the
    # real key in any form.
    refute yaml_keys_only(dialyzer) =~ "continue-on-error",
           "the nightly Dialyzer job must have NO continue-on-error key — it is the owned GATING type-contract signal"
  end

  test "probabilistic :epipe stress is bounded and advisory-only", %{
    nightly: nightly,
    epipe_regression: epipe_regression
  } do
    assert epipe_regression =~ "@tag :canary"
    assert epipe_regression =~ "@tag timeout: 60_000"
    refute epipe_regression =~ "Process.flag(:trap_exit, true)"

    assert nightly =~ "test/rindle/av/subprocess_epipe_test.exs"
    assert nightly =~ "test/rindle/av/subprocess_epipe_canary_test.exs"
    assert nightly =~ "--include canary"
  end

  test "the gcs-soak + package-consumer-gcs-live jobs live in nightly.yml, not ci.yml",
       %{nightly: nightly, ci: ci} do
    assert nightly =~ "gcs-soak:",
           "gcs-soak must live in nightly.yml, not ci.yml"

    assert nightly =~ "package-consumer-gcs-live:",
           "package-consumer-gcs-live must live in nightly.yml, not ci.yml"

    refute ci =~ "gcs-soak:",
           "gcs-soak must NOT be a job in ci.yml — it runs in nightly.yml"

    refute ci =~ "package-consumer-gcs-live:",
           "package-consumer-gcs-live must NOT be a job in ci.yml — it runs in nightly.yml"
  end

  test "nightly-failure-issue declares least-privilege permissions (issues: write only)",
       %{nightly: nightly} do
    issue_job = nightly_failure_issue_block(nightly)

    assert issue_job =~ "permissions:",
           "nightly-failure-issue must declare a job-scoped permissions block (least privilege)"

    assert issue_job =~ "issues: write",
           "nightly-failure-issue must grant `issues: write` to open/update the tracking issue"

    refute issue_job =~ "contents: write",
           "nightly-failure-issue must NOT grant contents: write — least privilege, it cannot push code"
  end

  # ------------------------------------------------------------------
  # Trust/speed label in CONTRIBUTING (shipped artifact). The internal lane
  # classification doc is intentionally NOT asserted here — it is a planning
  # artifact, not shipped code.
  # ------------------------------------------------------------------
  test "CONTRIBUTING.md carries the current PR feedback target and proof split",
       %{contributing: contributing} do
    for phrase <- [
          "what CI runs on your PR versus after merge",
          "after merge",
          "≤8 minutes median",
          "≤10 minutes p95",
          "representative `image` package-consumer install-smoke",
          "caught on `main` within one merge"
        ] do
      assert contributing =~ phrase,
             "CONTRIBUTING.md trust/speed label must contain #{inspect(phrase)}"
    end
  end

  # ------------------------------------------------------------------
  # RELEASE-COUPLING INVARIANT: a future lane edit must not
  # silently break the release train.
  # ------------------------------------------------------------------
  test "RELEASE-COUPLING: ci.yml line 1 is `name: CI` (release-train coupling)", %{ci: ci} do
    [first_line | _] = String.split(ci, "\n", parts: 2)

    assert first_line == "name: CI",
           "ci.yml line 1 must be exactly `name: CI` — release-please-automerge workflows:[CI] + release.yml gate-ci-green couple on it"
  end

  test "RELEASE-COUPLING: setup_branch_protection.sh requires exactly one check — `CI Summary`",
       %{branch_protection: branch_protection, required_checks_policy: policy} do
    assert policy["contexts"] == ["CI Summary"],
           "required-check policy must contain only CI Summary — got #{inspect(policy["contexts"])}"

    assert branch_protection =~ "jq -r '.contexts[]' \"${POLICY_FILE}\"",
           "setup_branch_protection.sh must project required contexts from the policy"
  end

  test "RELEASE-COUPLING: automerge listens on the `CI` workflow and release.yml gate reads `ci.yml`",
       %{automerge: automerge, release: release} do
    # release-please-automerge.yml workflow_run listener keys on the `CI`
    # workflow name (which is ci.yml's `name: CI`).
    assert automerge =~ "workflows:\n      - CI",
           "release-please-automerge.yml must listen on the `CI` workflow (couples to ci.yml `name: CI`)"

    assert automerge =~ "workflow_dispatch:",
           "release-please-automerge.yml must retain a manual recovery seam for an already-green release PR"

    assert automerge =~
             "github.event.workflow_run.head_branch == 'release-please--branches--main--components--rindle'",
           "automerge must react to successful CI on the canonical Release Please PR branch"

    refute automerge =~ "github.event.workflow_run.head_branch == 'main'",
           "pull-request CI reports the PR head branch, so a main-only condition permanently skips automerge"

    # release.yml gate-ci-green reads the ci.yml run conclusion by workflow_id.
    assert release =~ "workflow_id: 'ci.yml'",
           "release.yml gate-ci-green must read the ci.yml run by `workflow_id: 'ci.yml'`"
  end

  # ------------------------------------------------------------------
  # Block isolators — scope `refute` assertions to a single job's YAML so a
  # legitimate occurrence elsewhere never produces a false pass/fail.
  # ------------------------------------------------------------------

  defp job_block(ci, job) do
    [_, block] = Regex.run(~r/\n  #{Regex.escape(job)}:\n(.*?)(?=\n  [a-z][a-z0-9-]*:\n|\z)/s, ci)
    block
  end

  # Read the shipped workflow; all planning paths below are owned temporary fixtures.
  defp run_docs_truth_fixture(ci, dir, content, grep_error \\ "") do
    {:ok, _} = Application.ensure_all_started(:yamerl)
    [workflow] = :yamerl_constr.string(ci, str_node_as_binary: true)
    get = fn fields, key -> fields |> List.keyfind(key, 0) |> elem(1) end

    [step] =
      workflow
      |> get.("jobs")
      |> get.("quality")
      |> get.("steps")
      |> Enum.map(&Map.new/1)
      |> Enum.filter(&(&1["name"] == "TRUTH-01 docs-truth guard (PROJECT.md invariant 13)"))

    refute Map.has_key?(step, "if")
    refute Map.has_key?(step, "continue-on-error")
    File.mkdir_p!(Path.join(dir, ".planning"))
    if content, do: File.write!(Path.join(dir, ".planning/PROJECT.md"), content)
    File.mkdir_p!(Path.join(dir, "bin"))
    grep = Path.join(dir, "bin/grep")

    File.write!(grep, ~S"""
    #!/usr/bin/env bash
    for arg in "$@"; do
      if [ -n "$GREP_ERROR_PATTERN" ] && [ "$arg" = "$GREP_ERROR_PATTERN" ]; then exit 2; fi
    done
    exec "$REAL_GREP" "$@"
    """)

    File.chmod!(grep, 0o700)

    System.cmd("bash", ["-e", "-o", "pipefail", "-c", Map.fetch!(step, "run")],
      cd: dir,
      env: [
        {"PATH", Path.join(dir, "bin") <> ":" <> System.fetch_env!("PATH")},
        {"REAL_GREP", System.find_executable("grep")},
        {"GREP_ERROR_PATTERN", grep_error}
      ],
      stderr_to_stdout: true
    )
  end

  defp full_matrix_commands(ci) do
    {:ok, _} = Application.ensure_all_started(:yamerl)
    [workflow] = :yamerl_constr.string(ci, str_node_as_binary: true)
    get = fn fields, key -> fields |> List.keyfind(key, 0) |> elem(1) end
    job = workflow |> get.("jobs") |> get.("package-consumer-full")
    profiles = job |> get.("strategy") |> get.("matrix") |> get.("profile")
    steps = get.(job, "steps") |> Enum.map(&Map.new/1)
    [preflight] = Enum.filter(steps, &(&1["name"] == "Run release preflight"))

    [consumer] =
      Enum.filter(
        steps,
        &(&1["name"] == "Run built-artifact package-consumer proof against MinIO")
      )

    assert Enum.find_index(steps, &(&1 == preflight)) < Enum.find_index(steps, &(&1 == consumer))
    refute Map.has_key?(preflight, "continue-on-error")
    refute Map.has_key?(consumer, "continue-on-error")
    refute Map.has_key?(consumer, "if")
    {profiles, preflight, consumer}
  end

  defp preflight_applies?(preflight, profile) do
    Rindle.ReadinessWorkflow.condition(Map.fetch!(preflight, "if"), %{"profile" => profile})
  end

  # Execute the actual workflow command strings against owned shell stand-ins.
  # This proves orchestration/failure propagation; package behavior stays in its real suites.
  defp execute_matrix_fixture(profiles, preflight, consumer, failure) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "rindle_preflight_matrix_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(dir, "scripts"))
    on_exit(fn -> File.rm_rf!(dir) end)
    trace = Path.join(dir, "calls")

    File.write!(
      Path.join(dir, "scripts/release_preflight.sh"),
      ~S(printf 'preflight\n' >> "$TRACE"; test "$FAILURE" != preflight)
    )

    File.write!(
      Path.join(dir, "scripts/install_smoke.sh"),
      ~S(printf '%s\n' "$1" >> "$TRACE"; test "$FAILURE" != "$1")
    )

    results =
      Enum.map(profiles, fn profile ->
        commands = if preflight_applies?(preflight, profile), do: [preflight["run"]], else: []
        commands = commands ++ [String.replace(consumer["run"], "${{ matrix.profile }}", profile)]

        {_, status} =
          System.cmd("bash", ["-euo", "pipefail", "-c", Enum.join(commands, "\n")],
            cd: dir,
            env: [{"TRACE", trace}, {"FAILURE", failure}],
            stderr_to_stdout: true
          )

        {profile, status}
      end)

    {results, trace |> File.read!() |> String.split("\n", trim: true)}
  end

  defp job_needs(ci, job) do
    job_block(ci, job)
    |> String.split("\n")
    |> Enum.find_value([], fn line ->
      case Regex.run(~r/^    needs: \[(.*)\]$/, line) do
        [_, members] -> String.split(members, ", ", trim: true)
        _ -> nil
      end
    end)
    |> case do
      [] ->
        job_block(ci, job)
        |> String.split("\n    needs:\n", parts: 2)
        |> case do
          [_, following] ->
            following
            |> String.split("\n    if:", parts: 2)
            |> hd()
            |> String.split("\n", trim: true)
            |> Enum.map(&(String.trim(&1) |> String.trim_leading("- ")))

          _ ->
            []
        end

      members ->
        members
    end
  end

  defp median(runs, key) do
    values = runs |> Enum.map(& &1[key]) |> Enum.sort()
    Enum.at(values, div(length(values), 2))
  end

  defp nearest_rank_p95(runs, key) do
    runs |> Enum.map(& &1[key]) |> Enum.sort() |> Enum.at(length(runs) - 1)
  end

  # `package-consumer-full:` job body, from its job key up to the next top-level
  # (2-space-indented) job key.
  defp package_consumer_full_block(ci) do
    [_, after_key] = String.split(ci, "\n  package-consumer-full:\n", parts: 2)
    [block | _] = String.split(after_key, "\n  adoption-demo-unit:\n", parts: 2)
    block
  end

  defp package_consumer_block(ci) do
    [_, after_key] = String.split(ci, "\n  package-consumer:\n", parts: 2)
    [block | _] = String.split(after_key, "\n  package-consumer-full:\n", parts: 2)
    block
  end

  # `ci-summary:` job — isolate its `needs:` list (up to the `if:`/`steps:` keys).
  defp ci_summary_needs_block(ci) do
    [_, after_key] = String.split(ci, "\n  ci-summary:\n", parts: 2)
    [_, after_needs] = String.split(after_key, "\n    needs:\n", parts: 2)
    [needs | _] = String.split(after_needs, "\n    if:", parts: 2)
    needs
  end

  # `ci-observability:` job — isolate its `needs:` list (up to the `if:` key).
  defp ci_observability_needs_block(ci) do
    [_, after_key] = String.split(ci, "\n  ci-observability:\n", parts: 2)
    [_, after_needs] = String.split(after_key, "\n    needs:\n", parts: 2)
    [needs | _] = String.split(after_needs, "\n    if:", parts: 2)
    needs
  end

  # `adoption-demo-e2e-smoke:` job body, from its job key up to the next
  # top-level (2-space-indented) job key (`adopter:`).
  defp adoption_demo_e2e_smoke_block(ci) do
    [_, after_key] = String.split(ci, "\n  adoption-demo-e2e-smoke:\n", parts: 2)
    [block | _] = String.split(after_key, "\n  adopter:\n", parts: 2)
    block
  end

  # nightly.yml `dialyzer:` job body, up to the next top-level job (`gcs-soak:`).
  defp nightly_dialyzer_block(nightly) do
    [_, after_key] = String.split(nightly, "\n  dialyzer:\n", parts: 2)
    [block | _] = String.split(after_key, "\n  gcs-soak:\n", parts: 2)
    block
  end

  # nightly.yml `nightly-failure-issue:` job body (last job — to EOF).
  defp nightly_failure_issue_block(nightly) do
    [_, block] = String.split(nightly, "\n  nightly-failure-issue:\n", parts: 2)
    block
  end

  # Drop full-line YAML comments (lines whose first non-space char is `#`) so a
  # `refute` over actual YAML keys is not tripped by documentation prose that
  # merely *names* a key it deliberately omits.
  defp yaml_keys_only(block) do
    block
    |> String.split("\n")
    |> Enum.reject(&(String.trim_leading(&1) |> String.starts_with?("#")))
    |> Enum.join("\n")
  end
end
