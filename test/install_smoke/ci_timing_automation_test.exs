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

    on_exit(fn -> File.rm_rf!(root) end)

    %{
      root: root,
      bin: bin,
      state_dir: state_dir,
      fixture_dir: fixture_dir,
      receipt: receipt,
      baseline: baseline,
      head: String.trim(System.cmd("git", ["rev-parse", "HEAD"]) |> elem(0))
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

  test "resumes a discovered run without triggering a duplicate", context do
    File.write!(Path.join(context.fixture_dir, "count"), "1\n")

    state_file = Path.join(context.state_dir, "pr-96-#{context.head}.json")

    File.write!(
      state_file,
      Jason.encode!(%{
        schema_version: 1,
        repo: "szTheory/rindle",
        pr: 96,
        sha: context.head,
        label: "ci-timing-sample",
        max_sequences: 2,
        sequence_attempt: 1,
        status: "running",
        runs: [],
        current_run_id: 1001,
        errors: []
      })
    )

    assert {output, 0} = run_controller(context)
    assert output =~ "resuming discovered sample 1/10 as run 1001"

    manifest = manifest!(context.receipt)
    assert Enum.map(manifest["runs"], & &1["id"]) == Enum.to_list(1001..1010)
    assert String.trim(File.read!(Path.join(context.fixture_dir, "count"))) == "10"
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

  test "controller bounds workflow-list API use and backs off on rate limits" do
    source = File.read!(@script)

    refute source =~ "gh api --paginate"
    assert source =~ "per_page=100"
    assert source =~ "branch=${encoded_head_ref}"
    assert source =~ "GitHub API rate limited; retrying"
    assert source =~ "gh_api_json"
  end

  test "controller permits the preserved formatting-only cache-hygiene proof" do
    source = File.read!(@script)

    assert source =~ "test/install_smoke/ci_cache_hygiene_test\\.exs"
  end

  defp run_controller(context, extra_env \\ []) do
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
      "2",
      "--median-max",
      "480",
      "--p95-max",
      "600",
      "--correction-sha",
      context.head,
      "--preserved-subject-sha",
      context.head,
      "--receipt",
      context.receipt,
      "--state-dir",
      context.state_dir,
      "--no-publish",
      "--poll-seconds",
      "0"
    ]

    System.cmd("bash", [@script | args],
      env: controller_env(context) ++ extra_env,
      stderr_to_stdout: true
    )
  end

  defp controller_env(context) do
    [
      {"PATH", context.bin <> ":" <> System.get_env("PATH", "")},
      {"GH_FIXTURE_DIR", context.fixture_dir},
      {"GH_EXPECTED_SHA", context.head},
      {"GH_EXPECTED_PR", "96"}
    ]
  end

  defp verify_args(context) do
    [
      @script,
      "verify",
      "--repo",
      "szTheory/rindle",
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
      "--receipt",
      context.receipt
    ]
  end

  defp manifest!(receipt) do
    [_, body] = String.split(File.read!(receipt), "CI_TIMING_CURRENT_SOURCE_BEGIN\n", parts: 2)
    [json | _] = String.split(body, "\nCI_TIMING_CURRENT_SOURCE_END", parts: 2)
    Jason.decode!(json)
  end

  defp count(haystack, needle), do: length(String.split(haystack, needle)) - 1

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
      jq -cn --arg sha "$GH_EXPECTED_SHA" '{state:"OPEN",isDraft:true,headRefName:"codex/v1.25-maintainer-craft",headRefOid:$sha}'
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

    if [ "$1" = api ]; then
      endpoint="${*: -1}"
      count=$(cat "$count_file")
      case "$endpoint" in
        *actions/workflows/*/runs*)
          jq -cn \
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
            }]}]'
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
          jq -cn --arg sha "$GH_EXPECTED_SHA" --arg conclusion "$conclusion" --argjson id "$id" --argjson n "$n" '
            (1787616000 + (($n - 1) * (if env.GH_OVERLAP == "1" then 300 else 700 end))) as $started |
            {id:$id,event:(if env.GH_WRONG_EVENT == "1" then "push" else "pull_request" end),head_sha:(if env.GH_WRONG_HEAD == "1" then "0000000000000000000000000000000000000000" else $sha end),run_attempt:(if env.GH_WRONG_ATTEMPT == "1" then 2 else 1 end),status:"completed",conclusion:$conclusion,run_started_at:($started|todateiso8601),updated_at:($started + 400|todateiso8601),html_url:("https://github.com/szTheory/rindle/actions/runs/" + ($id | tostring))}'
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
