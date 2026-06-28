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
    Process.flag(:trap_exit, true)

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
    Process.flag(:trap_exit, true)

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

  # (3) Real-subprocess stress — owns EPIPE-04 (fails unpatched / passes patched).
  # `yes | head -n 100000` maximizes ACK-after-close chunks → maximizes the #98 race window.
  # use_cgroups: false is mandatory — CI and macOS have no cgroup mount (Pitfall 4).
  @tag :regression
  @tag :av
  test "run/3 never lets a broken-pipe (:epipe) exit kill the caller, even on large output" do
    Process.flag(:trap_exit, true)

    results =
      for _ <- 1..300 do
        Subprocess.run("sh", ["-c", "yes | head -n 100000"], use_cgroups: false)
      end

    assert length(results) == 300

    assert Enum.all?(results, fn
             {_out, status} when is_integer(status) -> true
             _ -> false
           end)

    refute_received {:EXIT, _, :epipe}
  end
end
