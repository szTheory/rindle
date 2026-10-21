defmodule Rindle.InstallSmoke.QualitySignalPolicyTest do
  use ExUnit.Case, async: false

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @mix_path Path.expand("../../mix.exs", __DIR__)
  @canonical_lint_condition "${{ matrix.lint }}"

  setup_all do
    {:ok, %{workflow: YamlElixir.read_from_file!(@ci_path), mix: File.read!(@mix_path)}}
  end

  @tag :tmp_dir
  test "Nightly proof harnesses overlap before any one completes", %{workflow: workflow, tmp_dir: dir} do
    script = step(workflow, "proof", "Run Nightly evidence harnesses")["run"]
    assert {_, 0} = run_nightly_harness_fixture(script, dir, true)
    assert length(File.ls!(Path.join(dir, "finished"))) == 4
  end

  @tag :tmp_dir
  test "Nightly proof waits for every harness and preserves each failure", %{
    workflow: workflow,
    tmp_dir: dir
  } do
    script = step(workflow, "proof", "Run Nightly evidence harnesses")["run"]

    for {name, index} <- Enum.with_index(nightly_harness_names()) do
      fixture = Path.join(dir, Integer.to_string(index))
      assert {_, status} = run_nightly_harness_fixture(script, fixture, false, name)
      refute status == 0
      assert Enum.sort(File.ls!(Path.join(fixture, "finished"))) == Enum.sort(nightly_harness_names())
    end
  end

  defp nightly_harness_names do
    ~w(test_nightly_dialyzer.sh test_nightly_summary_gate.sh test_nightly_incident.sh test_verify_nightly_run.sh)
  end

  defp run_nightly_harness_fixture(script, dir, barrier, failing \\ "") do
    File.mkdir_p!(Path.join(dir, "scripts/ci"))
    File.mkdir_p!(Path.join(dir, "started"))
    File.mkdir_p!(Path.join(dir, "finished"))

    for name <- nightly_harness_names() do
      File.write!(Path.join(dir, "scripts/ci/" <> name), ~S"""
      set -euo pipefail
      name="${0##*/}"
      touch "started/$name"
      if [ "$REQUIRE_OVERLAP" = true ]; then
        ready=false
        for attempt in {1..100}; do
          set -- started/*
          if [ "$#" -eq 4 ]; then ready=true; break; fi
          sleep 0.01
        done
        if [ "$ready" != true ]; then echo 'other harnesses never started'; exit 41; fi
      fi
      sleep 0.02
      touch "finished/$name"
      if [ "$name" = "$FAIL_HARNESS" ]; then exit 7; fi
      """)
    end

    System.cmd("bash", ["-e", "-o", "pipefail", "-c", script],
      cd: dir,
      env: [{"REQUIRE_OVERLAP", to_string(barrier)}, {"FAIL_HARNESS", failing}],
      stderr_to_stdout: true
    )
  end

  test "deterministic quality signals block through the existing Quality carrier", %{
    workflow: workflow
  } do
    assert_required_step!(
      workflow,
      "quality",
      "Credo quality",
      "bash scripts/maintainer/credo_quality.sh",
      @canonical_lint_condition
    )

    assert_required_step!(
      workflow,
      "quality",
      "Doctor (full, raise)",
      "MIX_ENV=dev mix doctor --full --raise",
      @canonical_lint_condition
    )

    assert_required_step!(
      workflow,
      "quality",
      "Run focused AV behavior tests",
      "mix test test/rindle/probe/av_probe_test.exs test/rindle/processor/image_test.exs --seed 0"
    )
  end

  test "focused AV proof follows its FFmpeg and libvips prerequisites", %{workflow: workflow} do
    names = workflow |> steps("quality") |> Enum.map(&Map.get(&1, "name"))

    assert index_of(names, "Install libvips") < index_of(names, "Run focused AV behavior tests")
    assert index_of(names, "Install FFmpeg") < index_of(names, "Run focused AV behavior tests")
  end

  test "runtime doctor and full-tree Credo style remain visible advisory checks", %{
    workflow: workflow
  } do
    assert step(workflow, "quality", "Verify AV runtime with public doctor task")[
             "continue-on-error"
           ]

    assert step(workflow, "quality", "Credo (strict, advisory style)")["continue-on-error"]
  end

  test "Quality runs mix hex.audit as an advisory step right after mix deps.audit", %{
    workflow: workflow
  } do
    names = workflow |> steps("quality") |> Enum.map(&Map.get(&1, "name"))
    hex_audit = step(workflow, "quality", "Audit Hex advisories (advisory)")

    assert hex_audit["run"] == "mix hex.audit"
    assert hex_audit["if"] == @canonical_lint_condition
    assert hex_audit["continue-on-error"] == true

    assert index_of(names, "Audit Hex advisories (advisory)") ==
             index_of(names, "Audit dependencies (advisory)") + 1
  end

  test "Contract carries deterministic contract tests and the preservation contract without masking",
       %{
         workflow: workflow
       } do
    contract_step_names = workflow |> steps("contract") |> Enum.map(&Map.get(&1, "name"))

    assert_required_step!(
      workflow,
      "contract",
      "Install FFmpeg",
      "bash scripts/ci/install_ffmpeg.sh"
    )

    assert index_of(contract_step_names, "Install FFmpeg") <
             index_of(contract_step_names, "Run contract tests")

    assert_required_step!(
      workflow,
      "contract",
      "Run contract tests",
      "mix test --only contract --seed 0"
    )

    assert_required_step!(
      workflow,
      "contract",
      "Run SAFE-01 preservation contract",
      "bash scripts/maintainer/refactor_contract.sh"
    )
  end

  test "the required CI and release topology remains unchanged", %{workflow: workflow} do
    summary = job(workflow, "ci-summary")

    assert workflow["name"] == "CI"
    assert summary["name"] == "CI Summary"
    assert "quality" in summary["needs"]
    assert "contract" in summary["needs"]

    assert step(workflow, "ci-summary", "Evaluate gating job results")["run"] ==
             "bash scripts/ci/eval_ci_summary.sh"

    refute "package-consumer-full" in summary["needs"]
  end

  test "required steps reject a false condition on the canonical matrix cell" do
    refute enabled_for_canonical_quality_cell?(%{"if" => "${{ false }}"})
  end

  test "local aliases run deterministic quality checks before one default suite", %{mix: mix} do
    assert mix =~ "refactor_contract: [\"cmd bash scripts/maintainer/refactor_contract.sh\"]"
    assert mix =~ "credo_quality: [\"cmd bash scripts/maintainer/credo_quality.sh\"]"
    assert mix =~ "quality_signals: ["
    assert mix =~ "\"cmd env MIX_ENV=dev mix doctor --full --raise\""

    ci = alias_block(mix, "ci")
    assert ci =~ "\"quality_signals\""

    assert index_of(String.split(ci, "\n"), "        \"quality_signals\",") <
             index_of(String.split(ci, "\n"), "        \"test\"")

    assert length(Regex.scan(~r/\"test\"/, ci)) == 1
  end

  @ci_timeouts %{
    "quality" => 15,
    "optional-dependencies" => 10,
    "integration" => 15,
    "contract" => 15,
    "proof" => 15,
    "package-consumer" => 15,
    "package-consumer-full" => 30,
    "adoption-demo-unit" => 10,
    "cohort-demo-smoke" => 20,
    "adoption-demo-e2e" => 30,
    "adoption-demo-e2e-smoke" => 15,
    "adopter" => 15,
    "mux-soak" => 30,
    "brandbook-tokens" => 10,
    "ci-observability" => 5,
    "ci-script-tests" => 5,
    "ci-summary" => 5
  }
  @nightly_timeouts %{
    "compat-matrix" => 45,
    "dialyzer" => 90,
    "gcs-soak" => 60,
    "package-consumer-gcs-live" => 30,
    "nightly-summary" => 5,
    "nightly-incident-verdict" => 5,
    "nightly-failure-issue" => 5
  }
  @minio_image "cgr.dev/chainguard/minio@sha256:2136d593beacf4461187035eca949fe49abd589d5079735025c711ca58fee0c8"
  @playwright_image "mcr.microsoft.com/playwright:v1.57.0-noble@sha256:3bed4b1a12f2338642f3d8cba28e291deef3c66bd4a964bbeb3e57bbff511dbd"
  @mc_hashes ~w(f06aa7f9d4a333b9481dcb9859bb2f6da5b4345b67f2cc7ac1c982f0c7cdd06c 160b34eaae2e32c4cce8784162a20b4449ed7e31210bf940e4698c030194f897)

  test "CI and Nightly consumers have reviewed time bounds and immutable tool inputs" do
    assert valid_infrastructure?(infrastructure())
  end

  test "each heavy job rejects missing or enlarged timeouts in its own parsed job" do
    original = infrastructure()

    for {workflow, limits} <- [{"ci", @ci_timeouts}, {"nightly", @nightly_timeouts}],
        {name, limit} <- limits,
        value <- [nil, limit + 1] do
      mutated = put_in(original, [workflow, "jobs", name, "timeout-minutes"], value)
      refute valid_infrastructure?(mutated), "#{workflow}/#{name} timeout=#{inspect(value)}"
    end
  end

  test "digest checksum cache and action mutations fail at the real consumer" do
    original = infrastructure()

    for name <- ~w(adoption-demo-e2e adoption-demo-e2e-smoke) do
      mutated =
        put_in(
          original,
          ["ci", "jobs", name, "env", "PLAYWRIGHT_IMAGE"],
          "mcr.microsoft.com/playwright:v1.57.0-noble"
        )

      refute valid_infrastructure?(mutated)
    end

    for name <- ["Start MinIO", "Install MinIO client"] do
      mutated =
        update_in(original, ["minio", "runs", "steps"], fn steps ->
          Enum.map(steps, fn step ->
            if step["name"] == name,
              do:
                Map.update!(
                  step,
                  "run",
                  &String.replace(&1, ~r/[a-f0-9]{64}/, String.duplicate("0", 64))
                ),
              else: step
          end)
        end)

      refute valid_infrastructure?(mutated)
    end

    for cache_name <- ["Restore deps cache", "Restore build cache"] do
      mutated =
        update_in(original, ["elixir", "runs", "steps"], fn steps ->
          Enum.map(steps, fn step ->
            if step["name"] == cache_name,
              do: put_in(step, ["with", "key"], "unscoped-cache"),
              else: step
          end)
        end)

      refute valid_infrastructure?(mutated)
    end

    mutated =
      update_in(original, ["ci", "jobs", "quality", "steps"], fn steps ->
        [first | rest] = steps
        [Map.put(first, "uses", "actions/checkout@main") | rest]
      end)

    refute valid_infrastructure?(mutated)
  end

  @tag :tmp_dir
  test "MinIO client copy verifies bytes before privileged installation", %{tmp_dir: dir} do
    client =
      infrastructure()["minio"]["runs"]["steps"]
      |> Enum.find(&(&1["name"] == "Install MinIO client"))
      |> Map.fetch!("run")

    bytes = "reviewed client fixture"
    digest = Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
    script = Enum.reduce(@mc_hashes, client, &String.replace(&2, &1, digest))

    for {arch, content, expected} <- [
          {"X64", bytes, 0},
          {"ARM64", bytes, 0},
          {"X64", "tampered client", 1}
        ] do
      run_dir = Path.join(dir, "#{arch}-#{expected}")
      File.mkdir_p!(run_dir)
      log = Path.join(run_dir, "calls")

      File.write!(Path.join(run_dir, "docker"), """
      #!/usr/bin/env bash
      echo copy >> '#{log}'
      printf '%s' '#{content}' > "$4"
      """)

      File.write!(Path.join(run_dir, "sudo"), "#!/usr/bin/env bash\necho install >> '#{log}'\n")
      for executable <- ~w(docker sudo), do: File.chmod!(Path.join(run_dir, executable), 0o755)

      {output, status} =
        System.cmd("bash", ["-c", script],
          env: [
            {"PATH", run_dir <> ":" <> System.get_env("PATH")},
            {"RUNNER_TEMP", run_dir},
            {"RUNNER_ARCH", arch}
          ],
          stderr_to_stdout: true
        )

      if expected == 0, do: assert(status == 0, output), else: assert(status != 0)
      calls = File.read!(log) |> String.split("\n", trim: true)
      assert calls == if(expected == 0, do: ["copy", "install"], else: ["copy"])
    end
  end

  test "sole required context and fork-safe topology reject parsed field mutations" do
    root = Path.expand("../..", __DIR__)
    ci = YamlElixir.read_from_file!(@ci_path)
    release = YamlElixir.read_from_file!(Path.join(root, ".github/workflows/release.yml"))

    authority =
      Path.join(root, "config/ci_required_checks.json") |> File.read!() |> Jason.decode!()

    assert valid_topology?(ci, release, authority)

    for mutated <- [
          Map.put(ci, "name", "Other CI"),
          put_in(ci, ["jobs", "ci-summary", "name"], "Other Summary"),
          put_in(ci, ["permissions", "contents"], "write"),
          put_in(
            ci,
            ["jobs", "adoption-demo-e2e-smoke", "if"],
            "github.repository == 'szTheory/rindle'"
          ),
          put_in(ci, ["on", "pull_request_target"], nil),
          put_in(ci, ["jobs", "quality", "permissions"], %{"contents" => "write"})
        ] do
      refute valid_topology?(mutated, release, authority)
    end

    for mutated <- [
          Map.put(authority, "contexts", ["CI Summary", "Quality"]),
          put_in(authority, ["workflow", "file"], "other.yml")
        ] do
      refute valid_topology?(ci, release, mutated)
    end

    refute valid_topology?(
             ci,
             put_in(release, ["jobs", "publish", "needs"], ["recovery-validation"]),
             authority
           )
  end

  test "release gate executes against the selected SHA and rejects other SHA success" do
    root = Path.expand("../..", __DIR__)
    release = YamlElixir.read_from_file!(Path.join(root, ".github/workflows/release.yml"))
    gate = step(release, "gate-ci-green", "Wait for CI to finish green on release SHA")
    script = get_in(gate, ["with", "script"])
    assert release_gate_result(script, "success")["passed"]
    refute release_gate_result(script, "wrong-sha")["passed"]
    refute release_gate_result(script, "failure")["passed"]
    weakened_filter = String.replace(script, "run.head_sha === sha", "true")
    assert release_gate_result(weakened_filter, "wrong-sha")["passed"]
    weakened_query = String.replace(script, "head_sha: sha,", "")
    refute release_gate_result(weakened_query, "success")["passed"]
  end

  defp valid_topology?(ci, release, authority) do
    valid_required_identity?(ci, authority) and fork_safe?(ci) and
      valid_release_topology?(release)
  end

  defp valid_required_identity?(ci, authority) do
    authority["contexts"] == ["CI Summary"] and
      authority["workflow"] == %{"file" => "ci.yml", "name" => "CI", "job_id" => "ci-summary"} and
      ci["name"] == "CI" and
      get_in(ci, ["jobs", "ci-summary", "name"]) == "CI Summary" and
      Enum.count(ci["jobs"], fn {_, job} -> job["name"] == "CI Summary" end) == 1
  end

  defp fork_safe?(ci) do
    ci["permissions"] == %{"contents" => "read"} and
      Map.has_key?(ci["on"], "pull_request") and not Map.has_key?(ci["on"], "pull_request_target") and
      get_in(ci, ["jobs", "adoption-demo-e2e-smoke", "if"]) == nil and
      Enum.all?(ci["jobs"], fn {_, job} ->
        Enum.all?(Map.get(job, "permissions", %{}), fn {_, permission} -> permission == "read" end)
      end)
  end

  defp valid_release_topology?(release) do
    "gate-ci-green" in get_in(release, ["jobs", "publish", "needs"]) and
      get_in(release, ["jobs", "publish", "if"]) =~ "needs.gate-ci-green.result == 'success'" and
      get_in(release, ["jobs", "gate-ci-green", "permissions"]) == %{
        "actions" => "read",
        "contents" => "read"
      }
  end

  defp release_gate_result(script, scenario) do
    sha = String.duplicate("a", 40)
    script = String.replace(script, "${{ steps.resolve.outputs.release_sha }}", sha)

    harness = ~S"""
    const failures = [], outputs = {};
    globalThis.setTimeout = callback => { callback(); return 0; };
    const sha = 'a'.repeat(40);
    const github = {rest: {actions: {listWorkflowRuns: async args => {
      if (args.workflow_id !== 'ci.yml' || args.head_sha !== sha) throw new Error('unbound CI lookup');
      return {data: {workflow_runs: [{head_sha: process.env.SCENARIO === 'wrong-sha' ? 'b'.repeat(40) : sha,
        status: 'completed', conclusion: process.env.SCENARIO === 'failure' ? 'failure' : 'success', html_url: 'fixture'}]}};
    }}}};
    const core = {info: () => {}, setFailed: reason => failures.push(reason),
                  setOutput: (key, value) => { outputs[key] = value; }};
    const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
    try { await new AsyncFunction('github', 'context', 'core', process.env.GATE_SCRIPT)(
      github, {repo: {owner: 'fixture', repo: 'fixture'}}, core); }
    catch (error) { failures.push(error.message); }
    console.log(JSON.stringify({passed: failures.length === 0 && outputs.ci_run_url === 'fixture'}));
    """

    {output, 0} =
      System.cmd("node", ["--input-type=module", "-e", harness],
        env: [{"GATE_SCRIPT", script}, {"SCENARIO", scenario}],
        stderr_to_stdout: true
      )

    Jason.decode!(output)
  end

  defp infrastructure do
    root = Path.expand("../..", __DIR__)

    %{
      "ci" => YamlElixir.read_from_file!(@ci_path),
      "nightly" => YamlElixir.read_from_file!(Path.join(root, ".github/workflows/nightly.yml")),
      "minio" =>
        YamlElixir.read_from_file!(Path.join(root, ".github/actions/setup-minio/action.yml")),
      "elixir" =>
        YamlElixir.read_from_file!(Path.join(root, ".github/actions/setup-elixir/action.yml"))
    }
  end

  defp valid_infrastructure?(data) do
    valid_timeouts?(data["ci"], @ci_timeouts) and
      valid_timeouts?(data["nightly"], @nightly_timeouts) and
      Enum.all?(~w(adoption-demo-e2e adoption-demo-e2e-smoke), fn name ->
        get_in(data, ["ci", "jobs", name, "env", "PLAYWRIGHT_IMAGE"]) == @playwright_image
      end) and valid_minio?(data["minio"]) and valid_caches?(data) and
      Enum.all?([data["ci"], data["nightly"]], fn workflow ->
        Enum.all?(workflow["jobs"], fn {_name, job} -> pinned_job_inputs?(job) end)
      end)
  end

  defp pinned_job_inputs?(job) do
    Enum.all?(Map.get(job, "steps", []), &pinned_action?/1) and
      Enum.all?(Map.get(job, "services", %{}), fn {_name, service} -> pinned_service?(service) end)
  end

  defp pinned_service?(service) do
    # Explicit exception: isolated disposable Postgres test fixtures track
    # security patches within the supported major/Alpine family.
    service["image"] == "postgres:16-alpine" or
      Regex.match?(~r/@sha256:[a-f0-9]{64}$/, service["image"] || "")
  end

  defp valid_timeouts?(workflow, limits) do
    Map.keys(workflow["jobs"]) |> Enum.sort() == Enum.sort(Map.keys(limits)) and
      Enum.all?(limits, fn {name, limit} ->
        get_in(workflow, ["jobs", name, "timeout-minutes"]) == limit
      end)
  end

  defp pinned_action?(%{"uses" => "./" <> _}), do: true
  defp pinned_action?(%{"uses" => uses}), do: Regex.match?(~r/^[^@]+@[a-f0-9]{40}$/, uses)
  defp pinned_action?(_), do: true

  defp valid_minio?(action) do
    steps = get_in(action, ["runs", "steps"])
    start = Enum.find(steps, &(&1["name"] == "Start MinIO"))["run"]
    client = Enum.find(steps, &(&1["name"] == "Install MinIO client"))["run"]

    String.contains?(start, @minio_image) and
      Enum.all?(@mc_hashes, &String.contains?(client, &1)) and
      String.contains?(client, "rindle-minio:/usr/bin/mc") and
      String.contains?(client, "sha256sum -c") and
      ordered_commands?(client, "sha256sum -c", "sudo install")
  end

  defp ordered_commands?(script, first, second) do
    case {:binary.match(script, first), :binary.match(script, second)} do
      {{left, _}, {right, _}} -> left < right
      _ -> false
    end
  end

  defp valid_caches?(data) do
    caches = get_in(data, ["elixir", "runs", "steps"])

    Enum.all?(["Restore deps cache", "Restore build cache"], fn name ->
      cache = Enum.find(caches, &(&1["name"] == name))
      key = get_in(cache, ["with", "key"]) || ""

      Enum.all?(
        [
          "runner.os",
          "runner.arch",
          "steps.beam.outputs.otp-version",
          "steps.beam.outputs.elixir-version",
          "inputs.mix-env",
          "hashFiles('mix.lock')"
        ],
        &String.contains?(key, &1)
      )
    end) and
      get_in(data, ["nightly", "jobs", "dialyzer", "steps"])
      |> Enum.filter(fn step ->
        String.starts_with?(step["uses"] || "", "actions/cache/")
      end)
      |> Enum.all?(fn step ->
        key = get_in(step, ["with", "key"]) || ""

        Enum.all?(
          [
            "steps.setup.outputs.resolved-elixir-version",
            "steps.setup.outputs.resolved-otp-version",
            "hashFiles('mix.exs', 'mix.lock', '.dialyzer_ignore.exs')"
          ],
          &String.contains?(key, &1)
        ) and not Map.has_key?(step["with"], "restore-keys")
      end)
  end

  defp assert_required_step!(workflow, job_name, step_name, run, condition \\ nil) do
    required_step = step(workflow, job_name, step_name)

    assert required_step["run"] == run
    assert required_step["if"] == condition
    refute required_step["continue-on-error"]

    if job_name == "quality" do
      assert enabled_for_canonical_quality_cell?(required_step)
    end
  end

  defp enabled_for_canonical_quality_cell?(step),
    do: Map.get(step, "if") in [nil, @canonical_lint_condition]

  defp job(workflow, name), do: workflow |> Map.fetch!("jobs") |> Map.fetch!(name)
  defp steps(workflow, job_name), do: job(workflow, job_name) |> Map.fetch!("steps")

  defp step(workflow, job_name, name) do
    Enum.find(steps(workflow, job_name), &(Map.get(&1, "name") == name)) ||
      flunk("missing #{job_name} step: #{name}")
  end

  defp index_of(items, item), do: Enum.find_index(items, &(&1 == item))

  defp alias_block(mix, name) do
    [_, after_name] = String.split(mix, "      #{name}: [", parts: 2)
    [block | _] = String.split(after_name, ~r/\n      [a-z_]+:/, parts: 2)
    block
  end
end
