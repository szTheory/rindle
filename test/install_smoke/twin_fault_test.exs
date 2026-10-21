Code.require_file("../twin/host/lib/twin/repo.ex", __DIR__)
Code.require_file("../twin/host/lib/twin/storage.ex", __DIR__)

defmodule Rindle.TwinFaultTest.Request do
  def request(operation, config) do
    send(config[:test_pid], {:delegated, operation.path, config[:sentinel]})
    {:ok, %{key: operation.path}}
  end
end

defmodule Rindle.TwinFaultTest do
  use ExUnit.Case, async: false
  @root Path.expand("../..", __DIR__)
  setup do
    opts =
      Keyword.take(Rindle.Repo.config(), [
        :hostname,
        :port,
        :username,
        :password,
        :database,
        :socket_dir
      ])

    schema = "twin_fault_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    {:ok, conn} = Postgrex.start_link(opts)
    Postgrex.query!(conn, "CREATE SCHEMA " <> schema, [])

    on_exit(fn ->
      {:ok, cleanup} = Postgrex.start_link(opts)
      Postgrex.query!(cleanup, "DROP SCHEMA " <> schema <> " CASCADE", [])
      GenServer.stop(cleanup)
    end)

    start_supervised!({Twin.Repo, opts ++ [parameters: [search_path: schema], pool_size: 4]})

    Twin.Repo.query!(
      "CREATE TABLE twin_fault_counters (run_id text, operation text, source_key text, claims integer NOT NULL, UNIQUE(run_id,operation))"
    )

    previous = System.get_env("TWIN_RUN_ID")
    System.put_env("TWIN_RUN_ID", schema)
    old = Application.get_env(:rindle, Rindle.Storage.S3)
    Application.put_env(:rindle, Rindle.Storage.S3, request_module: Rindle.TwinFaultTest.Request)

    on_exit(fn ->
      if previous,
        do: System.put_env("TWIN_RUN_ID", previous),
        else: System.delete_env("TWIN_RUN_ID")

      if old,
        do: Application.put_env(:rindle, Rindle.Storage.S3, old),
        else: Application.delete_env(:rindle, Rindle.Storage.S3)
    end)

    %{run_id: schema, repo_opts: opts ++ [parameters: [search_path: schema], pool_size: 4]}
  end

  test "concurrent selected deletes consume one committed fault and survive connection replacement",
       %{run_id: run, repo_opts: repo_opts} do
    Twin.Repo.query!(
      "INSERT INTO twin_fault_counters VALUES ($1,'stimulus','source',1),($1,'delete','source',0)",
      [run]
    )

    opts = [bucket: "fixture", aws_config: [test_pid: self(), sentinel: "unchanged"]]
    assert {:ok, _} = Twin.StorageFault.delete("variant", opts)
    assert_receive {:delegated, _, "unchanged"}
    tasks = for _ <- 1..2, do: Task.async(fn -> Twin.StorageFault.delete("source", opts) end)
    results = Enum.map(tasks, &Task.await/1)
    assert Enum.count(results, &(&1 == {:error, :twin_source_delete_once})) == 1
    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert_receive {:delegated, _, "unchanged"}

    assert %{rows: [[1]]} =
             Twin.Repo.query!("SELECT claims FROM twin_fault_counters WHERE operation='delete'")

    # A fresh ordinary Repo pool reads committed state; no Sandbox, ETS or file authority.
    config = Keyword.put(repo_opts, :name, :twin_counter_reader)
    {:ok, reader} = Twin.Repo.start_link(config)

    assert %{rows: [[1]]} =
             Ecto.Adapters.SQL.query!(
               :twin_counter_reader,
               "SELECT claims FROM twin_fault_counters WHERE operation='delete'"
             )

    GenServer.stop(reader)
    assert {:ok, _} = Twin.StorageFault.delete("source", opts)
    Twin.Repo.query!("DELETE FROM twin_fault_counters WHERE operation='delete'")
    assert {:error, :twin_fixture_missing} = Twin.StorageFault.delete("source", opts)
    assert Twin.StorageFault.capabilities() == Rindle.Storage.S3.capabilities()

    for {fun, arity} <- Rindle.Storage.behaviour_info(:callbacks),
        function_exported?(Rindle.Storage.S3, fun, arity) do
      assert function_exported?(Twin.StorageFault, fun, arity)
    end
  end

end
