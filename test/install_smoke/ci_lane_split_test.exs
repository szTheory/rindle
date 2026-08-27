defmodule Rindle.InstallSmoke.CiLaneSplitTest do
  @moduledoc """
  Phase 106 (Trigger Split + Matrix/Lane Refinement) LANE-topology regression
  lock. Mirrors the release_docs_parity_test / ci_cache_hygiene_test
  `setup_all` + `File.read!` `=~`/`refute =~` style so the trigger-split lane
  contract regresses inside the default `mix test` / `mix ci` suite (no exclude
  tag — same as the sibling install_smoke parity tests).

  ASSERTS CURRENT SHIPPED STATE. Phase 107 ran AFTER 106 and SHA-pinned every
  `uses:` + added job permissions, so NOTHING here asserts a mutable `@vX`
  action tag or any pre-107 detail — only the LANE topology facts (triggers,
  concurrency expression, the package-consumer lean/full split, the nightly
  lane placement, and the release-coupling invariants) that are true on disk
  right now. Every literal asserted below was grep-confirmed against the live
  files.

  Deliberately asserts SHIPPED artifacts ONLY (workflows, scripts, CONTRIBUTING).
  It does NOT couple to internal `.planning/` doc paths: those move when a
  milestone is archived (gsd-cleanup), which would break this suite for a
  non-shipped reason. LANE-04's substance is locked via the CONTRIBUTING.md
  trust/speed-label assertion below.

  Deliberately does NOT duplicate ci_cache_hygiene_test.exs: composite adoption
  counts, the cache-key schema, .tool-versions, ffmpeg, and the PLT
  restore/save *split* (CACHE-03) are owned there. This file owns LANE
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
  @contributing_path Path.expand("../../CONTRIBUTING.md", __DIR__)
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
  @phase_132_projection_path Path.expand(
                               "../fixtures/ci_timing/phase_132_topology_projection.json",
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
       contributing: File.read!(@contributing_path)
     }}
  end

  # ------------------------------------------------------------------
  # LANE-01: concurrency — stale PR runs cancel; push:main/dispatch serialize.
  # ------------------------------------------------------------------
  test "LANE-01: ci.yml has a top-level concurrency block keyed on workflow + ref", %{ci: ci} do
    assert ci =~ "concurrency:",
           "ci.yml must declare a top-level concurrency block (LANE-01)"

    assert ci =~ "group: ${{ github.workflow }}-${{ github.ref }}",
           "concurrency group must key on github.workflow + github.ref so each ref serializes independently (LANE-01)"
  end

  test "LANE-01: cancel-in-progress is true ONLY for pull_request events", %{ci: ci} do
    # The exact shipped expression: cancellation fires on PR, evaluates false on
    # push:main / workflow_dispatch (which then SERIALIZE and are never cancelled —
    # load-bearing for release.yml gate-ci-green reading the push:main conclusion).
    assert ci =~
             "cancel-in-progress: ${{ github.event_name == 'pull_request' }}",
           "cancel-in-progress must be true ONLY for pull_request — push:main/dispatch must never cancel (LANE-01)"

    # Guard against the D-06 footgun: a bare `cancel-in-progress: true` would
    # cancel push:main runs and destroy the full-matrix release evidence.
    refute ci =~ "cancel-in-progress: true",
           "cancel-in-progress must NOT be an unconditional `true` (would cancel push:main runs, D-06 footgun, LANE-01)"
  end

  # ------------------------------------------------------------------
  # LANE-02: package-consumer lean (PR) + package-consumer-full (off-PR) split.
  # ------------------------------------------------------------------
  test "LANE-02: both the lean package-consumer and the off-PR package-consumer-full jobs exist",
       %{ci: ci} do
    assert ci =~ "\n  package-consumer:\n",
           "the lean PR `package-consumer` job must exist (LANE-02)"

    assert ci =~ "\n  package-consumer-full:\n",
           "the off-PR `package-consumer-full` job must exist (LANE-02)"
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

  test "LANE-02: package-consumer-full is off-PR (event gate) with a fail-fast:false 5-profile matrix and NO continue-on-error",
       %{ci: ci} do
    full = package_consumer_full_block(ci)

    assert full =~ "if: github.event_name != 'pull_request'",
           "package-consumer-full must be gated `if: github.event_name != 'pull_request'` to stay off the PR critical path (LANE-02)"

    assert full =~ "fail-fast: false",
           "package-consumer-full matrix must be `fail-fast: false` so one red profile never masks the others (LANE-02)"

    assert full =~ "profile: [video, image, tus, mux, gcs]",
           "package-consumer-full must carry the full 5-profile matrix video/image/tus/mux/gcs (LANE-02)"

    refute yaml_keys_only(full) =~ "continue-on-error",
           "package-consumer-full must have NO continue-on-error key — a failed leg must make the push:main conclusion non-success so the release gate blocks (LANE-02, D-08)"
  end

  test "LANE-02: ci-summary needs the lean package-consumer but OMITS package-consumer-full (D-09)",
       %{ci: ci} do
    needs = ci_summary_needs_block(ci)

    assert needs =~ "- package-consumer\n",
           "ci-summary.needs must include the lean `package-consumer` (the always-running PR representative, LANE-02)"

    refute needs =~ "package-consumer-full",
           "ci-summary.needs must OMIT `package-consumer-full` — it is `if: != pull_request`, so listing it would emit a green-checkmark lie about a skipped lane (D-09, LANE-02)"
  end

  # ------------------------------------------------------------------
  # GATE-01 / GATE-04 (Phase 112): the lean `adoption-demo-e2e-smoke` PR-side
  # browser-render proxy is wired into the merge gate transitively via
  # `CI Summary`. These assert SHIPPED ci.yml topology ONLY (no `.planning/`
  # path, no mutable `@vX` tag): the job exists, runs on EVERY PR (no repo/event
  # `if:` gate, so it never skips-as-pass), carries the deterministic 2-spec
  # subset (excluding the screenshot spec), and is present in BOTH
  # `ci-summary.needs` and `ci-observability.needs`.
  # ------------------------------------------------------------------
  test "GATE-01: the adoption-demo-e2e-smoke job exists in ci.yml", %{ci: ci} do
    assert ci =~ "\n  adoption-demo-e2e-smoke:\n",
           "the lean PR `adoption-demo-e2e-smoke` browser-render proxy job must exist (GATE-01)"
  end

  test "GATE-01: the smoke job runs on EVERY PR (no repo/event if: gate) with the 2-spec subset, screenshot spec excluded",
       %{ci: ci} do
    smoke = adoption_demo_e2e_smoke_block(ci)

    # No repo/event gate — a gated lane would resolve to `skipped` on forks and
    # skip==pass would emit a green lie for the exact regression class this lane
    # exists to catch (T-112-02, GATE-01).
    refute smoke =~ "if: github.repository",
           "the smoke job must have NO `if: github.repository` gate — it must run on every PR incl forks (skip==pass safety, GATE-01)"

    refute smoke =~ "github.event_name != 'pull_request'",
           "the smoke job must have NO event gate — it must never be skipped on a PR (skip==pass safety, GATE-01)"

    assert smoke =~ ~s(ADOPTION_DEMO_E2E_SPECS:),
           "the smoke job must set ADOPTION_DEMO_E2E_SPECS to scope the lean run (GATE-01)"

    assert smoke =~ "e2e/smoke.spec.js e2e/admin-console.spec.js",
           "ADOPTION_DEMO_E2E_SPECS must be the deterministic 2-spec subset smoke + admin-console (GATE-01)"

    refute smoke =~ "admin-screenshots.spec.js",
           "the smoke job must EXCLUDE the screenshot spec — it is not a browser-render regression check (GATE-01)"
  end

  test "GATE-01/GATE-04: the smoke lane is present in BOTH ci-summary.needs and ci-observability.needs",
       %{ci: ci} do
    summary_needs = ci_summary_needs_block(ci)
    observability_needs = ci_observability_needs_block(ci)

    assert summary_needs =~ "- adoption-demo-e2e-smoke\n",
           "ci-summary.needs must include `adoption-demo-e2e-smoke` — the lane is merge-blocking transitively via CI Summary (GATE-01/GATE-04)"

    assert observability_needs =~ "- adoption-demo-e2e-smoke\n",
           "ci-observability.needs must include `adoption-demo-e2e-smoke` for timing parity with the gate (GATE-01/GATE-04)"
  end

  @tag :phase_132_topology_recovery
  test "D-08 exact six-edge topology", %{ci: ci} do
    for job <- ["integration", "contract", "adoption-demo-e2e-smoke"] do
      assert job_needs(ci, job) == [],
             "#{job} must have no prerequisites: D-08 removes only quality and optional-dependencies"
    end
  end

  @tag :phase_132_topology_recovery
  test "phase 132 D-09 freezes affected job authorities and the required aggregation graph", %{
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
      assert job_block(ci, job) =~ token, "#{job} must retain #{inspect(token)} (D-09)"
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

  @tag :phase_132_topology_recovery
  test "phase 132 deterministic topology projection is source-attributed and non-accepting" do
    fixture = @phase_132_projection_path |> File.read!() |> Jason.decode!()
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
  # LANE-03: nightly.yml lane placement (invisible to release-please-automerge).
  # ------------------------------------------------------------------
  test "LANE-03: nightly.yml is a separate `name: Nightly` workflow with schedule + dispatch and NO pull_request/push triggers",
       %{nightly: nightly} do
    assert nightly =~ "name: Nightly",
           "nightly.yml must be `name: Nightly` (a separate workflow id, invisible to release-please-automerge workflows:[CI], LANE-03)"

    assert nightly =~ "schedule:",
           "nightly.yml must carry a `schedule:` trigger (LANE-03)"

    assert nightly =~ "cron:",
           "nightly.yml schedule must declare a cron expression (LANE-03)"

    assert nightly =~ "workflow_dispatch:",
           "nightly.yml must allow manual workflow_dispatch (LANE-03)"

    # Structural invisibility to release consumers: a pull_request OR push
    # trigger would re-expose the nightly lane to the release/automerge train.
    refute nightly =~ "pull_request",
           "nightly.yml must have NO pull_request trigger — it must never become a PR-required check (LANE-03, D-12)"

    refute nightly =~ "push:",
           "nightly.yml must have NO push trigger — a `CI`/push run would fire release-please-automerge (LANE-03, D-12)"
  end

  test "LANE-03: nightly.yml carries the broad OTP×Elixir compat matrix (multiple cells)", %{
    nightly: nightly
  } do
    assert nightly =~ "compat-matrix:",
           "nightly.yml must declare the broad compat-matrix job (LANE-03)"

    # Multiple cells straddling the OTP-27 json_polyfill branch. OTP 25 is not a
    # supported cell because the current JOSE dependency requires OTP 26+.
    for cell <- [
          ~s(elixir: "1.15"),
          ~s(otp: "26"),
          ~s(elixir: "1.18"),
          ~s(otp: "28")
        ] do
      assert nightly =~ cell,
             "compat-matrix must include the #{inspect(cell)} cell (broad OTP×Elixir breadth, LANE-03)"
    end

    refute nightly =~ ~s(otp: "25"),
           "compat-matrix must not claim the unsupported OTP 25 toolchain (LANE-03)"
  end

  test "LANE-03: the owned nightly Dialyzer job runs gating (no continue-on-error YAML key in its block)",
       %{nightly: nightly} do
    dialyzer = nightly_dialyzer_block(nightly)

    assert dialyzer =~ "mix dialyzer",
           "the nightly Dialyzer job must actually run `mix dialyzer` (LANE-03, D-17)"

    # Scope to actual YAML keys, not the `# ... NO continue-on-error` doc comment
    # that legitimately appears inside the block (the verifier flagged these 5
    # grep hits as comment text, not keys). Strip comment lines, then refute the
    # real key in any form.
    refute yaml_keys_only(dialyzer) =~ "continue-on-error",
           "the nightly Dialyzer job must have NO continue-on-error key — it is the owned GATING type-contract signal (LANE-03, D-17)"
  end

  test "LANE-03: probabilistic :epipe stress is bounded and advisory-only", %{
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

  test "LANE-03: the moved gcs-soak + package-consumer-gcs-live jobs live in nightly.yml, not ci.yml",
       %{nightly: nightly, ci: ci} do
    assert nightly =~ "gcs-soak:",
           "gcs-soak must live in nightly.yml (moved off ci.yml by Phase 106, LANE-03/D-14)"

    assert nightly =~ "package-consumer-gcs-live:",
           "package-consumer-gcs-live must live in nightly.yml (moved off ci.yml by Phase 106, LANE-03/D-14)"

    refute ci =~ "gcs-soak:",
           "gcs-soak must NOT remain a job in ci.yml — it was moved to nightly.yml (LANE-03/D-14)"

    refute ci =~ "package-consumer-gcs-live:",
           "package-consumer-gcs-live must NOT remain a job in ci.yml — it was moved to nightly.yml (LANE-03/D-14)"
  end

  test "LANE-03: nightly-failure-issue declares least-privilege permissions (issues: write only)",
       %{nightly: nightly} do
    issue_job = nightly_failure_issue_block(nightly)

    assert issue_job =~ "permissions:",
           "nightly-failure-issue must declare a job-scoped permissions block (least privilege, LANE-03/D-16)"

    assert issue_job =~ "issues: write",
           "nightly-failure-issue must grant `issues: write` to open/update the tracking issue (LANE-03/D-16)"

    refute issue_job =~ "contents: write",
           "nightly-failure-issue must NOT grant contents: write — least privilege, it cannot push code (LANE-03/D-16)"
  end

  # ------------------------------------------------------------------
  # LANE-04: trust/speed label in CONTRIBUTING (shipped artifact). The internal
  # A–E classification doc (106-LANE-CLASSIFICATION.md) is intentionally NOT
  # asserted here — it is an archived planning artifact, not shipped code.
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
             "CONTRIBUTING.md trust/speed label must contain #{inspect(phrase)} (LANE-04)"
    end
  end

  # ------------------------------------------------------------------
  # RELEASE-COUPLING INVARIANT (supports LANE SC5): a future lane edit must not
  # silently break the release train.
  # ------------------------------------------------------------------
  test "RELEASE-COUPLING: ci.yml line 1 is `name: CI` (release-train coupling)", %{ci: ci} do
    [first_line | _] = String.split(ci, "\n", parts: 2)

    assert first_line == "name: CI",
           "ci.yml line 1 must be exactly `name: CI` — release-please-automerge workflows:[CI] + release.yml gate-ci-green couple on it (SC5)"
  end

  test "RELEASE-COUPLING: setup_branch_protection.sh requires exactly one check — `CI Summary`",
       %{branch_protection: branch_protection} do
    # Isolate the REQUIRED_CHECKS=( ... ) array and assert it has exactly one
    # entry, `CI Summary`. The string also appears in the print-expected heredoc,
    # so scope to the array to avoid a false multi-count.
    [_, after_open] = String.split(branch_protection, "REQUIRED_CHECKS=(\n", parts: 2)
    [array_body | _] = String.split(after_open, ")", parts: 2)

    entries =
      array_body
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    assert entries == ["\"CI Summary\""],
           "REQUIRED_CHECKS must be exactly one entry, \"CI Summary\" — got #{inspect(entries)} (SC5)"
  end

  test "RELEASE-COUPLING: automerge listens on the `CI` workflow and release.yml gate reads `ci.yml`",
       %{automerge: automerge, release: release} do
    # release-please-automerge.yml workflow_run listener keys on the `CI`
    # workflow name (which is ci.yml's `name: CI`).
    assert automerge =~ "workflows:\n      - CI",
           "release-please-automerge.yml must listen on the `CI` workflow (couples to ci.yml `name: CI`, SC5)"

    assert automerge =~ "workflow_dispatch:",
           "release-please-automerge.yml must retain a manual recovery seam for an already-green release PR"

    assert automerge =~
             "github.event.workflow_run.head_branch == 'release-please--branches--main--components--rindle'",
           "automerge must react to successful CI on the canonical Release Please PR branch"

    refute automerge =~ "github.event.workflow_run.head_branch == 'main'",
           "pull-request CI reports the PR head branch, so a main-only condition permanently skips automerge"

    # release.yml gate-ci-green reads the ci.yml run conclusion by workflow_id.
    assert release =~ "workflow_id: 'ci.yml'",
           "release.yml gate-ci-green must read the ci.yml run by `workflow_id: 'ci.yml'` (SC5)"
  end

  # ------------------------------------------------------------------
  # Block isolators — scope `refute` assertions to a single job's YAML so a
  # legitimate occurrence elsewhere never produces a false pass/fail.
  # ------------------------------------------------------------------

  defp job_block(ci, job) do
    [_, block] = Regex.run(~r/\n  #{Regex.escape(job)}:\n(.*?)(?=\n  [a-z][a-z0-9-]*:\n|\z)/s, ci)
    block
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
