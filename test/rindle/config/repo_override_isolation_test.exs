defmodule Rindle.Config.RepoOverrideIsolationTest do
  # ISO-05 concurrency proof (Phase 110, research §8).
  #
  # This is the executable, held-out proof that the counting double's repo override is
  # PROCESS-SCOPED, not global. It locks the old→new delta the milestone delivers:
  #
  #   * OLD impl — `with_counting_repo/2` did `Application.put_env(:rindle, :repo, double)`,
  #     a GLOBAL swap. A concurrent reader in any other process would resolve the double and
  #     its transaction would force-fail → this test would be RED.
  #   * NEW impl (Plan 01 resolver + Plan 02 process-scoped double) — the override lives in the
  #     calling process's dictionary (visible only down its own `$callers` tree), so an unrelated
  #     process reading `Config.repo()` still sees `Rindle.Repo` → this test is GREEN.
  #
  # Process A (the `with_counting_repo/1` callback's process) force-fails its 1st transaction
  # and sees the double. Process B is an UNRELATED reader created with bare `spawn`, so it has
  # no `$callers` ancestry from A. A only releases B after its override is open, and B acknowledges
  # that release before it resolves `Rindle.Repo` and commits. Repeating that causal window with
  # distinct refs makes one focused invocation a bounded 100-iteration stress proof.
  #
  # The module is `async: true`: it is itself the canonical async-safe demonstration, and any
  # future regression that re-globalizes the repo swap makes B observe the double and turns this
  # test RED — the un-droppable lock on the isolation property (threat T-110-06).
  use Rindle.DataCase, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Config
  alias Rindle.Test.CountingFailingTxnRepo

  test "process-scoped override does not pollute a concurrent reader in an unrelated process tree" do
    for iteration <- 1..100 do
      assert_causal_isolation(iteration)
    end
  end

  defp assert_causal_isolation(iteration) do
    test_pid = self()
    release_ref = make_ref()
    result_ref = make_ref()

    # Bare spawn deliberately creates no $callers ancestry from A. The monitor lets the test stop
    # a blocked reader if an assertion fails before release.
    {reader, monitor} =
      spawn_monitor(fn ->
        receive do
          {:release, ^release_ref} ->
            send(test_pid, {:reader_released, release_ref, self()})

            result = {Config.repo(), Config.repo().transaction(fn -> :ok end)}
            send(test_pid, {:reader_result, result_ref, self(), result})
        end
      end)

    Sandbox.allow(Rindle.Repo, test_pid, reader)

    try do
      CountingFailingTxnRepo.with_counting_repo(1, fn ->
        # A owns the open override window and B cannot move past this point before that window.
        assert Config.repo() == Rindle.Test.CountingFailingTxnRepo,
               "iteration #{iteration}: A did not resolve the counting double"

        assert match?(
                 {:error, :plan, _reason, %{}},
                 Config.repo().transaction(fn -> :ok end)
               ),
               "iteration #{iteration}: A did not force-fail its transaction"

        send(reader, {:release, release_ref})

        assert_receive {:reader_released, ^release_ref, ^reader},
                       1_000,
                       "iteration #{iteration}: B was not released while A's override remained open"

        assert_receive {:reader_result, ^result_ref, ^reader, {Rindle.Repo, {:ok, :ok}}},
                       1_000,
                       "iteration #{iteration}: unrelated B did not resolve Rindle.Repo and commit"
      end)
    after
      if Process.alive?(reader), do: Process.exit(reader, :kill)

      Process.demonitor(monitor, [:flush])
    end
  end
end
