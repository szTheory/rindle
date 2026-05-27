defmodule Rindle.Test.CountingFailingTxnRepo do
  @moduledoc false

  @count_key {__MODULE__, :transaction_count}

  def with_counting_repo(fail_after, fun) when is_integer(fail_after) and is_function(fun, 0) do
    previous_repo = Application.get_env(:rindle, :repo)
    previous_cfg = Application.get_env(:rindle, :counting_failing_txn_repo)

    Application.put_env(:rindle, :repo, __MODULE__)
    Application.put_env(:rindle, :counting_failing_txn_repo, fail_after: fail_after)
    reset_count()

    try do
      fun.()
    after
      restore_env(:repo, previous_repo)
      restore_env(:counting_failing_txn_repo, previous_cfg)
      reset_count()
    end
  end

  def transaction(fun) when is_function(fun, 0) do
    case next_count() do
      n when n == fail_after() ->
        {:error, :plan, fail_reason(), %{}}

      _ ->
        Rindle.Repo.transaction(fun)
    end
  end

  def transaction(multi) do
    case next_count() do
      n when n == fail_after() ->
        {:error, :plan, fail_reason(), %{}}

      _ ->
        Rindle.Repo.transaction(multi)
    end
  end

  def all(queryable), do: Rindle.Repo.all(queryable)
  def one(queryable), do: Rindle.Repo.one(queryable)
  def get(schema, id), do: Rindle.Repo.get(schema, id)
  def get!(schema, id), do: Rindle.Repo.get!(schema, id)
  def insert(changeset), do: Rindle.Repo.insert(changeset)
  def insert!(changeset), do: Rindle.Repo.insert!(changeset)
  def update(changeset), do: Rindle.Repo.update(changeset)
  def update!(changeset), do: Rindle.Repo.update!(changeset)
  def delete(struct), do: Rindle.Repo.delete(struct)
  def delete!(struct), do: Rindle.Repo.delete!(struct)
  def preload(struct_or_structs, preloads), do: Rindle.Repo.preload(struct_or_structs, preloads)

  defp next_count do
    count = Process.get(@count_key, 0) + 1
    Process.put(@count_key, count)
    count
  end

  defp reset_count, do: Process.delete(@count_key)

  defp fail_after do
    Application.get_env(:rindle, :counting_failing_txn_repo, [])
    |> Keyword.get(:fail_after)
  end

  defp fail_reason do
    Application.get_env(:rindle, :counting_failing_txn_repo, [])
    |> Keyword.get(:fail_reason, :forced_batch_failure)
  end

  defp restore_env(key, nil), do: Application.delete_env(:rindle, key)
  defp restore_env(key, value), do: Application.put_env(:rindle, key, value)
end
