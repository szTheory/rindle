defmodule Rindle.InstallSmoke.CiTimingAutomationTest do
  use ExUnit.Case, async: false

  @script Path.expand("../../scripts/ci/collect_pr_timing_receipt.sh", __DIR__)

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-ci-timing-#{System.os_time(:nanosecond)}-#{System.unique_integer([:positive])}"
      )

    bin = Path.join(root, "bin")
    state_dir = Path.join(root, "state")
    fixture_dir = Path.join(root, "fixture")
    File.mkdir_p!(bin)
    File.mkdir_p!(state_dir)
    File.mkdir_p!(fixture_dir)

    receipt = Path.join(root, "receipt.md")
    baseline = "# Timing Receipt\n\nImmutable failed baseline: 515.5s median / 544s p95.\n"
    File.write!(receipt, baseline)
    File.write!(Path.join(fixture_dir, "count"), "0\n")
    File.write!(Path.join(fixture_dir, "label"), "absent\n")
    write_gh_shim!(Path.join(bin, "gh"))
    repo_dir = Path.join(root, "transition-repository")
    anchors = transition_repository!(repo_dir)
    transition_manifest = Path.join(fixture_dir, "transition.md")
    write_transition_manifest!(repo_dir, transition_manifest, anchors)

    on_exit(fn -> File.rm_rf!(root) end)

    %{
      root: root,
      bin: bin,
      state_dir: state_dir,
      fixture_dir: fixture_dir,
      receipt: receipt,
      baseline: baseline,
      repo_dir: repo_dir,
      transition_manifest: transition_manifest,
      head: anchors.head,
      preserved_subject: anchors.repair,
      correction: anchors.controller,
      formatter: anchors.formatter
    }
  end

  test "drives ten sequential runs and writes a verified receipt", context do
    assert {output, 0} = run_controller(context)
    assert output =~ "CI timing receipt passed"
    assert File.read!(context.receipt) |> String.starts_with?(context.baseline)

    receipt = File.read!(context.receipt)
    assert receipt =~ "CI_TIMING_CURRENT_SOURCE_BEGIN"
    assert receipt =~ "CI_TIMING_CURRENT_TABLE_BEGIN"
    assert receipt =~ "Verdict | PASS"
    assert count(receipt, "https://github.com/szTheory/rindle/actions/runs/") == 20
    assert File.read!(Path.join(context.fixture_dir, "label")) == "absent\n"

    assert {verify_output, 0} =
             System.cmd("bash", verify_args(context),
               env: controller_env(context),
               stderr_to_stdout: true
             )

    assert verify_output =~ "receipt verification passed"
  end

  test "restarts the entire sequence once after an invalid run", context do
    assert {output, 0} = run_controller(context, [{"GH_FAIL_RUN_ID", "1003"}])
    assert output =~ "restarting sequence 2/2"

    manifest = manifest!(context.receipt)
    assert hd(manifest["runs"])["id"] == 1004
    assert List.last(manifest["runs"])["id"] == 1013
    assert String.trim(File.read!(Path.join(context.fixture_dir, "count"))) == "13"
  end

  test "rejects a sequence ceiling above two before any controller mutation", context do
    count_before = File.read!(Path.join(context.fixture_dir, "count"))
    receipt_before = File.read!(context.receipt)

    assert {output, 1} =
             run_controller(context, [], max_sequences: "3")

    assert output =~ "--max-sequences must be 1 or 2"
    assert File.read!(Path.join(context.fixture_dir, "count")) == count_before
    assert File.read!(context.receipt) == receipt_before
    refute File.exists?(Path.join(context.state_dir, "pr-96-#{context.head}.json"))
  end

  test "refuses a persisted failed state without changing its evidence", context do
    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")

    failed =
      valid_running_state(context)
      |> Map.put("status", "failed")
      |> Map.put("errors", [%{"reason" => "prior bounded failure", "runs" => []}])

    File.write!(state_file, Jason.encode!(failed))
    before = File.read!(state_file)

    assert {output, 1} = run_controller(context)
    assert output =~ "terminal failed"
    assert File.read!(state_file) == before
    assert File.read!(Path.join(context.fixture_dir, "count")) == "0\n"
  end

  test "rejects malformed and foreign running state before it can resume", context do
    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")

    invalid_states = [
      "not-json",
      Jason.encode!(Map.put(valid_running_state(context), "schema_version", 1)),
      Jason.encode!(Map.put(valid_running_state(context), "repo", "foreign/repo")),
      Jason.encode!(Map.put(valid_running_state(context), "sequence_attempt", 3)),
      Jason.encode!(Map.put(valid_running_state(context), "runs", [nil])),
      Jason.encode!(
        valid_running_state(context)
        |> Map.put("pending_trigger", %{
          "before_run_ids" => [],
          "triggered_at" => "2026-08-26T00:00:00Z",
          "triggered_at_epoch" => 1,
          "status" => "awaiting_run"
        })
        |> Map.put("current_run_id", 1001)
      )
    ]

    for state <- invalid_states do
      File.write!(state_file, state)
      assert {_output, 1} = run_controller(context)
      assert File.read!(state_file) == state
      assert File.read!(Path.join(context.fixture_dir, "count")) == "0\n"
    end
  end

  test "resumes a discovered run without triggering a duplicate", context do
    File.write!(Path.join(context.fixture_dir, "count"), "1\n")

    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")

    File.write!(
      state_file,
      Jason.encode!(%{
        schema_version: 2,
        repo: "szTheory/rindle",
        pr: 96,
        sha: context.head,
        label: "ci-timing-sample",
        max_sequences: 2,
        sequence_attempt: 1,
        status: "running",
        population_boundary_ids: [],
        runs: [],
        pending_trigger: %{
          before_run_ids: [],
          triggered_at: "2026-08-26T00:00:00Z",
          triggered_at_epoch: 1_787_616_000,
          status: "discovered",
          run_id: 1001
        },
        current_run_id: 1001,
        current_run_status: "discovered",
        errors: []
      })
    )

    assert {output, 0} = run_controller(context)
    assert output =~ "resuming discovered sample 1/10 as run 1001"

    manifest = manifest!(context.receipt)
    assert Enum.map(manifest["runs"], & &1["id"]) == Enum.to_list(1001..1010)
    assert String.trim(File.read!(Path.join(context.fixture_dir, "count"))) == "10"
  end

  test "waits for a queued discovered run without consuming its sequence or retriggering",
       context do
    File.write!(Path.join(context.fixture_dir, "count"), "1\n")

    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")

    File.write!(
      state_file,
      Jason.encode!(%{
        schema_version: 2,
        repo: "szTheory/rindle",
        pr: 96,
        sha: context.head,
        label: "ci-timing-sample",
        max_sequences: 2,
        sequence_attempt: 1,
        status: "running",
        population_boundary_ids: [],
        runs: [],
        pending_trigger: %{
          before_run_ids: [],
          triggered_at: "2026-08-26T00:00:00Z",
          triggered_at_epoch: 1_787_616_000,
          status: "discovered",
          run_id: 1001
        },
        current_run_id: 1001,
        current_run_status: "discovered",
        errors: []
      })
    )

    assert {output, 0} =
             run_controller(context, [{"GH_RUN_STATUS_SEQUENCE", "queued,in_progress,completed"}])

    assert output =~ "run 1001 is queued; waiting for terminal completion"
    assert output =~ "run 1001 is in_progress; waiting for terminal completion"

    manifest = manifest!(context.receipt)
    assert Enum.map(manifest["runs"], & &1["id"]) == Enum.to_list(1001..1010)
    assert String.trim(File.read!(Path.join(context.fixture_dir, "count"))) == "10"
  end

  test "persists a delayed label trigger across restart without consuming or retriggering",
       context do
    File.write!(Path.join(context.fixture_dir, "count"), "1\n")
    triggered_at_epoch = System.os_time(:second)

    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")

    File.write!(
      state_file,
      Jason.encode!(%{
        schema_version: 2,
        repo: "szTheory/rindle",
        pr: 96,
        sha: context.head,
        label: "ci-timing-sample",
        max_sequences: 2,
        sequence_attempt: 1,
        status: "running",
        population_boundary_ids: [],
        runs: [],
        pending_trigger: %{
          before_run_ids: [],
          triggered_at: DateTime.from_unix!(triggered_at_epoch) |> DateTime.to_iso8601(),
          triggered_at_epoch: triggered_at_epoch,
          status: "awaiting_run"
        },
        current_run_id: nil,
        current_run_status: nil,
        errors: []
      })
    )

    assert {output, 0} = run_controller(context, [{"GH_HIDE_RUN_POLLS", "2"}])
    assert output =~ "resuming owned delayed trigger for sample 1/10"
    assert output =~ "awaiting its delayed PR run; polling without relabeling"

    manifest = manifest!(context.receipt)
    assert Enum.map(manifest["runs"], & &1["id"]) == Enum.to_list(1001..1010)
    assert String.trim(File.read!(Path.join(context.fixture_dir, "count"))) == "10"
  end

  test "terminalizes a never-created trigger at its persisted creation deadline", context do
    assert {output, 1} =
             run_controller(context, [{"GH_HIDE_RUN_POLLS", "2"}], creation_timeout: "0")

    assert output =~ "did not appear before the persisted creation deadline"
    assert File.read!(Path.join(context.fixture_dir, "label")) == "absent\n"
    assert String.trim(File.read!(Path.join(context.fixture_dir, "count"))) == "1"

    state =
      context.state_dir
      |> Path.join("pr-96-#{context.head}.json")
      |> File.read!()
      |> Jason.decode!()

    assert state["status"] == "failed"
    assert [%{"reason" => reason}] = state["errors"]
    assert reason =~ "creation deadline"
  end

  test "permanent API rate limits terminalize owned state and preserve receipt evidence",
       context do
    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")
    receipt_before = File.read!(context.receipt)

    for endpoint <- [
          "actions/workflows",
          "actions/runs/1001",
          "actions/runs/1001/jobs"
        ] do
      File.rm_rf!(context.state_dir)
      File.mkdir_p!(context.state_dir)
      File.write!(Path.join(context.fixture_dir, "count"), "0\n")
      File.write!(Path.join(context.fixture_dir, "label"), "absent\n")

      if endpoint != "actions/workflows" do
        File.write!(state_file, Jason.encode!(discovered_running_state(context)))
      end

      assert {output, 1} =
               run_controller(
                 context,
                 [
                   {"GH_RATE_LIMIT_ENDPOINT", endpoint},
                   {"GH_RATE_LIMIT_AFTER", "1"}
                 ],
                 run_timeout: "1"
               )

      assert output =~ "deadline"
      state = state_file |> File.read!() |> Jason.decode!()
      assert state["status"] == "failed"
      assert state["pending_trigger"] == nil
      assert state["current_run_id"] == nil
      assert File.read!(Path.join(context.fixture_dir, "label")) == "absent\n"
      assert File.read!(context.receipt) == receipt_before
      refute File.exists?(state_file <> ".lock")

      terminal = File.read!(state_file)
      assert {_output, 1} = run_controller(context, [], run_timeout: "1")
      assert File.read!(state_file) == terminal
    end
  end

  test "rate limits at restart-boundary and final-population owners fail closed", context do
    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")
    receipt_before = File.read!(context.receipt)

    for {name, env} <- [
          {"restart boundary",
           [
             {"GH_FAIL_RUN_ID", "1001"},
             {"GH_RATE_LIMIT_ENDPOINT", "actions/workflows"},
             {"GH_RATE_LIMIT_AFTER", "5"}
           ]},
          {"final canonical population",
           [
             {"GH_RATE_LIMIT_ENDPOINT", "actions/workflows"},
             {"GH_RATE_LIMIT_AFTER", "41"}
           ]}
        ] do
      File.rm_rf!(context.state_dir)
      File.mkdir_p!(context.state_dir)
      File.write!(Path.join(context.fixture_dir, "count"), "0\n")
      File.rm(Path.join(context.fixture_dir, "api-count"))

      assert {output, 1} = run_controller(context, env, run_timeout: "1")
      assert output =~ "deadline"

      state = state_file |> File.read!() |> Jason.decode!()
      assert state["status"] == "failed", "#{name} retained a resumable state"
      assert state["pending_trigger"] == nil
      assert state["current_run_id"] == nil
      assert File.read!(context.receipt) == receipt_before
      refute File.exists?(state_file <> ".lock")
    end
  end

  test "rate-limit reset lookup cannot outlive an owned deadline", context do
    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")

    assert {output, 1} =
             run_controller(
               context,
               [
                 {"GH_RATE_LIMIT_ENDPOINT", "actions/workflows"},
                 {"GH_RATE_LIMIT_AFTER", "1"},
                 {"GH_RATE_LIMIT_RESET_BLOCK", "1"}
               ],
               run_timeout: "1"
             )

    assert output =~ "deadline"
    assert state_file |> File.read!() |> Jason.decode!() |> Map.fetch!("status") == "failed"
    refute File.exists?(Path.join(context.fixture_dir, "rate-limit-reset-called"))
    refute File.exists?(state_file <> ".lock")
  end

  test "verification fails when a qualifying second-page run is absent from the receipt",
       context do
    assert {_output, 0} = run_controller(context)

    assert {_output, 1} =
             System.cmd("bash", verify_args(context),
               env: controller_env(context) ++ [{"GH_SECOND_PAGE", "qualifying"}],
               stderr_to_stdout: true
             )
  end

  test "verification filters a nonqualifying second-page run", context do
    assert {_output, 0} = run_controller(context)

    assert {output, 0} =
             System.cmd("bash", verify_args(context),
               env: controller_env(context) ++ [{"GH_SECOND_PAGE", "nonqualifying"}],
               stderr_to_stdout: true
             )

    assert output =~ "receipt verification passed"
  end

  test "verify-only API rate limits preserve the accepted receipt", context do
    assert {_output, 0} = run_controller(context)
    receipt_before = File.read!(context.receipt)

    assert {output, 124} =
             System.cmd("bash", verify_args(context, run_timeout: "1"),
               env:
                 controller_env(context) ++
                   [
                     {"GH_RATE_LIMIT_ENDPOINT", "actions/runs/1001"},
                     {"GH_RATE_LIMIT_AFTER", "1"}
                   ],
               stderr_to_stdout: true
             )

    assert output =~ "rate-limit retry deadline expired"
    assert File.read!(context.receipt) == receipt_before
  end

  test "verify rejects a partial receipt", context do
    File.write!(context.receipt, """
    #{context.baseline}
    CI_TIMING_CURRENT_TABLE_BEGIN
    | Sequence | Run ID | Source | Started (UTC) | Duration seconds |
    | ---: | ---: | --- | --- | ---: |
    CI_TIMING_CURRENT_TABLE_END
    CI_TIMING_CURRENT_SOURCE_BEGIN
    {"sha":"#{context.head}","runs":[],"median_seconds":0,"p95_seconds":0}
    CI_TIMING_CURRENT_SOURCE_END
    """)

    assert {output, 1} =
             System.cmd("bash", verify_args(context),
               env: controller_env(context),
               stderr_to_stdout: true
             )

    assert output =~ "exactly 10 runs"
  end

  test "verify rejects a legacy receipt without a current section", context do
    assert {output, 1} =
             System.cmd("bash", verify_args(context),
               env: controller_env(context),
               stderr_to_stdout: true
             )

    assert output =~ "CI_TIMING_CURRENT_SOURCE_BEGIN"
  end

  test "verify uses API evidence and accepts inclusive timing boundaries", context do
    assert {_output, 0} =
             run_controller(context, [
               {"GH_BOUNDARY_DURATIONS", "400,420,440,460,480,480,500,520,540,600"}
             ])

    assert {output, 0} =
             System.cmd(
               "bash",
               verify_args(context),
               env:
                 controller_env(context) ++
                   [{"GH_BOUNDARY_DURATIONS", "400,420,440,460,480,480,500,520,540,600"}],
               stderr_to_stdout: true
             )

    assert output =~ "receipt verification passed"
  end

  test "verify rejects API identity, event, attempt, summary, duration, and chronology drift",
       context do
    assert {_output, 0} = run_controller(context)

    for {flag, value} <- [
          {"GH_WRONG_HEAD", "1"},
          {"GH_WRONG_EVENT", "1"},
          {"GH_WRONG_ATTEMPT", "1"},
          {"GH_BAD_SUMMARY", "1"},
          {"GH_DUPLICATE_SUMMARY", "1"}
        ] do
      assert {_output, 1} =
               System.cmd(
                 "bash",
                 verify_args(context),
                 env: controller_env(context) ++ [{flag, value}],
                 stderr_to_stdout: true
               )
    end
  end

  test "controller remains compatible with jq versions where label is a keyword" do
    source = File.read!(@script)

    refute source =~ "--arg label "
    refute source =~ "$label)"
    assert source =~ "--arg label_name"
    assert source =~ "$label_name"
  end

  test "controller gives every API retry caller-owned deadline budget" do
    source = File.read!(@script)

    assert source =~ "gh api --paginate --slurp"
    assert source =~ "per_page=100"
    assert source =~ "branch=${encoded_head_ref}"
    assert source =~ "GitHub API rate limited; retrying"
    assert source =~ "rate-limit retry deadline expired"
    assert source =~ "gh_api_json \"repos/${repo}/actions/runs/${run_id}\" \"\" \"$deadline\""
    assert source =~ "same_sha_runs \"$deadline\""
    assert source =~ "canonical_eligible_run_ids"
  end

  test "controller has no post-subject executable allowlist" do
    source = File.read!(@script)

    assert source =~ "validate_transition_manifest"
    refute source =~ "ci_cache_hygiene_test\\.exs"
    refute source =~ "scripts/ci/install_ffmpeg\\.sh"
  end

  test "controller locks a SHA-scoped state path before sampling" do
    source = File.read!(@script)

    assert source =~ "lock_dir=\"${state_file}.lock\""
    assert source =~ "another controller owns state"
    assert source =~ "release_controller_lock"
  end

  test "controller uses one PR-bound canonical API population authority" do
    source = File.read!(@script)

    assert source =~ "canonical_eligible_run_ids()"
    assert source =~ "verify_api_backed_receipt \"$receipt\""
    assert source =~ "selected run IDs do not equal the complete canonical eligible population"
    refute source =~ "contiguous slice of eligible"
  end

  test "completed PASS is revalidated against live API evidence" do
    source = File.read!(@script)

    assert source =~ "verify_api_backed_receipt \"$receipt\" \"$head_sha\""
    assert source =~ "verify requires --pr"
    assert source =~ "repo:$repo,pr:$pr,sha:$sha"
  end

  test "preflight rejects a missing transition manifest before it can own controller state",
       context do
    count_before = File.read!(Path.join(context.fixture_dir, "count"))
    receipt_before = File.read!(context.receipt)

    assert {output, 1} =
             System.cmd("bash", preflight_args(context),
               env: controller_env(context),
               cd: context.repo_dir,
               stderr_to_stdout: true
             )

    assert output =~ "--transition-manifest is required"
    assert File.read!(Path.join(context.fixture_dir, "count")) == count_before
    assert File.read!(context.receipt) == receipt_before
    refute File.exists?(Path.join(context.state_dir, "pr-96-#{context.head}.json"))
  end

  test "valid preserved-subject manifests accept planning-only evidence tails without mutation",
       context do
    for extra_env <- [[], [{"GH_REMOTE_SHA", context.formatter}]] do
      assert {output, 0} =
               System.cmd("bash", preflight_args(context, context.transition_manifest),
                 env: controller_env(context) ++ extra_env,
                 cd: context.repo_dir,
                 stderr_to_stdout: true
               )

      assert output =~ "preflight passed"
      assert File.read!(Path.join(context.fixture_dir, "count")) == "0\n"
      refute File.exists?(Path.join(context.state_dir, "pr-96-#{context.head}.json"))
    end
  end

  test "tampered transition manifests fail before labels, receipt, or controller ownership mutate",
       context do
    original_receipt = File.read!(context.receipt)
    manifest = transition_manifest!(context.transition_manifest)

    mutations = [
      {:malformed,
       "PRESERVATION_TRANSITION_V2_BEGIN\nnot json\nPRESERVATION_TRANSITION_V2_END\n"},
      {:version, transition_document(Map.put(manifest, "schema_version", 3))},
      {:chronology,
       transition_document(
         put_in(manifest, ["stages", Access.at(1), "from_sha"], String.duplicate("0", 40))
       )},
      {:identity,
       transition_document(Map.put(manifest, "repair_sha", String.duplicate("0", 40)))},
      {:classification,
       transition_document(
         manifest
         |> put_in(["stages", Access.at(0), "planning"], hd(manifest["stages"])["non_planning"])
         |> put_in(["stages", Access.at(0), "non_planning"], [])
       )},
      {:status,
       transition_document(
         put_in(manifest, ["stages", Access.at(0), "non_planning", Access.at(0), "status"], "M")
       )},
      {:blob,
       transition_document(
         put_in(
           manifest,
           ["stages", Access.at(2), "non_planning", Access.at(0), "blob_oid"],
           String.duplicate("0", 40)
         )
       )},
      {:extra_path,
       transition_document(
         update_in(
           manifest,
           ["stages", Access.at(1), "planning"],
           &(&1 ++ [%{"status" => "A", "path" => ".planning/hidden.md"}])
         )
       )}
    ]

    for {name, document} <- mutations do
      path = Path.join(context.fixture_dir, "#{name}-transition.md")
      File.write!(path, document)

      assert {_output, 1} =
               System.cmd("bash", preflight_args(context, path),
                 env: controller_env(context),
                 cd: context.repo_dir,
                 stderr_to_stdout: true
               )

      assert File.read!(Path.join(context.fixture_dir, "count")) == "0\n"
      assert File.read!(context.receipt) == original_receipt
      refute File.exists?(Path.join(context.state_dir, "pr-96-#{context.head}.json"))
    end
  end

  defp run_controller(context, extra_env \\ [], options \\ []) do
    args = [
      "run",
      "--repo",
      "szTheory/rindle",
      "--pr",
      "96",
      "--workflow",
      "ci.yml",
      "--summary-job",
      "CI Summary",
      "--label",
      "ci-timing-sample",
      "--samples",
      "10",
      "--max-sequences",
      Keyword.get(options, :max_sequences, "2"),
      "--median-max",
      "480",
      "--p95-max",
      "600",
      "--correction-sha",
      context.correction,
      "--preserved-subject-sha",
      context.preserved_subject,
      "--transition-manifest",
      context.transition_manifest,
      "--receipt",
      context.receipt,
      "--state-dir",
      context.state_dir,
      "--no-publish",
      "--poll-seconds",
      "0",
      "--creation-timeout",
      Keyword.get(options, :creation_timeout, "300"),
      "--run-timeout",
      Keyword.get(options, :run_timeout, "1800")
    ]

    System.cmd("bash", [@script | args],
      env: controller_env(context) ++ extra_env,
      cd: context.repo_dir,
      stderr_to_stdout: true
    )
  end

  defp valid_running_state(context) do
    %{
      "schema_version" => 2,
      "repo" => "szTheory/rindle",
      "pr" => 96,
      "sha" => context.head,
      "label" => "ci-timing-sample",
      "max_sequences" => 2,
      "sequence_attempt" => 1,
      "population_boundary_ids" => [],
      "status" => "running",
      "runs" => [],
      "pending_trigger" => nil,
      "current_run_id" => nil,
      "current_run_status" => nil,
      "errors" => []
    }
  end

  defp discovered_running_state(context) do
    valid_running_state(context)
    |> Map.put("pending_trigger", %{
      "before_run_ids" => [],
      "triggered_at" => "2026-08-26T00:00:00Z",
      "triggered_at_epoch" => 1_787_616_000,
      "status" => "discovered",
      "run_id" => 1001
    })
    |> Map.put("current_run_id", 1001)
    |> Map.put("current_run_status", "discovered")
  end

  defp preflight_args(context, transition_manifest \\ nil) do
    args = [
      @script,
      "preflight",
      "--repo",
      "szTheory/rindle",
      "--pr",
      "96",
      "--workflow",
      "ci.yml",
      "--summary-job",
      "CI Summary",
      "--label",
      "ci-timing-sample",
      "--samples",
      "10",
      "--max-sequences",
      "2",
      "--median-max",
      "480",
      "--p95-max",
      "600",
      "--correction-sha",
      context.correction,
      "--preserved-subject-sha",
      context.preserved_subject,
      "--receipt",
      context.receipt,
      "--state-dir",
      context.state_dir,
      "--no-publish",
      "--poll-seconds",
      "0"
    ]

    if transition_manifest, do: args ++ ["--transition-manifest", transition_manifest], else: args
  end

  defp controller_env(context) do
    [
      {"PATH", context.bin <> ":" <> System.get_env("PATH", "")},
      {"GH_FIXTURE_DIR", context.fixture_dir},
      {"GH_EXPECTED_SHA", context.head},
      {"GH_EXPECTED_PR", "96"}
    ]
  end

  defp verify_args(context, options \\ []) do
    [
      @script,
      "verify",
      "--repo",
      "szTheory/rindle",
      "--pr",
      "96",
      "--workflow",
      "ci.yml",
      "--summary-job",
      "CI Summary",
      "--samples",
      "10",
      "--median-max",
      "480",
      "--p95-max",
      "600",
      "--run-timeout",
      Keyword.get(options, :run_timeout, "1800"),
      "--receipt",
      context.receipt
    ]
  end

  defp manifest!(receipt) do
    [_, body] = String.split(File.read!(receipt), "CI_TIMING_CURRENT_SOURCE_BEGIN\n", parts: 2)
    [json | _] = String.split(body, "\nCI_TIMING_CURRENT_SOURCE_END", parts: 2)
    Jason.decode!(json)
  end

  defp transition_manifest!(path) do
    [_, body] = String.split(File.read!(path), "PRESERVATION_TRANSITION_V2_BEGIN\n", parts: 2)
    [json | _] = String.split(body, "\nPRESERVATION_TRANSITION_V2_END", parts: 2)
    Jason.decode!(json)
  end

  defp transition_document(manifest) do
    "PRESERVATION_TRANSITION_V2_BEGIN\n#{Jason.encode!(manifest)}\nPRESERVATION_TRANSITION_V2_END\n"
  end

  defp count(haystack, needle), do: length(String.split(haystack, needle)) - 1

  defp transition_repository!(repo_dir) do
    File.mkdir_p!(repo_dir)
    git!(repo_dir, ["init", "--quiet"])
    git!(repo_dir, ["config", "user.email", "timing@example.test"])
    git!(repo_dir, ["config", "user.name", "Timing Fixture"])

    write_fixture_file!(repo_dir, ".planning/prior.md", "prior preservation\n")
    prior = commit_fixture!(repo_dir, "prior preservation")

    write_fixture_file!(repo_dir, "scripts/ci/collect_pr_timing_receipt.sh", "controller v1\n")

    write_fixture_file!(
      repo_dir,
      "test/install_smoke/ci_timing_automation_test.exs",
      "controller test v1\n"
    )

    controller = commit_fixture!(repo_dir, "plan 132-12 controller")

    write_fixture_file!(repo_dir, ".planning/formatter.md", "formatter evidence\n")
    write_fixture_file!(repo_dir, "test/install_smoke/ci_lane_split_test.exs", "formatter v1\n")
    formatter = commit_fixture!(repo_dir, "plan 132-13 formatter")

    write_fixture_file!(
      repo_dir,
      "scripts/ci/collect_pr_timing_receipt.sh",
      "controller repair\n"
    )

    write_fixture_file!(
      repo_dir,
      "test/install_smoke/ci_timing_automation_test.exs",
      "controller test repair\n"
    )

    repair = commit_fixture!(repo_dir, "plan 132-14 repair")

    write_fixture_file!(repo_dir, ".planning/plan-132-15-summary.md", "preservation evidence\n")
    head = commit_fixture!(repo_dir, "plan 132-15 preservation evidence")

    %{prior: prior, controller: controller, formatter: formatter, repair: repair, head: head}
  end

  defp write_transition_manifest!(repo_dir, path, anchors) do
    non_planning = fn to_sha, paths ->
      Enum.map(paths, fn entry_path ->
        %{
          "status" => if(to_sha == anchors.repair, do: "M", else: "A"),
          "path" => entry_path,
          "blob_oid" => git!(repo_dir, ["rev-parse", "#{to_sha}:#{entry_path}"])
        }
      end)
    end

    manifest = %{
      "schema_version" => 2,
      "repo" => "szTheory/rindle",
      "pr" => 96,
      "prior_preserved_sha" => anchors.prior,
      "controller_correction_sha" => anchors.controller,
      "formatter_correction_sha" => anchors.formatter,
      "repair_sha" => anchors.repair,
      "preserved_subject_sha" => anchors.repair,
      "stages" => [
        %{
          "id" => "plan-132-12",
          "from_sha" => anchors.prior,
          "to_sha" => anchors.controller,
          "planning" => [],
          "non_planning" =>
            non_planning.(anchors.controller, [
              "scripts/ci/collect_pr_timing_receipt.sh",
              "test/install_smoke/ci_timing_automation_test.exs"
            ])
        },
        %{
          "id" => "plan-132-13",
          "from_sha" => anchors.controller,
          "to_sha" => anchors.formatter,
          "planning" => [%{"status" => "A", "path" => ".planning/formatter.md"}],
          "non_planning" =>
            non_planning.(anchors.formatter, ["test/install_smoke/ci_lane_split_test.exs"])
        },
        %{
          "id" => "plan-132-14-repair",
          "from_sha" => anchors.formatter,
          "to_sha" => anchors.repair,
          "planning" => [],
          "non_planning" =>
            non_planning.(anchors.repair, [
              "scripts/ci/collect_pr_timing_receipt.sh",
              "test/install_smoke/ci_timing_automation_test.exs"
            ])
        }
      ]
    }

    File.write!(
      path,
      "PRESERVATION_TRANSITION_V2_BEGIN\n#{Jason.encode!(manifest)}\nPRESERVATION_TRANSITION_V2_END\n"
    )
  end

  defp write_fixture_file!(repo_dir, relative_path, contents) do
    path = Path.join(repo_dir, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  defp commit_fixture!(repo_dir, message) do
    git!(repo_dir, ["add", "."])
    git!(repo_dir, ["commit", "--quiet", "-m", message])
    git!(repo_dir, ["rev-parse", "HEAD"])
  end

  defp git!(repo_dir, args) do
    {output, 0} = System.cmd("git", args, cd: repo_dir, stderr_to_stdout: true)
    String.trim(output)
  end

  defp write_gh_shim!(path) do
    File.write!(path, """
    #!/usr/bin/env bash
    set -euo pipefail
    : "${GH_FIXTURE_DIR:?}"
    : "${GH_EXPECTED_SHA:?}"
    : "${GH_EXPECTED_PR:?}"
    count_file="$GH_FIXTURE_DIR/count"
    label_file="$GH_FIXTURE_DIR/label"

    if [ "$1 $2" = "auth status" ]; then exit 0; fi
    if [ "$1 $2" = "label list" ]; then printf '%s\n' 'ci-timing-sample'; exit 0; fi

    if [ "$1 $2" = "pr view" ]; then
      jq -cn --arg sha "${GH_REMOTE_SHA:-$GH_EXPECTED_SHA}" '{state:"OPEN",isDraft:true,headRefName:"codex/v1.25-maintainer-craft",headRefOid:$sha}'
      exit 0
    fi

    if [ "$1 $2" = "pr edit" ]; then
      case " $* " in
        *" --add-label "*)
          count=$(cat "$count_file")
          count=$((count + 1))
          printf '%s\n' "$count" > "$count_file"
          printf '%s\n' present > "$label_file"
          ;;
        *" --remove-label "*) printf '%s\n' absent > "$label_file" ;;
      esac
      exit 0
    fi

    if [ "$1 $2" = "api rate_limit" ]; then
      : > "$GH_FIXTURE_DIR/rate-limit-reset-called"
      if [ "${GH_RATE_LIMIT_RESET_BLOCK:-}" = 1 ]; then sleep 30; fi
      printf '%s\n' '{"resources":{"core":{"reset":0}}}'
      exit 0
    fi

    if [ "$1" = api ]; then
      endpoint="${*: -1}"
      count=$(cat "$count_file")
      api_count_file="$GH_FIXTURE_DIR/api-count"
      api_count=$(cat "$api_count_file" 2>/dev/null || echo 0)
      api_count=$((api_count + 1))
      printf '%s\n' "$api_count" > "$api_count_file"
      if [ -n "${GH_RATE_LIMIT_ENDPOINT:-}" ] && [[ "$endpoint" == *"$GH_RATE_LIMIT_ENDPOINT"* ]] && [ "$api_count" -ge "${GH_RATE_LIMIT_AFTER:-1}" ]; then
        echo 'API rate limit exceeded' >&2
        exit 1
      fi
      case "$endpoint" in
        *actions/workflows/*/runs*)
          poll_file="$GH_FIXTURE_DIR/discovery-polls"
          polls=$(cat "$poll_file" 2>/dev/null || echo 0)
          if [ "$count" = 1 ] && [ -n "${GH_HIDE_RUN_POLLS:-}" ] && [ "$polls" -lt "$GH_HIDE_RUN_POLLS" ]; then
            printf '%s\n' "$((polls + 1))" > "$poll_file"
            jq -cn '[{workflow_runs: []}]'
            exit 0
          fi
          pages="$(jq -cn \
            --arg sha "$GH_EXPECTED_SHA" \
            --argjson pr "$GH_EXPECTED_PR" \
            --argjson count "$count" \
            '[{workflow_runs: [range(1; $count + 1) as $n | {
              id: (1000 + $n),
              event: "pull_request",
              head_sha: $sha,
              run_attempt: 1,
              status: "completed",
              conclusion: (if ((env.GH_FAIL_RUN_ID // "0") | tonumber) == (1000 + $n) then "failure" else "success" end),
              run_started_at: (1787616000 + (($n - 1) * 700) | todateiso8601),
              updated_at: (1787616400 + (($n - 1) * 700) | todateiso8601),
              html_url: ("https://github.com/szTheory/rindle/actions/runs/" + ((1000 + $n) | tostring)),
              pull_requests: [{number: $pr}]
            }]}]')"
          if [[ " $* " == *" --paginate "* ]] && [ -n "${GH_SECOND_PAGE:-}" ]; then
            jq -cn --argjson pages "$pages" --arg sha "$GH_EXPECTED_SHA" --argjson pr "$GH_EXPECTED_PR" '
              ($pages[0].workflow_runs | length) as $count |
              {id:9999,event:"pull_request",head_sha:(if env.GH_SECOND_PAGE == "qualifying" then $sha else "0000000000000000000000000000000000000000" end),run_attempt:1,status:"completed",conclusion:"success",run_started_at:(1787616000 + ($count * 700) | todateiso8601),updated_at:(1787616400 + ($count * 700) | todateiso8601),html_url:"https://github.com/szTheory/rindle/actions/runs/9999",pull_requests:[{number:$pr}]} as $second |
              $pages + [{workflow_runs:[$second]}]'
          else
            printf '%s\n' "$pages"
          fi
          ;;
        *actions/runs/*/jobs*)
          id="${endpoint#*actions/runs/}"
          id="${id%%/*}"
          n=$((id - 1000))
          conclusion=success
          if [ "${GH_FAIL_RUN_ID:-0}" = "$id" ]; then conclusion=failure; fi
          jq -cn --arg conclusion "$conclusion" --argjson n "$n" '
            ((env.GH_BOUNDARY_DURATIONS // "") | if . == "" then [] else split(",") | map(tonumber) end) as $durations |
            (if ($durations|length) >= $n then $durations[$n - 1] else 400 end) as $duration |
            [{name:"CI Summary",status:"completed",conclusion:(if env.GH_BAD_SUMMARY == "1" then "failure" else $conclusion end),completed_at:(1787616000 + (($n - 1) * 700) + $duration | todateiso8601)}] as $jobs |
            {jobs:(if env.GH_DUPLICATE_SUMMARY == "1" then $jobs + $jobs else $jobs end)}'
          ;;
        *actions/runs/*)
          id="${endpoint#*actions/runs/}"
          id="${id%%/*}"
          n=$((id - 1000))
          conclusion=success
          if [ "${GH_FAIL_RUN_ID:-0}" = "$id" ]; then conclusion=failure; fi
          status=completed
          if [ -n "${GH_RUN_STATUS_SEQUENCE:-}" ] && [ "$id" = 1001 ]; then
            status_count_file="$GH_FIXTURE_DIR/status-count"
            status_count=$(cat "$status_count_file" 2>/dev/null || echo 0)
            status=$(printf '%s' "$GH_RUN_STATUS_SEQUENCE" | cut -d, -f$((status_count + 1)))
            [ -n "$status" ] || status=completed
            printf '%s\n' "$((status_count + 1))" > "$status_count_file"
          fi
          jq -cn --arg sha "$GH_EXPECTED_SHA" --arg conclusion "$conclusion" --arg status "$status" --argjson id "$id" --argjson n "$n" '
            (1787616000 + (($n - 1) * (if env.GH_OVERLAP == "1" then 300 else 700 end))) as $started |
            {id:$id,event:(if env.GH_WRONG_EVENT == "1" then "push" else "pull_request" end),head_sha:(if env.GH_WRONG_HEAD == "1" then "0000000000000000000000000000000000000000" else $sha end),run_attempt:(if env.GH_WRONG_ATTEMPT == "1" then 2 else 1 end),status:$status,conclusion:(if $status == "completed" then $conclusion else null end),run_started_at:($started|todateiso8601),updated_at:($started + 400|todateiso8601),html_url:("https://github.com/szTheory/rindle/actions/runs/" + ($id | tostring))}'
          ;;
        *) echo "unexpected gh api endpoint: $endpoint" >&2; exit 2 ;;
      esac
      exit 0
    fi

    echo "unexpected gh invocation: $*" >&2
    exit 2
    """)

    File.chmod!(path, 0o755)
  end
end
