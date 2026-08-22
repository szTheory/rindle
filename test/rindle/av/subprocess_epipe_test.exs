defmodule Rindle.AV.SubprocessEpipeTest do
  # async: false — spawns OS processes (ffmpeg_test.exs:2 precedent).
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Rindle.AV.Subprocess

  # (1) Deterministic synthetic — drain-after-reply absorption (EPIPE-01/05).
  # No subprocess, zero OS race: inject a run_fun that returns the real {output, status}
  # AND fires a terminal {:EXIT, port, :epipe} into the worker's mailbox so the worker's
  # `after 0` drain + the parent's demonitor [:flush] both run deterministically.
  @tag :regression
  @tag :av
  test "run_isolated absorbs a terminal :epipe and still returns the real {output, status}" do
    fake_port =
      case Port.list() do
        [port | _] -> port
        [] -> :erlang.open_port({:spawn, "true"}, [:binary])
      end

    run_fun = fn _cmd, _args, _opts ->
      # Runs inside the worker process — self() is the worker's mailbox, which the drain reads.
      send(self(), {:EXIT, fake_port, :epipe})
      {"OK", 0}
    end

    assert {"OK", 0} =
             Subprocess.run_isolated("echo", ["x"], [], 1, run_fun)

    # The caller survived and no stray :epipe leaked into our mailbox.
    refute_received {:EXIT, _, :epipe}
  end

  # (2) Deterministic synthetic — pre-reply retry branch (D-05 bounded single retry + D-07 log).
  # The first call exit(:epipe)s BEFORE replying; the single bounded retry succeeds. Exactly one
  # Logger.debug citing #98 is emitted on the retry branch.
  @tag :regression
  @tag :av
  test "run_isolated retries exactly once on a pre-reply :epipe death and emits one #98 breadcrumb" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    run_fun = fn _cmd, _args, _opts ->
      n = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      if n == 0 do
        exit(:epipe)
      else
        {"OK", 0}
      end
    end

    # Ensure :debug records survive the primary Logger level filter for this module,
    # independent of the global level (the breadcrumb is emitted at :debug, D-07).
    Logger.put_module_level(Rindle.AV.Subprocess, :debug)
    on_exit(fn -> Logger.delete_module_level(Rindle.AV.Subprocess) end)

    log =
      capture_log([level: :debug], fn ->
        assert {"OK", 0} =
                 Subprocess.run_isolated("echo", ["x"], [], 1, run_fun)
      end)

    # Bounded: exactly two invocations (initial + single retry), never an infinite loop.
    assert Agent.get(counter, & &1) == 2
    Agent.stop(counter)

    # Exactly one breadcrumb citing #98 was emitted on the retry branch.
    assert log =~ "muontrap/issues/98"

    epipe_lines =
      log
      |> String.split("\n")
      |> Enum.count(&String.contains?(&1, "absorbed a pre-reply MuonTrap #98 :epipe"))

    assert epipe_lines == 1

    refute_received {:EXIT, _, :epipe}
  end

  @tag :regression
  @tag :av
  test "run_isolated bounds and retries a worker that never replies" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    run_fun = fn _cmd, _args, _opts ->
      Agent.update(counter, &(&1 + 1))
      Process.sleep(:infinity)
    end

    assert {"", :timeout} =
             Subprocess.run_isolated("blocked", [], [timeout: 10], 1, run_fun)

    assert Agent.get(counter, & &1) == 2
  end

  @tag :regression
  @tag :av
  test "run_isolated retries MuonTrap's port-close timeout race once" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    run_fun = fn _cmd, _args, _opts ->
      n = Agent.get_and_update(counter, fn count -> {count, count + 1} end)

      if n == 0 do
        exit({%ArgumentError{}, [{:erlang, :port_close, [], []}]})
      else
        {"OK", 0}
      end
    end

    assert {"OK", 0} =
             Subprocess.run_isolated("ffmpeg", [], [timeout: 10], 1, run_fun)

    assert Agent.get(counter, & &1) == 2
  end

  @tag :regression
  @tag :av
  test "run_isolated returns a bounded timeout when the port-close retry is exhausted" do
    run_fun = fn _cmd, _args, _opts ->
      exit({:badarg, [{:erlang, :port_close, 1, []}]})
    end

    assert {"", :timeout} =
             Subprocess.run_isolated("ffmpeg", [], [timeout: 10], 1, run_fun)
  end

  @tag :regression
  @tag :av
  test "run_isolated still fails loudly for unrelated worker exceptions" do
    run_fun = fn _cmd, _args, _opts -> exit(%ArgumentError{message: "unrelated"}) end

    assert catch_exit(Subprocess.run_isolated("ffmpeg", [], [timeout: 10], 1, run_fun)) ==
             %ArgumentError{message: "unrelated"}
  end

  # (3) Real-subprocess stress — advisory-only because it deliberately amplifies
  # a probabilistic OS race. The deterministic synthetic tests above remain in
  # the merge gate; nightly opts this probe back in alongside the raw canary.
  # `yes | head -n 100000` maximizes ACK-after-close chunks → maximizes the #98
  # race window. use_cgroups: false is mandatory in CI and on macOS.
  @tag :canary
  @tag :regression
  @tag :av
  @tag timeout: 60_000
  test "run/3 never lets a broken-pipe (:epipe) exit kill the caller, even on large output" do
    results =
      for _ <- 1..300 do
        Subprocess.run("sh", ["-c", "yes | head -n 100000"],
          use_cgroups: false,
          timeout: 5_000
        )
      end

    assert length(results) == 300

    assert Enum.all?(results, fn
             {_out, status} when is_integer(status) or status == :timeout -> true
             _ -> false
           end)

    refute_received {:EXIT, _, :epipe}
  end
end
