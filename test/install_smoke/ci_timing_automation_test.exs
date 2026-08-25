defmodule Rindle.InstallSmoke.CiTimingAutomationTest do
  use ExUnit.Case, async: false

  @script Path.expand("../../scripts/ci/collect_pr_timing_receipt.sh", __DIR__)

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-ci-timing-#{System.unique_integer([:positive])}"
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
    assert receipt =~ "CI_TIMING_SOURCE_BEGIN"
    assert receipt =~ "CI_TIMING_TABLE_BEGIN"
    assert receipt =~ "Verdict | PASS"
    assert count(receipt, "https://github.com/szTheory/rindle/actions/runs/") == 10
    assert File.read!(Path.join(context.fixture_dir, "label")) == "absent\n"

    assert {verify_output, 0} =
             System.cmd("bash", [@script, "verify", "--receipt", context.receipt],
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

  test "verify rejects a partial receipt", context do
    File.write!(context.receipt, """
    #{context.baseline}
    CI_TIMING_TABLE_BEGIN
    | Sequence | Run ID | Source | Started (UTC) | Duration seconds |
    | ---: | ---: | --- | --- | ---: |
    CI_TIMING_TABLE_END
    CI_TIMING_SOURCE_BEGIN
    {"sha":"#{context.head}","runs":[],"median_seconds":0,"p95_seconds":0}
    CI_TIMING_SOURCE_END
    """)

    assert {output, 1} =
             System.cmd("bash", [@script, "verify", "--receipt", context.receipt],
               env: controller_env(context),
               stderr_to_stdout: true
             )

    assert output =~ "exactly 10 runs"
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

  defp manifest!(receipt) do
    [_, body] = String.split(File.read!(receipt), "CI_TIMING_SOURCE_BEGIN\n", parts: 2)
    [json | _] = String.split(body, "\nCI_TIMING_SOURCE_END", parts: 2)
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
          jq -cn --arg conclusion "$conclusion" --argjson n "$n" '{jobs:[{name:"CI Summary",status:"completed",conclusion:$conclusion,completed_at:(1787616400 + (($n - 1) * 700) | todateiso8601)}]}'
          ;;
        *actions/runs/*)
          id="${endpoint#*actions/runs/}"
          id="${id%%/*}"
          n=$((id - 1000))
          conclusion=success
          if [ "${GH_FAIL_RUN_ID:-0}" = "$id" ]; then conclusion=failure; fi
          jq -cn --arg sha "$GH_EXPECTED_SHA" --arg conclusion "$conclusion" --argjson id "$id" --argjson n "$n" '{id:$id,event:"pull_request",head_sha:$sha,run_attempt:1,status:"completed",conclusion:$conclusion,run_started_at:(1787616000 + (($n - 1) * 700) | todateiso8601),updated_at:(1787616400 + (($n - 1) * 700) | todateiso8601),html_url:("https://github.com/szTheory/rindle/actions/runs/" + ($id | tostring))}'
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
