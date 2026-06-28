defmodule Rindle.Test.CountingFailingTxnRepo do
  @moduledoc false

  @count_key {__MODULE__, :transaction_count}
  @config_key {__MODULE__, :fail_config}

  def with_counting_repo(fail_after, fun) when is_integer(fail_after) and is_function(fun, 0) do
    Rindle.Config.put_repo_override(__MODULE__)
    Process.put(@config_key, fail_after: fail_after)
    reset_count()

    try do
      fun.()
    after
      Rindle.Config.delete_repo_override()
      Process.delete(@config_key)
      reset_count()
    end
  end

  # The reason this double exists: deterministically fail the Nth transaction so batch/erasure
  # code paths can be tested against a mid-run transaction failure. Everything else MUST behave
  # exactly like the real repo.
  def transaction(fun) when is_function(fun, 0) do
    if next_count() == fail_after() do
      {:error, :plan, fail_reason(), %{}}
    else
      Rindle.Repo.transaction(fun)
    end
  end

  def transaction(multi) do
    if next_count() == fail_after() do
      {:error, :plan, fail_reason(), %{}}
    else
      Rindle.Repo.transaction(multi)
    end
  end

  def transaction(fun, opts) when is_function(fun, 0) do
    if next_count() == fail_after() do
      {:error, :plan, fail_reason(), %{}}
    else
      Rindle.Repo.transaction(fun, opts)
    end
  end

  def transaction(multi, opts) do
    if next_count() == fail_after() do
      {:error, :plan, fail_reason(), %{}}
    else
      Rindle.Repo.transaction(multi, opts)
    end
  end

  # `with_counting_repo/2` installs this module as a PROCESS-LOCAL repo override (via
  # `Rindle.Config.put_repo_override/1`, not a global `:rindle, :repo` swap) for the duration of its
  # callback, so only the calling process (and its `$callers`-linked children) resolving
  # `Rindle.Config.repo()` dispatches through here — a concurrent async reader in another process
  # tree is unaffected. It must still proxy the ENTIRE Ecto.Repo surface, not a hand-maintained
  # subset — a missing function surfaces as an intermittent
  # `(UndefinedFunctionError) Rindle.Test.CountingFailingTxnRepo.<fn> is undefined` in any code that
  # resolves the override (get_by/2, exists?/1, config/0, … each bit us in turn). Generate a
  # passthrough for every Rindle.Repo function except transaction/1,2 (overridden above), so
  # completeness is guaranteed by construction rather than by audit.
  for {fun, arity} <- Rindle.Repo.__info__(:functions),
      {fun, arity} not in [transaction: 1, transaction: 2] do
    args = Macro.generate_arguments(arity, __MODULE__)

    def unquote(fun)(unquote_splicing(args)) do
      apply(Rindle.Repo, unquote(fun), [unquote_splicing(args)])
    end
  end

  defp next_count do
    count = Process.get(@count_key, 0) + 1
    Process.put(@count_key, count)
    count
  end

  defp reset_count, do: Process.delete(@count_key)

  defp fail_after do
    Process.get(@config_key, [])
    |> Keyword.get(:fail_after)
  end

  defp fail_reason do
    Process.get(@config_key, [])
    |> Keyword.get(:fail_reason, :forced_batch_failure)
  end
end
