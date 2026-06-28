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
  # and sees the double. Process B is an UNRELATED reader: it is a `Task.async` spawned from the
  # TEST process BEFORE entering A's window, so its `$callers` chain is the test process — NOT A.
  # The test process holds no override (A's override is set only inside the callback), so B
  # resolves `Rindle.Repo` and runs a real transaction successfully WHILE A's window is open.
  # If B were spawned from inside the window (a `$callers` descendant of A) it would correctly
  # inherit the override and the proof would be inverted — so it deliberately is not.
  #
  # The module is `async: true`: it is itself the canonical async-safe demonstration, and any
  # future regression that re-globalizes the repo swap makes B observe the double and turns this
  # test RED — the un-droppable lock on the isolation property (threat T-110-06).
  use Rindle.DataCase, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Config
  alias Rindle.Test.CountingFailingTxnRepo

  test "process-scoped override does not pollute a concurrent reader in an unrelated process tree" do
    test_pid = self()

    # Process A is THIS (test) process: with_counting_repo/2 runs its callback inline and sets the
    # override in the caller's process dictionary. So reader B must NOT have the test process in its
    # $callers chain — otherwise it would inherit A's override and the proof would be inverted.
    #
    # A bare `spawn` (unlike Task.async) injects NO `:"$callers"`, so B is a genuinely unrelated
    # process tree: its dict has no override and walks to no caller holding one → it resolves
    # Rindle.Repo. B blocks on :go so it reads Config.repo() and runs its real transaction
    # concurrently INSIDE A's open window. B needs an explicit Sandbox allowance (it shares no
    # ownership lineage with A) to run a real transaction against the sandboxed repo.
    reader =
      spawn(fn ->
        receive do
          :go -> :ok
        end

        result = {Config.repo(), Config.repo().transaction(fn -> :ok end)}
        send(test_pid, {:reader_result, self(), result})
      end)

    # Grant B access to A's sandbox connection so its real transaction can run.
    Sandbox.allow(Rindle.Repo, test_pid, reader)

    CountingFailingTxnRepo.with_counting_repo(1, fn ->
      # Process A: the override is active here and the 1st transaction force-fails.
      assert Config.repo() == Rindle.Test.CountingFailingTxnRepo
      assert {:error, :plan, _reason, %{}} = Config.repo().transaction(fn -> :ok end)

      # Release B so it reads the resolver and runs its real transaction inside A's window.
      send(reader, :go)

      # B (unpolluted) resolves the REAL repo and its transaction succeeds, concurrently with A.
      assert_receive {:reader_result, ^reader, {Rindle.Repo, {:ok, :ok}}}
    end)
  end
end
