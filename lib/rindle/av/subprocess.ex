defmodule Rindle.AV.Subprocess do
  @moduledoc """
  MuonTrap execution wrapper + 4-cap enforcement.
  """

  require Logger

  @cgroup_base "rindle_av"
  @port_check_ms 200
  @dead_port_grace_ms 100
  # Just under the wrapper's C int ceiling; output never gets near it.
  @ack_free_window 2_000_000_000

  @doc """
  Runs a command wrapped in MuonTrap with configured cgroups and 4-cap limits.
  """
  def run(cmd, args, opts \\ []) do
    opts = Keyword.put_new(opts, :use_cgroups, default_use_cgroups?())
    muon_opts = build_opts(opts)
    modified_args = build_args(cmd, args, opts)
    run_isolated(cmd, modified_args, muon_opts, 1, &ack_free_cmd/3)
  end

  # NOTE (MuonTrap #98, ACK-free): MuonTrap.cmd/3 acknowledges every stdout chunk by writing to
  # the wrapper's stdin. When the wrapper exits right after the child, that last write fails, the
  # port dies with :epipe and its {:exit_status, _} is never delivered, so the call is lost. On
  # Linux runners this hits short commands routinely. This is MuonTrap.Port.cmd/1 minus the ACKs:
  # the same wrapper binary and port options, but a window too large to run dry, so nothing is
  # ever written to the port and the exit status always arrives. The child still inherits that
  # (now silent) stdin pipe; build_args/3 keeps `-nostdin` on ffmpeg regardless.
  # Removal condition: #98 fixed AND the :muontrap pin bumped; the canaries in
  # test/rindle/av/subprocess_epipe_canary_test.exs and subprocess_stdin_test.exs are the signal.
  @doc false
  def ack_free_cmd(cmd, args, muon_opts) do
    options =
      MuonTrap.Options.validate(
        :cmd,
        cmd,
        args,
        Keyword.put(muon_opts, :stdio_window, @ack_free_window)
      )

    port_opts = MuonTrap.Port.port_options(options, ["--capture-output"])
    {initial, collector} = Collectable.into(options.into)
    timeout_message = {:timeout, make_ref()}
    timer = start_timer(options[:timeout], timeout_message)

    try do
      port = Port.open({:spawn_executable, to_charlist(MuonTrap.muontrap_path())}, port_opts)
      collect_port(port, initial, collector, timeout_message)
    catch
      kind, reason ->
        collector.(initial, :halt)
        :erlang.raise(kind, reason, __STACKTRACE__)
    else
      {acc, status} -> {collector.(acc, :done), status}
    after
      cancel_timer(timer, timeout_message)
    end
  end

  defp collect_port(port, acc, collector, timeout_message) do
    receive do
      {^port, {:data, data}} ->
        collect_port(port, collector.(acc, {:cont, data}), collector, timeout_message)

      {^port, {:exit_status, status}} ->
        {acc, status}

      ^timeout_message ->
        close_port(port)
        {acc, :timeout}
    end
  end

  defp close_port(port) do
    Port.close(port)
  rescue
    ArgumentError -> :ok
  end

  defp start_timer(timeout, message) when is_integer(timeout),
    do: Process.send_after(self(), message, timeout)

  defp start_timer(_timeout, _message), do: nil

  defp cancel_timer(nil, _message), do: :ok

  defp cancel_timer(timer, message) do
    _ = Process.cancel_timer(timer)

    receive do
      ^message -> :ok
    after
      0 -> :ok
    end
  end

  # NOTE (MuonTrap #98): https://github.com/fhunleth/muontrap/issues/98 (OPEN as of
  # 2026-06; reproduces in 1.7.0 / 1.8.0 / 2.0.0-rc.0). MuonTrap ACKs consumed stdout bytes by
  # writing to its wrapper's stdin (port.ex report_bytes_handled/2 -> Port.command/2). When the
  # child closes after the last chunk, that ACK write hits a dead reader and the port delivers an
  # async {:EXIT, port, :epipe} to its OWNER. MuonTrap's `rescue ArgumentError` catches only the
  # synchronous failure; this async exit kills the inline caller. We own the port in a throwaway
  # trap_exit'd worker so the signal dies with the worker, and surface the real {output, status}.
  # Removal condition: #98 fixed AND the :muontrap pin bumped to the fixed version. The live signal
  # is test/rindle/av/subprocess_epipe_canary_test.exs — do NOT delete that canary without deleting
  # this shim.
  #
  # `run_fun` is a test seam (default &ack_free_cmd/3); it lets the deterministic regression test
  # drive the absorption path with no OS race. run/3 never passes it, so the public contract is
  # byte-identical.
  @doc false
  def run_isolated(cmd, args, muon_opts, retries_left, run_fun) do
    parent = self()
    ref = make_ref()

    {pid, mon} =
      spawn_monitor(fn ->
        Process.flag(:trap_exit, true)
        result = run_fun.(cmd, args, muon_opts)
        send(parent, {ref, result})
        # Drain a possible late {:EXIT, port, :epipe} so it can't escape the worker.
        receive do
          {:EXIT, port, _reason} when is_port(port) -> :ok
        after
          0 -> :ok
        end
      end)

    deadline = System.monotonic_time(:millisecond) + watchdog_timeout(muon_opts)
    await_worker(pid, mon, ref, deadline, {cmd, args, muon_opts, retries_left, run_fun})
  end

  # A #98 :epipe can also kill the port mid-call, before MuonTrap sees {:exit_status, _}. The
  # trap_exit'd worker then just holds {:EXIT, port, :epipe} in its mailbox while MuonTrap's
  # receive waits for an exit status that never comes, so the call would sit until the MuonTrap
  # timeout (600 s by default). Poll for that dead-port state and retry like a pre-reply :epipe.
  defp await_worker(pid, mon, ref, deadline, {cmd, args, muon_opts, retries_left, run_fun} = call) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^ref, result} ->
        Process.demonitor(mon, [:flush])
        result

      {:DOWN, ^mon, :process, ^pid, :epipe} when retries_left > 0 ->
        Logger.debug(
          "Rindle.AV.Subprocess: absorbed a pre-reply MuonTrap #98 :epipe exit; retrying the AV call once " <>
            "(see https://github.com/fhunleth/muontrap/issues/98)"
        )

        run_isolated(cmd, args, muon_opts, retries_left - 1, run_fun)

      {:DOWN, ^mon, :process, ^pid, reason} ->
        cond do
          muontrap_timeout_race?(reason) and retries_left > 0 ->
            Logger.warning(
              "Rindle.AV.Subprocess: MuonTrap closed its port at the command timeout; retrying the AV call once"
            )

            run_isolated(cmd, args, muon_opts, retries_left - 1, run_fun)

          muontrap_timeout_race?(reason) ->
            {"", :timeout}

          true ->
            exit(reason)
        end
    after
      min(remaining, @port_check_ms) ->
        cond do
          remaining == 0 ->
            terminate_worker(pid, mon, ref)

            if retries_left > 0 do
              Logger.warning(
                "Rindle.AV.Subprocess: MuonTrap worker exceeded its command timeout; retrying the AV call once"
              )

              run_isolated(cmd, args, muon_opts, retries_left - 1, run_fun)
            else
              {"", :timeout}
            end

          port_died_before_exit_status?(pid) ->
            handle_dead_port(pid, mon, ref, deadline, call)

          true ->
            await_worker(pid, mon, ref, deadline, call)
        end
    end
  end

  defp handle_dead_port(
         pid,
         mon,
         ref,
         deadline,
         {cmd, args, muon_opts, retries_left, run_fun} = call
       ) do
    # A late :epipe can land just after MuonTrap returned; give the worker a moment to reply.
    receive do
      {^ref, result} ->
        Process.demonitor(mon, [:flush])
        result
    after
      @dead_port_grace_ms ->
        if port_died_before_exit_status?(pid) do
          terminate_worker(pid, mon, ref)

          if retries_left > 0 do
            Logger.warning(
              "Rindle.AV.Subprocess: MuonTrap port died before its exit status (#98 :epipe); " <>
                "retrying the AV call once (see https://github.com/fhunleth/muontrap/issues/98)"
            )

            run_isolated(cmd, args, muon_opts, retries_left - 1, run_fun)
          else
            exit(:epipe)
          end
        else
          await_worker(pid, mon, ref, deadline, call)
        end
    end
  end

  defp port_died_before_exit_status?(pid) do
    case Process.info(pid, :messages) do
      {:messages, messages} ->
        Enum.any?(messages, fn
          {:EXIT, port, reason} when is_port(port) -> reason != :normal
          _other -> false
        end)

      nil ->
        false
    end
  end

  defp watchdog_timeout(muon_opts) do
    Keyword.get(muon_opts, :timeout, 600_000) + 250
  end

  # MuonTrap 1.7 can race its timeout cleanup: the port is already closed when
  # MuonTrap.Port.do_cmd/4 calls :erlang.port_close/1, so the worker exits
  # instead of returning a timeout tuple. OTP releases wrap that exception
  # differently, so match the invariant stack entry anywhere in the monitored
  # reason. Unrelated worker exceptions still fail loudly.
  defp muontrap_timeout_race?(reason), do: contains_port_close?(reason)

  defp contains_port_close?({:erlang, :port_close, _args, _metadata}), do: true

  defp contains_port_close?(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.any?(&contains_port_close?/1)
  end

  defp contains_port_close?(list) when is_list(list),
    do: Enum.any?(list, &contains_port_close?/1)

  defp contains_port_close?(_other), do: false

  defp terminate_worker(pid, mon, ref) do
    Process.exit(pid, :kill)

    receive do
      {:DOWN, ^mon, :process, ^pid, _reason} -> :ok
    end

    receive do
      {^ref, _late_result} -> :ok
    after
      0 -> :ok
    end
  end

  defp default_use_cgroups? do
    env = System.get_env("RINDLE_AV_USE_CGROUPS")

    cond do
      env in ["0", "false", "FALSE"] -> false
      env in ["1", "true", "TRUE"] -> true
      true -> Application.get_env(:rindle, __MODULE__, [])[:use_cgroups] != false
    end
  end

  @doc false
  def build_opts(opts) do
    opts = Keyword.put_new(opts, :use_cgroups, default_use_cgroups?())
    timeout = Keyword.get(opts, :timeout, Keyword.get(opts, :max_wall_ms, default_timeout()))
    base = [into: "", stderr_to_stdout: true, timeout: timeout]

    if :os.type() == {:unix, :linux} and Keyword.get(opts, :use_cgroups, true) do
      cgroup_sets = [
        {"memory", "memory.limit_in_bytes", "536870912"},
        {"cpu", "cpu.cfs_period_us", "100000"},
        {"cpu", "cpu.cfs_quota_us", "50000"}
      ]

      base ++
        [
          cgroup_controllers: ["memory", "cpu"],
          cgroup_base: @cgroup_base,
          cgroup_sets: cgroup_sets
        ]
    else
      base
    end
  end

  defp default_timeout do
    Application.get_env(:rindle, __MODULE__, [])
    |> Keyword.get(:timeout, 600_000)
  end

  @doc false
  def build_args("ffmpeg", args, opts) do
    max_cpu_seconds = Keyword.get(opts, :max_cpu_seconds, 300)
    max_duration_seconds = Keyword.get(opts, :max_duration_seconds, 7200)
    max_output_bytes = Keyword.get(opts, :max_output_bytes, 500_000_000)

    # -nostdin: MuonTrap leaves the child's stdin on the pipe the BEAM writes stdout ACKs to.
    # ffmpeg polls stdin for keyboard commands and would eat those ACKs, starving MuonTrap's
    # flow-control window until the call stalls at its timeout (see
    # test/rindle/av/subprocess_stdin_test.exs).
    common = [
      "-nostdin",
      "-protocol_whitelist",
      "file,crypto,data",
      "-timelimit",
      Integer.to_string(max_cpu_seconds),
      "-t",
      Integer.to_string(max_duration_seconds)
    ]

    case List.pop_at(args, -1) do
      {destination, input_and_output_args} when is_binary(destination) ->
        common ++
          input_and_output_args ++ ["-fs", Integer.to_string(max_output_bytes), destination]

      _ ->
        common ++ args
    end
  end

  def build_args(_cmd, args, _opts), do: args
end
